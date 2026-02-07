#!/usr/bin/env bash
# core-utils.sh - Utilitários fundamentais (logging, sanitization, IO)

stderr() { printf '%s\n' "$*" >&2; }
stdout() { printf '%s\n' "$*"; }

sanitize_ws() {
    local in; in="${1-}"
    in="${in//$'\r'/}"
    in="${in//$'\n'/}"
    printf '%s' "$in" | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//'
}

sanitize_id() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_]+/_/g; s/^_+//; s/_+$//'
}

sanitize_path() {
    local in; in="$(sanitize_ws "${1-}")"
    # Basic path sanitization
    printf '%s' "$in"
}

require_cmd() {
    local cmd; cmd="$(sanitize_ws "${1-}")"
    if [[ -z "$cmd" ]]; then
        stderr "Erro: require_cmd recebeu comando vazio."
        return 1
    fi
    if ! command -v "$cmd" >/dev/null 2>&1; then
        stderr "Erro: dependência ausente: $cmd"
        return 1
    fi
}

mkdirs() {
    local dir; dir="$(sanitize_ws "${1-}")"
    if [[ -z "$dir" ]]; then
        stderr "Erro: mkdirs recebeu diretório vazio."
        return 1
    fi
    mkdir -p "$dir"
}

log_init() {
    mkdirs "$LOG_DIR"
    : >"$LOG_FILE"
}

log_line() {
    local level; level="$(sanitize_ws "${1-INFO}")"
    local msg; msg="$(sanitize_ws "${2-}")"
    local ts
    ts="$(date -Is 2>/dev/null || true)"
    if [[ -z "$(sanitize_ws "$ts")" ]]; then
        ts="unknown-time"
    fi
    printf '%s [%s] %s\n' "$ts" "$level" "$msg" >>"$LOG_FILE" 2>/dev/null || true
}

die() {
    local msg; msg="$(sanitize_ws "${1-Erro desconhecido.}")"
    LAST_ERROR="$msg"
    log_line "ERROR" "$msg"
    stderr "$msg"
    return 1
}
