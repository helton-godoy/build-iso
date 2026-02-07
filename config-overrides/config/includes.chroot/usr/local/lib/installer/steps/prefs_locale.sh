#!/usr/bin/env bash
step_installer_prefs_locale() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Idioma e Localidade"
    local lang
    if ! lang="$(ui_select "Selecione o idioma:" "pt_BR" "en_US")"; then
        return 1
    fi
    lang="$(sanitize_ws "$lang")"
    if [[ -z "$lang" ]]; then
        lang="pt_BR"
    fi
    state_kv_set "install_lang" "$lang" || return 1
}
