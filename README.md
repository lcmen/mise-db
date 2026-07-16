# mise-db

`mise-db` is a [mise](https://mise.jdx.dev/) backend plugin that provides a local database engine through containers.

Install the plugin as `db`, add a database to `mise.toml`, then start, stop, and use the database with familiar binaries such as `pg_ctl`, `postgres`, `psql`, `pg_dump`, and `pg_restore`. Those binaries are wrappers around a versioned PostgreSQL Docker image, so they feel like native tools while the database engine runs in a managed container.

Current status: PostgreSQL on Docker.

## Requirements

- [mise](https://mise.jdx.dev/)
- Docker CLI
- A running Docker daemon available to your user
- Network access during `mise install` so Docker can pull the PostgreSQL image

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

and installs wrapper commands into the mise tool installation.

## Use database

Thanks to thin wrappers, all commands can be executed like native ones:

```bash
pg_ctl start
psql -d postgres
pg_ctl stop
```

## Isolation

By default, database runs in global mode which gives you one database container instance for the selected version. Use `isolated = true` to create a project-specific instance, i.e.:

```bash
mise use 'db:postgres@18.4[isolated=true]'
```

This lets different projects use the same PostgreSQL version without sharing the same container or data directory.

## Data Storage

Database files are stored outside the mise install directory:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/mise-db/postgres/<version>/<instance>
```

Stopping PostgreSQL removes the container but keeps the data directory.

Uninstalling the mise tool does not delete database data.

## Docker Details

`mise-db` uses one shared Docker network:

```text
mise-db
```

`pg_ctl start` creates a persistent container with a Docker healthcheck and waits until PostgreSQL is healthy before returning.

If Docker removes the image later, for example through `docker image prune`, wrappers fail with a clear message. Run `mise install --force db:postgres@18.4` to pull the image back.

## Current Limitations

- PostgreSQL is the only implemented database.
- Docker is the only implemented runtime.
- MySQL and Valkey are planned but not available yet.
- Apple `container` support is planned but not available yet.
- Host DNS integration is not implemented yet.
- Images are pulled by tag, not pinned by digest yet.
