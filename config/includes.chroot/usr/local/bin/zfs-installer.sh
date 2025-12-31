#!/bin/bash
# =============================================================================
# zfs-installer.sh - Automação de Pool e Datasets ZFS para Calamares
# =============================================================================

set -e

# Variáveis enviadas pelo Calamares ou padrões
target_disk=${1:-"/dev/sda"}
mount_point=${2:-"/tmp/calamares-root"}
pool_name=${3:-"zroot"}

# Detecção automática de fallback se o disco informado não existir
if [[ ! -b ${target_disk} ]]; then
	echo "Aviso: ${target_disk} não encontrado. Tentando detectar disco disponível..."
	# Tenta detectar vda, sda, nvme0n1 (excluindo loop, sr, ram)
	DETECTED_DISK=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" && $1!~/^(loop|sr|ram)/ {print "/dev/"$1}' | head -n 1)
	if [[ -n ${DETECTED_DISK} ]]; then
		echo "Disco detectado: ${DETECTED_DISK}"
		target_disk="${DETECTED_DISK}"
	else
		echo "Erro: Nenhum disco válido encontrado!"
		exit 1
	fi
fi

echo "Iniciando preparação ZFS em ${target_disk}..."

# 1. Limpar disco
sgdisk --zap-all "${target_disk}"

# 2. Particionamento (GPT)
# P1: EFI (512MB)
# P2: ZFS (Resto)
sgdisk -n 1:0:+512M -t 1:ef00 "${target_disk}"
sgdisk -n 2:0:0 -t 2:bf01 "${target_disk}"

# Notificar kernel
partprobe "${target_disk}" || true
sleep 2

# Obter nomes das partições robustamente
# Detecta sufixo 'p' para nvme/mmc
if [[ ${target_disk} =~ nvme|mmcblk|loop ]]; then
	part_efi="${target_disk}p1"
	part_zfs="${target_disk}p2"
else
	part_efi="${target_disk}1"
	part_zfs="${target_disk}2"
fi

# Salvar informações para zbm-config.sh
echo "TARGET_DISK=${target_disk}" >/tmp/zfs_install_info
echo "EFI_PART=${part_efi}" >>/tmp/zfs_install_info
echo "ZFS_PART=${part_zfs}" >>/tmp/zfs_install_info

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
	-R "${mount_point}" \
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

echo "Pool ZFS e datasets criados com sucesso!"
