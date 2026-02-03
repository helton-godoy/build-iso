#!/bin/bash
VM_NAME="aurora-nas-node"
ISO_PATH="./output/live-image-amd64.hybrid.iso"
DISK_PATH="./vm/disks/aurora-disk.qcow2"

# Criar disco se não existir
[ -f "$DISK_PATH" ] || qemu-img create -f qcow2 "$DISK_PATH" 20G

sudo virt-install \
	--name "$VM_NAME" \
	--ram 4096 \
	--vcpus 2 \
	--disk path="$DISK_PATH",format=qcow2 \
	--cdrom "$ISO_PATH" \
	--network network=default,model=virtio \
	--channel unix,target_type=virtio,name=org.qemu.guest_agent.0 \
	--os-variant debian12 \
	--graphics none \
	--noautoconsole \
	--boot cdrom,hd
