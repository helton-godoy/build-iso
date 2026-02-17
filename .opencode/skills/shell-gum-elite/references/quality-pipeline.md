# Quality Pipeline

## Objective

Orchestrate a complete quality pipeline for Bash + Gum scripts: static analysis
(ShellCheck + shfmt), unit tests (BATS), and visual tests (VHS). This ref ties
together the individual tools documented in other references.

## The Pipeline

```text
┌────────────┐    ┌────────────┐    ┌────────────┐    ┌────────────┐
│  1. shfmt  │───▶│ 2.ShellCk  │───▶│  3. BATS   │───▶│  4. VHS    │
│  Format    │    │  Lint      │    │  Unit Test │    │ Visual Test│
│  Style     │    │  Bugs      │    │  Logic     │    │ TUI (opt)  │
└────────────┘    └────────────┘    └────────────┘    └────────────┘
```

## Step 1: shfmt (Code Formatting)

### What It Does

Like Prettier for shell. Enforces consistent formatting automatically.

### Configuration via `.editorconfig`

```ini
# .editorconfig — shfmt reads this automatically
[*.sh]
indent_style = space
indent_size = 2
shell_variant = bash
binary_next_line = true
switch_case_indent = true
space_redirects = true
keep_padding = false
```

### Key Flags

| Flag | Description |
| --- | --- |
| `-i 2` | Indent with 2 spaces |
| `-bn` | Binary ops (`&&`, `\|\|`) start next line |
| `-ci` | Indent switch cases |
| `-sr` | Space after redirect (`> file` not `>file`) |
| `-w` | Write changes in-place |
| `-d` | Diff mode (show what would change) |
| `-l` | List files that differ |
| `-ln bash` | Language variant (bash, posix, mksh) |

### Usage Patterns

```bash
# Check formatting without modifying (CI-friendly)
shfmt -d -i 2 -bn -ci scripts/

# Format all scripts in-place
shfmt -w -i 2 -bn -ci scripts/

# Format only changed files
git diff --name-only --diff-filter=ACM | grep '\.sh$' | xargs shfmt -w -i 2

# Verify formatting in CI (exits non-zero if unformatted)
shfmt -d scripts/ || { echo "Run: shfmt -w scripts/"; exit 1; }
```

## Step 2: ShellCheck (Static Analysis)

See [shellcheck-integration.md](shellcheck-integration.md) for complete
configuration, error codes, and CI patterns.

**Quick command:**

```bash
shellcheck -x scripts/*.sh
```

## Step 3: BATS (Unit Testing)

See [bats-testing.md](bats-testing.md) for test structure, Gum mocking,
cleanup traps, and error handling tests.

**Quick command:**

```bash
bats tests/
```

## Step 4: VHS (Visual Testing — Optional)

See [charm-suite.md](charm-suite.md) for VHS tape language and demo generation.

Use VHS to validate that TUI elements render correctly:

```bash
# Generate test tape, run it, verify output exists
generate_test_tape "my-script.sh" > /tmp/test.tape
vhs /tmp/test.tape
[[ -f /tmp/test_output.gif ]] && echo "Visual test passed"
```

## Orchestration Script

A single function to run the complete pipeline:

```bash
# Run the full quality pipeline
quality_check() {
  local target="${1:-.}"
  local failed=0

  log_info "═══ Quality Pipeline ═══"

  # 1. Format
  if command -v shfmt &>/dev/null; then
    log_info "[1/4] shfmt — verificando formatação..."
    if ! shfmt -d -i 2 -bn -ci "${target}"; then
      log_warn "Formatação inconsistente. Rode: shfmt -w -i 2 -bn -ci ${target}"
      (( failed++ ))
    else
      log_success "Formatação OK"
    fi
  else
    log_warn "[1/4] shfmt não encontrado — pulando"
  fi

  # 2. Lint
  log_info "[2/4] ShellCheck — análise estática..."
  if ! find "${target}" -name '*.sh' -not -path '*/mocks/*' -print0 \
       | xargs -0 shellcheck -x 2>/dev/null; then
    log_error "ShellCheck encontrou problemas"
    (( failed++ ))
  else
    log_success "ShellCheck OK"
  fi

  # 3. Unit tests
  if command -v bats &>/dev/null && [[ -d "tests" ]]; then
    log_info "[3/4] BATS — testes unitários..."
    if ! bats tests/; then
      log_error "Testes falharam"
      (( failed++ ))
    else
      log_success "Testes OK"
    fi
  else
    log_warn "[3/4] BATS não encontrado ou sem diretório tests/ — pulando"
  fi

  # 4. Visual tests (optional)
  if command -v vhs &>/dev/null && compgen -G "tests/*.tape" &>/dev/null; then
    log_info "[4/4] VHS — testes visuais..."
    local tape
    for tape in tests/*.tape; do
      vhs "${tape}" || (( failed++ ))
    done
    log_success "Testes visuais OK"
  else
    log_warn "[4/4] VHS/tapes não encontrados — pulando"
  fi

  # Summary
  printf '\n'
  if (( failed > 0 )); then
    log_error "Pipeline: ${failed} etapa(s) com falha"
    return 1
  else
    log_success "Pipeline: todas as etapas passaram ✓"
  fi
}
```

## CI Integration

### GitHub Actions

```yaml
name: Quality Pipeline
on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tools
        run: |
          sudo apt-get install -y shellcheck
          go install mvdan.cc/sh/v3/cmd/shfmt@latest
          sudo npm install -g bats

      - name: Format check
        run: shfmt -d -i 2 -bn -ci scripts/

      - name: Lint
        run: |
          find . -name '*.sh' -not -path '*/mocks/*' \
            | xargs shellcheck -x --format=gcc

      - name: Unit tests
        run: bats tests/
```

### Pre-commit Hook

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit — format + lint staged scripts
set -euo pipefail

mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACM \
  | grep '\.sh$' || true)

(( ${#staged[@]} == 0 )) && exit 0

# Format check
if command -v shfmt &>/dev/null; then
  shfmt -d -i 2 -bn -ci "${staged[@]}" || {
    printf 'Fix: shfmt -w -i 2 -bn -ci %s\n' "${staged[*]}"
    exit 1
  }
fi

# Lint
shellcheck -x "${staged[@]}"
```

## ShellSpec (BDD Alternative)

For teams preferring BDD-style tests, ShellSpec offers English-like syntax:

```bash
# spec/deploy_spec.sh
Describe 'deploy.sh'
  Include lib/validate.sh

  Describe 'validate_semver'
    It 'accepts valid versions'
      When call validate_semver "1.2.3"
      The status should be success
    End

    It 'rejects invalid versions'
      When call validate_semver "not-valid"
      The status should be failure
    End
  End
End
```

### BATS vs ShellSpec

| Aspect | BATS | ShellSpec |
| --- | --- | --- |
| Syntax | `@test "name" { ... }` | `Describe/It/End` blocks |
| Style | xUnit | BDD (Behavior Driven) |
| Mocking | Manual (PATH override) | Built-in `Mock` command |
| Ecosystem | Larger, more plugins | Smaller, more built-ins |
| Learning curve | Lower | Higher |
| **Recommendation** | Default choice | When BDD readability matters |

> **Guidance:** Start with BATS. Switch to ShellSpec only if your team
> strongly prefers BDD style or needs built-in mocking.

## See Also

- [shellcheck-integration.md](shellcheck-integration.md) — Full ShellCheck config
- [bats-testing.md](bats-testing.md) — BATS patterns and Gum mocking
- [charm-suite.md](charm-suite.md) — VHS tape language and Charm Stack workflow
