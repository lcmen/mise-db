# Architecture

## Overview

mise-db is a mise backend plugin. It installs versioned command wrappers that run database tools from OCI images.

The main responsibilities are split between three systems:

- mise selects versions, installs files, and activates the tool environment.
- mise-db translates mise actions into tool and runtime operations.
- the container runtime stores images and runs containers.

## Main Components

The Lua code handles mise integration:

- `hooks/` contains the mise backend entry points.
- `lib/utils.lua` validates tool names and provides shared behavior.
- Each supported tool has a module in `lib/`. A tool module defines its image, commands, available versions, and activation environment.
- `lib/registry.lua` discovers versions from an image registry.
- `lib/cache.lua` caches registry responses to avoid repeated network requests.

The shell code handles installed commands:

- `wrappers/` contains one main wrapper for each tool.
- `wrappers/lib/context.sh` creates stable names and data paths.
- Runtime adapter files translate common wrapper operations into commands for Docker or Apple Container.

## Mise Lifecycle

### Version discovery

The version-list hook loads the requested tool module. The tool module asks the registry layer for image tags, filters them into supported concrete versions, and returns them to mise in version order. Mutable major-only image tags are not exposed. A major selector therefore resolves to an exact release, and `mise upgrade` can detect when that resolved release changes.

Registry responses are cached for a limited time. Users can bypass the cache when they need fresh registry data.

### Installation

The install hook:

1. Loads and validates the requested tool.
2. Validates the globally configured container runtime.
3. Pulls the selected image.
4. Copies the wrapper and its support files into the mise install directory.
5. Creates command links in the install `bin/` directory.

Installed wrappers are self-contained. They use copies inside the versioned mise installation and do not link back to the plugin checkout.

### Activation

The environment hook validates and resolves the service name, adds the install `bin/` directory to `PATH`, and exports the resolved version, exact image, and name through underscore-prefixed, service-specific variables reserved for mise-db's wrappers. There is no per-installation manifest.

Activation prepares commands for use. It does not start a server.

## Wrapper Runtime

All command links for a tool point to the same wrapper. The wrapper checks the name used to call it and dispatches to the matching behavior.

At startup, the wrapper:

1. Finds its versioned install directory.
2. Validates activation-provided version, image, and name.
3. Loads shared context helpers.
4. Loads the runtime adapter named by the global `MISE_DB_ADAPTER` setting.

Wrappers manage persistent server containers and short-lived client containers. Before an operation uses the runtime or image, it checks that they are available. Wrappers do not pull missing images during normal command execution. A missing image causes a clear error so the user can reinstall or pull it again.

## Runtime Adapters

Docker and Apple Container use different command-line interfaces. Adapter files hide those differences behind a shared set of shell functions for operations such as:

- creating, starting, stopping, and removing containers;
- inspecting container state;
- running commands and following logs;
- creating the shared network;
- checking local images and runtime availability.

The wrapper calls this common interface instead of calling a runtime directly. `MISE_DB_ADAPTER` must globally select `apple` or `docker`. Installation and execution use that same explicit setting; adapters are never auto-detected. Changing it requires stopping services through the old runtime, updating the setting, force-reinstalling tools to pull their images into the new runtime, and starting them again. mise-db does not coordinate containers left running across runtimes.

## Identity, Storage, and Names

mise-db creates deterministic container and storage identities.

The container name follows this form:

```text
mise-db-<tool>-<version>-<name>
```

All managed containers for one runtime use the shared `mise-db` network.

Persistent data is stored outside the mise install directory:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/mise-db/<tool>/<version>/<name>
```

Missing and empty name options resolve to `global`. Explicit names must match `[a-z0-9]+(-[a-z0-9]+)*`. Each service resolves its own option, so PostgreSQL and Redis can use different names in one environment. Project paths do not influence identity.

Removing a container or uninstalling a mise tool must not remove its persistent data.

## Extension Boundaries

Adding another database tool normally requires:

- a tool module with image, command, version, and environment definitions;
- a wrapper for its server and client behavior;
- registration in the supported tool list.

Shared registry, cache, install, context, and adapter code should be reused where their behavior is truly common.

Runtime adapter functions may still contain assumptions from the currently implemented tool. Review those assumptions before reusing an operation for a new database.

mise-db does not own container runtime internals, automatic host DNS setup, data deletion, application migrations, or native database binary publishing.
