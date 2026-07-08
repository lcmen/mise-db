# mise-db

`mise-db` is a [mise](https://mise.jdx.dev/) backend plugin repository. The plugin is installed as `db` and installs prebuilt database binaries.

Phase 1 supports PostgreSQL 18.x on glibc Linux and macOS. The repository is structured so MySQL and Redis-compatible binaries can be added later without changing the release asset naming scheme.

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

Planned tools after phase 1:

- `mysql` - MySQL Community Server / client binaries
- `redis` - Redis-compatible server and CLI binaries

## Supported Platforms

Phase 1 supports:

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

## Private Repository Testing

While the repository is private, export a GitHub token before listing or installing:

```bash
export GH_TOKEN="$(gh auth token)"
```

The token needs read access to `lcmen/mise-db` releases.

## Manual GitHub Actions Builds

Use the `Build Linux database binary` or `Build Darwin database binary` workflow from the GitHub Actions tab.

Run the workflow manually with:

- `tool`: `postgres`
- `version`: exact upstream PostgreSQL 18.x version, for example `18.4`

The workflows build PostgreSQL from source for the supported Linux or macOS targets, package `.tar.xz` archives, generate `.sha256` files, verify them, and upload them to the matching GitHub Release.

## Local Packaging Verification

After a local build has created a prefix directory:

```bash
ci/package.sh postgres 18.4 linux-amd64-gnu "$PWD/prefix" "$PWD/dist"
ci/verify.sh postgres "$PWD/dist/db-postgres-18.4-linux-amd64-gnu.tar.xz"
```
