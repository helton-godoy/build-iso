#!/usr/bin/env bash
set -euo pipefail

echo "Verificando a nova estrutura de diretórios do projeto..."

DIRS=("docker/artifacts/logs" "docker/artifacts/dist" "docker/artifacts/build" "docker/artifacts/cache")
MISSING=0

for dir in "${DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "PASS: Diretório '$dir' existe."
    else
        echo "FAIL: Diretório '$dir' não encontrado."
        MISSING=$((MISSING + 1))
    fi
done

if [[ $MISSING -gt 0 ]]; then
    echo "Erro: $MISSING diretórios obrigatórios estão faltando."
    exit 1
fi

if [[ -f "docs/PROJECT_STRUCTURE.md" ]]; then
    echo "PASS: Documentação docs/PROJECT_STRUCTURE.md existe."
else
    echo "FAIL: Documentação docs/PROJECT_STRUCTURE.md não encontrada."
    exit 1
fi

echo "Estrutura do projeto validada com sucesso!"
exit 0
