# Script Architecture

## Reference Layout

```text
project/
  scripts/
    app.sh                # Main entry point (thin orchestrator)
  lib/
    cli.sh                # Argument parsing and help generation
    config.sh             # Configuration loading (env, files, defaults)
    guards.sh             # Precondition checks (require_cmd, require_root, etc.)
    log.sh                # Dual-channel logging (terminal + file)
    platform.sh           # OS detection and compatibility checks
    ui.sh                 # Adaptive Gum wrappers (interactive + CI)
    validate.sh           # Input validation functions
  config/
    theme.conf            # Customizable color theme
    defaults.env          # Default configuration values
  tests/
    setup.bash            # Shared test setup and teardown
    app.bats              # Integration tests for main script
    validate.bats         # Unit tests for validation functions
    guards.bats           # Unit tests for guard functions
    mocks/
      gum                 # Mock gum binary for deterministic testing
```

## Runtime Contract

- `app.sh` owns argument parsing and orchestration.
- `lib/*.sh` contains side-effect-limited helpers and reusable primitives.
- Every external dependency check is centralized in `guards.sh`.
- Logging format is centralized in `log.sh`.
- Configuration hierarchy is managed by `config.sh`.
- Interactive/CI adaptation is handled by `ui.sh`.
- All modules are sourced; none are executed directly.

## Module Responsibilities

### `cli.sh` — Argument Parsing

```bash
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--env) ENV="${2:?Missing --env}"; shift 2 ;;
      --env=*)  ENV="${1#*=}"; shift ;;
      -h|--help) show_help; exit 0 ;;
      --version-info) printf '%s\n' "${SCRIPT_VERSION}"; exit 0 ;;
      --verbose) SCRIPT_VERBOSE=1; shift ;;
      --debug) SCRIPT_DEBUG=1; shift ;;
      --) shift; break ;;
      -*) die "Unknown option: $1" ;;
      *) break ;;
    esac
  done
}
```

### `config.sh` — Configuration

```bash
resolve_config() {
  # Defaults → file → env (already set) → CLI (already parsed)
  load_env_file "${CONFIG_FILE:-defaults.env}"
  load_theme "${THEME_FILE:-}"
}
```

### `guards.sh` — Preconditions

```bash
require_cmd gum "brew install gum"
require_bash_version 4
require_file "${CONFIG_FILE}"
```

### `ui.sh` — Adaptive Wrappers

```bash
adaptive_choose() { ... }   # Falls back to first option in CI
adaptive_input() { ... }    # Falls back to default value in CI
adaptive_confirm() { ... }  # Falls back to default in CI
adaptive_spin() { ... }     # Falls back to log_info + direct exec in CI
```

## Logging API

### Basic (terminal only)

```bash
log_info()  { gum log --level info -- "$1"; }
log_warn()  { gum log --level warn -- "$1"; }
log_error() { gum log --level error -- "$1"; }
```

### Dual-channel (terminal + file)

```bash
_log() {
  local level="$1" msg="$2"
  if command -v gum >/dev/null 2>&1 && is_interactive; then
    gum log --level "${level}" -- "${msg}"
  else
    printf '[%s] %s\n' "${level^^}" "${msg}" >&2
  fi
  [[ -n "${LOG_FILE:-}" ]] && \
    printf '[%s] %-5s %s\n' "$(date -Iseconds)" "${level^^}" "${msg}" >> "${LOG_FILE}"
}
```

## Verbose and Debug Modes

```bash
SCRIPT_VERBOSE=${SCRIPT_VERBOSE:-0}
SCRIPT_DEBUG=${SCRIPT_DEBUG:-0}

debug() {
  [[ "${SCRIPT_DEBUG}" -eq 1 ]] && printf '[DBG] %s\n' "$*" >&2
}

verbose() {
  [[ "${SCRIPT_VERBOSE}" -eq 1 ]] && printf '[INF] %s\n' "$*" >&2
}
```

## Signal and Cleanup Discipline

```bash
cleanup() {
  local code=$?
  [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]] && rm -rf -- "${TMP_DIR}"
  [[ -n "${LOCK_FILE:-}" && -f "${LOCK_FILE}" ]] && rm -f "${LOCK_FILE}"
  exit "$code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
```

### Error context trap

```bash
error_trap() {
  local code=$? line="${1:-}"
  log_error "Failed at line ${line} (exit ${code}): ${BASH_COMMAND}"
  for ((i=1; i<${#FUNCNAME[@]}-1; i++)); do
    log_error "  ${FUNCNAME[$i]}() at line ${BASH_LINENO[$((i-1))]}"
  done
}
trap 'error_trap "${LINENO}"' ERR
```

## Semantic Versioning for Scripts

- Keep a script version constant: `SCRIPT_VERSION="1.3.0"`.
- Increment patch for fixes, minor for backward-compatible features, major for breaking changes.
- Gate behavior when needed:

```bash
gum version-check "${SCRIPT_VERSION}" ">= 1.0.0" || exit 2
```

## Testing Strategy with Bats

1. Unit-test pure helpers (`validate_semver`, `normalize_path`, etc.).
2. Integration-test interactive branches through deterministic fixtures.
3. Keep smoke tests for `--help`, `--version`, and non-interactive failure paths.
4. Mock Gum: prepend `tests/mocks/` to `$PATH` for headless testing.
5. Force non-interactive: `FORCE_NONINTERACTIVE=1` in test setup.
6. Test cleanup: verify temp dirs are removed and exit codes are preserved.

See [bats-testing.md](bats-testing.md) for comprehensive patterns and examples.

## Git Hooks

Automate quality gates with Bash-powered hooks.

### Pre-commit (`shellcheck` + `shfmt`)

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit
set -euo pipefail

mapfile -t staged < <(
  git diff --cached --name-only --diff-filter=ACM \
    | grep '\.sh$' || true
)

(( ${#staged[@]} == 0 )) && exit 0

printf '=== ShellCheck: %d file(s) ===\n' "${#staged[@]}"
shellcheck -x "${staged[@]}" || {
  printf 'ShellCheck failed. Fix errors or commit with --no-verify.\n' >&2
  exit 1
}

if command -v shfmt >/dev/null 2>&1; then
  printf '=== shfmt: checking format ===\n'
  shfmt -d -i 2 -ci "${staged[@]}" || {
    printf 'Format issues found. Run: shfmt -w -i 2 -ci <files>\n' >&2
    exit 1
  }
fi
```

### Pre-push (`bats`)

```bash
#!/usr/bin/env bash
# .git/hooks/pre-push
set -euo pipefail

if command -v bats >/dev/null 2>&1 && [[ -d tests/ ]]; then
  printf '=== Running tests before push ===\n'
  FORCE_NONINTERACTIVE=1 bats tests/ || {
    printf 'Tests failed. Push aborted.\n' >&2
    exit 1
  }
fi
```

### Installing hooks

```bash
install_hooks() {
  local hooks_dir=".git/hooks"
  [[ -d "${hooks_dir}" ]] || die "Not a git repository"

  for hook in pre-commit pre-push; do
    local file="${hooks_dir}/${hook}"
    cp "scripts/hooks/${hook}" "${file}"
    chmod +x "${file}"
    log_info "Installed ${hook} hook"
  done
}
```

## Version Management

### Script version pattern

```bash
# Centralized version constant
readonly SCRIPT_VERSION="1.3.0"

# Parse into components
IFS='.' read -r VER_MAJOR VER_MINOR VER_PATCH <<< "${SCRIPT_VERSION}"
```

### Tag-based release workflow

```bash
create_release_tag() {
  local version="$1"

  [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "Invalid semver: ${version}"

  git tag -a "v${version}" -m "Release ${version}"
  git push origin "v${version}"
  log_info "Tagged and pushed v${version}"
}
```

### Changelog generation

```bash
generate_changelog() {
  local from_tag="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo '')}"
  local range

  if [[ -n "${from_tag}" ]]; then
    range="${from_tag}..HEAD"
  else
    range="HEAD"
  fi

  printf '## Changes since %s\n\n' "${from_tag:-inception}"
  git log "${range}" --pretty=format:'- %s (%h)' --no-merges
  printf '\n'
}
```

## Script Self-Location

Robust `SCRIPT_DIR` resolution that handles symlinks.

```bash
resolve_script_dir() {
  local source="${BASH_SOURCE[0]}"

  # Resolve symlinks
  while [[ -L "${source}" ]]; do
    local dir
    dir="$(cd -P "$(dirname -- "${source}")" >/dev/null 2>&1 && pwd)"
    source="$(readlink -- "${source}")"
    # Handle relative symlinks
    [[ "${source}" != /* ]] && source="${dir}/${source}"
  done

  cd -P "$(dirname -- "${source}")" >/dev/null 2>&1 && pwd
}

readonly SCRIPT_DIR="$(resolve_script_dir)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
```

> **Rule**: Always use this pattern instead of `dirname "$0"` which fails
> with symlinks and sourced scripts.

