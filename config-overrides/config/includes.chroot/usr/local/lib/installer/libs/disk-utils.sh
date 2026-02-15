#!/usr/bin/env bash
# @INST_LIB_NAME: disk-utils
# @INST_DESC: Detecção, listagem e seleção de dispositivos de armazenamento.
# @INST_DEP: lsblk, awk, sed

set -euo pipefail

# Tamanho mínimo em GB
MIN_DISK_SIZE_GB=8
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
    return 3
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
#!/usr/bin/env bash
# @INST_LIB_NAME: partitioning
# @INST_DESC: Gerenciamento de tabelas GPT e criação de partições híbridas.
# @INST_DEP: sgdisk, wipefs, partprobe

set -euo pipefail

# Tamanhos das partições (exportadas para disponibilidade em subshells)
export PART_BIOS_SIZE="1MiB"
export PART_ESP_SIZE="512MiB"

# Variáveis das partições (serão definidas após particionamento)
PART_BIOS=""
PART_ESP=""
PART_ZFS=""

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

# Obtém o nome correto da partição baseado no tipo de dispositivo
_get_partition_name() {
  local disk="$1"
  local num="$2"

  # NVMe: nvme0n1 -> nvme0n1p1
  if [[ "$disk" =~ nvme ]]; then
    echo "${disk}p${num}"
  else
    # SATA/SAS/IDE: sda -> sda1
    echo "${disk}${num}"
  fi
}

# ============================================================================
# FUNÇÕES PÚBLICAS
# ============================================================================

# Limpa completamente o disco (wipefs + gdisk zap)
# Uso: partition_wipe_disk /dev/sda
# @INST_FUNC: partition_wipe_disk
# @INST_DESC: Remove todas as assinaturas e tabelas de partição de um disco.
# @INST_CAUTION: Operação destrutiva.
partition_wipe_disk() {
  local disk="$1"

  if [[ ! -b "$disk" ]]; then
    return 1
  fi

  # Limpa assinaturas de filesystem
  wipefs -af "$disk" 2>/dev/null || true

  # Destrói tabela de partição GPT
  sgdisk --zap-all "$disk" 2>/dev/null || true

  # Sincroniza
  partprobe "$disk" 2>/dev/null || true
  sync

  sleep 1
}

# Cria tabela de partição GPT com layout híbrido
# Layout: 1=BIOS Boot (1MB), 2=ESP (512MB), 3=ZFS (restante)
# Uso: partition_create_gpt /dev/sda
# @INST_FUNC: partition_create_gpt
# @INST_DESC: Cria o layout de partições padrão (BIOS Boot, ESP, ZFS).
# @INST_ARGS: disk
# @INST_STATE: PART_BIOS, PART_ESP, PART_ZFS
partition_create_gpt() {
  local disk="$1"

  if [[ ! -b "$disk" ]]; then
    return 1
  fi

  # Cria nova tabela GPT
  sgdisk -o "$disk"

  # Partição 1: BIOS Boot (EF02)
  sgdisk -n 1:2048:+"$PART_BIOS_SIZE" -t 1:EF02 -c 1:"BIOS Boot" "$disk"

  # Partição 2: EFI System Partition (EF00)
  sgdisk -n 2:0:+"$PART_ESP_SIZE" -t 2:EF00 -c 2:"EFI System" "$disk"

  # Partição 3: Solaris Root (BF00) - restante do disco
  sgdisk -n 3:0:0 -t 3:BF00 -c 3:"ZFS Root" "$disk"

  # Sincroniza
  partprobe "$disk"
  sync

  sleep 2

  # Define variáveis das partições
  PART_BIOS=$(_get_partition_name "$disk" 1)
  PART_ESP=$(_get_partition_name "$disk" 2)
  PART_ZFS=$(_get_partition_name "$disk" 3)
}

# Formata a partição ESP como FAT32
# Uso: partition_format_esp /dev/sda2
partition_format_esp() {
  local esp_part="$1"

  if [[ ! -b "$esp_part" ]]; then
    return 1
  fi

  mkfs.vfat -F 32 -n "EFI" "$esp_part"
}

# Retorna o caminho da partição BIOS Boot
# Uso: partition_get_bios /dev/sda
partition_get_bios() {
  local disk="${1:-}"
  if [[ -n "$disk" ]]; then
    _get_partition_name "$disk" 1
  else
    echo "$PART_BIOS"
  fi
}

# Retorna o caminho da partição ESP
# Uso: partition_get_esp /dev/sda
partition_get_esp() {
  local disk="${1:-}"
  if [[ -n "$disk" ]]; then
    _get_partition_name "$disk" 2
  else
    echo "$PART_ESP"
  fi
}

# Retorna o caminho da partição ZFS
# Uso: partition_get_zfs /dev/sda
partition_get_zfs() {
  local disk="${1:-}"
  if [[ -n "$disk" ]]; then
    _get_partition_name "$disk" 3
  else
    echo "$PART_ZFS"
  fi
}

# Verifica se as partições foram criadas corretamente
# Uso: partition_verify /dev/sda
partition_verify() {
  local disk="$1"
  local errors=0

  local bios=$(_get_partition_name "$disk" 1)
  local esp=$(_get_partition_name "$disk" 2)
  local zfs=$(_get_partition_name "$disk" 3)

  # Verifica se partições existem
  if [[ ! -b "$bios" ]]; then
    echo "ERRO: Partição BIOS Boot não encontrada: $bios"
    errors=$((errors + 1))
  fi

  if [[ ! -b "$esp" ]]; then
    echo "ERRO: Partição ESP não encontrada: $esp"
    errors=$((errors + 1))
  fi

  if [[ ! -b "$zfs" ]]; then
    echo "ERRO: Partição ZFS não encontrada: $zfs"
    errors=$((errors + 1))
  fi

  # Verifica tipo da partição ESP (deve ser FAT32)
  if [[ -b "$esp" ]]; then
    local fstype
    fstype=$(lsblk -d -n -o FSTYPE "$esp" 2>/dev/null || echo "")
    if [[ "$fstype" != "vfat" ]]; then
      echo "AVISO: Partição ESP não está formatada como FAT32"
    fi
  fi

  return $errors
}

# Exibe informações sobre as partições criadas
partition_info() {
  local disk="$1"

  echo "Layout de partições em $disk:"
  sgdisk -p "$disk" 2>/dev/null || parted -s "$disk" print
}

# ============================================================================
# TESTE UNITÁRIO (quando executado diretamente)
# ============================================================================

# ============================================================================
# DISKUTILS ADAPTERS (API Compatibility)
# ============================================================================

diskutils_validate_target_disk() {
  local disk="$1"
  if [[ ! -b "$disk" ]]; then
    stderr "Erro: Disco inválido: $disk"
    return 1
  fi
}

diskutils_refuse_install_on_media_disk() {
  local disk="$1"
  # TODO: Implementar verificação real se é a mídia de instalação
  # Por enquanto, apenas loga
  log_line "INFO" "Verificando se $disk é mídia de instalação..."
}

diskutils_umount_all_children() {
  local disk="$1"
  # Desmonta tudo associado ao disco
  lsblk -n -o MOUNTPOINT "$disk" | grep -v "^$" | sort -r | xargs -r umount -f || true
}

diskutils_wipe_signatures() {
  partition_wipe_disk "$1"
}

diskutils_zap_gpt() {
  sgdisk --zap-all "$1" 2>/dev/null || true
}

diskutils_create_gpt_efi_swap_optional() {
  local disk="$1"
  local efi_mib="${2:-512}"
  local swap_mib="${3:-0}"
  local bios_grub="${4:-0}"

  local part_num=1

  sgdisk -o "$disk"

  if [[ "$bios_grub" == "1" ]]; then
    sgdisk -n ${part_num}:2048:+"1MiB" -t ${part_num}:EF02 -c ${part_num}:"BIOS Boot" "$disk"
    part_num=$((part_num + 1))
  fi

  sgdisk -n ${part_num}:0:+"${efi_mib}MiB" -t ${part_num}:EF00 -c ${part_num}:"EFI System" "$disk"
  part_num=$((part_num + 1))

  if [[ "$swap_mib" != "0" ]]; then
    sgdisk -n ${part_num}:0:+"${swap_mib}MiB" -t ${part_num}:8200 -c ${part_num}:"Linux Swap" "$disk"
    part_num=$((part_num + 1))
  fi

  # Resto para ZFS
  sgdisk -n ${part_num}:0:0 -t ${part_num}:BF00 -c ${part_num}:"ZFS Root" "$disk"

  partprobe "$disk"
  sleep 2
}

diskutils_partition_paths_for_zfs_layout() {
  local disk="$1"
  local has_swap="${2:-0}"
  local bios_grub="${3:-0}"

  local p=1

  if [[ "$bios_grub" == "1" ]]; then
    p=$((p + 1))
  fi

  local efi_part="$(_get_partition_name "$disk" "$p")"
  p=$((p + 1))

  local swap_part=""
  if [[ "$has_swap" == "1" ]]; then
    swap_part="$(_get_partition_name "$disk" "$p")"
    p=$((p + 1))
  fi

  local zfs_part="$(_get_partition_name "$disk" "$p")"

  echo "EFI=$efi_part"
  echo "SWAP=$swap_part"
  echo "ZFS=$zfs_part"
}

diskutils_mkfs_vfat_efi() {
  partition_format_esp "$1"
}

diskutils_mkswap_partition() {
  mkswap "$1"
}
