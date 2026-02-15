# Configuration & Logging

## Objective

Patterns for hierarchical configuration loading, dual-channel logging
(terminal + file), and customizable theming.

## Configuration Hierarchy

Priority (highest to lowest):
1. CLI arguments (`--env=prod`)
2. Environment variables (`ENV=prod`)
3. Config file (`.env`, `.conf`)
4. Defaults in script

### Safe .env Loading

Never `source` a `.env` file directly — it may contain arbitrary code.

```bash
load_env_file() {
  local env_file="${1:-.env}"
  [[ -f "${env_file}" ]] || return 0

  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "${key}" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${key}" ]] && continue

    # Trim whitespace
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # Strip surrounding quotes
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"

    # Only set if not already defined (env vars take precedence)
    if [[ -z "${!key:-}" ]]; then
      export "${key}=${value}"
    fi
  done < "${env_file}"
}
```

### Full Configuration Resolution

```bash
resolve_config() {
  # 1. Load defaults
  LOG_LEVEL="${LOG_LEVEL:-info}"
  LOG_DIR="${LOG_DIR:-/var/log}"
  RETRY_COUNT="${RETRY_COUNT:-3}"
  THEME_FILE="${THEME_FILE:-}"

  # 2. Load config file (only overrides unset vars)
  load_env_file "${CONFIG_FILE:-.env}"

  # 3. CLI args override everything (done in parse_args)
}
```

## Dual-Channel Logging

### Setup

```bash
LOG_FILE=""
LOG_LEVEL="${LOG_LEVEL:-info}"

declare -A LOG_LEVELS=(
  [debug]=0
  [info]=1
  [warn]=2
  [error]=3
)

setup_logging() {
  local log_dir="${1:-${LOG_DIR:-/tmp}}"
  local script_name="${SCRIPT_NAME:-script}"
  local timestamp
  timestamp="$(date +%Y%m%d_%H%M%S)"

  mkdir -p "${log_dir}" || die "Cannot create log directory: ${log_dir}"
  LOG_FILE="${log_dir}/${script_name}_${timestamp}.log"
  readonly LOG_FILE

  log_info "Logging to: ${LOG_FILE}"
}
```

### Log Functions

```bash
_log() {
  local level="$1"
  local msg="$2"

  local current_level="${LOG_LEVELS[${LOG_LEVEL}]:-1}"
  local msg_level="${LOG_LEVELS[${level}]:-1}"

  # Skip if below threshold
  (( msg_level < current_level )) && return 0

  # Terminal output (via gum if available)
  if command -v gum >/dev/null 2>&1 && is_interactive; then
    gum log --level "${level}" -- "${msg}"
  else
    local prefix
    case "${level}" in
      debug) prefix="[DBG]" ;;
      info)  prefix="[INF]" ;;
      warn)  prefix="[WRN]" ;;
      error) prefix="[ERR]" ;;
    esac
    printf '%s %s\n' "${prefix}" "${msg}" >&2
  fi

  # File output (always, if log file is set)
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '[%s] %-5s %s\n' "$(date -Iseconds)" "${level^^}" "${msg}" >> "${LOG_FILE}"
  fi
}

log_debug() { _log debug "$1"; }
log_info()  { _log info "$1"; }
log_warn()  { _log warn "$1"; }
log_error() { _log error "$1"; }
```

### Log Rotation (Simple)

```bash
rotate_logs() {
  local log_dir="${1:-${LOG_DIR:-/tmp}}"
  local max_files="${2:-10}"
  local pattern="${SCRIPT_NAME:-script}_*.log"

  local count
  count="$(find "${log_dir}" -maxdepth 1 -name "${pattern}" -type f 2>/dev/null | wc -l)"

  if (( count > max_files )); then
    local to_remove=$(( count - max_files ))
    find "${log_dir}" -maxdepth 1 -name "${pattern}" -type f -printf '%T@ %p\n' \
      | sort -n \
      | head -n "${to_remove}" \
      | awk '{print $2}' \
      | xargs rm -f --
    log_info "Rotated ${to_remove} old log files"
  fi
}
```

## Customizable Themes

### Theme file format (`theme.conf`)

```bash
# theme.conf — Custom project theme
COLOR_PRIMARY="#8ECAE6"
COLOR_ACCENT="#FFB703"
COLOR_SUCCESS="#2A9D8F"
COLOR_WARNING="#FB8500"
COLOR_ERROR="#D62828"
COLOR_MUTED="#6C757D"
BORDER_STYLE="rounded"
PADDING_STANDARD="1 2"
SPINNER_STYLE="dot"
```

### Theme loader

```bash
# Default palette (fallback)
COLOR_PRIMARY="${COLOR_PRIMARY:-#8ECAE6}"
COLOR_ACCENT="${COLOR_ACCENT:-#FFB703}"
COLOR_SUCCESS="${COLOR_SUCCESS:-#2A9D8F}"
COLOR_WARNING="${COLOR_WARNING:-#FB8500}"
COLOR_ERROR="${COLOR_ERROR:-#D62828}"
COLOR_MUTED="${COLOR_MUTED:-#6C757D}"
BORDER_STYLE="${BORDER_STYLE:-rounded}"
PADDING_STANDARD="${PADDING_STANDARD:-1 2}"
SPINNER_STYLE="${SPINNER_STYLE:-dot}"

load_theme() {
  local theme_file="${1:-}"

  # Try project theme, then user theme, then defaults
  local candidates=(
    "${theme_file}"
    "${SCRIPT_DIR}/theme.conf"
    "${HOME}/.config/shell-gum/theme.conf"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -n "${candidate}" && -f "${candidate}" ]]; then
      load_env_file "${candidate}"
      log_debug "Theme loaded: ${candidate}"
      return 0
    fi
  done

  log_debug "Using default theme"
}
```

### Themed UI Helpers

```bash
ui_header() {
  gum style \
    --foreground "${COLOR_PRIMARY}" \
    --border "${BORDER_STYLE}" \
    --border-foreground "${COLOR_ACCENT}" \
    --padding "${PADDING_STANDARD}" \
    --bold \
    "$1"
}

ui_success() {
  gum style --foreground "${COLOR_SUCCESS}" --bold "[OK] $1"
}

ui_warn() {
  gum style --foreground "${COLOR_WARNING}" --bold "[WARN] $1"
}

ui_error() {
  gum style --foreground "${COLOR_ERROR}" --bold "[ERR] $1"
}

ui_muted() {
  gum style --foreground "${COLOR_MUTED}" --faint "$1"
}
```
