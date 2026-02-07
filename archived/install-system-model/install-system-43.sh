#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: zfs-utils.sh
# Purpose: ZFS pool/dataset creation for Debian ZFS-on-root, mount layout, ARC tuning, export/unmount helpers
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

ZFSUTILS_ALLOWED_POOL_RE_DEFAULT='^[A-Za-z][A-Za-z0-9_.:-]{0,47}$'
ZFSUTILS_ALLOWED_DS_RE_DEFAULT='^[A-Za-z0-9_.:-]+(/[A-Za-z0-9_.:-]+)+$'
ZFSUTILS_ALLOWED_TOPO_RE_DEFAULT='^(stripe|mirror|raidz1|raidz2|raidz3)$'
ZFSUTILS_ALLOWED_COMP_RE_DEFAULT='^(zstd|lz4|lzjb)$'
ZFSUTILS_ALLOWED_ASHIFT_RE_DEFAULT='^[0-9]{1,2}$'
ZFSUTILS_ALLOWED_MOUNT_RE_DEFAULT='^/[^[:cntrl:]]*$'

ZFSUTILS_TARGET_ROOT_DEFAULT="/mnt"

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

zfsutils_loaded() { :; }

zfsutils_is_poolname() {
    local p; p="$(sanitize_ws "${1-}")"
    [[ -n "$p" && "$p" =~ $ZFSUTILS_ALLOWED_POOL_RE_DEFAULT ]]
}

zfsutils_is_dataset() {
    local ds; ds="$(sanitize_ws "${1-}")"
    [[ -n "$ds" && "$ds" =~ $ZFSUTILS_ALLOWED_DS_RE_DEFAULT ]]
}

zfsutils_is_topology() {
    local t; t="$(sanitize_id "${1-}")"
    [[ -n "$t" && "$t" =~ $ZFSUTILS_ALLOWED_TOPO_RE_DEFAULT ]]
}

zfsutils_is_compression() {
    local c; c="$(sanitize_id "${1-}")"
    [[ -n "$c" && "$c" =~ $ZFSUTILS_ALLOWED_COMP_RE_DEFAULT ]]
}

zfsutils_is_ashift() {
    local a; a="$(sanitize_ws "${1-}")"
    [[ -n "$a" && "$a" =~ $ZFSUTILS_ALLOWED_ASHIFT_RE_DEFAULT ]]
}

zfsutils_is_mountpoint_path() {
    local mp; mp="$(sanitize_path "${1-}")"
    [[ -n "$mp" && "$mp" =~ $ZFSUTILS_ALLOWED_MOUNT_RE_DEFAULT ]]
}

zfsutils_pool_exists() {
    local pool; pool="$(sanitize_ws "${1-}")"
    zfsutils_is_poolname "$pool" || return 1
    require_cmd zpool || return 1
    zpool list -H -o name "$pool" >/dev/null 2>&1
}

zfsutils_dataset_exists() {
    local ds; ds="$(sanitize_ws "${1-}")"
    zfsutils_is_dataset "$ds" || return 1
    require_cmd zfs || return 1
    zfs list -H -o name "$ds" >/dev/null 2>&1
}

zfsutils_set_altroot_pool() {
    # Single responsibility: set altroot for pool (best-effort)
    # Args: pool altroot
    local pool; pool="$(sanitize_ws "${1-}")"
    local alt; alt="$(sanitize_path "${2-}")"
    zfsutils_is_poolname "$pool" || return 1
    zfsutils_is_mountpoint_path "$alt" || return 1
    require_cmd zpool || return 1
    zpool set altroot="$alt" "$pool" >/dev/null 2>&1 || return 1
}

zfsutils_import_pool_altroot() {
    # Single responsibility: import pool with altroot (and mount)
    # Args: pool altroot
    local pool; pool="$(sanitize_ws "${1-}")"
    local alt; alt="$(sanitize_path "${2-}")"
    zfsutils_is_poolname "$pool" || return 1
    zfsutils_is_mountpoint_path "$alt" || return 1
    require_cmd zpool || return 1
    require_cmd mkdir || return 1
    mkdir -p "$alt"
    zpool import -N -R "$alt" "$pool" >/dev/null 2>&1 || return 1
}

zfsutils_export_pool() {
    # Single responsibility: export pool
    # Args: pool
    local pool; pool="$(sanitize_ws "${1-}")"
    zfsutils_is_poolname "$pool" || return 1
    require_cmd zpool || return 1
    zpool export "$pool" >/dev/null 2>&1 || return 1
}

zfsutils_umount_all_under_altroot() {
    # Single responsibility: unmount all ZFS datasets mounted under altroot (best-effort)
    # Args: pool
    local pool; pool="$(sanitize_ws "${1-}")"
    zfsutils_is_poolname "$pool" || return 1
    require_cmd zfs || return 1
    zfs unmount -a >/dev/null 2>&1 || true
}

zfsutils_pool_create_single() {
    # Single responsibility: create a pool using a single disk/partition (stripe-like)
    # Args: pool vdev_path ashift compression dedup(0|1) altroot
    local pool; pool="$(sanitize_ws "${1-}")"
    local vdev; vdev="$(sanitize_path "${2-}")"
    local ashift; ashift="$(sanitize_ws "${3-12}")"
    local comp; comp="$(sanitize_id "${4-zstd}")"
    local dedup; dedup="$(sanitize_id "${5-0}")"
    local alt; alt="$(sanitize_path "${6-$ZFSUTILS_TARGET_ROOT_DEFAULT}")"

    zfsutils_is_poolname "$pool" || { stderr "Erro: pool inválido: $pool"; return 1; }
    [[ -n "$vdev" && -b "$vdev" ]] || { stderr "Erro: vdev inválido: $vdev"; return 1; }
    zfsutils_is_ashift "$ashift" || ashift="12"
    zfsutils_is_compression "$comp" || comp="zstd"
    [[ "$dedup" == "1" || "$dedup" == "0" || "$dedup" == "on" || "$dedup" == "off" ]] || dedup="0"
    zfsutils_is_mountpoint_path "$alt" || alt="$ZFSUTILS_TARGET_ROOT_DEFAULT"

    require_cmd zpool || return 1

    local dflag="off"
    if [[ "$dedup" == "1" || "$dedup" == "on" ]]; then
        dflag="on"
    fi

    zpool create -f \
        -o ashift="$ashift" \
        -o autotrim=on \
        -O atime=off \
        -O xattr=sa \
        -O acltype=posixacl \
        -O compression="$comp" \
        -O normalization=formD \
        -O mountpoint=none \
        -O canmount=off \
        -O dedup="$dflag" \
        -O relatime=on \
        -R "$alt" \
        "$pool" "$vdev" >/dev/null 2>&1 || return 1
}

zfsutils_pool_create_topology() {
    # Single responsibility: create a pool with mirror/raidz using multiple vdev paths
    # Args: pool topology ashift compression dedup(0|1) altroot vdev_paths...
    local pool; pool="$(sanitize_ws "${1-}")"
    local topo; topo="$(sanitize_id "${2-}")"
    local ashift; ashift="$(sanitize_ws "${3-12}")"
    local comp; comp="$(sanitize_id "${4-zstd}")"
    local dedup; dedup="$(sanitize_id "${5-0}")"
    local alt; alt="$(sanitize_path "${6-$ZFSUTILS_TARGET_ROOT_DEFAULT}")"
    shift 6 || true

    zfsutils_is_poolname "$pool" || { stderr "Erro: pool inválido: $pool"; return 1; }
    zfsutils_is_topology "$topo" || { stderr "Erro: topologia inválida: $topo"; return 1; }
    zfsutils_is_ashift "$ashift" || ashift="12"
    zfsutils_is_compression "$comp" || comp="zstd"
    [[ "$dedup" == "1" || "$dedup" == "0" || "$dedup" == "on" || "$dedup" == "off" ]] || dedup="0"
    zfsutils_is_mountpoint_path "$alt" || alt="$ZFSUTILS_TARGET_ROOT_DEFAULT"

    local vdevs=()
    local v
    for v in "$@"; do
        v="$(sanitize_path "$v")"
        [[ -z "$v" ]] && continue
        [[ -b "$v" ]] || { stderr "Erro: vdev inválido: $v"; return 1; }
        vdevs+=("$v")
    done
    if [[ ${#vdevs[@]} -lt 1 ]]; then
        stderr "Erro: vdevs vazios."
        return 1
    fi
    if [[ "$topo" == "mirror" && ${#vdevs[@]} -lt 2 ]]; then
        stderr "Erro: mirror requer >=2 vdevs."
        return 1
    fi
    if [[ "$topo" =~ ^raidz && ${#vdevs[@]} -lt 3 ]]; then
        stderr "Erro: raidz requer >=3 vdevs."
        return 1
    fi

    require_cmd zpool || return 1

    local dflag="off"
    if [[ "$dedup" == "1" || "$dedup" == "on" ]]; then
        dflag="on"
    fi

    local topo_args=()
    if [[ "$topo" != "stripe" ]]; then
        topo_args+=("$topo")
    fi

    zpool create -f \
        -o ashift="$ashift" \
        -o autotrim=on \
        -O atime=off \
        -O xattr=sa \
        -O acltype=posixacl \
        -O compression="$comp" \
        -O normalization=formD \
        -O mountpoint=none \
        -O canmount=off \
        -O dedup="$dflag" \
        -O relatime=on \
        -R "$alt" \
        "$pool" "${topo_args[@]}" "${vdevs[@]}" >/dev/null 2>&1 || return 1
}

zfsutils_create_root_datasets() {
    # Single responsibility: create ROOT dataset tree and set bootfs/canmount appropriately
    # Args: pool root_ds_name (e.g. rpool/ROOT/debian) altroot
    local pool; pool="$(sanitize_ws "${1-}")"
    local root_ds; root_ds="$(sanitize_ws "${2-}")"
    local alt; alt="$(sanitize_path "${3-$ZFSUTILS_TARGET_ROOT_DEFAULT}")"

    zfsutils_is_poolname "$pool" || return 1
    zfsutils_is_dataset "$root_ds" || { stderr "Erro: root dataset inválido: $root_ds"; return 1; }
    zfsutils_is_mountpoint_path "$alt" || alt="$ZFSUTILS_TARGET_ROOT_DEFAULT"

    require_cmd zfs || return 1
    require_cmd zpool || return 1

    local root_container="${pool}/ROOT"
    if ! zfsutils_dataset_exists "$root_container"; then
        zfs create -o mountpoint=none -o canmount=off "$root_container" >/dev/null 2>&1 || return 1
    fi

    if ! zfsutils_dataset_exists "$root_ds"; then
        zfs create -o mountpoint=/ -o canmount=noauto "$root_ds" >/dev/null 2>&1 || return 1
    fi

    zpool set bootfs="$root_ds" "$pool" >/dev/null 2>&1 || true
    zfs mount "$root_ds" >/dev/null 2>&1 || true

    # Ensure altroot mount path exists
    require_cmd mkdir || return 1
    mkdir -p "$alt"
}

zfsutils_create_dataset_preset_default() {
    # Single responsibility: create a reasonable default dataset layout for Debian
    # Args: pool root_ds
    local pool; pool="$(sanitize_ws "${1-}")"
    local root_ds; root_ds="$(sanitize_ws "${2-}")"

    zfsutils_is_poolname "$pool" || return 1
    zfsutils_is_dataset "$root_ds" || return 1
    require_cmd zfs || return 1

    local ds

    ds="${root_ds}/home"
    zfsutils_dataset_exists "$ds" || zfs create -o mountpoint=/home "$ds" >/dev/null 2>&1 || return 1

    ds="${root_ds}/var"
    zfsutils_dataset_exists "$ds" || zfs create -o mountpoint=/var "$ds" >/dev/null 2>&1 || return 1

    ds="${root_ds}/var_log"
    zfsutils_dataset_exists "$ds" || zfs create -o mountpoint=/var/log "$ds" >/dev/null 2>&1 || return 1

    ds="${root_ds}/var_tmp"
    zfsutils_dataset_exists "$ds" || zfs create -o mountpoint=/var/tmp "$ds" >/dev/null 2>&1 || return 1

    ds="${root_ds}/tmp"
    zfsutils_dataset_exists "$ds" || zfs create -o mountpoint=/tmp "$ds" >/dev/null 2>&1 || return 1

    # Optional: keep /srv as dataset for servers
    ds="${root_ds}/srv"
    zfsutils_dataset_exists "$ds" || zfs create -o mountpoint=/srv "$ds" >/dev/null 2>&1 || return 1
}

zfsutils_create_dataset_preset_server() {
    # Single responsibility: server-oriented dataset layout
    # Args: pool root_ds
    local pool; pool="$(sanitize_ws "${1-}")"
    local root_ds; root_ds="$(sanitize_ws "${2-}")"

    zfsutils_create_dataset_preset_default "$pool" "$root_ds" || return 1

    require_cmd zfs || return 1

    local ds
    ds="${root_ds}/var_lib"
    zfsutils_dataset_exists "$ds" || zfs create -o mountpoint=/var/lib "$ds" >/dev/null 2>&1 || return 1

    ds="${root_ds}/var_cache"
    zfsutils_dataset_exists "$ds" || zfs create -o mountpoint=/var/cache "$ds" >/dev/null 2>&1 || return 1

    ds="${root_ds}/opt"
    zfsutils_dataset_exists "$ds" || zfs create -o mountpoint=/opt "$ds" >/dev/null 2>&1 || return 1
}

zfsutils_apply_arc_tuning_target_file() {
    # Single responsibility: write ARC tuning into target modprobe.d (does not validate bytes conversion)
    # Args: target_root arc_mode(auto|custom) arc_max
    local root; root="$(sanitize_path "${1-}")"
    local mode; mode="$(sanitize_id "${2-auto}")"
    local max; max="$(sanitize_ws "${3-}")"

    if [[ -z "$root" ]]; then
        root="$ZFSUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ "$mode" != "auto" && "$mode" != "custom" ]]; then
        mode="auto"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/modprobe.d"

    local file
    file="$(sanitize_path "$root/etc/modprobe.d/zfs-arc.conf")"

    if [[ "$mode" == "auto" || -z "$max" ]]; then
        # Remove file to keep defaults
        rm -f "$file" >/dev/null 2>&1 || true
        return 0
    fi

    # Convert suffix K/M/G/T/P to bytes (base2) if needed; accept raw digits as bytes.
    local bytes=""
    if printf '%s' "$max" | grep -Eq '^[0-9]+$'; then
        bytes="$max"
    else
        bytes="$(printf '%s' "$max" | awk '
            function mul(s){
                if(s=="K") return 1024
                if(s=="M") return 1024^2
                if(s=="G") return 1024^3
                if(s=="T") return 1024^4
                if(s=="P") return 1024^5
                return 0
            }
            {
                v=$0
                gsub(/[[:space:]]/,"",v)
                if(match(v,/^([0-9]+)([KMGTP])$/,m)){
                    printf "%.0f", (m[1]+0)*mul(m[2])
                }
            }' 2>/dev/null || true)"
        bytes="$(sanitize_ws "$bytes")"
    fi

    if [[ -z "$bytes" ]] || ! printf '%s' "$bytes" | grep -Eq '^[0-9]+$'; then
        stderr "Erro: ARC max inválido: $max"
        return 1
    fi

    {
        printf '# Generated by fileserver-installer (zfs-utils)\n'
        printf 'options zfs zfs_arc_max=%s\n' "$bytes"
    } >"$file"
}

zfsutils_set_mountpoints_final() {
    # Single responsibility: set mountpoints under / (already created) and ensure canmount rules
    # Args: root_ds
    local root_ds; root_ds="$(sanitize_ws "${1-}")"
    zfsutils_is_dataset "$root_ds" || return 1
    require_cmd zfs || return 1

    # Ensure root is canmount=noauto; children canmount=on
    zfs set canmount=noauto "$root_ds" >/dev/null 2>&1 || true
    zfs set mountpoint=/ "$root_ds" >/dev/null 2>&1 || true

    local child
    while IFS= read -r child; do
        child="$(sanitize_ws "$child")"
        [[ -z "$child" ]] && continue
        if [[ "$child" == "$root_ds" ]]; then
            continue
        fi
        zfs set canmount=on "$child" >/dev/null 2>&1 || true
    done < <(zfs list -H -r -o name "$root_ds" 2>/dev/null || true)
}
