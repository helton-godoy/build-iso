#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: validate-utils.sh
# Purpose: validate configuration state (disk/network/time/users/zfs/boot) as a whole
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

VALIDATE_ALLOWED_DISK_RE_DEFAULT='^/dev/(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$'
VALIDATE_ALLOWED_POOL_RE_DEFAULT='^[A-Za-z][A-Za-z0-9_.:-]{0,47}$'
VALIDATE_ALLOWED_TOPO_RE_DEFAULT='^(stripe|mirror|raidz1|raidz2|raidz3)$'
VALIDATE_ALLOWED_COMP_RE_DEFAULT='^(zstd|lz4|lzjb)$'
VALIDATE_ALLOWED_TZ_RE_DEFAULT='^[A-Za-z]+(/[A-Za-z0-9._+-]+)+$'
VALIDATE_ALLOWED_KEYMAP_RE_DEFAULT='^[a-z0-9_-]{1,32}$'
VALIDATE_ALLOWED_LOCALE_RE_DEFAULT='^[A-Za-z]{2}_[A-Za-z]{2}\.UTF-8$'
VALIDATE_ALLOWED_HOST_RE_DEFAULT='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
VALIDATE_ALLOWED_DOMAIN_RE_DEFAULT='^$|^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z]{2,63}$'
VALIDATE_ALLOWED_USER_RE_DEFAULT='^[a-z_][a-z0-9_-]{0,31}$'
VALIDATE_ALLOWED_NET_METHOD_RE_DEFAULT='^(dhcp|manual)$'
VALIDATE_ALLOWED_BOOTLOADER_RE_DEFAULT='^(grub|refind|zfsbootmenu|none)$'
VALIDATE_ALLOWED_ARC_MODE_RE_DEFAULT='^(auto|custom)$'
VALIDATE_ALLOWED_ARC_RE_DEFAULT='^[0-9]+$|^[0-9]+[KMGTP]$'
VALIDATE_ALLOWED_ASHIFT_RE_DEFAULT='^[0-9]{1,2}$'

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

validate_loaded() { :; }

validate_regex() {
    # Single responsibility: validate string against regex (grep -E)
    # Args: value regex
    local val; val="$(sanitize_ws "${1-}")"
    local re; re="${2-}"
    if [[ -z "$re" ]]; then
        return 1
    fi
    printf '%s' "$val" | grep -Eq "$re"
}

validate_file_exists() {
    local p; p="$(sanitize_path "${1-}")"
    [[ -n "$p" && -f "$p" ]]
}

validate_block_device() {
    local p; p="$(sanitize_path "${1-}")"
    [[ -n "$p" && -b "$p" ]]
}

validate_bool01() {
    local v; v="$(sanitize_ws "${1-}")"
    [[ "$v" == "0" || "$v" == "1" ]]
}

validate_ipv4() {
    local ip; ip="$(sanitize_ws "${1-}")"
    if [[ -z "$ip" ]]; then
        return 1
    fi
    printf '%s' "$ip" | awk -F. '
        NF!=4{exit 1}
        {for(i=1;i<=4;i++){if($i!~/^[0-9]+$/||$i<0||$i>255)exit 1}}
        END{exit 0}'
}

validate_ipv4_list_space() {
    local list; list="$(sanitize_ws "${1-}")"
    if [[ -z "$list" ]]; then
        return 1
    fi
    local ip
    while IFS= read -r ip; do
        ip="$(sanitize_ws "$ip")"
        [[ -z "$ip" ]] && continue
        validate_ipv4 "$ip" || return 1
    done < <(printf '%s' "$list" | tr ' ' '\n' | sed -E '/^[[:space:]]*$/d')
}

validate_hostname_domain() {
    local hn; hn="$(sanitize_ws "${1-}")"
    local dom; dom="$(sanitize_ws "${2-}")"
    validate_regex "$hn" "$VALIDATE_ALLOWED_HOST_RE_DEFAULT" || return 1
    validate_regex "$dom" "$VALIDATE_ALLOWED_DOMAIN_RE_DEFAULT" || return 1
}

validate_users() {
    local user; user="$(sanitize_ws "${1-}")"
    local full; full="$(sanitize_ws "${2-}")"
    local pw1; pw1="$(sanitize_ws "${3-}")"
    local pw2; pw2="$(sanitize_ws "${4-}")"

    validate_regex "$user" "$VALIDATE_ALLOWED_USER_RE_DEFAULT" || return 1
    [[ -n "$full" ]] || return 1
    [[ -n "$pw1" && -n "$pw2" && "$pw1" == "$pw2" ]] || return 1

    if declare -F authutils_password_validate_all >/dev/null 2>&1; then
        authutils_password_validate_all "$pw1" "" "" || return 1
    fi
}

validate_root_policy() {
    local enable; enable="$(sanitize_ws "${1-0}")"
    local same; same="$(sanitize_ws "${2-0}")"
    local rp1; rp1="$(sanitize_ws "${3-}")"
    local rp2; rp2="$(sanitize_ws "${4-}")"
    local upw1; upw1="$(sanitize_ws "${5-}")"
    local upw2; upw2="$(sanitize_ws "${6-}")"

    validate_bool01 "$enable" || return 1
    validate_bool01 "$same" || return 1

    if [[ "$same" == "1" ]]; then
        enable="1"
        rp1="$upw1"
        rp2="$upw2"
    fi

    if [[ "$enable" == "0" ]]; then
        return 0
    fi

    [[ -n "$rp1" && -n "$rp2" && "$rp1" == "$rp2" ]] || return 1
    if declare -F authutils_password_validate_all >/dev/null 2>&1; then
        authutils_password_validate_all "$rp1" "" "" || return 1
    fi
}

validate_storage() {
    local disk; disk="$(sanitize_path "${1-}")"
    local wipe; wipe="$(sanitize_ws "${2-0}")"
    if ! validate_regex "$disk" "$VALIDATE_ALLOWED_DISK_RE_DEFAULT"; then
        return 1
    fi
    validate_block_device "$disk" || return 1
    validate_bool01 "$wipe" || return 1
    [[ "$wipe" == "1" ]]
}

validate_zfs() {
    local strategy; strategy="$(sanitize_id "${1-auto}")"
    local topo; topo="$(sanitize_id "${2-mirror}")"
    local pool; pool="$(sanitize_ws "${3-rpool}")"
    local comp; comp="$(sanitize_id "${4-zstd}")"
    local dedup; dedup="$(sanitize_id "${5-0}")"
    local ashift; ashift="$(sanitize_ws "${6-12}")"
    local arc_mode; arc_mode="$(sanitize_id "${7-auto}")"
    local arc_max; arc_max="$(sanitize_ws "${8-}")"

    [[ "$strategy" == "auto" || "$strategy" == "manual" ]] || return 1
    validate_regex "$topo" "$VALIDATE_ALLOWED_TOPO_RE_DEFAULT" || return 1
    validate_regex "$pool" "$VALIDATE_ALLOWED_POOL_RE_DEFAULT" || return 1
    validate_regex "$comp" "$VALIDATE_ALLOWED_COMP_RE_DEFAULT" || return 1
    [[ "$dedup" == "0" || "$dedup" == "1" || "$dedup" == "on" || "$dedup" == "off" ]] || return 1
    validate_regex "$ashift" "$VALIDATE_ALLOWED_ASHIFT_RE_DEFAULT" || return 1

    validate_regex "$arc_mode" "$VALIDATE_ALLOWED_ARC_MODE_RE_DEFAULT" || return 1
    if [[ "$arc_mode" == "custom" ]]; then
        validate_regex "$arc_max" "$VALIDATE_ALLOWED_ARC_RE_DEFAULT" || return 1
    fi
}

validate_boot() {
    local bl; bl="$(sanitize_id "${1-grub}")"
    validate_regex "$bl" "$VALIDATE_ALLOWED_BOOTLOADER_RE_DEFAULT" || return 1
}

validate_locale() {
    local lang; lang="$(sanitize_ws "${1-}")"
    local locale; locale="$(sanitize_ws "${2-}")"
    local keymap; keymap="$(sanitize_ws "${3-}")"
    validate_regex "$lang" "$VALIDATE_ALLOWED_LOCALE_RE_DEFAULT" || return 1
    validate_regex "$locale" "$VALIDATE_ALLOWED_LOCALE_RE_DEFAULT" || return 1
    validate_regex "$keymap" "$VALIDATE_ALLOWED_KEYMAP_RE_DEFAULT" || return 1
}

validate_time() {
    local tz; tz="$(sanitize_ws "${1-UTC}")"
    local ntp; ntp="$(sanitize_ws "${2-1}")"
    local srv; srv="$(sanitize_ws "${3-pool.ntp.org}")"

    validate_regex "$tz" "$VALIDATE_ALLOWED_TZ_RE_DEFAULT" || return 1
    validate_bool01 "$ntp" || return 1
    if [[ "$ntp" == "1" ]]; then
        [[ -n "$srv" ]] || return 1
        printf '%s' "$srv" | grep -Eq '^[^[:space:]]+$' || return 1
    fi
}

validate_network() {
    local method; method="$(sanitize_id "${1-dhcp}")"
    local ip; ip="$(sanitize_ws "${2-}")"
    local mask; mask="$(sanitize_ws "${3-}")"
    local gw; gw="$(sanitize_ws "${4-}")"
    local dns; dns="$(sanitize_ws "${5-}")"
    validate_regex "$method" "$VALIDATE_ALLOWED_NET_METHOD_RE_DEFAULT" || return 1

    if [[ "$method" == "dhcp" ]]; then
        return 0
    fi

    validate_ipv4 "$ip" || return 1
    local cidr; cidr="$(sanitize_uint "$mask")"
    if [[ -z "$cidr" ]]; then
        return 1
    fi
    if ! printf '%s' "$cidr" | awk '{exit !($1+0>=0 && $1+0<=32)}'; then
        return 1
    fi
    validate_ipv4 "$gw" || return 1
    validate_ipv4_list_space "$dns" || return 1
}

validate_all_checkpoint() {
    # Single responsibility: validate the whole configuration in current shell (expects state env already sourced)
    # Returns 0 if OK, 1 if invalid.
    local ok=1

    # shellcheck disable=SC2154
    validate_hostname_domain "${install_hostname-}" "${install_domain-}" || { stderr "Erro: hostname/domínio inválidos."; ok=0; }
    validate_locale "${install_lang-}" "${install_locale-}" "${install_keymap-}" || { stderr "Erro: locale/keymap inválidos."; ok=0; }
    validate_time "${install_tz-UTC}" "${install_ntp-1}" "${install_ntp_server-pool.ntp.org}" || { stderr "Erro: timezone/NTP inválidos."; ok=0; }

    validate_users "${install_username-}" "${install_user_fullname-}" "${install_user_password-}" "${install_user_password_confirm-}" || { stderr "Erro: usuário/senha inválidos."; ok=0; }
    validate_root_policy "${install_root_enable-0}" "${install_root_same_as_user-0}" "${install_root_password-}" "${install_root_password_confirm-}" "${install_user_password-}" "${install_user_password_confirm-}" || { stderr "Erro: política root inválida."; ok=0; }

    validate_network "${install_net_method-dhcp}" "${install_net_ip-}" "${install_net_mask-}" "${install_net_gw-}" "${install_net_dns-}" || { stderr "Erro: rede inválida."; ok=0; }

    validate_storage "${install_disk-}" "${install_wipe_confirmed-0}" || { stderr "Erro: armazenamento inválido (disco/wipe)."; ok=0; }

    validate_zfs "${install_zfs_strategy-auto}" "${zfs_topology-mirror}" "${zfs_pool_name-rpool}" "${zfs_compression-zstd}" "${zfs_dedup-0}" "${zfs_ashift-12}" "${zfs_arc_mode-auto}" "${zfs_arc_max-}" || { stderr "Erro: ZFS inválido."; ok=0; }

    validate_boot "${bootloader-grub}" || { stderr "Erro: bootloader inválido."; ok=0; }

    if [[ "$ok" == "1" ]]; then
        return 0
    fi
    return 1
}
