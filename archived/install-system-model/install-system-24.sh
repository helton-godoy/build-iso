#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# steps/install.sh
# Exports: step_install
# Depends on (lazy-loaded by router):
#   libs/disk-utils.sh libs/zfs-utils.sh libs/boot-utils.sh libs/install-utils.sh libs/validate-utils.sh libs/disks-identify-suporte-types.sh
# Uses router-provided: ui_*, state_*, sanitize_*

step_install() {
    ui_hero "${PROJECT_NAME:-FILESERVER INSTALLER}" "${PROJECT_TAGLINE:-Debian 13 + ZFS on Root}"
    ui_section "Instalação"

    if ! declare -F validate_all_checkpoint >/dev/null 2>&1; then
        ui_error "Validador não carregado (validate-utils.sh)."
        return 1
    fi
    if ! declare -F diskutils_validate_target_disk >/dev/null 2>&1; then
        ui_error "Disk utils não carregado (disk-utils.sh)."
        return 1
    fi
    if ! declare -F zfsutils_pool_create_autoroot >/dev/null 2>&1; then
        ui_error "ZFS utils não carregado (zfs-utils.sh)."
        return 1
    fi
    if ! declare -F installutils_debootstrap_base >/dev/null 2>&1; then
        ui_error "Install utils não carregado (install-utils.sh)."
        return 1
    fi
    if ! declare -F bootutils_ensure_boot_dirs >/dev/null 2>&1; then
        ui_error "Boot utils não carregado (boot-utils.sh)."
        return 1
    fi

    state_load || true

    local disk; disk="$(sanitize_ws "${install_disk-}")"
    local wipe; wipe="$(sanitize_ws "${install_wipe_confirmed-0}")"
    local strategy; strategy="$(sanitize_id "${install_zfs_strategy-auto}")"
    local topo; topo="$(sanitize_id "${zfs_topology-stripe}")"
    local pool; pool="$(sanitize_ws "${zfs_pool_name-rpool}")"
    local comp; comp="$(sanitize_id "${zfs_compression-zstd}")"
    local dedup; dedup="$(sanitize_id "${zfs_dedup-0}")"
    local arc_mode; arc_mode="$(sanitize_id "${zfs_arc_mode-auto}")"
    local arc_max; arc_max="$(sanitize_ws "${zfs_arc_max-}")"
    local preset; preset="$(sanitize_id "${zfs_dataset_preset-default}")"
    local bootloader; bootloader="$(sanitize_id "${bootloader-grub}")"
    local cmdline; cmdline="$(sanitize_ws "${kernel_params-}")"

    local suite; suite="$(sanitize_ws "${install_suite-stable}")"
    local mirror; mirror="$(sanitize_ws "${install_mirror-http://deb.debian.org/debian}")"
    local target_root; target_root="$(sanitize_ws "${install_target_root-/mnt}")"

    if [[ -z "$disk" ]]; then
        ui_error "Disco alvo não definido."
        return 1
    fi
    if [[ "$wipe" != "1" ]]; then
        ui_error "Wipe não confirmado."
        return 1
    fi
    if [[ -z "$pool" ]]; then
        pool="rpool"
    fi
    if [[ -z "$target_root" ]]; then
        target_root="/mnt"
    fi
    if [[ -z "$suite" ]]; then
        suite="stable"
    fi
    if [[ -z "$mirror" ]]; then
        mirror="http://deb.debian.org/debian"
    fi

    if ! validate_all_checkpoint; then
        ui_error "Validação falhou. Volte e corrija as configurações."
        return 1
    fi

    ui_card "Pré-checagens" \
        "  ${UI_BULLET:-●} Disco: ${disk}" \
        "  ${UI_BULLET:-●} ZFS: strategy=${strategy} topo=${topo} pool=${pool}" \
        "  ${UI_BULLET:-●} Debian: suite=${suite} mirror=${mirror}" \
        "  ${UI_BULLET:-●} Target: ${target_root}" \
        "" \
        "  ${UI_WARN:-⚠} Esta etapa executa operações destrutivas no disco."

    if ! ui_confirm "Confirmar EXECUÇÃO da instalação agora?" "Executar" "Voltar"; then
        return 1
    fi

    ui_section "1/6 Validando disco"
    if ! diskutils_validate_target_disk "$disk"; then
        ui_error "Validação do disco falhou: $disk"
        return 1
    fi
    if declare -F diskutils_refuse_install_on_media_disk >/dev/null 2>&1; then
        if ! diskutils_refuse_install_on_media_disk "$disk"; then
            ui_error "Disco alvo parece ser a mídia/ambiente atual."
            return 1
        fi
    fi
    ui_success "Disco validado."

    ui_section "2/6 Limpando e particionando"
    if ! diskutils_umount_all_children "$disk"; then
        ui_error "Falha ao desmontar partições do disco."
        return 1
    fi
    if ! diskutils_zap_gpt "$disk"; then
        ui_error "Falha ao limpar tabela GPT."
        return 1
    fi
    if ! diskutils_wipe_signatures "$disk"; then
        ui_error "Falha ao remover assinaturas (wipefs)."
        return 1
    fi

    local bios_grub
    if bootutils_is_uefi; then
        bios_grub="0"
    else
        bios_grub="1"
    fi

    local swap_mib; swap_mib="$(sanitize_ws "${install_swap_mib-0}")"
    if [[ -z "$swap_mib" ]] || ! printf '%s' "$swap_mib" | grep -Eq '^[0-9]+$'; then
        swap_mib="0"
    fi

    if ! diskutils_create_gpt_efi_swap_optional "$disk" "512" "$swap_mib" "$bios_grub"; then
        ui_error "Falha ao criar layout GPT (EFI/SWAP/ZFS)."
        return 1
    fi

    local parts efi_part swap_part zfs_part
    if ! parts="$(diskutils_partition_paths_for_zfs_layout "$disk" "$([[ "$swap_mib" != "0" ]] && printf '1' || printf '0')" "$bios_grub")"; then
        ui_error "Falha ao detectar partições criadas."
        return 1
    fi

    efi_part="$(printf '%s\n' "$parts" | sed -nE 's/^EFI=//p' | head -n1)"
    swap_part="$(printf '%s\n' "$parts" | sed -nE 's/^SWAP=//p' | head -n1 || true)"
    zfs_part="$(printf '%s\n' "$parts" | sed -nE 's/^ZFS=//p' | head -n1)"

    efi_part="$(sanitize_ws "$efi_part")"
    swap_part="$(sanitize_ws "$swap_part")"
    zfs_part="$(sanitize_ws "$zfs_part")"

    if [[ -z "$efi_part" || -z "$zfs_part" ]]; then
        ui_error "Partições inválidas (EFI/ZFS)."
        return 1
    fi
    if [[ ! -b "$efi_part" || ! -b "$zfs_part" ]]; then
        ui_error "Partições não são block devices (EFI/ZFS)."
        return 1
    fi

    if ! diskutils_mkfs_vfat_efi "$efi_part"; then
        ui_error "Falha ao formatar ESP (vfat)."
        return 1
    fi

    if [[ -n "$swap_part" && -b "$swap_part" ]]; then
        if ! diskutils_mkswap_partition "$swap_part"; then
            ui_error "Falha ao preparar SWAP."
            return 1
        fi
    fi
    ui_success "Particionamento concluído."

    ui_section "3/6 Criando pool/datasets ZFS"
    local vdevs
    vdevs=("$zfs_part")

    if [[ "$strategy" != "auto" ]]; then
        ui_error "Modo manual selecionado; este módulo executa apenas AUTO. Use o step ZFS manual."
        return 1
    fi

    if ! zfsutils_pool_create_autoroot "$pool" "$topo" "${zfs_ashift-12}" "$target_root" "/etc/zfs/zpool.cache" "${vdevs[@]}"; then
        ui_error "Falha ao criar pool ZFS."
        return 1
    fi

    if ! zfsutils_set_pool_properties_baseline "$pool" "$comp" "$dedup" "off" "off"; then
        ui_error "Falha ao aplicar propriedades base do ZFS."
        return 1
    fi

    if [[ "$arc_mode" == "custom" && -n "$arc_max" ]]; then
        if declare -F zfsutils_set_arc_max_bytes >/dev/null 2>&1; then
            if ! zfsutils_set_arc_max_bytes "$arc_max" "${target_root}/etc/modprobe.d"; then
                ui_error "Falha ao configurar ARC máximo."
                return 1
            fi
        fi
    fi

    if [[ "$preset" == "default" || "$preset" == "server" || "$preset" == "custom" ]]; then
        if ! zfsutils_create_root_layout_default "$pool"; then
            ui_error "Falha ao criar layout padrão de datasets."
            return 1
        fi
    fi

    local root_ds
    root_ds="${pool}/ROOT/debian"

    if ! zfsutils_mount_root_dataset "$root_ds" "$target_root"; then
        ui_error "Falha ao montar dataset root."
        return 1
    fi

    bootutils_ensure_boot_dirs "$target_root" || return 1
    if ! bootutils_mount_esp "$efi_part" "${target_root}/boot/efi"; then
        ui_error "Falha ao montar ESP no target."
        return 1
    fi
    state_kv_set "efi_part" "$efi_part" || true
    ui_success "ZFS e mounts concluídos."

    ui_section "4/6 Instalando sistema base (debootstrap)"
    local include
    include="ca-certificates,locales,openssh-client,gnupg"

    if ! installutils_write_apt_proxy_conf "$target_root" "$(sanitize_ws "${install_proxy-}")"; then
        ui_error "Falha ao escrever proxy do APT."
        return 1
    fi
    if ! installutils_debootstrap_base "$target_root" "$suite" "$mirror" "$include"; then
        ui_error "Falha no debootstrap."
        return 1
    fi
    if ! installutils_write_sources_list "$target_root" "$suite" "$mirror" "main contrib non-free-firmware"; then
        ui_error "Falha ao escrever sources.list."
        return 1
    fi
    if ! installutils_apt_configure_retries "$target_root" "${install_apt_retries-5}" "${install_apt_timeout-30}"; then
        ui_error "Falha ao configurar retries do APT."
        return 1
    fi
    ui_success "Sistema base instalado."

    ui_section "5/6 Preparando chroot e instalando kernel/ZFS"
    if ! installutils_bind_mounts "$target_root" ""; then
        ui_error "Falha ao bind-mount em chroot."
        return 1
    fi

    mkdir -p "$target_root/dev" "$target_root/proc" "$target_root/sys" "$target_root/run" >/dev/null 2>&1 || true

    if ! installutils_install_kernel_and_zfs "$target_root"; then
        installutils_bind_umounts "$target_root" "" || true
        ui_error "Falha ao instalar kernel e pacotes ZFS."
        return 1
    fi

    if ! installutils_write_fstab_stub_for_efi "$target_root" "$efi_part" "/boot/efi"; then
        installutils_bind_umounts "$target_root" "" || true
        ui_error "Falha ao registrar ESP no fstab."
        return 1
    fi

    ui_success "Kernel e ZFS instalados no target."

    ui_section "6/6 Preparando boot (parcial)"
    local zfs_root_hint
    zfs_root_hint="root=ZFS=${root_ds}"
    if [[ -n "$cmdline" ]]; then
        cmdline="$(sanitize_ws "${cmdline} ${zfs_root_hint}")"
    else
        cmdline="$zfs_root_hint"
    fi
    state_kv_set "kernel_params_effective" "$cmdline" || true

    if [[ "$bootloader" == "grub" ]]; then
        if ! installutils_apt_install_packages "$target_root" "grub-efi-amd64 shim-signed"; then
            if ! bootutils_is_uefi; then
                installutils_apt_install_packages "$target_root" "grub-pc" || true
            fi
        fi
    fi

    installutils_bind_umounts "$target_root" "" || true

    state_kv_set "install_stage_base_done" "1" || true
    state_kv_set "zfs_root_dataset" "$root_ds" || true

    ui_success "Instalação base concluída. Prossiga para Pós-instalação."
}
