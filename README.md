# mise-db

`mise-db` is a [mise](https://mise.jdx.dev/) backend plugin that provides a local database engine through containers.

Install the plugin as `db`, add a database to `mise.toml`, then start, stop, and use the database with familiar binaries such as `pg_ctl`, `postgres`, `psql`, `pg_dump`, and `pg_restore`. Those binaries are wrappers around a versioned PostgreSQL OCI image, so they feel like native tools while the database engine runs in a managed container.

Current status: PostgreSQL on Docker and Apple Container.

## Requirements

- [mise](https://mise.jdx.dev/)
- One usable runtime: Docker with a running daemon, or Apple Container with a running service
- Apple Container requires Apple silicon and macOS 26 or later
- Network access during `mise install` so the selected runtime can pull the PostgreSQL image

## Install The Plugin

```bash
mise plugin install db https://github.com/lcmen/mise-db
```

For local development of this plugin:

```bash
mise plugin link db /path/to/mise-db
```

## Add database

Add PostgreSQL to `mise.toml`:

```bash
mise use db:postgres@18.4
```

During install, `mise-db` pulls:

```text
postgres:18.4-alpine
```

and installs wrapper commands into the mise tool installation. The selected runtime adapter is recorded in that installation.

## Use database

Thanks to thin wrappers, all commands can be executed like native ones:

```bash
pg_ctl start
psql -d postgres
pg_ctl stop
```

## Container Runtime

During `mise install`, mise-db prefers a usable Apple Container service, then a usable Docker daemon. Set `MISE_DB_ADAPTER` to choose explicitly:

```bash
MISE_DB_ADAPTER=apple mise install db:postgres@18.4
MISE_DB_ADAPTER=docker mise install db:postgres@18.4
```

Apple Container must be installed and started first:

```bash
container system start
```

Changing `MISE_DB_ADAPTER` after installation is rejected so wrappers never mix runtimes. Force-reinstall with the intended adapter instead:

```bash
MISE_DB_ADAPTER=apple mise install --force db:postgres@18.4
```

## Isolation

By default, database runs in global mode which gives you one database container instance for the selected version. Use `isolated = true` to create a project-specific instance, i.e.:

```bash
mise use 'db:postgres@18.4[isolated=true]'
```

This lets different projects use the same PostgreSQL version without sharing the same container or data directory.

## Hostnames For Applications

By default, wrappers connect through the selected runtime's shared `mise-db` network and no database container host is exposed to applications. To expose stable container hostnames, run a DNS service such as [`devdns`](https://github.com/lcmen/devdns) and configure the container TLD globally:

```toml
# ~/.config/mise/config.toml
[env]
MISE_DB_CONTAINER_TLD = "container"
```

When `MISE_DB_CONTAINER_TLD` is available to mise, activation exports the database host using the tool's environment convention:

```text
PGHOST=mise-db-postgres-18-4-myapp-0abc.container
```

Rails can then use the activated environment:

```yaml
development:
  adapter: postgresql
  host: <%= ENV.fetch("PGHOST") %>
  username: <%= ENV.fetch("PGUSER", "postgres") %>
  password: <%= ENV.fetch("PGPASSWORD", "postgres") %>
```

DNS must resolve the generated hostname to an address reachable from the host. On Docker Desktop for macOS, container IPs may need additional networking support. Apple Container DNS setup remains manual; configure its DNS domain and macOS resolver before setting `MISE_DB_CONTAINER_TLD`.

## Data Storage

Database files are stored outside the mise install directory:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/mise-db/postgres/<version>/<instance>
```

Stopping PostgreSQL removes the container but keeps the data directory.

Uninstalling the mise tool does not delete database data.

## Runtime Details

Each runtime uses one shared network in its own runtime namespace:

```text
mise-db
```

`pg_ctl start` creates a persistent container and waits until PostgreSQL is ready before returning. Docker uses a container healthcheck; Apple Container polls `pg_isready` inside the managed container.

If the selected runtime removes the image later, wrappers fail with a clear message. Run `mise install --force db:postgres@18.4` to pull the image back.

## Current Limitations

- PostgreSQL is the only implemented database.
- MySQL and Valkey are planned but not available yet.
- Host DNS integration is not implemented yet.
- Images are pulled by tag, not pinned by digest yet.
