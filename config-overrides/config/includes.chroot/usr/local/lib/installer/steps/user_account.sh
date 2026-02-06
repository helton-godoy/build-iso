#!/usr/bin/env bash
step_user_account() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Conta do Usuário"

    local full user pass1 pass2
    if ! full="$(ui_input "Nome completo:" "Helton Silva")"; then
        return 1
    fi
    if ! user="$(ui_input "Nome de usuário:" "helton")"; then
        return 1
    fi
    if ! pass1="$(ui_password "Senha do usuário:")"; then
        return 1
    fi
    if ! pass2="$(ui_password "Confirmar senha:")"; then
        return 1
    fi

    full="$(sanitize_ws "$full")"
    user="$(sanitize_ws "$user")"
    if [[ -z "$full" || -z "$user" ]]; then
        ui_error "Nome completo e usuário são obrigatórios."
        return 1
    fi
    if [[ "$pass1" != "$pass2" ]]; then
        ui_error "As senhas não conferem."
        return 1
    fi

    state_kv_set "install_user_fullname" "$full" || return 1
    state_kv_set "install_username" "$user" || return 1
    state_kv_set "install_user_pass" "$pass1" || return 1
}
