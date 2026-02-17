#!/usr/bin/env bash
# @INST_STEP_ID: welcome
# @INST_STEP_FLOW: next=installer_prefs_locale
# @INST_STATE: welcome_screen
step_welcome() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Boas-vindas"
	ui_card "Requisitos do Sistema" \
		"  $UI_BULLET Modo UEFI (recomendado)" \
		"  $UI_BULLET Internet (recomendado)" \
		"  $UI_BULLET Disco 20GB+ (mínimo)"
	if ui_confirm "Iniciar instalação?" "Iniciar" "Sair"; then
		return 0
	fi
	return 1
}
