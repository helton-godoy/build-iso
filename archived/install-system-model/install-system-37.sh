#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_NAME="fileserver-installer"
SCRIPT_VERSION="1.0.0"

ROUTER_DEFAULT="./installer-router.sh"
STEPS_DIR_DEFAULT="./steps"
LIBS_DIR_DEFAULT="./libs"

STATE_DIR_DEFAULT="/var/lib/fileserver-installer"
LOG_DIR_DEFAULT="/var/log/fileserver-installer"

ROUTER="$ROUTER_DEFAULT"
STEPS_DIR="$STEPS_DIR_DEFAULT"
LIBS_DIR="$LIBS_DIR_DEFAULT"
STATE_DIR="$STATE_DIR_DEFAULT"
LOG_DIR="$LOG_DIR_DEFAULT"
NONINTERACTIVE="0"

stderr() { printf '%s\n' "$*" >&2; }
stdout() { printf '%s\n' "$*"; }

sanitize_ws() {
    local in; in="${1-}"
    in="${in//$'\r'/}"
    in="${in//$'\n'/}"
    printf '%s' "$in" | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//'
}

sanitize_path() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in" | sed -E 's/[[:cntrl:]]+//g'
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

mkdirs() {
    local dir; dir="$(sanitize_path "${1-}")"
    if [[ -z "$dir" ]]; then
        stderr "Erro: diretório vazio."
        return 1
    fi
    mkdir -p "$dir"
}

is_root() { [[ "${EUID:-$(id -u)}" == "0" ]]; }

print_banner() {
    stdout "──────────────────────────────────────────────────────────────────────"
    stdout " $SCRIPT_NAME  v$SCRIPT_VERSION"
    stdout " Debian 13 + ZFS on Root"
    stdout "──────────────────────────────────────────────────────────────────────"
}

usage() {
    stdout "Uso: $0 [--router PATH] [--steps-dir DIR] [--libs-dir DIR] [--state-dir DIR] [--log-dir DIR] [--noninteractive]"
}

parse_args() {
    local arg
    while [[ $# -gt 0 ]]; do
        arg="$(sanitize_ws "${1-}")"
        shift || true
        case "$arg" in
            --router)
                ROUTER="$(sanitize_path "${1-}")"; shift || true
                ;;
            --steps-dir)
                STEPS_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --libs-dir)
                LIBS_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --state-dir)
                STATE_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --log-dir)
                LOG_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --noninteractive)
                NONINTERACTIVE="1"
                ;;
            --version)
                stdout "$SCRIPT_NAME $SCRIPT_VERSION"
                return 2
                ;;
            --help|-h)
                usage
                return 2
                ;;
            *)
                stderr "Argumento inválido: $arg"
                usage
                return 1
                ;;
        esac
    done
}

validate_layout() {
    ROUTER="$(sanitize_path "$ROUTER")"
    STEPS_DIR="$(sanitize_path "$STEPS_DIR")"
    LIBS_DIR="$(sanitize_path "$LIBS_DIR")"
    STATE_DIR="$(sanitize_path "$STATE_DIR")"
    LOG_DIR="$(sanitize_path "$LOG_DIR")"

    if [[ -z "$ROUTER" || ! -f "$ROUTER" ]]; then
        stderr "Erro: router não encontrado: $ROUTER"
        return 1
    fi
    if [[ ! -x "$ROUTER" ]]; then
        chmod +x "$ROUTER" >/dev/null 2>&1 || true
    fi
    if [[ -z "$STEPS_DIR" || ! -d "$STEPS_DIR" ]]; then
        stderr "Erro: diretório de steps inválido: $STEPS_DIR"
        return 1
    fi
    if [[ -z "$LIBS_DIR" || ! -d "$LIBS_DIR" ]]; then
        stderr "Erro: diretório de libs inválido: $LIBS_DIR"
        return 1
    fi

    local needed_steps needed_libs s
    needed_steps="$(printf '%s\n' config_wizard.sh install.sh post_install.sh conclusion.sh)"
    needed_libs="$(printf '%s\n' auth-utils.sh net-utils.sh time-utils.sh disk-utils.sh zfs-utils.sh boot-utils.sh install-utils.sh post-utils.sh validate-utils.sh finalize-chroot.sh setup-zbm-config.sh disks-identify-suporte-types.sh)"

    while IFS= read -r s; do
        s="$(sanitize_ws "$s")"
        [[ -z "$s" ]] && continue
        if [[ ! -f "$STEPS_DIR/$s" ]]; then
            stderr "Erro: step ausente: $STEPS_DIR/$s"
            return 1
        fi
    done <<<"$needed_steps"

    while IFS= read -r s; do
        s="$(sanitize_ws "$s")"
        [[ -z "$s" ]] && continue
        if [[ ! -f "$LIBS_DIR/$s" ]]; then
            stderr "Erro: lib ausente: $LIBS_DIR/$s"
            return 1
        fi
    done <<<"$needed_libs"
}

check_prereqs() {
    require_cmd bash
    require_cmd sed
    require_cmd awk
    require_cmd grep
    require_cmd sort
    require_cmd lsblk
    require_cmd findmnt
    require_cmd mount
    require_cmd umount
    require_cmd wipefs
    require_cmd debootstrap
    require_cmd chroot

    if ! command -v zpool >/dev/null 2>&1 || ! command -v zfs >/dev/null 2>&1; then
        stderr "Erro: ferramentas ZFS ausentes no ambiente de instalação (zpool/zfs)."
        return 1
    fi

    if command -v gum >/dev/null 2>&1; then
        :
    fi
}

ensure_runtime_dirs() {
    mkdirs "$STATE_DIR"
    mkdirs "$LOG_DIR"
}

run_router() {
    local args=()
    args+=("--steps-dir" "$STEPS_DIR")
    args+=("--libs-dir" "$LIBS_DIR")
    args+=("--state-dir" "$STATE_DIR")
    args+=("--log-dir" "$LOG_DIR")
    if [[ "$NONINTERACTIVE" == "1" ]]; then
        args+=("--noninteractive")
    fi

    if ! "$ROUTER" "${args[@]}"; then
        stderr "Erro: instalador retornou falha."
        return 1
    fi
}

main() {
    require_cmd sed

    print_banner

    local prc
    if ! parse_args "$@"; then
        return 1
    fi
    prc=$?
    if [[ "$prc" == "2" ]]; then
        return 0
    fi

    if ! is_root; then
        stderr "Erro: execute como root."
        return 1
    fi

    validate_layout || return 1
    check_prereqs || return 1
    ensure_runtime_dirs || return 1
    run_router
}

main "$@"
