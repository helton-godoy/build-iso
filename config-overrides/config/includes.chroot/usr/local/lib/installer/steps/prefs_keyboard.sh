#!/usr/bin/env bash
step_installer_prefs_keyboard() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Teclado"
    local layout
    if ! layout="$(ui_select "Layout do teclado:" "br" "us")"; then
        return 1
    fi
    layout="$(sanitize_ws "$layout")"
    if [[ -z "$layout" ]]; then
        layout="br"
    fi
    state_kv_set "install_kbd_layout" "$layout" || return 1
}
