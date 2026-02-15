#!/usr/bin/env bash
# @INST_LIB_NAME: disk-utils
# @INST_DESC: Detecção, listagem e seleção de dispositivos de armazenamento.
# @INST_DEP: lsblk, awk, sed

set -euo pipefail

# Tamanho mínimo em GB
MIN_DISK_SIZE_GB=20
MIN_DISK_SIZE_BYTES=$((MIN_DISK_SIZE_GB * 1024 * 1024 * 1024))

# Variável global para disco selecionado
SELECTED_DISK=""
SELECTED_DISKS=()

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

_disk_strip_ansi() {
  local in="${1-}"
  printf '%s' "$in" | sed -E $'s/\x1B\[[0-9;]*[[:alpha:]]//g'
}

_disk_extract_device() {
  local line="${1-}"
  line="$(_disk_strip_ansi "$line")"
  printf '%s\n' "$line" | grep -oE '^/dev/[^ ]+'
}

# Converte tamanho para bytes
_disk_to_bytes() {
  local size="$1"
  local bytes

  size=$(echo "$size" | tr -d ' ')

  bytes=$(lsblk -d -n -b -o SIZE "/dev/$1" 2>/dev/null || echo "0")

  echo "$bytes"
}

# Converte bytes para formato legível
_disk_human_readable() {
  local bytes="$1"

  if [[ $bytes -ge 1099511627776 ]]; then
    echo "$(echo "scale=1; $bytes/1099511627776" | bc)TB"
  elif [[ $bytes -ge 1073741824 ]]; then
    echo "$(echo "scale=1; $bytes/1073741824" | bc)GB"
  elif [[ $bytes -ge 1048576 ]]; then
    echo "$(echo "scale=0; $bytes/1048576" | bc)MB"
  else
    echo "${bytes}B"
  fi
}

# ============================================================================
# FUNÇÕES PÚBLICAS
# ============================================================================

# Lista todos os discos disponíveis (exclui loop, cdrom, etc)
# Output: Lista formatada para gum choose
# @INST_FUNC: disk_list_available
# @INST_DESC: Retorna uma lista de discos que atendem aos requisitos mínimos de tamanho.
# @INST_STATE: MIN_DISK_SIZE_GB
disk_list_available() {
  local disks
  disks=$(lsblk -d -n -o NAME,SIZE,MODEL,TYPE,ROTA -e 7,11 -p 2>/dev/null || true)

  if [[ -z "$disks" ]]; then
    return 1
  fi

  local output=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local name size model type rota
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    model=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')
    type=$(lsblk -d -n -o TYPE "$name" 2>/dev/null || echo "disk")
    rota=$(lsblk -d -n -o ROTA "$name" 2>/dev/null || echo "1")

    # Pula se for loop device ou partição
    if [[ "$type" != "disk" ]]; then
      continue
    fi

    # Verifica tamanho mínimo
    local size_bytes
    size_bytes=$(lsblk -d -n -b -o SIZE "$name" 2>/dev/null || echo "0")

    if [[ "$size_bytes" -lt "$MIN_DISK_SIZE_BYTES" ]]; then
      continue
    fi

    # Determina tipo de disco
    local disk_type="HDD"
    if [[ "$rota" == "0" ]]; then
      disk_type="SSD"
    fi

    # Formata saída
    local hr_size
    hr_size=$(_disk_human_readable "$size_bytes")

    if [[ -n "$model" ]]; then
      output+="$name ($hr_size - $disk_type - $model)"$'\n'
    else
      output+="$name ($hr_size - $disk_type)"$'\n'
    fi
  done <<<"$disks"

  # Remove última nova linha
  echo -n "$output" | sed '/^$/d'
}

# Lista discos disponíveis excluindo uma lista específica (CSV)
# Uso: disk_list_available_excluding "/dev/sda,/dev/sdb"
# @INST_FUNC: disk_list_available_excluding
# @INST_DESC: Lista discos disponíveis filtrando os já selecionados.
disk_list_available_excluding() {
  local exclude_csv="${1:-}"
  local disks
  disks=$(disk_list_available)

  if [[ -z "$disks" ]]; then
    return 1
  fi

  if [[ -z "$exclude_csv" ]]; then
    echo "$disks"
    return 0
  fi

  local output=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local dev
    dev="$(_disk_extract_device "$line")"
    # Check if dev is in exclude_csv (simple string match wrapper)
    if [[ ",$exclude_csv," == *",$dev,"* ]]; then
      continue
    fi
    output+="$line"$'\n'
  done <<<"$disks"
  echo -n "$output" | sed '/^$/d'
}

# Retorna número de discos disponíves
disk_count() {
  disk_list_available | wc -l
}

# Verifica se há discos suficientes
# Retorna 0 se há pelo menos 1 disco, 1 caso contrário
disk_has_available() {
  local count
  count=$(disk_count)
  [[ "$count" -ge 1 ]]
}

# Seleciona um disco interativamente usando gum
# Retorna: Define SELECTED_DISK com o caminho do dispositivo
# @INST_FUNC: disk_select_interactive
# @INST_DESC: Interface para usuário selecionar o disco alvo da instalação.
# @INST_ARGS: prompt (opcional)
# @INST_STATE: SELECTED_DISK
disk_select_interactive() {
  local selected_many
  selected_many="$(disk_select_multi_interactive "${1:-Selecione o disco de destino:}")" || return 1
  SELECTED_DISK="$(printf '%s\n' "$selected_many" | sed -n '1p')"
  printf '%s\n' "$SELECTED_DISK"
}

# Seleciona múltiplos discos interativamente usando gum
# Retorna: caminhos /dev/... separados por nova linha
disk_select_multi_interactive() {
  local disks
  disks=$(disk_list_available)

  if [[ -z "$disks" ]]; then
    return 1
  fi

  local prompt="${1:-Selecione o disco de destino:}"

  local prompt="${1:-Selecione o disco de destino:}"

  local selected
  local ret=0
  if declare -F ui_filter_multiselect >/dev/null 2>&1; then
    local -a options=()
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      options+=("$line")
    done <<<"$disks"
    # Capture exit code from ui_filter_multiselect (propagated from gum/logic)
    selected="$(ui_filter_multiselect "$prompt" "${options[@]}")" || ret=$?
  else
    # Usar estilo do DS sem contaminar stdout (capturado pelo chamador)
    gum style --foreground "${DS_CLOUD:-250}" "$prompt" >&2
    gum style --foreground "${DS_FOG:-245}" --italic "  ${UI_ARROW:-▶} Espaço marca • Enter confirma seleção" >&2
    echo "" >&2

    selected=$(echo "$disks" | gum choose \
      --height 8 \
      --show-help \
      --no-limit \
      --cursor "${UI_ARROW:-▶} " \
      --selected-prefix "[${UI_BULLET:-●}] " \
      --unselected-prefix "[ ] " \
      --cursor-prefix "[ ] " \
      --cursor.foreground "${DS_FILESERVER_PEAK:-153}" \
      --item.foreground "${DS_CLOUD:-250}" \
      --selected.foreground "${DS_SILVER:-252}" \
      --selected.background "${DS_ELEVATION:-239}") || ret=$?
  fi

  # If canceled by user (Esc/Ctrl+C), return 1
  if [[ "$ret" -ne 0 ]]; then
    return 1
  fi

  if [[ -z "$(sanitize_ws "$selected")" ]]; then
    # Selected nothing but confirmed (Enter) -> Return 2
    return 2
  fi

  mapfile -t SELECTED_DISKS < <(
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      _disk_extract_device "$line"
    done <<<"$selected"
  )

  if [[ "${#SELECTED_DISKS[@]}" -eq 0 ]]; then
    return 2
  fi

  SELECTED_DISK="${SELECTED_DISKS[0]}"

  printf '%s\n' "${SELECTED_DISKS[@]}"
}

# Retorna o disco selecionado
disk_get_selected() {
  echo "$SELECTED_DISK"
}

# Obtém informações de um disco específico
# Uso: disk_get_info /dev/sda
disk_get_info() {
  local disk="$1"

  if [[ ! -b "$disk" ]]; then
    return 1
  fi

  local size_bytes model
  size_bytes=$(lsblk -d -n -b -o SIZE "$disk" 2>/dev/null || echo "0")
  model=$(lsblk -d -n -o MODEL "$disk" 2>/dev/null | sed 's/ *$//')

  echo "Dispositivo: $disk"
  echo "Tamanho: $(_disk_human_readable "$size_bytes")"
  echo "Modelo: ${model:-Desconhecido}"
}

# Obtém o nome da primeira partição do disco
# Uso: disk_get_partition_1 /dev/sda -> /dev/sda1 ou /dev/nvme0n1p1
disk_get_partition() {
  local disk="$1"
  local part_num="$2"

  # NVMe devices têm formato diferente: nvme0n1p1
  if [[ "$disk" =~ nvme ]]; then
    echo "${disk}p${part_num}"
  else
    echo "${disk}${part_num}"
  fi
}

# ============================================================================
# TESTE UNITÁRIO (quando executado diretamente)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "=== Teste de Detecção de Discos ==="
  echo
  echo "Discos disponíveis:"
  disk_list_available
  echo
  echo "Total: $(disk_count) disco(s)"
fi
