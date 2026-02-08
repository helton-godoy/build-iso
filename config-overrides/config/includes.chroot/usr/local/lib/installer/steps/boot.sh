#!/usr/bin/env bash
# @INST_STEP_ID: boot
# @INST_STEP_FLOW: prev=zfs_auto_datasets|zfs_manual, next=review
# @INST_STATE: bootloader, kernel_params
step_boot() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Boot"

	local bootloader
	bootloader="$(ui_select "Bootloader:" "grub" "refind" "zfsbootmenu")"
	bootloader="$(sanitize_id "$bootloader")"
	if [[ -z "$bootloader" ]]; then
		bootloader="grub"
	fi
	state_kv_set "bootloader" "$bootloader" || return 1

	local params
	params="$(ui_input "Parâmetros do kernel (opcional):" "quiet")"
	params="$(sanitize_ws "$params")"
	state_kv_set "kernel_params" "$params" || return 1
}
