#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: disks-identify-suporte-types.sh
# Purpose: identify disk transport/type characteristics (SSD/HDD/NVMe/USB) and provide policy helpers
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

DISKID_ALLOWED_DISK_RE_DEFAULT='^/dev/(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$'

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

diskid_loaded() { :; }

diskid_is_disk() {
    local disk; disk="$(sanitize_path "${1-}")"
    [[ -n "$disk" && "$disk" =~ $DISKID_ALLOWED_DISK_RE_DEFAULT && -b "$disk" ]]
}

diskid_basename() {
    # Single responsibility: return block device basename (sda, nvme0n1)
    # Args: /dev/...
    local disk; disk="$(sanitize_path "${1-}")"
    if [[ -z "$disk" ]]; then
        printf '%s' ""
        return 0
    fi
    printf '%s' "$disk" | sed -E 's|^/dev/||'
}

diskid_sys_block_dir() {
    # Single responsibility: return /sys/block/<name> for a disk
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_disk "$disk"; then
        printf '%s' ""
        return 0
    fi
    local name; name="$(diskid_basename "$disk")"
    name="$(sanitize_ws "$name")"
    if [[ -z "$name" ]]; then
        printf '%s' ""
        return 0
    fi
    printf '%s' "/sys/block/$name"
}

diskid_read_sys() {
    # Single responsibility: read first line from a sysfs file (best-effort)
    # Args: sys_path
    local p; p="$(sanitize_path "${1-}")"
    if [[ -z "$p" || ! -r "$p" ]]; then
        printf '%s' ""
        return 0
    fi
    local out
    out="$(head -n1 "$p" 2>/dev/null || true)"
    out="$(sanitize_ws "$out")"
    printf '%s' "$out"
}

diskid_rotational() {
    # Single responsibility: detect if disk is rotational (1) or not (0)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_disk "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    local dir; dir="$(diskid_sys_block_dir "$disk")"
    dir="$(sanitize_path "$dir")"
    if [[ -z "$dir" ]]; then
        printf '%s' ""
        return 0
    fi
    diskid_read_sys "$dir/queue/rotational"
}

diskid_tran() {
    # Single responsibility: detect transport (usb/sata/nvme/...)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_disk "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    if command -v lsblk >/dev/null 2>&1; then
        local out
        out="$(lsblk -dn -o TRAN "$disk" 2>/dev/null | head -n1 || true)"
        out="$(sanitize_ws "$out")"
        printf '%s' "$out"
        return 0
    fi
    printf '%s' ""
}

diskid_model() {
    # Single responsibility: get disk model (best-effort)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_disk "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    if command -v lsblk >/dev/null 2>&1; then
        local out
        out="$(lsblk -dn -o MODEL "$disk" 2>/dev/null | head -n1 || true)"
        out="$(sanitize_ws "$out")"
        printf '%s' "$out"
        return 0
    fi
    printf '%s' ""
}

diskid_is_nvme() {
    # Single responsibility: check if disk path is NVMe
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_disk "$disk"; then
        return 1
    fi
    printf '%s' "$disk" | grep -Eq '^/dev/nvme'
}

diskid_is_usb() {
    # Single responsibility: check if disk transport is usb
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_disk "$disk"; then
        return 1
    fi
    local t; t="$(diskid_tran "$disk" || true)"
    t="$(sanitize_ws "$t")"
    [[ "$t" == "usb" ]]
}

diskid_classify() {
    # Single responsibility: classify disk into one of: nvme|ssd|hdd|usb|unknown
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_disk "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi

    if diskid_is_usb "$disk"; then
        printf '%s' "usb"
        return 0
    fi
    if diskid_is_nvme "$disk"; then
        printf '%s' "nvme"
        return 0
    fi

    local rot
    rot="$(diskid_rotational "$disk" || true)"
    rot="$(sanitize_ws "$rot")"
    if [[ "$rot" == "0" ]]; then
        printf '%s' "ssd"
        return 0
    fi
    if [[ "$rot" == "1" ]]; then
        printf '%s' "hdd"
        return 0
    fi
    printf '%s' "unknown"
}

diskid_recommend_ashift() {
    # Single responsibility: recommend ashift (12 default; 13 for some advanced format—best-effort)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_disk "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi

    # Prefer 12 as safe default; if physical_block_size >= 8192, suggest 13
    local dir pbs
    dir="$(diskid_sys_block_dir "$disk")"
    dir="$(sanitize_path "$dir")"
    if [[ -z "$dir" ]]; then
        printf '%s' "12"
        return 0
    fi
    pbs="$(diskid_read_sys "$dir/queue/physical_block_size")"
    pbs="$(sanitize_ws "$pbs")"
    if [[ -n "$pbs" ]] && printf '%s' "$pbs" | grep -Eq '^[0-9]+$'; then
        if printf '%s' "$pbs" | awk '{exit !($1+0>=8192)}'; then
            printf '%s' "13"
            return 0
        fi
    fi
    printf '%s' "12"
}

diskid_policy_refuse_usb_install() {
    # Single responsibility: refuse install on USB drives by policy (returns 0 if OK, 1 if refuse)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_disk "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    if diskid_is_usb "$disk"; then
        stderr "Erro: política: instalação em USB não permitida: $disk"
        return 1
    fi
}
