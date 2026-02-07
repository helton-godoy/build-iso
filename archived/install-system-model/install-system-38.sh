#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

PROJECT_NAME="FILESERVER INSTALLER"
PROJECT_TAGLINE="Debian 13 + ZFS on Root"
PROJECT_BOOT_ID="debian"

SCRIPT_NAME="installer-router"
SCRIPT_VERSION="2.2.0"

STEPS_DIR_DEFAULT="./steps"
LIBS_DIR_DEFAULT="./libs"

STATE_DIR_DEFAULT="/var/lib/fileserver-installer"
STATE_FILE_DEFAULT="$STATE_DIR_DEFAULT/state.env"
LOG_DIR_DEFAULT="/var/log/fileserver-installer"
LOG_FILE_DEFAULT="$LOG_DIR_DEFAULT/installer.log"

UI_THEME_PRIMARY_DEFAULT="#7C3AED"
UI_THEME_MUTED_DEFAULT="#6B7280"
UI_THEME_DANGER_DEFAULT="#EF4444"
UI_THEME_SUCCESS_DEFAULT="#10B981"
UI_THEME_WARN_DEFAULT="#F59E0B"

UI_BULLET="•"
UI_WARN="⚠"
UI_OK="✓"
UI_X="✗"

STEPS_DIR="$STEPS_DIR_DEFAULT"
LIBS_DIR="$LIBS_DIR_DEFAULT"
STATE_DIR="$STATE_DIR_DEFAULT"
STATE_FILE="$STATE_FILE_DEFAULT"
LOG_DIR="$LOG_DIR_DEFAULT"
LOG_FILE="$LOG_FILE_DEFAULT"

GUM_BIN=""
NONINTERACTIVE="0"

declare -A STEP_ORDER=()
declare -A STEP_TITLE=()
declare -A STEP_DESC=()
declare -A STEP_PREV=()
declare -A STEP_NEXT=()
declare -A STEP_DEPS=()
declare -A STEP_MODULE=()
declare -A STEP_HANDLER=()

CURRENT_STEP_ID=""

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
    ts="$(sanitize_ws "$ts")"
    [[ -z "$ts" ]] && ts="unknown-time"
    printf '%s [%s] %s\n' "$ts" "$level" "$msg" >>"$LOG_FILE" 2>/dev/null || true
}

trap_cleanup() {
    local sig; sig="$(sanitize_ws "${1-TERM}")"
    log_line "WARN" "Encerrando por sinal: $sig"
    ui_warn "Encerrando por sinal: $sig"
    return 0
}

trap 'trap_cleanup INT' INT
trap 'trap_cleanup TERM' TERM
trap 'trap_cleanup HUP' HUP

ui_has_gum() {
    if [[ -n "$GUM_BIN" ]]; then
        return 0
    fi
    if command -v gum >/dev/null 2>&1; then
        GUM_BIN="gum"
        return 0
    fi
    return 1
}

ui_theme_primary() { printf '%s' "${UI_THEME_PRIMARY_DEFAULT}"; }
ui_theme_muted() { printf '%s' "${UI_THEME_MUTED_DEFAULT}"; }
ui_theme_danger() { printf '%s' "${UI_THEME_DANGER_DEFAULT}"; }
ui_theme_success() { printf '%s' "${UI_THEME_SUCCESS_DEFAULT}"; }
ui_theme_warn() { printf '%s' "${UI_THEME_WARN_DEFAULT}"; }

ui_plain_hr() { stdout "──────────────────────────────────────────────────────────────────────"; }

ui_plain_title() {
    local a; a="$(sanitize_ws "${1-}")"
    local b; b="$(sanitize_ws "${2-}")"
    ui_plain_hr
    stdout "$a"
    [[ -n "$b" ]] && stdout "$b"
    ui_plain_hr
}

ui_plain_error() { stderr "${UI_X} $(sanitize_ws "${1-}")"; }
ui_plain_warn() { stdout "${UI_WARN} $(sanitize_ws "${1-}")"; }
ui_plain_success() { stdout "${UI_OK} $(sanitize_ws "${1-}")"; }

ui_plain_confirm() {
    local prompt; prompt="$(sanitize_ws "${1-Confirmar?}")"
    if [[ "$NONINTERACTIVE" == "1" ]]; then
        return 0
    fi
    stdout "$prompt [s/N]: "
    local ans
    IFS= read -r ans || true
    ans="$(sanitize_id "$ans")"
    [[ "$ans" == "s" || "$ans" == "sim" || "$ans" == "y" || "$ans" == "yes" ]]
}

ui_hero() {
    local title; title="$(sanitize_ws "${1-$PROJECT_NAME}")"
    local subtitle; subtitle="$(sanitize_ws "${2-$PROJECT_TAGLINE}")"
    if ui_has_gum; then
        "$GUM_BIN" style --foreground "$(ui_theme_primary)" --bold --padding "1 2" --border "rounded" "$title"
        "$GUM_BIN" style --foreground "$(ui_theme_muted)" --padding "0 2" "$subtitle"
        return 0
    fi
    ui_plain_title "$title" "$subtitle"
}

ui_section() {
    local title; title="$(sanitize_ws "${1-}")"
    if ui_has_gum; then
        "$GUM_BIN" style --bold --foreground "$(ui_theme_primary)" --padding "0 1" "▌ $title"
        return 0
    fi
    stdout ""
    stdout "== $title =="
}

ui_card() {
    local title; title="$(sanitize_ws "${1-}")"
    shift || true
    if ui_has_gum; then
        local body
        body="$(printf '%s\n' "$@")"
        "$GUM_BIN" style --border "rounded" --padding "1 2" --foreground "$(ui_theme_muted)" --border-foreground "$(ui_theme_primary)" \
            "$(printf '%s\n\n%s' "$title" "$body")"
        return 0
    fi
    ui_plain_hr
    stdout "$title"
    ui_plain_hr
    printf '%s\n' "$@"
    ui_plain_hr
}

ui_error() {
    local msg; msg="$(sanitize_ws "${1-}")"
    log_line "ERROR" "$msg"
    if ui_has_gum; then
        "$GUM_BIN" style --foreground "$(ui_theme_danger)" --bold "${UI_X} $msg" >&2
        return 0
    fi
    ui_plain_error "$msg"
}

ui_warn() {
    local msg; msg="$(sanitize_ws "${1-}")"
    log_line "WARN" "$msg"
    if ui_has_gum; then
        "$GUM_BIN" style --foreground "$(ui_theme_warn)" --bold "${UI_WARN} $msg"
        return 0
    fi
    ui_plain_warn "$msg"
}

ui_success() {
    local msg; msg="$(sanitize_ws "${1-}")"
    log_line "INFO" "$msg"
    if ui_has_gum; then
        "$GUM_BIN" style --foreground "$(ui_theme_success)" --bold "${UI_OK} $msg"
        return 0
    fi
    ui_plain_success "$msg"
}

ui_confirm() {
    local prompt; prompt="$(sanitize_ws "${1-Confirmar?}")"
    local ok; ok="$(sanitize_ws "${2-Confirmar}")"
    local cancel; cancel="$(sanitize_ws "${3-Cancelar}")"
    if [[ "$NONINTERACTIVE" == "1" ]]; then
        return 0
    fi
    if ui_has_gum; then
        "$GUM_BIN" confirm "$prompt" --affirmative="$ok" --negative="$cancel"
        return $?
    fi
    ui_plain_confirm "$prompt"
}

ui_choose_from_stdin() {
    local header; header="$(sanitize_ws "${1-Selecionar:}")"
    local height; height="$(sanitize_uint "${2-15}")"
    if [[ -z "$height" ]]; then
        height="15"
    fi
    if [[ "$NONINTERACTIVE" == "1" ]]; then
        local first
        first="$(head -n1 2>/dev/null || true)"
        first="$(sanitize_ws "$first")"
        printf '%s' "$first"
        return 0
    fi
    if ui_has_gum; then
        "$GUM_BIN" choose --header "$header" --height "$height" 2>/dev/null || true
        return 0
    fi
    local i=1 opt chosen
    while IFS= read -r opt; do
        opt="$(sanitize_ws "$opt")"
        [[ -z "$opt" ]] && continue
        stdout "  [$i] $opt"
        i=$((i + 1))
    done
    stdout "Escolha: "
    IFS= read -r chosen || true
    chosen="$(sanitize_uint "$chosen")"
    if [[ -z "$chosen" ]]; then
        printf '%s' ""
        return 0
    fi
    # Re-read stdin is not possible here; caller should not use this in plain mode for large lists.
    printf '%s' ""
}

ui_select() {
    local prompt; prompt="$(sanitize_ws "${1-Selecionar:}")"
    shift || true
    if [[ "$NONINTERACTIVE" == "1" ]]; then
        printf '%s' "$(sanitize_ws "${1-}")"
        return 0
    fi
    if ui_has_gum; then
        printf '%s\n' "$@" | "$GUM_BIN" choose --header "$prompt" --height 15 2>/dev/null || true
        return 0
    fi
    stdout "$prompt"
    local i=1 opt
    for opt in "$@"; do
        stdout "  [$i] $opt"
        i=$((i + 1))
    done
    stdout "Escolha: "
    local ans
    IFS= read -r ans || true
    ans="$(sanitize_uint "$ans")"
    [[ -z "$ans" ]] && { printf '%s' ""; return 0; }
    printf '%s' "${@:$ans:1}"
}

state_init() {
    mkdirs "$STATE_DIR"
    if [[ ! -f "$STATE_FILE" ]]; then
        : >"$STATE_FILE"
    fi
}

state_load() {
    state_init
    set +o nounset
    # shellcheck disable=SC1090
    . "$STATE_FILE" 2>/dev/null || true
    set -o nounset
}

state_kv_set() {
    state_init
    local key; key="$(sanitize_id "${1-}")"
    local val; val="$(sanitize_ws "${2-}")"

    if [[ -z "$key" ]]; then
        stderr "Erro: state_kv_set key vazia."
        return 1
    fi

    local esc
    esc="$(printf '%s' "$val" | sed -E 's/\\/\\\\/g; s/"/\\"/g')"
    if grep -Eq "^[[:space:]]*${key}=" "$STATE_FILE" 2>/dev/null; then
        sed -i -E "s|^[[:space:]]*${key}=.*$|${key}=\"${esc}\"|g" "$STATE_FILE" || return 1
    else
        printf '%s="%s"\n' "$key" "$esc" >>"$STATE_FILE"
    fi
}

state_kv_get() {
    state_load || true
    local key; key="$(sanitize_id "${1-}")"
    [[ -z "$key" ]] && { printf '%s' ""; return; }
    # shellcheck disable=SC2154
    local val; val="${!key-}"
    val="$(sanitize_ws "$val")"
    printf '%s' "$val"
}

register_step() {
    local step_id; step_id="$(sanitize_id "${1-}")"
    local order; order="$(sanitize_uint "${2-}")"
    local title; title="$(sanitize_ws "${3-}")"
    local desc; desc="$(sanitize_ws "${4-}")"
    local prev; prev="$(sanitize_id "${5-}")"
    local next; next="$(sanitize_id "${6-}")"
    local deps; deps="$(sanitize_ws "${7-}")"
    local module; module="$(sanitize_ws "${8-}")"
    local handler; handler="$(sanitize_ws "${9-}")"

    if [[ -z "$step_id" || -z "$order" || -z "$title" || -z "$handler" ]]; then
        stderr "Erro: register_step parâmetros inválidos."
        return 1
    fi

    STEP_ORDER["$step_id"]="$order"
    STEP_TITLE["$step_id"]="$title"
    STEP_DESC["$step_id"]="$desc"
    STEP_PREV["$step_id"]="$prev"
    STEP_NEXT["$step_id"]="$next"
    STEP_DEPS["$step_id"]="$deps"
    STEP_MODULE["$step_id"]="$module"
    STEP_HANDLER["$step_id"]="$handler"
}

steps_list_sorted() {
    local tmp
    tmp="$(mktemp 2>/dev/null || true)"
    tmp="$(sanitize_path "$tmp")"
    [[ -z "$tmp" ]] && return 1

    local k
    for k in "${!STEP_ORDER[@]}"; do
        printf '%s\t%s\n' "${STEP_ORDER[$k]}" "$k" >>"$tmp"
    done

    sort -n "$tmp" | cut -f2-
    rm -f "$tmp" >/dev/null 2>&1 || true
}

lazy_source_file() {
    local file; file="$(sanitize_path "${1-}")"
    if [[ -z "$file" ]]; then
        stderr "Erro: lazy_source_file path vazio."
        return 1
    fi
    if [[ ! -f "$file" ]]; then
        stderr "Erro: arquivo não encontrado: $file"
        return 1
    fi
    # shellcheck disable=SC1090
    . "$file"
}

lazy_load_deps_csv() {
    local deps; deps="$(sanitize_ws "${1-}")"
    [[ -z "$deps" ]] && return 0

    local dep
    while IFS= read -r dep; do
        dep="$(sanitize_ws "$dep")"
        [[ -z "$dep" ]] && continue

        local path
        if [[ "$dep" == /* ]]; then
            path="$dep"
        else
            path="$LIBS_DIR/$dep"
        fi
        path="$(sanitize_path "$path")"
        if [[ ! -f "$path" ]]; then
            ui_error "Dependência ausente: $path"
            return 1
        fi
        lazy_source_file "$path" || return 1
    done < <(printf '%s' "$deps" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; /^[[:space:]]*$/d')
}

lazy_load_step_module() {
    local step_id; step_id="$(sanitize_id "${1-}")"
    [[ -z "$step_id" ]] && { stderr "Erro: step_id vazio."; return 1; }

    local deps; deps="$(sanitize_ws "${STEP_DEPS[$step_id]-}")"
    lazy_load_deps_csv "$deps" || return 1

    local module; module="$(sanitize_ws "${STEP_MODULE[$step_id]-}")"
    [[ -z "$module" ]] && return 0

    local path
    if [[ "$module" == /* ]]; then
        path="$module"
    else
        path="$STEPS_DIR/$module"
    fi
    path="$(sanitize_path "$path")"
    if [[ ! -f "$path" ]]; then
        ui_error "Módulo do step ausente: $path"
        return 1
    fi
    lazy_source_file "$path" || return 1
}

run_step() {
    local step_id; step_id="$(sanitize_id "${1-}")"
    if [[ -z "$step_id" ]]; then
        ui_error "Step inválido."
        return 1
    fi
    if [[ -z "${STEP_HANDLER[$step_id]-}" ]]; then
        ui_error "Step não registrado: $step_id"
        return 1
    fi

    CURRENT_STEP_ID="$step_id"
    state_kv_set "current_step_id" "$step_id" || true

    lazy_load_step_module "$step_id" || return 1

    local handler; handler="$(sanitize_ws "${STEP_HANDLER[$step_id]-}")"
    if [[ -z "$handler" ]]; then
        ui_error "Handler vazio para step: $step_id"
        return 1
    fi
    if ! declare -F "$handler" >/dev/null 2>&1; then
        ui_error "Handler não encontrado após load: $handler"
        return 1
    fi

    log_line "INFO" "Executando step=$step_id handler=$handler"
    if "$handler"; then
        state_kv_set "last_step_ok" "$step_id" || true
        return 0
    fi
    state_kv_set "last_step_failed" "$step_id" || true
    return 1
}

menu_main_entries_print() {
    local ids
    ids="$(steps_list_sorted)" || return 1

    local id title done
    while IFS= read -r id; do
        id="$(sanitize_id "$id")"
        title="$(sanitize_ws "${STEP_TITLE[$id]-$id}")"
        done="$(sanitize_ws "$(state_kv_get "step_${id}_done")")"
        if [[ "$done" == "1" ]]; then
            printf '%s\n' "${UI_OK}  ${title}  [${id}]"
        else
            printf '%s\n' "    ${title}  [${id}]"
        fi
    done <<<"$ids"

    printf '%s\n' "────────"
    printf '%s\n' "Resumo / Revisão"
    printf '%s\n' "Sair"
}

menu_pick_step_id_from_label() {
    local label; label="$(sanitize_ws "${1-}")"
    [[ -z "$label" ]] && { printf '%s' ""; return; }
    local id
    id="$(printf '%s' "$label" | sed -nE 's/.*\[(.+)\].*/\1/p' | head -n1 || true)"
    id="$(sanitize_id "$id")"
    printf '%s' "$id"
}

step_review() {
    ui_hero "${PROJECT_NAME}" "${PROJECT_TAGLINE}"
    ui_section "Resumo / Revisão"

    state_load || true

    local ids
    ids="$(steps_list_sorted)" || true
    if [[ -z "$(sanitize_ws "$ids")" ]]; then
        ui_error "Nenhum step registrado."
        return 1
    fi

    ui_card "Estado atual" \
        "  ${UI_BULLET} Estado: ${STATE_FILE}" \
        "  ${UI_BULLET} Log:    ${LOG_FILE}" \
        "  ${UI_BULLET} Step atual: $(sanitize_ws "$(state_kv_get current_step_id)")" \
        "  ${UI_BULLET} Último OK:   $(sanitize_ws "$(state_kv_get last_step_ok)")" \
        "  ${UI_BULLET} Último FAIL: $(sanitize_ws "$(state_kv_get last_step_failed)")"

    local lines="" id title done
    while IFS= read -r id; do
        id="$(sanitize_id "$id")"
        title="$(sanitize_ws "${STEP_TITLE[$id]-$id}")"
        done="$(sanitize_ws "$(state_kv_get "step_${id}_done")")"
        if [[ "$done" == "1" ]]; then
            lines+=$(printf '%s %s [%s]\n' "${UI_OK}" "$title" "$id")
        else
            lines+=$(printf '%s %s [%s]\n' "${UI_X}" "$title" "$id")
        fi
    done <<<"$ids"

    ui_card "Checklist" "$lines"
    ui_confirm "Voltar ao menu?" "Voltar" "Sair"
}

boot_register_steps_default() {
    register_step "config" "10" "Assistente de Configuração" "Coleta guiada de configurações" "" "review" \
        "auth-utils.sh,net-utils.sh,time-utils.sh,disk-utils.sh,zfs-utils.sh,validate-utils.sh" \
        "config_wizard.sh" "step_config_wizard"

    register_step "review" "50" "Resumo da Configuração" "Verificar estado e configurações" "config" "install" \
        "" "" "step_review"

    register_step "install" "60" "Instalação do Sistema Base" "Disk + ZFS + debootstrap + kernel" "review" "post_install" \
        "disk-utils.sh,zfs-utils.sh,boot-utils.sh,install-utils.sh,validate-utils.sh,disks-identify-suporte-types.sh" \
        "install.sh" "step_install"

    register_step "post_install" "70" "Configurações Pós-Instalação" "Hostname/locale/users/services/boot" "install" "conclusion" \
        "boot-utils.sh,install-utils.sh,post-utils.sh,time-utils.sh,net-utils.sh,validate-utils.sh,finalize-chroot.sh,setup-zbm-config.sh" \
        "post_install.sh" "step_post_install"

    register_step "conclusion" "90" "Conclusão" "Unmount/export + reboot" "post_install" "" \
        "boot-utils.sh,install-utils.sh,zfs-utils.sh" \
        "conclusion.sh" "step_conclusion"
}

parse_args() {
    local arg
    while [[ $# -gt 0 ]]; do
        arg="$(sanitize_ws "${1-}")"
        shift || true
        case "$arg" in
            --steps-dir)
                STEPS_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --libs-dir)
                LIBS_DIR="$(sanitize_path "${1-}")"; shift || true
                ;;
            --state-dir)
                STATE_DIR="$(sanitize_path "${1-}")"; shift || true
                STATE_FILE="$STATE_DIR/state.env"
                ;;
            --log-dir)
                LOG_DIR="$(sanitize_path "${1-}")"; shift || true
                LOG_FILE="$LOG_DIR/installer.log"
                ;;
            --noninteractive)
                NONINTERACTIVE="1"
                ;;
            --version)
                stdout "$SCRIPT_NAME $SCRIPT_VERSION"
                return 2
                ;;
            --help|-h)
                stdout "Uso: $0 [--steps-dir DIR] [--libs-dir DIR] [--state-dir DIR] [--log-dir DIR] [--noninteractive]"
                return 2
                ;;
            *)
                stderr "Argumento inválido: $arg"
                return 1
                ;;
        esac
    done
}

ensure_dirs() {
    [[ -z "$STEPS_DIR" ]] && STEPS_DIR="$STEPS_DIR_DEFAULT"
    [[ -z "$LIBS_DIR" ]] && LIBS_DIR="$LIBS_DIR_DEFAULT"

    STEPS_DIR="$(sanitize_path "$STEPS_DIR")"
    LIBS_DIR="$(sanitize_path "$LIBS_DIR")"
    STATE_DIR="$(sanitize_path "$STATE_DIR")"
    STATE_FILE="$(sanitize_path "$STATE_FILE")"
    LOG_DIR="$(sanitize_path "$LOG_DIR")"
    LOG_FILE="$(sanitize_path "$LOG_FILE")"

    mkdirs "$STATE_DIR"
    mkdirs "$LOG_DIR"

    [[ ! -f "$STATE_FILE" ]] && : >"$STATE_FILE"
    [[ ! -f "$LOG_FILE" ]] && : >"$LOG_FILE"
}

menu_loop() {
    state_load || true

    while true; do
        ui_hero "${PROJECT_NAME}" "${PROJECT_TAGLINE}"

        local choice
        if ui_has_gum && [[ "$NONINTERACTIVE" != "1" ]]; then
            choice="$(menu_main_entries_print | "$GUM_BIN" choose --header "Selecione uma etapa" --height 15 2>/dev/null || true)"
        else
            # Fallback: simple numbered select (first option if empty)
            local entries=()
            local line
            while IFS= read -r line; do
                line="$(sanitize_ws "$line")"
                [[ -z "$line" ]] && continue
                entries+=("$line")
            done < <(menu_main_entries_print)
            choice="$(ui_select "Selecione uma etapa" "${entries[@]}")"
        fi

        choice="$(sanitize_ws "$choice")"
        if [[ -z "$choice" ]]; then
            if ui_confirm "Sair do instalador?" "Sair" "Continuar"; then
                return 0
            fi
            continue
        fi

        if [[ "$choice" == "Sair" ]]; then
            return 0
        fi

        if [[ "$choice" == "Resumo / Revisão" ]]; then
            step_review || true
            continue
        fi

        if [[ "$choice" == "────────" ]]; then
            continue
        fi

        local step_id
        step_id="$(menu_pick_step_id_from_label "$choice")"
        step_id="$(sanitize_id "$step_id")"
        if [[ -z "$step_id" ]]; then
            ui_error "Seleção inválida."
            continue
        fi

        if run_step "$step_id"; then
            state_kv_set "step_${step_id}_done" "1" || true
            ui_success "Etapa concluída: ${STEP_TITLE[$step_id]-$step_id}"
        else
            ui_warn "Etapa não concluída: ${STEP_TITLE[$step_id]-$step_id}"
        fi

        if [[ "$NONINTERACTIVE" == "1" ]]; then
            return 0
        fi
    done
}

main() {
    require_cmd sed
    require_cmd awk
    require_cmd grep
    require_cmd sort

    log_init

    local parse_rc
    if ! parse_args "$@"; then
        return 1
    fi
    parse_rc=$?
    if [[ "$parse_rc" == "2" ]]; then
        return 0
    fi

    ensure_dirs || return 1
    boot_register_steps_default || return 1
    menu_loop
}

main "$@"
