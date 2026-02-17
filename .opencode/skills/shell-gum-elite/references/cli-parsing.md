# CLI Argument Parsing

## Objective

Provide robust, consistent argument parsing patterns that integrate seamlessly
with Gum for interactive fallbacks.

## Pattern 1: while/case (Recommended)

Supports short flags, long options, and `--key=value` syntax.

```bash
show_help() {
  cat <<'EOF'
Usage: deploy.sh [OPTIONS]

Options:
  -e, --env ENV        Target environment (dev|stage|prod)
  -v, --version VER    Release version (semver)
  -f, --force          Skip confirmation
      --dry-run        Simulate without executing
      --verbose        Enable verbose output
  -h, --help           Show this help
      --version-info   Show script version
EOF
}

parse_args() {
  ENV=""
  VERSION=""
  FORCE=0
  DRY_RUN=0
  SCRIPT_VERBOSE=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--env)
        ENV="${2:?Missing value for --env}"
        shift 2
        ;;
      --env=*)
        ENV="${1#*=}"
        shift
        ;;
      -v|--version)
        VERSION="${2:?Missing value for --version}"
        shift 2
        ;;
      --version=*)
        VERSION="${1#*=}"
        shift
        ;;
      -f|--force)
        FORCE=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --verbose)
        SCRIPT_VERBOSE=1
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      --version-info)
        printf '%s\n' "${SCRIPT_VERSION:-0.0.0}"
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        log_error "Unknown option: $1"
        show_help
        exit 2
        ;;
      *)
        break
        ;;
    esac
  done

  # Remaining positional arguments accessible via "$@"
  POSITIONAL_ARGS=("$@")
}
```

## Pattern 2: Hybrid (CLI + Gum Fallback)

Ask interactively for missing required arguments.

```bash
resolve_args() {
  parse_args "$@"

  # Fill missing required args via Gum (if interactive)
  [[ -z "${ENV}" ]] && ENV="$(adaptive_choose "Environment" dev stage prod)"
  [[ -z "${VERSION}" ]] && VERSION="$(adaptive_input "Version: " "")"
}

main() {
  resolve_args "$@"
  validate_args
  execute
}
```

## Pattern 3: Required Argument Validation

```bash
validate_args() {
  local errors=()

  [[ -z "${ENV}" ]] && errors+=("--env is required")
  [[ -z "${VERSION}" ]] && errors+=("--version is required")
  [[ "${ENV}" =~ ^(dev|stage|prod)$ ]] || errors+=("--env must be dev, stage, or prod")
  [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || errors+=("--version must be valid semver")

  if (( ${#errors[@]} > 0 )); then
    for err in "${errors[@]}"; do
      log_error "${err}"
    done
    show_help
    exit 2
  fi
}
```

## Pattern 4: Auto-Generated Help from Comments

```bash
# @description Deploy application to target environment
# @option -e --env      Target environment (dev|stage|prod)
# @option -v --version  Release version (semver)
# @flag   -f --force    Skip confirmation prompt
# @flag      --dry-run  Simulate without executing

auto_help() {
  local script_file="${BASH_SOURCE[1]:-$0}"
  printf 'Usage: %s [OPTIONS]\n\nOptions:\n' "${script_file##*/}"
  while IFS= read -r line; do
    if [[ "${line}" =~ ^#\ @option ]]; then
      printf '  %s\n' "${line#*@option }"
    elif [[ "${line}" =~ ^#\ @flag ]]; then
      printf '  %s\n' "${line#*@flag }"
    elif [[ "${line}" =~ ^#\ @description ]]; then
      printf '\n%s\n\n' "${line#*@description }"
    fi
  done < "${script_file}"
}
```

## Conventions

1. Short flags use single dash and single letter (`-e`, `-v`, `-f`).
2. Long options use double dash (`--env`, `--version`, `--force`).
3. `--key=value` syntax is supported alongside `--key value`.
4. `--` terminates option parsing; remaining args are positional.
5. `-h`/`--help` and `--version-info` always exit immediately.
6. Unknown flags cause an error with help text.
7. Boolean flags default to `0` (false); presence sets `1` (true).
