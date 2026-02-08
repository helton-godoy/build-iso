#!/usr/bin/env bash
# @INST_STEP_ID: post_install
# @INST_STEP_FLOW: prev=install, next=finish
# @INST_STATE: post_install_done
step_post_install() {
    ui_hero "${PROJECT_NAME:-FILESERVER INSTALLER}" "${PROJECT_TAGLINE:-Debian 13 + ZFS on Root}"
    ui_section "Pós-instalação"
    
    state_load || true
    local target="/mnt"

    # 1. Configurações Básicas Systema
    local hostname="${install_hostname:-debian}"
    local timezone="${install_timezone:-UTC}"
    
    ui_process_step "Configurando Hostname ($hostname)..." \
        system_set_hostname "$hostname" "$target" || return 1

    ui_process_step "Configurando Fuso Horário ($timezone)..." \
        system_set_timezone "$timezone" "$target" || return 1

    ui_process_step "Configurando Localidade (pt_BR)..." \
        system_set_locales "$target" || return 1
        
    # 2. Rede
    local net_method="${install_net_method:-dhcp}"
    if [[ "$net_method" == "dhcp" ]]; then
       ui_process_step "Configurando Rede (DHCP)..." \
           netutils_configure_dhcp "$target" || return 1
    else
       local ip="${install_net_ip-}"
       local mask="${install_net_mask-}"
       local gw="${install_net_gw-}"
       local dns="${install_net_dns-}"
       # Assume interface padrão para evitar complexidade de detecção no chroot
       ui_process_step "Configurando Rede (Estática: $ip)..." \
           netutils_configure_static "$target" "eth0" "$ip" "$mask" "$gw" "$dns" || return 1
    fi

    # 3. Usuários
    local user="${install_username-}"
    local pass="${install_user_pass-}"
    local full="${install_user_fullname-}"
    if [[ -n "$user" && -n "$pass" ]]; then
       ui_process_step "Criando usuário ($user)..." \
           authutils_create_user "$target" "$user" "$pass" || return 1
    fi
    
    local root_pass="${install_root_pass-}"
    if [[ -n "$root_pass" ]]; then
       ui_process_step "Definindo senha de root..." \
           authutils_set_root_pw "$target" "$root_pass" || return 1
    fi

    # 4. Bootloader (ZFSBootMenu)
    local disk="${install_disk-}"
    local pool="${zfs_pool_name:-zroot}"
    local part_efi="${install_part_efi-}" 
    
    if [[ -n "$part_efi" ]]; then
        ui_process_step "Instalando ZFSBootMenu..." \
            zbm_install "$part_efi" "$target" "$pool" || return 1
            
        # Tenta extrair número da partição para efibootmgr
        local efi_num="2"
        if [[ "$part_efi" =~ [0-9]+$ ]]; then
            efi_num="${BASH_REMATCH[0]}"
        fi
        
        ui_process_step "Configurando Boot Entry (EFIBootMgr)..." \
            zbm_configure_efi "$disk" "$efi_num" "$target" || true
            
        ui_process_step "Configurando Propriedades ZFS..." \
            zbm_configure_zfs_properties "$pool" "" || return 1
            
        ui_process_step "Gerando HostID..." \
            zbm_generate_hostid "$target" || return 1
            
        ui_process_step "Atualizando initramfs (pode demorar)..." \
            system_update_initramfs "$target" || return 1
    fi
    
    state_kv_set "post_install_done" "1" || return 1
    ui_success "Pós-instalação concluída!"
}
