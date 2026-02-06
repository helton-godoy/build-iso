#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# steps/install.sh
# Exports: step_install
# Depends on (lazy-loaded by router):
#   libs/disk-utils.sh libs/zfs-utils.sh libs/boot-utils.sh libs/install-utils.sh libs/validate-utils.sh libs/disks-identify-suporte-types.sh
# Uses router-provided: ui_*, state_*, sanitize_*, log_line

INSTALL_TARGET_ROOT_DEFAULT="/mnt"
INSTALL_ESP_MOUNT_DEFAULT="/boot/efi"
INSTALL_ESP_MOUNT_DEFAULT="/boot/efi"
INSTALL_EFI_MIB_DEFAULT="512"

step_install() {
    ui_hero "${PROJECT_NAME:-FILESERVER INSTALLER}" "${PROJECT_TAGLINE:-Debian 13 + ZFS on Root}"
    ui_section "Instalação do Sistema Base"

    state_load || true

    if declare -F validate_all_checkpoint >/dev/null 2>&1; then
        if ! validate_all_checkpoint; then
            ui_warn "Configuração inválida/ incompleta. Rode 'Assistente de Configuração' e revise no 'Resumo'."
            if ! ui_confirm "Continuar mesmo assim?" "Continuar" "Cancelar"; then
                return 1
            fi
        fi
    fi

    local disk pool topo comp dedup strategy ashift arc_mode arc_max suite mirror retries timeout swap_mib bootloader
    disk="$(sanitize_path "$(state_kv_get install_disk)")"
    pool="$(sanitize_ws "$(state_kv_get zfs_pool_name)")"
    topo="$(sanitize_id "$(state_kv_get zfs_topology)")"
    comp="$(sanitize_id "$(state_kv_get zfs_compression)")"
    dedup="$(sanitize_id "$(state_kv_get zfs_dedup)")"
    strategy="$(sanitize_id "$(state_kv_get install_zfs_strategy)")"
    ashift="$(sanitize_ws "$(state_kv_get zfs_ashift)")"
    arc_mode="$(sanitize_id "$(state_kv_get zfs_arc_mode)")"
    arc_max="$(sanitize_ws "$(state_kv_get zfs_arc_max)")"
    suite="$(sanitize_ws "$(state_kv_get install_suite)")"
    mirror="$(sanitize_ws "$(state_kv_get install_mirror)")"
    retries="$(sanitize_ws "$(state_kv_get install_apt_retries)")"
    timeout="$(sanitize_ws "$(state_kv_get install_apt_timeout)")"
    swap_mib="$(sanitize_ws "$(state_kv_get install_swap_mib)")"
    bootloader="$(sanitize_id "$(state_kv_get bootloader)")"

    [[ -z "$suite" ]] && suite="stable"
    [[ -z "$mirror" ]] && mirror="http://deb.debian.org/debian"
    [[ -z "$retries" ]] && retries="5"
    [[ -z "$timeout" ]] && timeout="30"
    [[ -z "$swap_mib" ]] && swap_mib="0"
    [[ -z "$bootloader" ]] && bootloader="grub"

    if [[ -z "$disk" || -z "$pool" ]]; then
        ui_error "Disco/pool não definidos. Rode o Assistente."
        return 1
    fi

    if declare -F diskid_policy_refuse_usb_install >/dev/null 2>&1; then
        diskid_policy_refuse_usb_install "$disk" || return 1
    fi

    diskutils_validate_target_disk "$disk" || return 1
    diskutils_refuse_install_on_media_disk "$disk" || return 1

    ui_card "Plano de instalação" \
        "  ${UI_BULLET:-•} Disco:       $disk" \
        "  ${UI_BULLET:-•} Pool:        $pool" \
        "  ${UI_BULLET:-•} Topologia:   $topo" \
        "  ${UI_BULLET:-•} Compressão:  $comp" \
        "  ${UI_BULLET:-•} Dedup:       $dedup" \
        "  ${UI_BULLET:-•} ARC:         ${arc_mode}${arc_max:+ ($arc_max)}" \
        "  ${UI_BULLET:-•} SWAP MiB:    $swap_mib" \
        "  ${UI_BULLET:-•} Suite:       $suite" \
        "  ${UI_BULLET:-•} Mirror:      $mirror" \
        "  ${UI_BULLET:-•} Bootloader:  $bootloader"

    if ! ui_confirm "CONFIRMAR e iniciar (destrutivo)?" "Instalar" "Cancelar"; then
        return 1
    fi

    ui_process_step "Preparando disco ($disk)..." \
        install_prepare_disk "$disk" "$swap_mib" "$bootloader" || return 1
        
    ui_process_step "Criando ZFS ($pool)..." \
        install_create_zfs "$disk" "$pool" "$topo" "$comp" "$dedup" "$ashift" "$strategy" "$swap_mib" || return 1
        
    ui_process_step "Montando volumes..." \
        install_mount_esp_and_write_fstab "$disk" "$swap_mib" || return 1
        
    ui_process_step "Instalando sistema base (Debian $suite)..." \
        install_debootstrap_and_apt "$suite" "$mirror" "$retries" "$timeout" || return 1
        
    ui_process_step "Configurando Kernel e ZFS..." \
        install_kernel_zfs_and_base_tools || return 1
        
    ui_process_step "Otimizando performance (ARC)..." \
        install_apply_arc_tuning "$arc_mode" "$arc_max" || return 1

    ui_success "Sistema base instalado."
}

# Export internals for spinner subshell
export -f install_prepare_disk
export -f install_create_zfs
export -f install_mount_esp_and_write_fstab
export -f install_debootstrap_and_apt
export -f install_kernel_zfs_and_base_tools
export -f install_apply_arc_tuning


install_prepare_disk() {
    # Single responsibility: wipe + GPT partitioning + format ESP + init swap optional
    # Args: disk swap_mib bootloader
    local disk; disk="$(sanitize_path "${1-}")"
    local swap_mib; swap_mib="$(sanitize_ws "${2-0}")"
    local bootloader; bootloader="$(sanitize_id "${3-grub}")"

    local bios_grub="0"
    if ! bootutils_is_uefi; then
        # BIOS install on GPT needs bios_grub partition for GRUB
        if [[ "$bootloader" == "grub" ]]; then
            bios_grub="1"
        fi
    fi

    diskutils_umount_all_children "$disk" || true
    if declare -F zfsutils_pool_exists >/dev/null 2>&1; then
        local pool
        pool="$(sanitize_ws "$(state_kv_get zfs_pool_name)")"
        if [[ -n "$pool" ]] && zfsutils_pool_exists "$pool"; then
            zfsutils_umount_all_under_altroot "$pool" || true
            zfsutils_export_pool "$pool" || true
        fi
    fi

    diskutils_wipe_signatures "$disk" || return 1
    diskutils_zap_gpt "$disk" || true

    local has_swap="0"
    if [[ -n "$swap_mib" ]] && printf '%s' "$swap_mib" | grep -Eq '^[0-9]+$' && [[ "$swap_mib" != "0" ]]; then
        has_swap="1"
    fi

    diskutils_create_gpt_efi_swap_optional "$disk" "$INSTALL_EFI_MIB_DEFAULT" "$swap_mib" "$bios_grub" || return 1

    local parts
    if ! parts="$(diskutils_partition_paths_for_zfs_layout "$disk" "$has_swap" "$bios_grub")"; then
        ui_error "Falha ao detectar partições criadas."
        return 1
    fi

    local efi swap zfsp
    efi="$(printf '%s\n' "$parts" | awk -F= '$1=="EFI"{print $2}' | head -n1 || true)"
    swap="$(printf '%s\n' "$parts" | awk -F= '$1=="SWAP"{print $2}' | head -n1 || true)"
    zfsp="$(printf '%s\n' "$parts" | awk -F= '$1=="ZFS"{print $2}' | head -n1 || true)"

    efi="$(sanitize_path "$efi")"
    swap="$(sanitize_path "$swap")"
    zfsp="$(sanitize_path "$zfsp")"

    if [[ -z "$efi" || -z "$zfsp" ]]; then
        ui_error "Partições EFI/ZFS não encontradas."
        return 1
    fi

    state_kv_set "install_part_efi" "$efi" || return 1
    state_kv_set "install_part_zfs" "$zfsp" || return 1
    state_kv_set "install_part_swap" "$swap" || true

    diskutils_mkfs_vfat_efi "$efi" || return 1
    if [[ "$has_swap" == "1" && -n "$swap" ]]; then
        diskutils_mkswap_partition "$swap" || return 1
    fi
}

install_create_zfs() {
    # Single responsibility: create pool + datasets and mount root dataset to target
    # Args: disk pool topo comp dedup ashift strategy swap_mib
    local disk; disk="$(sanitize_path "${1-}")"
    local pool; pool="$(sanitize_ws "${2-}")"
    local topo; topo="$(sanitize_id "${3-}")"
    local comp; comp="$(sanitize_id "${4-}")"
    local dedup; dedup="$(sanitize_id "${5-0}")"
    local ashift; ashift="$(sanitize_ws "${6-12}")"
    local strategy; strategy="$(sanitize_id "${7-auto}")"
    local swap_mib; swap_mib="$(sanitize_ws "${8-0}")"

    local zfsp
    zfsp="$(sanitize_path "$(state_kv_get install_part_zfs)")"
    if [[ -z "$zfsp" || ! -b "$zfsp" ]]; then
        ui_error "Partição ZFS inválida: $zfsp"
        return 1
    fi

    local root_ds="${pool}/ROOT/${PROJECT_BOOT_ID:-debian}"
    state_kv_set "zfs_root_dataset" "$root_ds" || return 1

    # This installer currently supports single-disk vdev by default for robustness.
    # Topology selection is stored but effective multi-disk vdev selection is a separate manual step.
    if [[ "$strategy" == "manual" ]]; then
        ui_warn "Modo manual selecionado, mas este fluxo padrão cria pool single-vdev em $zfsp."
        if ! ui_confirm "Continuar criando pool single-vdev?" "Continuar" "Cancelar"; then
            return 1
        fi
    fi

    # Create pool
    if zfsutils_pool_exists "$pool"; then
        ui_warn "Pool já existe; tentando exportar e recriar."
        zfsutils_umount_all_under_altroot "$pool" || true
        zfsutils_export_pool "$pool" || true
    fi

    zfsutils_pool_create_single "$pool" "$zfsp" "$ashift" "$comp" "$dedup" "$INSTALL_TARGET_ROOT_DEFAULT" || return 1

    # Root dataset tree
    zfsutils_create_root_datasets "$pool" "$root_ds" "$INSTALL_TARGET_ROOT_DEFAULT" || return 1

    # Presets
    local preset
    preset="$(sanitize_id "$(state_kv_get zfs_dataset_preset)")"
    [[ -z "$preset" ]] && preset="default"

    if [[ "$preset" == "server" ]]; then
        zfsutils_create_dataset_preset_server "$pool" "$root_ds" || return 1
    else
        zfsutils_create_dataset_preset_default "$pool" "$root_ds" || return 1
    fi

    zfsutils_set_mountpoints_final "$root_ds" || true

    # Ensure target root exists
    mkdir -p "$INSTALL_TARGET_ROOT_DEFAULT"
}

install_mount_esp_and_write_fstab() {
    # Single responsibility: mount ESP into target and write fstab entry
    # Args: disk swap_mib
    local disk; disk="$(sanitize_path "${1-}")"
    local swap_mib; swap_mib="$(sanitize_ws "${2-0}")"
    local efi swap
    efi="$(sanitize_path "$(state_kv_get install_part_efi)")"
    swap="$(sanitize_path "$(state_kv_get install_part_swap)")"

    if [[ -z "$efi" || ! -b "$efi" ]]; then
        ui_error "Partição EFI inválida: $efi"
        return 1
    fi

    bootutils_ensure_boot_dirs "$INSTALL_TARGET_ROOT_DEFAULT" || return 1
    bootutils_mount_esp "$efi" "$INSTALL_TARGET_ROOT_DEFAULT$INSTALL_ESP_MOUNT_DEFAULT" || return 1

    installutils_write_fstab_stub_for_efi "$INSTALL_TARGET_ROOT_DEFAULT" "$efi" "$INSTALL_ESP_MOUNT_DEFAULT" || return 1

    if [[ -n "$swap" && -b "$swap" && "$swap_mib" != "0" ]]; then
        # Optional: add swap to fstab if desired (simple)
        mkdir -p "$INSTALL_TARGET_ROOT_DEFAULT/etc"
        local fstab="$INSTALL_TARGET_ROOT_DEFAULT/etc/fstab"
        [[ -f "$fstab" ]] || : >"$fstab"
        if ! grep -Fq "$swap" "$fstab" 2>/dev/null; then
            printf '%s\tnone\tswap\tsw\t0\t0\n' "$swap" >>"$fstab"
        fi
    fi
}

install_debootstrap_and_apt() {
    # Single responsibility: debootstrap + apt configuration
    # Args: suite mirror retries timeout
    local suite; suite="$(sanitize_ws "${1-stable}")"
    local mirror; mirror="$(sanitize_ws "${2-http://deb.debian.org/debian}")"
    local retries; retries="$(sanitize_ws "${3-5}")"
    local timeout; timeout="$(sanitize_ws "${4-30}")"

    local proxy
    proxy="$(sanitize_ws "$(state_kv_get install_proxy)")"

    installutils_write_sources_list "$INSTALL_TARGET_ROOT_DEFAULT" "$suite" "$mirror" "main contrib non-free non-free-firmware" || return 1
    installutils_apt_configure_retries "$INSTALL_TARGET_ROOT_DEFAULT" "$retries" "$timeout" || return 1
    installutils_write_apt_proxy_conf "$INSTALL_TARGET_ROOT_DEFAULT" "$proxy" || return 1

    # Base include set ensures enough tooling
    local include="ca-certificates,gnupg,apt-transport-https,systemd-sysv"
    installutils_debootstrap_base "$INSTALL_TARGET_ROOT_DEFAULT" "$suite" "$mirror" "$include" || return 1

    installutils_bind_mounts "$INSTALL_TARGET_ROOT_DEFAULT" || return 1
}

install_kernel_zfs_and_base_tools() {
    # Single responsibility: install kernel + zfs + essentials inside target, then unmount binds kept for post_install
    installutils_install_kernel_and_zfs "$INSTALL_TARGET_ROOT_DEFAULT" || return 1

    # Basic tooling for boot/install/post steps
    installutils_apt_install_packages "$INSTALL_TARGET_ROOT_DEFAULT" "vim-tiny less curl wget openssh-server" || true
    installutils_apt_install_packages "$INSTALL_TARGET_ROOT_DEFAULT" "grub-efi-amd64 grub-pc efibootmgr" || true
    installutils_apt_install_packages "$INSTALL_TARGET_ROOT_DEFAULT" "refind" || true
}

install_apply_arc_tuning() {
    # Single responsibility: apply ARC tuning file into target
    # Args: arc_mode arc_max
    local mode; mode="$(sanitize_id "${1-auto}")"
    local max; max="$(sanitize_ws "${2-}")"
    zfsutils_apply_arc_tuning_target_file "$INSTALL_TARGET_ROOT_DEFAULT" "$mode" "$max" || return 1
}
