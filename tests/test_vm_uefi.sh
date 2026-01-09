#!/usr/bin/env bash
set -euo pipefail

echo "Iniciando teste de refinamento UEFI..."

# Se o OVMF existe, o comando QEMU uefi deve incluir o drive pflash ou bios correspondente
OVMF_FOUND=""
for p in "/usr/share/OVMF/OVMF_CODE.fd" "/usr/share/ovmf/OVMF.fd" "/usr/share/qemu/OVMF.fd"; do
	if [[ -f ${p} ]]; then
		OVMF_FOUND="${p}"
		break
	fi
done

if [[ -n ${OVMF_FOUND} ]]; then
	OUTPUT=$(./tools/test-iso.sh --dry-run uefi)
	echo "DEBUG Output: ${OUTPUT}"
	if echo "${OUTPUT}" | grep -q "OVMF"; then
		echo "PASS: UEFI configurado com OVMF encontrado."
	else
		echo "FAIL: UEFI selecionado mas OVMF não encontrado no comando dry-run."
		exit 1
	fi
else
	echo "SKIP: OVMF não disponível no host para teste."
fi
