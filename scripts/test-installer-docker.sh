#!/bin/bash
# Script para executar testes do instalador dentro de um container Docker
# Garante reprodutibilidade e isolamento do ambiente de teste.

set -euo pipefail

# Configurações
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_IMAGE="debian-trixie-zbm-tester"
TEST_CMD="/usr/bin/bats /app/tests/test_installer.bats"

# Cores
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}==> Preparando ambiente de teste em Docker...${NC}"

# Construir imagem de teste (rápida, baseada em debian:trixie)
# Instalamos apenas o necessário para rodar os testes: bash, bats e dependências básicas
docker build -t "${DOCKER_IMAGE}" - <<EOF
FROM debian:trixie-slim

# Evitar prompts interativos
ENV DEBIAN_FRONTEND=noninteractive

# Instalar BATS e dependências mínimas para os scripts
RUN apt-get update && apt-get install -y \
    bats \
    bash \
    coreutils \
    grep \
    sed \
    gawk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# O código será montado via volume, então não copiamos nada aqui
# Entrypoint padrão
CMD ["bash"]
EOF

echo -e "${GREEN}==> Executando testes...${NC}"

# Rodar os testes montando o diretório atual em /app
# --rm: Remove o container após o teste
# -v: Monta o projeto
docker run --rm \
	-v "${PROJECT_DIR}:/app" \
	-e TERM=xterm-256color \
	"${DOCKER_IMAGE}" \
	bash -c "${TEST_CMD}"

EXIT_CODE=$?

if [[ ${EXIT_CODE} -eq 0 ]]; then
	echo -e "${GREEN}==> Todos os testes passaram!${NC}"
else
	echo -e "\033[0;31m==> Falha nos testes (Exit Code: ${EXIT_CODE})${NC}"
fi

exit "${EXIT_CODE}"
