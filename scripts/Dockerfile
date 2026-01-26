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
