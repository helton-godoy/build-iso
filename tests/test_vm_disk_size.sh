#!/usr/bin/env bash
set -euo pipefail

echo "Iniciando teste de tamanho do disco virtual..."

DISK_FILE="test_size_disk.qcow2"
rm -f "${DISK_FILE}"

# Deve criar um disco de 10GB
if ./tools/test-iso.sh --create-disk "${DISK_FILE}" --disk-size 10G --check-deps; then
	# Verificar tamanho usando qemu-img info
	SIZE=$(qemu-img info "${DISK_FILE}" | grep "virtual size" | awk '{print $3}')
	if [[ ${SIZE} == "10" ]]; then
		echo "PASS: Disco criado com tamanho correto (10G)."
		rm -f "${DISK_FILE}"
	else
		echo "FAIL: Tamanho incorreto detectado: ${SIZE} (esperado 10G)."
		qemu-img info "${DISK_FILE}"
		exit 1
	fi
else
	echo "FAIL: Falha ao executar tools/test-iso.sh com --disk-size."
	exit 1
fi
