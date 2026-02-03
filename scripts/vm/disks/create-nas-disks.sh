#!/usr/bin/env bash
set -euo pipefail

# Cria discos virtuais para simular um ambiente NAS com ZFS

DISK_DIR="scripts/vm/disks"
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
