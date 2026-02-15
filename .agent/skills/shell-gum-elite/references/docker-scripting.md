# Docker Scripting Patterns

## Objective

Patterns for Bash scripts that **orchestrate Docker** — building images, running
containers, polling health, mounting volumes — with Gum UX for interactive
feedback and CI-safe fallbacks.

> This reference is about **scripting around Docker**, not writing Dockerfiles.

## Build with Progress Feedback

```bash
docker_build() {
  local tag="${1:?Usage: docker_build TAG [CONTEXT]}"
  local context="${2:-.}"

  require_cmd docker
  require_file "${context}/Dockerfile"

  adaptive_spin "Building image ${tag}..." \
    docker build --tag "${tag}" "${context}"

  log_info "Image built: ${tag}"
}
```

### Multi-stage target selection

```bash
docker_build_target() {
  local tag="$1" target="$2" context="${3:-.}"

  docker build \
    --tag "${tag}" \
    --target "${target}" \
    --build-arg "BUILD_DATE=$(date -Iseconds)" \
    --build-arg "VERSION=${SCRIPT_VERSION:-0.0.0}" \
    "${context}"
}
```

## Container Execution

### Run with captured output

```bash
docker_run_capture() {
  local image="$1"; shift
  local output

  output="$(docker run --rm "${image}" "$@" 2>&1)" || {
    log_error "Container failed: ${output}"
    return 1
  }

  printf '%s\n' "${output}"
}
```

### Exec into running container

```bash
docker_exec_safe() {
  local container="$1"; shift

  docker inspect --format='{{.State.Running}}' "${container}" 2>/dev/null \
    | grep -q true \
    || die "Container '${container}' is not running"

  docker exec -it "${container}" "$@"
}
```

## Health Check Polling

Wait for a container to become healthy before proceeding.

```bash
wait_for_healthy() {
  local container="$1"
  local timeout="${2:-60}"
  local interval="${3:-2}"
  local elapsed=0

  log_info "Waiting for ${container} to be healthy (timeout: ${timeout}s)..."

  while (( elapsed < timeout )); do
    local status
    status="$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null || echo "missing")"

    case "${status}" in
      healthy)   log_info "${container} is healthy"; return 0 ;;
      unhealthy) die "${container} is unhealthy" ;;
    esac

    sleep "${interval}"
    ((elapsed += interval))
  done

  die "Timeout waiting for ${container} (${timeout}s)"
}
```

### With Gum progress

```bash
wait_for_healthy_visual() {
  local container="$1"
  local timeout="${2:-60}"

  if is_interactive; then
    seq 1 "${timeout}" | while read -r i; do
      local status
      status="$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null || echo "starting")"
      [[ "${status}" == "healthy" ]] && break
      sleep 1
      echo "${i}"
    done | gum progress --title "Waiting for ${container}..." --total "${timeout}"
  else
    wait_for_healthy "${container}" "${timeout}"
  fi
}
```

## Volume Mount Validation

```bash
validate_mount_path() {
  local host_path="$1"

  [[ -d "${host_path}" ]] || die "Mount source does not exist: ${host_path}"
  [[ -r "${host_path}" ]] || die "Mount source not readable: ${host_path}"

  # Resolve to absolute path (handles symlinks)
  host_path="$(cd -- "${host_path}" && pwd)" || die "Cannot resolve: ${host_path}"

  printf '%s\n' "${host_path}"
}

docker_run_with_mount() {
  local image="$1"
  local host_dir="$2"
  local container_dir="${3:-/data}"

  host_dir="$(validate_mount_path "${host_dir}")"

  docker run --rm \
    -v "${host_dir}:${container_dir}:rw" \
    "${image}"
}
```

## .dockerignore Verification

```bash
verify_dockerignore() {
  local context="${1:-.}"

  if [[ ! -f "${context}/.dockerignore" ]]; then
    log_warn "No .dockerignore found in ${context} — build context may be large"

    if is_interactive; then
      gum confirm "Continue without .dockerignore?" --default=false || exit 0
    fi
  fi
}
```

## Build Context Size Check

```bash
check_context_size() {
  local context="${1:-.}"
  local max_mb="${2:-100}"

  local size_kb
  size_kb="$(du -sk "${context}" 2>/dev/null | cut -f1)"
  local size_mb=$(( size_kb / 1024 ))

  if (( size_mb > max_mb )); then
    log_warn "Build context is ${size_mb}MB (limit: ${max_mb}MB)"
    log_warn "Check .dockerignore for large excluded directories"
  else
    log_info "Build context: ${size_mb}MB"
  fi
}
```

## Image Cleanup

```bash
docker_prune_safe() {
  local dry_run="${DRY_RUN:-0}"

  # Show what would be removed
  local dangling
  dangling="$(docker images -f 'dangling=true' -q | wc -l)"

  if (( dangling == 0 )); then
    log_info "No dangling images to clean"
    return 0
  fi

  log_info "Found ${dangling} dangling image(s)"

  if (( dry_run )); then
    docker images -f 'dangling=true' --format '{{.Repository}}:{{.Tag}} ({{.Size}})'
    return 0
  fi

  adaptive_confirm "Remove ${dangling} dangling images?" || return 0
  adaptive_spin "Pruning..." docker image prune -f
  log_info "Cleanup complete"
}
```

## Combined Pattern: Build Pipeline Script

```bash
#!/usr/bin/env bash
set -euo pipefail

source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/guards.sh"
source "${SCRIPT_DIR}/lib/log.sh"

readonly IMAGE_TAG="myproject:$(date +%Y%m%d)"

main() {
  require_cmd docker
  verify_dockerignore
  check_context_size . 200

  docker_build "${IMAGE_TAG}" .

  log_info "Starting container..."
  docker run -d --name test-run --health-cmd "curl -f http://localhost/health || exit 1" "${IMAGE_TAG}"

  wait_for_healthy_visual test-run 30

  log_info "Running validation..."
  docker_run_capture "${IMAGE_TAG}" /app/validate.sh

  docker_prune_safe
}

main "$@"
```

## Anti-Patterns

- Calling `docker build` without checking for Dockerfile first.
- Using `docker exec` without verifying container is running.
- Hardcoding volume paths without validation.
- No `.dockerignore` leading to 500MB+ build contexts.
- Polling indefinitely without timeout.
- `docker rm -f` without confirmation on interactive sessions.
