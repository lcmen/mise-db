# Testing

mise-db has static checks and end-to-end plugin smoke tests against local release assets.

## Static checks

Install the development toolchain and run all configured checks:

```bash
mise install
mise run check
```

This validates Bash syntax and style plus Lua linting and formatting.

## Binary smoke tests

Run every service test:

```bash
mise run test
```

Or run one directly:

```bash
tests/postgres.test.sh
tests/mysql.test.sh
tests/valkey.test.sh
```

Each test creates isolated mise data, cache, config, and state directories under `/tmp`; links the checkout as the `db` plugin; packages stub executables using a version from `ci/tools.json`; and points `MISE_DB_ASSET_DIR` at that archive. It then:

1. Confirms the concrete version appears in `mise ls-remote`.
2. Confirms a partial selector resolves to that version.
3. Installs the matching release asset for the current platform.
4. Checks the archive's required public executables.
5. Runs a lightweight version command from the installed tool.

The tests require `mise` and `tar` with xz support. They do not require network access, initialize database servers, or retain their temporary mise directories.

When adding a tool, create `tests/<tool>.test.sh`. Assert the archive's documented command set and execute at least one fixture binary through `mise exec`. The build workflows separately verify real upstream binaries inside every target environment.
