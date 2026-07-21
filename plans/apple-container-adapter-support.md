# Apple Container Adapter Support

## Summary

Add `docker` and `apple` runtime adapters, selected during installation by
`MISE_DB_ADAPTER` or automatic runtime detection. Persist the resolved adapter
as `ADAPTER` in each install manifest. Wrappers must reject a conflicting
`MISE_DB_ADAPTER` and instruct the user to force-reinstall the tool.

## Implementation Changes

- Add shared adapter resolution/validation for `docker|apple`; an unset value
  prefers a usable Apple `container` runtime, then a usable Docker runtime.
  Invalid or explicitly unavailable adapters fail clearly.
- Update `BackendInstall` to resolve the adapter, validate its service, pull
  via `docker pull` or `container image pull`, and write
  `ADAPTER=<resolved adapter>` to the manifest.
- Rename Docker-specific helper APIs to adapter-neutral names (`require_adapter`,
  `adapter_tty_args`) and refactor the PostgreSQL wrapper to source
  `lib/docker.sh` or new `lib/apple.sh` from the manifest adapter.
- In `require_adapter`, compare a non-empty `MISE_DB_ADAPTER` with manifest
  `ADAPTER` before invoking either runtime. On mismatch, fail with an error
  naming both adapters and direct the user to run
  `mise install --force db:postgres@<version>` with the intended
  `MISE_DB_ADAPTER`.
- Make the wrapper use a common lifecycle API for image checks, network
  creation, container creation/start/stop/removal, execution, logs, and client
  runs; no direct runtime CLI calls remain in `wrappers/postgres`.
- Implement `wrappers/lib/apple.sh` with the same helper interface as Docker,
  mapped to Apple `container` commands and the shared `mise-db` network.
- Preserve Docker healthchecks. For Apple Container, implement readiness and
  healthy status by polling `pg_isready` through `container exec`; report status
  success only when the container is running and PostgreSQL accepts connections.
- Preserve persistent data paths, deterministic names, client working-directory
  mounts, credentials, lifecycle semantics, and the no-pull-during-wrapper-
  execution rule.

## Documentation

- Update README requirements, runtime details, configuration examples,
  adapter-mismatch/reinstall guidance, and limitations for Docker and Apple
  Container.
- Document `MISE_DB_ADAPTER=docker|apple`, auto-selection precedence during
  install, Apple Container's macOS 26+/Apple-silicon requirement, and manual
  Apple DNS setup for hostname-based `PGHOST`.
- Update AGENTS.md current state, runtime model, repository structure, helper
  naming/sorting rules, test commands, and future-work list to reflect
  completed Apple adapter support.

## Test Plan

- Adapt `tests/helpers.sh` and `tests/postgres.test.sh` to run the PostgreSQL
  lifecycle smoke flow independently with `MISE_DB_ADAPTER=docker` and
  `MISE_DB_ADAPTER=apple`.
- For each adapter: pull/check the image with that adapter, create an
  adapter-specific manifest, start PostgreSQL, verify healthy status, run
  `select 1 as ok`, stop/remove the container, and preserve test cleanup.
- Add coverage that a wrapper rejects `MISE_DB_ADAPTER` when it differs from
  manifest `ADAPTER`, including the forced-reinstall instruction.
- Run shell syntax and ShellCheck against both adapter libraries and revised
  tests.
- Run `tests/postgres.test.sh` after Apple Container is installed and its
  system service has been started; its default execution covers both runtimes.

## Assumptions

- Public adapter values are exactly `docker` and `apple`.
- `MISE_DB_ADAPTER` controls the adapter selected at installation; installed
  wrappers use manifest `ADAPTER` and only inspect the variable to reject
  mismatches.
- Apple DNS remains opt-in and documented only; wrappers never invoke
  privileged `container system dns` commands.
