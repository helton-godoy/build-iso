#!/usr/bin/env bash
step_admin_policy() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Administração (Root/Sudo)"

    local choice
    if ! choice="$(ui_select "Política de administração:" "sudo" "root")"; then
        return 1
    fi
    choice="$(sanitize_id "$choice")"
    if [[ -z "$choice" ]]; then
        choice="sudo"
    fi
    state_kv_set "install_admin_policy" "$choice" || return 1

    if [[ "$choice" == "root" ]]; then
        local same root1 root2
        if ui_confirm "Usar a mesma senha do usuário para root?" "Usar mesma" "Definir outra"; then
            same="1"
        else
            same="0"
        fi
        state_kv_set "install_root_same_pass" "$same" || return 1
        if [[ "$same" == "1" ]]; then
            state_kv_set "install_root_pass" "${install_user_pass-}" || return 1
            return 0
        fi
        if ! root1="$(ui_password "Senha do root:")"; then
            return 1
        fi
        if ! root2="$(ui_password "Confirmar senha do root:")"; then
            return 1
        fi
        if [[ "$root1" != "$root2" ]]; then
            ui_error "As senhas de root não conferem."
            return 1
        fi
        state_kv_set "install_root_pass" "$root1" || return 1
    fi
}
