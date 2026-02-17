# Charm Suite Integration

## Objective

Patterns for integrating Charmbracelet tools beyond Gum: **glow** (markdown),
**mods** (LLM), **freeze** (screenshots), **vhs** (recordings), and **skate**
(key-value store). All orchestrated from Pure Bash scripts.

## Tool Overview

| Tool | Function | Install |
| --- | --- | --- |
| **gum** | Input/UI (menus, spinners, forms) | `go install github.com/charmbracelet/gum@latest` |
| **glow** | Render markdown in terminal | `go install github.com/charmbracelet/glow@latest` |
| **mods** | LLM queries from CLI | `go install github.com/charmbracelet/mods@latest` |
| **freeze** | Code/output screenshots (PNG/SVG) | `go install github.com/charmbracelet/freeze@latest` |
| **vhs** | Record terminal sessions (GIF/MP4) | `go install github.com/charmbracelet/vhs@latest` |
| **skate** | Encrypted key-value store | `go install github.com/charmbracelet/skate@latest` |

## Charm Check (Graceful Degradation)

Always verify tool availability before using. Degrade gracefully.

```bash
# Check Charm tools and report missing ones
check_charm_tools() {
  local -a required=("gum")
  local -a optional=("glow" "mods" "freeze" "vhs")
  local missing=0

  for tool in "${required[@]}"; do
    command -v "${tool}" &>/dev/null || {
      log_error "Obrigatório: ${tool} não encontrado"
      (( missing++ ))
    }
  done

  (( missing > 0 )) && return 1

  for tool in "${optional[@]}"; do
    command -v "${tool}" &>/dev/null || {
      log_warn "${tool} não encontrado — recurso desativado"
    }
  done
}
```

## glow — Markdown Renderer

### Key Flags

| Flag | Description |
| --- | --- |
| `-s, --style <theme>` | Theme: `dark`, `light`, `auto`, or custom `.json` |
| `-w, --width <n>` | Force line wrap at N columns |
| `-p, --pager` | Open in scrollable pager mode |

### Rich Help Screen

```bash
show_help() {
  if command -v glow &>/dev/null; then
    glow -s dark -w "$(tput cols)" <<'HELP'
# 🚀 My CLI Tool

> Built with Gum & Glow

## Commands
* **install** — Install dependencies
* **deploy** — Deploy to production _(requires API key)_
* **status** — Show current state

## Environment
* `API_KEY` — Authentication token
* `ENV` — Target environment (dev/stage/prod)
HELP
  else
    # Plain text fallback
    printf '%s\n' "Usage: $0 {install|deploy|status}" \
                   "Set API_KEY and ENV before running."
  fi
}
```

### Documentation Viewer

```bash
# Display README.md or CHANGELOG.md with paging
show_docs() {
  local doc="${1:-README.md}"
  if command -v glow &>/dev/null; then
    glow -s dark -p "${doc}"
  else
    cat "${doc}" | less
  fi
}
```

## mods — LLM in the Terminal

### Key Flags

| Flag | Description |
| --- | --- |
| `-m, --model <id>` | Model: `gpt-4`, `gpt-3.5-turbo`, local via LocalAI |
| `--role <role>` | System persona (configured in `~/.config/mods/mods.yml`) |
| `-f, --format` | Render response as formatted markdown |
| `--no-limit` | Remove token limit (watch costs) |

### Prerequisites

```bash
require_mods() {
  command -v mods &>/dev/null || {
    log_error "mods não encontrado. Instale: go install github.com/charmbracelet/mods@latest"
    return 1
  }
  [[ -n "${OPENAI_API_KEY:-}" ]] || {
    log_warn "OPENAI_API_KEY não definida — mods pode não funcionar"
  }
}
```

### Gum + Mods Pipeline

```bash
# Smart commit message generator
smart_commit() {
  require_mods || return 1

  local description
  description="$(gum input --placeholder "O que você fez?")"
  [[ -n "${description}" ]] || return 0

  local commit_msg
  commit_msg="$(mods "Gere uma mensagem de commit convencional (feat/fix/chore) para: ${description}. Somente a mensagem, sem explicação.")"

  gum style --border rounded --padding "1 2" \
    --border-foreground "${COLOR_ACCENT:-#FFB703}" \
    "${commit_msg}"

  gum confirm "Commitar com esta mensagem?" && \
    git commit -m "${commit_msg}"
}
```

### Log Analysis

```bash
# Analyze error logs with AI
analyze_errors() {
  local log_file="${1:?Uso: analyze_errors <arquivo.log>}"
  local tail_lines="${2:-20}"

  local errors
  errors="$(tail -n "${tail_lines}" "${log_file}")"

  local analysis
  if _has_gum; then
    analysis="$(gum spin --spinner dot --title "Analisando erros..." -- \
      bash -c "echo '${errors}' | mods 'Analise estes erros e sugira correções em bash. Seja breve.'")"
  else
    analysis="$(echo "${errors}" | mods "Analise e sugira correções. Breve.")"
  fi

  gum style --border rounded --padding "1 2" "${analysis}"
}
```

## freeze — Code Screenshots

### Key Flags

| Flag | Description |
| --- | --- |
| `--theme <name>` | Syntax theme: `dracula`, `charm`, `catppuccin-mocha` |
| `--language <lang>` | Force syntax highlighting language |
| `--window` | Add macOS-style window buttons |
| `--output <file>` | Output path (.png, .svg) |
| `--execute "cmd"` | Capture command output instead of file |

### Deploy Report

```bash
# Generate visual report of deployment
deploy_report() {
  local version="${1:?}"
  local env="${2:?}"
  local report_file="/tmp/deploy_report.json"

  cat > "${report_file}" <<EOF
{
  "status": "success",
  "version": "${version}",
  "environment": "${env}",
  "deployed_at": "$(date -Iseconds)",
  "deployed_by": "$(whoami)"
}
EOF

  if command -v freeze &>/dev/null; then
    freeze "${report_file}" \
      --language json \
      --theme dracula \
      --window \
      --output "deploy_${version}.png"
    log_success "Relatório visual: deploy_${version}.png"
  else
    cat "${report_file}"
  fi

  rm -f "${report_file}"
}
```

## vhs — Terminal Recording

### Tape Language

| Command | Description |
| --- | --- |
| `Output <file.gif>` | Set output file |
| `Set Shell bash` | Target shell |
| `Set FontSize <n>` | Font size |
| `Set Width <n>` / `Set Height <n>` | Window dimensions |
| `Set Theme "Name"` | Terminal theme |
| `Type "text"` | Simulate typing |
| `Enter` | Press Enter |
| `Sleep <duration>` | Pause (e.g., `500ms`, `2s`) |
| `Ctrl+C`, `Up`, `Down`, `Tab` | Special keys |
| `Hide` / `Show` | Toggle command visibility |

### Demo Generator

```bash
# Generate a .tape file for a script demo
generate_demo_tape() {
  local script_name="${1:?}"
  local output_gif="${2:-demo.gif}"

  cat <<EOF
Output ${output_gif}
Set FontSize 16
Set Width 1200
Set Height 600
Set Theme "Catppuccin Mocha"
Set Shell "bash"

# Title
Type "# Demo: ${script_name}"
Enter
Sleep 1s

# Run the script
Type "./${script_name}"
Enter
Sleep 2s

# Navigate menu (if gum choose)
Down
Sleep 500ms
Down
Sleep 500ms
Enter
Sleep 3s
EOF
}

# Usage: generate_demo_tape "my-tool.sh" > demo.tape && vhs demo.tape
```

### VHS for Visual Testing

```bash
# Test that a gum menu renders correctly
generate_test_tape() {
  local script_name="${1:?}"

  cat <<EOF
Output /tmp/test_output.gif
Set FontSize 14
Set Width 800
Set Height 400
Set Shell "bash"

Type "./${script_name} --menu"
Enter
Sleep 1s

# Validate: menu should be visible
# Select first option
Enter
Sleep 1s
EOF
}
```

## skate — Key-Value Store (Experimental)

Encrypted personal key-value store. Use for persistent user preferences.

```bash
# Save user theme preference
save_preference() {
  command -v skate &>/dev/null || return 1
  skate set "theme" "${1:?}"
}

# Load user theme preference
load_preference() {
  command -v skate &>/dev/null || {
    echo "catppuccin"  # Default
    return
  }
  skate get "theme" 2>/dev/null || echo "catppuccin"
}
```

## Charm Stack Workflow

The integrated workflow for building rich CLI applications:

```text
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  1. GUM  │───▶│ 2. MODS  │───▶│ 3. GLOW  │───▶│ 4.FREEZE │───▶│  5. VHS  │
│  Input   │    │  Process │    │  Display │    │ Artifact │    │  Demo    │
│  UI/UX   │    │  AI/LLM  │    │ Markdown │    │ PNG/SVG  │    │ GIF/MP4  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
```

1. **Entrada** — `gum` captura dados do usuário
2. **Processamento** — `mods` analisa/gera texto (se complexo)
3. **Exibição** — `glow` renderiza resultados longos ou docs
4. **Artefato** — `freeze` salva resultado visual como imagem
5. **Documentação** — `vhs` gera GIF/demo do fluxo completo

> **Princípio:** Cada ferramenta é opcional. O script deve funcionar apenas
> com `gum` e degradar graciosamente quando as demais não existirem.

## See Also

- [gum-reference.md](gum-reference.md) — Complete Gum flags/env vars/enums
- [quality-pipeline.md](quality-pipeline.md) — Quality workflow with VHS testing
- [bats-testing.md](bats-testing.md) — Unit testing with BATS + Gum mocks
