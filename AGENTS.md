# mise-db contributor guide

mise-db is a [mise](https://mise.jdx.dev/) backend plugin that installs prebuilt database binaries from GitHub Releases.

Start with the document that matches your work:

- [Architecture](docs/architecture.md): plugin hooks, release assets, and build targets.
- [Development](docs/development.md): local setup and release-matrix changes.
- [Code conventions](docs/conventions.md): Lua and Bash style.
- [Testing](docs/testing.md): checks and binary smoke tests.

Keep these project rules:

- The public plugin name is `db`; tools are `postgres`, `mysql`, and `valkey`.
- Release tags use `<tool>-<version>`.
- Assets use `<tool>-<version>-<target>.tar.xz` plus a SHA-256 file.
- Supported targets are macOS arm64/x86_64 and the Ubuntu/Fedora targets in `ci/targets.json`.
- Do not commit generated binaries. Build and publish them with GitHub Actions.
- Archives must extract directly into a mise install and expose executables under `bin/`.
- Version discovery must return concrete upstream versions; mise resolves partial selectors.

Before submitting a change, install the current development tools and run:

```bash
mise run check
```

Run `mise run test` when plugin installation, version discovery, archive layout, or release assets change.
