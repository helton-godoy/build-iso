#!/usr/bin/env bash
# @INST_STEP_ID: installer_prefs_locale
# @INST_STEP_FLOW: prev=welcome, next=installer_prefs_keyboard
# @INST_STATE: install_lang

list_supported_locales() {
	local supported_file="/usr/share/i18n/SUPPORTED"
	if [[ -f "$supported_file" ]]; then
		awk '!/^#/ && NF { print $1 }' "$supported_file" | sort -u
		return 0
	fi

	printf '%s\n' "pt_BR.UTF-8" "en_US.UTF-8"
}

step_installer_prefs_locale() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Idioma e Localidade"
	ui_card "Configuração de idioma" \
		"  $UI_BULLET Lista completa baseada em /usr/share/i18n/SUPPORTED" \
		"  $UI_BULLET Digite para filtrar rapidamente a lista" \
		"  $UI_BULLET Recomendado: pt_BR.UTF-8 ou en_US.UTF-8"

	local -a locales
	mapfile -t locales < <(list_supported_locales)
	if [[ "${#locales[@]}" -eq 0 ]]; then
		locales=("pt_BR.UTF-8" "en_US.UTF-8")
	fi

	local lang
	lang="$(ui_filter_select "Selecione o locale do sistema:" "${locales[@]}")"
	lang="$(sanitize_ws "$lang")"
	if [[ -z "$lang" ]]; then
		lang="pt_BR.UTF-8"
	fi
	state_kv_set "install_lang" "$lang" || return 1
}
