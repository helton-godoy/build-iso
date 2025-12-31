#!/bin/bash
# =============================================================================
# build_iso.sh - Gera ISO Debian com perfis Server/Workstation (mmdebstrap)
# Executa DENTRO da VM de build
# =============================================================================

set -euo pipefail

# Configurações
BUILD_DIR="/root/build-iso/work"
OUTPUT_DIR="/root/build-iso/output/ISO"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ISO_NAME="debian-zfs-${TIMESTAMP}.iso"
DEBIAN_RELEASE="trixie"
ARCH="amd64"
HOSTNAME="debian-live"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERRO]${NC} $*" >&2; }

# =============================================================================
# CHECAGEM DE DEPENDÊNCIAS
# =============================================================================
check_deps() {
	# Comandos binários para verificar
	local cmds=(mmdebstrap mksquashfs xorriso mcopy mkfs.vfat grub-mkrescue curl git rsync)

	for cmd in "${cmds[@]}"; do
		if ! command -v "$cmd" &>/dev/null; then
			log_error "Comando ausente: $cmd"
			log_info "Instale as dependências: apt install mmdebstrap squashfs-tools xorriso mtools dosfstools grub-pc-bin grub-efi-amd64-bin curl git rsync"
			exit 1
		fi
	done

	# Verificação específica para módulos do GRUB (pacotes bin)
	if [ ! -d "/usr/lib/grub/i386-pc" ]; then
		log_error "Módulos GRUB PC (BIOS) ausentes."
		log_info "Instale: apt install grub-pc-bin"
		exit 1
	fi
	if [ ! -d "/usr/lib/grub/x86_64-efi" ]; then
		log_error "Módulos GRUB EFI ausentes."
		log_info "Instale: apt install grub-efi-amd64-bin"
		exit 1
	fi
}

# =============================================================================
# DEFINIÇÃO DE PACOTES
# =============================================================================

PKG_BASE=(
	# ZFS
	zfsutils-linux zfs-dkms zfs-initramfs zfs-zed libpam-zfs libzfsbootenv1linux libzfslinux-dev
	# Kernel
	linux-image-amd64 linux-headers-amd64 dkms
	# Rede
	network-manager isc-dhcp-client iputils-ping iproute2 openssh-server dnsutils nmap mtr iperf iperf3 nload ncdu
	# Tools
	keyboard-configuration coreutils bash bash-completion ca-certificates gnupg nano htop curl wget
	tmux git gum lolcat figlet rsync tar zip unzip ethtool pciutils usbutils numactl hwloc smartmontools
	nvme-cli lshw lm-sensors
	# Compressão & Particionamento
	zstd lz4 lzop gdisk parted dosfstools efibootmgr
	# Locale
	locales console-setup manpages-pt-br manpages-pt-br-dev task-portuguese task-brazilian-portuguese
	aspell-pt-br ibrazilian wbrazilian info info2man
	# Live System
	live-boot live-config live-config-systemd squashfs-tools grub-pc-bin grub-efi-amd64-bin
	# Firmware
	firmware-linux-free firmware-linux-nonfree
	# Intel
	intel-microcode thermald msr-tools
)

PKG_SERVER=(
	htop iotop iftop nmon glances sudo screen mc ncdu tree dpkg-dev build-essential
	logrotate rsyslog fail2ban ufw nfs-common cifs-utils
)

PKG_WORKSTATION=(
	plasma-desktop plasma-workspace sddm sddm-theme-breeze kwin-x11 plasma-nm plasma-pa powerdevil bluedevil
	dolphin dolphin-plugins konsole kate firefox-esr gwenview ark kcalc partitionmanager systemsettings
	pipewire pipewire-pulse wireplumber fonts-noto fonts-noto-color-emoji breeze breeze-icon-theme
	breeze-cursor-theme plasma-widgets-addons
)

PKG_CALAMARES=(
	calamares calamares-settings-debian os-prober cryptsetup kpartx
)

# =============================================================================
# FUNÇÕES DE BUILD
# =============================================================================

setup_env() {
	log_info "Limpando ambiente de build..."
	rm -rf "${BUILD_DIR}"
	mkdir -p "${BUILD_DIR}/rootfs" "${BUILD_DIR}/iso/live" "${BUILD_DIR}/iso/boot/grub" "${OUTPUT_DIR}"
}

build_rootfs() {
	log_info "Iniciando bootstrap do sistema (${DEBIAN_RELEASE})..."

	# Combinar listas
	local ALL_PKGS=("${PKG_BASE[@]}" "${PKG_SERVER[@]}" "${PKG_WORKSTATION[@]}" "${PKG_CALAMARES[@]}")
	# Converter array para string separada por vírgula
	local PKG_STR=$(
		IFS=,
		echo "${ALL_PKGS[*]}"
	)

	# mmdebstrap
	# --mode=root: Executado como root
	# --components: main contrib non-free non-free-firmware

	mmdebstrap \
		--mode=root \
		--architectures="${ARCH}" \
		--format=directory \
		--include="${PKG_STR}" \
		--components="main contrib non-free non-free-firmware" \
		--customize-hook='chroot "$1" systemctl enable sddm || true' \
		--customize-hook='chroot "$1" locale-gen pt_BR.UTF-8' \
		--customize-hook='echo "pt_BR.UTF-8 UTF-8" > "$1/etc/locale.gen"' \
		--customize-hook='chroot "$1" locale-gen' \
		"${DEBIAN_RELEASE}" \
		"${BUILD_DIR}/rootfs" \
		"https://debian.c3sl.ufpr.br/debian/"

	log_ok "Rootfs criado com sucesso!"
}

configure_rootfs() {
	log_info "Configurando Rootfs..."
	local R="${BUILD_DIR}/rootfs"

	# ---------------------------------------------------------
	# Montar sistemas de arquivos virtuais para o chroot funcionar
	# ---------------------------------------------------------
	log_info "Montando /proc, /sys, /dev..."
	mount -t proc proc "${R}/proc"
	mount -t sysfs sys "${R}/sys"
	mount --bind /dev "${R}/dev"
	mount --bind /dev/pts "${R}/dev/pts"

	# Hostname
	echo "${HOSTNAME}" >"${R}/etc/hostname"
	echo "127.0.0.1 localhost ${HOSTNAME}" >"${R}/etc/hosts"

	# Configurar usuário live
	# live-config deve cuidar disso, mas podemos forçar grupos
	log_info "Criando usuário 'user'..."

	# Garantir que shadow exista e tenha permissões
	chmod 640 "${R}/etc/shadow" 2>/dev/null || true

	# Gerar hash da senha 'live'
	local PASS_HASH=$(openssl passwd -6 "live")

	chroot "$R" useradd -m -G sudo,cdrom,dip,plugdev,netdev,audio,video -s /bin/bash -p "${PASS_HASH}" user || true
	# Caso o usuário já exista (re-run), garantir a senha
	chroot "$R" usermod -p "${PASS_HASH}" user

	# SDDM Autologin (KDE)
	mkdir -p "${R}/etc/sddm.conf.d"
	cat >"${R}/etc/sddm.conf.d/autologin.conf" <<EOF
[Autologin]
User=user
Session=plasma
Relogin=false
EOF

	# ZFSBootMenu (Download se não existir)
	local ZBM_DIR="${R}/usr/share/zfsbootmenu"
	mkdir -p "${ZBM_DIR}"
	if [ ! -f "${ZBM_DIR}/zfsbootmenu.EFI" ]; then
		log_info "Baixando ZFSBootMenu..."
		curl -L -o "${ZBM_DIR}/zfsbootmenu.EFI" \
			"https://github.com/zbm-dev/zfsbootmenu/releases/latest/download/zfsbootmenu-x86_64-vmlinuz.EFI" || log_warn "Falha download ZBM"
	fi

	# Limpeza
	chroot "$R" apt-get clean
	rm -rf "${R}/var/lib/apt/lists/*"
	rm -rf "${R}/tmp/*"

	# ---------------------------------------------------------
	# Desmontar
	# ---------------------------------------------------------
	log_info "Desmontando /proc, /sys, /dev..."
	umount "${R}/dev/pts" || true
	umount "${R}/dev" || true
	umount "${R}/sys" || true
	umount "${R}/proc" || true
}

copy_installer_files() {
	log_info "Copiando arquivos do instalador e configurações..."
	local R="${BUILD_DIR}/rootfs"
	local REPO_ROOT="/root/build-iso"

	# 1. Overlay includes.chroot (scripts, zbm-config, etc)
	if [ -d "${REPO_ROOT}/config/includes.chroot" ]; then
		log_info "Aplicando overlay includes.chroot..."
		rsync -avK "${REPO_ROOT}/config/includes.chroot/" "${R}/"
	fi

	# 2. Configurações do Calamares
	mkdir -p "${R}/etc/calamares"
	if [ -d "${REPO_ROOT}/config/calamares" ]; then
		log_info "Copiando configurações do Calamares..."
		# Copiar recursivamente
		rsync -avK "${REPO_ROOT}/config/calamares/" "${R}/etc/calamares/"
	fi

	# 3. Permissões de execução para scripts
	chmod +x "${R}/usr/local/bin/"*.sh 2>/dev/null || true
	chmod +x "${R}/usr/bin/"* 2>/dev/null || true
}

pack_rootfs() {
	# Certificar que copiou antes de empacotar
	copy_installer_files

	log_info "Criando SquashFS..."
	mksquashfs "${BUILD_DIR}/rootfs" "${BUILD_DIR}/iso/live/filesystem.squashfs" -comp zstd -b 1048576
	chmod 444 "${BUILD_DIR}/iso/live/filesystem.squashfs"

	# Copiar Kernel e Initrd para diretório live
	# Encontrar versão mais recente instalada
	local KERNEL_V=$(ls "${BUILD_DIR}/rootfs/boot/vmlinuz-"* | sort -V | tail -n1 | sed 's/.*vmlinuz-//')
	log_info "Kernel versão: $KERNEL_V"

	cp "${BUILD_DIR}/rootfs/boot/vmlinuz-${KERNEL_V}" "${BUILD_DIR}/iso/live/vmlinuz"
	cp "${BUILD_DIR}/rootfs/boot/initrd.img-${KERNEL_V}" "${BUILD_DIR}/iso/live/initrd.img"
}

create_grub_cfg() {
	log_info "Criando configuração GRUB..."

	cat >"${BUILD_DIR}/iso/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=10

menuentry "Debian Live (${DEBIAN_RELEASE}) - KDE/Server" {
    linux /live/vmlinuz boot=live components quiet splash username=user hostname=${HOSTNAME} autologin
    initrd /live/initrd.img
}

menuentry "Debian Live (Failsafe)" {
    linux /live/vmlinuz boot=live components memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal
    initrd /live/initrd.img
}
EOF
}

build_iso() {
	log_info "Gerando arquivo ISO..."

	# Criar imagem EFI para boot
	# Necessitamos de um arquivo FAT com EFI/BOOT/BOOTx64.EFI

	mkdir -p "${BUILD_DIR}/efi_tmp/EFI/BOOT"
	# Grub modules standalone
	# Gerar core.efi? Ou usar grub-mkrescue que faz tudo?

	# Vamos usar grub-mkrescue, muito mais simples
	# grub-mkrescue usa o diretório iso como raiz

	# Garantir que o diretório de saída existe
	if [ ! -d "${OUTPUT_DIR}" ]; then
		log_warn "Diretório de saída não encontrado. Recriando: ${OUTPUT_DIR}"
		mkdir -p "${OUTPUT_DIR}"
	fi

	grub-mkrescue -o "${OUTPUT_DIR}/${ISO_NAME}" \
		"${BUILD_DIR}/iso" \
		--modules="linux part_msdos part_gpt iso9660" \
		-V "DEBIAN_LIVE"

	log_ok "ISO GERADA: ${OUTPUT_DIR}/${ISO_NAME}"

	# Calcular Checksum
	cd "${OUTPUT_DIR}"
	sha256sum "${ISO_NAME}" >"${ISO_NAME}.sha256"
	log_info "SHA256: $(cat "${ISO_NAME}.sha256")"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
	if [ "$(id -u)" -ne 0 ]; then
		log_error "Este script precisa rodar como root!"
		exit 1
	fi

	check_deps
	setup_env
	build_rootfs
	configure_rootfs
	pack_rootfs
	create_grub_cfg
	build_iso
}

main "$@"
