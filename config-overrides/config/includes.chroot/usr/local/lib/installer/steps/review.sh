#!/usr/bin/env bash
step_review() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Revisão"

    local hn user disk strat topo pool comp
    hn="$(sanitize_ws "${install_hostname-}")"
    user="$(sanitize_ws "${install_username-}")"
    disk="$(sanitize_ws "${install_disk-}")"
    strat="$(sanitize_ws "${install_zfs_strategy-}")"
    topo="$(sanitize_ws "${zfs_topology-}")"
    pool="$(sanitize_ws "${zfs_pool_name-}")"
    comp="$(sanitize_ws "${zfs_compression-}")"

    ui_card "Resumo" \
        "  Sistema:       Debian 13 (trixie)" \
        "  Hostname:      ${hn:-"(não definido)"}" \
        "  Usuário:       ${user:-"(não definido)"}" \
        "  Disco:         ${disk:-"(não definido)"}" \
        "  ZFS:           strategy=${strat:-"(não definido)"} topo=${topo:-"-"} pool=${pool:-"-"} comp=${comp:-"-"}"

    if ui_confirm "Iniciar instalação agora?" "Instalar" "Voltar"; then
        return 0
    fi
    goto_prev || true
}
