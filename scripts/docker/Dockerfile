FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# 1. Provisionamento de ferramentas e suporte a locales
RUN apt-get update && apt-get install -y --no-install-recommends \
    live-build \
    live-config \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-common \
    grub-efi-amd64-bin \
    grub-pc-bin \
    mtools \
    dosfstools \
    zstd \
    build-essential \
    dkms \
    linux-headers-amd64 \
    locales \
    git \
    curl \
    ca-certificates \
    rsync \
    && echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen pt_BR.UTF-8 \
    && update-locale LANG=pt_BR.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

WORKDIR /work

