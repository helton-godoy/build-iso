#!/usr/bin/env bash
step_zfs_auto_topology() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "ZFS: Topologia do Pool"

    local topo pool
    if ! topo="$(ui_select "Topologia:" "stripe" "mirror" "raidz1" "raidz2")"; then
        return 1
    fi
    topo="$(sanitize_id "$topo")"
    if [[ -z "$topo" ]]; then
        topo="stripe"
    fi
    if ! pool="$(ui_input "Nome do pool:" "rpool")"; then
        return 1
    fi
    pool="$(sanitize_id "$pool")"
    if [[ -z "$pool" ]]; then
        pool="rpool"
    fi
    state_kv_set "zfs_topology" "$topo" || return 1
    state_kv_set "zfs_pool_name" "$pool" || return 1
}
