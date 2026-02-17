# CI & Non-Interactive Mode

## Objective

Ensure scripts built with Gum degrade gracefully in headless environments
(CI pipelines, cron jobs, `ssh -T`, Docker builds) while keeping the same
code paths.

## Detecting Interactivity

```bash
is_interactive() { [[ -t 0 && -t 1 ]]; }

is_ci() {
  [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${GITLAB_CI:-}" \
    || -n "${JENKINS_URL:-}" || -n "${BUILDKITE:-}" ]]
}
```

## Adaptive Wrappers

### Choose (single selection)

```bash
adaptive_choose() {
  local header="$1"; shift
  if is_interactive; then
    gum choose --header "${header}" "$@"
  else
    # Use first argument as default in non-interactive mode
    printf '%s\n' "$1"
  fi
}
```

### Choose (multi selection)

```bash
adaptive_choose_multi() {
  local header="$1"; shift
  if is_interactive; then
    gum choose --no-limit --header "${header}" "$@"
  else
    # Return all items in non-interactive mode
    printf '%s\n' "$@"
  fi
}
```

### Input

```bash
adaptive_input() {
  local prompt="$1"
  local default="${2:-}"
  if is_interactive; then
    gum input --prompt "${prompt}" --value "${default}"
  else
    [[ -n "${default}" ]] || {
      log_error "Input '${prompt}' requires a default value in non-interactive mode"
      exit 2
    }
    printf '%s\n' "${default}"
  fi
}
```

### Confirm

```bash
adaptive_confirm() {
  local prompt="$1"
  local default_yes="${2:-true}"
  if is_interactive; then
    gum confirm "${prompt}"
  else
    [[ "${default_yes}" == "true" ]]
  fi
}
```

### Write (multi-line)

```bash
adaptive_write() {
  local header="$1"
  local default="${2:-}"
  if is_interactive; then
    gum write --header "${header}" --value "${default}"
  else
    if [[ -n "${default}" ]]; then
      printf '%s\n' "${default}"
    elif [[ ! -t 0 ]]; then
      cat  # Read from piped stdin
    else
      log_error "Multi-line input requires --default or piped stdin in non-interactive mode"
      exit 2
    fi
  fi
}
```

### Spin (progress feedback)

```bash
adaptive_spin() {
  local title="$1"; shift
  if is_interactive; then
    gum spin --title "${title}" -- "$@"
  else
    log_info "${title}"
    "$@"
  fi
}
```

## Environment Variable Override

Allow forcing non-interactive mode explicitly:

```bash
FORCE_NONINTERACTIVE="${FORCE_NONINTERACTIVE:-0}"

is_interactive() {
  [[ "${FORCE_NONINTERACTIVE}" -eq 0 && -t 0 && -t 1 ]]
}
```

## Full Pattern: Script with Dual Mode

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source adaptive wrappers
source "${SCRIPT_DIR}/lib/ui.sh"

main() {
  require_cmd gum

  local env="${ENV:-}"
  local version="${VERSION:-}"

  # Falls back automatically in CI
  [[ -z "${env}" ]] && env="$(adaptive_choose "Environment" dev stage prod)"
  [[ -z "${version}" ]] && version="$(adaptive_input "Version: " "")"

  [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    log_error "Invalid semver: ${version}"
    exit 2
  }

  adaptive_confirm "Deploy ${version} to ${env}?" || exit 0
  adaptive_spin "Deploying..." ./deploy.sh "${env}" "${version}"
  log_info "Deployment completed"
}

main "$@"
```

## Anti-Patterns

- Calling `gum choose` without checking for a terminal.
- Silently defaulting without logging the fallback value.
- Using `gum spin` in CI where output is swallowed.
- Ignoring `TERM=dumb` which indicates limited terminal capabilities.
