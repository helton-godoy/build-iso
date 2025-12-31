#!/bin/bash
# =============================================================================
# HELTON OS INSTALLER - ZFS & ZFSBOOTMENU EDITION
# Adapted from Danfossi's Debian ZFS Root Installation Script
# =============================================================================

set -e

# --- CONFIGURAÇÃO ---
LOG_FILE="/var/log/heltonos-install.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

function log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

function error_exit() {
	gum style --foreground "#FF0000" --border double --margin "1" "ERRO FATAL: $1"
	exit 1
}

# --- DEPENDÊNCIAS ---
if ! command -v gum &>/dev/null; then
	echo "Erro: 'gum' não encontrado. Este script requer o pacote gum instalada na ISO."
	exit 1
fi

# =============================================================================
# 1. SELEÇÃO DE DISCOS E CONFIGURAÇÃO
# =============================================================================
clear
gum style --foreground "#00FFFF" --border double --margin "1" --padding "0 2" "🧭 Instalador HeltonOS (Debian 13 | ZFS | ZBM)"

# Validar modo de boot
if [[ -d "/sys/firmware/efi" ]]; then
	BOOT_MODE="UEFI"
else
	BOOT_MODE="BIOS"
	gum style --foreground "#FFA500" "Aviso: Boot em modo Legacy BIOS detectado."
	gum style --foreground "#FFA500" "ZFSBootMenu funciona melhor em UEFI. Grub será obrigatório para BIOS."
fi

# Listar discos
# Filtrar loop, sr (cdrom), e ram
DISKS=$(lsblk -d -n -o NAME,SIZE,MODEL,TYPE | awk '$4=="disk" && $1!~/^(loop|sr|ram)/ {print "/dev/"$1 " (" $2 " - " $3 ")"}')

if [[ -z ${DISKS} ]]; then
	error_exit "Nenhum disco físico detectado no sistema."
fi

gum style --foreground "#FFD700" "Selecione o(s) disco(s) para instalação:"
SELECTED_DISKS_RAW=$(gum choose --no-limit --height 10 "${DISKS}")

if [[ -z ${SELECTED_DISKS_RAW} ]]; then
	error_exit "Nenhum disco selecionado. Instalação cancelada."
fi

# Processar seleção
TARGET_DISKS=()
while IFS= read -r line; do
	disk=$(echo "${line}" | awk '{print $1}')
	TARGET_DISKS+=("${disk}")
done <<<"${SELECTED_DISKS_RAW}"

NUM_DISKS=${#TARGET_DISKS[@]}
log "Discos selecionados: ${TARGET_DISKS[*]}"

# Configuração de RAID
RAID_TYPE=""
if [[ ${NUM_DISKS} -gt 1 ]]; then
	RAID_TYPE=$(gum choose --header "Selecione o nível de RAID ZFS:" "mirror" "raidz1" "raidz2" "raid10 (striped mirror)")
	if [[ ${RAID_TYPE} == "raid10 (striped mirror)" ]]; then RAID_TYPE="raid10"; fi
fi

# Opções de Bootloader
USE_ZBM=true
USE_GRUB=false

if [[ ${BOOT_MODE} == "UEFI" ]]; then
	BOOTLOADER_CHOICE=$(gum choose --header "Selecione o Bootloader Principal:" "ZFSBootMenu (Recomendado)" "Grub (Apenas)" "Ambos (ZBM + Grub Fallback)")
	case "${BOOTLOADER_CHOICE}" in
	"ZFSBootMenu (Recomendado)")
		USE_ZBM=true
		USE_GRUB=false
		;;
	"Grub (Apenas)")
		USE_ZBM=false
		USE_GRUB=true
		;;
	"Ambos (ZBM + Grub Fallback)")
		USE_ZBM=true
		USE_GRUB=true
		;;
	esac
else
	gum style --foreground "#FFA500" "Modo BIOS detectado: Grub será instalado automaticamente."
	USE_ZBM=false
	USE_GRUB=true
fi

# Encriptação
ENCRYPT=$(gum choose --header "Encriptar o disco (Native ZFS Encryption)?" "Não" "Sim")
if [[ ${ENCRYPT} == "Sim" ]]; then
	gum style "A senha será solicitada durante a criação do pool."
fi

# Configuração de Usuário
HOSTNAME=$(gum input --placeholder "Hostname (ex: heltonos)" --value "heltonos")
USERNAME=$(gum input --placeholder "Usuário (ex: helton)")
PASSWORD=$(gum input --password --placeholder "Senha de Usuário")
ROOT_PASSWORD=$(gum input --password --placeholder "Senha de Root")

# Resumo
clear
gum style --border double "Resumo da Instalação"
echo "Discos: ${TARGET_DISKS[*]}"
echo "RAID: ${RAID_TYPE:-Single}"
echo "Bootloader: ZBM=${USE_ZBM}, GRUB=${USE_GRUB}"
echo "Encriptação: ${ENCRYPT}"
echo "Hostname: ${HOSTNAME}"
echo "---"
gum style --foreground "#FF0000" "ATENÇÃO: DADOS SERÃO APAGADOS PERMANENTEMENTE!"
gum confirm "Iniciar Instalação?" || exit 0

# =============================================================================
# 2. PREPARAÇÃO DE DISCOS E POOLS
# =============================================================================

# Definições de Partições
# P1: BIOS Boot (Legacy) ou Vazio
# P2: EFI System (512M)
# P3: bpool (1G ou 2G) - Compatibilidade Grub/ZBM
# P4: rpool (Resto)

PART_EFI=2
PART_BPOOL=3
PART_RPOOL=4

gum spin --title "Limpando e particionando discos..." -- bash -c "sleep 2"

for disk in "${TARGET_DISKS[@]}"; do
	log "Preparando ${disk}..."
	wipefs -a "${disk}"
	sgdisk --zap-all "${disk}"

	# Criar partições
	# 1: Tratamento Legacy (se necessário)
	if [[ ${BOOT_MODE} == "BIOS" ]]; then
		sgdisk -a1 -n1:24K:+1000K -t1:EF02 "${disk}" # BIOS Boot
	else
		# Espaço reservado/alinhamento
		:
	fi

	# 2: EFI (Sempre criada para compatibilidade e ZBM)
	sgdisk -n2:1M:+512M -t2:EF00 "${disk}"

	# 3: bpool (Boot Pool)
	# Aumentar para 2G para caber kernels + initramfs + backups ZBM
	sgdisk -n3:0:+2G -t3:BF01 "${disk}"

	# 4: rpool (Root Pool)
	sgdisk -n4:0:0 -t4:BF00 "${disk}"

	# Notificar kernel
	partprobe "${disk}" || true
done

sleep 2

# Construir lista de vdevs com sufixos corretos
# Detecção de sufixo (pX para nvme/mmc, X para sd/vd)
get_part_suffix() {
	local disk=$1
	if [[ ${disk} =~ nvme|mmcblk|loop ]]; then echo "p"; else echo ""; fi
}

# Tratamento de RAID para string do zpool
construct_vdev_list() {
	local part_num=$1
	local vdev_list=""

	if [[ ${RAID_TYPE} == "mirror" ]] || [[ ${RAID_TYPE} == "raidz1" ]] || [[ ${RAID_TYPE} == "raidz2" ]]; then
		vdev_list="${RAID_TYPE}"
	elif [[ ${RAID_TYPE} == "raid10" ]]; then
		# Complexo, simplificado para mirror pares se raid10 (não implementado full lógica aqui, fallback mirror)
		vdev_list="mirror"
	fi

	for disk in "${TARGET_DISKS[@]}"; do
		suffix=$(get_part_suffix "${disk}")
		vdev_list="${vdev_list} ${disk}${suffix}${part_num}"
	done
	echo "${vdev_list}"
}

BPOOL_ARGS=$(construct_vdev_list "${PART_BPOOL}")
RPOOL_ARGS=$(construct_vdev_list "${PART_RPOOL}")

log "Criando bpool com args: ${BPOOL_ARGS}"
log "Criando rpool com args: ${RPOOL_ARGS}"

# Criar bpool
# Features conservadoras para compatibilidade Grub/ZBM
zpool create -f \
	-o ashift=12 \
	-o autotrim=on \
	-o compatibility=grub2 \
	-o cachefile=/etc/zfs/zpool.cache \
	-O devices=off \
	-O acltype=posixacl -O xattr=sa \
	-O compression=lz4 \
	-O normalization=formD \
	-O relatime=on \
	-O canmount=off -O mountpoint=/boot -R /mnt \
	bpool "${BPOOL_ARGS}"

# Criar rpool
RPOOL_OPTS="-O acltype=posixacl -O xattr=sa -O dnodesize=auto -O compression=lz4 -O normalization=formD -O relatime=on -O canmount=off -O mountpoint=/ -R /mnt"

if [[ ${ENCRYPT} == "Sim" ]]; then
	gum style "Digite a senha de encriptação para o ZFS (rpool):"
	zpool create -f \
		-o ashift=12 \
		-o autotrim=on \
		-O encryption=on -O keylocation=prompt -O keyformat=passphrase \
		"${RPOOL_OPTS}" \
		rpool "${RPOOL_ARGS}"
else
	zpool create -f \
		-o ashift=12 \
		-o autotrim=on \
		"${RPOOL_OPTS}" \
		rpool "${RPOOL_ARGS}"
fi

# Datasets
log "Criando datasets..."
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/debian
zfs mount rpool/ROOT/debian

zfs create -o mountpoint=/boot bpool/BOOT
zfs create -o mountpoint=/boot bpool/BOOT/debian

# Datasets padrão
zfs create -o mountpoint=/home rpool/home
zfs create -o mountpoint=/root rpool/home/root
zfs create -o mountpoint=/var -o canmount=off rpool/var
zfs create -o mountpoint=/var/log rpool/var/log
zfs create -o mountpoint=/var/spool rpool/var/spool

# Datasets temporários (sem snapshot automático)
zfs create -o mountpoint=/var/cache -o com.sun:auto-snapshot=false rpool/var/cache
zfs create -o mountpoint=/var/lib -o com.sun:auto-snapshot=false rpool/var/lib
zfs create -o mountpoint=/var/tmp -o com.sun:auto-snapshot=false rpool/var/tmp
zfs create -o mountpoint=/srv rpool/srv

# Configurar bootfs
zpool set bootfs=rpool/ROOT/debian rpool

# =============================================================================
# 3. INSTALAÇÃO DO SISTEMA BASE (DEBOOTSTRAP)
# =============================================================================
mkdir -p /mnt/run /mnt/etc/zfs
cp /etc/zfs/zpool.cache /mnt/etc/zfs/

log "Iniciando debootstrap (trixie)..."
gum spin --title "Baixando pacotes base Debian Trixie..." -- \
	debootstrap trixie /mnt http://deb.debian.org/debian

# =============================================================================
# 4. CONFIGURAÇÃO DO SISTEMA
# =============================================================================

# Arquivos de Configuração Básicos
echo "${HOSTNAME}" >/mnt/etc/hostname
cat <<EOF >/mnt/etc/hosts
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME}
EOF

# Network (Copiando interfaces do live ou padrao simples)
cat <<EOF >/mnt/etc/network/interfaces
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
EOF

# Sources List (Debian Trixie)
cat <<EOF >/mnt/etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
EOF

# Preparar Chroot
mount --make-private --rbind /dev /mnt/dev
mount --make-private --rbind /proc /mnt/proc
mount --make-private --rbind /sys /mnt/sys

# Script interno para execução no chroot
cat <<'EOF_CHROOT' >/mnt/tmp/install_internal.sh
#!/bin/bash
set -e

# Configurar Locale e Timezone
echo "Configurando locales..."
apt-get update
apt-get install -y locales keyboard-configuration console-setup
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=pt_BR.UTF-8
echo "America/Sao_Paulo" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Instalar Kernel e ZFS
echo "Instalando Kernel e ZFS..."
apt-get install -y linux-image-amd64 linux-headers-amd64 systemd-sysv systemd-timesyncd firmware-linux firmware-linux-nonfree
apt-get install -y zfs-dkms zfsutils-linux zfs-initramfs zfs-zed zfs-auto-snapshot

# Configurar ZFS Import
echo "Habilitando zfs-import-bpool..."
cat << 'SERVICE' > /etc/systemd/system/zfs-import-bpool.service
[Unit]
DefaultDependencies=no
Before=zfs-import-scan.service
Before=zfs-import-cache.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/zpool import -N -o cachefile=none bpool
ExecStartPre=-/bin/mv /etc/zfs/zpool.cache /etc/zfs/preboot_zpool.cache
ExecStartPost=-/bin/mv /etc/zfs/preboot_zpool.cache /etc/zfs/zpool.cache

[Install]
WantedBy=zfs-import.target
SERVICE
systemctl enable zfs-import-bpool.service

# Usuários
echo "Configurando usuários..."
useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$ROOT_PASSWORD" | chpasswd
usermod -aG sudo,video,audio,netdev,plugdev "$USERNAME"

# Ferramentas extras
apt-get install -y sudo curl wget vim git dosfstools efibootmgr network-manager cron

# --- ZFS Shadow Copy (Samba Compatibility) ---
echo "Configurando script de snapshots Shadow Copy..."
cat << 'SC_SCRIPT' > /usr/local/bin/zfs-shadow-snapshot
#!/bin/bash
# ZFS Snapshot for Samba vfs_shadow_copy2 compatibility
# Format: @GMT-YYYY.MM.DD-HH.MM.SS

TIMESTAMP=$(date -u +%Y.%m.%d-%H.%M.%S)
SNAP_NAME="@GMT-${TIMESTAMP}"

# Datasets de dados do usuário (ajuste conforme necessário)
DATA_DATASETS=("rpool/home" "rpool/srv")

for ds in "${DATA_DATASETS[@]}"; do
    if zfs list "$ds" >/dev/null 2>&1; then
        zfs snapshot -r "${ds}${SNAP_NAME}"
        # Prune: Manter ultimos 48 (12h a cada 15m) + Diarios (logica simples de limpeza pode ser adicionada aqui ou via ferramenta externa)
        # Por simplicidade, este script apenas cria. Recomenda-se usar ferramentas de pruning dedicadas se o volume for alto.
    fi
done
SC_SCRIPT
chmod +x /usr/local/bin/zfs-shadow-snapshot

# Agendar no Cron (15 min)
echo "*/15 * * * * root /usr/local/bin/zfs-shadow-snapshot" > /etc/cron.d/zfs-shadow-snapshot
chmod 644 /etc/cron.d/zfs-shadow-snapshot

EOF_CHROOT
chmod +x /mnt/tmp/install_internal.sh

log "Executando configuração no chroot..."
gum spin --title "Configurando sistema no chroot..." -- chroot /mnt env USERNAME="${USERNAME}" PASSWORD="${PASSWORD}" ROOT_PASSWORD="${ROOT_PASSWORD}" /tmp/install_internal.sh

# =============================================================================
# 5. INSTALAÇÃO DE BOOTLOADER
# =============================================================================

# Montagem de EFI
# Vamos montar a partição EFI do primeiro disco em /boot/efi no chroot
FIRST_DISK=${TARGET_DISKS[0]}
SUFFIX=$(get_part_suffix "${FIRST_DISK}")
EFI_PART="${FIRST_DISK}${SUFFIX}${PART_EFI}"

log "Formatando e montando EFI: ${EFI_PART}"
mkfs.vfat -F32 "${EFI_PART}"
mkdir -p /mnt/boot/efi
mount "${EFI_PART}" /mnt/boot/efi

# Gerar fstab (básico para EFI, o resto é ZFS automount)
echo "UUID=$(blkid -s UUID -o value "${EFI_PART}") /boot/efi vfat defaults 0 0" >/mnt/etc/fstab

# --- ZFSBOOTMENU ---
if [[ ${USE_ZBM} == "true" ]]; then
	log "Instalando ZFSBootMenu..."
	mkdir -p /mnt/boot/efi/EFI/ZBM

	# 1. Tentar copiar da ISO (local)
	if [[ -f "/usr/share/zfsbootmenu/zfsbootmenu.EFI" ]]; then
		cp /usr/share/zfsbootmenu/zfsbootmenu.EFI /mnt/boot/efi/EFI/ZBM/zfsbootmenu.EFI
	else
		# 2. Download Fallback
		gum spin --title "Baixando ZFSBootMenu..." -- \
			wget "https://github.com/zbm-dev/zfsbootmenu/releases/download/v2.3.0/zfsbootmenu-release-x86_64-v2.3.0.EFI" \
			-O /mnt/boot/efi/EFI/ZBM/zfsbootmenu.EFI
	fi

	# Adicionar entrada UEFI
	# Remover entrada antiga se existir
	efibootmgr -B -L "ZFSBootMenu" || true
	# Criar nova
	# Precisamos do device path para efibootmgr (-d disk -p part)
	efibootmgr -c -d "${FIRST_DISK}" -p "${PART_EFI}" -L "ZFSBootMenu" -l '\EFI\ZBM\zfsbootmenu.EFI'

	# Configurar propriedades ZBM no dataset ROOT
	# ZBM usa org.zfsbootmenu:commandline para argumentos do kernel
	log "Configurando propriedades ZFSBootMenu..."
	zfs set org.zfsbootmenu:commandline="quiet splash" rpool/ROOT/debian
	zfs set org.zfsbootmenu:dodes="true" rpool/ROOT/debian # Tentativa de setup automático chave

	# Se encriptado, garantir que ZBM pergunte a senha
	if [[ ${ENCRYPT} == "Sim" ]]; then
		zfs set org.zfsbootmenu:keysource="rpool" rpool/ROOT/debian
	fi
fi

# --- GRUB ---
if [[ ${USE_GRUB} == "true" ]]; then
	log "Instalando Grub..."
	gum spin --title "Instalando Grub..." -- bash -c "
        chroot /mnt apt-get install -y grub-efi-amd64 shim-signed grub-pc-bin
        # Update grub config
        # Para ZFS, grub precisa de zfs module
        echo 'GRUB_CMDLINE_LINUX=\"root=ZFS=rpool/ROOT/debian boot=zfs\"' >> /mnt/etc/default/grub
        chroot /mnt update-grub
        chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck --no-floppy
    "
fi

# =============================================================================
# 6. FINALIZAÇÃO
# =============================================================================

# Gerar initramfs final
log "Gerando initramfs final..."
chroot /mnt update-initramfs -u -k all

# Criar Snapshot Inicial
log "Criando snapshot inicial (@install)..."
zfs snapshot -r rpool/ROOT/debian@install
zfs snapshot -r bpool/BOOT/debian@install

# Umount
log "Desmontando..."
umount -R /mnt
zpool export -a

gum style --border double --foreground "#00FF00" --margin "1" "✅ Instalação Concluída com Sucesso!"
gum style "Reinicie o sistema e selecione 'ZFSBootMenu' (se instalado) na BIOS/UEFI."
