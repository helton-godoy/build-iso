# Script Architecture

## Reference Layout

```text
scripts/
  app.sh
lib/
  cli.sh
  log.sh
  validate.sh
  platform.sh
tests/
  app.bats
```

## Runtime Contract

- `app.sh` owns argument parsing and orchestration.
- `lib/*.sh` contains side-effect-limited helpers and reusable primitives.
- Every external dependency check is centralized in `platform.sh`.
- Logging format is centralized in `log.sh`.

## Logging API

```bash
log_info()  { gum log --level info -- "$1"; }
log_warn()  { gum log --level warn -- "$1"; }
log_error() { gum log --level error -- "$1"; }
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
  exit "$code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
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
