#!/usr/bin/env bash

set -euo pipefail

#######################################
# Creates a managed container with a healthcheck.
# Arguments:
#   $1: Health command.
#   Remaining arguments: Arguments passed to docker create.
# Returns:
#   The Docker create command's exit status.
#######################################
container_create() {
  local health_cmd="${1:?health command is required}"
  shift

  log_debug "Creating Docker container"
  docker create \
    --health-cmd "$health_cmd" \
    --health-interval 1s \
    --health-timeout 5s \
    --health-retries 60 \
    "$@"
}

#######################################
# Deletes the managed container.
# Arguments:
#   $1: Container name.
# Returns:
#   The Docker remove command's exit status.
#######################################
container_delete() {
  local container="${1:?container name is required}"
  log_debug "Deleting Docker container: $container"
  docker rm "$container"
}

#######################################
# Executes a command in the managed container.
# Arguments:
#   $1: Container name.
#   Remaining arguments: Command and arguments to execute.
# Returns:
#   The Docker exec command's exit status.
#######################################
container_exec() {
  local container="${1:?container name is required}"
  shift

  log_debug "Executing a command in Docker container: $container"
  docker exec "$container" "$@"
}

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
# Returns the managed container's client connection host.
# Arguments:
#   $1: Container name.
# Outputs:
#   Container name.
# Returns:
#   0.
#######################################
container_host() {
  printf '%s\n' "${1:?container name is required}"
}

#######################################
# Follows logs from the managed container.
# Arguments:
#   $1: Container name.
# Returns:
#   The Docker logs command's exit status.
#######################################
container_logs() {
  docker logs --follow "${1:?container name is required}"
}

#######################################
# Waits until a container's Docker healthcheck reports healthy.
# Arguments:
#   $1: Container name.
#   $2: Timeout in seconds. Defaults to 60.
#   Remaining arguments: Readiness command, used by polling adapters.
# Returns:
#   0 when the container is healthy; exits with an error otherwise.
#######################################
container_ready() {
  local container="${1:?container name is required}"
  local timeout="${2:-60}"
  shift 2 || true
  local deadline status
  deadline=$((SECONDS + timeout))
  log_debug "Waiting up to ${timeout} seconds for Docker healthcheck in $container"

  while true; do
    status="$(container_health "$container" 2>/dev/null || true)"

    case "$status" in
      healthy)
        log_debug "Docker container is healthy: $container"
        return 0
        ;;
      unhealthy)
        docker logs "$container" >&2 || true
        log_error "Container healthcheck failed: $container"
        exit 1
        ;;
      none)
        log_error "Container does not have a healthcheck: $container"
        log_error "Remove and recreate the container to add one"
        exit 1
        ;;
    esac

    if (( SECONDS >= deadline )); then
      docker logs "$container" >&2 || true
      log_error "Container did not become healthy within ${timeout} seconds: $container"
      exit 1
    fi

    sleep 1
  done
}

#######################################
# Runs a command in a new Docker container.
# Arguments:
#   All arguments: Arguments passed to docker run.
# Returns:
#   The Docker run command's exit status.
#######################################
container_run() {
  log_debug "Running a short-lived Docker container"
  docker run "$@"
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
# Starts the managed container.
# Arguments:
#   $1: Container name.
# Returns:
#   The Docker start command's exit status.
#######################################
container_start() {
  local container="${1:?container name is required}"
  log_debug "Starting Docker container: $container"
  docker start "$container"
}

#######################################
# Prints a container's status and returns success only when healthy.
# Arguments:
#   $1: Container name.
#   $2: Display label. Defaults to "Container".
#   Remaining arguments: Readiness command, used by polling adapters.
# Returns:
#   0 when the container is running and healthy, 3 otherwise.
#######################################
container_status() {
  local container="${1:?container name is required}"
  local label="${2:-Container}"
  shift 2 || true

  if ! container_exists "$container"; then
    log_status "$label container does not exist: $container"
    return 3
  fi

  if ! container_running "$container"; then
    log_status "$label container is stopped: $container"
    return 3
  fi

  if [[ "$(container_health "$container")" == "healthy" ]]; then
    log_status "$label container is running: $container"
    return 0
  fi

  log_status "$label container is running but not healthy: $container"
  return 3
}

#######################################
# Stops the managed container.
# Arguments:
#   $1: Container name.
# Returns:
#   The Docker stop command's exit status.
#######################################
container_stop() {
  local container="${1:?container name is required}"
  log_debug "Stopping Docker container: $container"
  docker stop "$container"
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
#   $1: Docker image reference.
# Returns:
#   0 when the image exists; exits with an error otherwise.
#######################################
ensure_image() {
  local image="${1:?Docker image is required}"
  log_debug "Checking Docker image: $image"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    log_error "Docker image is missing: $image"
    log_error "Run mise install to pull it again"
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
    log_debug "Creating Docker network: $network"
    docker network create "$network" >/dev/null
  else
    log_debug "Docker network already exists: $network"
  fi
}

#######################################
# Verifies the selected adapter is Docker and that its CLI and daemon are available.
# Returns:
#   0 when Docker is usable; exits with an error otherwise.
#######################################
require_adapter() {
  log_debug "Validating Docker adapter"
  if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is required for this mise-db installation"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    log_error "Docker is installed but the daemon is not available"
    exit 1
  fi
  log_debug "Docker adapter is available"
}
