# Redis

mise-db runs Redis from the official `redis:<version>-alpine` image with Docker or Apple Container.

## Installed commands

The Redis install contains only:

```text
redis-server
redis-cli
```

`redis-server` controls the persistent server container:

- `redis-server start` creates and starts the container, then waits for Redis.
- `redis-server stop` stops and removes the container but keeps its data.
- `redis-server status` succeeds only when Redis is running and answers `PING`.
- `redis-server restart` stops and starts the container.
- `redis-server` with no arguments starts Redis and follows its logs.

`redis-cli` runs in a short-lived container connected to the managed server. `redis-cli --help` and `redis-cli --version` work without a running server.

## Versions and installation

Version discovery reads tags from the official Redis repository on Docker Hub. mise-db exposes stable numeric Alpine minor and patch releases for Redis 6 and newer, such as `7.4` and `7.4.2`, but excludes the mutable `7` major-only tag. Release candidates, distro-pinned tags such as `8.0-alpine3.21`, non-Alpine tags, pre-6 releases, and tags missing the current host's `amd64` or `arm64` image are also excluded.

Use a major selector such as `mise-db:redis@7`. Mise resolves it to the newest matching concrete release. Run `CACHE=0 mise upgrade` to discover and install a newer release immediately.

Registry results are cached for 24 hours:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/mise-db/redis.json
```

Set `CACHE=0` to bypass the cache. Installation pulls `redis:<resolved-version>-alpine`; wrapper execution never pulls an image.

Installation and execution require the same global `MISE_DB_ADAPTER` value (`apple` or `docker`). mise-db does not auto-detect a runtime.
To change adapters, stop Redis through the old adapter, update the global setting, force-reinstall the tool, and then start it through the new adapter. Otherwise, its old container can remain in the previous runtime.

The supported Redis range crosses license eras. Releases through 7.2.4 use BSD-3-Clause, Redis 7.4.x through 7.8.x use RSALv2 or SSPLv1, and Redis 8 and newer offer RSALv2, SSPLv1, or AGPLv3. Review the [official image license summary](https://hub.docker.com/_/redis) and [Redis licensing overview](https://redis.io/legal/licenses/) for the exact selected release.

## Environment and networking

Activation exports the wrapper state:

```text
_MISE_DB_REDIS_VERSION=<resolved-version>
_MISE_DB_REDIS_IMAGE=redis:<resolved-version>-alpine
_MISE_DB_REDIS_NAME=<name>
```

These underscore-prefixed values are internal wrapper state. The wrapper requires them, so run Redis commands in an activated mise environment. No installation manifest is used.

Missing and empty name options resolve to `global`. An explicit name must match `[a-z0-9]+(-[a-z0-9]+)*` and can be selected with `mise-db:redis[name=my-app]@7.4`.

When `MISE_DB_DOMAIN` is configured, activation exports:

```text
REDIS_URL=redis://<deterministic-container-hostname>:6379
```

Without `MISE_DB_DOMAIN`, mise-db does not export `REDIS_URL`. Wrapper clients always connect internally over the shared `mise-db` runtime network: Docker uses the managed container name, while Apple Container uses its IPv4 address.

mise-db does not publish a host port or configure host DNS. The server has no password and no TLS, so do not expose its container network to untrusted clients.

## Containers and persistence

The managed container name is:

```text
mise-db-redis-<version>-<name>
```

Redis stores `/data` on the host at:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/mise-db/redis/<version>/<name>
```

mise-db enables append-only persistence with `appendonly yes` and `appendfsync everysec`, following the official image's `/data` persistent-volume model. The container runs as the image's `redis` user, and mise-db makes the version/name data directory writable so bind mounts work with both runtimes. Up to roughly one second of acknowledged writes can be lost in a crash. Stopping Redis or uninstalling the mise tool does not delete this directory.

Docker uses `redis-cli ping` as the container healthcheck. Apple Container polls the same command inside the managed container.

## Current limits

- Images use tags and are not pinned by digest.
- Authentication, TLS, host-port publishing, Sentinel, clustering, modules, and custom configuration are not supported.
- mise-db manages one Redis server per selected version and name.
