#!/usr/bin/env bash
#
# partitioning.sh - Particionamento GPT híbrido (BIOS Boot + ESP + ZFS)
#

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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "
	=== Teste de Particionamento ===
	
	Esta é uma operação DESTRUTIVA.
	Use apenas em VMs ou discos de teste.
	
	Funções disponíveis:
	  partition_wipe_disk <disk>
	  partition_create_gpt <disk>
	  partition_format_esp <partition>
	  partition_verify <disk>
	"
fi
