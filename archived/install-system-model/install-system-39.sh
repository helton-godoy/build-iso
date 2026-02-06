#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_NAME="installer-audit"
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

FAIL_FAST="0"
STRICT_EXEC="0"

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
    stdout "Uso: $0 [--root DIR] [--router FILE] [--entrypoint FILE] [--steps-dir DIR] [--libs-dir DIR] [--fail-fast] [--strict-exec] [--version]"
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
            --fail-fast)
                FAIL_FAST="1"
                ;;
            --strict-exec)
                STRICT_EXEC="1"
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

file_exists() {
    local p; p="$(sanitize_path "${1-}")"
    [[ -n "$p" && -f "$p" ]]
}

dir_exists() {
    local p; p="$(sanitize_path "${1-}")"
    [[ -n "$p" && -d "$p" ]]
}

is_executable_if_required() {
    local p; p="$(sanitize_path "${1-}")"
    local req; req="$(sanitize_uint "${2-0}")"
    if [[ -z "$req" ]]; then
        req="0"
    fi
    if [[ "$req" != "1" ]]; then
        return 0
    fi
    [[ -x "$p" ]]
}

print_header() {
    stdout "──────────────────────────────────────────────────────────────────────"
    stdout " $SCRIPT_NAME v$SCRIPT_VERSION"
    stdout " Auditoria de arquivos do instalador (manifest + dependências)"
    stdout "──────────────────────────────────────────────────────────────────────"
}

report_ok() { stdout "✓ $(sanitize_ws "${1-}")"; }
report_warn() { stdout "⚠ $(sanitize_ws "${1-}")"; }
report_fail() { stderr "✗ $(sanitize_ws "${1-}")"; }

audit_required_structure() {
    local missing=0

    ROOT_DIR="$(sanitize_path "$ROOT_DIR")"
    [[ -z "$ROOT_DIR" ]] && ROOT_DIR="."

    local router_abs entry_abs steps_abs libs_abs
    router_abs="$(abs_path "$ROUTER")"
    entry_abs="$(abs_path "$ENTRYPOINT")"
    steps_abs="$(abs_path "$STEPS_DIR")"
    libs_abs="$(abs_path "$LIBS_DIR")"

    if dir_exists "$ROOT_DIR"; then
        report_ok "Root: $ROOT_DIR"
    else
        report_fail "Root não existe: $ROOT_DIR"
        return 1
    fi

    if file_exists "$router_abs"; then
        if is_executable_if_required "$router_abs" "$STRICT_EXEC"; then
            report_ok "Router: $router_abs"
        else
            report_warn "Router existe, mas não executável (strict): $router_abs"
            missing=$((missing + 1))
        fi
    else
        report_fail "Router ausente: $router_abs"
        missing=$((missing + 1))
        [[ "$FAIL_FAST" == "1" ]] && return 1
    fi

    if file_exists "$entry_abs"; then
        if is_executable_if_required "$entry_abs" "$STRICT_EXEC"; then
            report_ok "Entrypoint: $entry_abs"
        else
            report_warn "Entrypoint existe, mas não executável (strict): $entry_abs"
            missing=$((missing + 1))
        fi
    else
        report_warn "Entrypoint não encontrado (opcional se você chama o router direto): $entry_abs"
    fi

    if dir_exists "$steps_abs"; then
        report_ok "Steps dir: $steps_abs"
    else
        report_fail "Steps dir ausente: $steps_abs"
        missing=$((missing + 1))
        [[ "$FAIL_FAST" == "1" ]] && return 1
    fi

    if dir_exists "$libs_abs"; then
        report_ok "Libs dir: $libs_abs"
    else
        report_fail "Libs dir ausente: $libs_abs"
        missing=$((missing + 1))
        [[ "$FAIL_FAST" == "1" ]] && return 1
    fi

    if [[ "$missing" -gt 0 ]]; then
        return 1
    fi
}

audit_required_files() {
    local steps_abs libs_abs
    steps_abs="$(abs_path "$STEPS_DIR")"
    libs_abs="$(abs_path "$LIBS_DIR")"

    local missing=0

    local required_steps required_libs
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
    stdout "Arquivos obrigatórios (steps):"
    local f fp
    while IFS= read -r f; do
        f="$(sanitize_ws "$f")"
        [[ -z "$f" ]] && continue
        fp="$(sanitize_path "$steps_abs/$f")"
        if file_exists "$fp"; then
            report_ok "  $fp"
        else
            report_fail "  $fp"
            missing=$((missing + 1))
            [[ "$FAIL_FAST" == "1" ]] && return 1
        fi
    done <<<"$required_steps"

    stdout ""
    stdout "Arquivos obrigatórios (libs):"
    while IFS= read -r f; do
        f="$(sanitize_ws "$f")"
        [[ -z "$f" ]] && continue
        fp="$(sanitize_path "$libs_abs/$f")"
        if file_exists "$fp"; then
            report_ok "  $fp"
        else
            report_fail "  $fp"
            missing=$((missing + 1))
            [[ "$FAIL_FAST" == "1" ]] && return 1
        fi
    done <<<"$required_libs"

    if [[ "$missing" -gt 0 ]]; then
        return 1
    fi
}

audit_router_declared_deps_best_effort() {
    local router_abs
    router_abs="$(abs_path "$ROUTER")"
    if [[ ! -f "$router_abs" ]]; then
        report_warn "Router ausente; pulando auditoria de deps declaradas."
        return 0
    fi

    stdout ""
    stdout "Auditoria (best-effort) de deps declaradas no router:"

    require_cmd sed || return 1
    require_cmd awk || return 1
    require_cmd grep || return 1

    local tmp
    tmp="$(mktemp 2>/dev/null || true)"
    tmp="$(sanitize_path "$tmp")"
    if [[ -z "$tmp" ]]; then
        report_warn "mktemp falhou; pulando auditoria de deps."
        return 0
    fi

    # Extract register_step deps and module fields:
    # register_step "id" "order" "title" "desc" "prev" "next" "deps" "module" "handler"
    # Capture deps (field 7) and module (field 8) naive-quoted parsing.
    if ! awk '
        BEGIN{FS="\""}
        $0 ~ /^[[:space:]]*register_step[[:space:]]+/ {
            # naive: expect quoted fields; deps is 15th token, module is 17th token in FS="\""
            id=$2
            deps=$15
            mod=$17
            if(id!=""){
                print "STEP\t"id
                print "DEPS\t"deps
                print "MOD\t"mod
            }
        }' "$router_abs" >"$tmp" 2>/dev/null; then
        rm -f "$tmp" >/dev/null 2>&1 || true
        report_warn "Falha ao extrair deps do router; pulando."
        return 0
    fi

    local libs_abs steps_abs
    libs_abs="$(abs_path "$LIBS_DIR")"
    steps_abs="$(abs_path "$STEPS_DIR")"

    local missing=0
    local cur_step="" line kind val dep path
    while IFS= read -r line; do
        line="$(sanitize_ws "$line")"
        [[ -z "$line" ]] && continue
        kind="$(printf '%s' "$line" | awk -F'\t' '{print $1}' | head -n1)"
        val="$(printf '%s' "$line" | awk -F'\t' '{print $2}' | head -n1)"
        kind="$(sanitize_ws "$kind")"
        val="$(sanitize_ws "$val")"

        if [[ "$kind" == "STEP" ]]; then
            cur_step="$val"
            continue
        fi

        if [[ "$kind" == "MOD" ]]; then
            [[ -z "$val" ]] && continue
            path="$(sanitize_path "$steps_abs/$val")"
            if file_exists "$path"; then
                report_ok "  [$cur_step] module: $path"
            else
                report_fail "  [$cur_step] module ausente: $path"
                missing=$((missing + 1))
                [[ "$FAIL_FAST" == "1" ]] && { rm -f "$tmp" >/dev/null 2>&1 || true; return 1; }
            fi
            continue
        fi

        if [[ "$kind" == "DEPS" ]]; then
            [[ -z "$val" ]] && continue
            while IFS= read -r dep; do
                dep="$(sanitize_ws "$dep")"
                [[ -z "$dep" ]] && continue
                path="$(sanitize_path "$libs_abs/$dep")"
                if file_exists "$path"; then
                    report_ok "  [$cur_step] dep: $path"
                else
                    report_fail "  [$cur_step] dep ausente: $path"
                    missing=$((missing + 1))
                    [[ "$FAIL_FAST" == "1" ]] && { rm -f "$tmp" >/dev/null 2>&1 || true; return 1; }
                fi
            done < <(printf '%s' "$val" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; /^[[:space:]]*$/d')
        fi
    done <"$tmp"

    rm -f "$tmp" >/dev/null 2>&1 || true

    if [[ "$missing" -gt 0 ]]; then
        return 1
    fi
}

audit_recommended_files() {
    local steps_abs libs_abs
    steps_abs="$(abs_path "$STEPS_DIR")"
    libs_abs="$(abs_path "$LIBS_DIR")"

    stdout ""
    stdout "Recomendados (não-bloqueantes):"

    local rec
    rec="$(printf '%s\n' \
        "$libs_abs/ui-theme.sh" \
        "$libs_abs/telemetry.sh" \
        "$libs_abs/hw-detect.sh" \
        "$steps_abs/zfs_manual.sh" \
        "$steps_abs/storage_check.sh" \
        "$steps_abs/network_apply.sh")"

    local p
    while IFS= read -r p; do
        p="$(sanitize_path "$p")"
        [[ -z "$p" ]] && continue
        if file_exists "$p"; then
            report_ok "  $p"
        else
            report_warn "  ausente: $p"
        fi
    done <<<"$rec"
}

main() {
    require_cmd sed
    require_cmd awk
    require_cmd grep
    require_cmd sort

    print_header

    local prc
    if ! parse_args "$@"; then
        return 1
    fi
    prc=$?
    if [[ "$prc" == "2" ]]; then
        return 0
    fi

    local ok=1
    stdout ""
    stdout "Estrutura:"
    if audit_required_structure; then
        :
    else
        ok=0
    fi

    stdout ""
    if audit_required_files; then
        :
    else
        ok=0
    fi

    if audit_router_declared_deps_best_effort; then
        :
    else
        ok=0
    fi

    audit_recommended_files || true

    stdout ""
    if [[ "$ok" == "1" ]]; then
        stdout "RESULTADO: OK — o instalador está completo para o fluxo padrão (config → install → post_install → conclusion)."
        return 0
    fi
    stderr "RESULTADO: FALHA — faltam arquivos obrigatórios ou permissões (veja acima)."
    return 1
}

main "$@"
