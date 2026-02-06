 #!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_NAME="fileserver-installer-audit"
SCRIPT_VERSION="1.0.0"

ROUTER_SCRIPT_DEFAULT="./installer-router.sh"
STEPS_DIR_DEFAULT="./steps"
LIBS_DIR_DEFAULT="./libs"

PROJECT_MD_DEFAULT="/mnt/data/projeto.md"
DESIGN_MD_DEFAULT="/mnt/data/DESIGN_SYSTEM_v2.0.md"

LOG_DIR_DEFAULT="/var/log/fileserver-installer"
LOG_FILE_DEFAULT="$LOG_DIR_DEFAULT/audit.log"

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
        stderr "Erro: require_cmd recebeu comando vazio."
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

file_exists_readable() {
    local path; path="$(sanitize_path "${1-}")"
    [[ -n "$path" && -f "$path" && -r "$path" ]]
}

dir_exists_readable() {
    local path; path="$(sanitize_path "${1-}")"
    [[ -n "$path" && -d "$path" && -r "$path" ]]
}

usage() {
    stdout "Uso:"
    stdout "  $0 [--router FILE] [--steps-dir DIR] [--libs-dir DIR] [--projeto FILE] [--design FILE]"
    stdout ""
    stdout "Exemplos:"
    stdout "  $0 --router ./installer-router.sh --steps-dir ./steps --libs-dir ./libs"
    stdout "  $0 --projeto /mnt/data/projeto.md --design /mnt/data/DESIGN_SYSTEM_v2.0.md"
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
            --projeto|--project)
                PROJECT_MD="$(sanitize_path "${1-}")"; shift || true
                ;;
            --design)
                DESIGN_MD="$(sanitize_path "${1-}")"; shift || true
                ;;
            --help|-h)
                usage
                return 2
                ;;
            --version)
                stdout "$SCRIPT_NAME $SCRIPT_VERSION"
                return 2
                ;;
            *)
                stderr "Argumento inválido: $arg"
                usage >&2
                return 1
                ;;
        esac
    done
}

extract_modules_and_deps() {
    local router; router="$(sanitize_path "${1-}")"
    if ! file_exists_readable "$router"; then
        stderr "Erro: router não encontrado ou sem permissão: $router"
        return 1
    fi

    local raw
    if ! raw="$(sed -n -E 's/^[[:space:]]*register_step[[:space:]]+"[^"]+"[[:space:]]+"[^"]+"[[:space:]]+"[^"]+"[[:space:]]+"[^"]*"[[:space:]]+"[^"]*"[[:space:]]+"[^"]*"[[:space:]]+"([^"]*)"[[:space:]]+"([^"]*)"[[:space:]]+"([^"]*)".*$/\1\t\2\t\3/p' "$router")"; then
        stderr "Erro: falha ao extrair módulos/deps do router."
        return 1
    fi

    if [[ -z "$(sanitize_ws "$raw")" ]]; then
        stderr "Erro: nenhum register_step encontrado no router. Formato inesperado."
        return 1
    fi

    stdout "$raw"
}

split_csv() {
    local csv; csv="$(sanitize_ws "${1-}")"
    if [[ -z "$csv" ]]; then
        return 0
    fi
    printf '%s' "$csv" | awk -v RS=',' '{ gsub(/^[ \t]+|[ \t]+$/, "", $0); if (length($0)>0) print $0 }'
}

check_steps_modules() {
    local steps_dir; steps_dir="$(sanitize_path "${1-}")"
    local extracted; extracted="$(sanitize_ws "${2-}")"

    local missing=0
    local present=0

    local line deps module handler
    while IFS=$'\t' read -r deps module handler; do
        deps="$(sanitize_ws "$deps")"
        module="$(sanitize_ws "$module")"
        handler="$(sanitize_ws "$handler")"

        if [[ -n "$module" ]]; then
            local mod_path
            if [[ "$module" == /* ]]; then
                mod_path="$module"
            else
                mod_path="$steps_dir/$module"
            fi

            if file_exists_readable "$mod_path"; then
                present=$((present + 1))
                log_line "INFO" "MÓDULO OK: $mod_path"
            else
                missing=$((missing + 1))
                log_line "WARN" "MÓDULO AUSENTE: $mod_path (handler: $handler)"
            fi
        fi
    done <<<"$extracted"

    printf '%s\t%s\n' "$present" "$missing"
}

check_lib_deps() {
    local libs_dir; libs_dir="$(sanitize_path "${1-}")"
    local extracted; extracted="$(sanitize_ws "${2-}")"

    local missing=0
    local present=0

    local line deps module handler dep path
    while IFS=$'\t' read -r deps module handler; do
        deps="$(sanitize_ws "$deps")"
        if [[ -z "$deps" ]]; then
            continue
        fi
        while IFS= read -r dep; do
            dep="$(sanitize_ws "$dep")"
            if [[ -z "$dep" ]]; then
                continue
            fi
            if [[ "$dep" == /* ]]; then
                path="$dep"
            else
                path="$libs_dir/$dep"
            fi
            if file_exists_readable "$path"; then
                present=$((present + 1))
                log_line "INFO" "DEP OK: $path"
            else
                missing=$((missing + 1))
                log_line "WARN" "DEP AUSENTE: $path"
            fi
        done < <(split_csv "$deps")
    done <<<"$extracted"

    printf '%s\t%s\n' "$present" "$missing"
}

scan_router_placeholders() {
    local router; router="$(sanitize_path "${1-}")"
    if ! file_exists_readable "$router"; then
        stderr "Erro: router não encontrado: $router"
        return 1
    fi

    local placeholders
    if ! placeholders="$(grep -nE 'placeholder|skeleton|Implementação real|router skeleton' "$router" 2>/dev/null || true)"; then
        placeholders=""
    fi

    if [[ -n "$(sanitize_ws "$placeholders")" ]]; then
        stdout "$placeholders"
        return 0
    fi
    return 1
}

check_docs_presence() {
    local projeto; projeto="$(sanitize_path "${1-}")"
    local design; design="$(sanitize_path "${2-}")"
    local ok=0

    if file_exists_readable "$projeto"; then
        log_line "INFO" "DOC OK: $projeto"
    else
        log_line "WARN" "DOC AUSENTE/SEM PERMISSÃO: $projeto"
        ok=1
    fi

    if file_exists_readable "$design"; then
        log_line "INFO" "DOC OK: $design"
    else
        log_line "WARN" "DOC AUSENTE/SEM PERMISSÃO: $design"
        ok=1
    fi

    return "$ok"
}

print_summary() {
    local router; router="$(sanitize_path "${1-}")"
    local steps_dir; steps_dir="$(sanitize_path "${2-}")"
    local libs_dir; libs_dir="$(sanitize_path "${3-}")"
    local projeto; projeto="$(sanitize_path "${4-}")"
    local design; design="$(sanitize_path "${5-}")"
    local steps_present; steps_present="$(sanitize_ws "${6-0}")"
    local steps_missing; steps_missing="$(sanitize_ws "${7-0}")"
    local deps_present; deps_present="$(sanitize_ws "${8-0}")"
    local deps_missing; deps_missing="$(sanitize_ws "${9-0}")"
    local ph_lines; ph_lines="${10-}"

    stdout ""
    stdout "══════════════════════════════════════════════════════════════════════"
    stdout "AUDITORIA: Interação do Router / Lazy Loading / Dependências"
    stdout "══════════════════════════════════════════════════════════════════════"
    stdout "Router:     $router"
    stdout "Steps dir:  $steps_dir"
    stdout "Libs dir:   $libs_dir"
    stdout "Docs:       projeto=$(printf '%s' "$projeto")  design=$(printf '%s' "$design")"
    stdout "──────────────────────────────────────────────────────────────────────"
    stdout "Módulos de steps:  presentes=$steps_present  ausentes=$steps_missing"
    stdout "Deps de libs:      presentes=$deps_present   ausentes=$deps_missing"
    stdout "──────────────────────────────────────────────────────────────────────"

    if [[ -n "$(sanitize_ws "$ph_lines")" ]]; then
        stdout "Observações no router (indicando necessidade de módulos reais):"
        stdout "$ph_lines"
        stdout "──────────────────────────────────────────────────────────────────────"
    fi

    if [[ "$steps_missing" != "0" || "$deps_missing" != "0" ]]; then
        stdout "RESULTADO: Necessita scripts adicionais (steps/deps) para cumprir requisitos."
        stdout "Detalhes: veja $LOG_FILE"
        stdout "══════════════════════════════════════════════════════════════════════"
        return 1
    fi

    if [[ -n "$(sanitize_ws "$ph_lines")" ]]; then
        stdout "RESULTADO: Estrutura ok, mas há handlers placeholders; recomenda-se implementar módulos."
        stdout "Detalhes: veja $LOG_FILE"
        stdout "══════════════════════════════════════════════════════════════════════"
        return 1
    fi

    stdout "RESULTADO: Estrutura parece completa (módulos/deps presentes)."
    stdout "Detalhes: veja $LOG_FILE"
    stdout "══════════════════════════════════════════════════════════════════════"
}

main() {
    LOG_DIR="$LOG_DIR_DEFAULT"
    LOG_FILE="$LOG_FILE_DEFAULT"

    ROUTER_SCRIPT="$ROUTER_SCRIPT_DEFAULT"
    STEPS_DIR="$STEPS_DIR_DEFAULT"
    LIBS_DIR="$LIBS_DIR_DEFAULT"
    PROJECT_MD="$PROJECT_MD_DEFAULT"
    DESIGN_MD="$DESIGN_MD_DEFAULT"

    log_init

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
    PROJECT_MD="$(sanitize_path "$PROJECT_MD")"
    DESIGN_MD="$(sanitize_path "$DESIGN_MD")"

    if [[ -z "$ROUTER_SCRIPT" ]]; then
        stderr "Erro: router script inválido."
        return 1
    fi
    if [[ -z "$STEPS_DIR" ]]; then
        STEPS_DIR="$STEPS_DIR_DEFAULT"
    fi
    if [[ -z "$LIBS_DIR" ]]; then
        LIBS_DIR="$LIBS_DIR_DEFAULT"
    fi

    if ! file_exists_readable "$ROUTER_SCRIPT"; then
        stderr "Erro: router não encontrado/sem permissão: $ROUTER_SCRIPT"
        return 1
    fi

    if ! dir_exists_readable "$STEPS_DIR"; then
        log_line "WARN" "Steps dir ausente/sem permissão: $STEPS_DIR"
    fi
    if ! dir_exists_readable "$LIBS_DIR"; then
        log_line "WARN" "Libs dir ausente/sem permissão: $LIBS_DIR"
    fi

    if command -v gum >/dev/null 2>&1; then
        log_line "INFO" "Dependência OK: gum"
    else
        log_line "WARN" "Dependência ausente: gum (UI pode falhar)"
    fi

    check_docs_presence "$PROJECT_MD" "$DESIGN_MD" || true

    local extracted
    extracted="$(extract_modules_and_deps "$ROUTER_SCRIPT")"

    local steps_stats deps_stats
    local steps_present steps_missing deps_present deps_missing

    if ! steps_stats="$(check_steps_modules "$STEPS_DIR" "$extracted")"; then
        steps_stats="0 0"
    fi
    steps_present="$(sanitize_ws "$(printf '%s' "$steps_stats" | awk -F'\t' '{print $1}')" )"
    steps_missing="$(sanitize_ws "$(printf '%s' "$steps_stats" | awk -F'\t' '{print $2}')" )"

    if ! deps_stats="$(check_lib_deps "$LIBS_DIR" "$extracted")"; then
        deps_stats="0 0"
    fi
    deps_present="$(sanitize_ws "$(printf '%s' "$deps_stats" | awk -F'\t' '{print $1}')" )"
    deps_missing="$(sanitize_ws "$(printf '%s' "$deps_stats" | awk -F'\t' '{print $2}')" )"

    local ph_lines
    ph_lines="$(scan_router_placeholders "$ROUTER_SCRIPT" || true)"

    if [[ -z "$steps_present" ]]; then steps_present="0"; fi
    if [[ -z "$steps_missing" ]]; then steps_missing="0"; fi
    if [[ -z "$deps_present" ]]; then deps_present="0"; fi
    if [[ -z "$deps_missing" ]]; then deps_missing="0"; fi

    if ! print_summary \
        "$ROUTER_SCRIPT" \
        "$STEPS_DIR" \
        "$LIBS_DIR" \
        "$PROJECT_MD" \
        "$DESIGN_MD" \
        "$steps_present" \
        "$steps_missing" \
        "$deps_present" \
        "$deps_missing" \
        "$ph_lines"; then
        return 1
    fi
}

main "$@"

