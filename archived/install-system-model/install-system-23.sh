#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: zfs-utils.sh
# Purpose: ZFS pool/dataset creation for Debian root-on-ZFS (autoroot layout), mount/unmount/export helpers, ARC tuning
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

ZFSUTILS_ALLOWED_POOL_RE_DEFAULT='^[A-Za-z][A-Za-z0-9_.:-]{0,47}$'
ZFSUTILS_ALLOWED_TOPO_RE_DEFAULT='^(stripe|mirror|raidz1|raidz2|raidz3)$'
ZFSUTILS_ALLOWED_DEV_RE_DEFAULT='^/dev/(sd[a-z]+[0-9]+|vd[a-z]+[0-9]+|xvd[a-z]+[0-9]+|nvme[0-9]+n[0-9]+p[0-9]+|mmcblk[0-9]+p[0-9]+)$'
ZFSUTILS_ALLOWED_COMP_RE_DEFAULT='^(zstd|lz4|lzjb)$'
ZFSUTILS_ALLOWED_DEDUP_RE_DEFAULT='^(0|1|on|off)$'
ZFSUTILS_ALLOWED_ASHIFT_RE_DEFAULT='^[0-9]{1,2}$'
ZFSUTILS_ALLOWED_SIZE_RE_DEFAULT='^[0-9]+$|^[0-9]+[KMGTP]$'

stderr() { printf '%s\n' "$*" >&2; }
stdout() { printf '%s' "$*"; }

sanitize_ws() {
    local in; in="${1-}"
    in="${in//$'\r'/}"
    in="${in//$'\n'/}"
    printf '%s' "$in" | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//'
}

sanitize_id() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.:-]+/_/g; s/^_+//; s/_+$//'
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

zfsutils_loaded() { :; }

zfsutils_is_poolname() {
    local p; p="$(sanitize_ws "${1-}")"
    [[ -n "$p" && "$p" =~ $ZFSUTILS_ALLOWED_POOL_RE_DEFAULT ]]
}

zfsutils_is_topology() {
    local t; t="$(sanitize_id "${1-}")"
    [[ -n "$t" && "$t" =~ $ZFSUTILS_ALLOWED_TOPO_RE_DEFAULT ]]
}

zfsutils_is_partdev() {
    local d; d="$(sanitize_path "${1-}")"
    [[ -n "$d" && "$d" =~ $ZFSUTILS_ALLOWED_DEV_RE_DEFAULT && -b "$d" ]]
}

zfsutils_is_compression() {
    local c; c="$(sanitize_id "${1-}")"
    [[ -n "$c" && "$c" =~ $ZFSUTILS_ALLOWED_COMP_RE_DEFAULT ]]
}

zfsutils_is_dedup() {
    local d; d="$(sanitize_id "${1-}")"
    [[ -n "$d" && "$d" =~ $ZFSUTILS_ALLOWED_DEDUP_RE_DEFAULT ]]
}

zfsutils_is_ashift() {
    local a; a="$(sanitize_ws "${1-}")"
    [[ -n "$a" && "$a" =~ $ZFSUTILS_ALLOWED_ASHIFT_RE_DEFAULT ]]
}

zfsutils_is_size() {
    local s; s="$(sanitize_ws "${1-}")"
    [[ -n "$s" && "$s" =~ $ZFSUTILS_ALLOWED_SIZE_RE_DEFAULT ]]
}

zfsutils_recommend_dedup_warning() {
    # Single responsibility: whether to warn about dedup
    # Args: dedup (0|1|on|off)
    local d; d="$(sanitize_id "${1-}")"
    [[ "$d" == "1" || "$d" == "on" ]]
}

zfsutils_require_zfs_tools() {
    require_cmd zpool || return 1
    require_cmd zfs || return 1
}

zfsutils_wait_zvols_settle() {
    # Single responsibility: udev settle after zpool operations (best-effort)
    if command -v udevadm >/dev/null 2>&1; then
        udevadm settle >/dev/null 2>&1 || true
    fi
}

zfsutils_pool_exists() {
    # Single responsibility: check if pool exists
    # Args: pool
    local pool; pool="$(sanitize_ws "${1-}")"
    zfsutils_require_zfs_tools || return 1
    zpool list -H -o name 2>/dev/null | awk -v p="$pool" '$1==p{found=1} END{exit !found}'
}

zfsutils_destroy_pool_if_exists() {
    # Single responsibility: destroy pool if exists (dangerous)
    # Args: pool
    local pool; pool="$(sanitize_ws "${1-}")"
    if [[ -z "$pool" ]]; then
        stderr "Erro: pool vazio."
        return 1
    fi
    zfsutils_require_zfs_tools || return 1
    if zfsutils_pool_exists "$pool"; then
        zpool destroy -f "$pool" >/dev/null 2>&1 || return 1
    fi
}

zfsutils_pool_create_autoroot() {
    # Single responsibility: create a root-on-ZFS pool with altroot and basic properties
    # Args: pool topology ashift altroot cachefile vdevs...
    local pool; pool="$(sanitize_ws "${1-}")"
    local topo; topo="$(sanitize_id "${2-}")"
    local ashift; ashift="$(sanitize_ws "${3-12}")"
    local altroot; altroot="$(sanitize_path "${4-/mnt}")"
    local cachefile; cachefile="$(sanitize_path "${5-/etc/zfs/zpool.cache}")"
    shift 5 || true

    if ! zfsutils_is_poolname "$pool"; then
        stderr "Erro: pool inválido: $pool"
        return 1
    fi
    if ! zfsutils_is_topology "$topo"; then
        stderr "Erro: topologia inválida: $topo"
        return 1
    fi
    if ! zfsutils_is_ashift "$ashift"; then
        ashift="12"
    fi
    if [[ -z "$altroot" ]]; then
        altroot="/mnt"
    fi
    if [[ -z "$cachefile" ]]; then
        cachefile="/etc/zfs/zpool.cache"
    fi
    if [[ $# -lt 1 ]]; then
        stderr "Erro: nenhum vdev informado."
        return 1
    fi

    zfsutils_require_zfs_tools || return 1

    local args=()
    args+=("-o" "ashift=${ashift}")
    args+=("-O" "acltype=posixacl")
    args+=("-O" "xattr=sa")
    args+=("-O" "dnodesize=auto")
    args+=("-O" "normalization=formD")
    args+=("-O" "atime=off")
    args+=("-O" "mountpoint=none")
    args+=("-O" "canmount=off")
    args+=("-O" "devices=off")
    args+=("-O" "compression=lz4")
    args+=("-o" "autotrim=on")
    args+=("-o" "cachefile=${cachefile}")
    args+=("-R" "$altroot")

    local vdevs=()
    local d
    for d in "$@"; do
        d="$(sanitize_path "$d")"
        if ! zfsutils_is_partdev "$d"; then
            stderr "Erro: vdev inválido: $d"
            return 1
        fi
        vdevs+=("$d")
    done

    # Ensure pool doesn't already exist (should be wiped earlier)
    if zfsutils_pool_exists "$pool"; then
        stderr "Erro: pool já existe: $pool"
        return 1
    fi

    local topo_args=()
    case "$topo" in
        stripe)
            topo_args=("${vdevs[@]}")
            ;;
        mirror)
            topo_args=("mirror" "${vdevs[@]}")
            ;;
        raidz1)
            topo_args=("raidz1" "${vdevs[@]}")
            ;;
        raidz2)
            topo_args=("raidz2" "${vdevs[@]}")
            ;;
        raidz3)
            topo_args=("raidz3" "${vdevs[@]}")
            ;;
    esac

    if ! zpool create -f "${args[@]}" "$pool" "${topo_args[@]}" >/dev/null 2>&1; then
        stderr "Erro: falha ao criar pool: $pool"
        return 1
    fi
    zfsutils_wait_zvols_settle
}

zfsutils_set_pool_properties_baseline() {
    # Single responsibility: set baseline properties after create
    # Args: pool compression dedup relatime exec
    local pool; pool="$(sanitize_ws "${1-}")"
    local comp; comp="$(sanitize_id "${2-lz4}")"
    local dedup; dedup="$(sanitize_id "${3-off}")"
    local relatime; relatime="$(sanitize_id "${4-off}")"
    local exec; exec="$(sanitize_id "${5-off}")"

    if ! zfsutils_is_poolname "$pool"; then
        stderr "Erro: pool inválido: $pool"
        return 1
    fi
    if ! zfsutils_is_compression "$comp"; then
        comp="lz4"
    fi
    if ! zfsutils_is_dedup "$dedup"; then
        dedup="off"
    fi
    zfsutils_require_zfs_tools || return 1

    zfs set "compression=${comp}" "$pool" >/dev/null 2>&1 || return 1
    zfs set "dedup=${dedup}" "$pool" >/dev/null 2>&1 || return 1
    zfs set "relatime=${relatime}" "$pool" >/dev/null 2>&1 || true
    zfs set "exec=${exec}" "$pool" >/dev/null 2>&1 || true
}

zfsutils_create_root_layout_default() {
    # Single responsibility: create default dataset layout for Debian
    # Args: pool
    local pool; pool="$(sanitize_ws "${1-}")"
    if ! zfsutils_is_poolname "$pool"; then
        stderr "Erro: pool inválido: $pool"
        return 1
    fi
    zfsutils_require_zfs_tools || return 1

    # Root containers
    zfs create -o canmount=off -o mountpoint=none "${pool}/ROOT" >/dev/null 2>&1 || true
    zfs create -o canmount=noauto -o mountpoint=/ "${pool}/ROOT/debian" >/dev/null 2>&1 || return 1

    # System datasets
    zfs create -o mountpoint=/home "${pool}/HOME" >/dev/null 2>&1 || true
    zfs create -o mountpoint=/root "${pool}/ROOTDIR" >/dev/null 2>&1 || true
    zfs create -o canmount=off -o mountpoint=/var "${pool}/VAR" >/dev/null 2>&1 || true
    zfs create -o mountpoint=/var/log "${pool}/VAR/log" >/dev/null 2>&1 || true
    zfs create -o mountpoint=/var/tmp "${pool}/VAR/tmp" >/dev/null 2>&1 || true
    zfs create -o mountpoint=/tmp "${pool}/TMP" >/dev/null 2>&1 || true

    # Boot dataset (kept on ZFS but /boot as normal dir; ESP is separate)
    zfs create -o mountpoint=/boot "${pool}/BOOT" >/dev/null 2>&1 || true
}

zfsutils_mount_root_dataset() {
    # Single responsibility: mount root dataset under altroot
    # Args: root_dataset altroot
    local ds; ds="$(sanitize_ws "${1-}")"
    local altroot; altroot="$(sanitize_path "${2-/mnt}")"
    if [[ -z "$ds" ]]; then
        stderr "Erro: dataset root vazio."
        return 1
    fi
    if [[ -z "$altroot" ]]; then
        altroot="/mnt"
    fi
    zfsutils_require_zfs_tools || return 1

    # Ensure altroot exists
    mkdir -p "$altroot" >/dev/null 2>&1 || true

    # Mount root dataset
    if ! zfs mount "$ds" >/dev/null 2>&1; then
        # Attempt canmount=noauto may require explicit mountpoint
        zfs mount -o mountpoint="$altroot" "$ds" >/dev/null 2>&1 || return 1
    fi
}

zfsutils_umount_all_under_altroot() {
    # Single responsibility: unmount datasets belonging to pool (best-effort)
    # Args: pool
    local pool; pool="$(sanitize_ws "${1-}")"
    if [[ -z "$pool" ]]; then
        stderr "Erro: pool vazio."
        return 1
    fi
    zfsutils_require_zfs_tools || return 1
    zfs unmount -a >/dev/null 2>&1 || true
}

zfsutils_export_pool() {
    # Single responsibility: export pool
    # Args: pool
    local pool; pool="$(sanitize_ws "${1-}")"
    if [[ -z "$pool" ]]; then
        stderr "Erro: pool vazio."
        return 1
    fi
    zfsutils_require_zfs_tools || return 1
    zpool export "$pool" >/dev/null 2>&1 || return 1
}

zfsutils_set_arc_max_bytes() {
    # Single responsibility: configure ZFS ARC max via modprobe.d
    # Args: arc_value (bytes or size suffix) modprobe_dir
    local val; val="$(sanitize_ws "${1-}")"
    local dir; dir="$(sanitize_path "${2-}")"

    if [[ -z "$dir" ]]; then
        dir="/etc/modprobe.d"
    fi
    if ! zfsutils_is_size "$val"; then
        stderr "Erro: valor ARC inválido: $val"
        return 1
    fi
    require_cmd mkdir || return 1
    mkdir -p "$dir"

    local bytes="$val"
    if printf '%s' "$val" | grep -Eq '^[0-9]+[KMGTP]$'; then
        bytes="$(printf '%s' "$val" | awk '
            function mult(u){return (u=="K"?1024:(u=="M"?1024^2:(u=="G"?1024^3:(u=="T"?1024^4:(u=="P"?1024^5:1)))))}
            {n=substr($0,1,length($0)-1); u=substr($0,length($0),1); printf "%.0f", n*mult(u)}
        ')"
        bytes="$(sanitize_ws "$bytes")"
        if [[ -z "$bytes" ]] || ! printf '%s' "$bytes" | grep -Eq '^[0-9]+$'; then
            stderr "Erro: falha ao converter ARC para bytes."
            return 1
        fi
    fi

    local file
    file="$(sanitize_path "$dir/zfs-arc-max.conf")"
    printf 'options zfs zfs_arc_max=%s\n' "$bytes" >"$file"
}
