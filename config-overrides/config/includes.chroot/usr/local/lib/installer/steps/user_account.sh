#!/usr/bin/env bash
# @INST_STEP_ID: user_account
# @INST_STEP_FLOW: prev=time, next=admin_policy
# @INST_STATE: install_user_fullname, install_username, install_user_pass
step_user_account() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Conta do Usuário"

	local full user pass1 pass2
	full="$(ui_input "Nome completo:" "Helton Silva")"
	user="$(ui_input "Nome de usuário:" "helton")"
	pass1="$(ui_password "Senha do usuário" "Senha do usuário")"
	pass2="$(ui_password "Confirmar senha" "Confirmar senha")"

	full="$(sanitize_ws "$full")"
	user="$(sanitize_ws "$user")"
	if [[ -z "$full" || -z "$user" ]]; then
		ui_error "Nome completo e usuário são obrigatórios."
		return 1
	fi
	if [[ "$pass1" != "$pass2" ]]; then
		ui_error "As senhas não conferem."
		return 1
	fi

	state_kv_set "install_user_fullname" "$full" || return 1
	state_kv_set "install_username" "$user" || return 1
	state_kv_set "install_user_pass" "$pass1" || return 1
}
