#!/usr/bin/env bash
set -euo pipefail

echo "Iniciando teste de validação de boot e ISO..."

# Deve falhar se a ISO não existir (simulando diretório vazio)
TEMP_DIST=$(mktemp -d)
set +o pipefail # Desativar temporariamente para capturar erro do script com grep
if DIST_DIR="$TEMP_DIST" ./scripts/test-iso.sh bios 2>&1 | grep -q "Nenhuma ISO encontrada"; then
    echo "PASS: Script detectou corretamente a falta de ISO."
else
    echo "FAIL: Script não falhou como esperado ou mensagem de erro incorreta."
    set -o pipefail
    rm -rf "$TEMP_DIST"
    exit 1
fi
set -o pipefail
rm -rf "$TEMP_DIST"

# Deve passar no dry-run BIOS mesmo sem ISO
if ./scripts/test-iso.sh --dry-run bios | grep -q "Legacy BIOS"; then
    echo "PASS: Dry-run BIOS funcionando."
else
    echo "FAIL: Dry-run BIOS não identificou modo correto."
    exit 1
fi
