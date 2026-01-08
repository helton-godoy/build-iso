#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# build-iso-in-docker.sh
# 
# Gerencia a construção da ISO Debian Live dentro de um container Docker.
# ==============================================================================

# Cores e Estilos
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_CYAN='\033[38;5;39m'
readonly C_GREEN='\033[32m'
readonly C_RED='\033[31m'

# Nome da Imagem Docker
readonly IMAGE_NAME="debian-iso-builder"
readonly DOCKER_BUILD_CONTEXT="docker/tools"

# Diretórios (Host)
readonly DOCKER_DIR="docker"
readonly WORK_DIR_HOST="$DOCKER_DIR/work"
readonly DIST_DIR_HOST="$DOCKER_DIR/dist"
readonly LOG_DIR_HOST="$DOCKER_DIR/logs"
readonly CACHE_DIR_HOST="$WORK_DIR_HOST/cache"

# Diretórios de Entrada (Source)
readonly CONFIG_SRC="$DOCKER_DIR/config"
readonly INCLUDE_SRC="include"
readonly AUTO_SRC="$DOCKER_DIR/auto"

# Funções de logging
log_info()  { printf "${C_CYAN}ℹ %s${C_RESET}\n" "$*"; }
log_ok()    { printf "${C_GREEN}✔ %s${C_RESET}\n" "$*"; }
log_error() { printf "${C_RED}${C_BOLD}✖ %s${C_RESET}\n" "$*"; exit 1; }

function prepare_dirs() {
    mkdir -p "$WORK_DIR_HOST" "$DIST_DIR_HOST" "$LOG_DIR_HOST" "$CACHE_DIR_HOST"
}

function clean() {
    log_info "Limpando artefatos de build em $DOCKER_DIR..."
    rm -rf "$WORK_DIR_HOST" "$DIST_DIR_HOST" "$LOG_DIR_HOST"
    log_ok "Limpeza concluída."
}

function build() {
    prepare_dirs
    log_info "Iniciando Pipeline de Build da ISO..."

    # 1. Construir a imagem do Builder
    log_info "Construindo imagem Docker ($IMAGE_NAME)..."
    if ! docker build -t "$IMAGE_NAME" "$DOCKER_BUILD_CONTEXT" > "$LOG_DIR_HOST/docker-build.log" 2>&1; then
        log_error "Falha ao construir imagem Docker. Veja logs em: $LOG_DIR_HOST/docker-build.log"
    fi

    # 2. Executar Build
    log_info "Executando build no container..."
    
    # Exportamos as variáveis para o container via environment
    # O script interno agora assume que o projeto está em /work e o workspace em /work/docker/work
    local inner_script
    inner_script=$(cat <<'EOF'
set -e
PROJECT_ROOT="/work"
BUILD_WS="$PROJECT_ROOT/$WORK_DIR"
CONFIG_SRC_ABS="$PROJECT_ROOT/$CONFIG_DIR"
INCLUDE_SRC_ABS="$PROJECT_ROOT/$INCLUDE_DIR"
AUTO_SRC_ABS="$PROJECT_ROOT/$AUTO_DIR"

log() { echo "   -> $1"; }

log "Preparando workspace em $BUILD_WS..."
# Limpeza controlada do workspace para garantir estado limpo mas manter cache
rm -rf "$BUILD_WS/config" "$BUILD_WS/auto"
mkdir -p "$BUILD_WS/config/includes.chroot"

# Importar Configurações
if [[ -d "$CONFIG_SRC_ABS" ]]; then
    log "Importando $CONFIG_DIR..."
    cp -r "$CONFIG_SRC_ABS"/* "$BUILD_WS/config/"
fi

# Importar Includes (Overlay)
if [[ -d "$INCLUDE_SRC_ABS" ]]; then
    log "Aplicando overlay de include/..."
    cp -r "$INCLUDE_SRC_ABS"/* "$BUILD_WS/config/includes.chroot/"
fi

# Importar Auto (Scripts de automação)
if [[ -d "$AUTO_SRC_ABS" ]]; then
    log "Importando scripts auto/..."
    cp -r "$AUTO_SRC_ABS" "$BUILD_WS/"
fi

cd "$BUILD_WS"

# Configurar persistência de cache se existir
if [[ -d "$PROJECT_ROOT/$CACHE_DIR" ]]; then
    ln -snf "$PROJECT_ROOT/$CACHE_DIR" cache
fi

# CRITICAL: Inicializar configuração se não houver auto/config
# Isso gera os markers em .build/ que o lb build exige
log "Executando lb config..."
lb config

log "Executando lb build (pode demorar)..."
lb build

# Exportar resultados
log "Exportando artefatos para $DIST_DIR..."
mv *.iso "$PROJECT_ROOT/$DIST_DIR/" 2>/dev/null || true
mv *.packages "$PROJECT_ROOT/$DIST_DIR/" 2>/dev/null || true
mv *.buildlog "$PROJECT_ROOT/$LOG_DIR/" 2>/dev/null || true
EOF
)

    # Executa o container passando os caminhos como variáveis de ambiente
    if docker run --rm --privileged \
        -v "$(pwd):/work" \
        -e WORK_DIR="$WORK_DIR_HOST" \
        -e DIST_DIR="$DIST_DIR_HOST" \
        -e LOG_DIR="$LOG_DIR_HOST" \
        -e CACHE_DIR="$CACHE_DIR_HOST" \
        -e CONFIG_DIR="$CONFIG_SRC" \
        -e INCLUDE_DIR="$INCLUDE_SRC" \
        -e AUTO_DIR="$AUTO_SRC" \
        "$IMAGE_NAME" \
        bash -c "$inner_script" 2>&1 | tee "$LOG_DIR_HOST/lb-execution.log"; then
        
        log_ok "Build concluído com sucesso!"
    else
        log_error "Build falhou. Verifique os detalhes em: $LOG_DIR_HOST/lb-execution.log"
    fi

    # 3. Ajustar Permissões (Docker roda como root)
    log_info "Ajustando permissões..."
    docker run --rm --privileged -v "$(pwd):/work" "$IMAGE_NAME" \
        chown -R "$(id -u):$(id -g)" "/work/$DOCKER_DIR"
}

case "${1:-}" in
    --clean) clean ;;
    --build|*) build ;;
esac
