# mise-db

`mise-db` is a [mise](https://mise.jdx.dev/) backend plugin that provides a local database engine through containers.

Install the plugin as `mise-db`, add a database to `mise.toml`, then start, stop, and use it through familiar PostgreSQL or Redis commands. The installed binaries are wrappers around versioned OCI images, so they feel like native tools while the database engine runs in a managed container.

Current status: PostgreSQL and Redis on Docker and Apple Container.

## Requirements

- [mise](https://mise.jdx.dev/)
- `MISE_DB_ADAPTER` set globally to `docker` or `apple`
- The configured runtime, with its CLI installed and service running
- Apple Container requires Apple silicon and macOS 26 or later
- Network access during `mise install` so the selected runtime can pull the database image

## Install The Plugin

```bash
mise plugin install mise-db https://github.com/lcmen/mise-db
```

For local development of this plugin:

```bash
mise plugin link mise-db /path/to/mise-db
```

## Add database

Add PostgreSQL to `mise.toml`:

```bash
mise use mise-db:postgres@18
```

Or add Redis:

```bash
mise use mise-db:redis@7
```

Major selectors are recommended. Mise resolves them to the newest concrete matching release, so the examples above may resolve to versions such as PostgreSQL `18.4` and Redis `7.4.2`. mise-db excludes mutable major-only image tags and pulls the exact resolved image during installation.

Run `CACHE=0 mise upgrade` to refresh registry data immediately and install a newer concrete release that matches the selector.

During install, `mise-db` pulls:

```text
postgres:18.4-alpine
redis:7.4.2-alpine
```

and installs self-contained wrapper commands into the mise tool installation. Resolved version and image state is passed to those wrappers when mise activates the tool.

Version discovery is cached for 24 hours in:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/mise-db/<service>.json
```

Set `CACHE=0` to bypass the registry cache for a single run.

Set `DEBUG=1` to print detailed mise-db diagnostics for a single command:

```bash
DEBUG=1 mise ls-remote mise-db:postgres
```

Debug output includes cache decisions, individual Docker Hub tag pages, adapter selection, image installation, and container lifecycle operations. mise-db-owned messages use the `[mise-db]` prefix. Interactive debug messages are cyan, warnings are orange, and errors are red; redirected output does not contain terminal color codes.

## Use database

Thanks to thin wrappers, all commands can be executed like native ones:

```bash
pg_ctl start
psql
pg_ctl stop
```

Redis installs only `redis-server` and `redis-cli`:

```bash
redis-server start
redis-cli ping
redis-server stop
```

See [PostgreSQL](docs/services/postgresql.md) and [Redis](docs/services/redis.md) for service-specific lifecycle, persistence, versions, environment, and limitations.

## Container Runtime

mise-db requires one global runtime choice. Set `MISE_DB_ADAPTER` in your global mise config before installing:

```toml
# ~/.config/mise/config.toml
[env]
MISE_DB_ADAPTER = "apple"
# MISE_DB_ADAPTER = "docker"
```

Apple Container must be installed and started first:

```bash
container system start
```

Installation and wrapper execution always use this setting; mise-db never auto-detects or silently switches runtimes. To change it:

1. Stop all mise-db services while the old adapter is still configured.
2. Change `MISE_DB_ADAPTER` in the global mise config.
3. Force-reinstall every configured mise-db tool so its image is pulled into the new runtime.
4. Start the services again.

For example, after changing the setting:

```bash
mise install --force mise-db:<service>@<version>
```

Changing the setting while containers are running can leave those containers in the previous runtime. mise-db does not coordinate containers across runtimes.

## Names

By default, a database uses the `global` name, which gives it one container and datastore for the selected version. Set an explicit name when environments should not share state:

```bash
mise use 'mise-db:postgres[name=my-app]@18.4'
```

Names contain lowercase letters and digits separated by single hyphens. PostgreSQL and Redis options are independent, so one mise environment can assign a different name to each service.

## Hostnames For Applications

By default, wrappers connect through the selected runtime's shared `mise-db` network and no database container host is exposed to applications.

To expose stable container hostnames with Apple Container, create a local DNS domain and configure the same TLD in mise:

```bash
sudo container system dns create container
```

```toml
# ~/.config/mise/config.toml
[env]
MISE_DB_DOMAIN = "container"
```

Apple Container resolves named containers as `<container-name>.<domain>`. `mise-db` creates the persistent container with a deterministic name, so when `MISE_DB_DOMAIN` is available to mise, activation exports the database host using the tool's environment convention:

```text
PGHOST=mise-db-postgres-18-4-my-app.container
```

Redis activation exports a URL with the same deterministic naming:

```text
REDIS_URL=redis://mise-db-redis-7-4-my-app.container:6379
```

Rails can then use the activated environment:

```yaml
development:
  adapter: postgresql
  host: <%= ENV.fetch("PGHOST") %>
  username: <%= ENV.fetch("PGUSER", "postgres") %>
  password: <%= ENV.fetch("PGPASS", "postgres") %>
```

For Docker, start [`devdns`](https://github.com/lcmen/devdns) with the `mise-db` domain:

```bash
HOSTMACHINE_IP="$(docker network inspect mise-db --format '{{(index .IPAM.Config 0).Gateway}}')"

docker run -d \
  --name devdns \
  --restart unless-stopped \
  --network mise-db \
  -p 127.0.0.1:53:53/udp \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e DNS_DOMAIN=mise-db \
  -e NETWORK=mise-db \
  -e HOSTMACHINE_IP="$HOSTMACHINE_IP" \
  lmendelowski/devdns
```

The `mise-db` network must already exist; starting a mise-db-managed database creates it. `HOSTMACHINE_IP` reads that network's host-side gateway.

Follow devdns instructions to setup resolvers: https://github.com/lcmen/devdns#host-machine--containers

## Data Storage

Database files are stored outside the mise install directory:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/mise-db/<service>/<version>/<name>
```

Stopping a service removes its container but keeps the data directory. Redis mounts this directory at `/data` and enables AOF with `appendfsync everysec`.

Uninstalling the mise tool does not delete database data.

## Runtime Details

Each runtime uses one shared network in its own runtime namespace:

```text
mise-db
```

Starting a service creates a persistent container and waits until it is ready before returning. Docker uses a service-specific container healthcheck. Apple Container polls `pg_isready` for PostgreSQL and `redis-cli ping` for Redis.

Client commands run in short-lived containers on the shared network. Docker clients connect to the managed container by name; Apple Container clients connect to its IPv4 address on that network.

If the selected runtime removes the image later, wrappers fail with a clear message. Force-reinstall the selected mise-db tool to pull the image back.

There is no per-installation manifest. Mise activation exports the resolved version, exact image, and name to wrappers through internal, service-specific `_MISE_DB_POSTGRES_*` or `_MISE_DB_REDIS_*` variables. Run installed commands in an activated mise environment.

## Current Limitations

- MySQL is planned but not available yet.
- Redis authentication, TLS, host-port publishing, Sentinel, clustering, modules, and custom configuration are not implemented.
- Automatic host DNS setup is not implemented yet.
- Images are pulled by tag, not pinned by digest yet.
