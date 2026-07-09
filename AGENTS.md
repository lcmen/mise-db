# AGENTS.md

## Project

This repository implements **mise-db**, a custom **mise backend plugin** for installing prebuilt database binaries.

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
"db:postgres" = "18"
"db:mysql" = "8.4"
"db:redis" = "8"
```

Phase 1 only implements PostgreSQL 18.x. MySQL and Redis-compatible binaries are planned later.

Do **not** commit generated database binaries into git. Database binaries must be stored as GitHub Release assets.

---

## Final Product Behavior

Partial versions must resolve to the latest matching concrete upstream version:

```text
postgres 18 -> latest available 18.x, for example 18.4
mysql 8.4   -> latest available 8.4.x
redis 8     -> latest available 8.x
```

The plugin must publish and install exact upstream versions. Do not publish fake major-only versions such as `18` or `8`.

Good available versions:

```text
postgres: 16.14, 17.10, 18.4
mysql:    8.4.10, 9.4.0
redis:    8.0.3, 8.1.3
```

Bad available versions:

```text
postgres: 16, 17, 18
mysql:    8, 9
redis:    8
```

---

## Tool Names

Use these exact tool names:

```text
postgres
mysql
redis
```

Phase 1 validates and supports only:

```text
postgres
```

---

## Supported Platforms

Phase 1 required targets:

```text
linux-amd64-gnu
linux-arm64-gnu
darwin-amd64
darwin-arm64
```

Do not implement musl/Alpine or Windows in v0.1.

---

## GitHub Release Asset Naming

Database binaries must be uploaded to GitHub Releases using this naming scheme:

```text
db-<tool>-<version>-<target>.tar.xz
db-<tool>-<version>-<target>.tar.xz.sha256
```

Examples:

```text
db-postgres-18.4-linux-amd64-gnu.tar.xz
db-postgres-18.4-linux-arm64-gnu.tar.xz
db-postgres-18.4-darwin-amd64.tar.xz
db-postgres-18.4-darwin-arm64.tar.xz
db-mysql-8.4.10-linux-amd64-gnu.tar.xz
db-redis-8.1.3-linux-arm64-gnu.tar.xz
```

GitHub Release tags should use:

```text
<tool>-<version>
```

Examples:

```text
postgres-18.4
mysql-8.4.10
redis-8.1.3
```

Direct public URL shape:

```text
https://github.com/lcmen/mise-db/releases/download/<tool>-<version>/db-<tool>-<version>-<target>.tar.xz
```

While the repository is private, the plugin may download release assets through the GitHub Releases API with `GH_TOKEN`.

---

## Database Archive Layout

Each database binary archive should extract directly into the mise install directory and should have this general structure:

```text
bin/
lib/
share/
licenses/
```

PostgreSQL archive should include at least:

```text
bin/postgres
bin/pg_ctl
bin/initdb
bin/psql
bin/createdb
bin/dropdb
bin/createuser
bin/dropuser
```

MySQL archive should include at least:

```text
bin/mysqld
bin/mysql
bin/mysqladmin
bin/mysqldump
```

Redis-compatible archive should include at least:

```text
bin/redis-server
bin/redis-cli
```

`licenses/` should contain upstream license files copied by CI from the downloaded source or official binary package. Do not manually maintain upstream database license files in the repo root.

---

## Repository Structure

```text
metadata.lua
lib/
  utils.lua
hooks/
  backend_list_versions.lua
  backend_install.lua
  backend_exec_env.lua
ci/
  darwin.sh
  linux.sh
  matrix.json
  postgres.sh
  utils.sh
.github/
  workflows/
    build.yml
    rebuild.yml
README.md
AGENTS.md
```

Add helper scripts only when needed. Keep the implementation small and understandable.

---

## mise Backend Plugin Requirements

This must be implemented as a **mise backend plugin**, not as an asdf plugin.

Use the `db:<tool>` form:

```toml
[tools]
"db:postgres" = "18"
"db:mysql" = "8.4"
"db:redis" = "8"
```

The plugin should implement at least these hooks:

```text
BackendListVersions
BackendInstall
BackendExecEnv
```

### `BackendListVersions`

- Validate `ctx.tool`.
- Query GitHub Releases for `lcmen/mise-db`.
- Filter release tags by `<tool>-<version>`.
- Return concrete versions only.
- Sort versions oldest to newest so mise can resolve partial versions correctly.
- Ignore prereleases unless explicitly requested later.

### `BackendInstall`

- Validate tool name.
- Detect OS and architecture.
- Support glibc Linux and macOS targets listed above.
- Find the matching release asset named `db-<tool>-<version>-<target>.tar.xz`.
- Download the `.tar.xz` archive.
- Extract the archive into `ctx.install_path`.
- Ensure installed binaries are executable.
- Fail with a clear error if the platform or tool is unsupported.

### `BackendExecEnv`

- Add `<install_path>/bin` to `PATH`.
- Add useful home variables where applicable, such as `POSTGRES_HOME`.
- Do not start services automatically.

This plugin provides binaries only. It does not manage data directories, ports, service supervision, initialization, users, passwords, or migrations.

---

## CI Build Strategy

GitHub Actions should build or repackage database binaries and publish them as GitHub Release assets.

### PostgreSQL

Compile from source in CI through `ci/postgres.sh build`. The script uses:

```bash
VERSION=18.4 TARGET=linux-amd64-gnu ci/postgres.sh build
```

Internally it downloads PostgreSQL source, extracts it into `src/`, installs into `prefix/`, then packaging writes:

```text
dist/db-postgres-<version>-<target>.tar.xz
dist/db-postgres-<version>-<target>.tar.xz.sha256
```

PostgreSQL configure options:

```bash
./configure --prefix="$PREFIX" --with-openssl --with-icu --with-libxml --with-libxslt
make -j"$(cpu_count)"
make install
```

### MySQL

For v0.1, prefer repackaging official MySQL Community generic archives instead of compiling MySQL from source.

### Redis-Compatible Binaries

Future Redis-compatible binaries may be built from a compatible upstream source. Keep the public tool name `redis`.

---

## GitHub Actions Workflow Requirements

Manual workflows are enough for v0.1.

Required workflow permissions:

```yaml
permissions:
  contents: write
```

The normal workflow is:

```text
.github/workflows/build.yml
```

It reads tool/version pairs from:

```text
ci/matrix.json
```

and builds each pair for every supported target. Existing complete release assets are skipped when both the archive and `.sha256` already exist.

The force rebuild workflow is:

```text
.github/workflows/rebuild.yml
```

It accepts `tool` and `version` inputs and rebuilds/re-uploads that pair for every supported target.

Both workflows should:

1. Check out the repo.
2. Install platform dependencies through `ci/linux.sh setup` or `ci/darwin.sh setup`.
3. Build or repackage the selected tool/version through `ci/<tool>.sh build`.
4. Package the result into `dist/db-<tool>-<version>-<target>.tar.xz`.
5. Generate a `.sha256` file.
6. Verify the archive through `ci/<tool>.sh verify`.
7. Create or update the GitHub Release `<tool>-<version>` and upload assets with `--clobber`.

---

## Verification

`ci/<tool>.sh verify` should extract a generated archive into a temporary directory and run version commands.

PostgreSQL verification:

```bash
VERSION=18.4 TARGET=linux-amd64-gnu ci/postgres.sh verify
```

That command runs `bin/postgres --version`, `bin/psql --version`, and `bin/initdb --version`.

Verification should not start persistent services or require privileged access.

---

## README Requirements

Create a `README.md` explaining:

- What `mise-db` is.
- How to install the plugin as `db`.
- Example `mise.toml` usage.
- Supported tools.
- Supported platforms.
- That it installs binaries only and does not manage services.
- Where database binaries are hosted.
- How to run a manual GitHub Actions build.
- How version resolution works.

Include this example:

```toml
[tools]
"db:postgres" = "18"
```

Also include exact-version examples:

```toml
[tools]
"db:postgres" = "18.4"
```

---

## Version Discovery

Manual builds are enough for v0.1. If implementing discovery later:

- Discover latest supported PostgreSQL versions from official PostgreSQL release/source listings.
- Discover latest MySQL Community versions from official MySQL downloads/release metadata where practical.
- Discover latest Redis-compatible versions from upstream release metadata.
- Keep only the latest 4 relevant release lines per tool.
- Do not trigger builds for assets that already exist in GitHub Releases.

Discovery should be conservative. Prefer no automatic build over publishing the wrong version.

---

## Licensing Policy

Do not commit generated database binaries into git.

Do not manually copy upstream database license files into the repo root.

CI should copy upstream license files into generated database binary archives under:

```text
licenses/<tool>/
```

The repository root license should only describe the license for the `db` plugin/build scripts themselves.

---

## Portability Notes

Linux v0.1 targets are glibc-based Linux.

Be explicit in docs that v0.1 supports glibc Linux, not musl/Alpine.

Prefer bundling required shared libraries when practical, but do not overcomplicate v0.1. At minimum, verify the generated archive on the GitHub runner where it was built.

Future improvements:

- Add RPATH/patchelf handling for bundled shared libraries.
- Add musl targets only if there is clear demand.

---

## Coding Style

- Keep scripts POSIX-ish where practical, but Bash is acceptable.
- Use `set -euo pipefail` in shell scripts.
- Validate inputs early.
- Fail with clear error messages.
- Avoid hidden global state.
- Prefer small scripts over one large script.
- Do not add unrelated dependencies.
- Do not introduce service-management behavior into the mise plugin.

---

## Security and Integrity

- Generate SHA256 checksum files for every archive.
- Plugin-side checksum verification can be added later.
- Do not execute downloaded files during installation except for optional local verification in CI.
- Use HTTPS URLs only.
- Avoid curl-pipe-shell patterns.

---

## Non-Goals for v0.1

Do not implement these in the first version:

- Database service supervisor.
- Automatic `initdb` / MySQL data directory initialization.
- Automatic port allocation.
- Worktree-specific database names.
- musl/Alpine builds.
- Source-built MySQL.
- Windows builds.
- Docker images.

This repository should remain focused on one thing:

```text
Install prebuilt database binaries through mise.
```
