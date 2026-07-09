# mise-db

`mise-db` is a [mise](https://mise.jdx.dev/) backend plugin repository. The plugin is installed as `db` and installs prebuilt database binaries.

`mise-db` currently supports PostgreSQL on glibc Linux and macOS. The repository is structured so MySQL and Redis-compatible binaries can be added later without changing the release asset naming scheme.

This plugin provides binaries only. It does not manage services, data directories, ports, users, passwords, initialization, migrations, or process supervision.

## Install

```bash
mise plugin install db https://github.com/lcmen/mise-db
```

If you are testing from a local checkout:

```bash
mise plugin link db /path/to/mise-db
```

## Usage

Partial versions resolve to the latest matching concrete upstream version published in this repository's GitHub Releases:

```toml
[tools]
"db:postgres" = "18"
```

Exact versions are also supported:

```toml
[tools]
"db:postgres" = "18.4"
```

## Supported Tools

- `postgres` - PostgreSQL server and client binaries

Planned tools:

- `mysql` - MySQL Community Server / client binaries
- `redis` - Redis-compatible server and CLI binaries

## Supported Platforms

Supported targets:

- `linux-amd64-gnu`
- `linux-arm64-gnu`
- `darwin-amd64`
- `darwin-arm64`

musl/Alpine, Windows, MySQL, and Redis-compatible binaries are not supported yet.

## GitHub Release Assets

Database binaries are hosted as GitHub Release assets in this repository.

Release tags use:

```text
<tool>-<version>
```

Example:

```text
postgres-18.4
```

Assets use:

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
```

Archives extract directly into the mise install directory and contain:

```text
bin/
lib/
share/
licenses/
```

## Version Resolution

The plugin lists concrete PostgreSQL 18.x versions from GitHub Releases by reading tags named:

```text
postgres-18.x
```

Partial versions resolve to the latest matching concrete version. For example:

```text
postgres 18 -> latest available 18.x
```

The plugin publishes and installs exact upstream versions only. It does not publish fake major-only versions such as `18`.

## Manual GitHub Actions Builds

Use the `Build database binaries` workflow from the GitHub Actions tab.

The workflow reads tool/version pairs from `ci/matrix.json` and builds each pair for every supported target. Existing complete release assets are skipped.

Use the `Rebuild database binary` workflow to force rebuild and re-upload one tool/version across every supported target.

Local package verification:

```bash
export VERSION=18.4
export TARGET=linux-amd64-gnu

ci/postgres.sh package
ci/postgres.sh verify
```

## Available Versions

| Tool | Versions |
| --- | --- |
| `postgres` | `18.3`, `18.4` |
| `mysql` | Not supported yet |
| `redis` | Not supported yet |
