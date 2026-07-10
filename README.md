# mise-db

`mise-db` is a [mise](https://mise.jdx.dev/) backend plugin repository. The plugin is installed as `db` and installs prebuilt database binaries.

`mise-db` currently supports PostgreSQL and Valkey on Ubuntu-compatible Linux and macOS. The repository is structured so MySQL can be added later without changing the release asset naming scheme.

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
"db:valkey" = "9"
```

Exact versions are also supported:

```toml
[tools]
"db:postgres" = "18.4"
"db:valkey" = "9.1.0"
```

## Supported Tools

- `postgres` - PostgreSQL server and client binaries
- `valkey` - Valkey server and CLI binaries, including Redis-compatible `redis-server` and `redis-cli` names

Planned tools:

- `mysql` - MySQL Community Server / client binaries

## Supported Platforms

Supported targets:

- `linux-amd64`
- `linux-arm64`
- `darwin-amd64`
- `darwin-arm64`

Linux binaries are built and verified on GitHub-hosted Ubuntu runners. Other Linux distributions may work if compatible runtime libraries are available, but are not guaranteed. Windows, Alpine/musl, and MySQL binaries are not supported yet.

## GitHub Release Assets

Database binaries are hosted as GitHub Release assets in this repository.

Release tags use:

```text
<tool>-<version>
```

Example:

```text
postgres-18.4
valkey-9.1.0
```

Assets use:

```text
db-<tool>-<version>-<target>.tar.xz
db-<tool>-<version>-<target>.tar.xz.sha256
```

Examples:

```text
db-postgres-18.4-linux-amd64.tar.xz
db-postgres-18.4-linux-arm64.tar.xz
db-postgres-18.4-darwin-amd64.tar.xz
db-postgres-18.4-darwin-arm64.tar.xz
db-valkey-9.1.0-linux-amd64.tar.xz
```

Archives extract directly into the mise install directory and contain:

```text
bin/
lib/
share/
licenses/
```

## Version Resolution

The plugin lists concrete versions from GitHub Releases by reading tags named:

```text
<tool>-<version>
```

Partial versions resolve to the latest matching concrete version. For example:

```text
postgres 18 -> latest available 18.x
valkey 9    -> latest available 9.x
```

The plugin publishes and installs exact upstream versions only. It does not publish fake major-only versions such as `18`.

## Manual GitHub Actions Builds

Use the `Build database binaries` workflow from the GitHub Actions tab.

The workflow reads tool/version pairs from `ci/matrix.json` and builds each pair for every supported target. Existing complete release assets are skipped.

Use the `Rebuild database binary` workflow to force rebuild and re-upload one tool/version across every supported target.

Local package verification:

```bash
export VERSION=18.4
export TARGET=linux-amd64

ci/postgres.sh package
ci/postgres.sh verify
```

Valkey verification checks both native Valkey command names and Redis-compatible command names:

```bash
export VERSION=9.1.0
export TARGET=linux-amd64

ci/valkey.sh package
ci/valkey.sh verify
```

## Available Versions

| Tool | Versions |
| --- | --- |
| `postgres` | `16.12`, `16.13`, `16.14`, `17.8`, `17.9`, `17.10`, `18.2`, `18.3`, `18.4` |
| `mysql` | Not supported yet |
| `valkey` | `7.2.11`, `7.2.12`, `7.2.13`, `8.1.6`, `8.1.7`, `8.1.8`, `9.0.3`, `9.0.4`, `9.1.0` |
