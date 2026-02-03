#!/usr/bin/env bash
set -euo pipefail

# Script para preparar o ambiente de teste com QEMU/KVM
echo "Instalando dependências de virtualização..."
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients bridge-utils virtinst ovmf

echo "Ambiente preparado!"
