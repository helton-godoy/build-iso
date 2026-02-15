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

## Ecosystem Synergy

This skill builds on top of — and works best alongside — two complementary skills:

| Skill | Synergy |
|---|---|
| `pure-bash-bible` | Foundation for all native Bash patterns (strings, arrays, files, arithmetic). This skill extends those foundations into real-world script architecture. |
| `gum-ui` | Complete reference for every Gum subcommand and parameter. This skill curates the most impactful patterns and adds composition, theming, and CI adaptation on top. |
| `git-master` | Shell automation often orchestrates Git operations. Combined pattern: robust script flow + premium UX prompts + correct Git workflows. |

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
FORCE_NONINTERACTIVE=0    # Force non-interactive mode (for CI)

# Gum style baseline (override per script or via theme.conf)
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
SCRIPT_NAME="${0##*/}"
readonly SCRIPT_NAME

cleanup() {
  local code=$?
  [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]] && rm -rf -- "${TMP_DIR}"
  [[ -n "${LOCK_FILE:-}" && -f "${LOCK_FILE}" ]] && rm -f "${LOCK_FILE}"
  exit "$code"
}
trap cleanup EXIT INT TERM

# Adaptive: works in both interactive and CI modes
is_interactive() { [[ "${FORCE_NONINTERACTIVE:-0}" -eq 0 && -t 0 && -t 1 ]]; }

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
| Resilience | `retry_with_backoff` + `error_trap` + `die()` | Production-grade error recovery |
| Input UX | `gum choose`, `gum input`, `gum write`, `gum filter` | Human-in-the-loop control |
| Feedback UX | `gum style`, `gum log`, `gum spin`, `gum table` | Premium CLI readability |
| Progress | `gum progress`, wizard headers, step counters | Clear completion tracking |
| Composition | `gum join`, `gum style` boxes, dashboards | Rich multi-component layouts |
| CI mode | `is_interactive()` + `adaptive_*` wrappers | Graceful degradation in headless envs |
| CLI parsing | `while/case` + hybrid Gum fallback | Robust arg handling with interactive fill |
| Configuration | `.env` loader + hierarchy + themes | Flexible, layered settings |
| Logging | `gum log` (terminal) + `printf` (file) | Dual-channel for debug and audit |
| Concurrency | Worker pool + `wait` + lock files | Safe parallel execution |
| Testing | Bats + Gum mocks + cleanup traps | Reliable automated validation |
| Static analysis | ShellCheck `-x` + `.shellcheckrc` + CI gates | Catch bugs before runtime |
| Docker scripting | Build/exec/health wrappers + Gum feedback | Orchestrate containers safely |
| Portability | OS detection + GNU/BSD fallbacks + version gates | Cross-platform reliability |
| Naming | `verb_object()` + `SCREAMING_SNAKE` + guard clauses | Self-documenting code |
| Git hooks | Pre-commit (lint) + pre-push (test) + version tags | Automated quality gates |
| Gum reference | Complete flags/env vars + enum catalogs | No guessing, exact API |
| Theme gallery | Named palettes + 60-30-10 rule + Nerd Font icons | Premium visual design |
| Charm suite | glow + mods + freeze + vhs + skate integration | Full Charm Stack apps |
| Quality pipeline | shfmt + ShellCheck + BATS + VHS orchestration | Automated quality gates |

## Embedded Tools

| Script | Usage | Purpose |
| --- | --- | --- |
| [scripts/install-nerd-fonts.sh](scripts/install-nerd-fonts.sh) | `bash scripts/install-nerd-fonts.sh` | Install Nerd Fonts for terminal UX (interactive or `--font NAME`) |
| [scripts/install-charm-tools.sh](scripts/install-charm-tools.sh) | `bash scripts/install-charm-tools.sh` | Install Charm tools: glow, mods, freeze, vhs (interactive or `--tool NAME`) |

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
  - Use `gum progress` for operations with known step counts.
  - Confirm destructive operations.
- Accessibility
  - Never rely only on color; include icon/text prefixes (`[OK]`, `[ERR]`).
  - Support `NO_COLOR` and `TERM=dumb` environments.
- Theming
  - Load from `theme.conf` with fallback to default palette.
  - Allow per-project and per-user theme overrides.

## Script Architecture Standards

1. Split scripts into `lib/` modules (`ui.sh`, `log.sh`, `validate.sh`, `platform.sh`, `guards.sh`, `config.sh`).
2. Keep `main.sh` thin: parse args, orchestrate, call pure functions.
3. Use `readonly` constants and explicit return codes.
4. Support `--verbose`, `--debug`, and `--help` without changing business logic.
5. Handle signals (`INT`, `TERM`, `EXIT`, `ERR`) with deterministic cleanup.
6. Keep external dependencies optional; fail with clear installation hints.
7. Support both interactive and non-interactive (CI) execution.
8. Use hierarchical config: defaults → file → env vars → CLI args.
9. Log to both terminal (Gum) and file (printf) for audit trails.

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
- Mock Gum: prepend `tests/mocks/` to `$PATH` for deterministic tests
- Force non-interactive: `FORCE_NONINTERACTIVE=1 bats tests/`
- Pipeline:

```bash
shellcheck -x scripts/*.sh lib/*.sh
bats tests
```

## Best Practices

1. Default to pure Bash substitutions before calling external tools.
2. Keep user decisions explicit with Gum prompts.
3. Wrap risky operations with `gum confirm` and exit code checks.
4. Use structured logs over ad-hoc `echo` statements.
5. Always provide non-interactive fallbacks for CI environments.
6. Parse CLI args with `while/case`; fill missing values via Gum interactively.
7. Use precondition guards (`require_cmd`, `require_root`, `require_bash_version`).
8. Implement retry with backoff for network and flaky operations.
9. Log to file for operations that need audit trails.
10. Load themes from config files for consistent branding across scripts.
11. Use lock files to prevent concurrent execution of critical scripts.
12. Test with Bats: mock Gum, test cleanup traps, verify error paths.
13. Add version gates (`gum version-check`) when script behavior depends on CLI flags.
14. Keep docs and test scenarios synchronized with real command syntax.

## Reference Files

| File | Contents |
|---|---|
| [references/pure-bash-patterns.md](references/pure-bash-patterns.md) | Native Bash techniques from pure-bash-bible principles |
| [references/gum-ux-patterns.md](references/gum-ux-patterns.md) | Command-to-UX mapping for polished interactions |
| [references/script-architecture.md](references/script-architecture.md) | Modular structure, logging, signals, troubleshooting modes |
| [references/design-system.md](references/design-system.md) | Premium terminal visual system and accessibility rules |
| [references/acceptance-criteria.md](references/acceptance-criteria.md) | Validation checklist with correct/incorrect patterns |
| [references/ci-noninteractive.md](references/ci-noninteractive.md) | CI and non-interactive mode: detection, adaptive wrappers, fallbacks |
| [references/cli-parsing.md](references/cli-parsing.md) | CLI argument parsing: while/case, hybrid Gum, auto-help |
| [references/error-resilience.md](references/error-resilience.md) | Error handling: retry, backoff, stack trace, guards, safe temp files |
| [references/advanced-composition.md](references/advanced-composition.md) | Progress bars, wizards, dashboards, tables, file picker, pipe/stdin |
| [references/configuration-logging.md](references/configuration-logging.md) | Config hierarchy, dual logging, theming, log rotation |
| [references/concurrency-patterns.md](references/concurrency-patterns.md) | Parallel execution, worker pools, timeouts, lock files |
| [references/bats-testing.md](references/bats-testing.md) | Bats testing: mocking Gum, cleanup traps, error handling tests |
| [references/shellcheck-integration.md](references/shellcheck-integration.md) | ShellCheck config, error codes, CI integration, Gum suppressions |
| [references/docker-scripting.md](references/docker-scripting.md) | Docker CLI scripting: build, exec, health check, volumes with Gum UX |
| [references/gum-reference.md](references/gum-reference.md) | Complete cheat sheet: flags, env vars, enum catalogs for all subcommands |
| [references/theme-gallery.md](references/theme-gallery.md) | Named palettes, 60-30-10 rule, Nerd Font icons, kmscon TTY integration |
| [references/charm-suite.md](references/charm-suite.md) | Charm Stack: glow, mods, freeze, vhs, skate integration patterns |
| [references/quality-pipeline.md](references/quality-pipeline.md) | Quality pipeline: shfmt, orchestration, CI, ShellSpec comparison |
