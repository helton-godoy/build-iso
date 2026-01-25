#!/usr/bin/env bash
#
# components/06-chroot-configure.sh - Chroot configurations (users, hostname, locale, fstab, initramfs)
# Modularized from install-system
# Uses: lib/logging.sh, lib/chroot.sh
#

set -euo pipefail

# =============================================================================
# VARIÁVEIS
# =============================================================================

# Importar bibliotecas
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib"
export LIB_DIR
# shellcheck disable=SC1090
source "${LIB_DIR}/logging.sh"
# shellcheck disable=SC1090
source "${LIB_DIR}/chroot.sh"

# Variáveis globais (serão importadas do orquestrador)
declare HOSTNAME=""
declare USERNAME=""
declare ROOT_PASS=""
declare USER_PASS=""
declare MOUNT_POINT="${MOUNT_POINT:-/mnt/target}"

# =============================================================================
# FUNÇÕES DE CONFIGURAÇÃO
# =============================================================================

# Configurar hostname e /etc/hosts
configure_hostname() {
	log_step "Configurando hostname e hosts..."

	if [[ -z ${HOSTNAME} ]]; then
		log_warn "Hostname não definido, usando padrão 'debian'"
		HOSTNAME="debian"
	fi

	# Validar hostname
	if [[ ${#HOSTNAME} -gt 253 ]]; then
		log_error "Hostname muito longo (máx 253 caracteres)"
		return 1
	fi

	if ! echo "${HOSTNAME}" >"${MOUNT_POINT}/etc/hostname"; then
		log_error "Falha ao criar /etc/hostname"
		return 1
	fi

	# Criar /etc/hosts
	if ! cat >"${MOUNT_POINT}/etc/hosts" <<HOSTSEOF; then
127.0.0.1	localhost
127.0.1.1	${HOSTNAME}
::1		localhost ip6-localhost ip6-loopback
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
HOSTSEOF
		log_error "Falha ao criar /etc/hosts"
		return 1
	fi

	log_success "Hostname (${HOSTNAME}) e hosts configurados"
	return 0
}

# Configurar usuários e senhas
configure_users() {
	log_step "Configurando usuários..."

	# Validar senhas
	if [[ -z ${ROOT_PASS} ]]; then
		log_error "Senha do root não pode ser vazia"
		return 1
	fi

	if [[ ${#ROOT_PASS} -lt 6 ]]; then
		log_error "Senha do root muito curta (mínimo 6 caracteres)"
		return 1
	fi

	if [[ -z ${USER_PASS} ]]; then
		log_error "Senha do usuário não pode ser vazia"
		return 1
	fi

	if [[ ${#USER_PASS} -lt 6 ]]; then
		log_error "Senha do usuário muito curta (mínimo 6 caracteres)"
		return 1
	fi

	if [[ -z ${USERNAME} ]]; then
		log_error "Nome de usuário não pode ser vazio"
		return 1
	fi

	# Configurar senha do root
	chroot_zfs "${MOUNT_POINT}" /bin/bash -c "echo 'root:${ROOT_PASS}' | chpasswd"

	# Criar usuário
	chroot_zfs "${MOUNT_POINT}" useradd -m -s /bin/bash -G sudo,dip,plugdev,cdrom "${USERNAME}"

	# Configurar senha do usuário
	chroot_zfs "${MOUNT_POINT}" /bin/bash -c "echo '${USERNAME}:${USER_PASS}' | chpasswd"

	# Configurar sudo para o usuário
	chroot_zfs "${MOUNT_POINT}" /bin/bash -c "echo '${USERNAME} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/${USERNAME}"

	log_success "Usuários configurados: root, ${USERNAME} com sudo"
	return 0
}

# Configurar locale e timezone
configure_locale() {
	log_step "Configurando locale e timezone..."

	# Configurar locale padrão
	local selected_locale="pt_BR.UTF-8"
	echo "${selected_locale} UTF-8" >"${MOUNT_POINT}/etc/locale.gen"

	# Gerar locale
	chroot_zfs "${MOUNT_POINT}" locale-gen

	# Configurar LANGUAGE e LANG
	local lang_code
	lang_code=$(echo "${selected_locale}" | cut -d. -f1)
	chroot_zfs "${MOUNT_POINT}" update-locale LANG="${selected_locale}" LANGUAGE="${lang_code}"

	# Configurar timezone (padrão: America/Sao_Paulo)
	local selected_timezone="America/Sao_Paulo"
	echo "${selected_timezone}" >"${MOUNT_POINT}/etc/timezone"
	chroot_zfs "${MOUNT_POINT}" dpkg-reconfigure -f noninteractive tzdata

	log_success "Locale (${selected_locale}) e timezone (${selected_timezone}) configurados"
	return 0
}

# Configurar /etc/fstab
configure_fstab() {
	log_step "Configurando /etc/fstab..."

	local pool_name="${POOL_NAME:-zroot}"

	if ! cat >"${MOUNT_POINT}/etc/fstab" <<FSTABEOF; then
# /etc/fstab: arquivo de configuração de sistemas de arquivos estáticos
#
# Use 'blkid' para imprimir o UUID de dispositivos
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
${pool_name}/ROOT/debian	/	zfs	defaults,noatime,xattr=sa	0	0
${pool_name}/home		/home	zfs	defaults,noatime,xattr=sa	0	0
${pool_name}/home/root		/root	zfs	defaults,noatime,xattr=sa	0	0
${pool_name}/var/log		/var/log	zfs	defaults,noatime,xattr=sa	0	0
${pool_name}/var/cache		/var/cache	zfs	defaults,noatime,xattr=sa	0	0
${pool_name}/var/tmp		/var/tmp	zfs	defaults,noatime,xattr=sa	0	0
tmpfs		/tmp		tmpfs	defaults,nosuid,nodev,noexec,mode=1777	0	0
FSTABEOF
		log_error "Falha ao criar /etc/fstab"
		return 1
	fi

	log_success "/etc/fstab configurado"
	return 0
}

# Gerar hostid consistente com o pool
generate_hostid() {
	log_step "Gerando hostid consistente com pool ZFS..."

	# Remover hostid existente (pode vir do squashfs)
	if [[ -f "${MOUNT_POINT}/etc/hostid" ]]; then
		log_info "Removendo /etc/hostid existente..."
		rm -f "${MOUNT_POINT}/etc/hostid"
	fi

	# Gerar novo hostid
	chroot_zfs "${MOUNT_POINT}" zgenhostid

	log_success "Hostid gerado"
	return 0
}

# Configurar kmscon no sistema instalado
configure_kmscon() {
	log_step "Configurando kmscon no sistema instalado..."

	# Garantir que o diretório de configuração exista
	mkdir -p "${MOUNT_POINT}/etc/kmscon"

	# Copiar configuração do kmscon do ambiente live para o instalado
	if [[ -f "/etc/kmscon/kmscon.conf" ]]; then
		cp "/etc/kmscon/kmscon.conf" "${MOUNT_POINT}/etc/kmscon/kmscon.conf"
		log_info "Configuração do kmscon copiada do ambiente Live"
	else
		# Fallback se não existir no live (incomum, mas seguro)
		cat >"${MOUNT_POINT}/etc/kmscon/kmscon.conf" <<KMSEOF
font-engine=pango
font-size=16
font-name=FiraCode Nerd Font Mono
hwaccel=yes
xkb-layout=br
xkb-variant=abnt2
palette=black=#21222C
palette=red=#FF5555
palette=green=#50FA7B
palette=yellow=#F1FA8C
palette=blue=#BD93F9
palette=magenta=#FF79C6
palette=cyan=#8BE9FD
palette=white=#F8F8F2
palette=bright-black=#6272A4
palette=bright-red=#FF6E6E
palette=bright-green=#69FF94
palette=bright-yellow=#FFFFA5
palette=bright-blue=#D6ACFF
palette=bright-magenta=#FF92DF
palette=bright-cyan=#A4FFFF
palette=bright-white=#FFFFFF
term=xterm-256color
KMSEOF
		log_warn "Configuração do kmscon gerada (fallback)"
	fi

	# Copiar configuração de fonte (fallback para emojis)
	mkdir -p "${MOUNT_POINT}/etc/fonts/conf.d"
	if [[ -f "/etc/fonts/conf.d/99-kmscon-emoji.conf" ]]; then
		cp "/etc/fonts/conf.d/99-kmscon-emoji.conf" "${MOUNT_POINT}/etc/fonts/conf.d/"
	fi

	# Proteger pacote kmscon customizado
	chroot_zfs "${MOUNT_POINT}" apt-mark hold kmscon 2>/dev/null || true

	# Habilitar kmscon no systemd
	chroot_zfs "${MOUNT_POINT}" systemctl enable kmsconvt@tty1.service 2>/dev/null || true
	chroot_zfs "${MOUNT_POINT}" ln -sf /usr/lib/systemd/system/kmsconvt@.service /etc/systemd/system/autovt@.service 2>/dev/null || true

	log_success "kmscon configurado no sistema alvo"
	return 0
}

# Regenerar initramfs com suporte ZFS
update_initramfs() {
	log_step "Regenerando initramfs com suporte ZFS..."

	# Habilitar serviços systemd ZFS conforme documentação oficial
	chroot_zfs "${MOUNT_POINT}" systemctl enable zfs.target 2>/dev/null || true
	chroot_zfs "${MOUNT_POINT}" systemctl enable zfs-import-cache 2>/dev/null || true
	chroot_zfs "${MOUNT_POINT}" systemctl enable zfs-mount 2>/dev/null || true
	chroot_zfs "${MOUNT_POINT}" systemctl enable zfs-import.target 2>/dev/null || true

	# Regenerar initramfs para todos os kernels
	chroot_zfs "${MOUNT_POINT}" update-initramfs -c -k all

	log_success "Initramfs regenerado com suporte ZFS"

	# Configurar DKMS para rebuild automático quando ZFS for atualizado
	local dkms_conf="${MOUNT_POINT}/etc/dkms/zfs.conf"
	mkdir -p "$(dirname "${dkms_conf}")"
	echo "REMAKE_INITRD=yes" >"${dkms_conf}"

	log_info "DKMS configurado para rebuild automático do initramfs"
	return 0
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
	log_section "=== DEBIAN_ZFS Installer - Chroot Configuration Phase ==="
	log_info "Configurando sistema para ${PROFILE:-Server} profile..."

	# Validar que MOUNT_POINT está montado
	if ! mountpoint -q "${MOUNT_POINT}"; then
		log_error "MOUNT_POINT ${MOUNT_POINT} não está montado"
		return 1
	fi

	# Executar configurações
	configure_hostname || return 1
	configure_users || return 1
	configure_locale || return 1
	configure_fstab || return 1
	generate_hostid || return 1
	configure_kmscon || return 1
	update_initramfs || return 1

	log_success "=== Chroot configuration completed successfully ==="
	return 0
}

# Executar main se script for executado diretamente
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
	main "$@"
fi
