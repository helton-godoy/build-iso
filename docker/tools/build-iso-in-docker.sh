#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# build-iso-in-docker.sh
# 
# Este script executa o processo de construção da ISO Debian Live dentro de um
# container Docker.
# ==============================================================================

# --- Configuração de Caminhos (Baseado na estrutura da raiz do projeto) ---
DOCKER_BUILD_CONTEXT="docker/tools"

# Diretórios de Saída e Trabalho (Host)
WORK_DIR_HOST="docker/work"       # Onde o build (chroot) acontece
DIST_DIR_HOST="docker/dist"       # Onde a ISO final será salva
LOG_DIR_HOST="docker/logs"        # Onde os logs serão salvos
CACHE_DIR_HOST="docker/cache"     # Cache de pacotes (opcional, para acelerar)

# Diretórios de Entrada (Source)
CONFIG_SRC="docker/config"
AUTO_SRC="docker/auto"
INCLUDE_SRC="include"

# Nome da Imagem Docker
IMAGE_NAME="debian-iso-builder"

# --- Preparação ---

# Garantir que diretórios existam no host
mkdir -p "$WORK_DIR_HOST" "$DIST_DIR_HOST" "$LOG_DIR_HOST" "$CACHE_DIR_HOST"

echo "=== Iniciando Pipeline de Build da ISO ==="

# 1. Construir a imagem do Builder
echo "[1/4] Construindo imagem Docker ($IMAGE_NAME)..."
docker build -t "$IMAGE_NAME" "$DOCKER_BUILD_CONTEXT" > "$LOG_DIR_HOST/docker-build.log" 2>&1
echo "      Log: $LOG_DIR_HOST/docker-build.log"

# 2. Executar Build
echo "[2/4] Executando build no container..."

# Script interno que roda dentro do container
BUILD_CMD="
set -e

# Caminhos internos (Mapeados em /work)
PROJECT_ROOT=\"/work\"
BUILD_WS=\"/work/$WORK_DIR_HOST\"
CACHE_DIR=\"/work/$CACHE_DIR_HOST\"

echo '   -> Preparando workspace em: ' \$BUILD_WS

# Criar estrutura básica
mkdir -p \$BUILD_WS/config/includes.chroot

# ------------------------------------------------------------------------------
# IMPORTAÇÃO DE CONFIGURAÇÕES
# ------------------------------------------------------------------------------

# 1. Copiar 'config' (arquivos de configuração do live-build)
echo '   -> Importando docker/config...'
if [ -d \"\$PROJECT_ROOT/$CONFIG_SRC\" ]; then
    cp -r \$PROJECT_ROOT/$CONFIG_SRC/* \$BUILD_WS/config/
fi

# 2. Copiar 'auto' (scripts de automação do lb config)
#    IMPORTANTE: Esta pasta contém os scripts 'config', 'build', 'clean' que
#    definem os parâmetros do build. Ela NÃO é gerada automaticamente.
echo '   -> Importando docker/auto...'
if [ -d \"\$PROJECT_ROOT/$AUTO_SRC\" ]; then
    cp -r \$PROJECT_ROOT/$AUTO_SRC \$BUILD_WS/
fi

# 3. Aplicar Overlay de 'include' (arquivos extras da ISO)
echo '   -> Aplicando overlay de include/...'
if [ -d \"\$PROJECT_ROOT/$INCLUDE_SRC\" ]; then
    # Copia tudo de include/ para config/includes.chroot/
    cp -r \$PROJECT_ROOT/$INCLUDE_SRC/* \$BUILD_WS/config/includes.chroot/
fi

# ------------------------------------------------------------------------------
# EXECUÇÃO DO BUILD
# ------------------------------------------------------------------------------

cd \$BUILD_WS

# Configurar Cache (Symlink para persistência)
mkdir -p \$CACHE_DIR
ln -snf \$CACHE_DIR cache

# Executar 'lb build'
# O live-build usará a pasta 'auto' e 'config' que acabamos de preparar.
echo '   -> Executando lb build (pode demorar)...'
lb build

# ------------------------------------------------------------------------------
# FINALIZAÇÃO
# ------------------------------------------------------------------------------

# Mover artefatos para docker/dist
echo '   -> Movendo artefatos para $DIST_DIR_HOST...'
mv *.iso \$PROJECT_ROOT/$DIST_DIR_HOST/ 2>/dev/null || echo '      AVISO: Nenhuma ISO encontrada.'
mv *.packages \$PROJECT_ROOT/$DIST_DIR_HOST/ 2>/dev/null || true
mv *.buildlog \$PROJECT_ROOT/$LOG_DIR_HOST/ 2>/dev/null || true

# Limpar workspace (opcional, para economizar espaço, mas mantemos para debug por enquanto)
# rm -rf \$BUILD_WS/*
"

# Executar container
docker run --rm --privileged \
    -v "$(pwd):/work" \
    "$IMAGE_NAME" \
    bash -c "$BUILD_CMD" 2>&1 | tee "$LOG_DIR_HOST/lb-execution.log"

EXIT_CODE=${PIPESTATUS[0]}

# 3. Corrigir Permissões
# O Docker roda como root, então os arquivos gerados (ISO, logs, work) pertencem ao root.
# Mudamos para o usuário atual do host.
echo "[3/4] Ajustando permissões..."
docker run --rm --privileged \
    -v "$(pwd):/work" \
    "$IMAGE_NAME" \
    chown -R "$(id -u):$(id -g)" \
        "/work/$WORK_DIR_HOST" \
        "/work/$DIST_DIR_HOST" \
        "/work/$LOG_DIR_HOST" \
        "/work/$CACHE_DIR_HOST"

if [ $EXIT_CODE -eq 0 ]; then
    echo "=== SUCESSO ==="
    echo "ISO disponível em: $DIST_DIR_HOST"
else
    echo "=== FALHA ==="
    echo "Verifique os logs em: $LOG_DIR_HOST"
fi

exit $EXIT_CODE
