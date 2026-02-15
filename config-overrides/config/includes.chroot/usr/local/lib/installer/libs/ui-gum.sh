#!/usr/bin/env bash
# ui-gum.sh - Biblioteca de componentes de UI baseada em Gum e KMSCON
# Implementa padrões do "Shell Gum Elite" para o instalador.

set -euo pipefail

# =============================================================================
# CONSTANTS & THEME
# =============================================================================

# Palette (Slate Blue based)
export UI_COLOR_PRIMARY="#8ECAE6"    # Cyan Light
export UI_COLOR_ACCENT="#FFB703"     # Yellow
export UI_COLOR_SUCCESS="#2A9D8F"    # Green
export UI_COLOR_WARNING="#FB8500"    # Orange
export UI_COLOR_ERROR="#D62828"      # Red
export UI_COLOR_MUTED="#6C757D"      # Gray

# Gum Defaults
export GUM_CHOOSE_CURSOR_FOREGROUND="$UI_COLOR_ACCENT"
export GUM_CHOOSE_ITEM_FOREGROUND="$UI_COLOR_PRIMARY"
export GUM_CHOOSE_SELECTED_FOREGROUND="$UI_COLOR_ACCENT"
export GUM_INPUT_CURSOR_FOREGROUND="$UI_COLOR_ACCENT"
export GUM_INPUT_PROMPT_FOREGROUND="$UI_COLOR_PRIMARY"
export GUM_SPIN_SPINNER="globe"
export GUM_SPIN_SPINNER_FOREGROUND="$UI_COLOR_ACCENT"

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

# init_gum: Verifica dependências e prepara ambiente
sys_gum_init() {
    if ! command -v gum &>/dev/null; then
        echo "CRITICAL: 'gum' not found. Falling back to text mode or exiting." >&2
        exit 1
    fi
    
    # Optional: Check for KMSCON specific env vars if needed
    if [[ "${TERM:-}" != "xterm-256color" ]]; then
        export TERM=xterm-256color
    fi
}

# sys_header: Renderiza cabeçalho padrão
sys_header() {
    local title="${1:-Instalador}"
    local subtitle="${2:-}"
    
    local header_text
    header_text=$(gum style --foreground "$UI_COLOR_ACCENT" --bold "FILESERVER INSTALLER")
    
    local step_text=""
    if [[ -n "$subtitle" ]]; then
        step_text=$(gum style --foreground "$UI_COLOR_MUTED" " • $subtitle")
    fi
    
    gum join --horizontal "$header_text" "$step_text"
    gum style --foreground "$UI_COLOR_PRIMARY" "──────────────────────────────────────────────────────────"
}

# sys_page: Renderiza página completa (Header + Content + Footer)
# Usage: sys_page "Title" "Content String" "Footer String"
sys_page() {
    local title="$1"
    local content="$2"
    local footer="${3:-}"
    
    clear
    
    # Calculate available height
    local total_lines
    total_lines=$(tput lines)
    local header_height=3
    local footer_height=2
    local content_height=$((total_lines - header_height - footer_height))
    
    # Render layout
    sys_header "Fileserver" "$title"
    
    gum style --height "$content_height" --width "$(tput cols)" --align left --vertical-align top "$content"
    
    if [[ -n "$footer" ]]; then
        gum style --foreground "$UI_COLOR_MUTED" --align center "$footer"
    fi
}

# sys_confirm: Caixa de diálogo Sim/Não
sys_confirm() {
    local prompt="$1"
    gum confirm "$prompt" \
        --affirmative "Sim" \
        --negative "Não" \
        --default="No" \
        --prompt.foreground "$UI_COLOR_WARNING"
}

# sys_input: Entrada de texto
sys_input() {
    local prompt="$1"
    local placeholder="${2:-}"
    local value="${3:-}"
    
    gum input \
        --prompt "$prompt " \
        --placeholder "$placeholder" \
        --value "$value" \
        --width 60
}

# sys_select: Seleção de lista
# Usage: sys_select "Title" "Option1" "Option2" ...
sys_select() {
    local title="$1"
    shift
    local options=("$@")
    
    gum choose \
        --header "$title" \
        --cursor "➜ " \
        --no-limit=false \
        "${options[@]}"
}

# sys_msg_box: Exibe mensagem informativa com confirmação
sys_msg_box() {
    local title="$1"
    local msg="$2"
    
    clear
    sys_header "Info" "$title"
    echo ""
    gum style --border rounded --padding "1 2" --border-foreground "$UI_COLOR_PRIMARY" "$msg"
    echo ""
    gum style --foreground "$UI_COLOR_MUTED" "Pressione Enter para continuar..."
    read -r _
}

# sys_msg_error: Exibe erro
sys_msg_error() {
    local title="$1"
    local msg="$2"
    
    clear
    sys_header "ERRO" "$title"
    echo ""
    gum style --border double --padding "1 2" --border-foreground "$UI_COLOR_ERROR" "$msg"
    echo ""
    gum style --foreground "$UI_COLOR_ERROR" "Pressione Enter para continuar..."
    read -r _
}

# Auto-init on source if not guarded (common for simple includes)
sys_gum_init
