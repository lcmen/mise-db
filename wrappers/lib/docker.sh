#!/usr/bin/env bash

set -euo pipefail

#######################################
# Checks whether the managed container exists.
# Arguments:
#   $1: Container name.
# Returns:
#   0 when the container exists, non-zero otherwise.
#######################################
container_exists() {
  local container="${1:?container name is required}"
  docker container inspect "$container" >/dev/null 2>&1
}

#######################################
# Returns a container's Docker health status.
# Arguments:
#   $1: Container name.
# Outputs:
#   Health status, or "none" when the container has no healthcheck.
# Returns:
#   0 when inspection succeeds, non-zero otherwise.
#######################################
container_health() {
  local container="${1:?container name is required}"
  docker container inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container"
}

#######################################
# Waits until a container's Docker healthcheck reports healthy.
# Arguments:
#   $1: Container name.
#   $2: Timeout in seconds. Defaults to 60.
# Returns:
#   0 when the container is healthy; exits with an error otherwise.
#######################################
container_ready() {
  local container="${1:?container name is required}"
  local timeout="${2:-60}"
  local deadline status
  deadline=$((SECONDS + timeout))

  while true; do
    status="$(container_health "$container" 2>/dev/null || true)"

    case "$status" in
      healthy)
        return 0
        ;;
      unhealthy)
        docker logs "$container" >&2 || true
        echo "Container healthcheck failed: $container" >&2
        exit 1
        ;;
      none)
        echo "Container does not have a healthcheck: $container" >&2
        echo "Remove and recreate the container to add one." >&2
        exit 1
        ;;
    esac

    if (( SECONDS >= deadline )); then
      docker logs "$container" >&2 || true
      echo "Container did not become healthy within ${timeout} seconds: $container" >&2
      exit 1
    fi

    sleep 1
  done
}

#######################################
# Checks whether the managed container is currently running.
# Arguments:
#   $1: Container name.
# Returns:
#   0 when the container is running, non-zero otherwise.
#######################################
container_running() {
  local container="${1:?container name is required}"
  [[ "$(docker container inspect --format '{{.State.Running}}' "$container" 2>/dev/null || true)" == "true" ]]
}

#######################################
# Prints a container's status and returns success only when healthy.
# Arguments:
#   $1: Container name.
#   $2: Display label. Defaults to "Container".
# Returns:
#   0 when the container is running and healthy, 3 otherwise.
#######################################
container_status() {
  local container="${1:?container name is required}"
  local label="${2:-Container}"

  if ! container_exists "$container"; then
    echo "$label container does not exist: $container"
    return 3
  fi

  if ! container_running "$container"; then
    echo "$label container is stopped: $container"
    return 3
  fi

  if [[ "$(container_health "$container")" == "healthy" ]]; then
    echo "$label container is running: $container"
    return 0
  fi

  echo "$label container is running but not healthy: $container"
  return 3
}

#######################################
# Selects container-runtime TTY flags for the current stdin/stdout state.
# Outputs:
#   "-it" for interactive terminal use, otherwise "-i".
# Returns:
#   0.
#######################################
container_tty_args() {
  if [[ -t 0 && -t 1 ]]; then
    printf '%s\n' -it
  else
    printf '%s\n' -i
  fi
}

#######################################
# Verifies that an image is available locally.
# Arguments:
#   $1: Docker image reference.
# Returns:
#   0 when the image exists; exits with an error otherwise.
#######################################
ensure_image() {
  local image="${1:?Docker image is required}"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "Docker image is missing: $image" >&2
    echo "Run mise install to pull it again." >&2
    exit 1
  fi
}

#######################################
# Ensures the shared Docker network exists.
# Arguments:
#   $1: Network name.
# Returns:
#   0 after the network exists.
#######################################
ensure_network() {
  local network="${1:?network name is required}"
  if ! docker network inspect "$network" >/dev/null 2>&1; then
    docker network create "$network" >/dev/null
  fi
}

#######################################
# Verifies the selected adapter is Docker and that its CLI and daemon are available.
# Returns:
#   0 when Docker is usable; exits with an error otherwise.
#######################################
require_adapter() {
  if [[ -n "${MISE_DB_ADAPTER:-}" && "$MISE_DB_ADAPTER" != "$ADAPTER" ]]; then
    echo "mise-db install uses adapter $ADAPTER, but MISE_DB_ADAPTER requests $MISE_DB_ADAPTER." >&2
    echo "Update mise config, then run mise install --force db:postgres@$VERSION to reinstall with the intended adapter." >&2
    exit 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required for this mise-db installation." >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "Docker is installed but the daemon is not available." >&2
    exit 1
  fi
}
