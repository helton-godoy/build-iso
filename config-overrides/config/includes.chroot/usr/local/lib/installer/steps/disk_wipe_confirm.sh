#!/usr/bin/env bash
# @INST_STEP_ID: disk_wipe_confirm
# @INST_STEP_FLOW: prev=disk_select, next=zfs_strategy
# @INST_STATE: install_wipe_confirmed

strip_ansi() {
	printf '%s' "${1-}" | sed -E $'s/\x1B\[[0-9;]*[[:alpha:]]//g'
}

step_disk_wipe_confirm() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Confirmação de Wipe"

	local disks_csv disk
	disks_csv="$(sanitize_ws "${install_disks-}")"
	disk="$(sanitize_ws "${install_disk-}")"

	local -a disks
	if [[ -n "$disks_csv" ]]; then
		IFS=',' read -r -a disks <<<"$disks_csv"
	elif [[ -n "$disk" ]]; then
		disks=("$disk")
	fi

	if [[ "${#disks[@]}" -eq 0 ]]; then
		ui_error "Disco alvo não definido."
		return 1
	fi

	local -a disk_lines
	local d
	for d in "${disks[@]}"; do
		d="$(sanitize_ws "$(strip_ansi "$d")")"
		[[ -z "$d" ]] && continue
		disk_lines+=("  $UI_BULLET $d")
	done

	if [[ "${#disk_lines[@]}" -eq 0 ]]; then
		ui_error "Lista de discos inválida."
		return 1
	fi

	local confirm_text="APAGAR"
	if [[ "${#disk_lines[@]}" -gt 1 ]]; then
		confirm_text="APAGAR TODOS"
	fi

	ui_card "Confirmação" \
		"  $UI_WARN Você está prestes a APAGAR TODOS OS DADOS em:" \
		"${disk_lines[@]}" \
		"" \
		"  Digite $confirm_text para confirmar."
	local token
	token="$(ui_input "Confirmar:" "$confirm_text")"
	token="$(sanitize_ws "$token")"
	if [[ "$token" != "$confirm_text" ]]; then
		ui_error "Confirmação inválida. Operação cancelada."
		return 1
	fi
	state_kv_set "install_wipe_confirmed" "1" || return 1
}
