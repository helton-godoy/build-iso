#!/usr/bin/env bash
set -euo pipefail

# --- Logging Configuration ---
mkdir -p logs
LOG_FILE="logs/vm-start-test-${1:-uefi}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "--- Run: $(date --iso-8601=seconds) ---"

# Script para iniciar VM de teste com a ISO gerada e 4 discos virtuais (NAS simulation)

# 1. Define o modo (uefi ou bios)
MODE=${1:-uefi}
VM_NAME="nas-test-$MODE"
DISK_DIR="scripts/vm/disks/$MODE"
SOCKET_PATH="/tmp/${VM_NAME}.sock"
ISO_PATH=$(ls -t output/*.iso 2>/dev/null | head -n 1)

if [ -z "$ISO_PATH" ]; then
	echo "❌ Nenhuma ISO encontrada em output/. Execute o build primeiro."
	exit 1
fi

# 2. Garante diretórios de disco únicos por modo
mkdir -p "$DISK_DIR"

# 3. Limpeza de VM anterior se existir (Idempotência Total)
if virsh --connect qemu:///system list --all --name | grep -q "^$VM_NAME$"; then
	echo "
		⚠️  VM '$VM_NAME' já existe. 
		🧹 Limpando ambiente anterior para '$VM_NAME'...
		"

	# Força o desligamento (destroy) e remove a definição (undefine)
	# --nvram remove variáveis UEFI e --remove-all-storage apaga os discos antigos vinculados
	virsh --connect qemu:///system destroy "$VM_NAME" >/dev/null 2>&1 || true
	virsh --connect qemu:///system undefine "$VM_NAME" --nvram --remove-all-storage >/dev/null 2>&1 || true
fi

# 4. Recriação dos discos específicos para esta execução
# Aqui assumimos que seu script de criação aceita o diretório como argumento
mkdir -p "$DISK_DIR"

echo "💾 Criando 4 discos de 10GB para o Pool ZFS..."
for i in {1..4}; do
	if [ ! -f "$DISK_DIR/disk$i.qcow2" ]; then
		qemu-img create -f qcow2 "$DISK_DIR/disk$i.qcow2" 10G
		echo "   -> Criado: $DISK_DIR/disk$i.qcow2"
	else
		echo "   -> Já existe: $DISK_DIR/disk$i.qcow2"
	fi
done
echo "✅ Discos prontos em $DISK_DIR"

echo "🚀 Iniciando VM NAS ($MODE) com 4 discos + ISO: $ISO_PATH"

# 5. Configuração de Discos (usando o diretório específico do modo)
# Monta a string de discos para o virt-install
DISK_ARGS="--disk path=$DISK_DIR/disk1.qcow2,bus=virtio \
           --disk path=$DISK_DIR/disk2.qcow2,bus=virtio \
           --disk path=$DISK_DIR/disk3.qcow2,bus=virtio \
           --disk path=$DISK_DIR/disk4.qcow2,bus=virtio"

# 6. Diferenciação de Boot entre BIOS e UEFI
if [ "$MODE" = "uefi" ]; then
	BOOT_OPTS="uefi"
else
	# Configuração explícita para BIOS (Legacy)
	BOOT_OPTS="hd,cdrom,menu=on"
fi

echo "🚀 Iniciando VM '$VM_NAME' ($MODE)"
echo "📡 Socket serial para o Agente: $SOCKET_PATH"

# 7. Execução do virt-install otimizado para Agentes
virt-install \
	--connect qemu:///system \
	--name "$VM_NAME" \
	--ram 4096 \
	--vcpus 2 \
	$DISK_ARGS \
	--cdrom "$ISO_PATH" \
	--boot "$BOOT_OPTS" \
	--network network=default,model=virtio \
	--graphics spice \
	--os-variant debian12 \
	--noautoconsole \
	--transient \
	--serial unix,path="$SOCKET_PATH",mode=bind \
	--console pty,target_type=serial

echo "✅ VM '$VM_NAME' iniciada com sucesso!"
