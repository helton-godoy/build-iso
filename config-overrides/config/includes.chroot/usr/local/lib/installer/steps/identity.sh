#!/usr/bin/env bash
step_identity() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Identidade do Sistema"
	local hn
	hn="$(ui_input "Hostname:" "fileserver-nas")"
	hn="$(sanitize_ws "$hn")"
	if [[ -z "$hn" ]]; then
		hn="fileserver-nas"
	fi
	state_kv_set "install_hostname" "$hn" || return 1

	local dom
	dom="$(ui_input "Domínio (opcional):" "ex: lab.local")"
	dom="$(sanitize_ws "$dom")"
	state_kv_set "install_domain" "$dom" || return 1
}
