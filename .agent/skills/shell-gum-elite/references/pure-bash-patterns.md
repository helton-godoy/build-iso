# Pure Bash Patterns

## Objective

Keep scripts fast, portable, and dependency-light by preferring Bash built-ins
over subprocesses. Enforce consistent naming and function discipline.

## High-Value Native Patterns

### String and text operations

```bash
len="${#value}"
headless="${value#prefix}"
tailless="${value%suffix}"
replaced="${value//old/new}"
lower="${value,,}"
upper="${value^^}"
```

### Arithmetic

```bash
((count+=1))
((retry = retry + 1))
((is_even = count % 2 == 0))
```

### Arrays and lookup maps

```bash
declare -a items=("dev" "stage" "prod")
declare -A color=( [info]="#8ECAE6" [warn]="#FB8500" [error]="#D62828" )
```

### Safe reading patterns

```bash
mapfile -t lines < "${file}"
content="$(<"${file}")"
```

### Command checks

```bash
command -v gum >/dev/null 2>&1 || {
  printf 'gum is required\n' >&2
  exit 127
}
```

## Error Strategy

```bash
set -euo pipefail

cleanup() {
  local code=$?
  [[ -n "${tmp_dir:-}" && -d "${tmp_dir}" ]] && rm -rf -- "${tmp_dir}"
  exit "$code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
```

## Portability Guards

### OS Detection

```bash
detect_os() {
  case "$(uname -s)" in
    Linux*)  printf 'linux' ;;
    Darwin*) printf 'macos' ;;
    *)       printf 'unknown' ;;
  esac
}
readonly CURRENT_OS="$(detect_os)"
```

### GNU vs BSD Flag Fallbacks

```bash
# date: ISO format
portable_date_iso() {
  if [[ "${CURRENT_OS}" == "macos" ]]; then
    date -u +"%Y-%m-%dT%H:%M:%SZ"
  else
    date -Iseconds --utc
  fi
}

# readlink: resolve absolute path
portable_realpath() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  elif [[ "${CURRENT_OS}" == "macos" ]]; then
    perl -MCwd -e 'print Cwd::abs_path shift' "$1"
  else
    readlink -f "$1"
  fi
}

# sed: in-place editing
portable_sed_inplace() {
  if [[ "${CURRENT_OS}" == "macos" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# stat: file size in bytes
portable_file_size() {
  if [[ "${CURRENT_OS}" == "macos" ]]; then
    stat -f%z "$1"
  else
    stat --printf='%s' "$1"
  fi
}
```

### Bash Version Gate

```bash
if (( BASH_VERSINFO[0] < 4 )); then
  printf 'Requires Bash 4+ (current: %s)\n' "${BASH_VERSION}" >&2
  exit 1
fi
```

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Functions | `verb_object` lowercase | `validate_input()`, `build_image()` |
| Constants | `SCREAMING_SNAKE` | `MAX_RETRIES`, `DEFAULT_PORT` |
| Local variables | `lower_snake` | `file_path`, `retry_count` |
| Boolean variables | `is_`/`has_`/`can_` prefix | `is_verbose`, `has_config` |
| Environment exports | `UPPER_SNAKE` | `SCRIPT_VERBOSE`, `LOG_FILE` |
| Private helpers | `_` prefix | `_parse_line()`, `_emit_log()` |

> **Rule**: If a name needs a comment to explain it, rename it.

### Naming Anti-Patterns

```bash
# ❌ BAD: ambiguous
check() { ... }
n=5
fp="/tmp/out"

# ✅ GOOD: intent-revealing
validate_semver() { ... }
max_retries=5
output_file="/tmp/out"
```

## Function Discipline

| Rule | Guideline |
|---|---|
| **Size** | Max 50 lines; prefer 10-20 |
| **Params** | Max 3 positional; use named vars for more |
| **One thing** | Single responsibility per function |
| **Guard first** | Early returns for edge cases at the top |
| **Depth** | Max 2 levels of nesting |

### Pattern: Guard Clauses

```bash
process_file() {
  local file="$1"

  # Guards first — exit early on invalid state
  [[ -f "${file}" ]] || { log_error "Not a file: ${file}"; return 1; }
  [[ -r "${file}" ]] || { log_error "Not readable: ${file}"; return 1; }
  [[ -s "${file}" ]] || { log_warn "Empty file: ${file}"; return 0; }

  # Happy path
  local content
  content="$(<"${file}")"
  printf '%s\n' "${content}"
}
```

## Forbidden Substitutions

| ❌ Avoid | ✅ Use Instead | Why |
|---|---|---|
| `which cmd` | `command -v cmd` | POSIX, no path dependency |
| `echo -e "..."` | `printf '%b\n' "..."` | Portable escape handling |
| `echo -n "..."` | `printf '%s' "..."` | No trailing newline portably |
| `source file` | `. file` | POSIX compatible |
| `` `cmd` `` | `$(cmd)` | Nestable, readable |
| `expr 1 + 1` | `$(( 1 + 1 ))` | Native arithmetic |
| `cat file \| grep` | `grep pattern file` | Avoid useless cat |
| `ls \| while read` | `for f in dir/*` | Avoids parsing ls |

## Portability Rules (Linux/macOS)

1. Use `#!/usr/bin/env bash`.
2. Quote expansions (`"${var}"`) to avoid word splitting.
3. Prefer `printf` over `echo` for predictable output.
4. Gate Bash 4+ features when macOS compatibility matters.
5. Avoid GNU-only flags unless guarded by OS detection.

## Review Checklist

Before considering a function done, verify:

- [ ] All variables are quoted: `"${var}"` not `$var`
- [ ] No external tool where a built-in works (`${#var}` not `wc -c`)
- [ ] Function name reveals intent (`validate_config` not `check`)
- [ ] Guard clauses precede happy path
- [ ] ShellCheck passes with zero warnings

## Anti-Patterns to Avoid

- Backticks instead of `$(...)`.
- `expr` when `(( ... ))` works.
- Parsing `ls` output in loops.
- Silent error swallowing (`|| true`) without rationale.
- Broad `eval` use for dynamic behavior.
- Deep nesting (3+ levels) instead of guard clauses.
- God functions doing multiple unrelated things.
