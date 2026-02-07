#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: boot-utils.sh
# Purpose: UEFI/BIOS detection, ESP handling, bootloader helpers (GRUB/rEFInd/ZFSBootMenu)
# Notes:
# - Designed for lazy-loading by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

BOOTUTILS_EFI_DIR_DEFAULT="/sys/firmware/efi"
BOOTUTILS_ESP_MOUNT_DEFAULT="/mnt/boot/efi"
BOOTUTILS_BOOT_MOUNT_DEFAULT="/mnt/boot"
BOOTUTILS_ALLOWED_DEV_RE_DEFAULT='^/dev/(sd[a-z]+[0-9]*|vd[a-z]+[0-9]*|xvd[a-z]+[0-9]*|nvme[0-9]+n[0-9]+p?[0-9]*|mmcblk[0-9]+p?[0-9]*)$'

stderr() { printf '%s\n' "$*" >&2; }
stdout() { printf '%s\n' "$*"; }

sanitize_ws() {
    local in; in="${1-}"
    in="${in//$'\r'/}"
    in="${in//$'\n'/}"
    printf '%s' "$in" | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//'
}

sanitize_path() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in" | sed -E 's/[[:cntrl:]]+//g'
}

sanitize_id() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.:-]+/_/g; s/^_+//; s/_+$//'
}

require_cmd() {
    local cmd; cmd="$(sanitize_ws "${1-}")"
    if [[ -z "$cmd" ]]; then
        stderr "Erro: require_cmd recebeu comando vazio."
        return 1
    fi
    if ! command -v "$cmd" >/dev/null 2>&1; then
        stderr "Erro: dependência ausente: $cmd"
        return 1
    fi
}

bootutils_loaded() { :; }

bootutils_is_uefi() {
    local efi_dir; efi_dir="$(sanitize_path "${1-}")"
    if [[ -z "$efi_dir" ]]; then
        efi_dir="$BOOTUTILS_EFI_DIR_DEFAULT"
    fi
    [[ -d "$efi_dir" ]]
}

bootutils_is_valid_dev_path() {
    local dev; dev="$(sanitize_path "${1-}")"
    [[ -n "$dev" && "$dev" =~ $BOOTUTILS_ALLOWED_DEV_RE_DEFAULT && -b "$dev" ]]
}

bootutils_find_esp_partition_on_disk() {
    # Returns ESP partition path for a given disk (first match)
    # Args: disk (/dev/sda, /dev/nvme0n1)
    local disk; disk="$(sanitize_path "${1-}")"
    if ! bootutils_is_valid_dev_path "$disk"; then
        stderr "Erro: disco inválido para busca de ESP: $disk"
        return 1
    fi
    require_cmd lsblk || return 1
    require_cmd awk || return 1
    require_cmd grep || return 1

    local out
    # Identify partition with PARTTYPE GUID for ESP: c12a7328-f81f-11d2-ba4b-00a0c93ec93b
    # Also accept vfat with label EFI, and flags in PARTFLAGS when available.
    out="$(lsblk -prno PATH,TYPE,PARTTYPE,FSTYPE,LABEL "$disk" 2>/dev/null \
        | awk '
            $2=="part" {
                p=$1; guid=$3; fs=$4; label=$5;
                gsub(/"/,"",guid); gsub(/"/,"",fs); gsub(/"/,"",label);
                if (tolower(guid)=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b") { print p; exit }
                if (tolower(fs)=="vfat" && toupper(label)=="EFI") { print p; exit }
            }')"

    out="$(sanitize_path "$out")"
    if [[ -z "$out" ]]; then
        printf '%s' ""
        return 0
    fi
    stdout "$out"
}

bootutils_mount_esp() {
    # Single responsibility: mount ESP partition to esp_mount (creates dir)
    # Args: esp_part esp_mount
    local esp_part; esp_part="$(sanitize_path "${1-}")"
    local esp_mount; esp_mount="$(sanitize_path "${2-}")"

    if [[ -z "$esp_mount" ]]; then
        esp_mount="$BOOTUTILS_ESP_MOUNT_DEFAULT"
    fi
    if [[ -z "$esp_part" || ! -b "$esp_part" ]]; then
        stderr "Erro: partição ESP inválida: $esp_part"
        return 1
    fi

    require_cmd mkdir || return 1
    require_cmd mount || return 1
    mkdir -p "$esp_mount"

    if mountpoint -q "$esp_mount" 2>/dev/null; then
        return 0
    fi

    if ! mount -t vfat "$esp_part" "$esp_mount" >/dev/null 2>&1; then
        stderr "Erro: falha ao montar ESP $esp_part em $esp_mount"
        return 1
    fi
}

bootutils_umount_mountpoint() {
    # Single responsibility: unmount mountpoint if mounted
    # Args: mountpoint_path
    local mp; mp="$(sanitize_path "${1-}")"
    if [[ -z "$mp" ]]; then
        stderr "Erro: mountpoint vazio."
        return 1
    fi
    require_cmd umount || return 1
    if mountpoint -q "$mp" 2>/dev/null; then
        umount "$mp" >/dev/null 2>&1 || return 1
    fi
}

bootutils_ensure_boot_dirs() {
    # Single responsibility: ensure /boot and /boot/efi exist under target root
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="/mnt"
    fi
    require_cmd mkdir || return 1
    mkdir -p "$root/boot"
    mkdir -p "$root/boot/efi"
}

bootutils_grub_install_uefi() {
    # Single responsibility: install grub UEFI into target root (assumes chroot-ready)
    # Args: target_root efi_dir boot_id
    local root; root="$(sanitize_path "${1-}")"
    local efi_dir; efi_dir="$(sanitize_path "${2-}")"
    local boot_id; boot_id="$(sanitize_ws "${3-debian}")"

    if [[ -z "$root" ]]; then
        root="/mnt"
    fi
    if [[ -z "$efi_dir" ]]; then
        efi_dir="/boot/efi"
    fi
    boot_id="$(sanitize_id "$boot_id")"
    if [[ -z "$boot_id" ]]; then
        boot_id="debian"
    fi

    require_cmd chroot || return 1

    # We expect grub-efi-amd64 installed inside chroot.
    if ! chroot "$root" grub-install --target=x86_64-efi --efi-directory="$efi_dir" --bootloader-id="$boot_id" --recheck >/dev/null 2>&1; then
        stderr "Erro: grub-install (UEFI) falhou."
        return 1
    fi
}

bootutils_grub_install_bios() {
    # Single responsibility: install grub BIOS into target root
    # Args: target_root disk
    local root; root="$(sanitize_path "${1-}")"
    local disk; disk="$(sanitize_path "${2-}")"

    if [[ -z "$root" ]]; then
        root="/mnt"
    fi
    if ! bootutils_is_valid_dev_path "$disk"; then
        stderr "Erro: disco inválido para grub BIOS: $disk"
        return 1
    fi

    require_cmd chroot || return 1
    if ! chroot "$root" grub-install --target=i386-pc --recheck "$disk" >/dev/null 2>&1; then
        stderr "Erro: grub-install (BIOS) falhou."
        return 1
    fi
}

bootutils_grub_mkconfig() {
    # Single responsibility: generate grub config inside chroot
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="/mnt"
    fi
    require_cmd chroot || return 1

    if ! chroot "$root" update-grub >/dev/null 2>&1; then
        # Fallback for systems without update-grub alias
        if ! chroot "$root" grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; then
            stderr "Erro: geração de grub.cfg falhou."
            return 1
        fi
    fi
}

bootutils_refind_install() {
    # Single responsibility: install rEFInd inside chroot (assumes package installed)
    # Args: target_root efi_dir
    local root; root="$(sanitize_path "${1-}")"
    local efi_dir; efi_dir="$(sanitize_path "${2-}")"
    if [[ -z "$root" ]]; then
        root="/mnt"
    fi
    if [[ -z "$efi_dir" ]]; then
        efi_dir="/boot/efi"
    fi
    require_cmd chroot || return 1
    if ! chroot "$root" refind-install --usedefault "$efi_dir" >/dev/null 2>&1; then
        stderr "Erro: refind-install falhou."
        return 1
    fi
}

bootutils_efibootmgr_entry_list() {
    # Single responsibility: list EFI boot entries
    if ! bootutils_is_uefi; then
        stderr "Erro: não é UEFI (efibootmgr indisponível)."
        return 1
    fi
    require_cmd efibootmgr || return 1
    efibootmgr 2>/dev/null || return 1
}

bootutils_write_kernel_cmdline() {
    # Single responsibility: persist kernel cmdline for GRUB (Debian)
    # Args: target_root cmdline
    local root; root="$(sanitize_path "${1-}")"
    local cmdline; cmdline="$(sanitize_ws "${2-}")"
    if [[ -z "$root" ]]; then
        root="/mnt"
    fi
    if [[ -z "$cmdline" ]]; then
        return 0
    fi
    require_cmd sed || return 1

    local file
    file="$(sanitize_path "$root/etc/default/grub")"
    if [[ ! -f "$file" ]]; then
        stderr "Erro: arquivo não encontrado: $file"
        return 1
    fi

    local esc
    esc="$(printf '%s' "$cmdline" | sed -E 's/\\/\\\\/g; s/"/\\"/g')"
    if grep -Eq '^[[:space:]]*GRUB_CMDLINE_LINUX=' "$file" 2>/dev/null; then
        sed -i -E "s|^[[:space:]]*GRUB_CMDLINE_LINUX=.*$|GRUB_CMDLINE_LINUX=\"${esc}\"|g" "$file" || return 1
    else
        printf '\nGRUB_CMDLINE_LINUX="%s"\n' "$esc" >>"$file"
    fi
}

bootutils_detect_arch() {
    local arch
    arch="$(uname -m 2>/dev/null || true)"
    arch="$(sanitize_ws "$arch")"
    if [[ -z "$arch" ]]; then
        arch="unknown"
    fi
    stdout "$arch"
}

bootutils_supports_zfsbootmenu() {
    # Single responsibility: check if ZFSBootMenu tools likely available (best-effort)
    command -v chroot >/dev/null 2>&1 || return 1
    return 0
}
