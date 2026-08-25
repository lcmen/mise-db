# Development

## Setup

Install the development tools:

```bash
mise install
```

Link the checkout using the public plugin name:

```bash
mise plugin link db /path/to/mise-db
```

You can then inspect versions or test an install:

```bash
mise ls-remote db:postgres
mise install db:postgres@18.6
mise exec db:postgres@18.6 -- postgres --version
```

Set `GH_TOKEN` if GitHub API rate limits or private-release access require authentication.

To test an archive before publishing it, put it in a directory using the standard asset name and select that directory:

```bash
MISE_DB_ASSET_DIR=/path/to/dist mise install db:postgres@18.6
```

With this variable set, `mise ls-remote` also discovers versions from archive filenames in that directory.

## Change a published tool version

Add or update the concrete tool/version object in `ci/tools.json`. Do not add partial versions such as `18`; mise resolves those selectors from the concrete release list.

Build behavior belongs in `ci/tools/<tool>.sh`. It must support `build`, `package`, `verify`, and `release`, create the standard archive layout, include upstream licenses, verify required executables and linked libraries, and publish both the archive and checksum.

Targets belong in `ci/targets.json`. A new Linux target needs a GitHub runner with the matching architecture, a distro container image, dependency setup in `ci/provision/linux.sh`, and corresponding runtime requirements in the README.

Use the full build workflow for the declared matrix. Use the rebuild workflow for a single version or target.

## Validation

Run static checks after every change:

```bash
mise run check
```

Run the binary smoke tests for changes to hooks, assets, or archive layout:

```bash
mise run test
```

The smoke tests use local release assets through `MISE_DB_ASSET_DIR`. See [Testing](testing.md) for individual commands.
