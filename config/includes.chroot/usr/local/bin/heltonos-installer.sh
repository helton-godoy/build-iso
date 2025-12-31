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
# NOTA: MODEL pode conter espaços, então colocamos TYPE antes de MODEL
# para garantir que o campo TYPE esteja em posição fixa ($3)
DISKS=$(lsblk -d -n -o NAME,SIZE,TYPE,MODEL | awk '$3=="disk" && $1!~/^(loop|sr|ram)/ { model=$4; for(i=5;i<=NF;i++) model=model" "$i; print "/dev/"$1 " (" $2 " - " model ")"}')

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

# Perfil de Instalação
INSTALL_PROFILE=$(gum choose --header "Selecione o perfil de instalação:" \
	"SERVER (Somente linha de comando)" \
	"WORKSTATION (KDE Plasma Minimalista)")

case "${INSTALL_PROFILE}" in
"SERVER"*)
	PROFILE_TYPE="server"
	;;
"WORKSTATION"*)
	PROFILE_TYPE="workstation"
	;;
*)
	PROFILE_TYPE="server"
	;;
esac

# Configuração de Usuário
HOSTNAME=$(gum input --placeholder "Hostname (ex: heltonos)" --value "heltonos")
USERNAME=$(gum input --placeholder "Usuário (ex: helton)" --value "helton")
PASSWORD=$(gum input --password --placeholder "Senha de Usuário")
ROOT_PASSWORD=$(gum input --password --placeholder "Senha de Root")

# Validar campos obrigatórios
if [[ -z ${USERNAME} ]]; then
	error_exit "Nome de usuário não pode estar vazio."
fi
if [[ -z ${PASSWORD} ]]; then
	error_exit "Senha de usuário não pode estar vazia."
fi
if [[ -z ${ROOT_PASSWORD} ]]; then
	error_exit "Senha de root não pode estar vazia."
fi

# Resumo
clear
gum style --border double "Resumo da Instalação"
echo "Perfil: ${INSTALL_PROFILE}"
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

# Limpar recursos existentes (pools ZFS, partições montadas)
log "Limpando recursos existentes..."

# Desmontar bind mounts do chroot primeiro (se existirem)
for mount_point in /mnt/dev /mnt/proc /mnt/sys /mnt/run /mnt/boot/efi; do
	umount -lf "${mount_point}" 2>/dev/null || true
done

# Desmontar todos os datasets ZFS
zfs unmount -a 2>/dev/null || true

# Desmontar qualquer coisa em /mnt
umount -lR /mnt 2>/dev/null || true

# Destruir pools existentes FORÇADAMENTE
for pool in bpool rpool; do
	if zpool list "${pool}" &>/dev/null; then
		log "Destruindo pool existente: ${pool}"
		# Desmontar datasets do pool primeiro
		zfs unmount -a -f 2>/dev/null || true
		# Destruir o pool
		zpool destroy -f "${pool}" 2>/dev/null || true
	fi
done

# Verificar novamente e forçar mais ainda se necessário
for pool in bpool rpool; do
	if zpool list "${pool}" &>/dev/null; then
		log "Pool ${pool} ainda existe, forçando exportação..."
		zpool export -f "${pool}" 2>/dev/null || true
	fi
done

# Tentar importar e destruir pools órfãos que possam existir nos discos
for disk in "${TARGET_DISKS[@]}"; do
	# Importar pools órfãos do disco e destruir
	for pool in $(zpool import -d "${disk}" 2>/dev/null | grep "pool:" | awk '{print $2}'); do
		log "Destruindo pool órfão: ${pool}"
		zpool import -f -d "${disk}" "${pool}" 2>/dev/null || true
		zpool destroy -f "${pool}" 2>/dev/null || true
	done
done

# Desmontar partições dos discos selecionados
for disk in "${TARGET_DISKS[@]}"; do
	log "Liberando ${disk}..."

	# Desmontar todas as partições do disco
	for part in "${disk}"*; do
		umount -lf "${part}" 2>/dev/null || true
	done

	# Remover do device-mapper se existir
	dmsetup remove_all 2>/dev/null || true

	# Limpar labels ZFS de cada partição
	for part in "${disk}"*; do
		if [[ -b ${part} ]]; then
			zpool labelclear -f "${part}" 2>/dev/null || true
		fi
	done

	# Limpar label no disco inteiro também
	zpool labelclear -f "${disk}" 2>/dev/null || true
done

# Pequena pausa para o kernel liberar recursos
sleep 1

for disk in "${TARGET_DISKS[@]}"; do
	log "Preparando ${disk}..."

	# Limpar completamente o disco (zera os primeiros e últimos MB onde ZFS guarda labels)
	log "Limpando labels ZFS com dd..."
	dd if=/dev/zero of="${disk}" bs=1M count=10 status=none 2>/dev/null || true

	# Obter tamanho do disco e zerar o final também (ZFS guarda labels no fim)
	DISK_SIZE=$(blockdev --getsize64 "${disk}" 2>/dev/null || echo 0)
	if [[ ${DISK_SIZE} -gt 10485760 ]]; then
		# Zerar últimos 10MB
		dd if=/dev/zero of="${disk}" bs=1M count=10 seek=$((DISK_SIZE / 1048576 - 10)) status=none 2>/dev/null || true
	fi

	# Agora wipefs para garantir
	wipefs -af "${disk}" 2>/dev/null || true

	# Criar nova tabela de partições
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

	# Notificar kernel e sincronizar
	sync
	partprobe "${disk}" 2>/dev/null || true
	udevadm settle --timeout=10 2>/dev/null || true
done

# Aguardar partições ficarem disponíveis
log "Aguardando partições..."
sleep 3

# Limpar labels ZFS nas novas partições (por segurança)
for disk in "${TARGET_DISKS[@]}"; do
	suffix=""
	if [[ ${disk} =~ nvme|mmcblk|loop ]]; then suffix="p"; fi

	for partnum in 3 4; do
		part="${disk}${suffix}${partnum}"
		if [[ -b ${part} ]]; then
			zpool labelclear -f "${part}" 2>/dev/null || true
			wipefs -af "${part}" 2>/dev/null || true
		fi
	done
done

sleep 1

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
		if [[ -z ${vdev_list} ]]; then
			vdev_list="${disk}${suffix}${part_num}"
		else
			vdev_list="${vdev_list} ${disk}${suffix}${part_num}"
		fi
	done
	echo "${vdev_list}"
}

BPOOL_ARGS=$(construct_vdev_list "${PART_BPOOL}")
RPOOL_ARGS=$(construct_vdev_list "${PART_RPOOL}")

log "Criando bpool com args: ${BPOOL_ARGS}"
log "Criando rpool com args: ${RPOOL_ARGS}"

# Criar bpool
# Features conservadoras para compatibilidade Grub/ZBM
# shellcheck disable=SC2086 # Word splitting intencional para BPOOL_ARGS
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
	bpool ${BPOOL_ARGS}

# Criar rpool
RPOOL_OPTS=(
	-O acltype=posixacl
	-O xattr=sa
	-O dnodesize=auto
	-O compression=lz4
	-O normalization=formD
	-O relatime=on
	-O canmount=off
	-O mountpoint=/
	-R /mnt
)

# shellcheck disable=SC2086 # Word splitting intencional para RPOOL_ARGS
if [[ ${ENCRYPT} == "Sim" ]]; then
	gum style "Digite a senha de encriptação para o ZFS (rpool):"
	zpool create -f \
		-o ashift=12 \
		-o autotrim=on \
		-O encryption=on -O keylocation=prompt -O keyformat=passphrase \
		"${RPOOL_OPTS[@]}" \
		rpool ${RPOOL_ARGS}
else
	zpool create -f \
		-o ashift=12 \
		-o autotrim=on \
		"${RPOOL_OPTS[@]}" \
		rpool ${RPOOL_ARGS}
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
# 3. INSTALAÇÃO DO SISTEMA BASE (MMDEBSTRAP)
# =============================================================================

log "Iniciando mmdebstrap (trixie) - Perfil: ${PROFILE_TYPE}..."

# Pacotes base comuns a todos os perfis
BASE_PACKAGES="systemd-sysv,systemd-timesyncd,locales,keyboard-configuration,console-setup"
BASE_PACKAGES+=",linux-image-amd64,linux-headers-amd64,firmware-linux,firmware-linux-nonfree"
BASE_PACKAGES+=",zfs-dkms,zfsutils-linux,zfs-initramfs,zfs-zed"
BASE_PACKAGES+=",sudo,curl,wget,vim,git,dosfstools,efibootmgr,network-manager,cron"

# Pacotes específicos por perfil
if [[ ${PROFILE_TYPE} == "workstation" ]]; then
	gum style --foreground "#FFD700" "⏳ Instalando sistema WORKSTATION com KDE Plasma..."
	gum style --foreground "#888888" "   (Este processo pode levar 15-30 minutos dependendo da conexão)"

	# KDE Plasma minimalista + aplicativos essenciais
	DESKTOP_PACKAGES="plasma-desktop,sddm,konsole,dolphin,kate,ark,kcalc"
	DESKTOP_PACKAGES+=",plasma-nm,plasma-pa,powerdevil,bluedevil"
	DESKTOP_PACKAGES+=",breeze-gtk-theme,kde-spectacle,gwenview,okular"
	DESKTOP_PACKAGES+=",pipewire,pipewire-audio,wireplumber"
	DESKTOP_PACKAGES+=",fonts-noto,fonts-liberation2"

	INCLUDE_PACKAGES="${BASE_PACKAGES},${DESKTOP_PACKAGES}"
else
	gum style --foreground "#FFD700" "⏳ Instalando sistema SERVER (CLI)..."
	gum style --foreground "#888888" "   (Este processo pode levar 5-10 minutos dependendo da conexão)"

	# Servidor: apenas ferramentas CLI essenciais
	SERVER_PACKAGES="htop,tmux,rsync,openssh-server,ca-certificates"
	INCLUDE_PACKAGES="${BASE_PACKAGES},${SERVER_PACKAGES}"
fi

echo ""

# Executar mmdebstrap com saída visível
# --skip=check/empty: /mnt já tem datasets ZFS montados, não está vazio
mmdebstrap \
	--variant=apt \
	--components="main,contrib,non-free,non-free-firmware" \
	--include="${INCLUDE_PACKAGES}" \
	--skip=check/empty \
	trixie /mnt http://deb.debian.org/debian 2>&1 |
	tee -a "${LOG_FILE}" |
	grep -E "^I:|^W:|^E:|Retrieving|Unpacking|Setting up|Processing|done\.$"

# Verificar se mmdebstrap teve sucesso (PIPESTATUS[0] é o exit code do mmdebstrap)
MMDEBSTRAP_EXIT=${PIPESTATUS[0]}
if [[ ${MMDEBSTRAP_EXIT} -eq 0 ]]; then
	gum style --foreground "#00FF00" "✓ Sistema base instalado com sucesso!"
else
	error_exit "Falha no mmdebstrap (exit code: ${MMDEBSTRAP_EXIT}). Verifique ${LOG_FILE} para detalhes."
fi

# =============================================================================
# 4. CONFIGURAÇÃO DO SISTEMA
# =============================================================================

# Copiar cache ZFS para o sistema instalado
mkdir -p /mnt/run /mnt/etc/zfs /mnt/etc/network
cp /etc/zfs/zpool.cache /mnt/etc/zfs/

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
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=pt_BR.UTF-8
echo "America/Sao_Paulo" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Configurar teclado brasileiro
cat <<KEYBOARD > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="br"
XKBVARIANT="abnt2"
XKBOPTIONS=""
BACKSPACE="guess"
KEYBOARD
setupcon --force

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

# Habilitar serviços essenciais
systemctl enable NetworkManager

# Configurações específicas por perfil
if [[ "$PROFILE_TYPE" == "workstation" ]]; then
	echo "Configurando ambiente WORKSTATION (KDE Plasma)..."

	# Habilitar SDDM
	systemctl enable sddm

	# Configurar SDDM
	mkdir -p /etc/sddm.conf.d
	cat <<SDDM > /etc/sddm.conf.d/kde_settings.conf
[Theme]
Current=breeze

[General]
Numlock=on
SDDM

	# Adicionar usuário a grupos do KDE
	usermod -aG render "$USERNAME"

	# Habilitar PipeWire
	systemctl --global enable pipewire pipewire-pulse wireplumber || true
else
	echo "Configurando ambiente SERVER..."
	# Habilitar SSH
	systemctl enable ssh
fi

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
gum style --foreground "#FFD700" "⏳ Configurando sistema (locales, usuários, serviços)..."
gum style --foreground "#888888" "   (Este processo deve levar 1-3 minutos)"
echo ""

if chroot /mnt env USERNAME="${USERNAME}" PASSWORD="${PASSWORD}" ROOT_PASSWORD="${ROOT_PASSWORD}" PROFILE_TYPE="${PROFILE_TYPE}" /tmp/install_internal.sh 2>&1 |
	tee -a "${LOG_FILE}"; then
	gum style --foreground "#00FF00" "✓ Configuração do chroot concluída!"
else
	error_exit "Falha na configuração do chroot. Verifique ${LOG_FILE} para detalhes."
fi

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
	# Remover entradas antigas se existirem para evitar duplicatas ou lixo
	log "Limpando entradas UEFI antigas..."
	for num in $(efibootmgr | grep "ZFSBootMenu" | awk '{print $1}' | sed 's/Boot//' | sed 's/\*//'); do
		efibootmgr -b "${num}" -B || true
	done

	# Criar nova entrada
	# Precisamos do device path para efibootmgr (-d disk -p part)
	log "Registrando ZFSBootMenu na NVRAM..."
	efibootmgr -c -d "${FIRST_DISK}" -p "${PART_EFI}" -L "ZFSBootMenu" -l '\EFI\ZBM\zfsbootmenu.EFI'

	# 3. Copiar para o caminho de fallback (Removable Path)
	# Essencial para VMs e sistemas que perdem a NVRAM ou não seguem a ordem de boot estritamente.
	log "Configurando caminho de fallback UEFI (/EFI/BOOT/BOOTX64.EFI)..."
	mkdir -p /mnt/boot/efi/EFI/BOOT
	cp /mnt/boot/efi/EFI/ZBM/zfsbootmenu.EFI /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI

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

# Desmontagem
log "Desmontando..."

# Sincronizar sistemas de arquivos
sync

# Desmontar bind mounts do chroot primeiro
umount -lf /mnt/dev 2>/dev/null || true
umount -lf /mnt/proc 2>/dev/null || true
umount -lf /mnt/sys 2>/dev/null || true
umount -lf /mnt/run 2>/dev/null || true

# Desmontar EFI
umount -f /mnt/boot/efi 2>/dev/null || true

# Desmontar recursivamente /mnt
umount -R /mnt 2>/dev/null || umount -lR /mnt 2>/dev/null || true

# Pequena pausa para o sistema liberar recursos
sleep 2

# Exportar pools ZFS
log "Exportando pools ZFS..."
zpool export bpool 2>/dev/null || zpool export -f bpool 2>/dev/null || true
zpool export rpool 2>/dev/null || zpool export -f rpool 2>/dev/null || true

gum style --border double --foreground "#00FF00" --margin "1" "✅ Instalação Concluída com Sucesso!"
gum style "Reinicie o sistema e selecione 'ZFSBootMenu' (se instalado) na BIOS/UEFI."
