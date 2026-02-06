#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: disks-identify-suporte-types.sh
# Purpose: identify disk types/capabilities for topology suggestions (NVMe/SATA/USB/SSD/HDD)
# Notes:
# - Designed to be lazy-loaded by installer-router.sh (as a dep)
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

DISKID_ALLOWED_DISK_RE_DEFAULT='^/dev/(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$'
DISKID_SYS_BLOCK_DEFAULT="/sys/block"

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
        stderr "Erro: comando vazio."
        return 1
    fi
    if ! command -v "$cmd" >/dev/null 2>&1; then
        stderr "Erro: dependência ausente: $cmd"
        return 1
    fi
}

diskid_loaded() { :; }

diskid_is_valid_disk_path() {
    local disk; disk="$(sanitize_path "${1-}")"
    [[ -n "$disk" && "$disk" =~ $DISKID_ALLOWED_DISK_RE_DEFAULT && -b "$disk" ]]
}

diskid_basename() {
    local disk; disk="$(sanitize_path "${1-}")"
    if [[ -z "$disk" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "${disk##*/}"
}

diskid_sys_block_path() {
    local disk; disk="$(sanitize_path "${1-}")"
    local base
    base="$(sanitize_ws "$(diskid_basename "$disk")")"
    if [[ -z "$base" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$(sanitize_path "$DISKID_SYS_BLOCK_DEFAULT/$base")"
}

diskid_read_sysfs_value() {
    # Single responsibility: read a sysfs file content safely (trim)
    # Args: sysfs_file
    local file; file="$(sanitize_path "${1-}")"
    if [[ -z "$file" || ! -f "$file" ]]; then
        printf '%s' ""
        return 0
    fi
    local val
    if ! val="$(cat "$file" 2>/dev/null || true)"; then
        val=""
    fi
    val="$(sanitize_ws "$val")"
    printf '%s' "$val"
}

diskid_is_rotational() {
    # Single responsibility: determine if disk is rotational (HDD)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_valid_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    local sys bp rota
    sys="$(diskid_sys_block_path "$disk")"
    sys="$(sanitize_path "$sys")"
    if [[ -z "$sys" ]]; then
        stderr "Erro: sysfs path inválido para $disk"
        return 1
    fi
    bp="$(sanitize_path "$sys/queue/rotational")"
    rota="$(diskid_read_sysfs_value "$bp")"
    rota="$(sanitize_ws "$rota")"
    if [[ -z "$rota" ]]; then
        return 1
    fi
    if [[ "$rota" == "1" ]]; then
        return 0
    fi
    return 1
}

diskid_is_nvme() {
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_valid_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    printf '%s' "$disk" | grep -Eq '^/dev/nvme[0-9]+n[0-9]+$'
}

diskid_is_mmc() {
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_valid_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    printf '%s' "$disk" | grep -Eq '^/dev/mmcblk[0-9]+$'
}

diskid_is_usb_like() {
    # Single responsibility: detect if disk transport indicates USB (best-effort)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_valid_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi

    if command -v lsblk >/dev/null 2>&1; then
        local tran
        tran="$(lsblk -dn -o TRAN "$disk" 2>/dev/null | head -n1 || true)"
        tran="$(sanitize_id "$tran")"
        if [[ "$tran" == "usb" ]]; then
            return 0
        fi
    fi

    # sysfs heuristic: presence of "/usb" in device path
    local sys devpath
    sys="$(diskid_sys_block_path "$disk")"
    sys="$(sanitize_path "$sys")"
    if [[ -z "$sys" ]]; then
        return 1
    fi
    devpath="$(readlink -f "$sys/device" 2>/dev/null || true)"
    devpath="$(sanitize_path "$devpath")"
    if [[ -z "$devpath" ]]; then
        return 1
    fi
    printf '%s' "$devpath" | grep -Eq '/usb[0-9]*/' || printf '%s' "$devpath" | grep -Eq '/usb/'
}

diskid_is_removable() {
    # Single responsibility: check removable flag (sysfs)
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_valid_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi
    local sys rm
    sys="$(diskid_sys_block_path "$disk")"
    sys="$(sanitize_path "$sys")"
    if [[ -z "$sys" ]]; then
        return 1
    fi
    rm="$(diskid_read_sysfs_value "$sys/removable")"
    rm="$(sanitize_ws "$rm")"
    [[ "$rm" == "1" ]]
}

diskid_disk_kind() {
    # Single responsibility: classify disk kind: nvme|ssd|hdd|removable|unknown
    # Args: disk
    local disk; disk="$(sanitize_path "${1-}")"
    if ! diskid_is_valid_disk_path "$disk"; then
        stderr "Erro: disco inválido: $disk"
        return 1
    fi

    if diskid_is_removable "$disk"; then
        stdout "removable"
        return 0
    fi

    if diskid_is_usb_like "$disk"; then
        stdout "removable"
        return 0
    fi

    if diskid_is_nvme "$disk"; then
        stdout "nvme"
        return 0
    fi

    if diskid_is_rotational "$disk"; then
        stdout "hdd"
        return 0
    fi

    # Non-rotational and not NVMe: treat as SSD (SATA/SAS)
    stdout "ssd"
}

diskid_supported_topologies_for_count() {
    # Single responsibility: return supported topologies based on disk count
    # Args: count
    local count; count="$(sanitize_ws "${1-}")"
    if [[ -z "$count" ]] || ! printf '%s' "$count" | grep -Eq '^[0-9]+$'; then
        stderr "Erro: count inválido."
        return 1
    fi

    # Outputs space-separated
    if (( count <= 0 )); then
        stdout ""
        return 0
    fi
    if (( count == 1 )); then
        stdout "stripe"
        return 0
    fi
    if (( count == 2 )); then
        stdout "stripe mirror"
        return 0
    fi
    if (( count == 3 )); then
        stdout "stripe mirror raidz1"
        return 0
    fi
    if (( count == 4 )); then
        stdout "stripe mirror raidz1 raidz2"
        return 0
    fi
    stdout "stripe mirror raidz1 raidz2 raidz3"
}

diskid_recommend_topology() {
    # Single responsibility: recommend a topology based on count and disk kinds
    # Args: count disk1 disk2 ...
    local count; count="$(sanitize_ws "${1-}")"
    shift || true

    if [[ -z "$count" ]] || ! printf '%s' "$count" | grep -Eq '^[0-9]+$'; then
        stderr "Erro: count inválido."
        return 1
    fi
    if (( count != $# )); then
        stderr "Erro: count não corresponde ao número de discos informados (count=$count args=$#)."
        return 1
    fi
    if (( count <= 0 )); then
        stdout ""
        return 0
    fi

    # Rule-of-thumb:
    # - 1 disk: stripe
    # - 2 disks: mirror
    # - 3 disks: raidz1
    # - 4+ disks: raidz2
    # Special:
    # - If any disk removable/usb: prefer mirror (2) or stripe (1) and warn externally.
    local any_rem=0
    local d kind
    for d in "$@"; do
        d="$(sanitize_path "$d")"
        if [[ -z "$d" ]]; then
            continue
        fi
        if ! kind="$(diskid_disk_kind "$d")"; then
            kind="unknown"
        fi
        kind="$(sanitize_id "$kind")"
        if [[ "$kind" == "removable" ]]; then
            any_rem=1
        fi
    done

    if (( count == 1 )); then
        stdout "stripe"
        return 0
    fi

    if (( count == 2 )); then
        stdout "mirror"
        return 0
    fi

    if (( any_rem == 1 )); then
        # With removable disks in the set, conservative suggestion:
        stdout "mirror"
        return 0
    fi

    if (( count == 3 )); then
        stdout "raidz1"
        return 0
    fi

    stdout "raidz2"
}

diskid_summarize_disks() {
    # Single responsibility: emit summary lines for given disks
    # Args: disk1 disk2 ...
    local disk kind rota usb rm
    for disk in "$@"; do
        disk="$(sanitize_path "$disk")"
        if [[ -z "$disk" ]]; then
            continue
        fi
        if ! diskid_is_valid_disk_path "$disk"; then
            stderr "Erro: disco inválido no summary: $disk"
            return 1
        fi
        kind="$(sanitize_id "$(diskid_disk_kind "$disk")")"
        rota="0"
        usb="0"
        rm="0"
        diskid_is_rotational "$disk" && rota="1" || true
        diskid_is_usb_like "$disk" && usb="1" || true
        diskid_is_removable "$disk" && rm="1" || true
        printf '%s kind=%s rotational=%s usb=%s removable=%s\n' "$disk" "$kind" "$rota" "$usb" "$rm"
    done
}
