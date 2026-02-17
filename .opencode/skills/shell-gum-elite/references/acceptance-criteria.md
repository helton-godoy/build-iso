# Acceptance Criteria: shell-gum-elite

**SDK/Tooling Focus**: Bash + Gum CLI + ShellCheck + Bats
**Purpose**: Validate that generated scripts prioritize pure Bash logic and premium Gum UX.

---

## 1. Foundation Safety

### 1.1 Strict mode present

#### CORRECT
```bash
#!/usr/bin/env bash
set -euo pipefail
```

#### INCORRECT
```bash
#!/bin/bash
set +e
```

### 1.2 Safe quoting

#### CORRECT
```bash
printf '%s\n' "${value}"
```

#### INCORRECT
```bash
echo $value
```

---

## 2. Pure Bash Preference

### 2.1 String length uses parameter expansion

#### CORRECT
```bash
len="${#value}"
```

#### INCORRECT
```bash
len="$(echo "$value" | wc -c)"
```

### 2.2 Arithmetic uses native expansion

#### CORRECT
```bash
((retries+=1))
```

#### INCORRECT
```bash
retries="$(expr "$retries" + 1)"
```

---

## 3. Gum Interaction Quality

### 3.1 User decisions are explicit

#### CORRECT
```bash
target="$(gum choose dev stage prod)"
gum confirm "Deploy to ${target}?" || exit 0
```

#### INCORRECT
```bash
target="prod"
deploy_now
```

### 3.2 Long operations show feedback

#### CORRECT
```bash
gum spin --title "Deploying..." -- ./deploy.sh
```

#### INCORRECT
```bash
./deploy.sh
```

### 3.3 Known-count operations show progress

#### CORRECT

```bash
for i in "${!items[@]}"; do
  process "${items[$i]}"
  echo "$(( (i + 1) * 100 / ${#items[@]} ))"
done | gum progress --title "Processing..."
```

#### INCORRECT

```bash
for item in "${items[@]}"; do
  process "${item}"
done
```

---

## 4. Architecture and Diagnostics

### 4.1 Structured logging present

#### CORRECT

```bash
gum log --level info "Backup completed"
```

#### INCORRECT

```bash
echo "done"
```

### 4.2 Cleanup trap configured

#### CORRECT

```bash
cleanup() { local code=$?; exit "$code"; }
trap cleanup EXIT INT TERM
```

#### INCORRECT

```bash
# no trap configured
```

### 4.3 Error context on failure

#### CORRECT

```bash
error_trap() {
  local code=$? line="${1:-}"
  log_error "Failed at line ${line} (exit ${code}): ${BASH_COMMAND}"
}
trap 'error_trap "${LINENO}"' ERR
```

#### INCORRECT

```bash
# No ERR trap; errors produce no context
```

---

## 5. CI / Non-Interactive Support

### 5.1 Interactive detection before Gum calls

#### CORRECT

```bash
is_interactive() { [[ "${FORCE_NONINTERACTIVE:-0}" -eq 0 && -t 0 && -t 1 ]]; }

if is_interactive; then
  env="$(gum choose dev stage prod)"
else
  env="${ENV:?--env required in non-interactive mode}"
fi
```

#### INCORRECT

```bash
env="$(gum choose dev stage prod)"  # Hangs in CI
```

### 5.2 Spinner adapts to environment

#### CORRECT

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

#### INCORRECT

```bash
gum spin --title "Working..." -- long_command  # No output in CI
```

---

## 6. CLI Argument Parsing

### 6.1 Long options supported

#### CORRECT

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env) ENV="${2:?Missing --env}"; shift 2 ;;
    --env=*)  ENV="${1#*=}"; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) break ;;
  esac
done
```

#### INCORRECT

```bash
ENV="$1"  # Positional only, no validation
```

### 6.2 Missing args filled interactively

#### CORRECT

```bash
[[ -z "${ENV}" ]] && ENV="$(adaptive_choose "Environment" dev stage prod)"
```

#### INCORRECT

```bash
[[ -z "${ENV}" ]] && { echo "Missing --env"; exit 1; }
# Could have asked interactively
```

---

## 7. Configuration and Logging

### 7.1 Dual-channel logging

#### CORRECT

```bash
_log() {
  local level="$1" msg="$2"
  gum log --level "${level}" -- "${msg}"
  [[ -n "${LOG_FILE:-}" ]] && printf '[%s] %s: %s\n' "$(date -Iseconds)" "${level}" "${msg}" >> "${LOG_FILE}"
}
```

#### INCORRECT

```bash
echo "done"  # No structure, no file, no level
```

### 7.2 Config file loaded safely

#### CORRECT

```bash
# Parse key=value without source
while IFS='=' read -r key value; do
  [[ "${key}" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${!key:-}" ]] && export "${key}=${value}"
done < ".env"
```

#### INCORRECT

```bash
source .env  # Arbitrary code execution risk
```

---

## 8. Error Resilience

### 8.1 Precondition guards used

#### CORRECT

```bash
require_cmd gum "brew install gum"
require_bash_version 4
require_file "/etc/config.yaml"
```

#### INCORRECT

```bash
# Assumes everything is available
gum choose ...
```

### 8.2 Retry for flaky operations

#### CORRECT

```bash
retry_with_backoff 3 2 curl -sSf "${API_URL}"
```

#### INCORRECT

```bash
curl -sSf "${API_URL}"  # Fails permanently on transient error
```

---

## 9. Testing

### 9.1 Gum is mocked in tests

#### CORRECT

```bash
setup() {
  export PATH="${MOCK_DIR}:${PATH}"
  export FORCE_NONINTERACTIVE=1
}
```

#### INCORRECT

```bash
# Tests call real gum, hang waiting for input
```

### 9.2 Cleanup traps are tested

#### CORRECT

```bash
@test "cleanup removes temp dir" {
  run bash -c "TMP_DIR='${d}'; cleanup() { rm -rf \"\${TMP_DIR}\"; }; trap cleanup EXIT; exit 0"
  [ ! -d "${d}" ]
}
```

#### INCORRECT

```bash
# Cleanup behavior never validated
```

---

## 10. Forbidden Patterns

- Hardcoded credentials/tokens.
- `eval` for avoidable control flow.
- Unchecked destructive command execution.
- Overuse of external tools for native Bash-capable operations.
- Calling Gum without TTY detection.
- `source .env` without sanitization.
- Unbounded retries without backoff.
- Parallel jobs without exit code collection.

---

## 11. ShellCheck Compliance

### 11.1 Clean lint pass on all scripts

#### CORRECT

```bash
# All scripts pass without warnings
shellcheck -x scripts/*.sh lib/*.sh
```

#### INCORRECT

```bash
# Blanket suppressions without justification
# shellcheck disable=SC2086,SC2155,SC2034
```

### 11.2 Selective suppression with justification

#### CORRECT

```bash
# SC2086: Intentional word splitting for gum choose options
# shellcheck disable=SC2086
choice="$(gum choose ${OPTIONS})"
```

#### INCORRECT

```bash
# shellcheck disable=SC2086
# (no explanation of WHY this suppression is needed)
result="$(gum style $ARGS)"
```

---

## 12. Naming Discipline

### 12.1 Functions use verb_object convention

#### CORRECT

```bash
validate_input() { ... }
build_image() { ... }
download_binary() { ... }
```

#### INCORRECT

```bash
check() { ... }
do_it() { ... }
process() { ... }
```

### 12.2 Variables reveal intent

#### CORRECT

```bash
readonly MAX_RETRIES=3
local retry_count=0
local is_verbose="${SCRIPT_VERBOSE:-0}"
local output_file="/tmp/result.txt"
```

#### INCORRECT

```bash
MAX=3
n=0
v="$SCRIPT_VERBOSE"
fp="/tmp/result.txt"
```

