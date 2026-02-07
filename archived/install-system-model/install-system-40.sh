#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_NAME="installer-completeness-check"
SCRIPT_VERSION="1.0.0"

ROOT_DIR_DEFAULT="."
ROUTER_DEFAULT="installer-router.sh"
ENTRYPOINT_DEFAULT="fileserver-installer.sh"
STEPS_DIR_DEFAULT="steps"
LIBS_DIR_DEFAULT="libs"

ROOT_DIR="$ROOT_DIR_DEFAULT"
ROUTER="$ROUTER_DEFAULT"
ENTRYPOINT="$ENTRYPOINT_DEFAULT"
STEPS_DIR="$STEPS_DIR_DEFAULT"
LIBS_DIR="$LIBS_DIR_DEFAULT"

STRICT_EXEC="0"
CHECK_OPTIONALS="1"

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

sanitize_uint() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    if ! printf '%s' "$in" | grep -Eq '^[0-9]+$'; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in"
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

usage() {
    stdout "Uso: $0 [--root DIR] [--router FILE] [--entrypoint FILE] [--steps-dir DIR] [--libs-dir DIR] [--strict-exec] [--no-optionals] [--version]"
}

parse_args() {
    local arg
    while [[ $# -gt 0 ]]; do
        arg="$(sanitize_ws "${1-}")"
        shift || true
        case "$arg" in
            --root)
                ROOT_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --router)
                ROUTER="$(sanitize_path "${1-}")"; shift || true
                ;;
            --entrypoint)
                ENTRYPOINT="$(sanitize_path "${1-}")"; shift || true
                ;;
            --steps-dir)
                STEPS_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --libs-dir)
                LIBS_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --strict-exec)
                STRICT_EXEC="1"
                ;;
            --no-optionals)
                CHECK_OPTIONALS="0"
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

abs_path() {
    local p; p="$(sanitize_path "${1-}")"
    if [[ -z "$p" ]]; then
        printf '%s' ""
        return 0
    fi
    if [[ "$p" == /* ]]; then
        printf '%s' "$p"
        return 0
    fi
    printf '%s' "$(sanitize_path "$ROOT_DIR/$p")"
}

file_ok() {
    local p; p="$(sanitize_path "${1-}")"
    local strict; strict="$(sanitize_uint "${2-0}")"
    [[ -z "$strict" ]] && strict="0"
    if [[ -z "$p" || ! -f "$p" ]]; then
        return 1
    fi
    if [[ "$strict" == "1" && ! -x "$p" ]]; then
        return 1
    fi
}

dir_ok() {
    local p; p="$(sanitize_path "${1-}")"
    [[ -n "$p" && -d "$p" ]]
}

print_header() {
    stdout "──────────────────────────────────────────────────────────────────────"
    stdout " $SCRIPT_NAME v$SCRIPT_VERSION"
    stdout "──────────────────────────────────────────────────────────────────────"
}

ok_line() { stdout "✓ $(sanitize_ws "${1-}")"; }
warn_line() { stdout "⚠ $(sanitize_ws "${1-}")"; }
fail_line() { stderr "✗ $(sanitize_ws "${1-}")"; }

check_required_files() {
    local missing=0
    local router_abs entry_abs steps_abs libs_abs
    router_abs="$(abs_path "$ROUTER")"
    entry_abs="$(abs_path "$ENTRYPOINT")"
    steps_abs="$(abs_path "$STEPS_DIR")"
    libs_abs="$(abs_path "$LIBS_DIR")"

    if ! dir_ok "$ROOT_DIR"; then
        fail_line "Root não existe: $ROOT_DIR"
        return 1
    fi
    ok_line "Root: $ROOT_DIR"

    if file_ok "$router_abs" "$STRICT_EXEC"; then
        ok_line "Router: $router_abs"
    else
        fail_line "Router ausente/não executável: $router_abs"
        missing=$((missing + 1))
    fi

    if file_ok "$entry_abs" "$STRICT_EXEC"; then
        ok_line "Entrypoint: $entry_abs"
    else
        warn_line "Entrypoint ausente/não executável (opcional se usar router diretamente): $entry_abs"
    fi

    if dir_ok "$steps_abs"; then
        ok_line "Steps: $steps_abs"
    else
        fail_line "Steps dir ausente: $steps_abs"
        missing=$((missing + 1))
    fi

    if dir_ok "$libs_abs"; then
        ok_line "Libs:  $libs_abs"
    else
        fail_line "Libs dir ausente: $libs_abs"
        missing=$((missing + 1))
    fi

    local required_steps required_libs f fp
    required_steps="$(printf '%s\n' \
        "config_wizard.sh" \
        "install.sh" \
        "post_install.sh" \
        "conclusion.sh")"

    required_libs="$(printf '%s\n' \
        "auth-utils.sh" \
        "net-utils.sh" \
        "time-utils.sh" \
        "disk-utils.sh" \
        "zfs-utils.sh" \
        "boot-utils.sh" \
        "install-utils.sh" \
        "post-utils.sh" \
        "validate-utils.sh" \
        "finalize-chroot.sh" \
        "setup-zbm-config.sh" \
        "disks-identify-suporte-types.sh")"

    stdout ""
    stdout "Obrigatórios (steps):"
    while IFS= read -r f; do
        f="$(sanitize_ws "$f")"
        [[ -z "$f" ]] && continue
        fp="$(sanitize_path "$steps_abs/$f")"
        if file_ok "$fp" "0"; then
            ok_line "  $fp"
        else
            fail_line "  $fp"
            missing=$((missing + 1))
        fi
    done <<<"$required_steps"

    stdout ""
    stdout "Obrigatórios (libs):"
    while IFS= read -r f; do
        f="$(sanitize_ws "$f")"
        [[ -z "$f" ]] && continue
        fp="$(sanitize_path "$libs_abs/$f")"
        if file_ok "$fp" "0"; then
            ok_line "  $fp"
        else
            fail_line "  $fp"
            missing=$((missing + 1))
        fi
    done <<<"$required_libs"

    if [[ "$missing" -gt 0 ]]; then
        return 1
    fi
}

check_optionals() {
    local steps_abs libs_abs
    steps_abs="$(abs_path "$STEPS_DIR")"
    libs_abs="$(abs_path "$LIBS_DIR")"

    stdout ""
    stdout "Opcionais (não bloqueiam conclusão):"

    local optional_list p
    optional_list="$(printf '%s\n' \
        "$libs_abs/ui-theme.sh" \
        "$libs_abs/telemetry.sh" \
        "$libs_abs/hw-detect.sh" \
        "$steps_abs/zfs_manual.sh" \
        "$steps_abs/storage_check.sh" \
        "$steps_abs/network_apply.sh")"

    while IFS= read -r p; do
        p="$(sanitize_path "$p")"
        [[ -z "$p" ]] && continue
        if [[ -f "$p" ]]; then
            ok_line "  $p"
        else
            warn_line "  ausente: $p"
        fi
    done <<<"$optional_list"
}

main() {
    require_cmd sed
    require_cmd grep
    require_cmd printf

    print_header

    local prc
    if ! parse_args "$@"; then
        return 1
    fi
    prc=$?
    if [[ "$prc" == "2" ]]; then
        return 0
    fi

    ROOT_DIR="$(sanitize_path "$ROOT_DIR")"
    [[ -z "$ROOT_DIR" ]] && ROOT_DIR="."

    local ok=1
    stdout "Checagem de completude:"
    if check_required_files; then
        :
    else
        ok=0
    fi

    if [[ "$CHECK_OPTIONALS" == "1" ]]; then
        check_optionals || true
    fi

    stdout ""
    if [[ "$ok" == "1" ]]; then
        stdout "RESULTADO: CONCLUÍDO — fluxo padrão completo (config → install → post_install → conclusion)."
        return 0
    fi
    stderr "RESULTADO: AINDA NÃO — faltam arquivos obrigatórios (veja acima)."
    return 1
}

main "$@"
