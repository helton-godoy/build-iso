#!/usr/bin/env bash
#
# setup-opencode-antigravity.sh
# Script de configuração do OpenCode para exibir modelos do plugin Antigravity
#
# Este script configura automaticamente o OpenCode para listar todos os modelos
# Gemini e Claude disponíveis via proxy Antigravity.
#
# Uso:
#   ./setup-opencode-antigravity.sh [--force] [--dry-run]
#
# Opções:
#   --force      Sobrescreve configuração existente
#   --dry-run    Apenas mostra as ações sem executar
#

set -euo pipefail

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Funções de logging
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Variáveis
FORCE_DUP=${FORCE_DUP:-false}
DRY_RUN=${DRY_RUN:-false}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SOURCE="${SCRIPT_DIR}/.opencode/opencode-models-antigravity.json"
CONFIG_TARGET="${HOME}/.config/opencode/opencode.json"
OPENCODE_CONFIG_DIR="${HOME}/.config/opencode"

# Função de help
show_help() {
  cat << EOF
$(basename "$0") - Configurar OpenCode para Modelos Antigravity

USO:
    $(basename "$0") [OPÇÕES]

DESCRIÇÃO:
    Este script configura automaticamente o OpenCode para exibir todos os modelos
    Gemini e Claude disponíveis através do plugin Antigravity proxy.

    Ações realizadas:
    1. Criar diretório de configuração do OpenCode
    2. Copiar configuração de modelos para ~/.config/opencode/opencode.json
    3. Verificar/instalar dependências do plugin
    4. Validar configuração

OPÇÕES:
    --force      Sobrescrever configuração existente sem perguntar
    --dry-run    Mostrar ações sem executar realmente
    -h, --help   Mostrar esta ajuda

EXEMPLOS:
    $(basename "$0")                  # Executar configuração interativa
    $(basename "$0") --force           # Sobrescrever configuração existente
    $(basename "$0") --dry-run        # Verificar o que seria feito

ARQUIVO DE CONFIGURAÇÃO:
    Source: ${CONFIG_SOURCE}
    Target: ${CONFIG_TARGET}

MODELOS CONFIGURADOS:
    - gemini-3-pro-preview       (Gemini 3 Pro com reasoning avançado)
    - gemini-3-flash            (Gemini 3 Flash otimizado para velocidade)
    - gemini-2.5-flash-lite    (Gemini 2.5 Flash Lite, extremamente leve)
    - gemini-claude-sonnet-4-5  (Claude Sonnet 4.5 via proxy)
    - gemini-claude-sonnet-4-5-thinking (Claude Sonnet com reasoning)
    - gemini-claude-opus-4-5-thinking-4k   (Claude Opus, thinking budget 4K)
    - gemini-claude-opus-4-5-thinking-16k  (Claude Opus, thinking budget 16K)
    - gemini-claude-opus-4-5-thinking-32k  (Claude Opus, thinking budget 32K)

APÓS A CONFIGuração:
    Execute 'opencode models' para listar todos os modelos disponíveis.
    Use '/model <nome>' para alternar entre modelos.

Para mais informações, consulte:
    .opencode/opencode-models-antigravity.json
EOF
}

# Parse de argumentos
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        FORCE_DUP=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        log_error "Opção desconhecida: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# Função para executar comandos (respeitando dry-run)
run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Executaria: $*"
    return 0
  fi
  "$@"
}

# Verificar pré-requisitos
check_prerequisites() {
  log_info "Verificando pré-requisitos..."

  # Verificar se o arquivo fonte existe
  if [[ ! -f "$CONFIG_SOURCE" ]]; then
    log_error "Arquivo de configuração não encontrado: $CONFIG_SOURCE"
    log_info "Certifique-se de estar no diretório raiz do projeto."
    exit 1
  fi

  # Verificar se o OpenCode está instalado (opcional)
  if command -v opencode &> /dev/null; then
    log_success "OpenCode encontrado: $(which opencode)"
  else
    log_warn "OpenCode não encontrado no PATH. Instale o OpenCode primeiro."
    log_info "Download: https://opencode.ai/download"
  fi

  # Verificar se o plugin está disponível (opcional)
  if [[ -d "${SCRIPT_DIR}/.opencode/opencode-google-antigravity-auth" ]]; then
    log_success "Plugin Antigravity encontrado no projeto"
  else
    log_warn "Plugin opencode-google-antigravity-auth não encontrado no projeto"
    log_info "O plugin é necessário para autenticação com os modelos Gemini/Claude"
  fi

  log_success "Pré-requisitos verificados"
}

# Criar diretório de configuração
create_config_dir() {
  log_info "Criando diretório de configuração..."

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Criaria diretório: $OPENCODE_CONFIG_DIR"
    return 0
  fi

  mkdir -p "$OPENCODE_CONFIG_DIR"
  chmod 700 "$OPENCODE_CONFIG_DIR"
  log_success "Diretório criado: $OPENCODE_CONFIG_DIR"
}

# Copiar configuração de modelos
copy_model_config() {
  log_info "Copiando configuração de modelos..."

  # Verificar se arquivo já existe
  if [[ -f "$CONFIG_TARGET" ]]; then
    if [[ "$FORCE_DUP" == true ]]; then
      log_info "Sobrescrevendo configuração existente (--force)"
      run_cmd cp "$CONFIG_SOURCE" "$CONFIG_TARGET"
    else
      log_warn "Arquivo de configuração já existe: $CONFIG_TARGET"
      log_info "Use --force para sobrescrever ou remova manualmente:"
      log_info "  rm $CONFIG_TARGET"
      return 1
    fi
  else
    run_cmd cp "$CONFIG_SOURCE" "$CONFIG_TARGET"
  fi

  if [[ "$DRY_RUN" != true ]]; then
    chmod 600 "$CONFIG_TARGET"
    log_success "Configuração copiada para: $CONFIG_TARGET"
  fi
}

# Configurar plugin do Google Antigravity (opcional)
setup_google_plugin() {
  local plugin_source="${SCRIPT_DIR}/.opencode/opencode-google-antigravity-auth"
  local plugin_target="${HOME}/.opencode/opencode-google-antigravity-auth"

  if [[ ! -d "$plugin_source" ]]; then
    log_warn "Plugin source não encontrado, pulando configuração do plugin"
    return 0
  fi

  log_info "Configurando plugin Google Antigravity..."

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Copiaria plugin para: $plugin_target"
    return 0
  fi

  # Criar diretório do plugin se não existir
  mkdir -p "${HOME}/.opencode"

  # Copiar plugin (apenas arquivos necessários)
  run_cmd cp -r "$plugin_source" "$plugin_target"
  chmod -R u+w "$plugin_target" 2>/dev/null || true

  log_success "Plugin copiado para: $plugin_target"
}

# Validar configuração
validate_config() {
  log_info "Validando configuração..."

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Validaria configuração..."
    return 0
  fi

  # Verificar se arquivo JSON é válido
  if command -v python3 &> /dev/null; then
    if python3 -c "import json; json.load(open('$CONFIG_TARGET'))" 2>/dev/null; then
      log_success "Arquivo JSON válido"
    else
      log_error "Arquivo JSON inválido"
      return 1
    fi
  elif command -v jq &> /dev/null; then
    if jq empty "$CONFIG_TARGET" 2>/dev/null; then
      log_success "Arquivo JSON válido"
    else
      log_error "Arquivo JSON inválido"
      return 1
    fi
  else
    log_warn "python3/jq não encontrado, pulando validação JSON"
  fi

  # Verificar schema
  if grep -q '"$schema"' "$CONFIG_TARGET"; then
    log_success "Schema encontrado no arquivo"
  else
    log_warn "Schema não encontrado, pode haver incompatibilidade de versão"
  fi

  # Verificar modelos
  local model_count
  if command -v python3 &> /dev/null; then
    model_count=$(python3 -c "import json; print(len(json.load(open('$CONFIG_TARGET'))))" 2>/dev/null || echo "0")
  else
    model_count=$(grep -c '^{' "$CONFIG_TARGET" || echo "0")
  fi
  log_success "$model_count modelos configurados"

  log_success "Configuração validada"
}

# Mostrar instruções de uso
show_usage_instructions() {
  echo ""
  log_success "==========================================="
  log_success "  Configuração do OpenCode concluída!"
  log_success "==========================================="
  echo ""
  echo -e "${BLUE}Próximos passos:${NC}"
  echo ""
  echo "1. Reinicie o OpenCode para carregar os novos modelos"
  echo ""
  echo "2. Execute o comando para listar os modelos:"
  echo "   ${GREEN}opencode models${NC}"
  echo ""
  echo "3. Para selecionar um modelo específico:"
  echo "   ${GREEN}/model gemini-3-flash${NC}"
  echo ""
  echo -e "${BLUE}Modelos disponíveis:${NC}"
  echo ""
  python3 -c "
import json
with open('$CONFIG_TARGET') as f:
    models = json.load(f)
for model in models:
    desc = model.get('description', 'Sem descrição')[:60]
    print(f\"  - {model['name']}: {desc}...\")
" 2>/dev/null || cat << 'EOF'
  - gemini-3-pro-preview
  - gemini-3-flash
  - gemini-2.5-flash-lite
  - gemini-claude-sonnet-4-5
  - gemini-claude-sonnet-4-5-thinking
  - gemini-claude-opus-4-5-thinking-4k
  - gemini-claude-opus-4-5-thinking-16k
  - gemini-claude-opus-4-5-thinking-32k
EOF

  echo ""
  log_info "Para mais detalhes, consulte: $CONFIG_TARGET"
  echo ""
}

# Função principal
main() {
  echo ""
  echo "=========================================="
  echo "  OpenCode Antigravity Setup"
  echo "=========================================="
  echo ""

  # Parse argumentos
  parse_args "$@"

  # Executar etapas
  check_prerequisites
  create_config_dir
  copy_model_config || {
    log_warn "Configuração de modelos pulada (já existe)"
  }
  setup_google_plugin
  validate_config

  # Mostrar instruções
  show_usage_instructions
}

# Executar função principal
main "$@"
