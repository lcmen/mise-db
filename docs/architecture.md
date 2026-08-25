# Architecture

mise-db is a mise backend plugin for installing prebuilt PostgreSQL, MySQL, and Valkey distributions. GitHub Actions produces platform-specific archives and publishes them as GitHub Release assets; the plugin downloads those assets during `mise install`.

## Plugin flow

The plugin is installed under the public name `db`, so tools are selected as `db:postgres`, `db:mysql`, and `db:valkey`.

- `BackendListVersions` queries releases in `lcmen/mise-db`, accepts stable tags matching `<tool>-<version>`, and returns semantically sorted concrete versions.
- `BackendInstall` derives the current distro/architecture target, finds the matching release asset through the GitHub API, downloads it, and extracts it into the mise install directory.
- `BackendExecEnv` adds the installed `bin/` directory to `PATH`.

`GH_TOKEN` is optional for public releases and is added to GitHub API requests when present. When `MISE_DB_ASSET_DIR` is set, version discovery scans standard archive names in that directory and installation extracts the matching local target asset without contacting GitHub.

## Targets and assets

Targets are declared in `ci/targets.json`. macOS targets encode OS and architecture; Linux targets also encode the distribution release because the produced binaries dynamically link to distro libraries.

Release tags and assets follow these forms:

```text
<tool>-<version>
<tool>-<version>-<target>.tar.xz
<tool>-<version>-<target>.tar.xz.sha256
```

Each archive extracts directly into the install prefix and contains `bin/`, `lib/`, `share/`, and `licenses/` as applicable.

## Build pipeline

`.github/workflows/build.yml` expands `ci/tools.json` across every target. Linux builds run inside the matching Ubuntu or Fedora image on architecture-matched GitHub runners. macOS builds run on native Intel and Apple Silicon runners. Every archive is verified in its target environment before release.

`.github/workflows/rebuild.yml` rebuilds one tool/version for one target or all targets. Tool-specific acquisition, build, packaging, verification, and release logic lives in `ci/tools/`; shared release and platform helpers live in `ci/utils.sh`.
