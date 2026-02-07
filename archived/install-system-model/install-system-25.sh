#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# steps/post_install.sh
# Exports: step_post_install
# Depends on (lazy-loaded by router):
#   libs/boot-utils.sh libs/install-utils.sh libs/post-utils.sh libs/time-utils.sh libs/validate-utils.sh libs/finalize-chroot.sh libs/setup-zbm-config.sh
# Uses router-provided: ui_*, state_*, sanitize_*

step_post_install() {
    ui_hero "${PROJECT_NAME:-FILESERVER INSTALLER}" "${PROJECT_TAGLINE:-Debian 13 + ZFS on Root}"
    ui_section "Pós-instalação"

    if ! declare -F validate_all_checkpoint >/dev/null 2>&1; then
        ui_error "Validador não carregado (validate-utils.sh)."
        return 1
    fi
    if ! declare -F installutils_bind_mounts >/dev/null 2>&1; then
        ui_error "Install utils não carregado (install-utils.sh)."
        return 1
    fi
    if ! declare -F bootutils_is_uefi >/dev/null 2>&1; then
        ui_error "Boot utils não carregado (boot-utils.sh)."
        return 1
    fi
    if ! declare -F postutils_set_hostname >/dev/null 2>&1; then
        ui_error "Post utils não carregado (post-utils.sh)."
        return 1
    fi

    state_load || true

    local target_root; target_root="$(sanitize_ws "${install_target_root-/mnt}")"
    local pool; pool="$(sanitize_ws "${zfs_pool_name-rpool}")"
    local root_ds; root_ds="$(sanitize_ws "${zfs_root_dataset-${pool}/ROOT/debian}")"
    local efi_part; efi_part="$(sanitize_ws "${efi_part-}")"
    local disk; disk="$(sanitize_ws "${install_disk-}")"

    local hn dom tz ntp ntp_server
    hn="$(sanitize_ws "${install_hostname-}")"
    dom="$(sanitize_ws "${install_domain-}")"
    tz="$(sanitize_ws "${install_tz-UTC}")"
    ntp="$(sanitize_ws "${install_ntp-1}")"
    ntp_server="$(sanitize_ws "${install_ntp_server-pool.ntp.org}")"

    local fullname username user_pw user_pw2
    fullname="$(sanitize_ws "${install_user_fullname-}")"
    username="$(sanitize_id "${install_username-}")"
    user_pw="${install_user_password-}"
    user_pw2="${install_user_password_confirm-}"

    local root_enable root_pw root_pw2 same_root
    root_enable="$(sanitize_ws "${install_root_enable-0}")"
    root_pw="${install_root_password-}"
    root_pw2="${install_root_password_confirm-}"
    same_root="$(sanitize_ws "${install_root_same_as_user-0}")"

    local net_method dns_list
    net_method="$(sanitize_id "${install_net_method-dhcp}")"
    dns_list="$(sanitize_ws "${install_net_dns-}")"

    local bootloader
    bootloader="$(sanitize_id "${bootloader-grub}")"

    local cmdline
    cmdline="$(sanitize_ws "${kernel_params_effective-${kernel_params-}}")"
    if [[ -z "$cmdline" ]]; then
        cmdline="root=ZFS=${root_ds}"
    fi

    if [[ -z "$target_root" ]]; then
        target_root="/mnt"
    fi
    if [[ -z "$pool" ]]; then
        pool="rpool"
    fi
    if [[ -z "$root_ds" ]]; then
        root_ds="${pool}/ROOT/debian"
    fi

    if ! validate_all_checkpoint; then
        ui_error "Validação falhou. Volte e corrija as configurações."
        return 1
    fi

    if [[ -z "$hn" ]]; then
        ui_error "Hostname não definido."
        return 1
    fi
    if [[ -z "$fullname" || -z "$username" ]]; then
        ui_error "Usuário não definido."
        return 1
    fi

    if [[ -z "$(sanitize_ws "$user_pw")" || -z "$(sanitize_ws "$user_pw2")" ]]; then
        ui_error "Senha do usuário vazia."
        return 1
    fi
    if [[ "$user_pw" != "$user_pw2" ]]; then
        ui_error "Senha do usuário não confere."
        return 1
    fi

    if [[ "$same_root" == "1" ]]; then
        root_enable="1"
        root_pw="$user_pw"
        root_pw2="$user_pw2"
    fi
    if [[ "$root_enable" == "1" ]]; then
        if [[ -z "$(sanitize_ws "$root_pw")" || -z "$(sanitize_ws "$root_pw2")" ]]; then
            ui_error "Senha do root vazia."
            return 1
        fi
        if [[ "$root_pw" != "$root_pw2" ]]; then
            ui_error "Senha do root não confere."
            return 1
        fi
    fi

    ui_card "Resumo" \
        "  ${UI_BULLET:-●} Target: ${target_root}" \
        "  ${UI_BULLET:-●} Host: ${hn}${dom:+.${dom}}" \
        "  ${UI_BULLET:-●} TZ/NTP: ${tz} ntp=${ntp} server=${ntp_server}" \
        "  ${UI_BULLET:-●} User: ${username} (sudo)" \
        "  ${UI_BULLET:-●} Root: ${root_enable}" \
        "  ${UI_BULLET:-●} Boot: ${bootloader} (cmdline: ${cmdline})" \
        "" \
        "  ${UI_WARN:-⚠} Esta etapa escreve configurações no sistema instalado."

    if ! ui_confirm "Aplicar configurações e instalar boot agora?" "Aplicar" "Voltar"; then
        return 1
    fi

    ui_section "1/6 Preparando chroot"
    if ! installutils_bind_mounts "$target_root" ""; then
        ui_error "Falha ao bind-mount em chroot."
        return 1
    fi

    ui_section "2/6 Identidade e locale"
    postutils_set_hostname "$target_root" "$hn" "$dom" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha hostname/hosts."; return 1; }
    postutils_configure_locale "$target_root" "${install_locale-pt_BR.UTF-8}" "${install_lang-pt_BR.UTF-8}" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha locale."; return 1; }
    postutils_configure_keymap "$target_root" "${install_keymap-br}" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha keymap."; return 1; }

    ui_section "3/6 Timezone e NTP"
    postutils_set_timezone "$target_root" "$tz" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha timezone."; return 1; }
    if declare -F timeutils_configure_timesyncd_target >/dev/null 2>&1; then
        timeutils_configure_timesyncd_target "$target_root" "$ntp" "$ntp_server" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha NTP target."; return 1; }
    fi

    ui_section "4/6 Usuários e segurança"
    postutils_create_user "$target_root" "$username" "$fullname" "$user_pw" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha ao criar usuário."; return 1; }
    postutils_enable_root_account_optional "$target_root" "$root_enable" "$root_pw" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha root policy."; return 1; }

    if [[ "$net_method" == "manual" && -n "$dns_list" ]]; then
        postutils_write_resolv_conf_static_optional "$target_root" "$dns_list" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha resolv.conf target."; return 1; }
    fi

    ui_section "5/6 ZFS cache e initramfs"
    postutils_set_zfs_cachefile_path "$target_root" "$pool" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha zpool cachefile."; return 1; }
    postutils_update_initramfs_all "$target_root" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha initramfs."; return 1; }
    postutils_write_machine_id "$target_root" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha machine-id."; return 1; }

    ui_section "6/6 Bootloader"
    if [[ -z "$disk" ]]; then
        installutils_bind_umounts "$target_root" "" || true
        ui_error "Disco de instalação não definido (install_disk)."
        return 1
    fi

    bootutils_write_kernel_cmdline "$target_root" "$cmdline" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha ao escrever cmdline do GRUB."; return 1; }

    if bootutils_is_uefi; then
        if [[ -z "$efi_part" ]]; then
            if ! efi_part="$(bootutils_find_esp_partition_on_disk "$disk")"; then
                efi_part=""
            fi
            efi_part="$(sanitize_ws "$efi_part")"
        fi
        if [[ -n "$efi_part" ]]; then
            bootutils_mount_esp "$efi_part" "${target_root}/boot/efi" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha ao montar ESP no target."; return 1; }
            state_kv_set "efi_part" "$efi_part" || true
        fi
    fi

    case "$bootloader" in
        grub)
            if bootutils_is_uefi; then
                bootutils_grub_install_uefi "$target_root" "/boot/efi" "${PROJECT_BOOT_ID:-debian}" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha grub UEFI."; return 1; }
            else
                bootutils_grub_install_bios "$target_root" "$disk" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha grub BIOS."; return 1; }
            fi
            bootutils_grub_mkconfig "$target_root" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha grub-mkconfig."; return 1; }
            ;;
        refind)
            if ! bootutils_is_uefi; then
                installutils_bind_umounts "$target_root" "" || true
                ui_error "rEFInd requer UEFI."
                return 1
            fi
            installutils_chroot_run "$target_root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install refind" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha ao instalar refind."; return 1; }
            bootutils_refind_install "$target_root" "/boot/efi" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha refind-install."; return 1; }
            ;;
        zfsbootmenu)
            if ! bootutils_is_uefi; then
                installutils_bind_umounts "$target_root" "" || true
                ui_error "ZFSBootMenu (neste fluxo) requer UEFI."
                return 1
            fi
            if ! declare -F zbm_setup_all >/dev/null 2>&1; then
                installutils_bind_umounts "$target_root" "" || true
                ui_error "ZFSBootMenu helper não carregado (setup-zbm-config.sh)."
                return 1
            fi
            zbm_setup_all "$target_root" "$pool" "$root_ds" "/boot/efi" "$cmdline" "1" || { installutils_bind_umounts "$target_root" "" || true; ui_error "Falha ZFSBootMenu."; return 1; }
            ;;
        none)
            ui_warn "Bootloader: Nenhum (você assumirá a instalação manual após reboot)."
            ;;
        *)
            installutils_bind_umounts "$target_root" "" || true
            ui_error "Bootloader inválido: $bootloader"
            return 1
            ;;
    esac

    if [[ "$bootloader" == "grub" ]]; then
        if declare -F finalize_all >/dev/null 2>&1; then
            finalize_all "$target_root" "$pool" "$hn" "$dom" "$dns_list" "$cmdline" || true
        fi
    fi

    installutils_bind_umounts "$target_root" "" || true

    state_kv_set "install_stage_post_done" "1" || true
    state_kv_set "kernel_params_effective" "$cmdline" || true
    state_kv_set "zfs_root_dataset" "$root_ds" || true

    ui_success "Pós-instalação concluída. Prossiga para Conclusão/Reboot."
}
