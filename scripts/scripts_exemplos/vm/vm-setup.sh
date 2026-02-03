#!/bin/bash
# Configurações da VM Aurora NAS
VM_NAME="aurora-nas-node"
ISO_PATH="./output/live-image-amd64.hybrid.iso"
DISK_PATH="./vm/disks/aurora-disk.qcow2"
RAM=4096
CPUS=2

# 1. Instalar dependências no Host Debian (se necessário)
sudo apt update && sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst bridge-utils

# 2. Preparar diretório de armazenamento
mkdir -p ./vm/disks

# 3. Criar disco rígido virtual (formato QCOW2)
if [ ! -f "$DISK_PATH" ]; then
	echo "Criando novo disco virtual de 20GB..."
	qemu-img create -f qcow2 "$DISK_PATH" 20G
else
	echo "Disco virtual já existe em $DISK_PATH"
fi

# 4. Iniciar instalação via virt-install
# --graphics none + --console: permite ver o boot no terminal (útil para CI)
# --network bridge=virbr0: usa a rede padrão do libvirt
echo "Iniciando VM a partir da ISO..."
sudo virt-install \
	--name "$VM_NAME" \
	--ram "$RAM" \
	--vcpus "$CPUS" \
	--os-variant debian12 \
	--disk path="$DISK_PATH",format=qcow2 \
	--cdrom "$ISO_PATH" \
	--network bridge=virbr0 \
	--graphics none \
	--console pty,target_type=serial \
	--boot cdrom,hd,menu=on \
	--noautoconsole

echo "### VM $VM_NAME criada com sucesso! ###"
echo "Para visualizar o console, use: virsh console $VM_NAME"
