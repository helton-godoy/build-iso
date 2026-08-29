# Bash toolchain and installation

## Roles

| Tool | Role | Harness authority |
|---|---|---|
| Bash `-n` | Parser-level syntax check | Required |
| ShellCheck | Static analysis and defect patterns | Required |
| shfmt | Parser and deterministic formatting | Required |
| Bats Core | Behavioral regression tests | Required when `.bats` tests exist |
| bash-language-server | Editor diagnostics, navigation, and completion | Interactive only |

The language server is not a CI substitute. Pin tool versions in CI or a development container when reproducibility matters.

## Diagnose first

Run `scripts/bash-doctor`. Run `scripts/bash-doctor --install-plan` to print commands without executing them. Never install packages automatically unless the user explicitly authorizes that external change.

## Installation choices

Prefer the operating-system package manager for ShellCheck and shfmt when it provides an acceptable version. Common commands:

```bash
# Debian/Ubuntu
sudo apt-get install shellcheck shfmt bats

# macOS with Homebrew
brew install shellcheck shfmt bats-core

# shfmt from the Go module
GOBIN="$HOME/.local/bin" go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Project-local LSP and Bats through npm
npm install --save-dev bash-language-server bats
```

Project-local npm dependencies improve version pinning. Configure the editor to start `node_modules/.bin/bash-language-server start`. A global alternative is `npm install --global bash-language-server`, but it is less reproducible.

After installation, rerun `scripts/bash-doctor` and record versions in CI.

## Harness contract

Run `scripts/bash-harness init PROJECT` once to add conservative configuration without overwriting existing files. Existing projects start with `BP_SHELLCHECK_SEVERITY=warning` and `BP_SHFMT_MODE=advisory`; info/style findings are debt to ratchet separately, while warnings/errors block delivery; switch it to `enforce` only after formatting is intentionally adopted. `BP_MAX_FORMAT_LINES` prevents broad automatic rewrites. Run `check` before delivery. Run `fix` only when formatting changes are authorized, inspect the diff, then rerun `check`. Bats files are executed by Bats and are not passed to `bash -n` or shfmt.

Exit codes:

- `0`: every required available check passed.
- `1`: syntax, lint, format, or tests failed.
- `2`: required tooling is missing.
- `64+`: invocation or filesystem error.

The harness discovers `.sh`, `.bash`, `.bats`, and extensionless files with a Bash shebang, excluding `.git`, `.opencode`, `node_modules`, and vendor directories. Add project-specific exclusions by changing the harness rather than silently skipping failures.
