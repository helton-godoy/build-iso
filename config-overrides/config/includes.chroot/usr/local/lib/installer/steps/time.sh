#!/usr/bin/env bash
step_time() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Data e Hora"
    local tz
    if ! tz="$(ui_select "Fuso horário:" "America/Sao_Paulo" "UTC")"; then
        return 1
    fi
    tz="$(sanitize_ws "$tz")"
    if [[ -z "$tz" ]]; then
        tz="UTC"
    fi
    state_kv_set "install_tz" "$tz" || return 1

    local ntp
    if ui_confirm "Ativar NTP?" "Ativar" "Desativar"; then
        ntp="1"
    else
        ntp="0"
    fi
    state_kv_set "install_ntp" "$ntp" || return 1

    if [[ "$ntp" == "1" ]]; then
        local ntp_srv
        ntp_srv="$(ui_input "Servidor NTP (opcional):" "pool.ntp.org" || true)"
        ntp_srv="$(sanitize_ws "$ntp_srv")"
        state_kv_set "install_ntp_server" "$ntp_srv" || return 1
    fi
}
