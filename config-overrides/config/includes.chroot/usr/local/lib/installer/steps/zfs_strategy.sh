#!/usr/bin/env bash
step_zfs_strategy() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Estratégia ZFS"

    local strategy profile
    if ! strategy="$(ui_select "Modo:" "auto" "manual")"; then
        return 1
    fi
    strategy="$(sanitize_id "$strategy")"
    if [[ -z "$strategy" ]]; then
        strategy="auto"
    fi
    state_kv_set "install_zfs_strategy" "$strategy" || return 1

    if ! profile="$(ui_select "Perfil de uso:" "server_nas" "desktop" "vms_db")"; then
        return 1
    fi
    profile="$(sanitize_id "$profile")"
    if [[ -z "$profile" ]]; then
        profile="server_nas"
    fi
    state_kv_set "install_profile" "$profile" || return 1
}
