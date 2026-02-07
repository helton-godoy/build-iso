#!/usr/bin/env bash
step_disk_wipe_confirm() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Confirmação de Wipe"
    
    local disk; disk="$(sanitize_ws "${install_disk-}")"
    if [[ -z "$disk" ]]; then
        ui_error "Disco alvo não definido."
        return 1
    fi
    ui_card "Confirmação" \
        "  $UI_WARN Você está prestes a APAGAR TODOS OS DADOS em:" \
        "  $UI_BULLET $disk" \
        "" \
        "  Digite APAGAR para confirmar."
    local token
    if ! token="$(ui_input "Confirmar:" "APAGAR")"; then
        return 1
    fi
    token="$(sanitize_ws "$token")"
    if [[ "$token" != "APAGAR" ]]; then
        ui_error "Confirmação inválida. Operação cancelada."
        return 1
    fi
    state_kv_set "install_wipe_confirmed" "1" || return 1
}
