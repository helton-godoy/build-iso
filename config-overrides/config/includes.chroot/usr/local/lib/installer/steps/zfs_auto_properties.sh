#!/usr/bin/env bash
step_zfs_auto_properties() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "ZFS: Propriedades"

    local comp dedup arc_mode arc_max
    if ! comp="$(ui_select "Compressão:" "zstd" "lz4")"; then
        return 1
    fi
    comp="$(sanitize_id "$comp")"
    if [[ -z "$comp" ]]; then
        comp="zstd"
    fi

    if ui_confirm "Ativar deduplicação?" "Ativar" "Desativar"; then
        dedup="1"
    else
        dedup="0"
    fi

    if ui_confirm "Definir ARC máximo?" "Definir" "Automático"; then
        arc_mode="custom"
        if ! arc_max="$(ui_input "ARC máximo (ex: 4G):" "4G")"; then
            return 1
        fi
        arc_max="$(sanitize_ws "$arc_max")"
        if [[ -z "$arc_max" ]]; then
            arc_max="4G"
        fi
    else
        arc_mode="auto"
        arc_max=""
    fi

    state_kv_set "zfs_compression" "$comp" || return 1
    state_kv_set "zfs_dedup" "$dedup" || return 1
    state_kv_set "zfs_arc_mode" "$arc_mode" || return 1
    state_kv_set "zfs_arc_max" "$arc_max" || return 1
}
