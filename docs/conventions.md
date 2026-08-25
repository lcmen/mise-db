# Code conventions

mise-db uses Lua for mise backend hooks and Bash for build, release, and smoke-test scripts.

## Lua

- Target Lua 5.1 and format with StyLua.
- Use `snake_case` for functions, local variables, and module fields.
- Load project libraries with `dofile(RUNTIME.pluginDirPath .. "/lib/<name>.lua")`.
- Use `require` only for modules supplied by mise.
- Validate user-controlled tool names before network or filesystem operations.
- Quote dynamic shell arguments with `utils.shell_quote`.
- Return actionable errors that identify the failed release, asset, or platform.

## Bash

- Enable `set -euo pipefail` in executable scripts.
- Use two-space indentation, quoted expansions, arrays for argument lists, and `[[ ... ]]` for tests.
- Validate required arguments at function entry.
- Keep shared platform/release behavior in `ci/utils.sh` and tool-specific behavior in `ci/tools/<tool>.sh`.
- Make verification inspect archive contents, executable permissions, linked libraries, and a lightweight version command.
- Send errors to stderr and use exit status `2` for invalid command usage.

ShellCheck disables should be narrow and documented.

## Automated checks

```bash
mise run check
mise run fix
```

The check task runs Bash syntax checks, ShellCheck, Selene, and StyLua through hk.
