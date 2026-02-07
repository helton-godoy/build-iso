#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: zfs-utils.sh
# Purpose: ZFS pool/vdev/dataset helpers for Debian installer environments (ZFS on Root)
# Notes:
# - Designed for lazy-loading by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

ZFSUTILS_ALLOWED_POOL_RE_DEFAULT='^[a-zA-Z][a-zA-Z0-9_.:-]{0,47}$'
ZFSUTILS_ALLOWED_DATASET_RE_DEFAULT='^[A-Za-z0-9][A-Za-z0-9_.:-]{0,47}(/[A-Za-z0-9][A-Za-z0-9_.:-]{0,47})*$'
ZFSUTILS_ALLOWED_DEV_RE_DEFAULT='^/dev/(sd[a-z]+[0-9]*|vd[a-z]+[0-9]*|xvd[a-z]+[0-9]*|nvme[0-9]+n[0-9]+p?[0-9]*|mmcblk[0-9]+p?[0-9]*)$'
ZFSUTILS_MOUNT_ROOT_DEFAULT="/mnt"
ZFSUTILS_POOL_ALTROOT_DEFAULT="/mnt"
ZFSUTILS_ASHIFT_DEFAULT="12"

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

zfsutils_loaded() { :; }

zfsutils_require_zfs() {
    require_cmd zpool || return 1
    require_cmd zfs || return 1
}

zfsutils_is_valid_pool_name() {
    local pool; pool="$(sanitize_ws "${1-}")"
    [[ -n "$pool" && "$pool" =~ $ZFSUTILS_ALLOWED_POOL_RE_DEFAULT ]]
}

zfsutils_is_valid_dataset_path() {
    local ds; ds="$(sanitize_ws "${1-}")"
    [[ -n "$ds" && "$ds" =~ $ZFSUTILS_ALLOWED_DATASET_RE_DEFAULT ]]
}

zfsutils_is_valid_dev_path() {
    local dev; dev="$(sanitize_path "${1-}")"
    [[ -n "$dev" && "$dev" =~ $ZFSUTILS_ALLOWED_DEV_RE_DEFAULT && -b "$dev" ]]
}

zfsutils_join_args() {
    # Joins args into a single safely-sanitized string for display (not execution)
    local out="" a
    for a in "$@"; do
        a="$(sanitize_ws "$a")"
        if [[ -z "$out" ]]; then
            out="$a"
        else
            out+=" $a"
        fi
    done
    stdout "$out"
}

zfsutils_pool_exists() {
    local pool; pool="$(sanitize_ws "${1-}")"
    if ! zfsutils_is_valid_pool_name "$pool"; then
        stderr "Erro: nome de pool inválido: $pool"
        return 1
    fi
    zfsutils_require_zfs || return 1
    zpool list -H -o name "$pool" >/dev/null 2>&1
}

zfsutils_dataset_exists() {
    local ds; ds="$(sanitize_ws "${1-}")"
    if ! zfsutils_is_valid_dataset_path "$ds"; then
        stderr "Erro: dataset inválido: $ds"
        return 1
    fi
    zfsutils_require_zfs || return 1
    zfs list -H -o name "$ds" >/dev/null 2>&1
}

zfsutils_pool_status_summary() {
    local pool; pool="$(sanitize_ws "${1-}")"
    if ! zfsutils_is_valid_pool_name "$pool"; then
        stderr "Erro: nome de pool inválido: $pool"
        return 1
    fi
    zfsutils_require_zfs || return 1
    zpool status -x "$pool" 2>/dev/null || return 1
}

zfsutils_list_pools() {
    zfsutils_require_zfs || return 1
    zpool list -H -o name 2>/dev/null || true
}

zfsutils_list_datasets_under_pool() {
    local pool; pool="$(sanitize_ws "${1-}")"
    if ! zfsutils_is_valid_pool_name "$pool"; then
        stderr "Erro: nome de pool inválido: $pool"
        return 1
    fi
    zfsutils_require_zfs || return 1
    zfs list -H -o name -r "$pool" 2>/dev/null || true
}

zfsutils_validate_vdev_list() {
    # Args: /dev/... partitions or disks
    # Ensures each is a block device and matches allowed regex; rejects duplicates.
    local seen="" dev norm
    if [[ $# -lt 1 ]]; then
        stderr "Erro: lista de VDEVs vazia."
        return 1
    fi
    for dev in "$@"; do
        dev="$(sanitize_path "$dev")"
        if ! zfsutils_is_valid_dev_path "$dev"; then
            stderr "Erro: VDEV inválido: $dev"
            return 1
        fi
        norm="$dev"
        if printf '%s' "$seen" | tr ' ' '\n' | grep -Fxq "$norm" 2>/dev/null; then
            stderr "Erro: VDEV duplicado: $dev"
            return 1
        fi
        if [[ -z "$seen" ]]; then
            seen="$norm"
        else
            seen+=" $norm"
        fi
    done
}

zfsutils_topology_min_disks() {
    local topo; topo="$(sanitize_id "${1-}")"
    case "$topo" in
        stripe) stdout "1" ;;
        mirror) stdout "2" ;;
        raidz1) stdout "3" ;;
        raidz2) stdout "4" ;;
        raidz3) stdout "5" ;;
        *) stdout "" ;;
    esac
}

zfsutils_validate_topology_for_disks() {
    local topo; topo="$(sanitize_id "${1-}")"
    local count; count="$(sanitize_ws "${2-}")"
    if [[ -z "$topo" || -z "$count" ]] || ! printf '%s' "$count" | grep -Eq '^[0-9]+$'; then
        stderr "Erro: parâmetros inválidos para validação de topologia."
        return 1
    fi
    local min
    min="$(zfsutils_topology_min_disks "$topo")"
    min="$(sanitize_ws "$min")"
    if [[ -z "$min" ]]; then
        stderr "Erro: topologia desconhecida: $topo"
        return 1
    fi
    if ! printf '%s' "$count" | awk -v min="$min" '{exit !($1+0 >= min+0)}'; then
        stderr "Erro: topologia '$topo' requer >= $min discos; informado: $count."
        return 1
    fi
}

zfsutils_pool_create_args_for_topology() {
    # Echoes vdev layout arguments (not including pool name nor common flags)
    # Usage: zfsutils_pool_create_args_for_topology mirror /dev/sda3 /dev/sdb3
    local topo; topo="$(sanitize_id "${1-}")"
    shift || true

    zfsutils_validate_vdev_list "$@" || return 1

    case "$topo" in
        stripe)
            printf '%s' "$(zfsutils_join_args "$@")"
            ;;
        mirror)
            printf '%s' "mirror $(zfsutils_join_args "$@")"
            ;;
        raidz1)
            printf '%s' "raidz1 $(zfsutils_join_args "$@")"
            ;;
        raidz2)
            printf '%s' "raidz2 $(zfsutils_join_args "$@")"
            ;;
        raidz3)
            printf '%s' "raidz3 $(zfsutils_join_args "$@")"
            ;;
        *)
            stderr "Erro: topologia inválida: $topo"
            return 1
            ;;
    esac
}

zfsutils_pool_create_autoroot() {
    # Single responsibility: create pool with sane flags for root installs (altroot, cachefile, ashift)
    # Args: pool topo ashift altroot cachefile dev1 dev2 ...
    local pool; pool="$(sanitize_ws "${1-}")"
    local topo; topo="$(sanitize_id "${2-}")"
    local ashift; ashift="$(sanitize_ws "${3-}")"
    local altroot; altroot="$(sanitize_path "${4-}")"
    local cachefile; cachefile="$(sanitize_path "${5-}")"
    shift 5 || true

    if ! zfsutils_is_valid_pool_name "$pool"; then
        stderr "Erro: nome de pool inválido: $pool"
        return 1
    fi
    if [[ -z "$ashift" ]] || ! printf '%s' "$ashift" | grep -Eq '^[0-9]+$'; then
        ashift="$ZFSUTILS_ASHIFT_DEFAULT"
    fi
    if [[ -z "$altroot" ]]; then
        altroot="$ZFSUTILS_POOL_ALTROOT_DEFAULT"
    fi
    if [[ -z "$cachefile" ]]; then
        cachefile="/etc/zfs/zpool.cache"
    fi

    zfsutils_require_zfs || return 1
    if zfsutils_pool_exists "$pool"; then
        stderr "Erro: pool já existe: $pool"
        return 1
    fi

    zfsutils_validate_topology_for_disks "$topo" "$#" || return 1
    zfsutils_validate_vdev_list "$@" || return 1

    local vdev_args
    if ! vdev_args="$(zfsutils_pool_create_args_for_topology "$topo" "$@")"; then
        return 1
    fi
    vdev_args="$(sanitize_ws "$vdev_args")"
    if [[ -z "$vdev_args" ]]; then
        stderr "Erro: argumentos de VDEV vazios."
        return 1
    fi

    # Common properties for a root pool (tunable per project):
    # - -o ashift
    # - -O mountpoint=none at pool level
    # - -O canmount=off at pool level
    # - -O acltype=posixacl xattr=sa (common for Linux)
    # - -O compression set later per user choice
    # - -R altroot for install environment
    # - -o cachefile to ensure persistence after install (may be relocated in chroot)
    if ! zpool create -f \
        -o "ashift=${ashift}" \
        -o "autotrim=on" \
        -o "cachefile=${cachefile}" \
        -O "mountpoint=none" \
        -O "canmount=off" \
        -O "acltype=posixacl" \
        -O "xattr=sa" \
        -O "dnodesize=auto" \
        -R "$altroot" \
        "$pool" $vdev_args >/dev/null 2>&1; then
        stderr "Erro: falha ao criar pool $pool."
        return 1
    fi
}

zfsutils_set_pool_properties_baseline() {
    # Single responsibility: set baseline properties after pool creation
    # Args: pool compression dedup atime relatime
    local pool; pool="$(sanitize_ws "${1-}")"
    local compression; compression="$(sanitize_id "${2-}")"
    local dedup; dedup="$(sanitize_id "${3-}")"
    local atime; atime="$(sanitize_id "${4-off}")"
    local relatime; relatime="$(sanitize_id "${5-off}")"

    if ! zfsutils_is_valid_pool_name "$pool"; then
        stderr "Erro: pool inválido: $pool"
        return 1
    fi
    zfsutils_require_zfs || return 1
    if ! zfsutils_pool_exists "$pool"; then
        stderr "Erro: pool não existe: $pool"
        return 1
    fi

    case "$compression" in
        lz4|zstd|zstd_*|zstd-*)
            ;;
        lzjb)
            compression="lzjb"
            ;;
        *)
            compression="zstd"
            ;;
    esac

    case "$dedup" in
        1|on|yes|true) dedup="on" ;;
        0|off|no|false|"") dedup="off" ;;
        *) dedup="off" ;;
    esac

    case "$atime" in
        on|off) ;;
        *) atime="off" ;;
    esac

    case "$relatime" in
        on|off) ;;
        *) relatime="off" ;;
    esac

    if ! zfs set "compression=${compression}" "$pool" >/dev/null 2>&1; then
        stderr "Erro: falha ao definir compression=${compression} em $pool"
        return 1
    fi
    if ! zfs set "dedup=${dedup}" "$pool" >/dev/null 2>&1; then
        stderr "Erro: falha ao definir dedup=${dedup} em $pool"
        return 1
    fi
    if ! zfs set "atime=${atime}" "$pool" >/dev/null 2>&1; then
        stderr "Erro: falha ao definir atime=${atime} em $pool"
        return 1
    fi
    if ! zfs set "relatime=${relatime}" "$pool" >/dev/null 2>&1; then
        stderr "Erro: falha ao definir relatime=${relatime} em $pool"
        return 1
    fi
}

zfsutils_create_dataset() {
    # Single responsibility: create one dataset with optional properties + mountpoint
    # Args: dataset mountpoint canmount (on|off|noauto) extra_props_kv (comma sep) key=val...
    local ds; ds="$(sanitize_ws "${1-}")"
    local mountpoint; mountpoint="$(sanitize_path "${2-}")"
    local canmount; canmount="$(sanitize_id "${3-on}")"
    local extra; extra="$(sanitize_ws "${4-}")"

    if ! zfsutils_is_valid_dataset_path "$ds"; then
        stderr "Erro: dataset inválido: $ds"
        return 1
    fi
    zfsutils_require_zfs || return 1
    if zfsutils_dataset_exists "$ds"; then
        return 0
    fi

    local args=()
    case "$canmount" in
        on|off|noauto) ;;
        *) canmount="on" ;;
    esac

    args+=("-o" "canmount=${canmount}")

    if [[ -n "$mountpoint" ]]; then
        args+=("-o" "mountpoint=${mountpoint}")
    fi

    # extra: "key=val,key=val"
    if [[ -n "$extra" ]]; then
        local kv
        while IFS=',' read -r kv; do
            kv="$(sanitize_ws "$kv")"
            if [[ -z "$kv" ]]; then
                continue
            fi
            if ! printf '%s' "$kv" | grep -Eq '^[A-Za-z0-9_][A-Za-z0-9_.:-]*=.+$'; then
                stderr "Erro: propriedade inválida: $kv"
                return 1
            fi
            args+=("-o" "$kv")
        done <<<"$extra"
    fi

    if ! zfs create "${args[@]}" "$ds" >/dev/null 2>&1; then
        stderr "Erro: falha ao criar dataset: $ds"
        return 1
    fi
}

zfsutils_create_root_layout_default() {
    # Single responsibility: create common datasets for root installs
    # Args: pool
    local pool; pool="$(sanitize_ws "${1-}")"
    if ! zfsutils_is_valid_pool_name "$pool"; then
        stderr "Erro: pool inválido: $pool"
        return 1
    fi
    zfsutils_require_zfs || return 1
    if ! zfsutils_pool_exists "$pool"; then
        stderr "Erro: pool não existe: $pool"
        return 1
    fi

    # pool/ROOT + pool/ROOT/debian as / (legacy pattern can vary)
    zfsutils_create_dataset "${pool}/ROOT" "" "off" "mountpoint=none" || return 1
    zfsutils_create_dataset "${pool}/ROOT/debian" "/" "noauto" "mountpoint=/" || return 1

    # Common mountpoints (canmount=on) under altroot
    zfsutils_create_dataset "${pool}/home" "/home" "on" "" || return 1
    zfsutils_create_dataset "${pool}/var" "/var" "on" "" || return 1
    zfsutils_create_dataset "${pool}/var/log" "/var/log" "on" "" || return 1
    zfsutils_create_dataset "${pool}/var/cache" "/var/cache" "on" "" || return 1
    zfsutils_create_dataset "${pool}/tmp" "/tmp" "on" "setuid=off,devices=off,exec=on" || return 1

    # Optional: /usr as dataset (some prefer keep in root)
    zfsutils_create_dataset "${pool}/usr" "/usr" "on" "" || return 1
}

zfsutils_mount_root_dataset() {
    # Single responsibility: mount root dataset (canmount=noauto) to given mount root
    # Args: root_dataset mount_root
    local root_ds; root_ds="$(sanitize_ws "${1-}")"
    local mount_root; mount_root="$(sanitize_path "${2-}")"

    if ! zfsutils_is_valid_dataset_path "$root_ds"; then
        stderr "Erro: dataset root inválido: $root_ds"
        return 1
    fi
    if [[ -z "$mount_root" ]]; then
        mount_root="$ZFSUTILS_MOUNT_ROOT_DEFAULT"
    fi
    zfsutils_require_zfs || return 1
    require_cmd mkdir || return 1

    mkdir -p "$mount_root"
    if ! zfs mount "$root_ds" >/dev/null 2>&1; then
        # Some setups require explicit mountpoint or legacy mount.
        # Try setting mountpoint to mount_root if dataset is noauto and mountpoint is /
        if ! zfs set "mountpoint=${mount_root}" "$root_ds" >/dev/null 2>&1; then
            stderr "Erro: falha ao ajustar mountpoint para ${mount_root} em ${root_ds}"
            return 1
        fi
        if ! zfs mount "$root_ds" >/dev/null 2>&1; then
            stderr "Erro: falha ao montar dataset root: $root_ds"
            return 1
        fi
    fi
}

zfsutils_export_pool() {
    local pool; pool="$(sanitize_ws "${1-}")"
    if ! zfsutils_is_valid_pool_name "$pool"; then
        stderr "Erro: pool inválido: $pool"
        return 1
    fi
    zfsutils_require_zfs || return 1
    if ! zfsutils_pool_exists "$pool"; then
        return 0
    fi
    if ! zpool export "$pool" >/dev/null 2>&1; then
        stderr "Erro: falha ao exportar pool: $pool"
        return 1
    fi
}

zfsutils_import_pool_altroot() {
    # Single responsibility: import pool with altroot
    # Args: pool altroot cachefile
    local pool; pool="$(sanitize_ws "${1-}")"
    local altroot; altroot="$(sanitize_path "${2-}")"
    local cachefile; cachefile="$(sanitize_path "${3-}")"

    if ! zfsutils_is_valid_pool_name "$pool"; then
        stderr "Erro: pool inválido: $pool"
        return 1
    fi
    if [[ -z "$altroot" ]]; then
        altroot="$ZFSUTILS_POOL_ALTROOT_DEFAULT"
    fi
    if [[ -z "$cachefile" ]]; then
        cachefile="/etc/zfs/zpool.cache"
    fi

    zfsutils_require_zfs || return 1
    require_cmd mkdir || return 1
    mkdir -p "$altroot"

    if zfsutils_pool_exists "$pool"; then
        return 0
    fi

    if ! zpool import -N -R "$altroot" -o "cachefile=${cachefile}" "$pool" >/dev/null 2>&1; then
        stderr "Erro: falha ao importar pool $pool com altroot $altroot"
        return 1
    fi
}

zfsutils_set_arc_max_bytes() {
    # Single responsibility: write arc_max parameter for runtime (best-effort) and persist via modprobe.d
    # Args: bytes_or_human (e.g., 4294967296 or 4G) out_dir_for_persist (e.g., /etc/modprobe.d)
    local val; val="$(sanitize_ws "${1-}")"
    local outdir; outdir="$(sanitize_path "${2-}")"

    if [[ -z "$val" ]]; then
        stderr "Erro: ARC max vazio."
        return 1
    fi
    if [[ -z "$outdir" ]]; then
        outdir="/etc/modprobe.d"
    fi
    require_cmd mkdir || return 1
    mkdir -p "$outdir"

    # Convert human to bytes if numfmt exists; otherwise accept numeric only
    local bytes
    if command -v numfmt >/dev/null 2>&1; then
        if ! bytes="$(numfmt --from=iec --to=none "$val" 2>/dev/null || true)"; then
            bytes=""
        fi
        bytes="$(sanitize_ws "$bytes")"
        if [[ -z "$bytes" ]]; then
            if ! bytes="$(numfmt --from=si --to=none "$val" 2>/dev/null || true)"; then
                bytes=""
            fi
        fi
        bytes="$(sanitize_ws "$bytes")"
    else
        bytes="$(sanitize_ws "$val")"
    fi

    if [[ -z "$bytes" ]] || ! printf '%s' "$bytes" | grep -Eq '^[0-9]+$'; then
        stderr "Erro: valor ARC max inválido: $val"
        return 1
    fi

    # Best-effort runtime set
    if [[ -w /sys/module/zfs/parameters/zfs_arc_max ]]; then
        printf '%s' "$bytes" >/sys/module/zfs/parameters/zfs_arc_max 2>/dev/null || true
    fi

    local conf
    conf="$(sanitize_path "${outdir}/zfs.conf")"
    # Ensure single-line option
    local line
    line="options zfs zfs_arc_max=${bytes}"
    if [[ -f "$conf" ]]; then
        if grep -Eq '^[[:space:]]*options[[:space:]]+zfs[[:space:]]+zfs_arc_max=' "$conf" 2>/dev/null; then
            sed -i -E "s/^[[:space:]]*options[[:space:]]+zfs[[:space:]]+zfs_arc_max=.*/${line}/" "$conf" || true
        else
            printf '%s\n' "$line" >>"$conf"
        fi
    else
        printf '%s\n' "$line" >"$conf"
    fi
}

zfsutils_recommend_dedup_warning() {
    # Single responsibility: returns 0 if dedup is considered risky for typical installs
    # Args: dedup (on/off/1/0)
    local dedup; dedup="$(sanitize_id "${1-}")"
    case "$dedup" in
        on|1|yes|true) return 0 ;;
        *) return 1 ;;
    esac
}

zfsutils_dataset_set_properties() {
    # Single responsibility: set multiple properties (comma separated key=val) on dataset
    # Args: dataset props_csv
    local ds; ds="$(sanitize_ws "${1-}")"
    local props; props="$(sanitize_ws "${2-}")"

    if ! zfsutils_is_valid_dataset_path "$ds"; then
        stderr "Erro: dataset inválido: $ds"
        return 1
    fi
    if [[ -z "$props" ]]; then
        return 0
    fi
    zfsutils_require_zfs || return 1

    local kv
    while IFS=',' read -r kv; do
        kv="$(sanitize_ws "$kv")"
        if [[ -z "$kv" ]]; then
            continue
        fi
        if ! printf '%s' "$kv" | grep -Eq '^[A-Za-z0-9_][A-Za-z0-9_.:-]*=.+$'; then
            stderr "Erro: propriedade inválida: $kv"
            return 1
        fi
        if ! zfs set "$kv" "$ds" >/dev/null 2>&1; then
            stderr "Erro: falha ao definir $kv em $ds"
            return 1
        fi
    done <<<"$props"
}

zfsutils_umount_all_under_altroot() {
    # Single responsibility: unmount all datasets (best-effort) under given pool
    # Args: pool
    local pool; pool="$(sanitize_ws "${1-}")"
    if ! zfsutils_is_valid_pool_name "$pool"; then
        stderr "Erro: pool inválido: $pool"
        return 1
    fi
    zfsutils_require_zfs || return 1

    # Unmount children first: reverse depth by path length
    local list
    if ! list="$(zfs list -H -o name -r "$pool" 2>/dev/null | awk '{print length($0) "\t" $0}' | sort -rn | cut -f2-)"; then
        return 0
    fi
    list="$(sanitize_ws "$list")"
    if [[ -z "$list" ]]; then
        return 0
    fi

    if ! printf '%s\n' "$list" | while IFS= read -r ds; do
        ds="$(sanitize_ws "$ds")"
        if [[ -z "$ds" ]]; then
            continue
        fi
        zfs unmount "$ds" >/dev/null 2>&1 || true
    done; then
        return 1
    fi
}
