# Concurrency Patterns

## Objective

Patterns for safe parallel execution in Bash, with proper job control,
exit code collection, and visual feedback via Gum.

## Basic Parallel Execution

### Fire and collect

```bash
run_parallel() {
  local pids=()
  local cmds=("$@")

  for cmd in "${cmds[@]}"; do
    eval "${cmd}" &
    pids+=($!)
  done

  local failures=0
  for pid in "${pids[@]}"; do
    if ! wait "${pid}"; then
      ((failures++))
    fi
  done

  return "${failures}"
}

# Usage:
# run_parallel "task_a" "task_b" "task_c"
```

## Worker Pool with Concurrency Limit

```bash
run_pool() {
  local max_jobs="${1}"
  shift
  local items=("$@")

  local active=0
  local pids=()
  local failures=0

  for item in "${items[@]}"; do
    process_item "${item}" &
    pids+=($!)
    ((active++))

    # Wait when pool is full
    if (( active >= max_jobs )); then
      wait "${pids[0]}" || ((failures++))
      pids=("${pids[@]:1}")
      ((active--))
    fi
  done

  # Wait for remaining
  for pid in "${pids[@]}"; do
    wait "${pid}" || ((failures++))
  done

  return "${failures}"
}

# Usage:
# run_pool 4 "${files[@]}"
```

## Parallel with Progress Feedback

### Sequential spinner per job

```bash
run_jobs_with_feedback() {
  local -n job_names=$1
  local -n job_cmds=$2

  local total="${#job_names[@]}"
  local failed=0

  for i in "${!job_names[@]}"; do
    local label="[$(( i + 1 ))/${total}] ${job_names[$i]}"

    if is_interactive; then
      if ! gum spin --title "${label}" -- bash -c "${job_cmds[$i]}"; then
        log_error "${label}: FAILED"
        ((failed++))
      else
        log_info "${label}: OK"
      fi
    else
      log_info "${label}..."
      if ! bash -c "${job_cmds[$i]}"; then
        log_error "${label}: FAILED"
        ((failed++))
      fi
    fi
  done

  return "${failed}"
}

# Usage:
# declare -a names=("Build" "Test" "Lint")
# declare -a cmds=("make build" "make test" "make lint")
# run_jobs_with_feedback names cmds
```

### Background jobs with aggregated status

```bash
run_parallel_with_status() {
  local -A jobs   # pid -> name
  local -A results  # name -> exit_code

  start_job() {
    local name="$1"; shift
    "$@" &
    jobs[$!]="${name}"
  }

  start_job "build" make build
  start_job "lint" make lint
  start_job "test" make test

  # Collect results
  for pid in "${!jobs[@]}"; do
    local name="${jobs[$pid]}"
    if wait "${pid}"; then
      results["${name}"]=0
    else
      results["${name}"]=$?
    fi
  done

  # Display results
  local csv="Task,Status\n"
  local failures=0
  for name in "${!results[@]}"; do
    local code="${results[$name]}"
    if (( code == 0 )); then
      csv+="${name},OK\n"
    else
      csv+="${name},FAIL (${code})\n"
      ((failures++))
    fi
  done
  printf '%b' "${csv}" | gum table --separator ","

  return "${failures}"
}
```

## Timeout Wrapper

```bash
run_with_timeout() {
  local timeout="$1"; shift

  timeout --signal=TERM --kill-after=5 "${timeout}" "$@"
  local code=$?

  if (( code == 124 )); then
    log_error "Command timed out after ${timeout}: $*"
  fi

  return "${code}"
}

# Usage:
# run_with_timeout 30s curl -sSf "https://slow-api.example.com"
```

## Lock File (Prevent Concurrent Runs)

```bash
LOCK_FILE=""

acquire_lock() {
  LOCK_FILE="${1:-/tmp/${SCRIPT_NAME:-script}.lock}"

  if [[ -f "${LOCK_FILE}" ]]; then
    local pid
    pid="$(<"${LOCK_FILE}")"
    if kill -0 "${pid}" 2>/dev/null; then
      die "Script already running (PID ${pid}). Lock: ${LOCK_FILE}"
    else
      log_warn "Stale lock file found (PID ${pid} not running). Removing."
      rm -f "${LOCK_FILE}"
    fi
  fi

  printf '%s\n' "$$" > "${LOCK_FILE}"
}

release_lock() {
  [[ -n "${LOCK_FILE:-}" && -f "${LOCK_FILE}" ]] && rm -f "${LOCK_FILE}"
}

# Integrate with cleanup
cleanup() {
  local code=$?
  release_lock
  [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]] && rm -rf -- "${TMP_DIR}"
  exit "${code}"
}

trap cleanup EXIT
```

## Best Practices

1. Always collect exit codes from background jobs with `wait`.
2. Limit concurrency to avoid resource exhaustion (CPU, file descriptors).
3. Use lock files for scripts that must not run concurrently.
4. Prefer `timeout` over manual signal handling for simple cases.
5. Show aggregated status after parallel completion, not per-job noise.
6. Use `set -m` (job control) only when necessary; it changes behavior.
