#!/usr/bin/env bash
# @INST_STEP_ID: disk_select
# @INST_STEP_FLOW: prev=admin_policy, next=disk_wipe_confirm
# @INST_STATE: install_disk, install_disks, install_plan_selected_disks
# @INST_TODO: Melhorar validação de discos já em uso por outros pools.
step_disk_select() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Disco de Destino"
	ui_guidance \
		"Escolher os discos que farão parte do pool ZFS" \
		"Todos os discos selecionados podem ser apagados na instalação" \
		"Selecione apenas discos dedicados ao servidor" \
		"Houver dados importantes ou discos do sistema atual"
	ui_card "Aviso" \
		"  $UI_WARN Selecione um ou mais discos para a topologia desejada." \
		"  $UI_BULLET Espaço marca disco • Enter confirma" \
		"  $UI_BULLET O primeiro disco será usado como disco primário."

	local raw_disks
	if declare -F disk_select_multi_interactive >/dev/null; then
		raw_disks="$(disk_select_multi_interactive "Selecione o(s) disco(s) alvo:")"
	elif declare -F disk_select_interactive >/dev/null; then
		raw_disks="$(disk_select_interactive "Selecione o disco alvo:")"
	else
		raw_disks="$(ui_input "Disco alvo (ex: /dev/nvme0n1):" "/dev/nvme0n1")"
	fi

	local -a selected_disks
	mapfile -t selected_disks < <(printf '%s\n' "$raw_disks" | sed '/^$/d')

	if [[ "${#selected_disks[@]}" -eq 0 ]]; then
		ui_error "Disco alvo é obrigatório."
		return 1
	fi

	local primary_disk
	primary_disk="$(sanitize_ws "${selected_disks[0]}")"
	if [[ -z "$primary_disk" ]]; then
		ui_error "Disco primário inválido."
		return 1
	fi

	local disks_csv
	disks_csv="$(printf '%s,' "${selected_disks[@]}")"
	disks_csv="${disks_csv%,}"
	disks_csv="$(sanitize_ws "$disks_csv")"

	state_kv_set "install_disk" "$primary_disk" || return 1
	state_kv_set "install_disks" "$disks_csv" || return 1
	plan_ensure_version || return 1
	state_kv_set "install_plan_selected_disks" "$disks_csv" || return 1
	# Limpar composição de plano para evitar inconsistência após troca de disco(s)
	state_kv_set "install_plan_data_vdevs" "" || return 1
	state_kv_set "install_plan_aux_log_disks" "" || return 1
	state_kv_set "install_plan_aux_cache_disks" "" || return 1
	state_kv_set "install_plan_aux_special_disks" "" || return 1
	state_kv_set "install_plan_aux_dedup_disks" "" || return 1
	state_kv_set "install_plan_aux_spare_disks" "" || return 1
}
