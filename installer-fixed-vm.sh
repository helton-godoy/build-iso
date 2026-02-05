#!/bin/bash
# Instalador ZFS Debian - Versão Corrigida (sem subshells problemáticos)

set -uo pipefail

SCRIPT_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/installer"
POOL_NAME="zroot"
MOUNT_POINT="/mnt"
LOG_FILE="/var/log/installer-fixed.log"

log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
	log "ERRO: $1"
	echo "ERRO: $1" >&2
	exit 1
}

# Carrega módulos
source "$LIB_DIR/../fileserver-ds.sh" || error_exit "Design System não encontrado"
source "$LIB_DIR/firmware-detection.sh"
source "$LIB_DIR/disk-detection.sh"
source "$LIB_DIR/partitioning.sh"
source "$LIB_DIR/zfs-setup.sh"
source "$LIB_DIR/system-config.sh"
source "$LIB_DIR/zbm-install.sh"

log "=== INSTALADOR CORRIGIDO v2 ==="

# Configurações padrão
SELECTED_DISK=""
HOSTNAME=""
USERNAME=""
USER_PASS=""
ROOT_PASS=""

# Seleção de disco
clear
ds_hero "Instalação Automatizada de Debian com ZFS"
echo
echo "Discos disponíveis:"
lsblk -d -n -o NAME,SIZE,MODEL -e 7,11 | grep -E "^vd|^sd|^nvme"
echo
read -p "Digite o disco de destino (ex: /dev/vda): " SELECTED_DISK

if [[ ! -b "$SELECTED_DISK" ]]; then
	error_exit "Disco $SELECTED_DISK não encontrado"
fi

log "Disco selecionado: $SELECTED_DISK"

# Configurações
read -p "Hostname [fileserver]: " HOSTNAME
HOSTNAME=${HOSTNAME:-fileserver}

read -p "Usuário [admin]: " USERNAME
USERNAME=${USERNAME:-admin}

read -s -p "Senha do usuário: " USER_PASS
echo

read -s -p "Senha do root: " ROOT_PASS
echo

log "Configuração: hostname=$HOSTNAME, user=$USERNAME"

# Confirmação
echo
echo "================================"
echo "Resumo da instalação:"
echo "Disco: $SELECTED_DISK"
echo "Hostname: $HOSTNAME"
echo "Usuário: $USERNAME"
echo "================================"
echo "ATENÇÃO: TODOS OS DADOS SERÃO APAGADOS!"
read -p "Confirma? (digite SIM): " confirm

if [[ "$confirm" != "SIM" ]]; then
	log "Instalação cancelada pelo usuário"
	exit 0
fi

log "Instalação confirmada"

# ETAPA 1: Particionamento
log "[1/6] Particionando disco..."

log "Limpando disco $SELECTED_DISK..."
partition_wipe_disk "$SELECTED_DISK" || error_exit "Falha ao limpar disco"
log "✓ Disco limpo"

log "Criando partições GPT..."
partition_create_gpt "$SELECTED_DISK" || error_exit "Falha ao criar partições"
log "✓ Partições criadas"

# CORREÇÃO: Captura das variáveis imediatamente após criação
part_esp=$(partition_get_esp)
part_zfs=$(partition_get_zfs)

log "Partições criadas: ESP=$part_esp, ZFS=$part_zfs"

if [[ -z "$part_esp" || -z "$part_zfs" ]]; then
	error_exit "Partições não encontradas após criação"
fi

log "Formatando ESP..."
partition_format_esp "$part_esp" || error_exit "Falha ao formatar ESP"
log "✓ ESP formatado"

# ETAPA 2: ZFS
log "[2/6] Configurando ZFS..."

log "Criando pool ZFS em $part_zfs..."
zfs_create_pool "$part_zfs" || error_exit "Falha ao criar pool"
log "✓ Pool ZFS criado"

log "Criando datasets..."
zfs_create_datasets || error_exit "Falha ao criar datasets"
log "✓ Datasets criados"

# ETAPA 3: Cópia
log "[3/6] Copiando sistema..."
log "Isso pode demorar alguns minutos..."

rsync -aAXH --progress \
	--exclude={/dev/*,/proc/*,/sys/*,/tmp/*,/run/*,/mnt/*,/media/*,/lost+found,/var/log/*} \
	/ "${MOUNT_POINT}/" || error_exit "Falha na cópia do sistema"

mkdir -p "${MOUNT_POINT}"/{dev,proc,sys,tmp,run,mnt,media}
chmod 1777 "${MOUNT_POINT}/tmp"
log "✓ Cópia concluída"

# ETAPA 4: Configuração
log "[4/6] Configurando sistema..."

log "Montando sistemas virtuais..."
mount --bind /dev "${MOUNT_POINT}/dev"
mount --bind /proc "${MOUNT_POINT}/proc"
mount --bind /sys "${MOUNT_POINT}/sys"
mount --bind /run "${MOUNT_POINT}/run"

log "Configurando hostname..."
echo "$HOSTNAME" >"${MOUNT_POINT}/etc/hostname"
cat >"${MOUNT_POINT}/etc/hosts" <<EOF
127.0.0.1	localhost
127.0.1.1	$HOSTNAME
EOF

log "Criando usuário $USERNAME..."
chroot "$MOUNT_POINT" useradd -m -s /bin/bash -G sudo,plugdev,audio,video "$USERNAME"
echo "${USERNAME}:${USER_PASS}" | chroot "$MOUNT_POINT" chpasswd
echo "root:${ROOT_PASS}" | chroot "$MOUNT_POINT" chpasswd

log "Configurando rede..."
cat >"${MOUNT_POINT}/etc/network/interfaces" <<'EOF'
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
EOF

log "Gerando hostid..."
zgenhostid -f -o "${MOUNT_POINT}/etc/hostid"

log "✓ Sistema configurado"

# ETAPA 5: Bootloader
log "[5/6] Instalando bootloader..."

log "Instalando ZFSBootMenu..."
zbm_install "$part_esp" "$MOUNT_POINT" || error_exit "Falha ao instalar ZBM"

zbm_setup_fallback "$part_esp" "$MOUNT_POINT"

hostid=$(dd if="${MOUNT_POINT}/etc/hostid" bs=1 skip=0 count=4 2>/dev/null | od -A x -t x1 | head -1 | awk '{print $2$3$4$5}')
zbm_configure_zfs_properties "$POOL_NAME" "$hostid"

log "✓ Bootloader instalado"

# ETAPA 6: Finalização
log "[6/6] Finalizando..."

log "Desmontando sistemas virtuais..."
umount -l "${MOUNT_POINT}/run" 2>/dev/null || true
umount -l "${MOUNT_POINT}/sys" 2>/dev/null || true
umount -l "${MOUNT_POINT}/proc" 2>/dev/null || true
umount -l "${MOUNT_POINT}/dev" 2>/dev/null || true

log "Exportando pool ZFS..."
zpool export "$POOL_NAME" || error_exit "Falha ao exportar pool"

log "✓ Instalação concluída!"

echo
echo "================================"
echo "INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo "================================"
echo
echo "Remova a mídia de instalação e reinicie."
read -p "Reiniciar agora? (s/N): " reboot

if [[ "$reboot" =~ ^[Ss]$ ]]; then
	reboot
fi
