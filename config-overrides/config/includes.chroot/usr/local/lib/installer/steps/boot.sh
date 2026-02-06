#!/usr/bin/env bash
step_boot() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Boot"

    local bootloader
    if ! bootloader="$(ui_select "Bootloader:" "grub" "refind" "zfsbootmenu")"; then
        return 1
    fi
    bootloader="$(sanitize_id "$bootloader")"
    if [[ -z "$bootloader" ]]; then
        bootloader="grub"
    fi
    state_kv_set "bootloader" "$bootloader" || return 1

    local params
    params="$(ui_input "Parâmetros do kernel (opcional):" "quiet" || true)"
    params="$(sanitize_ws "$params")"
    state_kv_set "kernel_params" "$params" || return 1
}
