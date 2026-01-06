#!/usr/bin/env bash
set -euo pipefail

echo "Iniciando teste de detecção de dependências da VM..."

# O script deve aceitar uma flag --check-deps e retornar 0 se tudo estiver ok
if ./scripts/test-iso.sh --check-deps; then
    echo "PASS: Dependências detectadas corretamente."
else
    echo "FAIL: Falha na detecção de dependências ou flag não suportada."
    exit 1
fi
