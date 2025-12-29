#!/bin/bash
# =============================================================================
# zfs-installer.sh - Automação de Pool e Datasets ZFS para Calamares
# =============================================================================

set -e

# Variáveis enviadas pelo Calamares ou padrões
target_disk=${1:-"/dev/sda"}
pool_name=${2:-"zroot"}
host_name=${3:-"debian-zfs"}

echo "Iniciando preparação ZFS em ${target_disk}..."

# 1. Limpar disco
sgdisk --zap-all "${target_disk}"

# 2. Particionamento (GPT)
# P1: EFI (512MB)
# P2: ZFS (Resto)
sgdisk -n 1:0:+512M -t 1:ef00 "${target_disk}"
sgdisk -n 2:0:0 -t 2:bf01 "${target_disk}"

# Obter nomes das partições
part_efi=$(ls "${target_disk}"* | grep -E "[0-9]$|p[0-9]$" | head -n 1)
part_zfs=$(ls "${target_disk}"* | grep -E "[0-9]$|p[0-9]$" | tail -n 1)

# 3. Criar Pool ZFS compatível com ZFSBootMenu
# Nota: Desabilitamos algumas features que o ZBM pode não suportar em versões antigas, 
# mas no Trixie/ZBM moderno a maioria é OK.
zpool create -f -o ashift=12 \
    -O compression=zstd \
    -O acltype=posixacl \
    -O xattr=sa \
    -O normalization=formD \
    -O relatime=on \
    -O canmount=off \
    -O dnodesize=auto \
    -O mountpoint=none \
    "${pool_name}" "${part_zfs}"

# 4. Criar Hierarquia de Datasets (Layout ZBM)
# O dataset raiz deve ter mountpoint=/ para o ZBM identificar
zfs create -o mountpoint=none "${pool_name}/ROOT"
zfs create -o mountpoint=/ -o canmount=noauto "${pool_name}/ROOT/debian"
zpool set bootfs="${pool_name}/ROOT/debian" "${pool_name}"

# Datasets de dados
zfs create -o mountpoint=/home "${pool_name}/home"
zfs create -o mountpoint=/root "${pool_name}/home/root"
zfs create -o mountpoint=/var -o canmount=off "${pool_name}/var"
zfs create -o mountpoint=/var/log "${pool_name}/var/log"
zfs create -o mountpoint=/var/cache "${pool_name}/var/cache"

# Exportar para o Calamares montar no local correto (/tmp/calamares-root-...)
# O Calamares geralmente cuida da montagem se usarmos o módulo de mount, 
# mas como faremos manual, exportamos agora.
zpool export "${pool_name}"

echo "Pool ZFS e datasets criados com sucesso!"
