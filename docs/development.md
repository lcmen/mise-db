# Development

This guide explains the normal workflow for changing mise-db. Read [Architecture](architecture.md) before changing component boundaries and [Code conventions](conventions.md) before writing code.

## Set up the repository

Install the tools declared in `mise.toml`:

```bash
mise install
```

Link this checkout as the `mise-db` plugin:

```bash
mise plugin link mise-db /path/to/mise-db
```

You also need `MISE_DB_ADAPTER` set globally to `docker` or `apple`, with that runtime's service running.
mise-db does not auto-detect a runtime. When changing adapters, stop services through the old adapter, update the global setting, force-reinstall configured tools, and then start them through the new adapter.

## Make a change

Keep each change in the layer that owns the behavior:

- `hooks/` contains mise backend entry points.
- `lib/` contains shared Lua code and service definitions.
- `wrappers/` contains installed commands and runtime adapters.
- `tests/` contains fixtures, helpers, and smoke tests.

Keep shared code independent of a specific service when the behavior is truly common. Put database commands, environment variables, image rules, and readiness behavior in the service implementation.

Installed wrappers must work without the plugin checkout. Test the copied install layout, not paths into the repository.
They receive resolved version, image, and name from mise activation rather than an installation manifest.

## Add a service

Public service names are `postgres`, `redis`, and `mysql`. PostgreSQL and Redis are implemented; MySQL is planned.

To add a service:

1. Add its public name to the supported tool list.
2. Add a Lua service module with its commands, image rules, version discovery, and activation environment.
3. Add a multi-call wrapper for its server lifecycle and client commands.
4. Reuse the activation state, instance naming, data directory, and global adapter model.
5. Extend both runtime adapters where the service needs different behavior.
6. Add registry fixtures and a smoke test for both adapters.
7. Add `docs/services/<service>.md` with service-specific behavior and limitations.

Do not make an adapter helper look generic if it contains service-specific readiness logic. A clear service-specific helper is easier to maintain.

## Verify the change

Run all format, lint, and syntax checks:

```bash
mise run check
```

Use automatic fixes when needed:

```bash
mise run fix
```

Run the smoke test for each affected service:

```bash
tests/postgres.test.sh
tests/redis.test.sh
```

Check the output to confirm that every required adapter ran. The script skips adapters that are not available.

Before finishing:

- verify new errors explain how the user can recover;
- verify normal wrapper execution does not pull images;
- verify stop and uninstall behavior does not delete persistent data;
- update the relevant documentation when behavior changes.

See [Testing](testing.md) for the test harness and test-writing rules.
