#!/bin/bash
set -e

# =============================================================================
# CONFIGURAÇÕES DO USUÁRIO - ALTERE CONFORME NECESSÁRIO
# =============================================================================

# Defina o disco alvo. Use /dev/disk/by-id/ para maior segurança.
# Exemplo: DISK="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_..."
# Se deixar vazio, o script tentará perguntar.
TARGET_DISK=""

# Nome do Host
MY_HOSTNAME="zfsbootmenu-pc"

# Espelho do Debian (Padrão: deb.debian.org)
MIRROR="http://deb.debian.org/debian"

# =============================================================================
# VERIFICAÇÕES INICIAIS
# =============================================================================

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Este script deve ser executado como root (sudo -i)."
	exit 1
fi

# Instalar dependências necessárias no ambiente Live
echo ">>> Instalando ferramentas necessárias no ambiente Live..."
sed -i 's/main/main contrib non-free-firmware/g' /etc/apt/sources.list
apt-get update
apt-get install -y debootstrap gdisk dkms zfsutils-linux curl dosfstools efibootmgr

# Seleção do disco se não definido
if [[ -z ${TARGET_DISK} ]]; then
	echo "-----------------------------------------------------"
	lsblk -d -o NAME,MODEL,SIZE,TYPE,TRAN
	echo "-----------------------------------------------------"
	read -p "Digite o caminho completo do disco alvo (ex: /dev/sda): " TARGET_DISK
fi

if [[ ! -b ${TARGET_DISK} ]]; then
	echo "Erro: Disco ${TARGET_DISK} não encontrado."
	exit 1
fi

echo "!!! ATENÇÃO !!!"
echo "O disco ${TARGET_DISK} será COMPLETAMENTE APAGADO."
echo "Você tem 10 segundos para cancelar (Ctrl+C)."
sleep 10

# Solicitar senha para criptografia ZFS
echo
read -s -p "Digite a senha para criptografia do disco (ZFS): " ZFS_PASS
echo
read -s -p "Confirme a senha: " ZFS_PASS_CONFIRM
echo
if [[ ${ZFS_PASS} != "${ZFS_PASS_CONFIRM}" ]]; then
	echo "As senhas não conferem."
	exit 1
fi

# =============================================================================
# PREPARAÇÃO DO DISCO
# =============================================================================

echo ">>> Limpando disco..."
wipefs -a "${TARGET_DISK}"
sgdisk --zap-all "${TARGET_DISK}"

echo ">>> Criando partições..."
# Partição 1: EFI (1GB)
sgdisk -n 1:0:+1G -t 1:EF00 "${TARGET_DISK}"
# Partição 2: ZFS (Resto)
sgdisk -n 2:0:0 -t 2:BF01 "${TARGET_DISK}"

# Aguardar o sistema reconhecer as partições
sleep 2

# Identificar partições (suporta nvme0n1p1 e sda1)
if [[ ${TARGET_DISK} == *"nvme"* ]]; then
	PART1="${TARGET_DISK}p1"
	PART2="${TARGET_DISK}p2"
else
	PART1="${TARGET_DISK}1"
	PART2="${TARGET_DISK}2"
fi

# =============================================================================
# CRIAÇÃO DO ZFS POOL E DATASETS
# =============================================================================

echo ">>> Criando Pool 'zroot'..."
# Echo da senha para o zpool create
echo "${ZFS_PASS}" | zpool create -f -o ashift=12 \
	-O compression=lz4 \
	-O acltype=posixacl \
	-O xattr=sa \
	-O dnodesize=auto \
	-O normalization=formD \
	-O relatime=on \
	-O canmount=off \
	-O mountpoint=/ \
	-O encryption=aes-256-gcm \
	-O keylocation=prompt \
	-O keyformat=passphrase \
	-R /mnt \
	zroot "${PART2}"

echo ">>> Criando Datasets..."
zfs create -o mountpoint=none zroot/ROOT
zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/debian
zfs create -o mountpoint=/home zroot/home

# Definir bootfs (obrigatório para ZFSBootMenu)
zpool set bootfs=zroot/ROOT/debian zroot

echo ">>> Exportando e reimportando para verificar montagem..."
zpool export zroot
zpool import -N -R /mnt zroot
echo "${ZFS_PASS}" | zfs load-key zroot
zfs mount zroot/ROOT/debian
zfs mount -a

# =============================================================================
# INSTALAÇÃO DO SISTEMA BASE
# =============================================================================

echo ">>> Executando Debootstrap..."
debootstrap bookworm /mnt "${MIRROR}"

# =============================================================================
# CONFIGURAÇÃO PRÉ-CHROOT
# =============================================================================

echo ">>> Copiando configurações..."
cp /etc/apt/sources.list /mnt/etc/apt/sources.list
zgenhostid -f 0x00bab10c
cp /etc/hostid /mnt/etc/hostid
mkdir -p /mnt/etc/zfs
cp /etc/zfs/zpool.cache /mnt/etc/zfs/

# Montagens bind
mount --make-private --bind /dev /mnt/dev
mount --make-private --bind /proc /mnt/proc
mount --make-private --bind /sys /mnt/sys
mount --make-private --bind /run /mnt/run

# Preparar partição EFI
mkfs.vfat -F32 "${PART1}"
mkdir -p /mnt/boot/efi
mount "${PART1}" /mnt/boot/efi
EFI_UUID=$(blkid -s UUID -o value "${PART1}")

# =============================================================================
# CONFIGURAÇÃO DENTRO DO CHROOT
# =============================================================================

echo ">>> Entrando no Chroot para configurar o sistema..."

chroot /mnt /bin/bash <<EOF
set -e

# Configurar Hostname
echo "${MY_HOSTNAME}" > /etc/hostname
echo "127.0.1.1 ${MY_HOSTNAME}" >> /etc/hosts

# Configurar Fstab (EFI)
echo "UUID=${EFI_UUID} /boot/efi vfat umask=0077 0 1" >> /etc/fstab

# Atualizar repositórios e instalar locales
apt-get update
apt-get install -y locales console-setup
echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/default/locale

# Instalar Kernel e ZFS
# O frontend noninteractive evita perguntas durante a instalação
DEBIAN_FRONTEND=noninteractive apt-get install -y linux-image-amd64 linux-headers-amd64 zfs-dkms zfs-initramfs

# Habilitar serviços ZFS
systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target

# Garantir ZFS no initramfs
echo "zfs" >> /etc/initramfs-tools/modules
update-initramfs -c -k all

# Configurar ZFSBootMenu Properties
zfs set org.zfsbootmenu:commandline="quiet" zroot/ROOT
zfs set org.zfsbootmenu:active=on zroot/ROOT/debian

# Baixar ZFSBootMenu (conforme documentação oficial)
mkdir -p /boot/efi/EFI/ZBM
curl -o /boot/efi/EFI/ZBM/VMLINUZ.EFI -L https://get.zfsbootmenu.org/efi
cp /boot/efi/EFI/ZBM/VMLINUZ.EFI /boot/efi/EFI/ZBM/VMLINUZ-BACKUP.EFI

# Instalar efibootmgr e configurar boot
apt-get install -y efibootmgr

# Definir senha de root (interativo)
echo "------------------------------------------------"
echo ">>> Defina a senha de ROOT para o novo sistema:"
echo "------------------------------------------------"
passwd

EOF

# =============================================================================
# FINALIZAÇÃO FORA DO CHROOT (BOOT ENTRY)
# =============================================================================

echo ">>> Adicionando entrada UEFI..."
efibootmgr -c -d "${TARGET_DISK}" \
	-p 1 \
	-L "ZFSBootMenu" \
	-l '\EFI\ZBM\VMLINUZ.EFI'

echo ">>> Desmontando e exportando..."
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export -a

echo "==========================================================="
echo " Instalação Concluída!"
echo " Reinicie o computador e remova o pendrive."
echo "==========================================================="
