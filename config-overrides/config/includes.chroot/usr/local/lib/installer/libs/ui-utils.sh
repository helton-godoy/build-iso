#!/usr/bin/env bash
# ui-utils.sh - FILESERVER Design System v2.0
# Sistema visual monocromático para instalador TTY

# ═══════════════════════════════════════════════════════════
# PALETA DE CORES
# ═══════════════════════════════════════════════════════════

# Fundos
export DS_VOID=235
export DS_DEPTH=237
export DS_ELEVATION=239

# Bordas
export DS_WHISPER=240
export DS_MIST=243

# Textos
export DS_FOG=245
export DS_HAZE=248
export DS_CLOUD=250
export DS_SILVER=252

# Acentos
export DS_SLATE_DIM=66
export DS_SLATE=67
export DS_SLATE_GLOW=68
export DS_FILESERVER_PEAK=153

# Funcionais
export DS_SUCCESS=108
export DS_WARNING=179
export DS_ERROR=167

# ═══════════════════════════════════════════════════════════
# CARACTERES UI
# ═══════════════════════════════════════════════════════════

export UI_H='─'
export UI_H_D='═'
export UI_V='│'
export UI_TL='┌'
export UI_TR='┐'
export UI_BL='└'
export UI_BR='┘'
export UI_ARROW='▶'
export UI_BULLET='●'
export UI_CHECK='✓'
export UI_WARN='⚠'

# ═══════════════════════════════════════════════════════════
# COMPONENTES
# ═══════════════════════════════════════════════════════════

ui_hero() {
    local title="$1" subtitle="$2"
    clear
    gum style \
        --foreground "$DS_FILESERVER_PEAK" \
        --border-foreground "$DS_SLATE" \
        --border double --align center \
        --width 60 --margin "1 2" --padding "1 2" \
        "$title" "$subtitle"
}

ui_section() {
    local title="$1"
    echo ""
    gum style --foreground "$DS_MIST" --bold \
        "$(printf "$UI_H%.0s" {1..60})"
    gum style --foreground "$DS_SILVER" --bold \
        "  $UI_ARROW $title"
    gum style --foreground "$DS_MIST" --bold \
        "$(printf "$UI_H%.0s" {1..60})"
}

ui_card() {
    local title="$1"; shift
    gum style \
        --border-foreground "$DS_WHISPER" \
        --border normal \
        --padding "1 2" --margin "1 2" \
        "$(gum style --foreground "$DS_SLATE_GLOW" --bold "$title")" \
        "$(gum style --foreground "$DS_MIST" "$(printf "$UI_H%.0s" {1..30})")" \
        "$@"
}

ui_progress() {
    local current="$1" total="$2" label="$3"
    local width=40
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local pct=$((current * 100 / total))

    local bar_filled=$(printf '█%.0s' $(seq 1 $filled))
    local bar_empty=$(printf '░%.0s' $(seq 1 $empty))

    gum style --foreground "$DS_SLATE" \
        "  [$bar_filled$bar_empty] $pct%"
    gum style --foreground "$DS_FOG" --italic \
        "      $UI_ARROW $label"
}

ui_input() {
    local label="$1" placeholder="$2" hint="$3"
    gum style --foreground "$DS_CLOUD" "$label:"
    local value=$(gum input \
        --placeholder "$placeholder" \
        --prompt.foreground "$DS_SLATE" \
        --cursor.foreground "$DS_FILESERVER_PEAK")
    [[ -n "$hint" ]] && \
        gum style --foreground "$DS_FOG" --italic "    $hint"
    echo "$value"
}

ui_select() {
    local title="$1"; shift
    gum style --foreground "$DS_CLOUD" "$title"
    echo ""
    printf '%s\n' "$@" | gum choose \
        --height 8 \
        --cursor.foreground "$DS_FILESERVER_PEAK" \
        --selected.foreground "$DS_SILVER"
}

ui_error() {
    local title="$1" message="$2"
    gum style \
        --foreground "$DS_ERROR" \
        --border-foreground "$DS_ERROR" \
        --border double \
        --padding "2 3" --margin "2 2" --align center \
        "$UI_WARN $title" "" "$message"
}

ui_success() {
    local message="$1"
    gum style \
        --foreground "$DS_SUCCESS" \
        --border-foreground "$DS_SUCCESS" \
        --border double \
        --padding "2 3" --margin "2 2" --align center \
        "$UI_CHECK $message"
}

ui_confirm() {
    local title="$1"
    local affirmative="${2:-Sim}"
    local negative="${3:-Não}"
    
    gum confirm "$title" \
        --affirmative "$affirmative" \
        --negative "$negative" \
        --prompt.foreground "$DS_SLATE" \
        --selected.foreground "$DS_FILESERVER_PEAK" \
        --unselected.foreground "$DS_FOG"
}

# ──────────────────────────────────────────────────────────────────────────────
# Process Wrapper (Spinner)
# ──────────────────────────────────────────────────────────────────────────────

ui_process_step() {
    local title="$1"
    shift
    local cmd
    # Escape arguments for safe injection into bash -c
    cmd="$(printf "%q " "$@")"
    
    gum spin --spinner dot --title "$title" --show-error -- bash -c "
        set -euo pipefail
        exec >>'${LOG_FILE:-/dev/null}' 2>&1
        # Source all libs to ensure environment in subshell
        # Use simple glob expansion if LIBS_DIR is set
        if [[ -d '${LIBS_DIR}' ]]; then
            for f in '${LIBS_DIR}'/*.sh; do source \"\$f\"; done
        fi
        $cmd
    "
}

ui_require() {
    # Check if gum is available
    if ! command -v gum >/dev/null 2>&1; then
        echo "Erro: gum não encontrado. Instale gum." >&2
        return 1
    fi
}
