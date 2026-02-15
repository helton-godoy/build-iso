---
name: shell-gum-elite
description: |
  Elite shell scripting with pure Bash foundations plus premium Gum terminal UX.
  Use for: interactive Bash CLIs, safe automation flows, resilient script architecture,
  structured logging, validation loops, and Linux/macOS-compatible terminal tools.
  Triggers: "bash script", "shell automation", "gum menu", "interactive cli",
  "pure bash", "terminal ux", "bats", "shellcheck".
---

# Shell + Gum Elite

## Ecosystem Synergy First

Highest-value complementary skill: `git-master`.

Why it is the best current synergy:
- Shell automation often orchestrates Git operations (`status`, `branch`, `commit`, release tagging).
- `git-master` improves safety and atomicity, while this skill upgrades the interaction layer with Gum.
- Combined pattern: robust script flow in pure Bash + premium UX prompts + correct Git workflows.

## Installation

```bash
# Core runtime
brew install gum shellcheck bats-core   # macOS

# Linux examples
sudo apt install gum shellcheck bats    # Debian/Ubuntu (package names may vary)
sudo dnf install gum ShellCheck bats    # Fedora/RHEL
```

## Environment Variables

```bash
# Script behavior
SCRIPT_VERBOSE=0
SCRIPT_DEBUG=0
SCRIPT_LOG_LEVEL=info
NO_COLOR=0

# Gum style baseline (override per script)
GUM_CHOOSE_CURSOR_FOREGROUND="#FFB703"
GUM_INPUT_PROMPT_FOREGROUND="#8ECAE6"
GUM_CONFIRM_PROMPT_FOREGROUND="#FB8500"
GUM_SPIN_SPINNER="dot"
```

## Core Workflow

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

cleanup() {
  local code=$?
  [[ ${SCRIPT_DEBUG:-0} -eq 1 ]] && printf 'cleanup(exit=%s)\n' "$code" >&2
  exit "$code"
}
trap cleanup EXIT INT TERM

log_info() { gum log --level info -- "${1}"; }
log_warn() { gum log --level warn -- "${1}"; }
log_error() { gum log --level error -- "${1}"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "Missing required command: $1"
    exit 127
  }
}

main() {
  require_cmd gum

  local env
  env="$(gum choose --header "Select environment" dev stage prod)"
  local version
  version="$(gum input --placeholder "Release version (semver)")"

  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || {
    log_error "Invalid semver: $version"
    exit 2
  }

  gum confirm "Deploy $version to $env?" || {
    log_warn "Cancelled by user"
    exit 0
  }

  gum spin --title "Deploying..." -- sleep 1
  log_info "Deployment completed"
}

main "$@"
```

## Feature Map

| Area | Preferred Pattern | Why |
|---|---|---|
| String ops | `${var//x/y}`, `${#var}`, `${var%%pattern}` | Avoid subprocesses and improve speed |
| Data structures | Indexed arrays + associative arrays | Predictable state transitions |
| Arithmetic | `(( ... ))` | Native math and clearer intent |
| Error handling | `set -euo pipefail` + `trap` + explicit exit codes | Fail fast and recover safely |
| Input UX | `gum choose`, `gum input`, `gum write`, `gum filter` | Human-in-the-loop control |
| Feedback UX | `gum style`, `gum log`, `gum spin`, `gum table` | Premium CLI readability |

## Premium Terminal Design System

Use this baseline for visual consistency:

- Palette
  - Primary: `#8ECAE6`
  - Accent: `#FFB703`
  - Success: `#2A9D8F`
  - Warning: `#FB8500`
  - Error: `#D62828`
  - Muted: `#6C757D`
- Typography
  - Keep line length between 72-100 columns.
  - Prefer sentence case labels and short action verbs.
- Spacing
  - 1 blank line between sections.
  - 2 spaces indentation inside status blocks.
- Motion/feedback
  - Always show a spinner for commands > 300ms.
  - Confirm destructive operations.
- Accessibility
  - Never rely only on color; include icon/text prefixes (`[OK]`, `[ERR]`).

## Script Architecture Standards

1. Split scripts into `lib/` modules (`ui.sh`, `log.sh`, `validate.sh`, `platform.sh`).
2. Keep `main.sh` thin: parse args, orchestrate, call pure functions.
3. Use `readonly` constants and explicit return codes.
4. Support `--verbose` and `--debug` without changing business logic.
5. Handle signals (`INT`, `TERM`, `EXIT`) with deterministic cleanup.
6. Keep external dependencies optional; fail with clear installation hints.

## Cross-Platform Rules (Linux/macOS)

- Validate Bash version for features you use (associative arrays require Bash 4+).
- Avoid GNU-only flags unless guarded by compatibility checks.
- Prefer POSIX-safe quoting and `printf` over shell-specific `echo` behavior.
- Detect OS for edge cases:

```bash
case "$(uname -s)" in
  Linux)  platform="linux" ;;
  Darwin) platform="macos" ;;
  *)      platform="unknown" ;;
esac
```

## Testing and Quality Gates

- Lint: `shellcheck -x script.sh`
- Unit/integration tests: `bats tests/**/*.bats`
- Optional format/lint pipeline:

```bash
shellcheck -x scripts/*.sh lib/*.sh
bats tests
```

## Best Practices

1. Default to pure Bash substitutions before calling external tools.
2. Keep user decisions explicit with Gum prompts.
3. Wrap risky operations with `gum confirm` and exit code checks.
4. Use structured logs over ad-hoc `echo` statements.
5. Add version gates (`gum version-check`) when script behavior depends on CLI flags.
6. Keep docs and test scenarios synchronized with real command syntax.

## Reference Files

| File | Contents |
|---|---|
| [references/pure-bash-patterns.md](references/pure-bash-patterns.md) | Native Bash techniques from pure-bash-bible principles |
| [references/gum-ux-patterns.md](references/gum-ux-patterns.md) | Command-to-UX mapping for polished interactions |
| [references/script-architecture.md](references/script-architecture.md) | Modular structure, logging, signals, troubleshooting modes |
| [references/design-system.md](references/design-system.md) | Premium terminal visual system and accessibility rules |
| [references/acceptance-criteria.md](references/acceptance-criteria.md) | Validation checklist with correct/incorrect patterns |
