#!/bin/bash
set -euo pipefail

# Configurações
ISO_DIR="output"
VM_DISK="test-disk.qcow2"
VM_DISK_SIZE="20G"
OVMF_VARS="OVMF_VARS.fd"
OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"

# Encontrar arquivo OVMF_CODE
if [[ ! -f ${OVMF_CODE} ]]; then
	if [[ -f /usr/share/ovmf/OVMF.fd ]]; then
		OVMF_CODE="/usr/share/ovmf/OVMF.fd"
	elif [[ -f /usr/share/qemu/OVMF.fd ]]; then
		OVMF_CODE="/usr/share/qemu/OVMF.fd"
	else
		echo "AVISO: Firmware UEFI (OVMF) não encontrado. O boot pode falhar em modo UEFI."
	fi
fi

# Encontrar a ISO mais recente
# shellcheck disable=SC2012
ISO_FILE=$(ls -t "${ISO_DIR}"/*.iso 2>/dev/null | head -n 1)

if [[ -z ${ISO_FILE} ]]; then
	echo "ERRO: Nenhuma ISO encontrada em ${ISO_DIR}"
	exit 1
fi

echo "==> Testando ISO: ${ISO_FILE}"

# Criar disco se não existir
if [[ ! -f ${VM_DISK} ]]; then
	echo "==> Criando disco virtual de ${VM_DISK_SIZE}..."
	qemu-img create -f qcow2 "${VM_DISK}" "${VM_DISK_SIZE}"
fi

# Copiar vars do OVMF para local se necessário (para persistência de variáveis EFI)
if [[ ! -f ${OVMF_VARS} ]] && [[ -f /usr/share/OVMF/OVMF_VARS.fd ]]; then
	cp /usr/share/OVMF/OVMF_VARS.fd "${OVMF_VARS}"
fi

# Construir argumentos do QEMU
QEMU_ARGS=(
	"-m" "4G"
	"-smp" "4"
	"-enable-kvm"
	"-cpu" "host"
	"-drive" "file=${ISO_FILE},media=cdrom"
	"-drive" "file=${VM_DISK},format=qcow2"
	"-net" "nic,model=virtio"
	"-net" "user"
	"-vga" "virtio"
	"-display" "gtk,gl=on"
	"-usb"
	"-device" "usb-tablet"
)

# Adicionar suporte UEFI se disponível
if [[ -f ${OVMF_CODE} ]]; then
	echo "==> Modo UEFI ativado"
	QEMU_ARGS+=(-drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}")
	if [[ -f ${OVMF_VARS} ]]; then
		QEMU_ARGS+=(-drive "if=pflash,format=raw,file=${OVMF_VARS}")
	fi
else
	echo "==> Modo BIOS Legacy (UEFI não encontrado)"
fi

echo "==> Iniciando QEMU..."
echo "    [DICA] Para liberar o mouse: Pressione Ctrl+Alt+G"
echo "    [DICA] Para sair: Feche a janela ou pressione Ctrl+A depois X (se no terminal)"
exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
