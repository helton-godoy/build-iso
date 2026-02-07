 #!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# ──────────────────────────────────────────────────────────────────────────────
# FILESERVER Installer Router (Debian 13 + ZFS) — Step Map + Lazy Loading
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_NAME="fileserver-installer-router"
SCRIPT_VERSION="2.0.0"
PROJECT_NAME="FILESERVER INSTALLER"
PROJECT_TAGLINE="Debian 13 + ZFS on Root"
DEFAULT_STEP="welcome"
STATE_DIR_DEFAULT="/run/fileserver-installer"
STATE_FILE_DEFAULT="$STATE_DIR_DEFAULT/state.env"
STEPS_DIR_DEFAULT="./steps"
LIBS_DIR_DEFAULT="./libs"
LOG_DIR_DEFAULT="/var/log/fileserver-installer"
LOG_FILE_DEFAULT="$LOG_DIR_DEFAULT/installer.log"

GUM_BIN_DEFAULT="gum"
GUM_STYLE_WIDTH_DEFAULT="68"

export STATE_DIR="${STATE_DIR:-$STATE_DIR_DEFAULT}"
export STATE_FILE="${STATE_FILE:-$STATE_DIR/state.env}"
export STEPS_DIR="${STEPS_DIR:-$STEPS_DIR_DEFAULT}"
export LIBS_DIR="${LIBS_DIR:-$LIBS_DIR_DEFAULT}"
export LOG_DIR="${LOG_DIR:-$LOG_DIR_DEFAULT}"
export LOG_FILE="${LOG_FILE:-$LOG_DIR/installer.log}"

export GUM_BIN="$GUM_BIN_DEFAULT"
export GUM_STYLE_WIDTH="$GUM_STYLE_WIDTH_DEFAULT"

# ──────────────────────────────────────────────────────────────────────────────
# Design System (Monochrome Slate) — minimal subset aligned to DS v2.0
# ──────────────────────────────────────────────────────────────────────────────

export DS_VOID=235
export DS_DEPTH=237
export DS_ELEVATION=239

export DS_WHISPER=240
export DS_MIST=243

export DS_FOG=245
export DS_HAZE=248
export DS_CLOUD=250
export DS_SILVER=252

export DS_SLATE_DIM=66
export DS_SLATE=67
export DS_SLATE_GLOW=68
export DS_FILESERVER_PEAK=153

export DS_SUCCESS=108
export DS_WARNING=179
export DS_ERROR=167

export UI_H='─'
export UI_H_D='═'
export UI_V='│'
export UI_TL='┌'
export UI_TR='┐'
export UI_BL='└'
export UI_BR='┘'
export UI_ARROW='▶'
export UI_BULLET='●'
export UI_CHECK='✓'
export UI_WARN='⚠'

# ──────────────────────────────────────────────────────────────────────────────
# Globals (State)
# ──────────────────────────────────────────────────────────────────────────────

export CURRENT_STEP="$DEFAULT_STEP"
export NEXT_STEP=""
export PREV_STEP=""
export LAST_ERROR=""
export INSTALL_PROFILE=""

# ──────────────────────────────────────────────────────────────────────────────
# Step Registry (Stable IDs)
# ──────────────────────────────────────────────────────────────────────────────

declare -A STEP_TITLE=()
declare -A STEP_DESC=()
declare -A STEP_ORDER=()
declare -A STEP_NEXT=()
declare -A STEP_PREV=()
declare -A STEP_DEPS=()
declare -A STEP_MODULE=()
declare -A STEP_HANDLER=()
declare -a STEP_IDS=()

# ──────────────────────────────────────────────────────────────────────────────
# Utilities
# ──────────────────────────────────────────────────────────────────────────────

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

trap_cleanup() {
    local code; code="${1-0}"
    local msg
    msg="Encerrando ($code)."
    log_line "INFO" "$msg"
}

on_sigint() { trap_cleanup 130; }
on_sigterm() { trap_cleanup 143; }

setup_traps() {
    trap 'on_sigint' INT
    trap 'on_sigterm' TERM
}

# ──────────────────────────────────────────────────────────────────────────────
# Gum UI Components (DS v2.0 aligned)
# ──────────────────────────────────────────────────────────────────────────────

ui_require() {
    require_cmd "$GUM_BIN" || return 1
}

ui_clear() { command clear || true; }

ui_hero() {
    local title; title="$(sanitize_ws "${1-}")"
    local subtitle; subtitle="$(sanitize_ws "${2-}")"
    ui_clear
    "$GUM_BIN" style \
        --foreground "$DS_FILESERVER_PEAK" \
        --border-foreground "$DS_SLATE" \
        --border double \
        --align center --width "$GUM_STYLE_WIDTH" \
        --margin "1 2" --padding "1 2" \
        "$title" "$subtitle"
}

ui_section() {
    local label; label="$(sanitize_ws "${1-}")"
    "$GUM_BIN" style --foreground "$DS_MIST" --bold "$(printf '─%.0s' {1..68})"
    "$GUM_BIN" style --foreground "$DS_SILVER" --bold "  $UI_ARROW $label"
    "$GUM_BIN" style --foreground "$DS_MIST" --bold "$(printf '─%.0s' {1..68})"
}

ui_card() {
    local title; title="$(sanitize_ws "${1-}")"
    shift || true
    local body; body="$(printf '%s\n' "$@" | sed -E 's/\r$//')"
    "$GUM_BIN" style \
        --border-foreground "$DS_WHISPER" \
        --border normal \
        --padding "1 2" --margin "1 2" \
        "$( "$GUM_BIN" style --foreground "$DS_SLATE_GLOW" --bold "$title" )" \
        "$( "$GUM_BIN" style --foreground "$DS_MIST" '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' )" \
        "$( "$GUM_BIN" style --foreground "$DS_CLOUD" "$body" )"
}

ui_error() {
    local msg; msg="$(sanitize_ws "${1-}")"
    "$GUM_BIN" style --border normal --border-foreground "$DS_ERROR" --padding "1 2" --margin "1 2" \
        "$( "$GUM_BIN" style --foreground "$DS_ERROR" --bold "❌ ERRO" )" \
        "$( "$GUM_BIN" style --foreground "$DS_CLOUD" "$msg" )"
}

ui_success() {
    local msg; msg="$(sanitize_ws "${1-}")"
    "$GUM_BIN" style --border normal --border-foreground "$DS_SUCCESS" --padding "1 2" --margin "1 2" \
        "$( "$GUM_BIN" style --foreground "$DS_SUCCESS" --bold "✓ OK" )" \
        "$( "$GUM_BIN" style --foreground "$DS_CLOUD" "$msg" )"
}

ui_confirm() {
    local prompt; prompt="$(sanitize_ws "${1-Confirmar?}")"
    local yes; yes="$(sanitize_ws "${2-Sim}")"
    local no; no="$(sanitize_ws "${3-Não}")"
    if "$GUM_BIN" confirm "$prompt" --affirmative "$yes" --negative "$no"; then
        return 0
    fi
    return 1
}

ui_select() {
    local prompt; prompt="$(sanitize_ws "${1-Selecione:}")"
    shift || true
    "$GUM_BIN" choose --cursor "$UI_ARROW" --header "$prompt" "$@"
}

ui_input() {
    local prompt; prompt="$(sanitize_ws "${1-}")"
    local placeholder; placeholder="$(sanitize_ws "${2-}")"
    "$GUM_BIN" input --prompt "$prompt " --placeholder "$placeholder"
}

ui_password() {
    local prompt; prompt="$(sanitize_ws "${1-Senha:}")"
    "$GUM_BIN" input --password --prompt "$prompt "
}

# ──────────────────────────────────────────────────────────────────────────────
# State I/O
# ──────────────────────────────────────────────────────────────────────────────

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
    if grep -Eq "^${key}=" "$STATE_FILE"; then
        sed -i -E "s|^${key}=.*$|${key}=$(printf '%q' "$val")|" "$STATE_FILE" || return 1
    else
        printf '%s=%q\n' "$key" "$val" >>"$STATE_FILE" || return 1
    fi
}

state_load() {
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$STATE_FILE" || return 1
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Step Registration + Lazy Loading
# ──────────────────────────────────────────────────────────────────────────────

register_step() {
    local id; id="$(sanitize_id "${1-}")"
    local order; order="$(sanitize_ws "${2-}")"
    local title; title="$(sanitize_ws "${3-}")"
    local desc; desc="$(sanitize_ws "${4-}")"
    local prev; prev="$(sanitize_id "${5-}")"
    local next; next="$(sanitize_id "${6-}")"
    local deps; deps="$(sanitize_ws "${7-}")"
    local module; module="$(sanitize_ws "${8-}")"
    local handler; handler="$(sanitize_ws "${9-}")"

    if [[ -z "$id" || -z "$order" || -z "$title" || -z "$handler" ]]; then
        stderr "Erro: register_step parâmetros inválidos (id/order/title/handler obrigatórios)."
        return 1
    fi

    STEP_TITLE["$id"]="$title"
    STEP_DESC["$id"]="$desc"
    STEP_ORDER["$id"]="$order"
    STEP_PREV["$id"]="$prev"
    STEP_NEXT["$id"]="$next"
    STEP_DEPS["$id"]="$deps"
    STEP_MODULE["$id"]="$module"
    STEP_HANDLER["$id"]="$handler"
    STEP_IDS+=("$id")
}

step_exists() {
    local id; id="$(sanitize_id "${1-}")"
    [[ -n "$id" && -n "${STEP_TITLE[$id]-}" ]]
}

step_module_path() {
    local id; id="$(sanitize_id "${1-}")"
    local module; module="$(sanitize_ws "${STEP_MODULE[$id]-}")"
    if [[ -z "$module" ]]; then
        printf '%s' ""
        return
    fi
    if [[ "$module" == /* ]]; then
        printf '%s' "$module"
        return
    fi
    printf '%s' "$STEPS_DIR/$module"
}

lazy_source_step() {
    local id; id="$(sanitize_id "${1-}")"
    local path
    path="$(sanitize_ws "$(step_module_path "$id")")"

    if [[ -z "$path" ]]; then
        return 0
    fi
    if [[ ! -f "$path" ]]; then
        log_line "WARN" "Módulo ausente para step '$id': $path (usando handler interno)"
        return 0
    fi

    # shellcheck disable=SC1090
    source "$path"
}

lazy_source_deps() {
    local deps; deps="$(sanitize_ws "${1-}")"
    local dep
    if [[ -z "$deps" ]]; then
        return 0
    fi
    while IFS=',' read -r dep; do
        dep="$(sanitize_ws "$dep")"
        if [[ -z "$dep" ]]; then
            continue
        fi
        if [[ "$dep" != /* ]]; then
            dep="$LIBS_DIR/$dep"
        fi
        if [[ -f "$dep" ]]; then
            # shellcheck disable=SC1090
            source "$dep"
        else
            log_line "WARN" "Dependência não encontrada: $dep"
        fi
    done <<<"$deps"
}

# ──────────────────────────────────────────────────────────────────────────────
# Step Map (Stable IDs) — Router-friendly
# ──────────────────────────────────────────────────────────────────────────────

register_all_steps() {
    # ID, ORDER, TITLE, DESC, PREV, NEXT, DEPS, MODULE, HANDLER
    register_step "welcome"                "00" "Boas-vindas"                 "Contexto, requisitos e início"                      ""                      "installer_prefs_locale"    ""                           "welcome.sh"                "step_welcome"
    register_step "installer_prefs_locale"  "01" "Idioma e Localidade"        "Idioma, região e codificação"                        "welcome"               "installer_prefs_keyboard"  ""                           "prefs_locale.sh"           "step_installer_prefs_locale"
    register_step "installer_prefs_keyboard" "02" "Teclado"                    "Layout, variante e teste"                            "installer_prefs_locale" "identity"                  ""                           "prefs_keyboard.sh"         "step_installer_prefs_keyboard"
    register_step "identity"               "03" "Identidade do Sistema"       "Hostname e domínio opcional"                         "installer_prefs_keyboard" "network"                   ""                           "identity.sh"               "step_identity"

    register_step "network"                "04" "Rede"                        "Interface, DHCP/Manual, DNS e proxy"                 "identity"              "time"                      "net-utils.sh"               "network.sh"                "step_network"
    register_step "time"                   "05" "Data e Hora"                 "Fuso horário e NTP"                                   "network"               "user_account"              "time-utils.sh"              "time.sh"                   "step_time"

    register_step "user_account"           "06" "Conta do Usuário"            "Nome, usuário e senha"                                "time"                  "admin_policy"              "auth-utils.sh"              "user_account.sh"           "step_user_account"
    register_step "admin_policy"           "07" "Administração (Root/Sudo)"   "Política de root e senha root opcional"               "user_account"          "disk_select"               "auth-utils.sh"              "admin_policy.sh"           "step_admin_policy"

    register_step "disk_select"            "08" "Disco de Destino"            "Detectar e selecionar o disco alvo"                  "admin_policy"          "disk_wipe_confirm"         "disk-utils.sh"              "disk_select.sh"            "step_disk_select"
    register_step "disk_wipe_confirm"      "09" "Confirmação de Wipe"         "Confirmação forte para apagar dados"                 "disk_select"           "zfs_strategy"              "disk-utils.sh"              "disk_wipe_confirm.sh"      "step_disk_wipe_confirm"

    register_step "zfs_strategy"           "10" "Estratégia ZFS"              "Automático (recomendado) ou Avançado"                "disk_wipe_confirm"     "zfs_auto_topology"         "zfs-utils.sh"               "zfs_strategy.sh"           "step_zfs_strategy"
    register_step "zfs_auto_topology"      "11" "ZFS: Topologia do Pool"      "Stripe/Mirror/RAIDZ conforme discos"                 "zfs_strategy"          "zfs_auto_properties"       "zfs-utils.sh,disks-identify-suporte-types.sh" "zfs_auto_topology.sh" "step_zfs_auto_topology"
    register_step "zfs_auto_properties"    "12" "ZFS: Propriedades"           "Compressão, dedup, ARC e avançado"                   "zfs_auto_topology"     "zfs_auto_datasets"         "zfs-utils.sh"               "zfs_auto_properties.sh"    "step_zfs_auto_properties"
    register_step "zfs_auto_datasets"      "13" "ZFS: Datasets"               "Preset padrão/servidor/custom"                       "zfs_auto_properties"   "boot"                      "zfs-utils.sh"               "zfs_auto_datasets.sh"      "step_zfs_auto_datasets"

    register_step "zfs_manual"             "14" "ZFS: Manual (Avançado)"      "VDEVs, pools, datasets e propriedades"               "zfs_strategy"          "boot"                      "zfs-utils.sh"               "zfs_manual.sh"             "step_zfs_manual"

    register_step "boot"                   "15" "Boot"                        "UEFI/BIOS, bootloader e parâmetros"                   "zfs_auto_datasets"      "review"                   "boot-utils.sh"              "boot.sh"                   "step_boot"
    register_step "review"                 "16" "Revisão"                     "Resumo, validações e checkpoint"                      "boot"                  "install"                   "validate-utils.sh"          "review.sh"                 "step_review"
    register_step "install"                "17" "Instalação"                  "Execução e progresso"                                 "review"                "post_install"              "install-utils.sh"           "install.sh"                "step_install"
    register_step "post_install"           "18" "Pós-instalação"              "Ajustes finais: apt, serviços, pacotes"               "install"               "finish"                    "post-utils.sh,finalize-chroot.sh,setup-zbm-config.sh" "post_install.sh" "step_post_install"
    register_step "finish"                 "19" "Concluído"                   "Resumo final e reboot"                                "post_install"          ""                          ""                           "finish.sh"                 "step_finish"
}

# ──────────────────────────────────────────────────────────────────────────────
# Router Logic
# ──────────────────────────────────────────────────────────────────────────────

compute_next_step() {
    local id; id="$(sanitize_id "${1-}")"
    local next; next="$(sanitize_id "${STEP_NEXT[$id]-}")"
    local strategy; strategy="$(sanitize_ws "${install_zfs_strategy-}")"

    # Router rule: if strategy == manual, jump to zfs_manual
    if [[ "$id" == "zfs_strategy" ]]; then
        if [[ "$(sanitize_id "$strategy")" == "manual" ]]; then
            printf '%s' "zfs_manual"
            return
        fi
        printf '%s' "zfs_auto_topology"
        return
    fi

    # Router rule: boot prev depends on which ZFS flow was used
    if [[ "$id" == "boot" ]]; then
        printf '%s' "$next"
        return
    fi

    printf '%s' "$next"
}

compute_prev_step() {
    local id; id="$(sanitize_id "${1-}")"
    local prev; prev="$(sanitize_id "${STEP_PREV[$id]-}")"
    local strategy; strategy="$(sanitize_ws "${install_zfs_strategy-}")"

    if [[ "$id" == "boot" ]]; then
        if [[ "$(sanitize_id "$strategy")" == "manual" ]]; then
            printf '%s' "zfs_manual"
            return
        fi
        printf '%s' "zfs_auto_datasets"
        return
    fi

    if [[ "$id" == "zfs_auto_topology" || "$id" == "zfs_manual" ]]; then
        printf '%s' "zfs_strategy"
        return
    fi

    printf '%s' "$prev"
}

step_invoke() {
    local id; id="$(sanitize_id "${1-}")"
    local handler; handler="$(sanitize_ws "${STEP_HANDLER[$id]-}")"
    local deps; deps="$(sanitize_ws "${STEP_DEPS[$id]-}")"

    if [[ -z "$id" || -z "$handler" ]]; then
        stderr "Erro: step_invoke id/handler inválidos."
        return 1
    fi

    lazy_source_deps "$deps" || return 1
    lazy_source_step "$id" || return 1

    if ! declare -F "$handler" >/dev/null 2>&1; then
        stderr "Erro: handler não encontrado: $handler (step: $id)"
        return 1
    fi

    "$handler"
}

goto_step() {
    local id; id="$(sanitize_id "${1-}")"
    if [[ -z "$id" ]]; then
        stderr "Erro: goto_step recebeu id vazio."
        return 1
    fi
    if ! step_exists "$id"; then
        stderr "Erro: step inexistente: $id"
        return 1
    fi
    CURRENT_STEP="$id"
    state_kv_set "current_step" "$CURRENT_STEP" || return 1
}

goto_next() {
    local next
    next="$(sanitize_id "$(compute_next_step "$CURRENT_STEP")")"
    if [[ -z "$next" ]]; then
        return 0
    fi
    goto_step "$next"
}

goto_prev() {
    local prev
    prev="$(sanitize_id "$(compute_prev_step "$CURRENT_STEP")")"
    if [[ -z "$prev" ]]; then
        return 0
    fi
    goto_step "$prev"
}

# ──────────────────────────────────────────────────────────────────────────────
# Map/Export Utilities (Router-friendly outputs)
# ──────────────────────────────────────────────────────────────────────────────

print_steps_table() {
    local id
    printf '%-22s %-6s %-22s %-16s %-16s\n' "STEP_ID" "ORDER" "TITLE" "PREV" "NEXT"
    printf '%s\n' "$(printf '=%.0s' {1..86})"
    for id in "${STEP_IDS[@]}"; do
        printf '%-22s %-6s %-22s %-16s %-16s\n' \
            "$id" \
            "${STEP_ORDER[$id]}" \
            "$(printf '%.22s' "${STEP_TITLE[$id]}")" \
            "${STEP_PREV[$id]}" \
            "${STEP_NEXT[$id]}"
    done
}

print_steps_json() {
    local id
    printf '{\n  "name": "%s",\n  "version": "%s",\n  "default_step": "%s",\n  "steps": [\n' \
        "$SCRIPT_NAME" "$SCRIPT_VERSION" "$DEFAULT_STEP"
    local first="1"
    for id in "${STEP_IDS[@]}"; do
        if [[ "$first" == "1" ]]; then
            first="0"
        else
            printf ',\n'
        fi
        printf '    {\n'
        printf '      "id": "%s",\n' "$id"
        printf '      "order": "%s",\n' "${STEP_ORDER[$id]}"
        printf '      "title": "%s",\n' "$(printf '%s' "${STEP_TITLE[$id]}" | sed -E 's/"/\\"/g')"
        printf '      "description": "%s",\n' "$(printf '%s' "${STEP_DESC[$id]}" | sed -E 's/"/\\"/g')"
        printf '      "prev": "%s",\n' "${STEP_PREV[$id]}"
        printf '      "next": "%s",\n' "${STEP_NEXT[$id]}"
        printf '      "deps": "%s",\n' "$(printf '%s' "${STEP_DEPS[$id]}" | sed -E 's/"/\\"/g')"
        printf '      "module": "%s",\n' "$(printf '%s' "${STEP_MODULE[$id]}" | sed -E 's/"/\\"/g')"
        printf '      "handler": "%s"\n' "$(printf '%s' "${STEP_HANDLER[$id]}" | sed -E 's/"/\\"/g')"
        printf '    }'
    done
    printf '\n  ]\n}\n'
}

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────
# Internal Handlers
# ──────────────────────────────────────────────────────────────────────────────
#
# REFATORAÇÃO (2026-02-06): Handlers internos removidos.
# A implementação de cada step reside agora exclusivamente em $STEPS_DIR/*.sh.
# O router utiliza lazy_source_step() para carregar o código sob demanda.
#


# ──────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ──────────────────────────────────────────────────────────────────────────────

parse_args() {
    local arg
    while [[ $# -gt 0 ]]; do
        arg="$(sanitize_ws "${1-}")"
        shift || true
        case "$arg" in
            --state-dir)
                STATE_DIR="$(sanitize_ws "${1-}")"; shift || true
                if [[ -z "$STATE_DIR" ]]; then
                    STATE_DIR="$STATE_DIR_DEFAULT"
                fi
                STATE_FILE="$STATE_DIR/state.env"
                ;;
            --steps-dir)
                STEPS_DIR="$(sanitize_ws "${1-}")"; shift || true
                if [[ -z "$STEPS_DIR" ]]; then
                    STEPS_DIR="$STEPS_DIR_DEFAULT"
                fi
                ;;
            --libs-dir)
                LIBS_DIR="$(sanitize_ws "${1-}")"; shift || true
                if [[ -z "$LIBS_DIR" ]]; then
                    LIBS_DIR="$LIBS_DIR_DEFAULT"
                fi
                ;;
            --start)
                CURRENT_STEP="$(sanitize_id "${1-}")"; shift || true
                if [[ -z "$CURRENT_STEP" ]]; then
                    CURRENT_STEP="$DEFAULT_STEP"
                fi
                ;;
            --print-map)
                state_prepare || return 1
                register_all_steps || return 1
                print_steps_table
                return 2
                ;;
            --print-json)
                state_prepare || return 1
                register_all_steps || return 1
                print_steps_json
                return 2
                ;;
            --version)
                printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"
                return 2
                ;;
            *)
                stderr "Argumento inválido: $arg"
                return 1
                ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Main Flow
# ──────────────────────────────────────────────────────────────────────────────

main_loop() {
    local safe_guard
    safe_guard=0

    while true; do
        safe_guard=$((safe_guard + 1))
        if (( safe_guard > 200 )); then
            die "Loop de navegação excedeu limite de segurança."
            return 1
        fi

        if ! step_exists "$CURRENT_STEP"; then
            die "Step inválido no estado atual: $CURRENT_STEP"
            return 1
        fi

        log_line "INFO" "Entrando step=$CURRENT_STEP"
        if step_invoke "$CURRENT_STEP"; then
            NEXT_STEP="$(sanitize_id "$(compute_next_step "$CURRENT_STEP")")"
            if [[ -z "$NEXT_STEP" ]]; then
                break
            fi
            goto_next || return 1
            state_load || true
            continue
        fi

        # Falha/voltar: tenta ir para prev; se não houver, encerra com erro.
        PREV_STEP="$(sanitize_id "$(compute_prev_step "$CURRENT_STEP")")"
        if [[ -n "$PREV_STEP" ]]; then
            goto_prev || return 1
            state_load || true
            continue
        fi

        die "Operação cancelada."
        return 1
    done
}

main() {
    setup_traps
    log_init
    ui_require || return 1
    state_prepare || return 1

    local parse_rc
    if ! parse_args "$@"; then
        return 1
    fi
    parse_rc=$?
    if [[ "$parse_rc" == "2" ]]; then
        return 0
    fi

    register_all_steps || return 1
    state_load || true

    local cs
    cs="$(sanitize_id "${current_step-}")"
    if [[ -n "$cs" ]]; then
        CURRENT_STEP="$cs"
    fi
    if [[ -z "$CURRENT_STEP" ]]; then
        CURRENT_STEP="$DEFAULT_STEP"
    fi
    if ! step_exists "$CURRENT_STEP"; then
        CURRENT_STEP="$DEFAULT_STEP"
    fi

    # Demonstration (example arguments usage):
    #   ./installer-router.sh --print-map
    #   ./installer-router.sh --print-json
    #   ./installer-router.sh --start network

    main_loop
}

main "$@"

