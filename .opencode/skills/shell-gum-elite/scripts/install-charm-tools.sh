#!/usr/bin/env bash
# install-charm-tools.sh — Instala ferramentas Charmbracelet opcionais
# Parte da skill shell-gum-elite
#
# Uso:
#   bash scripts/install-charm-tools.sh                  # Modo interativo (Gum)
#   bash scripts/install-charm-tools.sh --tool glow      # Instala uma ferramenta
#   bash scripts/install-charm-tools.sh --all            # Instala todas
#   bash scripts/install-charm-tools.sh --check          # Verifica instaladas
#   bash scripts/install-charm-tools.sh --help           # Ajuda

set -euo pipefail

# ============================================================================
# Constantes
# ============================================================================

readonly CHARM_TOOLS=(
  "gum:Interatividade terminal (menus, inputs, spinners)"
  "glow:Renderizador de Markdown no terminal"
  "mods:LLM no terminal (requer API key)"
  "freeze:Screenshots de código/terminal (PNG/SVG)"
  "vhs:Gravação de demos terminal (GIF/MP4)"
  "skate:Key-value store criptografado"
)

# ============================================================================
# Helpers
# ============================================================================

_has_gum() { command -v gum &>/dev/null; }

log_info() { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
log_success() { printf '\033[0;32m[OK]\033[0m   %s\n' "$*"; }
log_warn() { printf '\033[0;33m[WARN]\033[0m %s\n' "$*"; }
log_error() { printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }

# ============================================================================
# Detecção do sistema
# ============================================================================

detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)             echo "unknown" ;;
  esac
}

# ============================================================================
# Verificação de ferramentas
# ============================================================================

check_tools() {
  local installed=0
  local missing=0

  log_info "Verificando ferramentas Charmbracelet..."
  printf '\n'

  local entry name desc
  for entry in "${CHARM_TOOLS[@]}"; do
    name="${entry%%:*}"
    desc="${entry#*:}"
    if command -v "${name}" &>/dev/null; then
      local ver=""
      ver="$("${name}" --version 2>/dev/null | head -1 || echo "?")"
      log_success "${name} — ${desc} [${ver}]"
      (( installed++ ))
    else
      log_warn "${name} — ${desc} [NÃO INSTALADO]"
      (( missing++ ))
    fi
  done

  printf '\n'
  log_info "Instaladas: ${installed} | Faltando: ${missing}"
}

# ============================================================================
# Instalação via go install
# ============================================================================

install_via_go() {
  local tool="${1:?}"

  if ! command -v go &>/dev/null; then
    log_error "Go não encontrado. Instale: https://go.dev/dl/"
    log_info "Alternativa: brew install ${tool} (macOS) ou veja https://charm.sh"
    return 1
  fi

  local repo
  case "${tool}" in
    gum)    repo="github.com/charmbracelet/gum@latest" ;;
    glow)   repo="github.com/charmbracelet/glow@latest" ;;
    mods)   repo="github.com/charmbracelet/mods@latest" ;;
    freeze) repo="github.com/charmbracelet/freeze@latest" ;;
    vhs)    repo="github.com/charmbracelet/vhs@latest" ;;
    skate)  repo="github.com/charmbracelet/skate@latest" ;;
    *)
      log_error "Ferramenta desconhecida: ${tool}"
      return 1
      ;;
  esac

  log_info "Instalando ${tool} via go install..."

  if _has_gum; then
    gum spin --spinner dot --title "Instalando ${tool}..." -- \
      go install "${repo}"
  else
    go install "${repo}"
  fi

  if command -v "${tool}" &>/dev/null; then
    log_success "${tool} instalado com sucesso"
  else
    log_warn "${tool} instalado, mas não encontrado no PATH"
    log_info "Verifique se \$(go env GOPATH)/bin está no PATH"
  fi
}

# ============================================================================
# Instalação via Homebrew (macOS / Linux)
# ============================================================================

install_via_brew() {
  local tool="${1:?}"

  if ! command -v brew &>/dev/null; then
    log_warn "Homebrew não encontrado. Tentando go install..."
    install_via_go "${tool}"
    return
  fi

  log_info "Instalando ${tool} via Homebrew..."

  if _has_gum; then
    gum spin --spinner dot --title "Instalando ${tool}..." -- \
      brew install "${tool}"
  else
    brew install "${tool}"
  fi

  if command -v "${tool}" &>/dev/null; then
    log_success "${tool} instalado com sucesso"
  else
    log_error "Falha ao instalar ${tool}"
    return 1
  fi
}

# ============================================================================
# Motor de instalação
# ============================================================================

install_tool() {
  local tool="${1:?}"

  # Já instalado?
  if command -v "${tool}" &>/dev/null; then
    log_success "${tool} já está instalado"
    return 0
  fi

  # Detectar método preferido
  if command -v brew &>/dev/null; then
    install_via_brew "${tool}"
  elif command -v go &>/dev/null; then
    install_via_go "${tool}"
  else
    log_error "Nenhum gerenciador encontrado (brew ou go)"
    log_info "Instale manualmente: https://charm.sh"
    return 1
  fi
}

install_all() {
  local entry name
  for entry in "${CHARM_TOOLS[@]}"; do
    name="${entry%%:*}"
    install_tool "${name}" || true
  done
}

# ============================================================================
# Modo interativo
# ============================================================================

interactive_install() {
  if ! _has_gum; then
    log_error "Gum necessário para modo interativo"
    log_info "Use: --tool NOME ou --all"
    return 1
  fi

  # Montar lista com status
  local -a options=()
  local entry name desc
  for entry in "${CHARM_TOOLS[@]}"; do
    name="${entry%%:*}"
    desc="${entry#*:}"
    if command -v "${name}" &>/dev/null; then
      options+=("✅ ${name} — ${desc}")
    else
      options+=("⬜ ${name} — ${desc}")
    fi
  done

  local selection
  selection="$(gum choose --no-limit \
    --header "Selecione ferramentas Charm para instalar:" \
    --cursor.foreground "#FFB703" \
    --selected.foreground "#2EC4B6" \
    "${options[@]}")" || return 0

  [[ -z "${selection}" ]] && {
    log_info "Nenhuma ferramenta selecionada"
    return 0
  }

  local line tool_name
  while IFS= read -r line; do
    # Extrair nome: "⬜ glow — desc" -> "glow"
    tool_name="${line#* }"
    tool_name="${tool_name%% —*}"
    tool_name="${tool_name## }"

    if [[ "${line}" == ✅* ]]; then
      log_success "${tool_name} já instalado — pulando"
    else
      install_tool "${tool_name}"
    fi
  done <<< "${selection}"
}

# ============================================================================
# Ajuda
# ============================================================================

show_help() {
  cat <<'EOF'
install-charm-tools.sh — Instala ferramentas Charmbracelet

MODOS:
  (sem args)          Modo interativo (requer gum)
  --tool NOME         Instala ferramenta específica
  --all               Instala todas as ferramentas
  --check             Verifica ferramentas instaladas
  --help              Mostra esta ajuda

FERRAMENTAS:
  gum     Interatividade terminal (menus, inputs, spinners)
  glow    Renderizador de Markdown no terminal
  mods    LLM no terminal (requer API key)
  freeze  Screenshots de código/terminal (PNG/SVG)
  vhs     Gravação de demos terminal (GIF/MP4)
  skate   Key-value store criptografado

EXEMPLOS:
  bash scripts/install-charm-tools.sh --check
  bash scripts/install-charm-tools.sh --tool glow
  bash scripts/install-charm-tools.sh --all
EOF
}

# ============================================================================
# Main
# ============================================================================

main() {
  case "${1:-}" in
    --help|-h)
      show_help
      ;;
    --check)
      check_tools
      ;;
    --tool)
      [[ -z "${2:-}" ]] && {
        log_error "Uso: --tool NOME"
        return 1
      }
      install_tool "${2}"
      ;;
    --all)
      install_all
      ;;
    "")
      interactive_install
      ;;
    *)
      log_error "Opção desconhecida: ${1}"
      show_help
      return 1
      ;;
  esac
}

main "$@"
