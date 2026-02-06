#!/usr/bin/env bash
#
# post-utils.sh - Utilitários pós-instalação
#

set -euo pipefail

finalize_chroot_setup() {
    local target="$1"
    
    # Executa configurações finais no chroot
    # Ex: update-initramfs, grub-install (se houver), zbm configuration
    
    # Atualiza initramfs
    chroot "$target" update-initramfs -u -k all
}

setup_zbm_config() {
    local target="$1"
    local pool="$2"
    
    # Gera /etc/zfs/zfs-list.cache/pool se necessário
    # Configura menu.lst do ZBM se usar hooks customizados
    :
}
