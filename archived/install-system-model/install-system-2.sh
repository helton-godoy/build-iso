#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_NAME="fileserver-installer-scaffold"
SCRIPT_VERSION="1.0.0"

ROUTER_SCRIPT_DEFAULT="./installer-router.sh"
STEPS_DIR_DEFAULT="./steps"
LIBS_DIR_DEFAULT="./libs"

MODE="create"
ROUTER_SCRIPT="$ROUTER_SCRIPT_DEFAULT"
STEPS_DIR="$STEPS_DIR_DEFAULT"
LIBS_DIR="$LIBS_DIR_DEFAULT"
FORCE_OVERWRITE="0"

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

file_readable() {
    local path; path="$(sanitize_path "${1-}")"
    [[ -n "$path" && -f "$path" && -r "$path" ]]
}

file_exists() {
    local path; path="$(sanitize_path "${1-}")"
    [[ -n "$path" && -f "$path" ]]
}

write_file_atomic() {
    local dest; dest="$(sanitize_path "${1-}")"
    local content; content="${2-}"
    if [[ -z "$dest" ]]; then
        stderr "Erro: write_file_atomic destino vazio."
        return 1
    fi

    local tmpdir tmpfile
    tmpdir="$(dirname -- "$dest")"
    mkdir -p "$tmpdir"

    tmpfile="$tmpdir/.tmp.$(basename -- "$dest").$$"
    umask 077
    printf '%s' "$content" >"$tmpfile"
    chmod 0644 "$tmpfile" || true
    mv -f "$tmpfile" "$dest"
}

append_if_missing() {
    local dest; dest="$(sanitize_path "${1-}")"
    local marker; marker="$(sanitize_ws "${2-}")"
    local content; content="${3-}"

    if [[ -z "$dest" || -z "$marker" ]]; then
        stderr "Erro: append_if_missing parâmetros inválidos."
        return 1
    fi

    if file_exists "$dest"; then
        if grep -Fq "$marker" "$dest" 2>/dev/null; then
            return 0
        fi
        printf '\n%s\n' "$content" >>"$dest"
        return 0
    fi

    write_file_atomic "$dest" "$content"
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
            --mode)
                MODE="$(sanitize_id "${1-}")"; shift || true
                ;;
            --force)
                FORCE_OVERWRITE="1"
                ;;
            --version)
                stdout "$SCRIPT_NAME $SCRIPT_VERSION"
                return 2
                ;;
            --help|-h)
                stdout "Uso: $0 [--router FILE] [--steps-dir DIR] [--libs-dir DIR] [--mode create|verify] [--force]"
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

    # Output TSV per row:
    # step_id \t module \t handler \t deps
    # register_step "id" "order" "title" "desc" "prev" "next" "deps" "module" "handler"
    sed -n -E 's/^[[:space:]]*register_step[[:space:]]+"([^"]+)"[[:space:]]+"[^"]+"[[:space:]]+"[^"]+"[[:space:]]+"[^"]+"[[:space:]]+"[^"]*"[[:space:]]+"[^"]*"[[:space:]]+"([^"]*)"[[:space:]]+"([^"]*)"[[:space:]]+"([^"]*)".*$/\1\t\3\t\4\t\2/p' "$router"
}

split_csv_lines() {
    local csv; csv="$(sanitize_ws "${1-}")"
    if [[ -z "$csv" ]]; then
        return 0
    fi
    printf '%s' "$csv" | awk -v RS=',' '{ gsub(/^[ \t]+|[ \t]+$/, "", $0); if (length($0)>0) print $0 }'
}

render_step_module() {
    local step_id; step_id="$(sanitize_id "${1-}")"
    local handler; handler="$(sanitize_ws "${2-}")"
    local title; title="$(sanitize_ws "${3-}")"

    if [[ -z "$step_id" || -z "$handler" ]]; then
        stderr "Erro: render_step_module step_id/handler inválidos."
        return 1
    fi

    cat <<EOF
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Module: step/${step_id}
# Handler: ${handler}
# Title: ${title}

# This module is lazy-loaded by installer-router.sh when the step is invoked.
# Keep each function single-responsibility.

${handler}() {
    # NOTE: UI helpers are expected to be provided by router (gum wrappers).
    # State persistence is expected via state_kv_set.

    ui_hero "\${PROJECT_NAME:-FILESERVER INSTALLER}" "\${PROJECT_TAGLINE:-Debian 13 + ZFS on Root}"
    ui_section "${title:-${step_id}}"

    ui_card "Pendente" \\
        "  ${UI_BULLET:-●} Implementar tela e validações deste step." \\
        "  ${UI_BULLET:-●} Persistir chaves no state.env via state_kv_set." \\
        "" \\
        "  Arquivo: \${BASH_SOURCE[0]}"

    if ui_confirm "Marcar este step como concluído?" "Concluir" "Voltar"; then
        state_kv_set "step_${step_id}_done" "1"
        return 0
    fi
    return 1
}
EOF
}

render_lib_module() {
    local lib; lib="$(sanitize_ws "${1-}")"
    local lib_id; lib_id="$(sanitize_id "${lib}")"
    if [[ -z "$lib" ]]; then
        stderr "Erro: render_lib_module lib vazio."
        return 1
    fi

    cat <<EOF
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: ${lib}
# Purpose: utilities for installer modules (lazy-loaded).

lib_${lib_id}_loaded() { :; }

# Single-responsibility example function:
lib_${lib_id}_noop() {
    local msg; msg="$(sanitize_ws "\${1-}")"
    if [[ -z "\$msg" ]]; then
        msg="${lib}: noop"
    fi
    printf '%s\n' "\$msg"
}
EOF
}

infer_step_title_from_router() {
    local router; router="$(sanitize_path "${1-}")"
    local step; step="$(sanitize_ws "${2-}")"
    if [[ -z "$router" || -z "$step" ]]; then
        printf '%s' ""
        return
    fi

    local title
    title="$(sed -n -E "s/^[[:space:]]*register_step[[:space:]]+\"${step}\"[[:space:]]+\"[^\"]+\"[[:space:]]+\"([^\"]+)\".*/\\1/p" "$router" | head -n1 || true)"
    title="$(sanitize_ws "$title")"
    if [[ -z "$title" ]]; then
        title="$step"
    fi
    printf '%s' "$title"
}

create_step_module_file() {
    local router; router="$(sanitize_path "${1-}")"
    local steps_dir; steps_dir="$(sanitize_path "${2-}")"
    local step_id; step_id="$(sanitize_ws "${3-}")"
    local module; module="$(sanitize_ws "${4-}")"
    local handler; handler="$(sanitize_ws "${5-}")"

    local path title content
    step_id="$(sanitize_id "$step_id")"
    if [[ -z "$step_id" || -z "$module" || -z "$handler" ]]; then
        stderr "Erro: create_step_module_file parâmetros inválidos."
        return 1
    fi

    if [[ "$module" == /* ]]; then
        path="$module"
    else
        path="$steps_dir/$module"
    fi
    path="$(sanitize_path "$path")"

    title="$(infer_step_title_from_router "$router" "$step_id")"
    content="$(render_step_module "$step_id" "$handler" "$title")"

    if file_exists "$path" && [[ "$FORCE_OVERWRITE" != "1" ]]; then
        stdout "SKIP step module exists: $path"
        return 0
    fi

    write_file_atomic "$path" "$content"
    chmod 0755 "$path" || true
    stdout "OK   step module created: $path"
}

create_lib_dep_file() {
    local libs_dir; libs_dir="$(sanitize_path "${1-}")"
    local dep; dep="$(sanitize_ws "${2-}")"

    local path content
    if [[ -z "$dep" ]]; then
        return 0
    fi

    if [[ "$dep" == /* ]]; then
        path="$dep"
    else
        path="$libs_dir/$dep"
    fi
    path="$(sanitize_path "$path")"

    content="$(render_lib_module "$dep")"

    if file_exists "$path" && [[ "$FORCE_OVERWRITE" != "1" ]]; then
        stdout "SKIP dep exists: $path"
        return 0
    fi

    write_file_atomic "$path" "$content"
    chmod 0755 "$path" || true
    stdout "OK   dep created: $path"
}

create_project_structure() {
    local router; router="$(sanitize_path "${1-}")"
    local steps_dir; steps_dir="$(sanitize_path "${2-}")"
    local libs_dir; libs_dir="$(sanitize_path "${3-}")"

    mkdirs "$steps_dir"
    mkdirs "$libs_dir"

    local rows
    rows="$(extract_register_step_rows "$router")"
    if [[ -z "$(sanitize_ws "$rows")" ]]; then
        stderr "Erro: nenhum register_step encontrado."
        return 1
    fi

    local step_id module handler deps dep
    while IFS=$'\t' read -r step_id module handler deps; do
        step_id="$(sanitize_ws "$step_id")"
        module="$(sanitize_ws "$module")"
        handler="$(sanitize_ws "$handler")"
        deps="$(sanitize_ws "$deps")"

        if [[ -n "$module" ]]; then
            create_step_module_file "$router" "$steps_dir" "$step_id" "$module" "$handler" || return 1
        fi

        if [[ -n "$deps" ]]; then
            while IFS= read -r dep; do
                dep="$(sanitize_ws "$dep")"
                if [[ -z "$dep" ]]; then
                    continue
                fi
                create_lib_dep_file "$libs_dir" "$dep" || return 1
            done < <(split_csv_lines "$deps")
        fi
    done <<<"$rows"

    create_manifest_file "$router" "$steps_dir" "$libs_dir" || return 1
}

create_manifest_file() {
    local router; router="$(sanitize_path "${1-}")"
    local steps_dir; steps_dir="$(sanitize_path "${2-}")"
    local libs_dir; libs_dir="$(sanitize_path "${3-}")"

    local dest; dest="$(sanitize_path "./MANIFEST.lazy-load.txt")"
    local rows line step_id module handler deps dep

    rows="$(extract_register_step_rows "$router")"
    if [[ -z "$(sanitize_ws "$rows")" ]]; then
        stderr "Erro: falha ao construir manifest."
        return 1
    fi

    local out
    out=""
    out+=$(printf 'MANIFEST (Lazy Loading)\n')
    out+=$(printf 'Generated by: %s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION")
    out+=$(printf 'Router: %s\n' "$router")
    out+=$(printf 'Steps:  %s\n' "$steps_dir")
    out+=$(printf 'Libs:   %s\n' "$libs_dir")
    out+=$(printf '────────────────────────────────────────────────────────────\n\n')
    out+=$(printf '%-22s %-26s %-24s %s\n' "STEP_ID" "MODULE" "HANDLER" "DEPS")
    out+=$(printf '%s\n' "$(printf '=%.0s' {1..92})")

    while IFS=$'\t' read -r step_id module handler deps; do
        step_id="$(sanitize_ws "$step_id")"
        module="$(sanitize_ws "$module")"
        handler="$(sanitize_ws "$handler")"
        deps="$(sanitize_ws "$deps")"
        out+=$(printf '%-22s %-26s %-24s %s\n' "$step_id" "$module" "$handler" "$deps")
    done <<<"$rows"

    write_file_atomic "$dest" "$out"
    stdout "OK   manifest created: $dest"
}

verify_structure() {
    local router; router="$(sanitize_path "${1-}")"
    local steps_dir; steps_dir="$(sanitize_path "${2-}")"
    local libs_dir; libs_dir="$(sanitize_path "${3-}")"

    local rows
    rows="$(extract_register_step_rows "$router")"
    if [[ -z "$(sanitize_ws "$rows")" ]]; then
        stderr "Erro: nenhum register_step encontrado."
        return 1
    fi

    local missing_steps missing_deps ok_steps ok_deps
    missing_steps=0
    missing_deps=0
    ok_steps=0
    ok_deps=0

    local step_id module handler deps dep path
    while IFS=$'\t' read -r step_id module handler deps; do
        step_id="$(sanitize_id "$step_id")"
        module="$(sanitize_ws "$module")"
        deps="$(sanitize_ws "$deps")"

        if [[ -n "$module" ]]; then
            if [[ "$module" == /* ]]; then
                path="$module"
            else
                path="$steps_dir/$module"
            fi
            if file_readable "$path"; then
                ok_steps=$((ok_steps + 1))
            else
                missing_steps=$((missing_steps + 1))
                stderr "MÓDULO AUSENTE: $path (step=$step_id)"
            fi
        fi

        if [[ -n "$deps" ]]; then
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
                if file_readable "$path"; then
                    ok_deps=$((ok_deps + 1))
                else
                    missing_deps=$((missing_deps + 1))
                    stderr "DEP AUSENTE: $path"
                fi
            done < <(split_csv_lines "$deps")
        fi
    done <<<"$rows"

    stdout "OK steps: $ok_steps | Missing steps: $missing_steps"
    stdout "OK deps:  $ok_deps  | Missing deps:  $missing_deps"

    if (( missing_steps > 0 || missing_deps > 0 )); then
        return 1
    fi
}

main() {
    require_cmd sed
    require_cmd awk
    require_cmd grep
    require_cmd head
    require_cmd chmod
    require_cmd mkdir
    require_cmd mv
    require_cmd printf

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
    MODE="$(sanitize_id "$MODE")"

    if [[ -z "$ROUTER_SCRIPT" ]]; then
        ROUTER_SCRIPT="$ROUTER_SCRIPT_DEFAULT"
    fi
    if [[ -z "$STEPS_DIR" ]]; then
        STEPS_DIR="$STEPS_DIR_DEFAULT"
    fi
    if [[ -z "$LIBS_DIR" ]]; then
        LIBS_DIR="$LIBS_DIR_DEFAULT"
    fi
    if [[ -z "$MODE" ]]; then
        MODE="create"
    fi

    if ! file_readable "$ROUTER_SCRIPT"; then
        stderr "Erro: router não encontrado/sem permissão: $ROUTER_SCRIPT"
        return 1
    fi

    case "$MODE" in
        create)
            create_project_structure "$ROUTER_SCRIPT" "$STEPS_DIR" "$LIBS_DIR"
            ;;
        verify)
            verify_structure "$ROUTER_SCRIPT" "$STEPS_DIR" "$LIBS_DIR"
            ;;
        *)
            stderr "Erro: mode inválido: $MODE (use create|verify)"
            return 1
            ;;
    esac
}

main "$@"
