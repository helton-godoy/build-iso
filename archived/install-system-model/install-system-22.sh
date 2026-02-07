#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: disk-utils.sh
# Purpose: disk discovery, safety checks, wipe/partition (GPT + ESP + optional BIOS_GRUB + optional SWAP + ZFS partition)
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

DISKUTILS_ALLOWED_DISK_RE_DEFAULT='^/dev/(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$'
DISKUTILS_ALLOWED_PART_RE_DEFAULT='^/dev/(sd[a-z]+[0-9]+|vd[a-z]+[0-9]+|xvd[a-z]+[0-9]+|nvme[0-9]+n[0-9]+p[0-9]+|mmcblk[0-9]+p[0-9]+)$'
DISKUTILS_MIN_DISK_BYTES_DEFAULT="21474836480" # 20 GiB

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

sanitize_uint() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    if ! printf '%s' "$in" | grep -Eq '^[0-9]+$'; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in"
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

diskutils_block_size_bytes() {
    # Single responsibility: return disk size in bytes (or empty)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    require_cmd lsblk || return 1

    local out
    out="$(lsblk -bdn -o SIZE "$disk" 2>/dev/null | head -n1 || true)"
    out="$(sanitize_uint "$out")"
    if [[ -z "$out" ]]; then
        printf '%s' ""
        return 0
    fi
    stdout "$out"
}

diskutils_validate_target_disk() {
    # Single responsibility: validate disk exists and meets minimal requirements
    # Args: disk [min_bytes]
    local disk; disk="$(sanitize_path "${1-}")"
    local min; min="$(sanitize_uint "${2-}")"
    if [[ -z "$min" ]]; then
        min="$DISKUTILS_MIN_DISK_BYTES_DEFAULT"
    fi

    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi

    local sz
    if ! sz="$(diskutils_block_size_bytes "$disk")"; then
        return 1
    fi
    sz="$(sanitize_uint "$sz")"
    if [[ -z "$sz" ]]; then
        stderr "Erro: não foi possível obter tamanho do disco: $disk"
        return 1
    fi

    if ! printf '%s' "$sz" | awk -v min="$min" '{exit !($1+0 >= min+0)}'; then
        stderr "Erro: disco pequeno demais: $disk size=$sz min=$min"
        return 1
    fi
}

diskutils_refuse_install_on_media_disk() {
    # Single responsibility: refuse install if disk backs current root/live media (best-effort heuristic)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    require_cmd lsblk || return 1
    require_cmd awk || return 1
    require_cmd grep || return 1

    # Find root source device
    local root_src
    root_src="$(findmnt -no SOURCE / 2>/dev/null || true)"
    root_src="$(sanitize_path "$root_src")"
    if [[ -z "$root_src" ]]; then
        return 0
    fi

    # Map to parent disk (PKNAME)
    local pk
    pk="$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -n1 || true)"
    pk="$(sanitize_ws "$pk")"
    if [[ -z "$pk" ]]; then
        return 0
    fi
    local root_disk
    root_disk="/dev/${pk}"
    root_disk="$(sanitize_path "$root_disk")"

    if [[ "$root_disk" == "$disk" ]]; then
        stderr "Erro: disco alvo é o disco do ambiente atual: $disk"
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

    local mps
    mps="$(lsblk -prno MOUNTPOINT "$disk" 2>/dev/null | sed -E '/^[[:space:]]*$/d' || true)"
    mps="$(sanitize_ws "$mps")"
    if [[ -z "$mps" ]]; then
        return 0
    fi

    # Unmount deepest first
    if ! printf '%s\n' "$mps" | awk '{print length($0) "\t" $0}' | sort -rn | cut -f2- | while IFS= read -r mp; do
        mp="$(sanitize_path "$mp")"
        [[ -z "$mp" ]] && continue
        umount "$mp" >/dev/null 2>&1 || true
    done; then
        return 1
    fi
}

diskutils_zap_gpt() {
    # Single responsibility: wipe partition table (GPT/MBR) using sgdisk or wipefs fallback
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi

    if command -v sgdisk >/dev/null 2>&1; then
        sgdisk --zap-all "$disk" >/dev/null 2>&1 || return 1
        return 0
    fi

    require_cmd wipefs || return 1
    wipefs -a "$disk" >/dev/null 2>&1 || return 1
}

diskutils_wipe_signatures() {
    # Single responsibility: remove filesystem signatures (including partitions) best-effort
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    require_cmd wipefs || return 1
    wipefs -a "$disk" >/dev/null 2>&1 || return 1
    if command -v partprobe >/dev/null 2>&1; then
        partprobe "$disk" >/dev/null 2>&1 || true
    fi
}

diskutils_partprobe_settle() {
    # Single responsibility: ensure kernel sees new partition table
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    if command -v partprobe >/dev/null 2>&1; then
        partprobe "$disk" >/dev/null 2>&1 || true
    fi
    if command -v udevadm >/dev/null 2>&1; then
        udevadm settle >/dev/null 2>&1 || true
    fi
}

diskutils_disk_part_prefix() {
    # Single responsibility: return partition prefix for disk (/dev/sda -> /dev/sda, /dev/nvme0n1 -> /dev/nvme0n1p)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskutils_is_disk_path "$disk"; then
        printf '%s' ""
        return 0
    fi
    if printf '%s' "$disk" | grep -Eq '^/dev/nvme|^/dev/mmcblk'; then
        stdout "${disk}p"
        return 0
    fi
    stdout "$disk"
}

diskutils_create_gpt_efi_swap_optional() {
    # Single responsibility: create GPT layout:
    #   [optional BIOS_GRUB 1MiB]
    #   ESP (MiB size)
    #   [optional SWAP (MiB)]
    #   ZFS (rest)
    # Args: disk esp_mib swap_mib bios_grub(1|0)
    local disk; disk="$(sanitize_path "${1-}")"
    local esp_mib; esp_mib="$(sanitize_uint "${2-512}")"
    local swap_mib; swap_mib="$(sanitize_uint "${3-0}")"
    local bios_grub; bios_grub="$(sanitize_ws "${4-0}")"

    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    if [[ -z "$esp_mib" ]]; then
        esp_mib="512"
    fi
    if [[ -z "$swap_mib" ]]; then
        swap_mib="0"
    fi
    if [[ "$bios_grub" != "1" && "$bios_grub" != "0" ]]; then
        bios_grub="0"
    fi

    if command -v sgdisk >/dev/null 2>&1; then
        sgdisk -o "$disk" >/dev/null 2>&1 || return 1

        local idx=1 start="1MiB"
        if [[ "$bios_grub" == "1" ]]; then
            sgdisk -n "${idx}:${start}:+1MiB" -t "${idx}:EF02" -c "${idx}:BIOS_GRUB" "$disk" >/dev/null 2>&1 || return 1
            idx=$((idx + 1))
            start="2MiB"
        fi

        sgdisk -n "${idx}:${start}:+${esp_mib}MiB" -t "${idx}:EF00" -c "${idx}:EFI" "$disk" >/dev/null 2>&1 || return 1
        idx=$((idx + 1))

        if [[ "$swap_mib" != "0" ]]; then
            sgdisk -n "${idx}:0:+${swap_mib}MiB" -t "${idx}:8200" -c "${idx}:SWAP" "$disk" >/dev/null 2>&1 || return 1
            idx=$((idx + 1))
        fi

        sgdisk -n "${idx}:0:0" -t "${idx}:BF00" -c "${idx}:ZFS" "$disk" >/dev/null 2>&1 || return 1

        diskutils_partprobe_settle "$disk" || true
        return 0
    fi

    # Fallback: parted
    require_cmd parted || return 1
    parted -s "$disk" mklabel gpt >/dev/null 2>&1 || return 1

    local cur_start="1MiB"
    local partnum=1

    if [[ "$bios_grub" == "1" ]]; then
        parted -s "$disk" mkpart BIOS_GRUB "$cur_start" "2MiB" >/dev/null 2>&1 || return 1
        parted -s "$disk" set "$partnum" bios_grub on >/dev/null 2>&1 || true
        partnum=$((partnum + 1))
        cur_start="2MiB"
    fi

    local esp_end="${esp_mib}MiB"
    # If BIOS_GRUB used, esp ends at (2MiB + esp_mib)
    if [[ "$bios_grub" == "1" ]]; then
        esp_end="$((2 + esp_mib))MiB"
    fi
    parted -s "$disk" mkpart EFI fat32 "$cur_start" "$esp_end" >/dev/null 2>&1 || return 1
    parted -s "$disk" set "$partnum" esp on >/dev/null 2>&1 || true
    partnum=$((partnum + 1))
    cur_start="$esp_end"

    if [[ "$swap_mib" != "0" ]]; then
        local swap_end
        swap_end="$(( (bios_grub=="1"?2:1) + esp_mib + swap_mib ))MiB"
        # shellcheck disable=SC2154
        swap_end="$(sanitize_ws "$swap_end")"
        parted -s "$disk" mkpart SWAP linux-swap "$cur_start" "$swap_end" >/dev/null 2>&1 || return 1
        partnum=$((partnum + 1))
        cur_start="$swap_end"
    fi

    parted -s "$disk" mkpart ZFS "$cur_start" "100%" >/dev/null 2>&1 || return 1
    diskutils_partprobe_settle "$disk" || true
}

diskutils_partition_paths_for_zfs_layout() {
    # Single responsibility: compute expected partition paths for layout created above
    # Args: disk has_swap(1|0) bios_grub(1|0)
    # Output lines: EFI=/dev/... ; SWAP=/dev/... (if any); ZFS=/dev/...
    local disk; disk="$(sanitize_path "${1-}")"
    local has_swap; has_swap="$(sanitize_ws "${2-0}")"
    local bios_grub; bios_grub="$(sanitize_ws "${3-0}")"

    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    if [[ "$has_swap" != "1" && "$has_swap" != "0" ]]; then
        has_swap="0"
    fi
    if [[ "$bios_grub" != "1" && "$bios_grub" != "0" ]]; then
        bios_grub="0"
    fi

    local prefix
    prefix="$(diskutils_disk_part_prefix "$disk")"
    prefix="$(sanitize_path "$prefix")"
    if [[ -z "$prefix" ]]; then
        stderr "Erro: prefix inválido."
        return 1
    fi

    local base=1
    if [[ "$bios_grub" == "1" ]]; then
        base=2
    fi

    local efi_num="$base"
    local swap_num=""
    local zfs_num=""

    if [[ "$has_swap" == "1" ]]; then
        swap_num="$((base + 1))"
        zfs_num="$((base + 2))"
    else
        zfs_num="$((base + 1))"
    fi

    local efi_part swap_part zfs_part
    efi_part="${prefix}${efi_num}"
    zfs_part="${prefix}${zfs_num}"
    if [[ -n "$swap_num" ]]; then
        swap_part="${prefix}${swap_num}"
    else
        swap_part=""
    fi

    printf 'EFI=%s\n' "$efi_part"
    if [[ -n "$swap_part" ]]; then
        printf 'SWAP=%s\n' "$swap_part"
    fi
    printf 'ZFS=%s\n' "$zfs_part"
}

diskutils_mkfs_vfat_efi() {
    # Single responsibility: format ESP as vfat
    # Args: efi_part
    local efi; efi="$(sanitize_path "${1-}")"
    if ! diskutils_is_part_path "$efi"; then
        stderr "Erro: partição EFI inválida: $efi"
        return 1
    fi
    require_cmd mkfs.vfat || return 1
    mkfs.vfat -F32 -n EFI "$efi" >/dev/null 2>&1 || return 1
}

diskutils_mkswap_partition() {
    # Single responsibility: prepare swap partition
    # Args: swap_part
    local sw; sw="$(sanitize_path "${1-}")"
    if ! diskutils_is_part_path "$sw"; then
        stderr "Erro: partição swap inválida: $sw"
        return 1
    fi
    require_cmd mkswap || return 1
    mkswap -L SWAP "$sw" >/dev/null 2>&1 || return 1
}

diskutils_disks_human_table() {
    # Single responsibility: return disk table for UI (path size model tran)
    # Args: min_bytes(optional)
    local min; min="$(sanitize_uint "${1-}")"
    if [[ -z "$min" ]]; then
        min="$DISKUTILS_MIN_DISK_BYTES_DEFAULT"
    fi
    require_cmd lsblk || return 1
    require_cmd awk || return 1

    lsblk -bdn -o PATH,SIZE,MODEL,TRAN,TYPE 2>/dev/null \
        | awk -v min="$min" '
            $5=="disk" && $2+0>=min+0 {
                size=$2
                gb=size/1024/1024/1024
                printf "%-16s %8.1fGiB  %-24s  %-8s\n", $1, gb, $3, $4
            }' || true
}

diskutils_smart_short_test() {
    # Single responsibility: start a SMART short test if smartctl exists (best-effort)
    # Args: disk wait_seconds(optional)
    local disk; disk="$(sanitize_path "${1-}")"
    local wait; wait="$(sanitize_uint "${2-30}")"

    if ! diskutils_is_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    if [[ -z "$wait" ]]; then
        wait="30"
    fi
    if ! command -v smartctl >/dev/null 2>&1; then
        return 1
    fi
    smartctl -t short "$disk" >/dev/null 2>&1 || return 1
    sleep "$wait" >/dev/null 2>&1 || true
    smartctl -H "$disk" >/dev/null 2>&1 || return 1
}
