#!/usr/bin/env bash
set -euo pipefail

echo "Iniciando teste de criação de disco virtual..."

DISK_FILE="test_disk.qcow2"
rm -f "$DISK_FILE"

# O script deve aceitar uma flag --create-disk <file> e criar o arquivo
if ./tools/test-iso.sh --create-disk "$DISK_FILE" --check-deps; then
    if [[ -f "$DISK_FILE" ]]; then
        echo "PASS: Disco virtual criado com sucesso."
        rm -f "$DISK_FILE"
    else
        echo "FAIL: O comando retornou sucesso mas o arquivo do disco não foi criado."
        exit 1
    fi
else
    echo "FAIL: Falha ao executar tools/test-iso.sh com --create-disk."
    exit 1
fi
