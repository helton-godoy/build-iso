#!/usr/bin/env bash
step_disk_select() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Disco de Destino"
    ui_card "Aviso" \
        "  $UI_WARN O disco selecionado será usado para instalação." \
        "  $UI_BULLET A confirmação de wipe ocorrerá na próxima tela."

    local disk
    # Tenta usar disk_list_available se possível, ou input manual
    if declare -F disk_select_interactive >/dev/null; then
        if ! disk="$(disk_select_interactive "Selecione o disco alvo:")"; then
             return 1
        fi
    else
        disk="$(ui_input "Disco alvo (ex: /dev/nvme0n1):" "/dev/nvme0n1" || true)"
    fi

    disk="$(sanitize_ws "$disk")"
    if [[ -z "$disk" ]]; then
        ui_error "Disco alvo é obrigatório."
        return 1
    fi
    state_kv_set "install_disk" "$disk" || return 1
}
