#!/usr/bin/env bash
# @INST_STEP_ID: welcome
# @INST_STEP_FLOW: next=installer_prefs_locale
# @INST_STATE: welcome_screen

step_welcome() {
    # Carrega biblioteca de UI se não estiver carregada
    if [[ -z "${UI_COLOR_PRIMARY:-}" ]]; then
        # shellcheck source=/dev/null
        source /usr/local/lib/installer/libs/ui-gum.sh
    fi

    local welcome_msg="
Bem-vindo ao instalador do Fileserver Corporativo.

Este assistente irá guiá-lo através da:
 1. Seleção e formatação de discos
 2. Configuração do ZFS (RAID, Criptografia, Compressão)
 3. Instalação do sistema base Debian
 4. Configuração de Rede e Usuários

⚠️  AVISO: Todos os dados nos discos selecionados serão APAGADOS.
"
    
    # Usa o novo componente sys_page com sys_confirm
    sys_page "Bem-vindo" "$welcome_msg" "Pressione 'Sim' para continuar ou 'Não' para abortar."
    
    if ! sys_confirm "Deseja iniciar a instalação?"; then
        sys_msg_error "Cancelado" "O instalador foi abortado pelo usuário."
        exit 0
    fi
}
