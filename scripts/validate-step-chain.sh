#!/usr/bin/env bash
# =============================================================================
# Validacao de Cadeia de Steps
# =============================================================================
# Verifica cadeia de steps do instalador
# Confirma que cada step tem @INST_STEP_ID unico
# Valida que @INST_NEXT pointing para proximo step existe
# Detecta cadeias quebradas
# =============================================================================

set -euo pipefail

# Configuracao
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STEPS_DIR="$PROJECT_ROOT/config-overrides/config/includes.chroot/usr/local/lib/installer/steps"

# Contadores
total_steps=0
steps_with_issues=0
VERBOSE=true
chain_issues=()

# =============================================================================
# Funcoes
# =============================================================================

usage() {
  cat <<EOF
Uso: $(basename "$0") [OPCOES]

Valida cadeia de steps do instalador.

OPCOES:
  -h, --help          Mostra esta ajuda
  -v, --verbose       Modo verboso
  -o, --output FILE   Salva relatorio em arquivo

VALIDACOES:
  1. Cada step tem @INST_STEP_ID unico
  2. @INST_NEXT pointing para step existente
  3. Nao ha cadeias quebradas (orphan steps)
  4. Step final tem @INST_NEXT vazio ou nulo
EOF
}

log() {
  local level="$1"
  shift
  case "$level" in
    INFO)  echo "[INFO] $*" ;;
    WARN)  echo "[WARN] $*" >&2 ;;
    ERROR) echo "[ERROR] $*" >&2 ;;
    DEBUG) [[ "$VERBOSE" == "true" ]] && echo "[DEBUG] $*" ;;
  esac
}

# Extrai ID do step
extract_step_id() {
  local file="$1"
  grep -oP '@INST_STEP_ID\s+\K[a-zA-Z0-9_-]+' "$file" 2>/dev/null | head -1
}

# Extrai proximo step
extract_next_step() {
  local file="$1"
  grep -oP '@INST_NEXT\s+\K[a-zA-Z0-9_-]+' "$file" 2>/dev/null | head -1
}

# Valida step individual
validate_step() {
  local file="$1"
  local step_id
  local next_step

  ((total_steps++))

  step_id=$(extract_step_id "$file")
  next_step=$(extract_next_step "$file")

  if [[ -z "$step_id" ]]; then
    chain_issues+=("$(printf '%s: Step sem @INST_STEP_ID' "$file")")
    ((steps_with_issues++))
    return 1
  fi

  log DEBUG "Step: $step_id -> $next_step"

  # Retorna o step para analise
  echo "$step_id:$next_step:$file"
}

# Valida todos os steps
validate_all() {
  local -a steps=()
  local -A step_map
  local -A next_map

  log INFO "Iniciando validacao de cadeia de steps..."

  # Procura por arquivos de step
  if [[ ! -d "$STEPS_DIR" ]]; then
    log WARN "Diretorio de steps nao encontrado: $STEPS_DIR"
    return 1
  fi

  local -a step_files=()
  while IFS= read -r -d '' file; do
    step_files+=("$file")
  done < <(find "$STEPS_DIR" -type f -name "*.sh" -print0 2>/dev/null || true)

  if [[ ${#step_files[@]} -eq 0 ]]; then
    log WARN "Nenhum arquivo de step encontrado"
    return 1
  fi

  log INFO "Encontrados ${#step_files[@]} arquivos de step"

  # Coleta informacoes de todos os steps
  for file in "${step_files[@]}"; do
    local result
    result=$(validate_step "$file")

    if [[ -n "$result" ]]; then
      local step_id next
      step_id=$(echo "$result" | cut -d: -f1)
      next=$(echo "$result" | cut -d: -f2)

      step_map["$step_id"]="$file"
      if [[ -n "$next" ]]; then
        next_map["$step_id"]="$next"
      fi
    fi
  done

  # Valida cadeias
  validate_chains "${!step_map[@]}" "${!next_map[@]}"
}

# Valida integridade das cadeias
validate_chains() {
  local all_steps=("$1")
  local all_next=("$2")

  log INFO "Validando integridade das cadeias..."

  # Verifica duplicates de step_id
  local -A seen_steps
  for step in "${all_steps[@]}"; do
    if [[ -n "${seen_steps[$step]}" ]]; then
      chain_issues+=("Step ID duplicado: $step")
      ((steps_with_issues++))
    fi
    seen_steps["$step"]=1
  done

  # Verifica que todos os @INST_NEXT apontam para steps existentes
  for step in "${!next_map[@]}"; do
    local next="${next_map[$step]}"

    if [[ -n "$next" ]] && [[ -z "${step_map[$next]}" ]]; then
      chain_issues+=("Cadeia quebrada: $step -> $next (step nao existe)")
      ((steps_with_issues++))
    fi
  done

  # Detecta orphan steps (steps que ninguem referencia)
  local -A referenced
  for next in "${next_map[@]}"; do
    referenced["$next"]=1
  done

  for step in "${all_steps[@]}"; do
    if [[ -z "${referenced[$step]}" ]]; then
      # So e problema se nao for o primeiro step
      local is_first=false
      for s in "${!next_map[@]}"; do
        if [[ "${next_map[$s]}" == "$step" ]]; then
          is_first=true
          break
        fi
      done

      if [[ "$is_first" == "false" ]] && [[ ${#next_map[@]} -gt 1 ]]; then
        chain_issues+=("Orphan step: $step (nenhum step aponta para ele)")
      fi
    fi
  done
}

# Gera relatorio
generate_report() {
  echo "=============================================="
  echo "  RELATORIO DE CADEIA DE STEPS"
  echo "=============================================="
  echo
  echo "Total de steps:        $total_steps"
  echo "Steps com issues:      $steps_with_issues"
  echo

  if [[ ${#chain_issues[@]} -gt 0 ]]; then
    echo "--- Issues Encontradas ---"
    printf '%s\n' "${chain_issues[@]}"
    echo
    echo "Status: FALHA"
    echo "Acao: Corrigir cadeia de steps conforme issues acima"
    return 1
  else
    echo "--- Cadeia de Steps ---"
    echo "  Todos os steps estao corretamente encadeados!"
    echo
    echo "Status: SUCESSO"
    return 0
  fi
}

# =============================================================================
# Main
# =============================================================================

VERBOSE=true
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
