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

- macOS arm64 (`darwin-arm64`)
- macOS x86_64 (`darwin-amd64`)
- Fedora 43 arm64 (`fedora43-arm64`)
- Fedora 43 x86_64 (`fedora43-amd64`)
- Fedora 44 arm64 (`fedora44-arm64`)
- Fedora 44 x86_64 (`fedora44-amd64`)
- Ubuntu 24.04 LTS arm64 (`ubuntu24-arm64`)
- Ubuntu 24.04 LTS x86_64 (`ubuntu24-amd64`)
- Ubuntu 26.04 LTS arm64 (`ubuntu26-arm64`)
- Ubuntu 26.04 LTS x86_64 (`ubuntu26-amd64`)

## Requirements

### Ubuntu

#### Ubuntu 24.04:

```bash
sudo apt install ca-certificates libaio1t64 libncurses6 libnuma1 libreadline8t64 libxml2 libxslt1.1 openssl xz-utils zlib1g
```

#### Ubuntu 26.04:

```bash
sudo apt install ca-certificates libaio1t64 libncurses6 libnuma1 libreadline8t64 libxml2-16 libxslt1.1 openssl xz-utils zlib1g
```

MySQL on Ubuntu 26.04 also needs a `libaio.so.1` compatibility symlink.

For x86_64:

```bash
sudo ln -s /usr/lib/x86_64-linux-gnu/libaio.so.1t64 /usr/lib/libaio.so.1
```

For arm64:

```bash
sudo ln -s /usr/lib/aarch64-linux-gnu/libaio.so.1t64 /usr/lib/libaio.so.1
```

### Fedora

```bash
sudo dnf install ca-certificates libaio libicu libxml2 libxslt numactl-libs openssl-libs readline tar xz zlib
```

## Available Versions

| Tool       | Versions                   |
| ---------- | -------------------------- |
| `postgres` | `16.14`, `17.10`, `18.4`   |
| `mysql`    | `8.0.46`, `8.4.9`, `9.7.1` |
| `valkey`   | `7.2.13`, `8.1.8`, `9.1.0` |
