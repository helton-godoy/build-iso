#!/usr/bin/env bash
# state-utils.sh - Gerenciamento de estado e persistência (key-value)

state_prepare() {
    mkdirs "$STATE_DIR"
    if [[ ! -f "$STATE_FILE" ]]; then
        : >"$STATE_FILE"
    fi
}

state_kv_set() {
    local key; key="$(sanitize_id "${1-}")"
    local val; val="$(sanitize_ws "${2-}")"
    if [[ -z "$key" ]]; then
        stderr "Erro: state_kv_set key vazia."
        return 1
    fi
    if [[ ! -f "$STATE_FILE" ]]; then
        state_prepare || return 1
    fi
    # Se existe, substitui; senão apenda.
    if grep -Eq "^${key}=" "$STATE_FILE"; then
        sed -i -E "s|^${key}=.*$|${key}=$(printf '%q' "$val")|" "$STATE_FILE" || return 1
    else
        printf '%s=%q\n' "$key" "$val" >>"$STATE_FILE" || return 1
    fi
}

state_kv_get() {
    local key; key="$(sanitize_id "${1-}")"
    if [[ -f "$STATE_FILE" ]]; then
        local val
        # Source state file in a subshell to avoid polluting current shell, 
        # or grab the value via grep/sed?
        # Sourcing is dangerous if values are not safe, but state_kv_set uses printf %q so it's "safer".
        # But grabbing just the var is better.
        val="$(grep "^${key}=" "$STATE_FILE" | tail -n1 | cut -d= -f2-)"
        # eval to unquote? printf %q adds quotes.
        # eval echo "$val"
        # BASH printf %q might output 'value' or value or value\ space.
        # Let's use source for simplicity as we control the file writing.
        (
            source "$STATE_FILE" >/dev/null 2>&1
            echo "${!key}"
        )
    fi
}

state_load() {
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$STATE_FILE" || return 1
    fi
}
