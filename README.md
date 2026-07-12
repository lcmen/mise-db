# mise-db

`mise-db` is a [mise](https://mise.jdx.dev/) backend plugin repository. The plugin is installed as `db` and installs prebuilt database binaries.

`mise-db` currently supports PostgreSQL, MySQL, and Valkey on distro-specific Linux targets and macOS.

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
"db:mysql" = "9"
"db:valkey" = "9"
```

Exact versions are also supported:

```toml
[tools]
"db:postgres" = "18.4"
"db:mysql" = "9.7.1"
"db:valkey" = "9.1.0"
```

## Supported Tools

- `postgres` - PostgreSQL server and client binaries
- `mysql` - MySQL Community Server and client binaries
- `valkey` - Valkey server and CLI binaries, including Redis-compatible `redis-server` and `redis-cli` names

## Supported Platforms

Supported platforms:

- Ubuntu 24.04 LTS x86_64 (`ubuntu24-amd64`)
- Ubuntu 24.04 LTS arm64 (`ubuntu24-arm64`)
- Ubuntu 26.04 LTS x86_64 (`ubuntu26-amd64`)
- Ubuntu 26.04 LTS arm64 (`ubuntu26-arm64`)
- Fedora 43 x86_64 (`fedora43-amd64`)
- Fedora 43 arm64 (`fedora43-arm64`)
- Fedora 44 x86_64 (`fedora44-amd64`)
- Fedora 44 arm64 (`fedora44-arm64`)
- macOS x86_64 (`darwin-amd64`)
- macOS arm64 (`darwin-arm64`)

Linux binaries are built and verified for the specific distro release named in the asset. Other Linux distributions are unsupported in v0.1. Arch Linux is intentionally excluded because it is a rolling release, and Ubuntu interim releases such as 25.x are unsupported unless dedicated artifacts are added. Windows and Alpine/musl are not supported yet.

## GitHub Release Assets

Database binaries are hosted as GitHub Release assets in this repository.

Release tags use:

```text
<tool>-<version>
```

Example:

```text
postgres-18.4
mysql-9.7.1
valkey-9.1.0
```

Assets use:

```text
<tool>-<version>-<target>.tar.xz
<tool>-<version>-<target>.tar.xz.sha256
```

Examples:

```text
postgres-18.4-ubuntu24-amd64.tar.xz
postgres-18.4-ubuntu24-arm64.tar.xz
postgres-18.4-ubuntu26-amd64.tar.xz
postgres-18.4-ubuntu26-arm64.tar.xz
postgres-18.4-fedora43-amd64.tar.xz
postgres-18.4-fedora43-arm64.tar.xz
postgres-18.4-fedora44-amd64.tar.xz
postgres-18.4-fedora44-arm64.tar.xz
postgres-18.4-darwin-amd64.tar.xz
postgres-18.4-darwin-arm64.tar.xz
mysql-9.7.1-ubuntu24-amd64.tar.xz
mysql-9.7.1-ubuntu24-arm64.tar.xz
valkey-9.1.0-fedora44-amd64.tar.xz
valkey-9.1.0-fedora44-arm64.tar.xz
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
mysql 9    -> latest available 9.x
valkey 9    -> latest available 9.x
```

The plugin publishes and installs exact upstream versions only. It does not publish fake major-only versions such as `18`.

## Manual GitHub Actions Builds

Use the `Build database binaries` workflow from the GitHub Actions tab.

The workflow reads tool/version pairs from `ci/tools.json` and supported targets from `ci/targets.json`. Linux builds run inside the matching distro container. Existing complete release assets are skipped.

Use the `Rebuild database binary` workflow to force rebuild and re-upload one tool/version across every supported target.

Local package verification:

```bash
export VERSION=18.4
export TARGET=ubuntu24-amd64

ci/tools/postgres.sh package
ci/tools/postgres.sh verify
```

Valkey verification checks both native Valkey command names and Redis-compatible command names:

```bash
export VERSION=9.1.0
export TARGET=fedora44-amd64

ci/tools/valkey.sh package
ci/tools/valkey.sh verify
```

MySQL is repackaged from official MySQL Community generic archives:

```bash
export VERSION=9.7.1
export TARGET=ubuntu24-amd64

ci/tools/mysql.sh build
ci/tools/mysql.sh package
ci/tools/mysql.sh verify
```

## Available Versions

| Tool | Versions |
| --- | --- |
| `postgres` | `16.14`, `17.10`, `18.4` |
| `mysql` | `8.0.46`, `8.4.9`, `9.7.1` |
| `valkey` | `7.2.13`, `8.1.8`, `9.1.0` |
