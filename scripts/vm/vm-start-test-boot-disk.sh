#!/usr/bin/env bash
# =============================================================================
# @DEV_SCRIPT: vm-start-test-boot-disk - Inicia VM a partir de disco instalado
# @DEV_CATEGORY: vm
# @DEV_DEP: virt-install, virsh, qemu-img
# @DEV_INPUT: $1=disk_path, -f={uefi|bios}, -m=memory, -c=cpus
# @DEV_OUTPUT: /tmp/{vm-name}.sock
# @DEV_MAKEFILE: vm-boot-disk-uefi, vm-boot-disk-bios
# =============================================================================
set -euo pipefail

# =============================================================================
# Script para iniciar VM a partir de disco com sistema instalado
# =============================================================================
# Suporta boot de discos virtuais com Debian + ZFS já instalado
# =============================================================================

# --- Logging Configuration ---
mkdir -p logs
LOG_FILE="logs/vm-boot-disk-${1:-uefi}-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "--- Run: $(date --iso-8601=seconds) ---"

# --- Funções de Ajuda ---
show_help() {
	cat <<EOF
Uso: $0 [opções] <caminho-do-disco>

Inicia uma VM QEMU/KVM a partir de um disco virtual com sistema instalado.

ARGUMENTOS:
  <caminho-do-disco>    Caminho para o arquivo de disco (qcow2, raw, vmdk)

OPÇÕES:
  -f, --firmware <tipo>  Tipo de firmware: uefi (padrão) ou bios
  -m, --memory <tamanho>  Memória da VM (padrão: 4G)
  -c, --cpus <número>     Número de CPUs (padrão: 2)
  -n, --name <nome>       Nome da VM (padrão: disk-boot-<firmware>)
  -h, --help              Mostra esta ajuda

EXEMPLOS:
  # Boot UEFI com disco específico
  $0 scripts/vm/disks/uefi/installed-system.qcow2

  # Boot BIOS com configuração customizada
  $0 -f bios -m 2G -c 1 scripts/vm/disks/bios/installed-system.qcow2

  # Boot com nome customizado
  $0 -n meu-teste scripts/vm/disks/uefi/installed-system.qcow2

NOTAS:
  - O disco deve conter um sistema instalado (Debian + ZFS)
  - Para UEFI, o disco deve ter partição ESP com bootloader
  - Para BIOS, o disco deve ter MBR/GRUB instalado
  - Console serial disponível em /tmp/<nome-vm>.sock
EOF
}

# --- Parse de Argumentos ---
FIRMWARE="uefi"
MEMORY="4G"
CPUS=2
VM_NAME=""
DISK_PATH=""

while [[ $# -gt 0 ]]; do
	case $1 in
	-f | --firmware)
		FIRMWARE="$2"
		shift 2
		;;
	-m | --memory)
		MEMORY="$2"
		shift 2
		;;
	-c | --cpus)
		CPUS="$2"
		shift 2
		;;
	-n | --name)
		VM_NAME="$2"
		shift 2
		;;
	-h | --help)
		show_help
		exit 0
		;;
	-*)
		echo "❌ Opção desconhecida: $1"
		show_help
		exit 1
		;;
	*)
		if [ -z "$DISK_PATH" ]; then
			DISK_PATH="$1"
		else
			echo "❌ Múltiplos caminhos de disco especificados"
			exit 1
		fi
		shift
		;;
	esac
done

# --- Validações ---
# Valida firmware
if [[ ! "$FIRMWARE" =~ ^(uefi|bios)$ ]]; then
	echo "❌ Firmware inválido: $FIRMWARE (deve ser 'uefi' ou 'bios')"
	exit 1
fi

# Valida caminho do disco
if [ -z "$DISK_PATH" ]; then
	echo "❌ Caminho do disco não especificado"
	show_help
	exit 1
fi

# Valida existência do disco
if [ ! -f "$DISK_PATH" ]; then
	echo "❌ Disco não encontrado: $DISK_PATH"
	echo ""
	echo "💡 Dica: Verifique se o caminho está correto ou crie um disco de teste:"
	echo "   qemu-img create -f qcow2 $DISK_PATH 20G"
	exit 1
fi

# Valida formato do disco
DISK_FORMAT=$(qemu-img info "$DISK_PATH" 2>/dev/null | grep "file format" | awk '{print $3}')
if [ -z "$DISK_FORMAT" ]; then
	echo "❌ Não foi possível determinar o formato do disco: $DISK_PATH"
	exit 1
fi

echo "📋 Formato do disco detectado: $DISK_FORMAT"

# Valida tamanho mínimo do disco (1GB)
DISK_SIZE_BYTES=$(qemu-img info "$DISK_PATH" 2>/dev/null | grep "virtual size" | grep -oP '\d+')
if [ "$DISK_SIZE_BYTES" -lt 1073741824 ]; then
	echo "⚠️  Aviso: Disco muito pequeno (< 1GB). O boot pode falhar."
fi

# Define nome da VM se não especificado
if [ -z "$VM_NAME" ]; then
	VM_NAME="disk-boot-$FIRMWARE"
fi

SOCKET_PATH="/tmp/${VM_NAME}.sock"

# --- Limpeza de VM anterior (Idempotência) ---
if virsh --connect qemu:///system list --all --name | grep -q "^${VM_NAME}$"; then
	echo ""
	echo "⚠️  VM '$VM_NAME' já existe."
	echo "🧹 Limpando ambiente anterior..."
	echo ""

	virsh --connect qemu:///system destroy "$VM_NAME" >/dev/null 2>&1 || true
	virsh --connect qemu:///system undefine "$VM_NAME" --nvram >/dev/null 2>&1 || true
fi

# --- Configuração de Boot ---
if [ "$FIRMWARE" = "uefi" ]; then
	BOOT_OPTS="uefi"
	BOOT_ORDER="hd"
else
	# Configuração para BIOS (Legacy)
	BOOT_OPTS="hd,menu=on"
	BOOT_ORDER="hd"
fi

# --- Exibição de Informações ---
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🚀 Iniciando VM a partir de disco instalado"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Nome da VM:      $VM_NAME"
echo "  Firmware:        $FIRMWARE"
echo "  Disco:           $DISK_PATH"
echo "  Formato:         $DISK_FORMAT"
echo "  Memória:         $MEMORY"
echo "  CPUs:            $CPUS"
echo "  Socket serial:   $SOCKET_PATH"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# --- Inicialização da VM ---
virt-install \
	--connect qemu:///system \
	--name "$VM_NAME" \
	--ram "$MEMORY" \
	--vcpus "$CPUS" \
	--disk path="$DISK_PATH",format="$DISK_FORMAT",bus=virtio \
	--boot "$BOOT_OPTS" \
	--network network=default,model=virtio \
	--graphics spice \
	--os-variant debian12 \
	--noautoconsole \
	--transient \
	--serial unix,path="$SOCKET_PATH",mode=bind \
	--console pty,target_type=serial

echo ""
echo "✅ VM '$VM_NAME' iniciada com sucesso!"
echo ""
echo "📡 Para conectar ao console serial:"
echo "   nc -U $SOCKET_PATH"
echo ""
echo "📝 Ou use o script de conexão:"
echo "   ./scripts/vm/vm-connent-socket.sh $VM_NAME"
echo ""
echo "📋 Logs desta sessão: $LOG_FILE"
