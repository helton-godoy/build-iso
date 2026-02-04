#!/usr/bin/env bash
set -euo pipefail

# Script para iniciar VM via disco virtual
DISK_PATH="${1:-scripts/vm/disks/test-disk.qcow2}"

if [ ! -f "$DISK_PATH" ]; then
	echo "Erro: Disco não encontrado em $DISK_PATH"
	exit 1
fi

echo "Iniciando VM a partir do disco: $DISK_PATH"
# Comando básico de teste
kvm -m 2G -drive file="$DISK_PATH",format=qcow2 -bios /usr/share/ovmf/OVMF.fd
