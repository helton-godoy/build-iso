#!/usr/bin/env bash
# @INST_LIB_NAME: ui-utils
# @INST_DESC: FILESERVER Design System v2.0 - Componentes visuais baseados no 'gum'.
# @INST_DEP: gum

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

# @INST_FUNC: _ui_get_width
# @INST_DESC: Calcula a largura do conteúdo principal baseada no terminal.
_ui_get_width() {
	local term_width
	term_width=$(tput cols || echo 80)
	
	# Largura padrão (desktop/vm)
	local content_width=$((term_width - 4))
	
	# Limites de legibilidade
	[[ "$content_width" -lt 40 ]] && content_width=40
	[[ "$content_width" -gt 100 ]] && content_width=100
	
	echo "$content_width"
}

# @INST_FUNC: ui_hero
# @INST_DESC: Exibe o cabeçalho principal da aplicação (Hero component).
ui_hero() {
	local title="${1:-FILESERVER INSTALLER}"
	local subtitle="${2:-}"
	clear

	local width
	width=$(_ui_get_width)

	# Hero tem margem externa de 2 chars (total 4) e padding interno
	# Para alinhar com Section (que é full width no content area), 
	# Hero deve ter a mesma largura visual total.
	
	gum style \
		--foreground "$DS_FILESERVER_PEAK" \
		--border-foreground "$DS_SLATE" \
		--border double --align center \
		--width "$width" --margin "1 2" --padding "1 2" \
		"$title" "$subtitle"
}

ui_section() {
	local title="$1"
	
	local width
	width=$(_ui_get_width)
	
	echo ""
	gum style --foreground "$DS_MIST" --bold --margin "0 2" \
		"$(printf "$UI_H%.0s" $(seq 1 "$width"))"
	gum style --foreground "$DS_SILVER" --bold --margin "0 2" \
		"  $UI_ARROW $title"
	gum style --foreground "$DS_MIST" --bold --margin "0 2" \
		"$(printf "$UI_H%.0s" $(seq 1 "$width"))"
}

ui_card() {
	local title="$1"
	shift
	
	local width
	width=$(_ui_get_width)
	
	# Cards have border (2 chars) + padding (4 chars) + margin (4 chars)
	# gum style --width includes border and padding but NOT margin?
	# margin "1 2" means 2 spaces left, 2 right.
	# width should be exactly same as Hero to align borders.
	
	gum style \
		--border-foreground "$DS_WHISPER" \
		--border normal \
		--padding "1 2" --margin "1 2" \
		--width "$width" \
		"$(gum style --foreground "$DS_SLATE_GLOW" --bold "$title")" \
		"$(gum style --foreground "$DS_MIST" "$(printf "$UI_H%.0s" $(seq 1 "$((width - 6))"))")" \
		"$@"
}

ui_guidance() {
	local goal="${1-}"
	local impact="${2-}"
	local recommendation="${3-}"
	local avoid_when="${4-}"

	ui_card "Guia da etapa" \
		"  $UI_BULLET Objetivo: ${goal:-n/d}" \
		"  $UI_BULLET Impacto: ${impact:-n/d}" \
		"  $UI_BULLET Recomendado: ${recommendation:-n/d}" \
		"  $UI_WARN Evite quando: ${avoid_when:-n/d}"
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

# @INST_FUNC: ui_input
# @INST_DESC: Solicita entrada de texto do usuário via 'gum input'.
ui_input() {
	local label="$1"
	local placeholder="${2:-}"
	local hint="${3:-}"
	gum style --foreground "$DS_CLOUD" --margin "0 2" "$label:" >&2
	local value=$(gum input \
		--placeholder "$placeholder" \
		--header "" \
		--prompt.foreground "$DS_SLATE" \
		--placeholder.foreground "$DS_FOG" \
		--cursor.foreground "$DS_FILESERVER_PEAK")
	[[ -n "$hint" ]] &&
		gum style --foreground "$DS_FOG" --italic --margin "0 2" "    $hint" >&2
	echo "$value"
}

ui_password() {
	local label="$1"
	local placeholder="${2:-Senha}"
	local hint="${3:-}"
	gum style --foreground "$DS_CLOUD" --margin "0 2" "$label:" >&2
	local value
	value="$(gum input \
		--password \
		--placeholder "$placeholder" \
		--header "" \
		--prompt.foreground "$DS_SLATE" \
		--placeholder.foreground "$DS_FOG" \
		--cursor.foreground "$DS_FILESERVER_PEAK")"
	[[ -n "$hint" ]] &&
		gum style --foreground "$DS_FOG" --italic --margin "0 2" "    $hint" >&2
	echo "$value"
}

# @INST_FUNC: ui_select
# @INST_DESC: Menu de seleção única via 'gum choose'.
ui_select() {
	local title="$1"
	shift
	local selection

	gum style --foreground "$DS_CLOUD" --margin "0 2" "$title" >&2
	gum style --foreground "$DS_FOG" --italic --margin "0 2" "  $UI_ARROW Use ↑/↓ para navegar e Enter para confirmar" >&2
	echo "" >&2

	if [[ "$#" -eq 0 ]]; then
		ui_error "Opções inválidas" "Nenhuma opção foi fornecida para seleção."
		return 1
	fi

	if ! selection="$(gum choose "$@" \
		--height 8 \
		--show-help \
		--cursor "$UI_ARROW " \
		--selected-prefix "$UI_BULLET " \
		--unselected-prefix "• " \
		--cursor.foreground "$DS_FILESERVER_PEAK" \
		--item.foreground "$DS_CLOUD" \
		--selected.foreground "$DS_SILVER" \
		--selected.background "$DS_ELEVATION")"; then
		return 1
	fi

	if [[ -z "$selection" ]]; then
		selection="${1:-}"
	fi

	printf '%s' "$selection"
}

ui_filter_select() {
	local title="$1"
	shift
	local selection

	gum style --foreground "$DS_CLOUD" --margin "0 2" "$title" >&2
	gum style --foreground "$DS_FOG" --italic --margin "0 2" "  $UI_ARROW Digite para filtrar e Enter para selecionar" >&2
	echo "" >&2

	if [[ "$#" -eq 0 ]]; then
		ui_error "Opções inválidas" "Nenhuma opção foi fornecida para seleção."
		return 1
	fi

	if ! selection="$(printf '%s\n' "$@" | gum filter \
		--height 12 \
		--show-help \
		--fuzzy \
		--strict \
		--header "$title" \
		--placeholder "Digite para filtrar..." \
		--prompt "$UI_ARROW " \
		--indicator "$UI_BULLET" \
		--selected-prefix "$UI_BULLET " \
		--unselected-prefix "• " \
		--selected-indicator.foreground "$DS_FILESERVER_PEAK" \
		--unselected-prefix.foreground "$DS_FOG" \
		--text.foreground "$DS_CLOUD" \
		--cursor-text.foreground "$DS_SILVER" \
		--match.foreground "$DS_FILESERVER_PEAK" \
		--prompt.foreground "$DS_SLATE" \
		--placeholder.foreground "$DS_FOG")"; then
		return 1
	fi

	printf '%s' "$selection"
}

ui_multiselect() {
	local title="$1"
	shift
	local selection

	gum style --foreground "$DS_CLOUD" --margin "0 2" "$title" >&2
	gum style --foreground "$DS_FOG" --italic --margin "0 2" "  $UI_ARROW Espaço marca • Enter confirma • Ctrl+C cancela" >&2
	echo "" >&2

	if [[ "$#" -eq 0 ]]; then
		ui_error "Opções inválidas" "Nenhuma opção foi fornecida para seleção."
		return 1
	fi

	if ! selection="$(gum choose "$@" \
		--no-limit \
		--height 10 \
		--show-help \
		--cursor "$UI_ARROW " \
		--selected-prefix "[$UI_BULLET] " \
		--unselected-prefix "[ ] " \
		--cursor-prefix "[ ] " \
		--cursor.foreground "$DS_FILESERVER_PEAK" \
		--item.foreground "$DS_CLOUD" \
		--selected.foreground "$DS_SILVER" \
		--selected.background "$DS_ELEVATION")"; then
		return 1
	fi

	printf '%s' "$selection"
}

ui_filter_multiselect() {
	local title="$1"
	shift
	local selection

	gum style --foreground "$DS_CLOUD" --margin "0 2" "$title" >&2
	gum style --foreground "$DS_FOG" --italic --margin "0 2" "  $UI_ARROW Digite para filtrar • Tab alterna • Enter confirma" >&2
	echo "" >&2

	if [[ "$#" -eq 0 ]]; then
		ui_error "Opções inválidas" "Nenhuma opção foi fornecida para seleção."
		return 1
	fi

	# Pad options with 2 spaces for alignment
	local -a options_padded
	local opt
	for opt in "$@"; do
		options_padded+=("  $opt")
	done

	if ! selection="$(printf '%s\n' "${options_padded[@]}" | gum filter \
		--no-limit \
		--height 12 \
		--show-help \
		--fuzzy \
		--strict \
		--header "$title" \
		--placeholder "Digite para filtrar..." \
		--prompt "$UI_ARROW " \
		--indicator "$UI_BULLET" \
		--selected-prefix "[$UI_BULLET] " \
		--unselected-prefix "[ ] " \
		--selected-indicator.foreground "$DS_FILESERVER_PEAK" \
		--text.foreground "$DS_CLOUD" \
		--cursor-text.foreground "$DS_SILVER" \
		--match.foreground "$DS_FILESERVER_PEAK" \
		--prompt.foreground "$DS_SLATE" \
		--placeholder.foreground "$DS_FOG")"; then
		return 1
	fi

	# Remove the 2-space padding from the result
	printf '%s\n' "$selection" | sed 's/^  //'
}

ui_error() {
	local title="${1:-Erro}"
	local message="${2:-}"
	
	local width
	width=$(_ui_get_width)

	if [[ -n "$message" ]]; then
		gum style \
			--foreground "$DS_ERROR" \
			--border-foreground "$DS_ERROR" \
			--border double \
			--padding "1 2" --margin "1 2" --align center \
			--width "$width" \
			"$UI_WARN $title" "" "$message"
	else
		gum style \
			--foreground "$DS_ERROR" \
			--border-foreground "$DS_ERROR" \
			--border double \
			--padding "1 2" --margin "1 2" --align center \
			--width "$width" \
			"$UI_WARN $title"
	fi
}

ui_success() {
	local message="$1"
	
	local width
	width=$(_ui_get_width)
	
	gum style \
		--foreground "$DS_SUCCESS" \
		--border-foreground "$DS_SUCCESS" \
		--border double \
		--padding "1 2" --margin "1 2" --align center \
		--width "$width" \
		"$UI_CHECK $message"
}

# @INST_FUNC: ui_confirm
# @INST_DESC: Diálogo de confirmação sim/não.
ui_confirm() {
	local title="$1"
	local affirmative="${2:-Sim}"
	local negative="${3:-Não}"

	gum confirm "$title" \
		--affirmative "$affirmative" \
		--negative "$negative" \
		--show-help \
		--padding "0 0" \
		--prompt.foreground "$DS_SLATE" \
		--selected.foreground "$DS_FILESERVER_PEAK" \
		--selected.background "$DS_ELEVATION" \
		--unselected.foreground "$DS_FOG" \
		--unselected.background "$DS_VOID"
}

# ──────────────────────────────────────────────────────────────────────────────
# Process Wrapper (Spinner)
# ──────────────────────────────────────────────────────────────────────────────

# @INST_FUNC: ui_process_step
# @INST_DESC: Executa um comando com spinner e redirecionamento de logs.
# @INST_DEP: gum spin
ui_process_step() {
	local title="$1"
	shift
	local cmd
	local libs_dir="${LIBS_DIR:-}"
	# Escape arguments for safe injection into bash -c
	cmd="$(printf "%q " "$@")"

	gum spin --spinner dot --title "$title" --show-error \
		--spinner.foreground "$DS_SLATE" \
		--title.foreground "$DS_CLOUD" -- bash -c "
        set -euo pipefail
        exec >>'${LOG_FILE:-/dev/null}' 2>&1
        # Source all libs to ensure environment in subshell
        # Use simple glob expansion if LIBS_DIR is set
        if [[ -n '$libs_dir' && -d '$libs_dir' ]]; then
            for f in '$libs_dir'/*.sh; do source \"\$f\"; done
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
