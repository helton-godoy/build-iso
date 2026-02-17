# Error Handling & Resilience

## Objective

Move beyond basic `set -euo pipefail` with patterns that provide rich error
context, automatic retries, precondition guards, and safe temporary resources.

## Rich Error Context

### Stack trace on failure

```bash
error_trap() {
  local code=$?
  local line="${1:-unknown}"
  local func="${FUNCNAME[1]:-main}"
  local cmd="${BASH_COMMAND:-unknown}"

  log_error "Command failed (exit ${code}): ${cmd}"
  log_error "  at ${func}(), line ${line}"

  # Print call stack
  if (( ${#FUNCNAME[@]} > 2 )); then
    log_error "  Call stack:"
    for ((i=1; i<${#FUNCNAME[@]}-1; i++)); do
      log_error "    ${FUNCNAME[$i]}() at line ${BASH_LINENO[$((i-1))]}"
    done
  fi

  exit "${code}"
}

trap 'error_trap "${LINENO}"' ERR
```

### die() with styled output

```bash
die() {
  local msg="$1"
  local code="${2:-1}"

  if command -v gum >/dev/null 2>&1 && is_interactive; then
    gum style \
      --foreground "#D62828" \
      --border rounded \
      --border-foreground "#D62828" \
      --padding "0 2" \
      --bold \
      "[FATAL] ${msg}"
  else
    printf '[FATAL] %s\n' "${msg}" >&2
  fi

  exit "${code}"
}
```

## Retry with Exponential Backoff

```bash
retry_with_backoff() {
  local max_attempts="${1}"
  local base_delay="${2}"
  shift 2
  local cmd=("$@")

  local attempt=1
  local delay="${base_delay}"

  while (( attempt <= max_attempts )); do
    if "${cmd[@]}"; then
      return 0
    fi

    local code=$?
    if (( attempt == max_attempts )); then
      log_error "Command failed after ${max_attempts} attempts: ${cmd[*]}"
      return "${code}"
    fi

    log_warn "Attempt ${attempt}/${max_attempts} failed (exit ${code}). Retrying in ${delay}s..."
    sleep "${delay}"
    ((delay *= 2))
    ((attempt++))
  done
}

# Usage:
# retry_with_backoff 5 2 curl -sSf "https://api.example.com/health"
```

## Precondition Guards

```bash
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1 (install with: ${2:-package manager})" 127
}

require_root() {
  (( EUID == 0 )) || die "This script must be run as root" 1
}

require_non_root() {
  (( EUID != 0 )) || die "This script must NOT be run as root" 1
}

require_bash_version() {
  local minimum="$1"
  (( BASH_VERSINFO[0] >= minimum )) || die "Requires Bash ${minimum}+ (current: ${BASH_VERSION})" 1
}

require_file() {
  [[ -f "$1" ]] || die "Required file not found: $1" 2
}

require_dir() {
  [[ -d "$1" ]] || die "Required directory not found: $1" 2
}

require_var() {
  [[ -n "${!1:-}" ]] || die "Required variable not set: $1" 2
}

require_disk_space() {
  local path="$1"
  local min_mb="$2"
  local avail_kb
  avail_kb="$(df --output=avail -k "${path}" 2>/dev/null | tail -1)"
  local avail_mb=$(( avail_kb / 1024 ))
  (( avail_mb >= min_mb )) || die "Insufficient disk space at ${path}: ${avail_mb}MB < ${min_mb}MB" 1
}

require_network() {
  local host="${1:-1.1.1.1}"
  local timeout="${2:-3}"
  if command -v ping >/dev/null 2>&1; then
    ping -c1 -W"${timeout}" "${host}" >/dev/null 2>&1 || die "No network connectivity (cannot reach ${host})" 1
  elif command -v curl >/dev/null 2>&1; then
    curl -sf --max-time "${timeout}" "https://${host}" >/dev/null 2>&1 || die "No network connectivity" 1
  fi
}
```

## Safe Temporary Resources

```bash
setup_temp() {
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${SCRIPT_NAME:-script}.XXXXXXXXXX")" || die "Failed to create temp directory"
  readonly TMP_DIR
}

cleanup() {
  local code=$?
  [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]] && rm -rf -- "${TMP_DIR}"
  exit "${code}"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
```

### Temp file helpers

```bash
make_temp_file() {
  local name="${1:-tmp}"
  local file="${TMP_DIR}/${name}.$$"
  touch "${file}" || die "Failed to create temp file: ${file}"
  printf '%s\n' "${file}"
}
```

## Combined Pattern: Robust Script Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SCRIPT_NAME="${0##*/}"
readonly SCRIPT_NAME

# Source libraries
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/guards.sh"

# Setup
setup_temp
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'error_trap "${LINENO}"' ERR

# Guards
require_bash_version 4
require_cmd gum "brew install gum"
require_cmd curl

main() {
  # Safe operations with retry
  local response
  response="$(retry_with_backoff 3 2 curl -sSf "https://api.example.com/status")"

  log_info "Service status: ${response}"
}

main "$@"
```
