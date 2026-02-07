#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Module: step/conclusion
# Handler: step_conclusion
# Single responsibility: finalize, unmount/export, offer reboot and optional media eject

step_conclusion() {
    ui_hero "${PROJECT_NAME:-FILESERVER INSTALLER}" "${PROJECT_TAGLINE:-Debian 13 + ZFS on Root}"
    ui_section "Conclusão"

    state_load || true

    local target_root; target_root="$(sanitize_ws "${install_target_root-/mnt}")"
    local pool; pool="$(sanitize_ws "${zfs_pool_name-rpool}")"
    local disk; disk="$(sanitize_ws "${install_disk-}")"
    local efi_part; efi_part="$(sanitize_ws "${efi_part-}")"
    local root_ds; root_ds="$(sanitize_ws "${zfs_root_dataset-${pool}/ROOT/debian}")"

    local post_done base_done
    base_done="$(sanitize_ws "${install_stage_base_done-0}")"
    post_done="$(sanitize_ws "${install_stage_post_done-0}")"

    if [[ -z "$target_root" ]]; then
        target_root="/mnt"
    fi
    if [[ -z "$pool" ]]; then
        pool="rpool"
    fi

    ui_card "Status" \
        "  ${UI_BULLET:-●} Base instalado: ${base_done}" \
        "  ${UI_BULLET:-●} Pós-instalação: ${post_done}" \
        "  ${UI_BULLET:-●} Pool: ${pool}" \
        "  ${UI_BULLET:-●} Root dataset: ${root_ds}" \
        "  ${UI_BULLET:-●} Target: ${target_root}" \
        "  ${UI_BULLET:-●} Disco: ${disk:-N/D}" \
        "  ${UI_BULLET:-●} ESP: ${efi_part:-N/D}"

    if [[ "$base_done" != "1" || "$post_done" != "1" ]]; then
        ui_warn "Nem todas as etapas foram marcadas como concluídas."
        if ! ui_confirm "Mesmo assim finalizar e preparar reboot?" "Finalizar" "Voltar"; then
            return 1
        fi
    else
        if ! ui_confirm "Finalizar instalação e preparar reboot?" "Finalizar" "Voltar"; then
            return 1
        fi
    fi

    ui_section "1/4 Sincronizando e limpando mounts"
    sync >/dev/null 2>&1 || true

    # Try unmount ESP if mounted
    if declare -F bootutils_umount_mountpoint >/dev/null 2>&1; then
        bootutils_umount_mountpoint "${target_root}/boot/efi" >/dev/null 2>&1 || true
    else
        if command -v umount >/dev/null 2>&1 && command -v mountpoint >/dev/null 2>&1; then
            mountpoint -q "${target_root}/boot/efi" 2>/dev/null && umount "${target_root}/boot/efi" >/dev/null 2>&1 || true
        fi
    fi

    # Unmount /boot if mounted separately
    if command -v mountpoint >/dev/null 2>&1 && command -v umount >/dev/null 2>&1; then
        mountpoint -q "${target_root}/boot" 2>/dev/null && umount "${target_root}/boot" >/dev/null 2>&1 || true
    fi

    # Unmount bind mounts best-effort
    if declare -F installutils_bind_umounts >/dev/null 2>&1; then
        installutils_bind_umounts "$target_root" "" >/dev/null 2>&1 || true
    else
        if command -v umount >/dev/null 2>&1 && command -v mountpoint >/dev/null 2>&1; then
            mountpoint -q "${target_root}/run" 2>/dev/null && umount "${target_root}/run" >/dev/null 2>&1 || true
            mountpoint -q "${target_root}/sys" 2>/dev/null && umount "${target_root}/sys" >/dev/null 2>&1 || true
            mountpoint -q "${target_root}/proc" 2>/dev/null && umount "${target_root}/proc" >/dev/null 2>&1 || true
            mountpoint -q "${target_root}/dev" 2>/dev/null && umount "${target_root}/dev" >/dev/null 2>&1 || true
        fi
    fi

    ui_section "2/4 Desmontando datasets ZFS"
    if declare -F zfsutils_umount_all_under_altroot >/dev/null 2>&1; then
        zfsutils_umount_all_under_altroot "$pool" >/dev/null 2>&1 || true
    else
        if command -v zfs >/dev/null 2>&1; then
            zfs unmount -a >/dev/null 2>&1 || true
        fi
    fi

    ui_section "3/4 Exportando pool ZFS"
    if declare -F zfsutils_export_pool >/dev/null 2>&1; then
        zfsutils_export_pool "$pool" >/dev/null 2>&1 || true
    else
        if command -v zpool >/dev/null 2>&1; then
            zpool export "$pool" >/dev/null 2>&1 || true
        fi
    fi

    sync >/dev/null 2>&1 || true
    ui_success "Finalização concluída."

    ui_section "4/4 Reiniciar"
    local eject_choice reboot_choice
    eject_choice="0"
    reboot_choice="0"

    if ui_confirm "Ejetar mídia de instalação automaticamente (se possível)?" "Ejetar" "Pular"; then
        eject_choice="1"
    fi

    if [[ "$eject_choice" == "1" ]]; then
        if command -v eject >/dev/null 2>&1; then
            # Best-effort: try common devices
            eject >/dev/null 2>&1 || true
            [[ -n "$disk" ]] && eject "$disk" >/dev/null 2>&1 || true
        fi
    fi

    if ui_confirm "Reiniciar agora?" "Reiniciar" "Reiniciar depois"; then
        reboot_choice="1"
    fi

    state_kv_set "install_stage_done" "1" || true

    if [[ "$reboot_choice" == "1" ]]; then
        ui_warn "Reiniciando..."
        if command -v systemctl >/dev/null 2>&1; then
            systemctl reboot >/dev/null 2>&1 || true
        fi
        if command -v reboot >/dev/null 2>&1; then
            reboot >/dev/null 2>&1 || true
        fi
        ui_error "Falha ao acionar reboot automaticamente. Reinicie manualmente."
        return 1
    fi

    ui_success "Você pode reiniciar quando desejar."
}
