#!/usr/bin/env bash
set -euo pipefail

# --- Logging Configuration ---
mkdir -p logs
LOG_FILE="logs/vm-setup.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "--- Setup Run: $(date --iso-8601=seconds) ---"

echo "🔧 Instalando dependências de virtualização..."
sudo apt-get update
sudo apt-get install -y \
	qemu-kvm \
	qemu-utils \
	qemu-system-x86 \
	libvirt-daemon-system \
	libvirt-clients \
	bridge-utils \
	virtinst \
	virt-viewer \
	ovmf # Essencial para o modo UEFI

# Garante que o usuário atual tenha permissão para gerenciar VMs
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

echo "✅ Ambiente pronto. Reinicie a sessão (ou execute 'newgrp libvirt') antes de prosseguir."
