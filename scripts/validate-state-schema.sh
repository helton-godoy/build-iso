#!/usr/bin/env bash
# =============================================================================
# Validacao de Schema de Estado
# =============================================================================
# Lista chaves de estado usadas no codigo
# Compara com schema oficial
# Valida que apenas chaves registradas sao usadas
# =============================================================================

set -euo pipefail

# Configuracao
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALLER_DIR="$PROJECT_ROOT/config-overrides/config/includes.chroot/usr/local/lib/installer"

# Schema oficial de chaves de estado (deve estar em sincronia com AGENTS.md)
readonly -a STATE_SCHEMA=(
  "INST_DISK_TARGET"
  "INST_ZFS_POOL"
  "INST_ZFS_STRATEGY"
  "INST_HOSTNAME"
  "INST_USER_ADMIN"
  "INST_SMB_COMPAT"
  "INST_STEP_CURRENT"
  "INST_PARTITION_TABLE"
  "INST_BOOT_MODE"
  "INST_ESP_SIZE"
  "INST_SWAP_SIZE"
  "INST_TIMEZONE"
  "INST_KEYBOARD_LAYOUT"
  "INST_NETWORK_CONFIG"
  "INST_DNS_SERVERS"
  "INST_NTP_SERVERS"
  "INST_AD_DOMAIN"
  "INST_AD_JOINED"
  "INST_SMB_ENABLED"
  "INST_NFS_ENABLED"
)

# Contadores
total_files=0
files_checked=0
VERBOSE=false
keys_found=()
keys_unregistered=()
keys_registered=()

# =============================================================================
# Funcoes
# =============================================================================

usage() {
  cat <<EOF
Uso: $(basename "$0") [OPCOES]

Valida uso de chaves de estado conforme schema oficial.

OPCOES:
  -h, --help          Mostra esta ajuda
  -v, --verbose       Modo verboso
  -s, --schema FILE   Schema alternativo (um chave por linha)
  -o, --output FILE   Salva relatorio em arquivo

CHAVES REGISTRADAS:
$(printf '  - %s\n' "${STATE_SCHEMA[@]}")

EXEMPLOS:
  $(basename "$0") -v
  $(basename "$0") -s custom-schema.txt
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

# Extrai chaves de estado de um arquivo
extract_state_keys() {
  local file="$1"
  local keys=()

  # Procura por state_get e state_set
  while IFS= read -r line; do
    # state_get "KEY"
    if [[ "$line" =~ state_get[[:space:]]+[\"\']?([A-Z_][A-Z0-9_]*) ]]; then
      keys+=("${BASH_REMATCH[1]}")
    fi

    # state_set "KEY" value
    if [[ "$line" =~ state_set[[:space:]]+[\"\']?([A-Z_][A-Z0-9_]*) ]]; then
      keys+=("${BASH_REMATCH[1]}")
    fi

    # export INST_*= (variaveis de ambiente de instalacao)
    if [[ "$line" =~ export[[:space:]]+(INST_[A-Z_][A-Z0-9_]*) ]]; then
      keys+=("${BASH_REMATCH[1]}")
    fi

    # declare -g INST_*= (variaveis globais)
    if [[ "$line" =~ declare[[:space:]]+-g[[:space:]]+([A-Z_][A-Z0-9_]*) ]]; then
      keys+=("${BASH_REMATCH[1]}")
    fi
  done < "$file"

  # Remove duplicatas
  printf '%s\n' "${keys[@]}" | sort -u
}

# Valida chave contra schema
validate_key() {
  local key="$1"
  local registered=false

  for schema_key in "${STATE_SCHEMA[@]}"; do
    if [[ "$key" == "$schema_key" ]]; then
      registered=true
      break
    fi
  done

  if [[ "$registered" == "true" ]]; then
    keys_registered+=("$key")
  else
    keys_unregistered+=("$key")
  fi
}

# Processa arquivo
process_file() {
  local file="$1"
  local keys

  ((total_files++))

  log DEBUG "Processando: $file"

  keys=$(extract_state_keys "$file")

  if [[ -n "$keys" ]]; then
    ((files_checked++))
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      validate_key "$key"
    done <<< "$keys"
  fi
}

# Valida todos os arquivos
validate_all() {
  local -a shell_files=()

  log INFO "Iniciando validacao de schema de estado..."

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
    process_file "$file"
  done
}

# Gera relatorio
generate_report() {
  local unique_registered
  local unique_unregistered

  # Remove duplicatas
  unique_registered=$(printf '%s\n' "${keys_registered[@]}" | sort -u)
  unique_unregistered=$(printf '%s\n' "${keys_unregistered[@]}" | sort -u)

  echo "=============================================="
  echo "  RELATORIO DE SCHEMA DE ESTADO"
  echo "=============================================="
  echo
  echo "Arquivos processados:    $files_checked"
  echo "Total de arquivos:       $total_files"
  echo

  echo "--- Chaves Registradas ---"
  if [[ -n "$unique_registered" ]]; then
    echo "$unique_registered" | while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      echo "  ✓ $key"
    done
  else
    echo "  (nenhuma)"
  fi
  echo

  echo "--- Chaves Nao Registradas ---"
  if [[ -n "$unique_unregistered" ]]; then
    echo "$unique_unregistered" | while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      echo "  ✗ $key"
    done
    echo
    echo "Status: FALHA"
    echo "Acao: Registrar chaves acima em AGENTS.md ou usar chaves existentes"
    return 1
  else
    echo "  (nenhuma)"
    echo
    echo "Status: SUCESSO"
    echo "Todas as chaves de estado estao registradas no schema!"
    return 0
  fi
}

# =============================================================================
# Main
# =============================================================================

VERBOSE=false
OUTPUT_FILE=""
CUSTOM_SCHEMA=""

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
    -s|--schema)
      CUSTOM_SCHEMA="$2"
      shift 2
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

# Carrega schema customizado se especificado
if [[ -n "$CUSTOM_SCHEMA" ]] && [[ -f "$CUSTOM_SCHEMA" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    STATE_SCHEMA+=("$line")
  done < "$CUSTOM_SCHEMA"
fi

validate_all
generate_report

exit $?
