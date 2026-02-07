#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: auth-utils.sh
# Purpose: credential rules, password confirmation helpers, safe hashing, admin policy helpers
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

AUTHUTILS_ALLOWED_USER_RE_DEFAULT='^[a-z_][a-z0-9_-]{0,31}$'
AUTHUTILS_PW_MIN_LEN_DEFAULT="10"
AUTHUTILS_PW_MAX_LEN_DEFAULT="128"

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
    printf '%s' "$in" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.:-]+/_/g; s/^_+//; s/_+$//'
}

require_cmd() {
    local cmd; cmd="$(sanitize_ws "${1-}")"
    if [[ -z "$cmd" ]]; then
        stderr "Erro: comando vazio."
        return 1
    fi
    if ! command -v "$cmd" >/dev/null 2>&1; then
        stderr "Erro: dependência ausente: $cmd"
        return 1
    fi
}

authutils_loaded() { :; }

authutils_is_username() {
    local u; u="$(sanitize_ws "${1-}")"
    [[ -n "$u" && "$u" =~ $AUTHUTILS_ALLOWED_USER_RE_DEFAULT ]]
}

authutils_password_len_ok() {
    local pw; pw="${1-}"
    local min; min="$(sanitize_ws "${2-}")"
    local max; max="$(sanitize_ws "${3-}")"
    if [[ -z "$min" ]]; then
        min="$AUTHUTILS_PW_MIN_LEN_DEFAULT"
    fi
    if [[ -z "$max" ]]; then
        max="$AUTHUTILS_PW_MAX_LEN_DEFAULT"
    fi
    if ! printf '%s' "$min" | grep -Eq '^[0-9]+$'; then
        min="$AUTHUTILS_PW_MIN_LEN_DEFAULT"
    fi
    if ! printf '%s' "$max" | grep -Eq '^[0-9]+$'; then
        max="$AUTHUTILS_PW_MAX_LEN_DEFAULT"
    fi

    local len
    len="$(printf '%s' "$pw" | wc -c | awk '{print $1}' 2>/dev/null || true)"
    len="$(sanitize_ws "$len")"
    if [[ -z "$len" ]] || ! printf '%s' "$len" | grep -Eq '^[0-9]+$'; then
        return 1
    fi

    if ! printf '%s' "$len" | awk -v min="$min" -v max="$max" '{exit !($1+0>=min+0 && $1+0<=max+0)}'; then
        return 1
    fi
}

authutils_password_complexity_ok() {
    # Single responsibility: enforce simple complexity policy (best-effort)
    # Args: password
    local pw; pw="${1-}"
    if [[ -z "$(sanitize_ws "$pw")" ]]; then
        return 1
    fi
    # Requires at least 1 letter and 1 digit; allows symbols.
    if ! printf '%s' "$pw" | grep -Eq '[A-Za-z]'; then
        return 1
    fi
    if ! printf '%s' "$pw" | grep -Eq '[0-9]'; then
        return 1
    fi
}

authutils_password_validate_all() {
    # Single responsibility: validate password by length + complexity
    # Args: password min max
    local pw; pw="${1-}"
    local min; min="$(sanitize_ws "${2-}")"
    local max; max="$(sanitize_ws "${3-}")"
    authutils_password_len_ok "$pw" "$min" "$max" || return 1
    authutils_password_complexity_ok "$pw" || return 1
}

authutils_passwords_match() {
    local a; a="${1-}"
    local b; b="${2-}"
    [[ "$a" == "$b" ]]
}

authutils_hash_password_sha512crypt() {
    # Single responsibility: produce a salted SHA512-crypt hash (for /etc/shadow)
    # Args: password
    local pw; pw="${1-}"
    if [[ -z "$(sanitize_ws "$pw")" ]]; then
        stderr "Erro: senha vazia para hash."
        return 1
    fi

    if command -v mkpasswd >/dev/null 2>&1; then
        mkpasswd --method=sha-512 --rounds=500000 "$pw" 2>/dev/null || return 1
        return 0
    fi

    if command -v openssl >/dev/null 2>&1; then
        # openssl passwd -6 may be disabled by policy in some builds; handle failure.
        local out
        out="$(openssl passwd -6 "$pw" 2>/dev/null || true)"
        out="$(sanitize_ws "$out")"
        if [[ -z "$out" ]]; then
            stderr "Erro: openssl passwd -6 indisponível."
            return 1
        fi
        stdout "$out"
        return 0
    fi

    stderr "Erro: sem mkpasswd/openssl para gerar hash."
    return 1
}

authutils_admin_policy_is_root() {
    local v; v="$(sanitize_id "${1-}")"
    [[ "$v" == "root" ]]
}

authutils_admin_policy_is_sudo() {
    local v; v="$(sanitize_id "${1-}")"
    [[ "$v" == "sudo" ]]
}

authutils_normalize_bool01() {
    local v; v="$(sanitize_ws "${1-}")"
    case "$v" in
        1|on|yes|true) stdout "1" ;;
        0|off|no|false|"") stdout "0" ;;
        *) stdout "0" ;;
    esac
}
