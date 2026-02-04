#!/usr/bin/env bash
set -euo pipefail

# Script para iniciar VM de teste com a ISO gerada e 4 discos virtuais (NAS simulation)

MODE=${1:-uefi}
# Encontra a ISO mais recente no diretório output
ISO_PATH=$(ls -t output/*.iso 2>/dev/null | head -n 1)

if [ -z "$ISO_PATH" ]; then
    echo "❌ Nenhuma ISO encontrada em output/. Execute o build primeiro."
    exit 1
fi

DISK_DIR="scripts/vm/disks"
VM_NAME="nas-test-$MODE"

# Garante que os discos existem
./scripts/vm/disks/create-nas-disks.sh

# Limpeza de VM anterior se existir
if virsh --connect qemu:///system list --all --name | grep -q "^$VM_NAME$"; then
    echo "⚠️  VM '$VM_NAME' já existe. Reiniciando..."
    virsh --connect qemu:///system destroy "$VM_NAME" >/dev/null 2>&1 || true
    virsh --connect qemu:///system undefine "$VM_NAME" --nvram >/dev/null 2>&1 || true
fi

echo "🚀 Iniciando VM NAS ($MODE) com 4 discos + ISO: $ISO_PATH"

# Monta a string de discos para o virt-install
DISK_ARGS="--disk path=$DISK_DIR/disk1.qcow2,bus=virtio \
           --disk path=$DISK_DIR/disk2.qcow2,bus=virtio \
           --disk path=$DISK_DIR/disk3.qcow2,bus=virtio \
           --disk path=$DISK_DIR/disk4.qcow2,bus=virtio"

BOOT_ARGS="loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.fd"
if [ "$MODE" != "uefi" ]; then
    BOOT_ARGS="hd,cdrom,menu=on"
fi

virt-install \
    --connect qemu:///system \
    --name "$VM_NAME" \
    --ram 4096 \
    --vcpus 2 \
    $DISK_ARGS \
    --cdrom "$ISO_PATH" \
    --boot "$BOOT_ARGS" \
    --network network=default,model=virtio \
    --security type=none \
    --serial pty \
    --console pty,target_type=serial \
    --graphics spice \
    --os-variant debian12 \
    --transient
