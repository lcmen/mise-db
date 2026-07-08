# AGENTS.md

## Project

This repository implements **binaries-db**, a custom **mise backend plugin** for installing prebuilt database binaries.

The plugin should expose these tools:

```toml
[tools]
"binaries-db:postgres" = "18"
"binaries-db:mysql" = "8.4"
"binaries-db:valkey" = "8"
```

The repository contains both:

1. The mise backend plugin source code.
2. GitHub Actions scripts that build or repackage database binaries and upload them to GitHub Releases in this same repository.

Do **not** commit generated database binaries into git. Database binaries must be stored as GitHub Release assets.

---

## Final product behavior

Users should be able to install the plugin with:

```bash
mise plugin install binaries-db https://github.com/<owner>/binaries-db
```

Then use it in `mise.toml`:

```toml
[tools]
"binaries-db:postgres" = "18"
"binaries-db:mysql" = "8.4"
"binaries-db:valkey" = "8"
```

Partial versions must resolve to the latest matching concrete upstream version:

```text
postgres 18   -> latest available 18.x, for example 18.4
mysql 8.4     -> latest available 8.4.x
valkey 8      -> latest available 8.x
```

The plugin must publish and install exact upstream versions. Do not publish fake major-only versions such as `18` or `8`.

Good available versions:

```text
postgres: 16.14, 17.10, 18.4
mysql:    8.4.10, 9.4.0
valkey:   8.0.3, 8.1.3
```

Bad available versions:

```text
postgres: 16, 17, 18
mysql:    8, 9
valkey:   8
```

---

## Tool names

Use these exact tool names:

```text
postgres
mysql
valkey
```

Do not expose Valkey as `redis` in v0.1.

Rationale:

- `postgres` provides PostgreSQL binaries.
- `mysql` provides MySQL Community Server / client binaries.
- `valkey` provides a Redis-protocol-compatible server with a cleaner license story than modern Redis.

---

## Supported platforms

MVP required targets:

```text
linux-amd64-gnu
linux-arm64-gnu
```

Design the asset naming and plugin target detection so these can be added later without breaking compatibility:

```text
darwin-amd64
darwin-arm64
```

Do not implement musl in v0.1 unless explicitly requested later.

---

## GitHub Release asset naming

Database binaries must be uploaded to GitHub Releases using this naming scheme:

```text
binaries-db-<tool>-<version>-<target>.tar.xz
binaries-db-<tool>-<version>-<target>.tar.xz.sha256
```

Examples:

```text
binaries-db-postgres-18.4-linux-amd64-gnu.tar.xz
binaries-db-postgres-18.4-linux-arm64-gnu.tar.xz
binaries-db-mysql-8.4.10-linux-amd64-gnu.tar.xz
binaries-db-valkey-8.1.3-linux-arm64-gnu.tar.xz
```

GitHub Release tags should use:

```text
<tool>-<version>
```

Examples:

```text
postgres-18.4
mysql-8.4.10
valkey-8.1.3
```

The plugin should be able to construct the download URL mechanically from:

```text
repo owner/name
tool
version
target
```

URL shape:

```text
https://github.com/<owner>/binaries-db/releases/download/<tool>-<version>/binaries-db-<tool>-<version>-<target>.tar.xz
```

---

## Database archive layout

Each database binary archive should extract directly into the mise install directory and should have this general structure:

```text
bin/
lib/
share/
licenses/
```

`bin/` must contain the expected user-facing binaries.

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

Valkey archive should include at least:

```text
bin/valkey-server
bin/valkey-cli
```

If upstream also provides Redis-compatible command names such as `redis-server` or `redis-cli`, do not rely on them as the primary interface. Prefer Valkey names.

`licenses/` should contain upstream license files copied by CI from the downloaded source or official binary package. Do not manually maintain upstream license files in the repo root.

## Repository structure

Create this structure:

```text
metadata.lua
hooks/
  backend_list_versions.lua
  backend_install.lua
  backend_exec_env.lua
ci/
  postgres.sh
  build-mysql.sh
  build-valkey.sh
  package.sh
  verify.sh
.github/
  workflows/
    build.yml
README.md
AGENTS.md
```

Add helper scripts only when needed. Keep the implementation small and understandable.

---

## mise backend plugin requirements

This must be implemented as a **mise backend plugin**, not as an asdf plugin.

Use the `binaries-db:<tool>` form:

```toml
[tools]
"binaries-db:postgres" = "18"
"binaries-db:mysql" = "8.4"
"binaries-db:valkey" = "8"
```

The plugin should implement at least these hooks:

```text
BackendListVersions
BackendInstall
BackendExecEnv
```

Expected responsibilities:

### `BackendListVersions`

- Validate that `ctx.tool` is one of `postgres`, `mysql`, or `valkey`.
- Query GitHub Releases for this repository.
- Filter release tags by `<tool>-<version>`.
- Return concrete versions only.
- Sort versions oldest to newest so mise can resolve partial versions correctly.
- Ignore prereleases unless the user explicitly requests prerelease support later.

### `BackendInstall`

- Validate tool name.
- Detect OS and architecture.
- Support Linux glibc targets for v0.1:
  - `linux-amd64-gnu`
  - `linux-arm64-gnu`
- Construct the GitHub Release asset URL.
- Download the `.tar.xz` archive.
- Optionally download and verify the `.sha256` file.
- Extract the archive into `ctx.install_path`.
- Ensure installed binaries are executable.
- Fail with a clear error if the platform or tool is unsupported.

### `BackendExecEnv`

- Add `<install_path>/bin` to `PATH`.
- Add useful home variables:
  - `POSTGRES_HOME`
  - `MYSQL_HOME`
  - `VALKEY_HOME`
- Do not start services automatically.

This plugin provides binaries only. It does not manage data directories, ports, service supervision, initialization, users, passwords, or migrations.

---

## CI build strategy

GitHub Actions should build or repackage database binaries and publish them as GitHub Release assets.

### PostgreSQL

Compile from source in CI.

Expected rough flow:

```bash
curl -fSLO "https://ftp.postgresql.org/pub/source/v${version}/postgresql-${version}.tar.bz2"
tar -xf "postgresql-${version}.tar.bz2"
cd "postgresql-${version}"
./configure --prefix="$prefix" --with-openssl --with-icu --with-libxml --with-libxslt
make -j"$(nproc)"
make install
```

### MySQL

For v0.1, prefer repackaging official MySQL Community generic Linux tarballs instead of compiling MySQL from source.

Reason: MySQL source builds are significantly heavier and more fragile in CI than PostgreSQL and Valkey.

The script should normalize official MySQL archives into the common `binaries-db` archive layout.

Later, source-built MySQL can be added as a separate task.

### Valkey

Compile from source in CI.

Expected rough flow:

```bash
curl -fSL "https://github.com/valkey-io/valkey/archive/refs/tags/${version}.tar.gz" -o "valkey-${version}.tar.gz"
tar -xf "valkey-${version}.tar.gz"
cd "valkey-${version}"
make -j"$(nproc)"
make PREFIX="$prefix" install
```

Be prepared for upstream tag names to use either `8.1.3` or `v8.1.3`. Implement this robustly.

---

## GitHub Actions workflow requirements

Create `.github/workflows/build.yml`.

It should support manual builds first:

```yaml
on:
  workflow_dispatch:
    inputs:
      tool:
        type: choice
        options:
          - postgres
          - mysql
          - valkey
      version:
        type: string
        required: true
```

Use a matrix for required Linux targets:

```yaml
strategy:
  fail-fast: false
  matrix:
    include:
      - target: linux-amd64-gnu
        arch: amd64
        runner: ubuntu-24.04
      - target: linux-arm64-gnu
        arch: arm64
        runner: ubuntu-24.04-arm
```

The workflow should:

1. Check out the repo.
2. Install build dependencies.
3. Build or repackage the selected tool/version.
4. Package the result into `dist/binaries-db-<tool>-<version>-<target>.tar.xz`.
5. Generate a `.sha256` file.
6. Smoke-test the archive by extracting it and running version commands.
7. Create or update the GitHub Release `<tool>-<version>`.
8. Upload the archive and checksum with `--clobber`.

Required workflow permissions:

```yaml
permissions:
  contents: write
```

---

## Smoke tests

`ci/verify.sh` should extract a generated archive into a temporary directory and run version commands.

PostgreSQL smoke test:

```bash
bin/postgres --version
bin/psql --version
bin/initdb --version
```

MySQL smoke test:

```bash
bin/mysqld --version
bin/mysql --version
```

Valkey smoke test:

```bash
bin/valkey-server --version
bin/valkey-cli --version
```

Smoke tests should not start persistent services or require privileged access.

---

## README requirements

Create a `README.md` explaining:

- What `binaries-db` is.
- How to install the mise plugin.
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
"binaries-db:postgres" = "18"
"binaries-db:mysql" = "8.4"
"binaries-db:valkey" = "8"
```

Also include exact-version examples:

```toml
[tools]
"binaries-db:postgres" = "18.4"
"binaries-db:mysql" = "8.4.10"
"binaries-db:valkey" = "8.1.3"
```

---

## Version discovery

Manual builds are enough for v0.1. If implementing discovery later:

- Discover latest supported PostgreSQL versions from official PostgreSQL release/source listings.
- Discover latest MySQL Community versions from official MySQL downloads/release metadata where practical.
- Discover latest Valkey versions from GitHub releases/tags.
- Keep only the latest 4 relevant release lines per tool.
- Do not trigger builds for assets that already exist in GitHub Releases.

Discovery should be conservative. Prefer no automatic build over publishing the wrong version.

---

## Licensing policy

Do not commit generated database binaries into git.

Do not manually copy upstream database license files into the repo root.

CI should copy upstream license files into the generated database binary archive under:

```text
licenses/<tool>/
```

The repository root license should only describe the license for the `binaries-db` plugin/build scripts themselves.

The generated archives should preserve relevant upstream license notices.

---

## Portability notes

Linux v0.1 target is glibc-based Linux.

Be explicit in docs that v0.1 supports glibc Linux, not musl/Alpine.

Prefer bundling required shared libraries when practical, but do not overcomplicate v0.1. At minimum, smoke-test the generated archive on the GitHub runner where it was built.

Future improvement:

- Add RPATH/patchelf handling for bundled shared libraries.
- Add macOS targets.
- Add musl targets only if there is clear demand.

---

## Coding style

- Keep scripts POSIX-ish where practical, but Bash is acceptable.
- Use `set -euo pipefail` in shell scripts.
- Validate inputs early.
- Fail with clear error messages.
- Avoid hidden global state.
- Prefer small scripts over one large script.
- Do not add unrelated dependencies.
- Do not introduce service-management behavior into the mise plugin.

---

## Security and integrity

- Generate SHA256 checksum files for every archive.
- The plugin should verify checksums when practical.
- Do not execute downloaded files during installation except for optional local smoke tests in CI.
- Use HTTPS URLs only.
- Avoid curl-pipe-shell patterns.

---

## Non-goals for v0.1

Do not implement these in the first version:

- Database service supervisor.
- Automatic `initdb` / MySQL data directory initialization.
- Automatic port allocation.
- Worktree-specific database names.
- Redis compatibility alias named `redis`.
- musl/Alpine builds.
- Source-built MySQL.
- Windows builds.
- Docker images.

This repository should remain focused on one thing:

```text
Install prebuilt database binaries through mise.
```
