#!/usr/bin/env bash

set -euo pipefail

#######################################
# Creates a managed container.
# Arguments:
#   $1: Health command, unused by Apple Container.
#   Remaining arguments: Arguments passed to container create.
# Returns:
#   The Apple Container create command's exit status.
#######################################
container_create() {
  : "${1:?health command is required}"
  shift

  container create "$@"
}

#######################################
# Deletes the managed container.
# Arguments:
#   $1: Container name.
# Returns:
#   The Apple Container delete command's exit status.
#######################################
container_delete() {
  container delete "${1:?container name is required}"
}

#######################################
# Executes a command in the managed container.
# Arguments:
#   $1: Container name.
#   Remaining arguments: Command and arguments to execute.
# Returns:
#   The Apple Container exec command's exit status.
#######################################
container_exec() {
  local managed_container="${1:?container name is required}"
  shift

  container exec "$managed_container" "$@"
}

#######################################
# Checks whether the managed container exists.
# Arguments:
#   $1: Container name.
# Returns:
#   0 when the container exists, non-zero otherwise.
#######################################
container_exists() {
  container inspect "${1:?container name is required}" >/dev/null 2>&1
}

#######################################
# Returns the managed container's client connection host.
# Arguments:
#   $1: Container name.
# Outputs:
#   IPv4 address without its CIDR suffix.
# Returns:
#   0 when an IPv4 address is available; exits with an error otherwise.
#######################################
container_host() {
  container_ip "${1:?container name is required}"
}

#######################################
# Returns the managed container's IPv4 address on its attached network.
# Arguments:
#   $1: Container name.
# Outputs:
#   IPv4 address without its CIDR suffix.
# Returns:
#   0 when an IPv4 address is available; exits with an error otherwise.
#######################################
container_ip() {
  local managed_container="${1:?container name is required}"
  local address

  address="$(container inspect "$managed_container" 2>/dev/null | sed -nE 's/.*"ipv4Address"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n 1)"
  address="$(printf '%s' "$address" | tr -d '\134')"
  address="${address%%/*}"

  if [[ -z "$address" ]]; then
    echo "Apple Container has no IPv4 address: $managed_container" >&2
    exit 1
  fi

  printf '%s\n' "$address"
}

#######################################
# Follows logs from the managed container.
# Arguments:
#   $1: Container name.
# Returns:
#   The Apple Container logs command's exit status.
#######################################
container_logs() {
  container logs --follow "${1:?container name is required}"
}

#######################################
# Waits until PostgreSQL accepts connections inside the managed container.
# Arguments:
#   $1: Container name.
#   $2: Timeout in seconds. Defaults to 60.
#   $3: PostgreSQL user. Defaults to postgres.
# Returns:
#   0 when PostgreSQL is ready; exits with an error otherwise.
#######################################
container_ready() {
  local managed_container="${1:?container name is required}"
  local timeout="${2:-60}"
  local user="${3:-postgres}"
  local deadline
  deadline=$((SECONDS + timeout))

  while true; do
    if container_running "$managed_container" && container exec "$managed_container" pg_isready -U "$user" >/dev/null 2>&1; then
      return 0
    fi

    if (( SECONDS >= deadline )); then
      container logs "$managed_container" >&2 || true
      echo "PostgreSQL did not become ready within ${timeout} seconds: $managed_container" >&2
      exit 1
    fi

    sleep 1
  done
}

#######################################
# Runs a command in a new Apple Container container.
# Arguments:
#   All arguments: Arguments passed to container run.
# Returns:
#   The Apple Container run command's exit status.
#######################################
container_run() {
  container run "$@"
}

#######################################
# Checks whether the managed container is currently running.
# Arguments:
#   $1: Container name.
# Returns:
#   0 when the container is running, non-zero otherwise.
#######################################
container_running() {
  container inspect "${1:?container name is required}" 2>/dev/null | grep -Eq '"state"[[:space:]]*:[[:space:]]*"running"'
}

#######################################
# Starts the managed container.
# Arguments:
#   $1: Container name.
# Returns:
#   The Apple Container start command's exit status.
#######################################
container_start() {
  container start "${1:?container name is required}"
}

#######################################
# Prints a container's status and returns success only when PostgreSQL is ready.
# Arguments:
#   $1: Container name.
#   $2: Display label. Defaults to "Container".
#   $3: PostgreSQL user. Defaults to postgres.
# Returns:
#   0 when the container is running and PostgreSQL is ready, 3 otherwise.
#######################################
container_status() {
  local managed_container="${1:?container name is required}"
  local label="${2:-Container}"
  local user="${3:-postgres}"

  if ! container_exists "$managed_container"; then
    echo "$label container does not exist: $managed_container"
    return 3
  fi

  if ! container_running "$managed_container"; then
    echo "$label container is stopped: $managed_container"
    return 3
  fi

  if container exec "$managed_container" pg_isready -U "$user" >/dev/null 2>&1; then
    echo "$label container is running: $managed_container"
    return 0
  fi

  echo "$label container is running but PostgreSQL is not ready: $managed_container"
  return 3
}

#######################################
# Stops the managed container.
# Arguments:
#   $1: Container name.
# Returns:
#   The Apple Container stop command's exit status.
#######################################
container_stop() {
  container stop "${1:?container name is required}"
}

#######################################
# Selects container-runtime TTY flags for the current stdin/stdout state.
# Outputs:
#   "-it" for interactive terminal use, otherwise "-i".
# Returns:
#   0.
#######################################
container_tty_args() {
  if [[ -t 0 ]]; then
    printf '%s' -it
  else
    printf '%s' -i
  fi
}

#######################################
# Verifies that an image is available locally.
# Arguments:
#   $1: Apple Container image reference.
# Returns:
#   0 when the image exists; exits with an error otherwise.
#######################################
ensure_image() {
  local image="${1:?image is required}"
  if ! container image inspect "$image" >/dev/null 2>&1; then
    echo "Apple Container image is missing: $image" >&2
    echo "Run mise install to pull it again." >&2
    exit 1
  fi
}

#######################################
# Ensures the shared Apple Container network exists.
# Arguments:
#   $1: Network name.
# Returns:
#   0 after the network exists.
#######################################
ensure_network() {
  local network="${1:?network name is required}"
  if ! container network inspect "$network" >/dev/null 2>&1; then
    container network create "$network" >/dev/null
  fi
}

#######################################
# Verifies the selected adapter is Apple Container and its service is available.
# Returns:
#   0 when Apple Container is usable; exits with an error otherwise.
#######################################
require_adapter() {
  if [[ -n "${MISE_DB_ADAPTER:-}" && "$MISE_DB_ADAPTER" != "$ADAPTER" ]]; then
    echo "mise-db install uses adapter $ADAPTER, but MISE_DB_ADAPTER requests $MISE_DB_ADAPTER." >&2
    echo "Update mise config, then run mise install --force db:postgres@$VERSION to reinstall with the intended adapter." >&2
    exit 1
  fi

  if ! command -v container >/dev/null 2>&1; then
    echo "Apple Container is required for this mise-db installation." >&2
    exit 1
  fi
  if ! container system status >/dev/null 2>&1; then
    echo "Apple Container is installed but its system service is not available." >&2
    echo "Run container system start, then try again." >&2
    exit 1
  fi
}
