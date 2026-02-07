#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_NAME="fileserver-installer-next"
SCRIPT_VERSION="1.0.0"

ROUTER_SCRIPT_DEFAULT="./installer-router.sh"
STEPS_DIR_DEFAULT="./steps"
LIBS_DIR_DEFAULT="./libs"

ROUTER_SCRIPT="$ROUTER_SCRIPT_DEFAULT"
STEPS_DIR="$STEPS_DIR_DEFAULT"
LIBS_DIR="$LIBS_DIR_DEFAULT"

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

sanitize_id() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_]+/_/g; s/^_+//; s/_+$//'
}

file_readable() {
    local path; path="$(sanitize_path "${1-}")"
    [[ -n "$path" && -f "$path" && -r "$path" ]]
}

dir_readable() {
    local path; path="$(sanitize_path "${1-}")"
    [[ -n "$path" && -d "$path" && -r "$path" ]]
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

parse_args() {
    local arg
    while [[ $# -gt 0 ]]; do
        arg="$(sanitize_ws "${1-}")"
        shift || true
        case "$arg" in
            --router)
                ROUTER_SCRIPT="$(sanitize_path "${1-}")"; shift || true
                ;;
            --steps-dir)
                STEPS_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --libs-dir)
                LIBS_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --version)
                stdout "$SCRIPT_NAME $SCRIPT_VERSION"
                return 2
                ;;
            --help|-h)
                stdout "Uso: $0 [--router FILE] [--steps-dir DIR] [--libs-dir DIR]"
                return 2
                ;;
            *)
                stderr "Argumento inválido: $arg"
                return 1
                ;;
        esac
    done
}

extract_register_step_rows() {
    local router; router="$(sanitize_path "${1-}")"
    if ! file_readable "$router"; then
        stderr "Erro: router não encontrado/sem permissão: $router"
        return 1
    fi
    # step_id \t title \t deps \t module \t handler
    sed -n -E 's/^[[:space:]]*register_step[[:space:]]+"([^"]+)"[[:space:]]+"[^"]+"[[:space:]]+"([^"]+)"[[:space:]]+"[^"]+"[[:space:]]+"[^"]*"[[:space:]]+"[^"]*"[[:space:]]+"([^"]*)"[[:space:]]+"([^"]*)"[[:space:]]+"([^"]*)".*$/\1\t\2\t\3\t\4\t\5/p' "$router"
}

split_csv_lines() {
    local csv; csv="$(sanitize_ws "${1-}")"
    if [[ -z "$csv" ]]; then
        return 0
    fi
    printf '%s' "$csv" | awk -v RS=',' '{ gsub(/^[ \t]+|[ \t]+$/, "", $0); if (length($0)>0) print $0 }'
}

resolve_step_module_path() {
    local steps_dir; steps_dir="$(sanitize_path "${1-}")"
    local module; module="$(sanitize_ws "${2-}")"
    if [[ -z "$module" ]]; then
        printf '%s' ""
        return
    fi
    if [[ "$module" == /* ]]; then
        printf '%s' "$(sanitize_path "$module")"
        return
    fi
    printf '%s' "$(sanitize_path "$steps_dir/$module")"
}

resolve_dep_path() {
    local libs_dir; libs_dir="$(sanitize_path "${1-}")"
    local dep; dep="$(sanitize_ws "${2-}")"
    if [[ -z "$dep" ]]; then
        printf '%s' ""
        return
    fi
    if [[ "$dep" == /* ]]; then
        printf '%s' "$(sanitize_path "$dep")"
        return
    fi
    printf '%s' "$(sanitize_path "$libs_dir/$dep")"
}

collect_missing() {
    local router; router="$(sanitize_path "${1-}")"
    local steps_dir; steps_dir="$(sanitize_path "${2-}")"
    local libs_dir; libs_dir="$(sanitize_path "${3-}")"

    local rows
    rows="$(extract_register_step_rows "$router")"
    if [[ -z "$(sanitize_ws "$rows")" ]]; then
        stderr "Erro: nenhum register_step encontrado."
        return 1
    fi

    local missing_steps missing_deps total_steps total_deps
    missing_steps=0
    missing_deps=0
    total_steps=0
    total_deps=0

    local step_id title deps module handler mod_path dep dep_path
    local miss_steps_list miss_deps_list
    miss_steps_list=""
    miss_deps_list=""

    while IFS=$'\t' read -r step_id title deps module handler; do
        step_id="$(sanitize_id "$step_id")"
        title="$(sanitize_ws "$title")"
        deps="$(sanitize_ws "$deps")"
        module="$(sanitize_ws "$module")"
        handler="$(sanitize_ws "$handler")"

        if [[ -n "$module" ]]; then
            total_steps=$((total_steps + 1))
            mod_path="$(resolve_step_module_path "$steps_dir" "$module")"
            if [[ -n "$mod_path" && ! -f "$mod_path" ]]; then
                missing_steps=$((missing_steps + 1))
                miss_steps_list+=$(printf '%s\t%s\t%s\t%s\n' "$step_id" "$title" "$module" "$mod_path")
            fi
        fi

        if [[ -n "$deps" ]]; then
            while IFS= read -r dep; do
                dep="$(sanitize_ws "$dep")"
                if [[ -z "$dep" ]]; then
                    continue
                fi
                total_deps=$((total_deps + 1))
                dep_path="$(resolve_dep_path "$libs_dir" "$dep")"
                if [[ -n "$dep_path" && ! -f "$dep_path" ]]; then
                    missing_deps=$((missing_deps + 1))
                    miss_deps_list+=$(printf '%s\t%s\n' "$dep" "$dep_path")
                fi
            done < <(split_csv_lines "$deps")
        fi
    done <<<"$rows"

    stdout "══════════════════════════════════════════════════════════════════════"
    stdout "STATUS: Próximos arquivos esperados (Steps/Deps) — Lazy Loading"
    stdout "══════════════════════════════════════════════════════════════════════"
    stdout "Router:    $router"
    stdout "Steps dir: $steps_dir"
    stdout "Libs dir:  $libs_dir"
    stdout "──────────────────────────────────────────────────────────────────────"
    stdout "Steps (módulos): total_referenciados=$total_steps  ausentes=$missing_steps"
    stdout "Deps (libs):     total_referenciados=$total_deps   ausentes=$missing_deps"
    stdout "──────────────────────────────────────────────────────────────────────"

    if [[ "$missing_steps" -gt 0 ]]; then
        stdout "PRÓXIMOS (módulos de step ausentes):"
        stdout "$(printf '%-18s %-24s %-22s %s\n' "STEP_ID" "TITLE" "MODULE" "PATH")"
        stdout "$(printf '%s\n' "$(printf '=%.0s' {1..96})")"
        printf '%s' "$miss_steps_list" | awk -F'\t' '
            {
                sid=$1; title=$2; mod=$3; path=$4;
                if (length(title)>24) title=substr(title,1,24);
                if (length(mod)>22) mod=substr(mod,1,22);
                printf "%-18s %-24s %-22s %s\n", sid, title, mod, path
            }'
        stdout "──────────────────────────────────────────────────────────────────────"
        stdout "PRÓXIMO SUGERIDO: implementar o PRIMEIRO módulo acima (ordem do fluxo)."
    else
        stdout "PRÓXIMOS (módulos de step): nenhum — todos presentes."
    fi

    if [[ "$missing_deps" -gt 0 ]]; then
        stdout "──────────────────────────────────────────────────────────────────────"
        stdout "PRÓXIMOS (deps de libs ausentes):"
        stdout "$(printf '%-34s %s\n' "DEP" "PATH")"
        stdout "$(printf '%s\n' "$(printf '=%.0s' {1..70})")"
        printf '%s' "$miss_deps_list" | awk -F'\t' '
            { dep=$1; path=$2; if (length(dep)>34) dep=substr(dep,1,34); printf "%-34s %s\n", dep, path }'
    else
        stdout "──────────────────────────────────────────────────────────────────────"
        stdout "PRÓXIMOS (deps de libs): nenhum — todos presentes."
    fi

    stdout "──────────────────────────────────────────────────────────────────────"
    stdout "RESPOSTA DIRETA:"
    stdout "  - O próximo arquivo a ser enviado/implementado é o PRIMEIRO item em 'módulos de step ausentes'."
    stdout "  - Quantos arquivos faltam: steps_ausentes=$missing_steps + deps_ausentes=$missing_deps = $((missing_steps + missing_deps))"
    stdout "══════════════════════════════════════════════════════════════════════"
}

main() {
    require_cmd sed
    require_cmd awk
    require_cmd grep

    local parse_rc
    if ! parse_args "$@"; then
        return 1
    fi
    parse_rc=$?
    if [[ "$parse_rc" == "2" ]]; then
        return 0
    fi

    ROUTER_SCRIPT="$(sanitize_path "$ROUTER_SCRIPT")"
    STEPS_DIR="$(sanitize_path "$STEPS_DIR")"
    LIBS_DIR="$(sanitize_path "$LIBS_DIR")"

    if [[ -z "$ROUTER_SCRIPT" ]]; then
        ROUTER_SCRIPT="$ROUTER_SCRIPT_DEFAULT"
    fi
    if [[ -z "$STEPS_DIR" ]]; then
        STEPS_DIR="$STEPS_DIR_DEFAULT"
    fi
    if [[ -z "$LIBS_DIR" ]]; then
        LIBS_DIR="$LIBS_DIR_DEFAULT"
    fi

    if ! file_readable "$ROUTER_SCRIPT"; then
        stderr "Erro: router não encontrado/sem permissão: $ROUTER_SCRIPT"
        return 1
    fi
    if ! dir_readable "$STEPS_DIR"; then
        stderr "Aviso: steps-dir não encontrado/sem permissão: $STEPS_DIR"
    fi
    if ! dir_readable "$LIBS_DIR"; then
        stderr "Aviso: libs-dir não encontrado/sem permissão: $LIBS_DIR"
    fi

    collect_missing "$ROUTER_SCRIPT" "$STEPS_DIR" "$LIBS_DIR"
}

main "$@"
