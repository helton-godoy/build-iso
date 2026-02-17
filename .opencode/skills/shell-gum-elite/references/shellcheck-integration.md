# ShellCheck Integration

## Objective

Systematically enforce script quality with ShellCheck, adapted for Bash + Gum
projects. Covers project configuration, selective suppression, CI integration,
and the most impactful error codes.

## Project Configuration (`.shellcheckrc`)

Place at the project root. All `shellcheck` invocations inherit these settings.

```ini
# Target shell — Bash 4+ (not POSIX sh)
shell=bash

# Follow sourced files
external-sources=true

# Enable strict optional checks
enable=avoid-nullary-conditions
enable=require-variable-braces
enable=check-unassigned-uppercase

# SC1091: Not following sourced files when path is dynamic
#   Justification: lib/*.sh paths are resolved at runtime via SCRIPT_DIR
disable=SC1091
```

## Top 10 Error Codes You Will Hit

| Code | Severity | Problem | Fix |
|---|---|---|---|
| SC2086 | Warning | Unquoted variable | `"${var}"` not `$var` |
| SC2155 | Warning | `local var=$(cmd)` masks return code | `local var; var=$(cmd)` |
| SC2181 | Style | `if [ $? -eq 0 ]` | `if some_cmd; then` |
| SC2015 | Info | `A && B \|\| C` isn't if/else | Use `if A; then B; else C; fi` |
| SC2034 | Warning | Variable appears unused | Export, prefix with `_`, or remove |
| SC2154 | Warning | Variable referenced but not assigned | Declare or check `${var:-}` |
| SC2128 | Warning | Array without index expands to first element | Use `"${arr[@]}"` |
| SC2068 | Error | Double quote array expansions | `"$@"` not `$@` |
| SC2046 | Warning | Unquoted command substitution | `"$(cmd)"` not `$(cmd)` |
| SC2164 | Warning | `cd` without `||` exit | `cd dir || exit 1` |

## Selective Suppression

### Per-line (always with justification comment)

```bash
# SC2086: Intentional word splitting for gum choose options
# shellcheck disable=SC2086
choice="$(gum choose ${OPTIONS})"
```

### Per-function

```bash
my_function() {
  # shellcheck disable=SC2155
  local output="$(expensive_cmd)"  # Return code checked below
  [[ -n "${output}" ]] || return 1
}
```

### Per-file (top of script, after shebang)

```bash
#!/usr/bin/env bash
# shellcheck disable=SC1091  # Dynamic source paths resolved at runtime
```

> **Rule**: Never suppress without a comment explaining *why*.

## Gum-Specific Suppressions

Gum commands often trigger false positives:

```bash
# SC2086: Gum --header accepts the unquoted string as-is
# shellcheck disable=SC2086
gum style --border rounded --padding "1 2" ${HEADER_TEXT}

# SC2034: GUM_* env vars consumed externally by gum binary
# shellcheck disable=SC2034
GUM_CHOOSE_CURSOR_FOREGROUND="#FFB703"
```

## Parallel Checking

```bash
lint_all() {
  local failed=0
  find . -name '*.sh' -not -path './tests/mocks/*' -print0 \
    | xargs -0 -P "$(nproc)" -n 1 shellcheck -x \
    || failed=1
  return "${failed}"
}
```

## CI Integration

### Pre-commit hook

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit — lint only staged shell scripts
set -euo pipefail

mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$' || true)

if (( ${#staged[@]} == 0 )); then
  exit 0
fi

printf 'ShellCheck: %d file(s)\n' "${#staged[@]}"
shellcheck -x "${staged[@]}"
```

### GitHub Actions snippet

```yaml
- name: ShellCheck
  run: |
    find . -name '*.sh' -not -path './tests/mocks/*' \
      | xargs shellcheck -x --format=gcc
```

## Output Formats

| Format | Use Case | Command |
|---|---|---|
| `tty` (default) | Local development | `shellcheck script.sh` |
| `gcc` | CI (parseable by editors) | `shellcheck --format=gcc script.sh` |
| `json` | Programmatic processing | `shellcheck --format=json script.sh` |
| `quiet` | Pass/fail gate only | `shellcheck --format=quiet script.sh` |

## Anti-Patterns

- Blanket `disable=SC2086` at file level — defeats the purpose.
- Running ShellCheck with `--shell=sh` on Bash scripts — false positives on `[[`, arrays, etc.
- Suppressing without justification — creates tech debt.
- Not using `-x` flag — misses issues in sourced files.
- Checking `tests/mocks/gum` — mock stubs will always fail lint.

## Companion: shfmt (Code Formatting)

ShellCheck finds bugs; **shfmt** enforces style. Use both together.

### Configuration (`.editorconfig`)

```ini
[*.sh]
indent_style = space
indent_size = 2
shell_variant = bash
binary_next_line = true
switch_case_indent = true
space_redirects = true
```

### Quick Commands

```bash
# Check only (CI-safe, exits non-zero if unformatted)
shfmt -d -i 2 -bn -ci scripts/

# Fix in-place
shfmt -w -i 2 -bn -ci scripts/

# Format staged files only
git diff --cached --name-only --diff-filter=ACM \
  | grep '\.sh$' \
  | xargs shfmt -w -i 2
```

> **Order:** Run `shfmt -w` first, then `shellcheck`. Formatting fixes often
> resolve ShellCheck warnings (e.g., broken indentation in heredocs).

## See Also

- [quality-pipeline.md](quality-pipeline.md) — Full pipeline: shfmt → ShellCheck → BATS → VHS
- [bats-testing.md](bats-testing.md) — Unit testing with BATS + Gum mocks
