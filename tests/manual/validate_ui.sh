#!/usr/bin/env bash
#
# validate_ui.sh - Script de validação visual do Design System v2.0
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../scripts/lib/fileserver-ds.sh"

echo "=== Validação do Design System v2.0 ==="
echo

# Teste 1: Hero
echo "Teste 1: Hero"
ds_hero "Teste de Validação Visual"
sleep 1

# Teste 2: Seção
echo "Teste 2: Seção"
ds_section "Seção de Teste" "Esta é uma descrição de teste"
sleep 1

# Teste 3: Card com status
echo "Teste 3: Cards com diferentes status"
ds_card "Card informativo padrão" "info"
ds_card "Card de sucesso" "success"
ds_card "Card de aviso" "warning"
ds_card "Card de erro" "error"
sleep 1

# Teste 4: Textos
echo "Teste 4: Estilos de texto"
ds_text "Texto normal"
ds_text_muted "Texto muted/subtle"
ds_text_bold "Texto em negrito"
ds_text_primary "Texto primário"
ds_text_success "Texto sucesso"
ds_text_warning "Texto aviso"
ds_text_error "Texto erro"
sleep 1

# Teste 5: Feedback
echo "Teste 5: Mensagens de feedback"
ds_success "Operação concluída com sucesso"
ds_error "Ocorreu um erro na operação"
ds_warning "Atenção: verifique as configurações"
ds_info "Informação importante"
sleep 1

# Teste 6: Telas do instalador
echo "Teste 6: Telas do instalador"
ds_welcome_screen "UEFI"
read -p "Pressione Enter para continuar..."

ds_disk_select_screen
read -p "Pressione Enter para continuar..."

ds_config_screen
read -p "Pressione Enter para continuar..."

ds_confirm_screen "/dev/sda" "fileserver" "admin"
read -p "Pressione Enter para continuar..."

ds_install_progress_screen 3 6 "Testando progresso"
read -p "Pressione Enter para continuar..."

ds_complete_screen
read -p "Pressione Enter para finalizar..."

echo
echo "=== Validação concluída ==="
