#!/usr/bin/env bash
# @INST_LIB_NAME: system-config
# @INST_DESC: Configurações essenciais do sistema instalado (hostname, timezone, usuários).

set -euo pipefail

# Diretório de montagem do sistema alvo
TARGET_MOUNT="/mnt"

# ============================================================================
# FUNÇÕES PÚBLICAS
# ============================================================================

# Define o hostname do sistema
# Uso: system_set_hostname <hostname> [target_mount]
system_set_hostname() {
	local hostname="$1"
	local target="${2:-$TARGET_MOUNT}"

	# Valida hostname (apenas alfanuméricos e hífens)
	if [[ ! "$hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
		return 1
	fi

	# /etc/hostname
	echo "$hostname" >"${target}/etc/hostname"

	# /etc/hosts
	cat >"${target}/etc/hosts" <<EOF
127.0.0.1	localhost
127.0.1.1	${hostname}

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
}

# Cria usuário inicial com sudo
# Uso: system_create_user <username> <password> [target_mount]
system_create_user() {
	local username="$1"
	local password="$2"
	local target="${3:-$TARGET_MOUNT}"

	# Cria usuário com groups padrão
	chroot "$target" useradd -m -s /bin/bash \
		-G sudo,plugdev,audio,video,users "$username"

	# Define senha
	echo "${username}:${password}" | chroot "$target" chpasswd
}

# Define senha do root
# Uso: system_set_root_password <password> [target_mount]
system_set_root_password() {
	local password="$1"
	local target="${2:-$TARGET_MOUNT}"

	echo "root:${password}" | chroot "$target" chpasswd
}

# Configura timezone
# Uso: system_set_timezone <timezone> [target_mount]
system_set_timezone() {
	local timezone="${1:-UTC}"
	local target="${2:-$TARGET_MOUNT}"

	chroot "$target" ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
	chroot "$target" dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true
}

# Configura locales
# Uso: system_set_locales [target_mount]
system_set_locales() {
	local target="${1:-$TARGET_MOUNT}"

	# Gera locales principais
	chroot "$target" sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
	chroot "$target" sed -i 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
	chroot "$target" locale-gen 2>/dev/null || true

	# Define locale padrão
	echo 'LANG=en_US.UTF-8' >"${target}/etc/default/locale"
}

# Configura rede DHCP
# Uso: system_configure_network [target_mount]
system_configure_network() {
	local target="${1:-$TARGET_MOUNT}"

	# Configuração básica de interfaces para DHCP
	cat >"${target}/etc/network/interfaces" <<'EOF'
# This file describes the network interfaces available on your system
# and how to activate them.

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug ens3
iface ens3 inet dhcp

allow-hotplug ens4
iface ens4 inet dhcp
EOF
}

# Gera hostid persistente
# Uso: system_generate_hostid [target_mount]
system_generate_hostid() {
	local target="${1:-$TARGET_MOUNT}"

	# Gera hostid e salva no sistema alvo
	zgenhostid -f -o "${target}/etc/hostid"
}

# Obtém hostid gerado
# Uso: system_get_hostid [target_mount]
system_get_hostid() {
	local target="${1:-$TARGET_MOUNT}"

	if [[ -f "${target}/etc/hostid" ]]; then
		dd if="${target}/etc/hostid" bs=1 skip=0 count=4 2>/dev/null | od -A x -t x1 | head -1 | awk '{print $2$3$4$5}'
	else
		echo "00000000"
	fi
}

# Configura fstab mínimo para ZFS
# Uso: system_configure_fstab <pool_name> [target_mount]
system_configure_fstab() {
	local pool="$1"
	local target="${2:-$TARGET_MOUNT}"

	# ZFS gerencia seus próprios mounts, fstab é mínimo
	cat >"${target}/etc/fstab" <<EOF
# /etc/fstab: static file system information
#
# ZFS datasets are managed by ZFS itself
${pool}/ROOT/debian / zfs defaults 0 0
EOF
}

# Atualiza initramfs no sistema alvo
# Uso: system_update_initramfs [target_mount]
system_update_initramfs() {
	local target="${1:-$TARGET_MOUNT}"

	chroot "$target" update-initramfs -u -k all
}

# ============================================================================
# FUNÇÕES DE CHROOT HELPERS
# ============================================================================

# Monta sistemas virtuais para chroot
# Uso: system_mount_vfs [target_mount]
system_mount_vfs() {
	local target="${1:-$TARGET_MOUNT}"

	mount --bind /dev "${target}/dev"
	mount --bind /proc "${target}/proc"
	mount --bind /sys "${target}/sys"
	mount --bind /run "${target}/run"
}

# Desmonta sistemas virtuais
# Uso: system_umount_vfs [target_mount]
system_umount_vfs() {
	local target="${1:-$TARGET_MOUNT}"

	umount -l "${target}/run" 2>/dev/null || true
	umount -l "${target}/sys" 2>/dev/null || true
	umount -l "${target}/proc" 2>/dev/null || true
	umount -l "${target}/dev" 2>/dev/null || true
}

# ============================================================================
# TESTE UNITÁRIO (quando executado diretamente)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "=== Teste de Configuração do Sistema ==="
	echo
	echo "Funções disponíveis:"
	echo "  system_set_hostname <hostname> [target]"
	echo "  system_create_user <user> <pass> [target]"
	echo "  system_set_root_password <pass> [target]"
	echo "  system_set_timezone [timezone] [target]"
	echo "  system_set_locales [target]"
	echo "  system_configure_network [target]"
	echo "  system_generate_hostid [target]"
	echo "  system_configure_fstab <pool> [target]"
fi
