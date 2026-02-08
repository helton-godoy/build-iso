#!/usr/bin/env bash

list_keyboard_layouts() {
	local xkb_file="/usr/share/X11/xkb/rules/base.lst"
	if [[ -f "$xkb_file" ]]; then
		awk '
			/^! layout/ { in_layout=1; next }
			/^!/ && in_layout { exit }
			in_layout && NF { print $1 }
		' "$xkb_file" | sort -u
		return 0
	fi

	printf '%s\n' "br" "us"
}

step_installer_prefs_keyboard() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Teclado"
	ui_card "Layout do teclado" \
		"  $UI_BULLET Lista completa baseada em /usr/share/X11/xkb/rules/base.lst" \
		"  $UI_BULLET Digite para filtrar rapidamente a lista" \
		"  $UI_BULLET Recomendado para Brasil: br" \
		"  $UI_BULLET Você pode alterar depois no sistema"

	local -a layouts
	mapfile -t layouts < <(list_keyboard_layouts)
	if [[ "${#layouts[@]}" -eq 0 ]]; then
		layouts=("br" "us")
	fi

	local layout
	layout="$(ui_filter_select "Selecione o layout do teclado:" "${layouts[@]}")"
	layout="$(sanitize_ws "$layout")"
	if [[ -z "$layout" ]]; then
		layout="br"
	fi
	state_kv_set "install_kbd_layout" "$layout" || return 1
}
