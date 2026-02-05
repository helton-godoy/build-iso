#!/usr/bin/env bash
#
# disk-detection.sh - Detecção e listagem de discos disponíveis
#

set -euo pipefail

# Tamanho mínimo em GB
MIN_DISK_SIZE_GB=8
MIN_DISK_SIZE_BYTES=$((MIN_DISK_SIZE_GB * 1024 * 1024 * 1024))

# Variável global para disco selecionado
SELECTED_DISK=""

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

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
disk_select_interactive() {
	local disks
	disks=$(disk_list_available)

	if [[ -z "$disks" ]]; then
		return 1
	fi

	local selected
	selected=$(echo "$disks" | gum choose --header "Selecione o disco de destino:")

	# Extrai apenas o caminho do dispositivo (primeira coluna)
	SELECTED_DISK=$(echo "$selected" | awk '{print $1}')

	echo "$SELECTED_DISK"
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
