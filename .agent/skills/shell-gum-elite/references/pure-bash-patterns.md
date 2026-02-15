# Pure Bash Patterns

## Objective

Keep scripts fast, portable, and dependency-light by preferring Bash built-ins over subprocesses.

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

## Portability Rules (Linux/macOS)

1. Use `#!/usr/bin/env bash`.
2. Quote expansions (`"${var}"`) to avoid word splitting.
3. Prefer `printf` over `echo` for predictable output.
4. Gate Bash 4+ features when macOS compatibility matters.
5. Avoid GNU-only flags unless guarded by OS detection.

## Anti-Patterns to Avoid

- Backticks instead of `$(...)`.
- `expr` when `(( ... ))` works.
- Parsing `ls` output in loops.
- Silent error swallowing (`|| true`) without rationale.
- Broad `eval` use for dynamic behavior.
