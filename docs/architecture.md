# Architecture

mise-db is a mise backend plugin for installing prebuilt PostgreSQL, MySQL, and Valkey distributions. GitHub Actions produces platform-specific archives and publishes them as GitHub Release assets; the plugin downloads those assets during `mise install`.

## Plugin flow

The plugin is installed under the public name `db`, so tools are selected as `db:postgres`, `db:mysql`, and `db:valkey`.

- `BackendListVersions` queries releases in `lcmen/mise-db`, accepts stable tags matching `<tool>-<version>`, and returns semantically sorted concrete versions.
- `BackendInstall` derives the current distro/architecture target, finds the matching release asset through the GitHub API, downloads it, and extracts it into the mise install directory.
- `BackendExecEnv` adds the installed `bin/` directory to `PATH`.

`GH_TOKEN` is optional for public releases and is added to GitHub API requests when present. When `MISE_DB_ASSET_DIR` is set, version discovery scans standard archive names in that directory and installation extracts the matching local target asset without contacting GitHub. The installer makes files writable by the current user and marks files under `bin/` executable after extraction.

## Targets and assets

Targets are declared in `ci/targets.json`. macOS targets encode OS and architecture; Linux targets also encode the distribution release because the produced binaries dynamically link to distro libraries.

Release tags and assets follow these forms:

```text
<tool>-<version>
<tool>-<version>-<target>.tar.xz
<tool>-<version>-<target>.tar.xz.sha256
```

Each archive extracts directly into the install prefix and contains `bin/`, `lib/`, `share/`, and `licenses/` as applicable. A checksum file is published beside every archive; the build pipeline uses the archive and checksum pair to decide whether a target is already complete.

## Version matrix

`ci/tools.json` is the source of truth for versions built by the full workflow. It contains concrete upstream versions because mise resolves partial selectors from published release tags. The matrix tracks supported upstream release lines rather than every historical version. MySQL versions can use either semantic versioning or the `YY.M.P` calendar versioning introduced with MySQL 26.7.

## Build pipeline

`.github/workflows/build.yml` expands `ci/tools.json` across every target. Linux builds run inside the matching Ubuntu or Fedora image on architecture-matched GitHub runners. macOS builds run on native Intel and Apple Silicon runners. Every archive is verified in its target environment before release.

The full workflow skips a target when both its archive and checksum already exist. `.github/workflows/rebuild.yml` rebuilds one tool/version for one target or all targets and replaces matching release assets. Tool-specific acquisition, build, packaging, verification, and release logic lives in `ci/tools/`; shared release and platform helpers live in `ci/utils.sh`.
