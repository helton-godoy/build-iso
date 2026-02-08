#!/usr/bin/env bash
# @INST_STEP_ID: zfs_strategy
# @INST_STEP_FLOW: prev=disk_wipe_confirm, next=zfs_auto_topology|zfs_manual
# @INST_STATE: install_zfs_strategy, install_profile
step_zfs_strategy() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Estratégia ZFS"
	ui_guidance \
		"Definir nível de assistência da configuração ZFS" \
		"Modo manual exige decisões avançadas e aumenta chance de erro" \
		"Para equipe junior, use auto + perfil server_nas" \
		"Você precisar de customização muito específica sem validação"

	local strategy profile
	strategy="$(ui_select "Modo:" "auto" "manual")"
	strategy="$(sanitize_id "$strategy")"
	if [[ -z "$strategy" ]]; then
		strategy="auto"
	fi
	state_kv_set "install_zfs_strategy" "$strategy" || return 1

	profile="$(ui_filter_select "Perfil de uso:" "server_nas" "desktop" "vms_db")"
	profile="$(sanitize_id "$profile")"
	if [[ -z "$profile" ]]; then
		profile="server_nas"
	fi
	state_kv_set "install_profile" "$profile" || return 1
	plan_ensure_version || return 1
	state_kv_set "install_plan_strategy" "$strategy" || return 1
	state_kv_set "install_plan_profile" "$profile" || return 1
}
