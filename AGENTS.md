# AGENTS.md

## Project

This repository implements **mise-db**, a custom **mise backend plugin** that installs versioned database command wrappers backed by OCI images.

The GitHub repository is:

```text
lcmen/mise-db
```

The mise plugin name is:

```text
db
```

Users should install it with:

```bash
mise plugin install db https://github.com/lcmen/mise-db
```

Then use it in `mise.toml`:

```toml
[tools]
"db:postgres" = { version = "18.4", isolated = true }
```

The previous native-binary release direction has been superseded by the container-backed wrapper direction. Do not add CI for compiling or packaging database binaries unless the project explicitly reverses that decision.

---

## Current State

The current implementation is a PostgreSQL-only OCI-wrapper MVP with Docker and Apple Container adapters.

Implemented:

- `BackendListVersions` returns PostgreSQL versions discovered from Docker Hub tags via `lib/registry.lua`.
- `BackendInstall` validates `postgres`, resolves an Apple Container or Docker adapter, pulls `postgres:<version>-alpine`, copies wrappers into the mise install path, writes a manifest, and creates command symlinks.
- `BackendExecEnv` adds the install `bin/` directory to `PATH`, sets basic PostgreSQL credentials, and sets `PGHOST` when `MISE_DB_CONTAINER_TLD` is configured.
- PostgreSQL wrappers manage persistent server containers and short-lived client containers through the manifest-selected adapter.
- Docker healthchecks and Apple Container `pg_isready` polling are used for readiness.
- `tests/postgres.test.sh` smoke-tests both adapters.

Not implemented yet:

- MySQL wrappers.
- Valkey wrappers.
- Automatic host DNS setup through `devdns` or Apple Container DNS.
- Image digest pinning.
- Full non-PostgreSQL `BackendExecEnv` host/container naming variables.
- Native database binary publishing.

---

## Product Direction

`mise-db` should be treated as:

```text
A mise backend plugin that installs versioned database command wrappers backed by OCI images.
```

Mise is responsible for:

- version selection;
- installing wrapper files;
- activation through `PATH` and environment variables;
- per-tool options such as `isolated`.

The container runtime is responsible for:

- image storage;
- image execution;
- persistent server containers;
- short-lived client containers;
- container networking.

Do not silently pull images during ordinary wrapper execution. Installation should pull the image. If a user later removes the image, wrappers should fail clearly and tell the user to reinstall or repull.

---

## Tool Names

Use these exact public tool names:

```text
postgres
mysql
valkey
```

Only `postgres` is currently implemented. MySQL and Valkey are planned.

---

## PostgreSQL Wrapper Behavior

Installed PostgreSQL versions provide symlinks for:

```text
postgres
pg_ctl
psql
pg_dump
pg_restore
createdb
dropdb
createuser
dropuser
```

`pg_ctl` is the lifecycle interface for the persistent PostgreSQL container:

- `pg_ctl start` creates the container if missing, starts it, and waits until PostgreSQL is ready.
- `pg_ctl stop` stops and removes the container while preserving the data directory.
- `pg_ctl status` reports the managed container status and returns success only when the container is running and healthy.
- `pg_ctl restart` stops then starts.
- `pg_ctl reload` executes PostgreSQL reload inside the running container.

`postgres` starts the managed server and follows its logs.

Client commands such as `psql`, `pg_dump`, and `pg_restore` run in short-lived containers attached to the shared adapter network.

---

## Runtime Model

The supported runtimes are Docker and Apple Container. Adapter selection happens during installation: an unset `MISE_DB_ADAPTER` prefers Apple Container, then Docker; `MISE_DB_ADAPTER=docker|apple` selects explicitly. The resolved adapter is persisted in the install manifest. Wrappers reject a conflicting non-empty `MISE_DB_ADAPTER` and direct the user to force-reinstall.

The shared network name is:

```text
mise-db
```

The persistent container name is deterministic:

```text
mise-db-<tool>-<version-tag>-<instance>
```

Examples:

```text
mise-db-postgres-18-4-global
mise-db-postgres-18-4-myapp-0abc
```

The data directory is:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/mise-db/<tool>/<version>/<instance>
```

Global mode uses:

```text
global
```

Isolated mode derives an instance name from the project root slug plus a small checksum.

---

## Manifest

`BackendInstall` writes a manifest into the mise install path:

```text
TOOL=postgres
VERSION=18.4
IMAGE=postgres:18.4-alpine
ISOLATED=true
ADAPTER=apple
```

Installed wrappers must use the copied manifest and wrapper files inside the versioned mise install directory. Do not symlink installed commands back to the plugin checkout.

---

## Repository Structure

Current structure:

```text
metadata.lua
lib/
  postgres.lua
  registry.lua
  utils.lua
hooks/
  backend_list_versions.lua
  backend_install.lua
  backend_exec_env.lua
wrappers/
  postgres
  lib/
    apple.sh
    context.sh
    docker.sh
tests/
  helpers.sh
  postgres.test.sh
README.md
AGENTS.md
```

Add helper scripts only when needed. Keep the implementation small and understandable.

---

## Coding Style

- Bash scripts must use `set -euo pipefail`.
- Validate inputs early.
- Fail with clear error messages.
- Prefer explicit function arguments over hidden globals in shared helpers.
- Keep functions in `wrappers/lib/apple.sh`, `wrappers/lib/context.sh`, and `wrappers/lib/docker.sh` sorted alphabetically by function name.
- Use uppercase readonly variables for wrapper-level constants such as `LIB_DIR`, `INSTALL_DIR`, `CONTAINER`, and `NETWORK`.
- It is acceptable to use a file-level shellcheck disable for deliberate wrapper patterns, such as dynamic `source` paths or one-line readonly command substitutions.
- Prefer small, focused shell helpers over one large dispatch script.
- Do not introduce unrelated dependencies.

---

## Testing

Run static checks:

```bash
bash -n wrappers/postgres wrappers/lib/context.sh wrappers/lib/apple.sh wrappers/lib/docker.sh tests/postgres.test.sh
shellcheck wrappers/postgres wrappers/lib/apple.sh wrappers/lib/docker.sh tests/postgres.test.sh
```

Run the adapter smoke test:

```bash
tests/postgres.test.sh
```

The smoke test creates a temporary mise install layout under `/tmp` for both adapters, starts PostgreSQL, checks `pg_ctl status`, runs `select 1 as ok`, and stops the container. Both Apple Container and Docker must be available.

---

## Future Work

Near-term priorities:

1. Improve PostgreSQL wrapper coverage.
2. Add data safety checks.
3. Expand `BackendExecEnv` conventions for future MySQL and Valkey support.
4. Add host DNS integration.
5. Add MySQL and Valkey wrappers.

---

## Non-Goals For The Current MVP

Do not implement these unless explicitly requested:

- native database binary build CI;
- GitHub Release database binary assets;
- Windows support;
- musl/Alpine host support claims;
- source-built MySQL;
- automatic database migrations;
- automatic application database creation;
- automatic port allocation;
- deleting persistent database data on uninstall;
- service supervision outside the managed container lifecycle.
