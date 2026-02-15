#!/usr/bin/env bash
# install-nerd-fonts.sh — Instalação interativa de Nerd Fonts para terminal UX
# Parte da skill shell-gum-elite
#
# Uso:
#   bash scripts/install-nerd-fonts.sh                    # Modo interativo (Gum)
#   bash scripts/install-nerd-fonts.sh --font JetBrainsMono  # Modo direto
#   bash scripts/install-nerd-fonts.sh --all              # Instala todas as recomendadas
#   bash scripts/install-nerd-fonts.sh --list             # Lista fonts disponíveis
#   bash scripts/install-nerd-fonts.sh --check            # Verifica fonts instaladas

set -euo pipefail

# ============================================================================
# Constantes
# ============================================================================

readonly NERD_FONTS_VERSION="v3.3.0"
readonly NERD_FONTS_BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}"

# Fonts recomendadas para terminal UX (nome = nome do zip no GitHub)
readonly -a RECOMMENDED_FONTS=(
  "JetBrainsMono"
  "FiraCode"
  "Hack"
  "CascadiaCode"
  "SourceCodePro"
  "UbuntuMono"
  "IBMPlexMono"
  "Meslo"
)

# Diretórios de instalação por OS
declare FONT_DIR=""
declare CACHE_DIR=""

# ============================================================================
# Core: Logging
# ============================================================================

_has_gum() { command -v gum &>/dev/null; }

log_info() {
  if _has_gum; then
    gum log --level info "$@"
  else
    printf '[INFO] %s\n' "$*" >&2
  fi
}

log_warn() {
  if _has_gum; then
    gum log --level warn "$@"
  else
    printf '[WARN] %s\n' "$*" >&2
  fi
}

log_error() {
  if _has_gum; then
    gum log --level error "$@"
  else
    printf '[ERR]  %s\n' "$*" >&2
  fi
}

log_success() {
  if _has_gum; then
    gum log --level info "✓ $*"
  else
    printf '[OK]   ✓ %s\n' "$*" >&2
  fi
}

# ============================================================================
# Core: Dependências e OS
# ============================================================================

require_cmd() {
  command -v "$1" &>/dev/null || {
    log_error "Comando obrigatório não encontrado: $1"
    exit 2
  }
}

detect_os() {
  local uname_out
  uname_out="$(uname -s)"
  case "${uname_out}" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}

setup_dirs() {
  local os
  os="$(detect_os)"

  case "${os}" in
    linux)
      FONT_DIR="${HOME}/.local/share/fonts/NerdFonts"
      ;;
    macos)
      FONT_DIR="${HOME}/Library/Fonts/NerdFonts"
      ;;
    *)
      log_error "Sistema operacional não suportado: ${os}"
      exit 2
      ;;
  esac

  CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/nerd-fonts"
  mkdir -p "${FONT_DIR}" "${CACHE_DIR}"
}

# ============================================================================
# Core: Verificação de fonts
# ============================================================================

is_font_installed() {
  local font_name="$1"
  # Verifica via fc-list se disponível, senão verifica diretório
  if command -v fc-list &>/dev/null; then
    fc-list | grep -qi "${font_name}.*Nerd" && return 0
  fi
  # Fallback: verifica se existem arquivos .ttf ou .otf no diretório
  local count
  count="$(find "${FONT_DIR}" -maxdepth 1 -iname "*${font_name}*NerdFont*" -type f 2>/dev/null | head -1)"
  [[ -n "${count}" ]]
}

list_installed_fonts() {
  local font installed_count=0

  log_info "Verificando Nerd Fonts instaladas..."
  printf '\n'

  for font in "${RECOMMENDED_FONTS[@]}"; do
    if is_font_installed "${font}"; then
      printf '  ✓ %s (instalada)\n' "${font}"
      (( installed_count++ ))
    else
      printf '  ✗ %s (não encontrada)\n' "${font}"
    fi
  done

  printf '\n'
  log_info "${installed_count}/${#RECOMMENDED_FONTS[@]} fonts recomendadas instaladas"
}

# ============================================================================
# Core: Download e instalação
# ============================================================================

download_font() {
  local font_name="$1"
  local zip_file="${CACHE_DIR}/${font_name}.zip"
  local url="${NERD_FONTS_BASE_URL}/${font_name}.zip"

  # Cache hit — usa zip existente
  if [[ -f "${zip_file}" ]]; then
    log_info "Cache encontrado: ${font_name}.zip"
    return 0
  fi

  # Download
  if _has_gum; then
    gum spin --spinner dot --title "Baixando ${font_name}..." -- \
      curl -fsSL --retry 3 --retry-delay 2 -o "${zip_file}" "${url}"
  else
    printf 'Baixando %s...' "${font_name}"
    curl -fsSL --retry 3 --retry-delay 2 -o "${zip_file}" "${url}"
    printf ' OK\n'
  fi

  # Verifica download
  if [[ ! -f "${zip_file}" ]] || [[ ! -s "${zip_file}" ]]; then
    log_error "Falha no download de ${font_name}"
    rm -f "${zip_file}"
    return 1
  fi
}

install_font() {
  local font_name="$1"
  local zip_file="${CACHE_DIR}/${font_name}.zip"
  local extract_dir="${CACHE_DIR}/${font_name}"

  # Idempotência — não reinstala
  if is_font_installed "${font_name}"; then
    log_info "${font_name} já instalada, pulando"
    return 0
  fi

  # Download (com cache)
  download_font "${font_name}" || return 1

  # Extrai apenas .ttf e .otf (ignora Windows-compatible)
  mkdir -p "${extract_dir}"
  if _has_gum; then
    gum spin --spinner line --title "Instalando ${font_name}..." -- \
      unzip -oqj "${zip_file}" "*.ttf" "*.otf" -d "${extract_dir}" 2>/dev/null
  else
    unzip -oqj "${zip_file}" "*.ttf" "*.otf" -d "${extract_dir}" 2>/dev/null
  fi

  # Remove variantes Windows-compat (nomes com "Windows Compatible")
  find "${extract_dir}" -name "*Windows*" -type f -delete 2>/dev/null || true

  # Move para diretório de fonts
  local file_count=0
  while IFS= read -r -d '' font_file; do
    mv -f "${font_file}" "${FONT_DIR}/"
    (( file_count++ ))
  done < <(find "${extract_dir}" \( -name "*.ttf" -o -name "*.otf" \) -type f -print0 2>/dev/null)

  # Cleanup extração temporária
  rm -rf "${extract_dir}"

  if (( file_count > 0 )); then
    log_success "${font_name} instalada (${file_count} arquivos)"
  else
    log_warn "${font_name}: nenhum arquivo de fonte encontrado no zip"
    return 1
  fi
}

refresh_font_cache() {
  if command -v fc-cache &>/dev/null; then
    if _has_gum; then
      gum spin --spinner dot --title "Atualizando cache de fontes..." -- \
        fc-cache -f "${FONT_DIR}"
    else
      printf 'Atualizando cache de fontes...'
      fc-cache -f "${FONT_DIR}"
      printf ' OK\n'
    fi
    log_success "Cache de fontes atualizado"
  else
    log_warn "fc-cache não encontrado — reinicie o terminal para aplicar"
  fi
}

# ============================================================================
# Modos de operação
# ============================================================================

mode_interactive() {
  require_cmd gum

  log_info "Nerd Fonts Installer — shell-gum-elite"
  printf '\n'

  # Detecta já instaladas
  local available=()
  local font status
  for font in "${RECOMMENDED_FONTS[@]}"; do
    if is_font_installed "${font}"; then
      status="✓"
    else
      status=" "
    fi
    available+=("${font} [${status}]")
  done

  # Seleção múltipla
  local selected
  selected="$(printf '%s\n' "${available[@]}" | gum choose \
    --no-limit \
    --header "Selecione as fontes para instalar (✓ = já instalada)" \
    --cursor.foreground "#8ECAE6" \
    --selected.foreground "#FFB703")" || {
    log_warn "Nenhuma fonte selecionada"
    exit 0
  }

  # Extrai nomes (remove sufixo " [✓]" ou " [ ]")
  local fonts_to_install=()
  while IFS= read -r line; do
    local name="${line%% \[*}"
    fonts_to_install+=("${name}")
  done <<< "${selected}"

  if (( ${#fonts_to_install[@]} == 0 )); then
    log_warn "Nenhuma fonte selecionada"
    exit 0
  fi

  # Confirmação
  gum confirm "Instalar ${#fonts_to_install[@]} fonte(s)?" || {
    log_warn "Cancelado pelo usuário"
    exit 0
  }

  # Instala
  local success=0 fail=0
  for font in "${fonts_to_install[@]}"; do
    if install_font "${font}"; then
      (( success++ ))
    else
      (( fail++ ))
    fi
  done

  # Refresh cache
  refresh_font_cache

  printf '\n'
  log_info "Resultado: ${success} instalada(s), ${fail} falha(s)"
  log_info "Diretório: ${FONT_DIR}"

  if (( fail > 0 )); then
    exit 1
  fi
}

mode_direct() {
  local font_name="$1"

  # Valida que a font existe na lista
  local found=false
  for f in "${RECOMMENDED_FONTS[@]}"; do
    if [[ "${f}" == "${font_name}" ]]; then
      found=true
      break
    fi
  done

  if ! "${found}"; then
    log_error "Fonte desconhecida: ${font_name}"
    log_info "Fontes disponíveis: ${RECOMMENDED_FONTS[*]}"
    exit 2
  fi

  if install_font "${font_name}"; then
    refresh_font_cache
  else
    exit 1
  fi
}

mode_all() {
  log_info "Instalando todas as ${#RECOMMENDED_FONTS[@]} fontes recomendadas..."

  local success=0 fail=0
  for font in "${RECOMMENDED_FONTS[@]}"; do
    if install_font "${font}"; then
      (( success++ ))
    else
      (( fail++ ))
    fi
  done

  refresh_font_cache

  printf '\n'
  log_info "Resultado: ${success} instalada(s), ${fail} falha(s)"

  if (( fail > 0 )); then
    exit 1
  fi
}

show_help() {
  cat << 'EOF'
install-nerd-fonts.sh — Instalação de Nerd Fonts para terminal UX

USO:
  bash scripts/install-nerd-fonts.sh                       Modo interativo (Gum)
  bash scripts/install-nerd-fonts.sh --font JetBrainsMono  Instala uma fonte
  bash scripts/install-nerd-fonts.sh --all                 Instala todas
  bash scripts/install-nerd-fonts.sh --list                Lista status
  bash scripts/install-nerd-fonts.sh --check               Alias de --list
  bash scripts/install-nerd-fonts.sh --clean-cache         Remove downloads
  bash scripts/install-nerd-fonts.sh --help                Exibe esta ajuda

FONTS DISPONÍVEIS:
  JetBrainsMono   FiraCode      Hack           CascadiaCode
  SourceCodePro   UbuntuMono    IBMPlexMono    Meslo

VARIÁVEIS DE AMBIENTE:
  XDG_CACHE_HOME   Diretório de cache (padrão: ~/.cache)

DEPENDÊNCIAS:
  Obrigatórias: curl, unzip
  Opcionais:    gum (interatividade), fc-list/fc-cache (detecção)
EOF
}

# ============================================================================
# Main
# ============================================================================

main() {
  require_cmd curl
  require_cmd unzip
  setup_dirs

  # Parse args
  case "${1:-}" in
    --help|-h)
      show_help
      ;;
    --list|--check)
      list_installed_fonts
      ;;
    --font)
      [[ -n "${2:-}" ]] || { log_error "Uso: --font <nome>"; exit 2; }
      mode_direct "$2"
      ;;
    --all)
      mode_all
      ;;
    --clean-cache)
      if [[ -d "${CACHE_DIR}" ]]; then
        rm -rf "${CACHE_DIR}"
        log_success "Cache limpo: ${CACHE_DIR}"
      else
        log_info "Cache não encontrado"
      fi
      ;;
    "")
      if _has_gum; then
        mode_interactive
      else
        log_warn "Gum não encontrado — use --font <nome> ou --all"
        show_help
        exit 2
      fi
      ;;
    *)
      log_error "Opção desconhecida: $1"
      show_help
      exit 2
      ;;
  esac
}

main "$@"
