#!/usr/bin/env bash
# =============================================================================
# Verificacao de Anti-Padroes
# =============================================================================
# Detecta anti-padroes Shell:
#   - echo para erros fatais (deve usar ui_panic)
#   - chroot /target direto (deve usar execute_in_chroot)
#   - Variaveis nao entre aspas em expressoes
#   - Uso de [ ] ao inves de [[ ]]
# =============================================================================

set -euo pipefail

# Configuracao
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALLER_DIR="$PROJECT_ROOT/config-overrides/config/includes.chroot/usr/local/lib/installer"

# Contadores
total_files=0
files_with_issues=0
issues_found=0

# Issues encontradas
declare -a ECHO_ERROR_ISSUES=()
declare -a CHROOT_DIRECT_ISSUES=()
declare -a UNQUOTED_VAR_ISSUES=()
declare -a BRACKET_ISSUES=()

# =============================================================================
# Funcoes
# =============================================================================

usage() {
  cat <<EOF
Uso: $(basename "$0") [OPCOES]

Detecta anti-padroes Shell nos scripts do instalador.

OPCOES:
  -h, --help          Mostra esta ajuda
  -v, --verbose       Modo verboso
  -o, --output FILE   Salva relatorio em arquivo

ANTI-PADROES DETECTADOS:
  1. echo para erros fatais (use ui_panic)
  2. chroot /target direto (use execute_in_chroot)
  3. Variaveis sem aspas em expressoes
  4. Uso de [ ] ao inves de [[ ]]
EOF
}

log() {
  local level="$1"
  shift
  case "$level" in
    INFO)  echo "[INFO] $*" ;;
    WARN)  echo "[WARN] $*" >&2 ;;
    ERROR) echo "[ERROR] $*" >&2 ;;
    DEBUG) [[ "${VERBOSE:-false}" == "true" ]] && echo "[DEBUG] $*" ;;
  esac
}

# Verifica echo para erros fatais
check_echo_error() {
  local file="$1"
  local line_num=0

  while IFS= read -r line; do
    ((line_num++))

    # Ignora comentarios
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Detecta echo ... >&2 para erros (mas nao se ja tem ui_panic)
    if [[ "$line" =~ echo.*\>&\ 2 ]] && [[ ! "$line" =~ ui_panic ]]; then
      # Verifica se e mensagem de erro (contem error, fatal, fail, etc)
      if [[ "$line" =~ (error|fatal|fail|erro|critico) ]]; then
        ECHO_ERROR_ISSUES+=("$(printf '%s:%d: echo para erro fatal (use ui_panic)' "$file" "$line_num")")
      fi
    fi
  done < "$file"
}

# Verifica chroot direto
check_chroot_direct() {
  local file="$1"
  local line_num=0

  while IFS= read -r line; do
    ((line_num++))

    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Detecta chroot sem funcao wrapper
    if [[ "$line" =~ ^[[:space:]]*chroot[[:space:]] ]]; then
      # Se nao usa execute_in_chroot ou similar
      if [[ ! "$line" =~ (execute_in_chroot|chroot_execute|run_in_chroot) ]]; then
        CHROOT_DIRECT_ISSUES+=("$(printf '%s:%d: chroot direto (use funcao wrapper)' "$file" "$line_num")")
      fi
    fi
  done < "$file"
}

# Verifica variaveis sem aspas
check_unquoted_vars() {
  local file="$1"
  local line_num=0
  local in_function=false

  while IFS= read -r line; do
    ((line_num++))

    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Detecta funcao
    if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?[a-z_][a-z0-9_]*[[:space:]]*\(\) ]]; then
      in_function=true
      continue
    fi

    # Fim de funcao
    if [[ "$in_function" == true ]] && [[ "$line" =~ ^[[:space:]]*\} ]]; then
      in_function=false
      continue
    fi

    # So verifica dentro de funcoes
    if [[ "$in_function" == true ]]; then
      # Padrao: $VAR em contextos perigosos (if, while, arithmetic)
      # Exclui: ${var}, "$var", ${var:-default}

      # Detecta $VAR (sem aspas) em condicoes
      if [[ "$line" =~ (if|while|\[\[).*\$\ [a-zA-Z_] ]]; then
        # Filtra falsos positivos (ja quoted)
        if [[ ! "$line" =~ \"\$\{ ]]; then
          UNQUOTED_VAR_ISSUES+=("$(printf '%s:%d: variavel sem aspas em condicao' "$file" "$line_num")")
        fi
      fi
    fi
  done < "$file"
}

# Verifica uso de [ ] ao inves de [[ ]]
check_bracket_usage() {
  local file="$1"
  local line_num=0

  while IFS= read -r line; do
    ((line_num++))

    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*#! ]] && continue

    # Detecta [ ] simples (nao [[ ]])
    if [[ "$line" =~ ^[[:space:]]*\[ ]]; then
      # Exclui [[ e ja verificado
      if [[ ! "$line" =~ ^[[:space:]]*\[\[ ]]; then
        # Detecta operadores que exigem [[ (regex, ==, etc)
        if [[ "$line" =~ (==|=~\|\|&&|\+\+|--) ]]; then
          BRACKET_ISSUES+=("$(printf '%s:%d: [ ] com operador avancado (use [[ ]])' "$file" "$line_num")")
        fi
      fi
    fi
  done < "$file"
}

# Valida arquivo
validate_file() {
  local file="$1"

  ((total_files++))

  log DEBUG "Verificando: $file"

  check_echo_error "$file"
  check_chroot_direct "$file"
  check_unquoted_vars "$file"
  check_bracket_usage "$file"

  # Verifica se encontrou issues
  local file_issues=0

  for issue in "${ECHO_ERROR_ISSUES[@]}"; do
    [[ "$issue" =~ ^$file: ]] && ((file_issues++))
  done

  for issue in "${CHROOT_DIRECT_ISSUES[@]}"; do
    [[ "$issue" =~ ^$file: ]] && ((file_issues++))
  done

  for issue in "${UNQUOTED_VAR_ISSUES[@]}"; do
    [[ "$issue" =~ ^$file: ]] && ((file_issues++))
  done

  for issue in "${BRACKET_ISSUES[@]}"; do
    [[ "$issue" =~ ^$file: ]] && ((file_issues++))
  done

  if [[ $file_issues -gt 0 ]]; then
    ((files_with_issues++))
  fi
}

# Valida todos os arquivos
validate_all() {
  local -a shell_files=()

  log INFO "Iniciando verificacao de anti-padroes..."

  # Procura por arquivos shell
  while IFS= read -r -d '' file; do
    shell_files+=("$file")
  done < <(find "$INSTALLER_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null || true)

  if [[ -f "$PROJECT_ROOT/config-overrides/config/includes.chroot/usr/local/bin/installer" ]]; then
    shell_files+=("$PROJECT_ROOT/config-overrides/config/includes.chroot/usr/local/bin/installer")
  fi

  if [[ ${#shell_files[@]} -eq 0 ]]; then
    log WARN "Nenhum arquivo shell encontrado"
    return 1
  fi

  log INFO "Encontrados ${#shell_files[@]} arquivos"

  for file in "${shell_files[@]}"; do
    validate_file "$file"
  done
}

# Gera relatorio
generate_report() {
  echo "=============================================="
  echo "  RELATORIO DE ANTI-PADROES"
  echo "=============================================="
  echo
  echo "Arquivos analisados:  $total_files"
  echo "Arquivos com issues:  $files_with_issues"
  echo

  if [[ ${#ECHO_ERROR_ISSUES[@]} -gt 0 ]]; then
    echo "--- Echo para Erros Fatais (${#ECHO_ERROR_ISSUES[@]}) ---"
    printf '%s\n' "${ECHO_ERROR_ISSUES[@]}"
    echo
  fi

  if [[ ${#CHROOT_DIRECT_ISSUES[@]} -gt 0 ]]; then
    echo "--- Chroot Direto (${#CHROOT_DIRECT_ISSUES[@]}) ---"
    printf '%s\n' "${CHROOT_DIRECT_ISSUES[@]}"
    echo
  fi

  if [[ ${#UNQUOTED_VAR_ISSUES[@]} -gt 0 ]]; then
    echo "--- Variaveis sem Aspas (${#UNQUOTED_VAR_ISSUES[@]}) ---"
    printf '%s\n' "${UNQUOTED_VAR_ISSUES[@]}"
    echo
  fi

  if [[ ${#BRACKET_ISSUES[@]} -gt 0 ]]; then
    echo "--- Uso Inadequado de [ ] (${#BRACKET_ISSUES[@]}) ---"
    printf '%s\n' "${BRACKET_ISSUES[@]}"
    echo
  fi

  ((issues_found=${#ECHO_ERROR_ISSUES[@]}+${#CHROOT_DIRECT_ISSUES[@]}+${#UNQUOTED_VAR_ISSUES[@]}+${#BRACKET_ISSUES[@]}))

  if [[ $issues_found -gt 0 ]]; then
    echo "Total de issues encontradas: $issues_found"
    echo "Status: FALHA"
    echo "Acao: Corrigir anti-padroes conforme listados acima"
    return 1
  else
    echo "Status: SUCESSO"
    echo "Nenhum anti-padrao encontrado!"
    return 0
  fi
}

# =============================================================================
# Main
# =============================================================================

VERBOSE=false
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -o|--output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      echo "Opcao invalida: $1"
      usage
      exit 1
      ;;
  esac
done

validate_all
generate_report

exit $?
