#!/usr/bin/env bash
step_zfs_auto_datasets() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "ZFS: Datasets"

    local preset
    if ! preset="$(ui_select "Preset:" "default" "server" "custom")"; then
        return 1
    fi
    preset="$(sanitize_id "$preset")"
    if [[ -z "$preset" ]]; then
        preset="default"
    fi
    state_kv_set "zfs_dataset_preset" "$preset" || return 1
}
