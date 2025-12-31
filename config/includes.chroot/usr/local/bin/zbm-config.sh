#!/bin/bash
# =============================================================================
# zbm-config.sh - Instalação de ZFSBootMenu e Fallback Grub
# =============================================================================

set -e

# O Calamares monta o alvo em /tmp/calamares-root-... ou similar.
# Passaremos o caminho como argumento.
target_root=$1
override_efi_part=$2

# Recuperar informações salvas pelo zfs-installer.sh
INFO_FILE="/tmp/zfs_install_info"
# shellcheck disable=SC1090,SC2153
if [[ -f ${INFO_FILE} ]]; then
	source "${INFO_FILE}"
	echo "Carregado estado da instalação: TARGET_DISK=${TARGET_DISK}, EFI_PART=${EFI_PART}"

	# Se carregou do arquivo, usamos essas variáveis
	efi_part="${EFI_PART}"
	target_disk="${TARGET_DISK}"
else
	# Fallback para o argumento (comportamento antigo, mas frágil)
	efi_part="${override_efi_part}"
	target_disk="$(echo "${efi_part}" | sed 's/[0-9]*$//' | sed 's/p$//')"
	echo "Aviso: Informação de estado não encontrada. Usando argumentos: ${efi_part}"
fi

if [[ ! -b ${efi_part} ]]; then
	echo "Erro: Partição EFI ${efi_part} não encontrada ou inválida!"
	exit 1
fi

echo "Configurando ZFSBootMenu em ${target_root}..."

# 1. Montar partição EFI
mkdir -p "${target_root}/boot/efi"
mount "${efi_part}" "${target_root}/boot/efi"

# 2. Copiar binário ZFSBootMenu (que incluímos na ISO em /usr/share/zfsbootmenu)
mkdir -p "${target_root}/boot/efi/EFI/ZBM"
cp /usr/share/zfsbootmenu/zfsbootmenu.EFI "${target_root}/boot/efi/EFI/ZBM/zfsbootmenu.EFI"

# 3. Registrar na NVRAM com efibootmgr
# Assumindo partição 1 para EFI conforme zfs-installer.sh
efibootmgr -c -d "${target_disk}" -p 1 \
	-L "ZFSBootMenu" -l '\EFI\ZBM\zfsbootmenu.EFI'

# 4. Configurações ZFS para o Menu e Initramfs
# Garantir que o hostid seja consistente
hostid >"${target_root}/etc/hostid"

# Chroot para configurar o sistema instalado
chroot "${target_root}" /usr/sbin/update-initramfs -u -k all

# 5. Configurar GRUB como Fallback (opcional, mas solicitado)
# Chroot para instalar o grub
chroot "${target_root}" /usr/sbin/grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck --no-floppy
chroot "${target_root}" /usr/sbin/update-grub

# 6. Definir propriedades necessárias para o ZBM no sistema instalado
zfs set org.zfsbootmenu:commandline="quiet splash" zroot/ROOT/debian

umount "${target_root}/boot/efi"

echo "ZFSBootMenu configurado!"
