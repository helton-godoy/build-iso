#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: disk-utils.sh
# Purpose: disk discovery, validation, wipe/partitioning, filesystem prep (EFI/SWAP), mount/umount helpers
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

DISKUTILS_ALLOWED_DISK_RE_DEFAULT='^/dev/(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$'
DISKUTILS_ALLOWED_PART_RE_DEFAULT='^/dev/(sd[a-z]+[0-9]+|vd[a-z]+[0-9]+|xvd[a-z]+[0-9]+|nvme[0-9]+n[0-9]+p[0-9]+|mmcblk[0-9]+p[0-9]+)$'

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

diskutils_loaded() { :; }

diskutils_is_disk_path() {
    local disk; disk="$(sanitize_path "${1-}")"
    [[ -n "$disk" && "$disk" =~ $DISKUTILS_ALLOWED_DISK_RE_DEFAULT && -b "$disk" ]]
}

diskutils_is_part_path() {
    local part; part="$(sanitize_path "${1-}")"
    [[ -n "$part" && "$part" =~ $DISKUTILS_ALLOWED_PART_RE_DEFAULT && -b "$part" ]]
}

diskutils_list_disks() {
    # Single responsibility: list disks (one per line) with minimal descriptor
    require_cmd lsblk || return 1
    require_cmd awk || return 1
    require_cmd sed || return 1

    # Output format: "/dev/sda  (SIZE=..., MODEL=..., TRAN=...)"
    # Caller can parse by taking first token.
    lsblk -dn -o PATH,SIZE,MODEL,TRAN,TYPE 2>/dev/null \
        | awk '$5=="disk"{printf "%s  (SIZE=%s MODEL=%s TRAN=%s)\n",$1,$2,($3?$3:"-"),($4?$4:"-")}' \
        | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//' || true
}

diskutils_extract_disk_from_label() {
    # Single responsibility: extract /dev/... from a label line
    # Args: label
    local label; label="$(sanitize_ws "${1-}")"
    local disk
    disk="$(printf '%s' "$label" | awk '{print $1}' | head -n1 || true)"
    disk="$(sanitize_path "$disk")"
    printf '%s' "$disk"
}

diskutils_validate_target_disk() {
    # Single responsibility: validate disk path and basic safety checks
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    require_cmd lsblk || return 1

    local dtype
    dtype="$(lsblk -dn -o TYPE "$disk" 2>/dev/null | head -n1 || true)"
    dtype="$(sanitize_ws "$dtype")"
    if [[ "$dtype" != "disk" ]]; then
        stderr "Erro: alvo não é disco: $disk"
        return 1
    fi
}

diskutils_refuse_install_on_media_disk() {
    # Single responsibility: refuse if disk appears to be current live media root device (best-effort)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    require_cmd findmnt || return 1
    require_cmd lsblk || return 1
    require_cmd sed || return 1

    # Determine backing device of current / (root) mount; strip partition suffix to disk.
    local src base
    src="$(findmnt -nro SOURCE / 2>/dev/null | head -n1 || true)"
    src="$(sanitize_path "$src")"
    if [[ -z "$src" ]]; then
        return 0
    fi

    base="$src"
    if printf '%s' "$base" | grep -Eq '^/dev/nvme[0-9]+n[0-9]+p[0-9]+$'; then
        base="$(printf '%s' "$base" | sed -E 's/p[0-9]+$//')"
    else
        base="$(printf '%s' "$base" | sed -E 's/[0-9]+$//')"
    fi
    base="$(sanitize_path "$base")"

    # If root is on overlayfs, try /run/live/medium or /cdrom.
    if [[ "$src" == "overlay" || "$src" == "tmpfs" ]]; then
        local msrc
        msrc="$(findmnt -nro SOURCE /cdrom 2>/dev/null | head -n1 || true)"
        msrc="$(sanitize_path "$msrc")"
        if [[ -n "$msrc" && "$msrc" =~ ^/dev/ ]]; then
            base="$msrc"
            if printf '%s' "$base" | grep -Eq '^/dev/nvme[0-9]+n[0-9]+p[0-9]+$'; then
                base="$(printf '%s' "$base" | sed -E 's/p[0-9]+$//')"
            else
                base="$(printf '%s' "$base" | sed -E 's/[0-9]+$//')"
            fi
            base="$(sanitize_path "$base")"
        fi
    fi

    if [[ -n "$base" && "$base" == "$disk" ]]; then
        stderr "Erro: disco alvo parece conter o sistema atual (root/live media): $disk"
        return 1
    fi
}

diskutils_umount_all_children() {
    # Single responsibility: unmount all mounted partitions under a disk (best-effort)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi

    require_cmd lsblk || return 1
    require_cmd umount || return 1
    require_cmd awk || return 1
    require_cmd sort || return 1

    local mps
    mps="$(lsblk -prno MOUNTPOINT "$disk" 2>/dev/null | awk 'NF{print $1}' | sort -r || true)"
    mps="$(sanitize_ws "$mps")"
    if [[ -z "$mps" ]]; then
        return 0
    fi

    local mp
    while IFS= read -r mp; do
        mp="$(sanitize_path "$mp")"
        [[ -z "$mp" ]] && continue
        if command -v mountpoint >/dev/null 2>&1; then
            mountpoint -q "$mp" 2>/dev/null || continue
        fi
        umount "$mp" >/dev/null 2>&1 || true
    done <<<"$(printf '%s\n' "$mps")"
}

diskutils_zap_gpt() {
    # Single responsibility: wipe partition table (sgdisk if available, else parted)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi

    if command -v sgdisk >/dev/null 2>&1; then
        sgdisk --zap-all "$disk" >/dev/null 2>&1 || return 1
        sgdisk --clear "$disk" >/dev/null 2>&1 || return 1
        return 0
    fi

    require_cmd parted || return 1
    parted -s "$disk" mklabel gpt >/dev/null 2>&1 || return 1
}

diskutils_wipe_signatures() {
    # Single responsibility: wipe filesystem signatures
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    require_cmd wipefs || return 1
    wipefs -a "$disk" >/dev/null 2>&1 || return 1
}

diskutils_create_gpt_efi_swap_optional() {
    # Single responsibility: create GPT layout with ESP + optional SWAP + BIOS_GRUB optional + ZFS remainder
    # Args: disk efi_mib swap_mib bios_grub(1|0)
    local disk; disk="$(sanitize_path "${1-}")"
    local efi_mib; efi_mib="$(sanitize_ws "${2-512}")"
    local swap_mib; swap_mib="$(sanitize_ws "${3-0}")"
    local bios_grub; bios_grub="$(sanitize_ws "${4-0}")"

    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    if [[ -z "$efi_mib" ]] || ! printf '%s' "$efi_mib" | grep -Eq '^[0-9]+$'; then
        efi_mib="512"
    fi
    if [[ -z "$swap_mib" ]] || ! printf '%s' "$swap_mib" | grep -Eq '^[0-9]+$'; then
        swap_mib="0"
    fi
    if [[ "$bios_grub" != "1" && "$bios_grub" != "0" ]]; then
        bios_grub="0"
    fi

    require_cmd parted || return 1

    # Align at 1MiB. Layout:
    # 1) BIOS_GRUB (if requested): 1MiB..3MiB (2MiB) flagged bios_grub
    # 2) EFI: next.. +efi_mib MiB, fat32, flags esp+boot
    # 3) SWAP: next.. +swap_mib MiB (if swap_mib>0), linux-swap
    # 4) ZFS: remainder, type linux-filesystem (we set GUID later via sgdisk if available)

    parted -s "$disk" mklabel gpt >/dev/null 2>&1 || return 1

    local start_mib=1
    local pnum=1

    if [[ "$bios_grub" == "1" ]]; then
        local end_bios=$((start_mib + 2))
        parted -s -a optimal "$disk" mkpart primary "${start_mib}MiB" "${end_bios}MiB" >/dev/null 2>&1 || return 1
        parted -s "$disk" set "$pnum" bios_grub on >/dev/null 2>&1 || return 1
        start_mib="$end_bios"
        pnum=$((pnum + 1))
    fi

    local end_efi=$((start_mib + efi_mib))
    parted -s -a optimal "$disk" mkpart ESP fat32 "${start_mib}MiB" "${end_efi}MiB" >/dev/null 2>&1 || return 1
    parted -s "$disk" set "$pnum" esp on >/dev/null 2>&1 || return 1
    parted -s "$disk" set "$pnum" boot on >/dev/null 2>&1 || return 1
    start_mib="$end_efi"
    pnum=$((pnum + 1))

    if [[ "$swap_mib" != "0" ]]; then
        local end_swap=$((start_mib + swap_mib))
        parted -s -a optimal "$disk" mkpart primary linux-swap "${start_mib}MiB" "${end_swap}MiB" >/dev/null 2>&1 || return 1
        start_mib="$end_swap"
        pnum=$((pnum + 1))
    fi

    parted -s -a optimal "$disk" mkpart primary "${start_mib}MiB" "100%" >/dev/null 2>&1 || return 1

    # Inform kernel
    if command -v partprobe >/dev/null 2>&1; then
        partprobe "$disk" >/dev/null 2>&1 || true
    fi
    if command -v udevadm >/dev/null 2>&1; then
        udevadm settle >/dev/null 2>&1 || true
    fi

    # Ensure ZFS partition type GUID if sgdisk exists (Linux filesystem is okay, but better to tag)
    if command -v sgdisk >/dev/null 2>&1; then
        local last
        last="$(sgdisk -p "$disk" 2>/dev/null | awk '/^[[:space:]]*[0-9]+[[:space:]]/ {n=$1} END{print n}' || true)"
        last="$(sanitize_ws "$last")"
        if [[ -n "$last" ]] && printf '%s' "$last" | grep -Eq '^[0-9]+$'; then
            # Solaris root / ZFS GUID: 6A898CC3-1DD2-11B2-99A6-080020736631
            sgdisk -t "${last}:6A898CC3-1DD2-11B2-99A6-080020736631" "$disk" >/dev/null 2>&1 || true
            sgdisk -c "${last}:ZFS" "$disk" >/dev/null 2>&1 || true
        fi
    fi
}

diskutils_partition_paths_for_zfs_layout() {
    # Single responsibility: output key=value lines for EFI/SWAP/ZFS partitions
    # Args: disk has_swap(1|0) has_bios_grub(1|0)
    local disk; disk="$(sanitize_path "${1-}")"
    local has_swap; has_swap="$(sanitize_ws "${2-0}")"
    local has_bios; has_bios="$(sanitize_ws "${3-0}")"

    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    if [[ "$has_swap" != "1" && "$has_swap" != "0" ]]; then
        has_swap="0"
    fi
    if [[ "$has_bios" != "1" && "$has_bios" != "0" ]]; then
        has_bios="0"
    fi

    local p1 p2 p3 p4
    if printf '%s' "$disk" | grep -Eq '^/dev/nvme|^/dev/mmcblk'; then
        p1="${disk}p1"
        p2="${disk}p2"
        p3="${disk}p3"
        p4="${disk}p4"
    else
        p1="${disk}1"
        p2="${disk}2"
        p3="${disk}3"
        p4="${disk}4"
    fi

    local efi swap zfs
    if [[ "$has_bios" == "1" ]]; then
        # p1=bios_grub, p2=efi, p3=swap?, p4=zfs
        efi="$p2"
        if [[ "$has_swap" == "1" ]]; then
            swap="$p3"
            zfs="$p4"
        else
            swap=""
            zfs="$p3"
        fi
    else
        # p1=efi, p2=swap?, p3=zfs
        efi="$p1"
        if [[ "$has_swap" == "1" ]]; then
            swap="$p2"
            zfs="$p3"
        else
            swap=""
            zfs="$p2"
        fi
    fi

    efi="$(sanitize_path "$efi")"
    swap="$(sanitize_path "$swap")"
    zfs="$(sanitize_path "$zfs")"

    printf 'EFI=%s\n' "$efi"
    printf 'SWAP=%s\n' "$swap"
    printf 'ZFS=%s\n' "$zfs"
}

diskutils_mkfs_vfat_efi() {
    # Single responsibility: format an EFI partition as vfat
    # Args: efi_part
    local efi; efi="$(sanitize_path "${1-}")"
    if ! diskutils_is_part_path "$efi"; then
        stderr "Erro: partição EFI inválida: $efi"
        return 1
    fi
    require_cmd mkfs.vfat || return 1
    mkfs.vfat -F 32 -n EFI "$efi" >/dev/null 2>&1 || return 1
}

diskutils_mkswap_partition() {
    # Single responsibility: initialize swap partition
    # Args: swap_part
    local sw; sw="$(sanitize_path "${1-}")"
    if ! diskutils_is_part_path "$sw"; then
        stderr "Erro: partição SWAP inválida: $sw"
        return 1
    fi
    require_cmd mkswap || return 1
    mkswap -L SWAP "$sw" >/dev/null 2>&1 || return 1
}
