#!/usr/bin/env bash
#
# zbm-install.sh - Instalação e configuração do ZFSBootMenu
#

set -euo pipefail

# Diretórios padrão
ZBM_BIN_DIR="/usr/share/zfsbootmenu"
EFI_DIR="/boot/efi"
POOL_NAME="zroot"

# ============================================================================
# FUNÇÕES PÚBLICAS
# ============================================================================

# Instala ZFSBootMenu na partição ESP
# Uso: zbm_install <esp_partition> [target_mount] [pool_name]
zbm_install() {
	local esp_part="$1"
	local target="${2:-/mnt}"
	local pool="${3:-$POOL_NAME}"

	if [[ ! -b "$esp_part" ]]; then
		return 1
	fi

	# Cria diretórios necessários
	mkdir -p "${target}${EFI_DIR}"

	# Monta ESP
	mount "$esp_part" "${target}${EFI_DIR}"

	# Cria diretório do ZBM
	mkdir -p "${target}${EFI_DIR}/EFI/ZBM"

	# Copia arquivos do ZFSBootMenu se disponíveis
	if [[ -d "$ZBM_BIN_DIR" ]]; then
		# Copia EFI executable
		if [[ -f "${ZBM_BIN_DIR}/zfsbootmenu.EFI" ]]; then
			cp "${ZBM_BIN_DIR}/zfsbootmenu.EFI" "${target}${EFI_DIR}/EFI/ZBM/"
		elif [[ -f "${ZBM_BIN_DIR}/BOOTX64.EFI" ]]; then
			cp "${ZBM_BIN_DIR}/BOOTX64.EFI" "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI"
		fi

		# Copia componentes (vmlinuz e initramfs) para BIOS/Legacy
		if [[ -f "${ZBM_BIN_DIR}/vmlinuz" ]]; then
			cp "${ZBM_BIN_DIR}/vmlinuz" "${target}${EFI_DIR}/EFI/ZBM/"
		fi

		if [[ -f "${ZBM_BIN_DIR}/initramfs.img" ]]; then
			cp "${ZBM_BIN_DIR}/initramfs.img" "${target}${EFI_DIR}/EFI/ZBM/"
		fi
	fi

	# Fallback: procura em locais alternativos
	if [[ ! -f "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI" ]]; then
		# Tenta copiar da ISO (diretório de build)
		if [[ -f "/zbm/vmlinuz" ]]; then
			mkdir -p "${target}${EFI_DIR}/EFI/ZBM"
			cp /zbm/vmlinuz "${target}${EFI_DIR}/EFI/ZBM/" 2>/dev/null || true
			cp /zbm/initramfs.img "${target}${EFI_DIR}/EFI/ZBM/" 2>/dev/null || true
		fi
	fi

	sync
}

# Configura entrada de boot EFI
# Uso: zbm_configure_efi <disk> <partition_number> [target_mount]
zbm_configure_efi() {
	local disk="$1"
	local part_num="$2"
	local target="${3:-/mnt}"

	if ! command -v efibootmgr &>/dev/null; then
		return 1
	fi

	# Cria entrada de boot para ZFSBootMenu
	efibootmgr --create \
		--disk "$disk" \
		--part "$part_num" \
		--label "ZFSBootMenu" \
		--loader "\\EFI\\ZBM\\zfsbootmenu.EFI" \
		--verbose || true
}

# Configura propriedades ZFS para boot
# Uso: zbm_configure_zfs_properties <pool_name> [hostid]
zbm_configure_zfs_properties() {
	local pool="${1:-$POOL_NAME}"
	local hostid="${2:-}"

	# Obtém hostid se não fornecido
	if [[ -z "$hostid" ]]; then
		if [[ -f /etc/hostid ]]; then
			hostid=$(dd if=/etc/hostid bs=1 skip=0 count=4 2>/dev/null | od -A x -t x1 | head -1 | awk '{print $2$3$4$5}')
		else
			hostid=$(hostid 2>/dev/null || echo "00000000")
		fi
	fi

	# Define commandline no dataset ROOT
	local cmdline="quiet loglevel=4"
	if [[ -n "$hostid" && "$hostid" != "00000000" ]]; then
		cmdline="${cmdline} spl.spl_hostid=0x${hostid}"
	fi

	zfs set org.zfsbootmenu:commandline="$cmdline" "${pool}/ROOT"

	# Configura bootfs
	zpool set bootfs="${pool}/ROOT/debian" "$pool"
}

# Gera hostid para ZFS
# Uso: zbm_generate_hostid [target_mount]
zbm_generate_hostid() {
	local target="${1:-}"

	if [[ -n "$target" && -d "$target" ]]; then
		# Gera no sistema alvo
		zgenhostid -f -o "${target}/etc/hostid"
	else
		# Gera no sistema atual
		zgenhostid -f
	fi
}

# Obtém hostid atual
# Uso: zbm_get_hostid [target_mount]
zbm_get_hostid() {
	local target="${1:-}"
	local hostid_file="${target}/etc/hostid"

	if [[ -f "$hostid_file" ]]; then
		dd if="$hostid_file" bs=1 skip=0 count=4 2>/dev/null | od -A x -t x1 | head -1 | awk '{print $2$3$4$5}'
	else
		hostid 2>/dev/null | tr -d ' ' || echo "00000000"
	fi
}

# Configura ZFSBootMenu como fallback boot
# Uso: zbm_setup_fallback <esp_partition> [target_mount]
zbm_setup_fallback() {
	local esp_part="$1"
	local target="${2:-/mnt}"

	if [[ ! -b "$esp_part" ]]; then
		return 1
	fi

	# Cria diretório fallback EFI/BOOT
	mkdir -p "${target}${EFI_DIR}/EFI/BOOT"

	# Copia ZBM como bootloader fallback
	if [[ -f "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI" ]]; then
		cp "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI" \
			"${target}${EFI_DIR}/EFI/BOOT/BOOTX64.EFI"
	fi
}

# Desmonta ESP
# Uso: zbm_unmount_esp [target_mount]
zbm_unmount_esp() {
	local target="${1:-/mnt}"

	umount "${target}${EFI_DIR}" 2>/dev/null || true
}

# Verifica instalação ZBM
# Uso: zbm_verify [target_mount]
zbm_verify() {
	local target="${1:-/mnt}"
	local errors=0

	# Verifica se EFI está instalado
	if [[ ! -f "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI" ]]; then
		echo "AVISO: ZFSBootMenu EFI não encontrado"
		errors=$((errors + 1))
	fi

	# Verifica propriedades ZFS
	local pool="$POOL_NAME"
	if zpool list "$pool" &>/dev/null; then
		local bootfs
		bootfs=$(zpool get -H -o value bootfs "$pool" 2>/dev/null || echo "-")
		if [[ "$bootfs" == "-" ]]; then
			echo "AVISO: bootfs não configurado no pool"
			errors=$((errors + 1))
		fi
	fi

	return $errors
}

# ============================================================================
# TESTE UNITÁRIO (quando executado diretamente)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "=== Teste de Instalação ZFSBootMenu ==="
	echo
	echo "Funções disponíveis:"
	echo "  zbm_install <esp_partition> [target] [pool]"
	echo "  zbm_configure_efi <disk> <part_num> [target]"
	echo "  zbm_configure_zfs_properties [pool] [hostid]"
	echo "  zbm_generate_hostid [target]"
	echo "  zbm_setup_fallback <esp_partition> [target]"
	echo "  zbm_verify [target]"
fi
