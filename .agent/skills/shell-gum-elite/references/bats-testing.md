# Bats Testing Guide

## Objective

Practical patterns for testing Bash scripts using Bats (Bash Automated Testing
System), including mocking Gum commands and testing error handling.

## Directory Structure

```text
project/
  scripts/
    deploy.sh
  lib/
    log.sh
    validate.sh
    guards.sh
    ui.sh
  tests/
    setup.bash        # Shared setup for all tests
    deploy.bats       # Tests for deploy.sh
    validate.bats     # Tests for validate.sh
    guards.bats       # Tests for guards.sh
    mocks/
      gum             # Mock gum binary
```

## Shared Setup (`tests/setup.bash`)

```bash
#!/usr/bin/env bash

# Load bats helpers
load '/usr/lib/bats-support/load.bash' 2>/dev/null || true
load '/usr/lib/bats-assert/load.bash' 2>/dev/null || true

# Project paths
PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
MOCK_DIR="${BATS_TEST_DIRNAME}/mocks"

# Force non-interactive mode
export FORCE_NONINTERACTIVE=1
export NO_COLOR=1

# Create temp directory for each test
setup() {
  TEST_TEMP="$(mktemp -d)"
  export TEST_TEMP
}

# Clean up after each test
teardown() {
  [[ -n "${TEST_TEMP:-}" && -d "${TEST_TEMP}" ]] && rm -rf "${TEST_TEMP}"
}

# Helper: source a library
source_lib() {
  source "${LIB_DIR}/$1"
}
```

## Testing Pure Functions (`tests/validate.bats`)

```bash
#!/usr/bin/env bats

load 'setup'

setup() {
  source_lib "validate.sh"
}

@test "validate_semver accepts valid version" {
  run validate_semver "1.2.3"
  [ "$status" -eq 0 ]
}

@test "validate_semver accepts version with pre-release" {
  run validate_semver "1.2.3-beta.1"
  [ "$status" -eq 0 ]
}

@test "validate_semver rejects invalid version" {
  run validate_semver "not-a-version"
  [ "$status" -ne 0 ]
}

@test "validate_semver rejects empty input" {
  run validate_semver ""
  [ "$status" -ne 0 ]
}
```

## Testing Guard Functions (`tests/guards.bats`)

```bash
#!/usr/bin/env bats

load 'setup'

setup() {
  source_lib "guards.sh"
  # Override die to prevent exit in tests
  die() { printf 'DIE: %s\n' "$1" >&2; return "${2:-1}"; }
}

@test "require_cmd succeeds for existing command" {
  run require_cmd "bash"
  [ "$status" -eq 0 ]
}

@test "require_cmd fails for missing command" {
  run require_cmd "nonexistent_command_xyz123"
  [ "$status" -ne 0 ]
  [[ "$output" == *"nonexistent_command_xyz123"* ]]
}

@test "require_file succeeds for existing file" {
  touch "${TEST_TEMP}/testfile"
  run require_file "${TEST_TEMP}/testfile"
  [ "$status" -eq 0 ]
}

@test "require_file fails for missing file" {
  run require_file "${TEST_TEMP}/nonexistent"
  [ "$status" -ne 0 ]
}

@test "require_var succeeds when variable is set" {
  export MY_VAR="value"
  run require_var "MY_VAR"
  [ "$status" -eq 0 ]
}

@test "require_var fails when variable is unset" {
  unset MY_VAR 2>/dev/null || true
  run require_var "MY_VAR"
  [ "$status" -ne 0 ]
}

@test "require_bash_version accepts current version" {
  run require_bash_version "${BASH_VERSINFO[0]}"
  [ "$status" -eq 0 ]
}

@test "require_bash_version rejects higher version" {
  run require_bash_version 99
  [ "$status" -ne 0 ]
}
```

## Mocking Gum (`tests/mocks/gum`)

Create a mock `gum` binary for deterministic testing.

```bash
#!/usr/bin/env bash
# Mock gum — returns predictable values based on subcommand

case "$1" in
  choose)
    # Return the first option after all flags
    while [[ "$1" == -* ]]; do shift; done
    shift  # skip 'choose' itself
    printf '%s\n' "${1:-default}"
    ;;
  input)
    printf '%s\n' "${GUM_MOCK_INPUT:-test-input}"
    ;;
  confirm)
    return "${GUM_MOCK_CONFIRM:-0}"
    ;;
  spin)
    # Strip gum spin args, run the command after --
    while [[ "$1" != "--" && $# -gt 0 ]]; do shift; done
    shift  # skip --
    "$@"
    ;;
  log)
    shift  # skip 'log'
    while [[ "$1" == -* ]]; do shift; done
    printf '%s\n' "$*" >&2
    ;;
  style)
    shift
    while [[ "$1" == -* ]]; do shift; done
    printf '%s\n' "$*"
    ;;
  *)
    printf 'mock-gum: unknown subcommand: %s\n' "$1" >&2
    exit 1
    ;;
esac
```

### Using the mock

```bash
# In test setup, prepend mock to PATH
setup() {
  chmod +x "${MOCK_DIR}/gum"
  export PATH="${MOCK_DIR}:${PATH}"
  export GUM_MOCK_INPUT="1.0.0"
  export GUM_MOCK_CONFIRM=0
}
```

## Testing Cleanup Traps

```bash
@test "cleanup removes temp directory" {
  local test_dir="${TEST_TEMP}/cleanup_test"
  mkdir -p "${test_dir}"

  # Simulate script with cleanup
  run bash -c "
    TMP_DIR='${test_dir}'
    cleanup() {
      rm -rf -- \"\${TMP_DIR}\"
    }
    trap cleanup EXIT
    exit 0
  "

  [ "$status" -eq 0 ]
  [ ! -d "${test_dir}" ]
}

@test "cleanup preserves exit code" {
  run bash -c "
    cleanup() { local c=\$?; exit \$c; }
    trap cleanup EXIT
    exit 42
  "

  [ "$status" -eq 42 ]
}
```

## Testing Error Handling

```bash
@test "retry_with_backoff succeeds on second attempt" {
  local attempt_file="${TEST_TEMP}/attempts"
  printf '0\n' > "${attempt_file}"

  fail_once() {
    local count
    count="$(<"${attempt_file}")"
    ((count++))
    printf '%s\n' "${count}" > "${attempt_file}"
    (( count >= 2 ))  # Succeed on second attempt
  }

  source_lib "error-resilience.sh"
  run retry_with_backoff 3 0.1 fail_once
  [ "$status" -eq 0 ]

  local final_count
  final_count="$(<"${attempt_file}")"
  [ "${final_count}" -eq 2 ]
}

@test "retry_with_backoff fails after max attempts" {
  source_lib "error-resilience.sh"
  run retry_with_backoff 2 0.1 false
  [ "$status" -ne 0 ]
}
```

## Running Tests

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/validate.bats

# Verbose output
bats --verbose-run tests/

# TAP format (for CI)
bats --formatter tap tests/
```

## Best Practices

1. **Isolate tests**: each test gets its own temp directory via `setup`/`teardown`.
2. **Mock external tools**: prepend `tests/mocks/` to `$PATH` instead of stubbing functions.
3. **Test failure paths**: verify that scripts fail correctly, not just succeed.
4. **Use `run`**: always wrap function calls in `run` to capture status and output.
5. **Override `die`**: replace `die()` in tests to prevent `exit` from killing the test runner.
6. **Force non-interactive**: set `FORCE_NONINTERACTIVE=1` to bypass Gum prompts.
7. **Keep tests fast**: use `sleep 0.1` or smaller for retry/backoff tests.

## Testing TUI with Expect

For complex interactive prompts that BATS cannot simulate (password prompts,
multi-step wizards, SSH sessions), use `expect`:

```bash
#!/usr/bin/expect -f
# test_wizard.exp — Test a gum-based wizard flow
set timeout 10

spawn bash ./wizard.sh

# Wait for gum choose menu
expect "Select environment"
send -- "\r"

# Wait for gum input prompt
expect "Enter version"
send -- "1.2.3\r"

# Wait for gum confirm
expect "Deploy?"
send -- "y\r"

expect eof
catch wait result
set exit_code [lindex $result 3]

if {$exit_code != 0} {
  puts "FAIL: wizard exited with code $exit_code"
  exit 1
}
puts "PASS: wizard completed successfully"
```

### When to Use Each

| Scenario | Tool | Why |
| --- | --- | --- |
| Pure function logic | **BATS** | Fast, no UI needed |
| Gum prompts with mocks | **BATS + mock** | Deterministic, PATH override |
| Multi-step interactive flow | **Expect** | Simulates real user input |
| Visual rendering validation | **VHS** | Generates recording for review |

## See Also

- [quality-pipeline.md](quality-pipeline.md) — Full pipeline: shfmt → ShellCheck → BATS → VHS
- [shellcheck-integration.md](shellcheck-integration.md) — Static analysis config
- [charm-suite.md](charm-suite.md) — VHS tape language and visual testing
