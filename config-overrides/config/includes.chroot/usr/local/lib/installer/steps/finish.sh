#!/usr/bin/env bash
step_finish() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Concluído"
    ui_success "Instalação finalizada (router skeleton)."
    ui_card "Próximos passos" \
        "  $UI_WARN Remova a mídia de instalação antes de reiniciar." \
        "  $UI_BULLET Reiniciar agora ou abrir linha de comando."
    if ui_confirm "Reiniciar agora?" "Reiniciar" "Linha de comando"; then
        state_kv_set "reboot_requested" "1" || return 1
        return 0
    fi
    state_kv_set "reboot_requested" "0" || return 1
}
