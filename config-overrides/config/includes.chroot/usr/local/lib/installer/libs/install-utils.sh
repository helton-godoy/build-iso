#!/usr/bin/env bash
#
# install-utils.sh - Utilitários de instalação (debootstrap, apt, packages)
#

set -euo pipefail

installutils_write_sources_list() {
    local target="$1"
    local suite="$2"
    local mirror="$3"
    local components="$4"
    
    mkdir -p "$target/etc/apt"
    cat > "$target/etc/apt/sources.list" <<EOF
deb $mirror $suite $components
deb $mirror $suite-updates $components
deb http://security.debian.org/debian-security $suite-security $components
EOF
}

installutils_apt_configure_retries() {
    local target="$1"
    local retries="$2"
    local timeout="$3"
    
    mkdir -p "$target/etc/apt/apt.conf.d"
    cat > "$target/etc/apt/apt.conf.d/99retries" <<EOF
Acquire::Retries "$retries";
Acquire::http::Timeout "$timeout";
EOF
}

installutils_write_apt_proxy_conf() {
    local target="$1"
    local proxy="$2"
    
    if [[ -n "$proxy" ]]; then
        echo "Acquire::http::Proxy \"$proxy\";" > "$target/etc/apt/apt.conf.d/01proxy"
    fi
}

installutils_debootstrap_base() {
    local target="$1"
    local suite="$2"
    local mirror="$3"
    local include="$4"
    
    # Verifica se debootstrap está instalado
    if ! command -v debootstrap >/dev/null; then
        stderr "Erro: debootstrap não encontrado."
        return 1
    fi
    
    debootstrap --arch=amd64 --include="$include" "$suite" "$target" "$mirror"
}

installutils_bind_mounts() {
    local target="$1"
    
    mount --bind /dev "$target/dev"
    mount --bind /proc "$target/proc"
    mount --bind /sys "$target/sys"
    mount --bind /run "$target/run" 2>/dev/null || true
}

installutils_install_kernel_and_zfs() {
    local target="$1"
    
    # Atualiza repositórios
    chroot "$target" apt-get update
    
    # Instala headers do kernel, zfs e initramfs
    # ZFS on Linux requer contrib non-free (já configurado em sources.list)
    
    # Instala linux-image-amd64 e linux-headers-amd64
    chroot "$target" apt-get install -y linux-image-amd64 linux-headers-amd64 zfs-dkms zfsutils-linux
    
    # ZFSBootMenu requer que geremos initramfs compatível
    # Mas aqui instalamos apenas o básico. A configuração do ZBM vem depois ou via zbm-install
}

installutils_write_fstab_stub_for_efi() {
    local target="$1"
    local efi_dev="$2"
    local mount_point="$3"
    local uuid
    
    if [[ ! -b "$efi_dev" ]]; then
        uuid="UNKNOWN"
    else
        uuid=$(blkid -s UUID -o value "$efi_dev" 2>/dev/null || echo "UNKNOWN")
    fi
    
    mkdir -p "$target/etc"
    if [[ ! -f "$target/etc/fstab" ]]; then
        echo "# /etc/fstab: static file system information" > "$target/etc/fstab"
    fi
    
    # Adiciona apenas se não existir
    if ! grep -q "$mount_point" "$target/etc/fstab"; then
        echo "UUID=$uuid $mount_point vfat defaults 0 2" >> "$target/etc/fstab"
    fi
}

