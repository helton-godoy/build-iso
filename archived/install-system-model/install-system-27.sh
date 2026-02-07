#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: boot-utils.sh
# Purpose: UEFI detection, ESP mount helpers, GRUB/rEFInd install helpers, kernel cmdline handling
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

BOOTUTILS_TARGET_ROOT_DEFAULT="/mnt"
BOOTUTILS_ESP_MOUNT_DEFAULT="/boot/efi"
BOOTUTILS_GRUB_DEFAULT_FILE="/etc/default/grub"

BOOTUTILS_ALLOWED_DISK_RE_DEFAULT='^/dev/(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$'
BOOTUTILS_ALLOWED_PART_RE_DEFAULT='^/dev/(sd[a-z]+[0-9]+|vd[a-z]+[0-9]+|xvd[a-z]+[0-9]+|nvme[0-9]+n[0-9]+p[0-9]+|mmcblk[0-9]+p[0-9]+)$'
BOOTUTILS_ALLOWED_MOUNT_RE_DEFAULT='^/[^[:cntrl:]]*$'

stderr() { printf '%s\n' "$*" >&2; }
stdout() { printf '%s' "$*"; }

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
        stderr "Erro: comando vazio."
        return 1
    fi
    if ! command -v "$cmd" >/dev/null 2>&1; then
        stderr "Erro: dependência ausente: $cmd"
        return 1
    fi
}

bootutils_loaded() { :; }

bootutils_is_uefi() {
    # Single responsibility: detect UEFI environment
    [[ -d /sys/firmware/efi ]]
}

bootutils_is_disk_path() {
    local disk; disk="$(sanitize_path "${1-}")"
    [[ -n "$disk" && "$disk" =~ $BOOTUTILS_ALLOWED_DISK_RE_DEFAULT && -b "$disk" ]]
}

bootutils_is_part_path() {
    local part; part="$(sanitize_path "${1-}")"
    [[ -n "$part" && "$part" =~ $BOOTUTILS_ALLOWED_PART_RE_DEFAULT && -b "$part" ]]
}

bootutils_is_mountpoint_path() {
    local mp; mp="$(sanitize_path "${1-}")"
    [[ -n "$mp" && "$mp" =~ $BOOTUTILS_ALLOWED_MOUNT_RE_DEFAULT ]]
}

bootutils_ensure_boot_dirs() {
    # Single responsibility: ensure target boot directories exist
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$BOOTUTILS_TARGET_ROOT_DEFAULT"
    fi
    require_cmd mkdir || return 1
    mkdir -p "$root/boot"
    mkdir -p "$root/boot/efi"
}

bootutils_mount_esp() {
    # Single responsibility: mount ESP into target root
    # Args: esp_part target_mount (inside target root)
    local esp; esp="$(sanitize_path "${1-}")"
    local mp; mp="$(sanitize_path "${2-}")"
    if ! bootutils_is_part_path "$esp"; then
        stderr "Erro: ESP inválida: $esp"
        return 1
    fi
    if [[ -z "$mp" ]]; then
        mp="$BOOTUTILS_TARGET_ROOT_DEFAULT$BOOTUTILS_ESP_MOUNT_DEFAULT"
    fi
    if ! bootutils_is_mountpoint_path "$mp"; then
        stderr "Erro: mountpoint inválido: $mp"
        return 1
    fi

    require_cmd mkdir || return 1
    require_cmd mount || return 1
    mkdir -p "$mp"

    if command -v mountpoint >/dev/null 2>&1; then
        if mountpoint -q "$mp" 2>/dev/null; then
            return 0
        fi
    fi

    mount -t vfat -o umask=0077 "$esp" "$mp" >/dev/null 2>&1 || return 1
}

bootutils_umount_mountpoint() {
    # Single responsibility: umount mountpoint if mounted
    # Args: mountpoint
    local mp; mp="$(sanitize_path "${1-}")"
    if ! bootutils_is_mountpoint_path "$mp"; then
        stderr "Erro: mountpoint inválido: $mp"
        return 1
    fi
    require_cmd umount || return 1
    if command -v mountpoint >/dev/null 2>&1; then
        if ! mountpoint -q "$mp" 2>/dev/null; then
            return 0
        fi
    fi
    umount "$mp" >/dev/null 2>&1 || return 1
}

bootutils_find_esp_partition_on_disk() {
    # Single responsibility: find ESP partition path on disk (best-effort)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! bootutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    require_cmd lsblk || return 1
    require_cmd awk || return 1

    local out
    out="$(lsblk -prno PATH,PARTTYPE,FSTYPE,PARTLABEL "$disk" 2>/dev/null \
        | awk '
            tolower($2) ~ /^c12a7328-f81f-11d2-ba4b-00a0c93ec93b$/ {print $1; exit}
            tolower($3)=="vfat" && tolower($4)=="efi" {print $1; exit}
        ' || true)"
    out="$(sanitize_path "$out")"
    if [[ -z "$out" ]]; then
        return 1
    fi
    stdout "$out"
}

bootutils_write_kernel_cmdline() {
    # Single responsibility: write kernel cmdline into /etc/default/grub (GRUB_CMDLINE_LINUX)
    # Args: target_root cmdline
    local root; root="$(sanitize_path "${1-}")"
    local cmdline; cmdline="$(sanitize_ws "${2-}")"
    if [[ -z "$root" ]]; then
        root="$BOOTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$cmdline" ]]; then
        return 0
    fi

    local file
    file="$(sanitize_path "$root$BOOTUTILS_GRUB_DEFAULT_FILE")"
    if [[ ! -f "$file" ]]; then
        # best-effort create with minimal defaults
        require_cmd mkdir || return 1
        mkdir -p "$(dirname -- "$file")"
        {
            printf 'GRUB_DEFAULT=0\n'
            printf 'GRUB_TIMEOUT=5\n'
            printf 'GRUB_DISTRIBUTOR=`lsb_release -i -s 2>/dev/null || echo Debian`\n'
            printf 'GRUB_CMDLINE_LINUX_DEFAULT="quiet"\n'
            printf 'GRUB_CMDLINE_LINUX=""\n'
        } >"$file"
    fi

    require_cmd sed || return 1
    local esc
    esc="$(printf '%s' "$cmdline" | sed -E 's/\\/\\\\/g; s/"/\\"/g')"

    if grep -Eq '^[[:space:]]*GRUB_CMDLINE_LINUX=' "$file" 2>/dev/null; then
        sed -i -E "s|^[[:space:]]*GRUB_CMDLINE_LINUX=.*$|GRUB_CMDLINE_LINUX=\"${esc}\"|g" "$file" || return 1
    else
        printf '\nGRUB_CMDLINE_LINUX="%s"\n' "$esc" >>"$file"
    fi
}

bootutils_grub_install_uefi() {
    # Single responsibility: install GRUB for UEFI into ESP inside target
    # Args: target_root esp_mount_inside_target label(optional)
    local root; root="$(sanitize_path "${1-}")"
    local esp; esp="$(sanitize_path "${2-}")"
    local label; label="$(sanitize_ws "${3-debian}")"

    if [[ -z "$root" ]]; then
        root="$BOOTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$esp" ]]; then
        esp="$BOOTUTILS_ESP_MOUNT_DEFAULT"
    fi

    require_cmd chroot || return 1

    # Ensure mount exists
    if [[ ! -d "$root$esp" ]]; then
        stderr "Erro: ESP mount não encontrado no target: $root$esp"
        return 1
    fi

    if ! chroot "$root" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        /bin/bash -lc "grub-install --target=x86_64-efi --efi-directory='${esp}' --bootloader-id='${label}' --recheck" >/dev/null 2>&1; then
        stderr "Erro: grub-install UEFI falhou."
        return 1
    fi
}

bootutils_grub_install_bios() {
    # Single responsibility: install GRUB for BIOS to disk MBR (or BIOS-GPT embedding)
    # Args: target_root disk
    local root; root="$(sanitize_path "${1-}")"
    local disk; disk="$(sanitize_path "${2-}")"

    if [[ -z "$root" ]]; then
        root="$BOOTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if ! bootutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi

    require_cmd chroot || return 1

    if ! chroot "$root" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        /bin/bash -lc "grub-install --target=i386-pc '${disk}' --recheck" >/dev/null 2>&1; then
        stderr "Erro: grub-install BIOS falhou."
        return 1
    fi
}

bootutils_grub_mkconfig() {
    # Single responsibility: generate grub.cfg
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$BOOTUTILS_TARGET_ROOT_DEFAULT"
    fi
    require_cmd chroot || return 1
    if ! chroot "$root" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        /bin/bash -lc "update-grub" >/dev/null 2>&1; then
        if ! chroot "$root" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin \
            /bin/bash -lc "grub-mkconfig -o /boot/grub/grub.cfg" >/dev/null 2>&1; then
            stderr "Erro: geração de grub.cfg falhou."
            return 1
        fi
    fi
}

bootutils_refind_install() {
    # Single responsibility: run refind-install inside target (UEFI only)
    # Args: target_root esp_mount_inside_target
    local root; root="$(sanitize_path "${1-}")"
    local esp; esp="$(sanitize_path "${2-}")"
    if [[ -z "$root" ]]; then
        root="$BOOTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$esp" ]]; then
        esp="$BOOTUTILS_ESP_MOUNT_DEFAULT"
    fi
    require_cmd chroot || return 1

    if [[ ! -d "$root$esp" ]]; then
        stderr "Erro: ESP mount não encontrado no target: $root$esp"
        return 1
    fi

    if ! chroot "$root" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        /bin/bash -lc "refind-install --usedefault '${esp}'" >/dev/null 2>&1; then
        stderr "Erro: refind-install falhou."
        return 1
    fi
}
