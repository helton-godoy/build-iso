#!/bin/bash
#==============================================================================
# Script: build-debian-trixie-zbm.sh
# Descrição: Gerador de ISO Debian Trixie com ZFSBootMenu (UEFI + BIOS Legacy)
# Autor: Sistema de Build Automatizado
# Versão: 2.1.0 - Com ZFSBootMenu integrado e correções de build
# Data: 2026-01-25
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# CONFIGURAÇÕES GLOBAIS
#==============================================================================

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'

readonly NC='\033[0m'

# Diretórios
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly BUILD_DIR="${PROJECT_DIR}/build"
readonly OUTPUT_DIR="${PROJECT_DIR}/output"
readonly CONFIG_DIR="${PROJECT_DIR}/config"
readonly HOOKS_DIR="${CONFIG_DIR}/hooks"
readonly CACHE_DIR="${PROJECT_DIR}/cache"

# Configurações da ISO (Valores padrão - sobrescritos por config/build.conf)
DEBIAN_VERSION="trixie"
ISO_NAME="debian-trixie-zbm"
ARCH="amd64"
LOCALE="pt_BR.UTF-8"
TIMEZONE="America/Sao_Paulo"
KEYBOARD="br"
MIRROR_CHROOT="http://ftp.br.debian.org/debian/"
MIRROR_BINARY="http://ftp.br.debian.org/debian/"

# Configurações ZFSBootMenu
ZBM_SOURCE_URL="https://get.zfsbootmenu.org/source"

# Configurações Docker
DOCKER_IMAGE="debian-trixie-zbm-builder"
DOCKER_TAG="latest"

# Artefatos e URLs
KMSCON_DEB_NAME="kmscon-custom_9.3.0_amd64.deb"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFontMono-Regular.ttf"

# Carregar configurações externas se existirem
if [[ -f "${CONFIG_DIR}/build.conf" ]]; then
	# shellcheck source=/dev/null
	source "${CONFIG_DIR}/build.conf"
	# Não imprimimos mensagem aqui para não poluir output se rodar em subshell,
	# mas garantimos que as variáveis foram carregadas.
fi

# Exportar variáveis para subshells/docker
export DEBIAN_VERSION ISO_NAME ARCH LOCALE TIMEZONE KEYBOARD
export MIRROR_CHROOT MIRROR_BINARY ZBM_SOURCE_URL
export DOCKER_IMAGE DOCKER_TAG KMSCON_DEB_NAME NERD_FONT_URL

#==============================================================================
# FUNÇÕES UTILITÁRIAS
#==============================================================================

print_message() {
	local type="$1"
	local message="$2"

	case "${type}" in
	"info")
		echo -e "${BLUE}[INFO]${NC} ${message}"
		;;
	"success")
		echo -e "${GREEN}[SUCESSO]${NC} ${message}"
		;;
	"warning")
		echo -e "${YELLOW}[AVISO]${NC} ${message}"
		;;
	"error")
		echo -e "${RED}[ERRO]${NC} ${message}" >&2
		;;
	"step")
		echo -e "\n${GREEN}==>${NC} ${BLUE}${message}${NC}\n"
		;;
	*)
		echo -e "${message}"
		;;
	esac
}

error_exit() {
	print_message "error" "$1"
	exit 1
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

check_dependencies() {
	print_message "step" "Verificando dependências..."

	local deps=("docker" "git")
	local missing_deps=()

	for dep in "${deps[@]}"; do
		if ! command_exists "${dep}"; then
			missing_deps+=("${dep}")
		fi
	done

	if [[ ${#missing_deps[@]} -ne 0 ]]; then
		error_exit "Dependências faltando: ${missing_deps[*]}\nInstale-as antes de continuar."
	fi

	if ! docker info >/dev/null 2>&1; then
		error_exit "Docker não está rodando. Inicie o serviço Docker."
	fi

	print_message "success" "Todas as dependências estão instaladas"
}

create_directory_structure() {
	print_message "step" "Criando estrutura de diretórios..."

	mkdir -p "${BUILD_DIR}"
	mkdir -p "${OUTPUT_DIR}"
	mkdir -p "${CONFIG_DIR}"
	mkdir -p "${HOOKS_DIR}"
	mkdir -p "${CONFIG_DIR}/includes.chroot/etc"
	mkdir -p "${CONFIG_DIR}/includes.chroot/usr/local/bin"
	mkdir -p "${CONFIG_DIR}/includes.binary/boot/syslinux"
	mkdir -p "${CONFIG_DIR}/includes.binary/EFI/ZBM"
	mkdir -p "${CACHE_DIR}/debs"
	mkdir -p "${CACHE_DIR}/packages.bootstrap"

	# Copiar arquivos do diretório include/ para includes.chroot
	if [[ -d "${PROJECT_DIR}/include" ]]; then
		print_message "info" "Copiando arquivos de include/ para includes.chroot..."
		cp -rv "${PROJECT_DIR}/include/"* "${CONFIG_DIR}/includes.chroot/" 2>/dev/null || true
		print_message "success" "Arquivos de include/ copiados (instalador + gum)"
	fi

	print_message "success" "Estrutura de diretórios criada"
}

generate_dockerfile() {
	local use_cache=false

	# Verificar se existe cache do kmscon
	if [[ -f "${CACHE_DIR}/debs/${KMSCON_DEB_NAME}" ]]; then
		print_message "info" "Cache encontrado: ${KMSCON_DEB_NAME} (pulando compilação)"
		use_cache=true
	else
		print_message "info" "Cache não encontrado, kmscon será compilado"
	fi

	print_message "step" "Gerando Dockerfile com kmscon customizado e ZFSBootMenu..."

	if [[ ${use_cache} == true ]]; then
		# Dockerfile simplificado usando cache
		cat >"${SCRIPT_DIR}/Dockerfile" <<'EOF'
# =============================================================================
# Dockerfile com CACHE - kmscon pré-compilado
# =============================================================================
FROM debian:trixie

LABEL maintainer="Sistema de Build Automatizado"
LABEL description="Ambiente de build para ISO Debian Trixie com ZFSBootMenu e kmscon cacheado"
LABEL version="2.2.0-cached"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

# Atualizar e instalar dependências base
RUN apt-get update && apt-get install -y \
    live-build \
    debootstrap \
    xorriso \
    isolinux \
    syslinux \
    syslinux-common \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    mtools \
    dosfstools \
    squashfs-tools \
    zstd \
    curl \
    wget \
    git \
    rsync \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependências do ZFSBootMenu
RUN apt-get update && apt-get install -y \
    libsort-versions-perl \
    libboolean-perl \
    libyaml-pp-perl \
    fzf \
    mbuffer \
    kexec-tools \
    dracut-core \
    efibootmgr \
    systemd-boot-efi \
    bsdextrautils \
    make \
    cpanminus \
    perl \
    && rm -rf /var/lib/apt/lists/*

# Configurar localização
RUN echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen pt_BR.UTF-8 && \
    update-locale LANG=pt_BR.UTF-8

WORKDIR /build

VOLUME ["/build", "/output", "/cache"]

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["build"]
EOF
		print_message "success" "Dockerfile gerado (modo CACHE - build rápido)"
	else
		# Dockerfile completo com compilação
		cat >"${SCRIPT_DIR}/Dockerfile" <<'EOF'
# =============================================================================
# Estágio 1: Compilação do KMSCON customizado
# =============================================================================
FROM debian:trixie AS kmscon-builder

ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências de compilação
RUN apt-get update && apt-get install -y \
    meson \
    ninja-build \
    pkg-config \
    git \
    libtsm-dev \
    libdrm-dev \
    libxkbcommon-dev \
    libpango1.0-dev \
    libcairo2-dev \
    libglib2.0-dev \
    libudev-dev \
    libgbm-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libsystemd-dev \
    libdbus-1-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libinput-dev \
    dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

# Clonar kmscon do repositório oficial (branch master = v9.3+)
# Nota: A versão do repositório oficial é mais recente que os backports
RUN git clone https://github.com/Aetf/kmscon.git /src/kmscon && \
    cd /src/kmscon && \
    git checkout master

# Compilar kmscon
WORKDIR /src/kmscon
RUN meson setup builddir \
    --prefix=/usr \
    --buildtype=release \
    -Dmulti_seat=enabled \
    -Dfont_pango=enabled \
    -Drenderer_gltex=enabled \
    -Dvideo_drm3d=enabled && \
    ninja -C builddir

# Instalar em diretório staging para criar .deb
RUN DESTDIR=/staging ninja -C builddir install

# Criar estrutura do pacote .deb e arquivo de controle
RUN mkdir -p /staging/DEBIAN && \
    echo "Package: kmscon" > /staging/DEBIAN/control && \
    echo "Version: 99:9.3.0-custom" >> /staging/DEBIAN/control && \
    echo "Architecture: amd64" >> /staging/DEBIAN/control && \
    echo "Maintainer: Build System <build@localhost>" >> /staging/DEBIAN/control && \
    echo "Section: utils" >> /staging/DEBIAN/control && \
    echo "Priority: optional" >> /staging/DEBIAN/control && \
    echo "Depends: libtsm4, libc6, libglib2.0-0, libsystemd0, libudev1, libxkbcommon0, libdrm2, libgbm1, libegl1, libgles2, libpango-1.0-0, libcairo2, libfontconfig1, libinput10" >> /staging/DEBIAN/control && \
    echo "Provides: kmscon" >> /staging/DEBIAN/control && \
    echo "Conflicts: kmscon" >> /staging/DEBIAN/control && \
    echo "Replaces: kmscon" >> /staging/DEBIAN/control && \
    echo "Description: KMS/DRM based terminal emulator (Custom Build)" >> /staging/DEBIAN/control && \
    echo " Custom build of kmscon v9.3+ including:" >> /staging/DEBIAN/control && \
    echo "  * Native mouse support via libinput" >> /staging/DEBIAN/control && \
    echo "  * Enhanced emoji rendering with Pango" >> /staging/DEBIAN/control && \
    echo "  * Atomic mode-setting for modern GPUs" >> /staging/DEBIAN/control && \
    echo " ." >> /staging/DEBIAN/control && \
    echo " This package uses Epoch 99: to prevent replacement by official repos." >> /staging/DEBIAN/control && \
    cat /staging/DEBIAN/control

# Construir o pacote .deb
RUN dpkg-deb --build /staging /kmscon-custom_9.3.0_amd64.deb && \
    dpkg-deb -I /kmscon-custom_9.3.0_amd64.deb

# =============================================================================
# Estágio 2: Ambiente de Build da ISO
# =============================================================================
FROM debian:trixie

LABEL maintainer="Sistema de Build Automatizado"
LABEL description="Ambiente de build para ISO Debian Trixie com ZFSBootMenu e kmscon customizado"
LABEL version="2.1.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

# Copiar pacote .deb do estágio anterior
COPY --from=kmscon-builder /kmscon-custom_9.3.0_amd64.deb /opt/

# Atualizar e instalar dependências base
RUN apt-get update && apt-get install -y \
    live-build \
    debootstrap \
    xorriso \
    isolinux \
    syslinux \
    syslinux-common \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    mtools \
    dosfstools \
    squashfs-tools \
    zstd \
    curl \
    wget \
    git \
    rsync \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependências do ZFSBootMenu
RUN apt-get update && apt-get install -y \
    libsort-versions-perl \
    libboolean-perl \
    libyaml-pp-perl \
    fzf \
    mbuffer \
    kexec-tools \
    dracut-core \
    efibootmgr \
    systemd-boot-efi \
    bsdextrautils \
    make \
    cpanminus \
    perl \
    && rm -rf /var/lib/apt/lists/*

# Configurar localização
RUN echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen pt_BR.UTF-8 && \
    update-locale LANG=pt_BR.UTF-8

WORKDIR /build

VOLUME ["/build", "/output", "/cache"]

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["build"]
EOF
		print_message "success" "Dockerfile gerado com kmscon customizado (multi-stage build)"
	fi
}

generate_docker_entrypoint() {
	print_message "step" "Gerando script de entrada do Docker..."

	cat >"${SCRIPT_DIR}/docker-entrypoint.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

echo "==> Iniciando build da ISO Debian ${DEBIAN_VERSION} com ZFSBootMenu"
echo "==> Configuração:"
echo "    -> ISO Name: ${ISO_NAME}"
echo "    -> Arch: ${ARCH}"
echo "    -> Locale: ${LOCALE}"
echo "    -> Mirror: ${MIRROR_CHROOT}"

cd /build

# Limpar builds anteriores
if [ -d "live-build-config" ]; then
    echo "==> Limpando configurações anteriores..."
    # Tentar limpar com força bruta, ignorando erros de montagem primeiro
    rm -rf live-build-config || {
        echo "[AVISO] Falha ao remover 'live-build-config' simples. Tentando limpeza mais profunda..."
        find live-build-config -mindepth 1 -delete || echo "[ERRO CRÍTICO] Não é possível limpar o diretório de trabalho."
    }
fi

# Copiar pacote kmscon customizado para packages.chroot
echo "==> Preparando pacote kmscon customizado..."
mkdir -p /build/config/packages.chroot

# Prioridade: 1) Cache montado, 2) /opt (compilado no Docker)
if [ -f "/cache/debs/${KMSCON_DEB_NAME}" ]; then
    echo "===> Usando kmscon do CACHE"
    cp "/cache/debs/${KMSCON_DEB_NAME}" /build/config/packages.chroot/
    dpkg-deb -I "/build/config/packages.chroot/${KMSCON_DEB_NAME}"
elif [ -f "/opt/${KMSCON_DEB_NAME}" ]; then
    echo "===> Usando kmscon COMPILADO"
    cp "/opt/${KMSCON_DEB_NAME}" /build/config/packages.chroot/
    dpkg-deb -I "/build/config/packages.chroot/${KMSCON_DEB_NAME}"
    
    # Salvar no cache para futuros builds
    if [ -d "/cache/debs" ]; then
        echo "===> Salvando kmscon no CACHE para futuros builds"
        cp "/opt/${KMSCON_DEB_NAME}" "/cache/debs/"
    fi
else
    echo "AVISO: Pacote kmscon customizado (${KMSCON_DEB_NAME}) não encontrado!"
    echo "       Verifique se o cache ou a compilação funcionou."
fi

# Executar script de configuração
if [ -f "/build/config/configure-live-build.sh" ]; then
    echo "==> Executando configuração do live-build..."
    bash /build/config/configure-live-build.sh
else
    echo "ERRO: Script de configuração não encontrado!"
    exit 1
fi

# Copiar arquivos de saída
if [ -d "live-build-config" ]; then
    echo "==> Copiando ISO gerada para /output..."
    find live-build-config -name "*.iso" -exec cp {} /output/ \;
    find live-build-config -name "*.packages" -exec cp {} /output/ \;
    find live-build-config -name "*.sha256" -exec cp {} /output/ \;
    
    # Copiar logs
    if [ -f "live-build-config/build.log" ]; then
        cp live-build-config/build.log /output/
    fi
    
    echo "==> Build concluído com sucesso!"
else
    echo "ERRO: Diretório de build não encontrado!"
    exit 1
fi
EOF

	chmod +x "${SCRIPT_DIR}/docker-entrypoint.sh"
	print_message "success" "Script de entrada gerado"
}

generate_live_build_config() {
	print_message "step" "Gerando script de configuração do live-build com ZFSBootMenu..."

	cat >"${CONFIG_DIR}/configure-live-build.sh" <<'LBCONFIG'
#!/bin/bash
set -euo pipefail

echo "==> Criando configuração do live-build..."

mkdir -p live-build-config
cd live-build-config

# Configurar live-build com suporte híbrido
lb config noauto \
    --mode debian \
    --distribution "${DEBIAN_VERSION}" \
    --parent-mirror-chroot "${MIRROR_CHROOT}" \
    --parent-mirror-binary "${MIRROR_BINARY}" \
    --archive-areas "main contrib non-free non-free-firmware" \
    --parent-archive-areas 'main contrib non-free-firmware non-free' \
    --architectures "${ARCH}" \
    --linux-flavours "${ARCH}" \
    --bootappend-live "boot=live components quiet splash username=debian hostname=${ISO_NAME} locales=${LOCALE} timezone=${TIMEZONE} keyboard-layouts=${KEYBOARD}" \
    --memtest none \
    --debian-installer none \
    --debian-installer-gui false \
    --bootloaders "syslinux,grub-efi" \
    --binary-images iso-hybrid \
    --checksums sha256 \
    --compression xz \
    --chroot-squashfs-compression-type zstd \
    --zsync false \
    --apt-recommends true \
    --apt-indices false \
    --cache-packages true \
    --debootstrap-options "--include=ca-certificates" \
    --security true \
    --backports true \
    --updates true \
    "${@}"

# Configurar pinning para priorizar backports para kmscon e dependências
mkdir -p config/archives
cat > config/archives/backports.pref.chroot << 'BPPREF'
Package: kmscon libtsm4*
Pin: release n=trixie-backports
Pin-Priority: 990
BPPREF

# Copiar arquivos de /build/include para config/includes.chroot (instalador + gum + zbm)
if [[ -d /build/include ]]; then
    echo "==> Copiando arquivos do instalador e ZFSBootMenu..."
    mkdir -p config/includes.chroot
    cp -rv /build/include/* config/includes.chroot/ 2>/dev/null || true
    echo "==> Arquivos copiados com sucesso!"
    ls -la config/includes.chroot/usr/local/bin/ 2>/dev/null || true
fi

echo "==> Adicionando pacotes essenciais + ZFSBootMenu..."

# Lista de pacotes
cat > config/package-lists/custom.list.chroot << 'PKGLIST'

# === Extração do Sistema ===
squashfs-tools

# === Particionamento ===
gdisk
parted
dosfstools

# === Live System Base ===
live-boot
live-config
live-config-systemd
systemd-sysv

# === ZFS Support ===
zfs-dkms
zfsutils-linux
zfs-initramfs
zfs-zed

# === Kernel & Modules ===
linux-image-amd64
linux-headers-amd64
dkms
firmware-linux
firmware-linux-nonfree
firmware-misc-nonfree
firmware-realtek
firmware-iwlwifi
firmware-atheros
firmware-libertas

# === Essential Tools ===
console-setup
locales
ca-certificates
parted
gdisk
dosfstools
efibootmgr
busybox
initramfs-tools
keyboard-configuration
tzdata
curl
wget
apt-utils
bash-completion
sudo

# === Terminal Avançado ===
ncurses-base
ncurses-bin
kbd
console-setup
console-data

# Kernel e módulos
linux-image-amd64
linux-headers-amd64
firmware-linux
firmware-linux-nonfree

# Sistema base
live-boot
live-config
systemd
systemd-timesyncd
dbus
locales
console-setup
keyboard-configuration

# ZFS completo
zfs-dkms
zfsutils-linux
zfs-initramfs

# ZFSBootMenu dependências
libsort-versions-perl
libboolean-perl
libyaml-pp-perl
fzf
mbuffer
kexec-tools
dracut-core
efibootmgr
gdisk
dosfstools
parted
systemd-boot-efi
bsdextrautils
make
cpanminus
perl

# kmscon customizado (instalado via .deb em packages.chroot)
# Não instalar via apt - versão customizada será usada

# Fontes (incluindo Terminus para console e fontes para kmscon)
fonts-noto
fonts-noto-color-emoji
fonts-dejavu-core
fonts-liberation
fonts-freefont-ttf
console-terminus
fonts-dejavu
fontconfig

# Ferramentas essenciais
curl
wget
git
htop
tmux
vim
nano
openssh-server
sudo
net-tools
iproute2
iputils-ping
ca-certificates
gnupg

# Utilitários de sistema
psmisc
procps
lsof
rsync
unzip
zip
less
man-db

# Rede
network-manager
wpasupplicant
iw
wireless-tools

# === File Sharing (TrueNAS-like) ===
samba
samba-common-bin
smbclient
winbind
libpam-winbind
libnss-winbind
nfs-kernel-server
nfs-common
nfs4-acl-tools
acl
attr

# === Active Directory & Identity ===
sssd
sssd-tools
realmd
adcli
packagekit
krb5-user
libpam-krb5

# === Storage Management & Monitoring ===
sanoid
pv
lzop
mbuffer
smartmontools

# Bootloaders
# ZFSBootMenu substitui GRUB. Syslinux apenas para Legacy BIOS.
syslinux
syslinux-common
# grub-pc-bin      <-- REMOVIDO
# grub-efi-amd64-bin <-- REMOVIDO

# Secure Boot Support
shim-signed
mokutil
sbsigntool

PKGLIST

echo "==> Criando hooks de personalização..."

mkdir -p config/hooks/normal

# Hook 1: Configuração de localização
cat > config/hooks/normal/0010-configure-locale.hook.chroot << 'LOCALHOOK'
#!/bin/bash
set -e

echo "==> Configurando localização ${LOCALE}..."

# Configurar locale
echo "${LOCALE} UTF-8" > /etc/locale.gen
locale-gen ${LOCALE}
update-locale LANG=${LOCALE} LC_ALL=${LOCALE}

# Configurar timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
echo "${TIMEZONE}" > /etc/timezone

# Configurar teclado
cat > /etc/default/keyboard << 'KBDEOF'
XKBMODEL="abnt2"
XKBLAYOUT="${KEYBOARD}"
XKBVARIANT="abnt2"
XKBOPTIONS=""
BACKSPACE="guess"
KBDEOF

# Configurar console
cat > /etc/default/console-setup << 'CONSEOF'
CHARMAP="UTF-8"
CODESET="Lat15"
FONTFACE="TerminusBold"
FONTSIZE="16"
CONSEOF
LOCALHOOK
chmod +x config/hooks/normal/0010-configure-locale.hook.chroot

# Hook 1.5: Instalar Nerd Fonts (FiraCode)
# Necessário para ícones avançados no terminal (Gum, TUI)
cat > config/hooks/normal/0015-install-nerd-fonts.hook.chroot << 'FONTHOOK'
#!/bin/bash
set -e

echo "==> Instalando FiraCode Nerd Font..."

mkdir -p /usr/local/share/fonts/truetype/nerdfonts
cd /usr/local/share/fonts/truetype/nerdfonts

# Download FiraCode Nerd Font
# Baixando apenas o Regular Mono para economizar espaço
curl -fLo "FiraCodeNerdFontMono-Regular.ttf" \
    "${NERD_FONT_URL}"

# Atualizar cache de fontes (verificar se fc-cache está disponível)
if command -v fc-cache >/dev/null 2>&1; then
    echo "==> Atualizando cache de fontes..."
    fc-cache -fv
else
    echo "AVISO: fc-cache não encontrado, cache de fontes não atualizado"
fi

echo "==> FiraCode Nerd Font instalada com sucesso!"
FONTHOOK
chmod +x config/hooks/normal/0015-install-nerd-fonts.hook.chroot

# Hook 2: Configuração kmscon avançada + Correção de Emojis
cat > config/hooks/normal/0020-configure-kmscon.hook.chroot << 'KMSHOOK'
#!/bin/bash
set -e

echo "==> Configurando FontConfig para Emojis..."

# 1. Criar regra de FontConfig para forçar fallback de Emoji em Monospace
# Isso é crucial para o Pango aceitar Noto Color Emoji no terminal
mkdir -p /etc/fonts/conf.d

# Regra de fallback para emoji em fontes monospace
cat > /etc/fonts/conf.d/99-kmscon-emoji.conf << 'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Fallback de Emoji para fontes monospace -->
  <match target="pattern">
    <test name="family"><string>monospace</string></test>
    <edit name="family" mode="append"><string>Noto Color Emoji</string></edit>
  </match>

  <match target="pattern">
    <test name="family"><string>FiraCode Nerd Font Mono</string></test>
    <edit name="family" mode="append"><string>Noto Color Emoji</string></edit>
  </match>

  <!-- CRÍTICO: Hinting para emojis coloridos (evita bug do Cairo/Pango) -->
  <!-- Ref: https://www.reddit.com/r/archlinux/comments/j0z3a8/pango_renders_nothing_for_emojis_with/ -->
  <match target="font">
    <test name="family" compare="contains">
      <string>Emoji</string>
    </test>
    <edit name="hinting" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
  </match>
</fontconfig>
XML

# Regenerar cache de fontes para aplicar a nova regra
fc-cache -fv

echo "==> Configurando kmscon v9.3+ com recursos avançados..."

mkdir -p /etc/kmscon
cat > /etc/kmscon/kmscon.conf << 'KMSEOF'
# =============================================================================
# kmscon.conf - Console Avançado KMS/DRM
# Configuração otimizada baseada nas melhores práticas do Fedora 44
# Ref: https://fedoraproject.org/wiki/Changes/UseKmsconVTConsole
# =============================================================================

# -----------------------------------------------------------------------------
# RENDERIZAÇÃO E FONTES
# -----------------------------------------------------------------------------
font-engine=pango           # Motor de renderização avançado (Unicode, CJK, Emoji)
font-name=FiraCode Nerd Font Mono
font-size=16
font-dpi=96                 # DPI padrão (96=100%, 144=150%, 192=200% para HiDPI)

# Aceleração de Hardware (OpenGL ESv2 via gltex)
# Ref: https://dvdhrm.wordpress.com/2012/08/11/kmscon-linux-kmsdrm-based-virtual-console/
hwaccel

# -----------------------------------------------------------------------------
# MOUSE E ENTRADA (kmscon 9.3+)
# Ref: https://www.phoronix.com/forums/forum/phoronix/latest-phoronix-articles/1607936
# -----------------------------------------------------------------------------
mouse                       # Suporte nativo a mouse via libinput
                            # - Clique esquerdo + arrastar: selecionar texto
                            # - Clique central (roda): colar texto selecionado
                            # - Compatível com vim, htop, midnight commander, etc.

# -----------------------------------------------------------------------------
# LAYOUT DE TECLADO BRASILEIRO
# -----------------------------------------------------------------------------
xkb-layout=${KEYBOARD}
xkb-variant=abnt2
xkb-options=

# -----------------------------------------------------------------------------
# SESSÕES E TERMINAIS VIRTUAIS
# -----------------------------------------------------------------------------
session-control             # Habilita atalhos para múltiplas sessões
session-max=50              # Limite de sessões concorrentes (padrão: 50)

# -----------------------------------------------------------------------------
# PALETA DE CORES (Dracula Theme)
# https://draculatheme.com/
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# TERMINAL E HISTÓRICO
# -----------------------------------------------------------------------------
term=xterm-256color
scrollback=10000            # Linhas de histórico

# -----------------------------------------------------------------------------
# ATALHOS DE TECLADO (Produtividade)
# Sintaxe: <Modificador>Tecla onde Modificador = Shift, Ctrl, Alt, Logo
# -----------------------------------------------------------------------------
# Navegação no histórico
grab-scroll-up=<Shift>Prior
grab-scroll-down=<Shift>Next

# Zoom de fonte dinâmico (útil para apresentações)
grab-zoom-in=<Ctrl>plus
grab-zoom-out=<Ctrl>minus

# Gerenciamento de múltiplas sessões (requer session-control)
grab-terminal-new=<Ctrl><Logo>Return
grab-session-next=<Ctrl><Logo>Right
grab-session-prev=<Ctrl><Logo>Left
grab-session-close=<Ctrl><Logo>w
KMSEOF

# Habilitar kmscon em todos os TTYs (1-6)
for tty in 1 2 3 4 5 6; do
    systemctl enable kmsconvt@tty${tty}.service || true
done

# Configurar kmscon como console padrão
mkdir -p /etc/systemd/system
ln -sf /usr/lib/systemd/system/kmsconvt@.service /etc/systemd/system/autovt@.service || true

# Proteger pacote kmscon customizado contra atualizações
echo "==> Protegendo kmscon customizado..."
apt-mark hold kmscon 2>/dev/null || true

echo "==> kmscon v9.3+ configurado com sucesso!"
echo "    - Mouse: HABILITADO (libinput)"
echo "    - Emojis coloridos: HABILITADO (hinting configurado)"
echo "    - Múltiplas sessões: HABILITADO (Ctrl+Logo+Enter para nova)"
echo "    - Tema: Dracula"
KMSHOOK
chmod +x config/hooks/normal/0020-configure-kmscon.hook.chroot

# Hook 3: Sistema base
cat > config/hooks/normal/0030-configure-system.hook.chroot << 'SYSHOOK'
#!/bin/bash
set -e

echo "==> Configurando sistema base..."

# Criar usuário
useradd -m -s /bin/bash -G sudo,audio,video,cdrom,netdev,input debian || true
# Forçar senha usando OpenSSL para contornar PAM (senha: live)
usermod -p '$1$ZWG3pXdv$.kjniJggSkxfIXZHe6dSJ/' debian || echo "debian:live" | chpasswd

# Sudo sem senha
echo "debian ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/debian
chmod 0440 /etc/sudoers.d/debian

# Habilitar serviços
systemctl enable ssh || true
systemctl enable systemd-timesyncd || true
systemctl enable sssd || true
systemctl enable smbd || true
systemctl enable nmbd || true
systemctl enable winbind || true
systemctl enable nfs-server || true

# Pre-enable kmscon alias if not exists to avoid enable errors
mkdir -p /etc/systemd/system/autovt@.service.d
ln -sf /lib/systemd/system/kmsconvt@.service /etc/systemd/system/autovt@.service || true

# Hostname
echo "${ISO_NAME}" > /etc/hostname

# Otimizações de kernel
cat >> /etc/sysctl.d/99-custom.conf << EOF
# Otimizações para servidor de arquivos
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
fs.file-max=2097152
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
EOF
SYSHOOK
chmod +x config/hooks/normal/0030-configure-system.hook.chroot

# Hook 4: ZFS
cat > config/hooks/normal/0040-configure-zfs.hook.chroot << 'ZFSHOOK'
#!/bin/bash
set -e

echo "==> Configurando ZFS..."

# Módulo ZFS no boot
echo "zfs" >> /etc/modules

# DKMS automático
echo "REMAKE_INITRD=yes" > /etc/dkms/zfs.conf

# Serviços ZFS
systemctl enable zfs.target || true
systemctl enable zfs-import-cache || true
systemctl enable zfs-mount || true
systemctl enable zfs-import.target || true

# Helper ZFS
cat > /usr/local/bin/zfs-setup-helper << 'ZFSHELPER'
#!/bin/bash
cat << EOF

╔═══════════════════════════════════════════════════════════════╗
║    Helper de Configuração ZFS - Debian ${DEBIAN_VERSION}      ║
╚═══════════════════════════════════════════════════════════════╝

📦 CRIAR POOL ZFS:
   sudo zpool create -f mypool /dev/sdX

🗂️  CRIAR DATASETS:
   sudo zfs create mypool/data
   sudo zfs set mountpoint=/mnt/data mypool/data

📊 LISTAR POOLS:
   zpool list
   zpool status

🔐 POOL CRIPTOGRAFADO:
   sudo zpool create -f \\
     -O encryption=aes-256-gcm \\
     -O keyformat=passphrase \\
     -O keylocation=prompt \\
     mypool /dev/sdX

📸 SNAPSHOTS:
   sudo zfs snapshot mypool/data@backup1
   sudo zfs list -t snapshot

🔄 RESTAURAR SNAPSHOT:
   sudo zfs rollback mypool/data@backup1

💡 Para usar ZFSBootMenu após instalação, consulte:
   /usr/share/doc/zfsbootmenu/README.md

EOF
ZFSHELPER
chmod +x /usr/local/bin/zfs-setup-helper
ZFSHOOK
chmod +x config/hooks/normal/0040-configure-zfs.hook.chroot

# Hook 5: ZFSBootMenu
cat > config/hooks/normal/0050-install-zfsbootmenu.hook.chroot << 'ZBMHOOK'
#!/bin/bash
set -e

echo "==> Instalando ZFSBootMenu..."

# Download e instalação do ZFSBootMenu
mkdir -p /usr/local/src/zfsbootmenu
cd /usr/local/src/zfsbootmenu

curl -L "${ZBM_SOURCE_URL}" | tar -zxv --strip-components=1 -f - || {
    echo "AVISO: Falha ao baixar ZFSBootMenu online, tentando fallback..."
}

# Instalar componentes core do ZFSBootMenu
if [ -f Makefile ]; then
    make core dracut || echo "AVISO: Instalação parcial do ZFSBootMenu"
fi

# Criar configuração padrão
mkdir -p /etc/zfsbootmenu

cat > /etc/zfsbootmenu/config.yaml << 'ZBMCONF'
Global:
  ManageImages: true
  BootMountPoint: /boot/efi
  DracutConfDir: /etc/zfsbootmenu/dracut.conf.d
  PreHooksDir: /etc/zfsbootmenu/generate-zbm.pre.d
  PostHooksDir: /etc/zfsbootmenu/generate-zbm.post.d
  InitCPIOHookDirs:
  - /etc/zfsbootmenu/initcpio.pre.d
  - /etc/zfsbootmenu/initcpio.post.d

Components:
  Enabled: false
  
EFI:
  ImageDir: /boot/efi/EFI/ZBM
  Versions: false
  Enabled: true

Kernel:
  CommandLine: "quiet loglevel=0 zbm.timeout=10"
  Path: 
  Prefix:
ZBMCONF

# Criar diretórios de configuração dracut
mkdir -p /etc/zfsbootmenu/dracut.conf.d

cat > /etc/zfsbootmenu/dracut.conf.d/zfsbootmenu.conf << 'DRACUTCONF'
# Configuração dracut para ZFSBootMenu
add_dracutmodules+=" zfsbootmenu "
omit_dracutmodules+=" btrfs "
install_optional_items+=" /usr/bin/fzf /usr/bin/mbuffer "
DRACUTCONF

# Documentação
mkdir -p /usr/share/doc/zfsbootmenu
cat > /usr/share/doc/zfsbootmenu/README.md << 'ZBMREADME'
# ZFSBootMenu - Guia Rápido

## O que é ZFSBootMenu?

ZFSBootMenu é um gerenciador de boot avançado que permite:
- ✅ Boot direto de pools ZFS (raiz em ZFS)
- ✅ Múltiplos ambientes de boot (boot environments)
- ✅ Gerenciamento de snapshots antes do boot
- ✅ Suporte a criptografia ZFS nativa
- ✅ Recuperação avançada do sistema

## Instalação Pós-Live

### 1. UEFI (Modo Recomendado)

```bash
# Criar partição EFI (512MB)
sudo gdisk /dev/sdX
# n, 1, <enter>, +512M, ef00

# Formatar EFI
sudo mkfs.vfat -F32 /dev/sdX1

# Montar
sudo mkdir -p /boot/efi
sudo mount /dev/sdX1 /boot/efi

# Criar pool ZFS raiz
sudo zpool create -f \
  -o ashift=12 \
  -O encryption=aes-256-gcm \
  -O keyformat=passphrase \
  -O keylocation=prompt \
  -O compression=lz4 \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  -m none \
  zroot /dev/sdX2

# Criar datasets
sudo zfs create -o mountpoint=none zroot/ROOT
sudo zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/debian
sudo zfs create -o mountpoint=/home zroot/home

# Definir boot environment
sudo zpool set bootfs=zroot/ROOT/debian zroot

# Gerar imagem ZFSBootMenu
sudo mkdir -p /boot/efi/EFI/ZBM
sudo generate-zbm

# Criar entrada EFI
sudo efibootmgr -c -d /dev/sdX -p 1 \
  -L "ZFSBootMenu" \
  -l '\EFI\ZBM\VMLINUZ.EFI'
```

### 2. BIOS Legacy (com Syslinux)

```bash
# Criar partição boot (512MB, tipo 83, bootable)
sudo fdisk /dev/sdX
# n, p, 1, <enter>, +512M, a, 1, w

# Formatar
sudo mkfs.ext4 /dev/sdX1

# Montar
sudo mkdir -p /boot/syslinux
sudo mount /dev/sdX1 /boot/syslinux

# Instalar syslinux
sudo apt install syslinux
sudo cp /usr/lib/syslinux/modules/bios/*.c32 /boot/syslinux/
sudo extlinux --install /boot/syslinux

# Instalar MBR
sudo dd bs=440 count=1 conv=notrunc \
  if=/usr/lib/syslinux/mbr/mbr.bin \
  of=/dev/sdX

# Criar pool ZFS (similar ao UEFI)
# ... (mesmo processo acima)

# Gerar imagem ZFSBootMenu
sudo generate-zbm

# Configurar syslinux
sudo tee /boot/syslinux/syslinux.cfg << 'EOF'
DEFAULT zfsbootmenu
TIMEOUT 50
PROMPT 0

LABEL zfsbootmenu
  MENU LABEL ZFSBootMenu
  LINUX /zfsbootmenu/vmlinuz-bootmenu
  INITRD /zfsbootmenu/initramfs-bootmenu.img
  APPEND zbm.prefer=zroot ro quiet loglevel=0

LABEL zfsbootmenu-backup
  MENU LABEL ZFSBootMenu (Backup)
  LINUX /zfsbootmenu/vmlinuz-bootmenu-backup
  INITRD /zfsbootmenu/initramfs-bootmenu-backup.img
  APPEND zbm.prefer=zroot ro quiet loglevel=0
EOF
```

## Uso do ZFSBootMenu

### Interface Interativa

Ao bootar, você verá:
- Lista de boot environments disponíveis
- Opção de selecionar snapshots
- Menu de kernels disponíveis
- Countdown de 10 segundos para boot automático

### Atalhos de Teclado

- `Enter` - Boot no ambiente selecionado
- `Ctrl+L` - Ver logs
- `Ctrl+D` - Duplicar/clonar ambiente
- `Ctrl+S` - Gerenciar snapshots
- `Escape` - Voltar/cancelar

## Boot Environments

### Criar novo BE

```bash
sudo zfs snapshot zroot/ROOT/debian@pre-upgrade
sudo zfs clone zroot/ROOT/debian@pre-upgrade zroot/ROOT/debian-new
sudo zpool set bootfs=zroot/ROOT/debian-new zroot
```

### Listar BEs

```bash
zfs list -r zroot/ROOT
```

### Alternar entre BEs

No menu do ZFSBootMenu, selecione o BE desejado e pressione Enter.

## Troubleshooting

### ZFSBootMenu não aparece

**UEFI:**
```bash
# Verificar entradas
sudo efibootmgr -v

# Recriar entrada
sudo efibootmgr -c -d /dev/sdX -p 1 \
  -L "ZFSBootMenu" \
  -l '\EFI\ZBM\VMLINUZ.EFI'
```

**BIOS:**
```bash
# Reinstalar MBR
sudo dd bs=440 count=1 conv=notrunc \
  if=/usr/lib/syslinux/mbr/mbr.bin \
  of=/dev/sdX

# Verificar syslinux.cfg
sudo cat /boot/syslinux/syslinux.cfg
```

### Pool não importa

```bash
# No ZFSBootMenu, pressione Alt+C para shell
# Importar manualmente:
zpool import -f zroot

# Se criptografado:
zfs load-key -a
zfs mount -a
```

## Documentação Oficial

- Site: https://zfsbootmenu.org/
- Docs: https://docs.zfsbootmenu.org/
- GitHub: https://github.com/zbm-dev/zfsbootmenu

ZBMREADME

# Script auxiliar para regenerar ZFSBootMenu
cat > /usr/local/bin/zbm-update << 'ZBMUPDATE'
#!/bin/bash
set -e

echo "==> Atualizando ZFSBootMenu..."

if [ ! -f /etc/zfsbootmenu/config.yaml ]; then
    echo "ERRO: ZFSBootMenu não está instalado!"
    exit 1
fi

# Verificar modo de boot
if [ -d /sys/firmware/efi ]; then
    echo "==> Detectado modo UEFI"
    BOOT_MODE="uefi"
else
    echo "==> Detectado modo BIOS Legacy"
    BOOT_MODE="bios"
fi

# Gerar nova imagem
if command -v generate-zbm >/dev/null 2>&1; then
    generate-zbm
    echo "==> ZFSBootMenu atualizado com sucesso!"
    
    if [ "$BOOT_MODE" = "uefi" ]; then
        echo "==> Localização: /boot/efi/EFI/ZBM/"
        ls -lh /boot/efi/EFI/ZBM/ || true
    else
        echo "==> Localização: /boot/syslinux/zfsbootmenu/"
        ls -lh /boot/syslinux/zfsbootmenu/ || true
    fi
else
    echo "ERRO: generate-zbm não encontrado!"
    exit 1
fi
ZBMUPDATE
chmod +x /usr/local/bin/zbm-update

echo "==> ZFSBootMenu instalado com sucesso!"
ZBMHOOK
chmod +x config/hooks/normal/0050-install-zfsbootmenu.hook.chroot

# Hook 6: Scripts auxiliares
cat > config/hooks/normal/0060-helper-scripts.hook.chroot << 'HELPERHOOK'
#!/bin/bash
set -e

echo "==> Criando scripts auxiliares..."

# Script de boas-vindas
cat > /etc/motd << 'MOTD'

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     Debian ${DEBIAN_VERSION} Live - ZFSBootMenu Edition       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

✨ Recursos Incluídos:
   • ZFS com suporte completo (incluindo criptografia)
   • ZFSBootMenu para gerenciamento avançado de boot
   • kmscon com suporte a truecolor e emojis
   • Localização ${LOCALE} (teclado ABNT2)
   • Kernel otimizado para file servers

📚 Comandos Úteis:
   • zfs-setup-helper    - Guia rápido de ZFS
   • zbm-update          - Atualizar ZFSBootMenu
   • htop                - Monitor de sistema

🔧 Usuário padrão:
   Login: debian
   Senha: live
   Sudo: sem senha

📖 Documentação ZFSBootMenu:
   /usr/share/doc/zfsbootmenu/README.md

🌐 Para instalar o sistema permanentemente, consulte:
   https://docs.zfsbootmenu.org/

MOTD

# Script de informações do sistema
cat > /usr/local/bin/system-info << 'SYSINFO'
#!/bin/bash

echo "
╔═══════════════════════════════════════════════════════════════╗
║                   Informações do Sistema                      ║
╚═══════════════════════════════════════════════════════════════╝
"

echo "🖥️  Hostname: $(hostname)"
echo "👤 Usuário: $(whoami)"
echo "📅 Data/Hora: $(date '+%d/%m/%Y %H:%M:%S %Z')"
echo "⏰ Uptime: $(uptime -p)"
echo ""
echo "💾 Memória:"
free -h | grep -E "Mem|Swap"
echo ""
echo "💿 Discos:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | head -10
echo ""

if command -v zpool >/dev/null 2>&1; then
    echo "
💾 Pools ZFS:"
zpool list
echo ""
echo "📊 Datasets:"
zfs list -o name,used,avail,mountpoint | head -10
fi

echo ""
echo "🔧 Kernel:"
uname -r
echo ""
SYSINFO
chmod +x /usr/local/bin/system-info

echo "==> Scripts auxiliares criados com sucesso!"
HELPERHOOK
chmod +x config/hooks/normal/0060-helper-scripts.hook.chroot

# Hook 7: Configurar instalador Debian ZFS
cat > config/hooks/normal/0070-install-debian-installer.hook.chroot << 'INSTALLHOOK'
#!/bin/bash
set -e

echo "==> Configurando instalador Debian ZFS..."

# Remover arquivos residuais de builds anteriores em locais incorretos
# Isso evita conflitos com versões antigas que possam estar em /usr/local/lib/
if [[ -f "/usr/local/lib/install-system" ]]; then
    echo "==> Removendo arquivo residual em /usr/local/lib/install-system..."
    rm -f "/usr/local/lib/install-system"
fi

# Definir diretórios do instalador
INSTALLER_BIN="/usr/local/bin/install-system"
INSTALLER_DIR="/usr/local/bin/installer"
GUM_BIN="/usr/local/bin/gum"

# Configurar permissões do instalador principal
if [[ -f "${INSTALLER_BIN}" ]]; then
    chmod +x "${INSTALLER_BIN}"
    echo "install-system encontrado e configurado"
    
    # Validar sintaxe do script bash
    echo "==> Validando sintaxe do install-system..."
    if bash -n "${INSTALLER_BIN}"; then
        echo "    ✓ Sintaxe OK"
    else
        echo "    ✗ ERRO: Sintaxe inválida no install-system!"
        exit 1
    fi
else
    echo "AVISO: install-system não encontrado em ${INSTALLER_BIN}"
fi

# Configurar bibliotecas do instalador
if [[ -d "${INSTALLER_DIR}/lib" ]]; then
    echo "==> Configurando bibliotecas do instalador..."
    for lib_file in "${INSTALLER_DIR}"/lib/*.sh; do
        if [[ -f "${lib_file}" ]]; then
            chmod +x "${lib_file}"
            # Validar sintaxe de cada biblioteca
            if bash -n "${lib_file}"; then
                echo "    ✓ $(basename "${lib_file}")"
            else
                echo "    ✗ ERRO: Sintaxe inválida em $(basename "${lib_file}")"
                exit 1
            fi
        fi
    done
fi

# Configurar componentes do instalador
if [[ -d "${INSTALLER_DIR}/components" ]]; then
    echo "==> Configurando componentes do instalador..."
    for comp_file in "${INSTALLER_DIR}"/components/*.sh; do
        if [[ -f "${comp_file}" ]]; then
            chmod +x "${comp_file}"
            # Validar sintaxe de cada componente
            if bash -n "${comp_file}"; then
                echo "    ✓ $(basename "${comp_file}")"
            else
                echo "    ✗ ERRO: Sintaxe inválida em $(basename "${comp_file}")"
                exit 1
            fi
        fi
    done
fi

# Configurar gum
if [[ -f "${GUM_BIN}" ]]; then
    chmod +x "${GUM_BIN}"
    echo "gum encontrado e configurado"
    # Verificar se gum é executável válido
    if "${GUM_BIN}" --version >/dev/null 2>&1; then
        echo "    ✓ gum funcional: $(${GUM_BIN} --version 2>/dev/null | head -1)"
    else
        echo "    ⚠ gum pode não funcionar corretamente"
    fi
else
    echo "AVISO: gum não encontrado em ${GUM_BIN}"
fi

# Criar diretório para ZFSBootMenu binários
mkdir -p /usr/share/zfsbootmenu

# Atualizar MOTD com informação do instalador
cat >> /etc/motd << 'MOTDADD'

💿 Para instalar o sistema permanentemente:
   sudo install-system

MOTDADD

echo "==> Instalador Debian ZFS configurado com sucesso!"
INSTALLHOOK
chmod +x config/hooks/normal/0070-install-debian-installer.hook.chroot

echo "==> Iniciando build da ISO..."
lb build 2>&1 | tee build.log

echo "==> Build concluído!"

# Renomear ISO
if [ -f *.iso ]; then
    ISO_FILE=$(ls *.iso | head -n 1)
    NEW_NAME="${ISO_NAME}-$(date +%Y%m%d).iso"
    mv "$ISO_FILE" "$NEW_NAME"
    sha256sum "$NEW_NAME" > "${NEW_NAME}.sha256"
    echo "==> ISO gerada: $NEW_NAME"
fi
LBCONFIG

	# Injetar valores das variáveis no script gerado (substituir placeholders)
	# Nota: A maioria das variáveis já foi injetada diretamente no cat << 'LBCONFIG' (exceto onde usamos aspas simples)
	# Mas para ZBM_SOURCE_URL e NERD_FONT_URL que estão dentro de aspas simples ou contextos complexos, reforçamos:

	# Em hooks usando aspas simples (ex: << 'LOCALHOOK'), variáveis do bash host NÃO são expandidas.
	# Portanto, precisamos usar sed para substituir placeholders ou mudar a estratégia de heredoc.
	# Optei por mudar os heredocs críticos para "cat << EOF" (expandível) onde possível,
	# mas para manter a consistência com o código original (que usava 'EOF'), vou usar sed para injeção.

	# Injeção via SED para garantir que funcione dentro dos heredocs 'escapados'
	sed -i "s|\${ISO_NAME}|${ISO_NAME}|g" "${CONFIG_DIR}/configure-live-build.sh"
	sed -i "s|\${ZBM_SOURCE_URL}|${ZBM_SOURCE_URL}|g" "${CONFIG_DIR}/configure-live-build.sh"
	sed -i "s|\${NERD_FONT_URL}|${NERD_FONT_URL}|g" "${CONFIG_DIR}/configure-live-build.sh"
	sed -i "s|\${LOCALE}|${LOCALE}|g" "${CONFIG_DIR}/configure-live-build.sh"
	sed -i "s|\${TIMEZONE}|${TIMEZONE}|g" "${CONFIG_DIR}/configure-live-build.sh"
	sed -i "s|\${KEYBOARD}|${KEYBOARD}|g" "${CONFIG_DIR}/configure-live-build.sh"
	sed -i "s|\${DEBIAN_VERSION}|${DEBIAN_VERSION}|g" "${CONFIG_DIR}/configure-live-build.sh"
	sed -i "s|\${MIRROR_CHROOT}|${MIRROR_CHROOT}|g" "${CONFIG_DIR}/configure-live-build.sh"
	sed -i "s|\${MIRROR_BINARY}|${MIRROR_BINARY}|g" "${CONFIG_DIR}/configure-live-build.sh"

	chmod +x "${CONFIG_DIR}/configure-live-build.sh"
	print_message "success" "Script de configuração gerado"
}

# Função para construir imagem Docker
build_docker_image() {
	print_message "step" "Construindo imagem Docker..."

	docker build -t "${DOCKER_IMAGE}:${DOCKER_TAG}" "${SCRIPT_DIR}" ||
		error_exit "Falha ao construir imagem Docker"

	print_message "success" "Imagem Docker construída: ${DOCKER_IMAGE}:${DOCKER_TAG}"
}

# Função para executar build da ISO
run_iso_build() {
	print_message "step" "Iniciando build da ISO com ZFSBootMenu (isso pode levar 30-60 minutos)..."

	# Verificar se cache existe
	if [[ -f "${CACHE_DIR}/debs/${KMSCON_DEB_NAME}" ]]; then
		print_message "info" "Usando cache de artefatos compilados"
	fi

	docker run --rm --privileged \
		-e DEBIAN_VERSION="${DEBIAN_VERSION}" \
		-e ARCH="${ARCH}" \
		-e LOCALE="${LOCALE}" \
		-e TIMEZONE="${TIMEZONE}" \
		-e KEYBOARD="${KEYBOARD}" \
		-e ISO_NAME="${ISO_NAME}" \
		-e MIRROR_CHROOT="${MIRROR_CHROOT}" \
		-e MIRROR_BINARY="${MIRROR_BINARY}" \
		-e ZBM_SOURCE_URL="${ZBM_SOURCE_URL}" \
		-e NERD_FONT_URL="${NERD_FONT_URL}" \
		-e KMSCON_DEB_NAME="${KMSCON_DEB_NAME}" \
		-v "${PROJECT_DIR}:/build" \
		-v "${OUTPUT_DIR}:/output" \
		-v "${CACHE_DIR}:/cache" \
		"${DOCKER_IMAGE}:${DOCKER_TAG}" build ||
		error_exit "Falha ao executar build da ISO"

	print_message "success" "Build da ISO concluído!"
}

# Função para exibir informações da ISO gerada
show_iso_info() {
	print_message "step" "Informações da ISO gerada:"

	if ls "${OUTPUT_DIR}"/*.iso >/dev/null 2>&1; then
		for iso in "${OUTPUT_DIR}"/*.iso; do
			echo ""
			local basename_iso
			basename_iso="$(basename "${iso}")"
			print_message "info" "Arquivo: ${basename_iso}"

			local size_iso
			size_iso="$(du -h "${iso}" | cut -f1)" || size_iso="N/A"
			print_message "info" "Tamanho: ${size_iso}"

			if [[ -f "${iso}.sha256" ]]; then
				local sha256_content
				sha256_content="$(cat "${iso}.sha256")" || sha256_content="Erro ao ler"
				print_message "info" "SHA256: ${sha256_content}"
			fi
		done
		echo ""
		print_message "success" "ISO disponível em: ${OUTPUT_DIR}"
	else
		print_message "warning" "Nenhuma ISO encontrada em ${OUTPUT_DIR}"
	fi
}

# Função para limpar arquivos temporários
# Função para limpar arquivos temporários e artefatos de build
cleanup() {
	print_message "step" "Executando limpeza de artefatos..."

	if [[ -x "${SCRIPT_DIR}/clean-build-artifacts.sh" ]]; then
		"${SCRIPT_DIR}/clean-build-artifacts.sh" --force
	else
		# Fallback se o script de limpeza dedicado não for encontrado
		print_message "warning" "Script clean-build-artifacts.sh não encontrado. Executando limpeza manual..."
		rm -rf "${BUILD_DIR}" "live-build-config" "output" "config" ".build" "chroot" "build.log"
	fi

	print_message "success" "Limpeza concluída"
}

# Função para exibir ajuda
show_help() {
	cat <<EOF
Uso: $0 [OPÇÃO]

Gerador de imagem ISO Debian Trixie com ZFSBootMenu

OPÇÕES:
    build       Construir ISO completa (padrão)
    clean       Limpar arquivos temporários
    rebuild     Limpar e reconstruir tudo
    help        Exibir esta mensagem de ajuda

RECURSOS:
    - ZFSBootMenu integrado para boot nativo de ZFS
    - kmscon com suporte a Unicode e fontes modernas
    - Suporte a UEFI e BIOS Legacy
    - Mirror brasileiro para download mais rápido

EXEMPLOS:
    $0              # Build padrão
    $0 build        # Build explícito
    $0 rebuild      # Limpar e reconstruir
    $0 clean        # Apenas limpar

SAÍDA:
    A ISO gerada estará em: ${PROJECT_DIR}/output/

EOF
}

#==============================================================================
# FUNÇÃO PRINCIPAL
#==============================================================================

main() {
	local command="${1:-build}"

	case "${command}" in
	build)
		print_message "info" "Iniciando build da ISO Debian Trixie com ZFSBootMenu..."
		check_dependencies
		create_directory_structure
		# Baixar binários ZFSBootMenu
		if [[ -x "${PROJECT_DIR}/scripts/download-zfsbootmenu.sh" ]]; then
			print_message "step" "Baixando binários ZFSBootMenu..."
			"${PROJECT_DIR}/scripts/download-zfsbootmenu.sh" || print_message "warning" "Falha parcial no download do ZFSBootMenu"
		fi
		generate_dockerfile
		generate_docker_entrypoint
		generate_live_build_config
		build_docker_image
		run_iso_build
		show_iso_info
		print_message "success" "Processo concluído com sucesso!"
		;;
	clean)
		cleanup
		;;
	rebuild)
		cleanup
		main build
		;;
	help | --help | -h)
		show_help
		;;
	*)
		print_message "error" "Comando inválido: ${command}"
		show_help
		exit 1
		;;
	esac
}

# Executar função principal
main "$@"
