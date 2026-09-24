# Code conventions

mise-db uses Lua for mise backend hooks and Bash for installed command wrappers and smoke tests. Keep changes small, validate input early, and return errors that tell the user how to recover.

See [Architecture](architecture.md) for component boundaries and [Testing](testing.md) for test workflows.

## Lua

- Target Lua 5.1. StyLua uses four-space indentation and a 120-column limit.
- Use `snake_case` for functions, local variables, and module fields. Use `UPPER_SNAKE_CASE` for constants.
- Reusable libraries use `local M = {}` and finish with `return M`.
- Hooks define mise callbacks on `PLUGIN` and return the table shape required by mise.
- Load project libraries with `dofile(RUNTIME.pluginDirPath .. "/lib/<name>.lua")`. Use `require` for modules supplied by mise, such as `cmd`, `file`, `json`, and `semver`.
- Keep functions small. Prefer explicit arguments over hidden state.
- Add `---@param`, `---@return`, and `---@type` annotations to shared or non-obvious code.
- Quote dynamic shell arguments with `utils.shell_quote` or `utils.shell_quotes`.
- Write progress and diagnostics to stderr. Keep normal output clean.

## Bash

- Use Bash. Executable scripts must enable `set -euo pipefail`. Sourced helpers must be safe under strict mode.
- Use two-space indentation and `snake_case` for functions and local variables.
- Use readonly `UPPER_SNAKE_CASE` names for wrapper constants such as `LIB_DIR`, `INSTALL_DIR`, `CONTAINER`, and `NETWORK`.
- Quote variable expansions. Use arrays for argument lists, `[[ ... ]]` for tests, and `(( ... ))` for arithmetic.
- Validate required arguments at function entry, for example `${1:?container name is required}`.
- Prefer explicit arguments. If a helper reads environment variables, list them in its `Globals:` documentation.
- Document shared helpers with the existing purpose, arguments, output, and return-status blocks.
- Keep functions in `wrappers/lib/*.sh` in alphabetical order.
- Use `printf` for structured output. Send errors and recovery instructions to stderr.
- Use exit status `2` for unsupported command use and `3` when a managed service is stopped or unhealthy. Use `1` for other fatal errors.

ShellCheck disables are allowed for deliberate patterns such as dynamic `source` paths. Keep each disable narrow and documented.

## Runtime adapters

`wrappers/lib/apple.sh` and `wrappers/lib/docker.sh` provide the same adapter functions. When one shared function changes, check whether the matching function in the other adapter also needs to change.

Keep runtime commands in adapter files. Keep shared naming and path logic in `context.sh`. Wrappers may check whether an image exists, but they must not pull it during normal execution.

## Automated checks

Use the repository configuration:

```bash
mise run check
```

This runs Bash syntax checks, ShellCheck, Selene, and StyLua through hk. Use `mise run fix` for supported automatic fixes and `mise run hooks` to install the repository hooks.
