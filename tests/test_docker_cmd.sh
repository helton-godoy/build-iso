#!/usr/bin/env bash
set -euo pipefail

echo "Verificando funcionalidade do script de build e logs..."

# Executar um comando rápido (lb --version) para testar o pipeline
./scripts/build-iso-in-docker.sh lb --version > /dev/null

if [[ -f "docker/artifacts/logs/lb-build.log" ]]; then
    echo "PASS: Log docker/artifacts/logs/lb-build.log foi gerado."
else
    echo "FAIL: Log docker/artifacts/logs/lb-build.log não encontrado."
    exit 1
fi

# Verificar se o log contém um padrão de data/versão (formato live-build)
if grep -qE "[0-9]{8}" docker/artifacts/logs/lb-build.log; then
    echo "PASS: Conteúdo do log contém padrão de versão."
else
    echo "FAIL: Conteúdo do log não parece ser uma versão do live-build."
    cat docker/artifacts/logs/lb-build.log
    exit 1
fi

echo "Validação do script de build concluída com sucesso!"
exit 0
