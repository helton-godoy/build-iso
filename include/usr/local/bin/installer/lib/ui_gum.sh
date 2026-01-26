#!/usr/bin/env bash
#
# lib/ui_gum.sh - Modern UI Framework using Gum
# Implements "UI/UX Pro Max" principles for TUI
#
# shellcheck disable=SC2034

# Proteção contra múltipla inclusão
if [[ -n ${UI_GUM_SH_LOADED-} ]]; then
	return 0
fi
readonly UI_GUM_SH_LOADED=true

# =============================================================================
# DESIGN SYSTEM
# =============================================================================

# Colors (Dracula-inspired for high contrast & modern look)
# Prefixed with GUM_ to avoid conflicts with logging.sh variables
readonly GUM_COLOR_PRIMARY="#BD93F9"   # Purple
readonly GUM_COLOR_SECONDARY="#FF79C6" # Pink
readonly GUM_COLOR_ACCENT="#8BE9FD"    # Cyan
readonly GUM_COLOR_SUCCESS="#50FA7B"   # Green
readonly GUM_COLOR_WARNING="#FFB86C"   # Orange
readonly GUM_COLOR_ERROR="#FF5555"     # Red
readonly GUM_COLOR_TEXT="#F8F8F2"      # White
readonly GUM_COLOR_SUBTEXT="#6272A4"   # Gray

# Icons (Unicode Emoji with ASCII fallback)
readonly GUM_ICON_DISK="💾"
readonly GUM_ICON_ZFS="🐬"
readonly GUM_ICON_USER="👤"
readonly GUM_ICON_KEY="🔑"
readonly GUM_ICON_CONFIRM="✅"
readonly GUM_ICON_ERROR="❌"
readonly GUM_ICON_WARN="⚠️"

# Gum Binary
GUM_BIN="${LIB_DIR}/../gum"
if [[ ! -x ${GUM_BIN} ]]; then
	# Fallback to system gum if local not found
	if command -v gum &>/dev/null; then
		GUM_BIN=$(command -v gum)
	else
		echo "ERROR: Gum not found. UI requires gum." >&2
		exit 1
	fi
fi

# =============================================================================
# COMPONENTS
# =============================================================================

# Header with Logo/Title
# Usage: ui_header "Title" "Subtitle"
ui_header() {
	local title="$1"
	local subtitle="${2-}"

	"${GUM_BIN}" style \
		--border double \
		--border-foreground "${GUM_COLOR_PRIMARY}" \
		--padding "1 2" \
		--margin "1 0" \
		--align center \
		--width 80 \
		"$(echo -e "${title}")" \
		"" \
		"$(echo -e "${GUM_COLOR_ACCENT}${subtitle}")"
}

# Standard Input
# Usage: var=$(ui_input "Label" "Placeholder" "DefaultValue" "is_password")
ui_input() {
	local label="$1"
	local placeholder="$2"
	local value="${3-}"
	local is_pass="${4:-false}"
	local arg_list
	arg_list=(
		--cursor.foreground "${GUM_COLOR_ACCENT}"
		--prompt.foreground "${GUM_COLOR_PRIMARY}"
		--prompt "* ${label}: "
		--placeholder "${placeholder}"
		--width 60
	)

	if [[ -n ${value} ]]; then
		arg_list+=(--value "${value}")
	fi

	if [[ ${is_pass} == "true" ]]; then
		arg_list+=(--password)
	fi

	"${GUM_BIN}" input "${arg_list[@]}"
}

# Selection Menu
# Usage: var=$(ui_choose "Title" "Option1" "Option2" ...)
ui_choose() {
	local title="$1"
	shift
	local options=("$@")

	echo -e "${GUM_COLOR_PRIMARY}* ${title}${GUM_COLOR_TEXT}" >&2
	"${GUM_BIN}" choose \
		--cursor.foreground "${GUM_COLOR_ACCENT}" \
		--header.foreground "${GUM_COLOR_SUBTEXT}" \
		--selected.foreground "${GUM_COLOR_SUCCESS}" \
		--limit 1 \
		"${options[@]}"
}

# Multi-Selection Menu
# Usage: var=$(ui_choose_multi "Title" "Option1" "Option2" ...)
ui_choose_multi() {
	local title="$1"
	shift
	local options=("$@")

	echo -e "${GUM_COLOR_PRIMARY}* ${title} ${GUM_COLOR_SUBTEXT}(SPACE to select, ENTER to confirm)${GUM_COLOR_TEXT}" >&2
	"${GUM_BIN}" choose \
		--no-limit \
		--cursor.foreground "${GUM_COLOR_ACCENT}" \
		--header.foreground "${GUM_COLOR_SUBTEXT}" \
		--selected.foreground "${GUM_COLOR_SUCCESS}" \
		"${options[@]}"
}

# Confirmation Dialog
# Usage: if ui_confirm "Question?"; then ...
ui_confirm() {
	local question="$1"

	"${GUM_BIN}" confirm \
		--prompt.foreground "${GUM_COLOR_WARNING}" \
		--selected.background "${GUM_COLOR_PRIMARY}" \
		--selected.foreground "${GUM_COLOR_TEXT}" \
		"${question}"
}

# Spinner for long running tasks
# Usage: ui_spin "Message" command args...
ui_spin() {
	local message="$1"
	shift
	local cmd=("$@")

	"${GUM_BIN}" spin \
		--spinner dot \
		--title.foreground "${GUM_COLOR_ACCENT}" \
		--title " ${message}..." \
		-- \
		"${cmd[@]}"
}

# Rich Alert/Format
# Usage: ui_alert "Title" "Message" "Type(info/warn/error)"
ui_alert() {
	local title="$1"
	local message="$2"
	local type="${3:-info}"
	local color="${GUM_COLOR_ACCENT}"

	case "${type}" in
	warn) color="${GUM_COLOR_WARNING}" ;;
	error) color="${GUM_COLOR_ERROR}" ;;
	success) color="${GUM_COLOR_SUCCESS}" ;;
	*) color="${GUM_COLOR_ACCENT}" ;; # Default to accent color for info or unknown types
	esac

	"${GUM_BIN}" format \
		--theme dracula \
		"## ${title}" \
		"${message}" |
		"${GUM_BIN}" style \
			--border rounded \
			--border-foreground "${color}" \
			--padding "1 2" \
			--margin "1 0" \
			--width 70
}

# Table Display
# Usage: ui_table "Header1,Header2" "row1\nrow2"
ui_table() {
	local headers="$1"
	local data="$2"

	"${GUM_BIN}" table \
		--border rounded \
		--border.foreground "${GUM_COLOR_ACCENT}" \
		--header.foreground "${GUM_COLOR_PRIMARY}" \
		--selected.foreground "${GUM_COLOR_TEXT}" \
		--columns "${headers}" \
		--print \
		<<<"${data}"
}
