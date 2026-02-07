#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: validate-utils.sh
# Purpose: preflight and configuration validation (network, storage, ZFS, boot) for installer checkpoint
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

VALIDATE_ALLOWED_HOST_RE_DEFAULT='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
VALIDATE_ALLOWED_DOMAIN_RE_DEFAULT='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z]{2,63}$'
VALIDATE_ALLOWED_USER_RE_DEFAULT='^[a-z_][a-z0-9_-]{0,31}$'
VALIDATE_ALLOWED_TZ_RE_DEFAULT='^[A-Za-z]+(/[A-Za-z0-9._+-]+)+$'
VALIDATE_ALLOWED_IPV4_RE_DEFAULT='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
VALIDATE_ALLOWED_CIDR_RE_DEFAULT='^([0-9]|[12][0-9]|3[0-2])$'
VALIDATE_ALLOWED_PROXY_RE_DEFAULT='^(https?://)?[^[:space:]]+$'

stderr() { printf '%s\n' "$*" >&2; }
stdout() { printf '%s\n' "$*"; }

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

validateutils_loaded() { :; }

validate_is_hostname() {
    local hn; hn="$(sanitize_ws "${1-}")"
    [[ -n "$hn" && "$hn" =~ $VALIDATE_ALLOWED_HOST_RE_DEFAULT ]]
}

validate_is_domain_optional() {
    local dom; dom="$(sanitize_ws "${1-}")"
    if [[ -z "$dom" ]]; then
        return 0
    fi
    [[ "$dom" =~ $VALIDATE_ALLOWED_DOMAIN_RE_DEFAULT ]]
}

validate_is_username() {
    local u; u="$(sanitize_ws "${1-}")"
    [[ -n "$u" && "$u" =~ $VALIDATE_ALLOWED_USER_RE_DEFAULT ]]
}

validate_is_tz() {
    local tz; tz="$(sanitize_ws "${1-}")"
    [[ -n "$tz" && "$tz" =~ $VALIDATE_ALLOWED_TZ_RE_DEFAULT ]]
}

validate_is_ipv4() {
    local ip; ip="$(sanitize_ws "${1-}")"
    [[ -n "$ip" && "$ip" =~ $VALIDATE_ALLOWED_IPV4_RE_DEFAULT ]]
}

validate_is_cidr() {
    local cidr; cidr="$(sanitize_ws "${1-}")"
    [[ -n "$cidr" && "$cidr" =~ $VALIDATE_ALLOWED_CIDR_RE_DEFAULT ]]
}

validate_is_proxy_optional() {
    local p; p="$(sanitize_ws "${1-}")"
    if [[ -z "$p" ]]; then
        return 0
    fi
    [[ "$p" =~ $VALIDATE_ALLOWED_PROXY_RE_DEFAULT ]]
}

validate_is_bool01() {
    local v; v="$(sanitize_ws "${1-}")"
    [[ "$v" == "0" || "$v" == "1" ]]
}

validate_is_zfs_strategy() {
    local v; v="$(sanitize_id "${1-}")"
    [[ "$v" == "auto" || "$v" == "manual" ]]
}

validate_is_bootloader() {
    local v; v="$(sanitize_id "${1-}")"
    [[ "$v" == "grub" || "$v" == "refind" || "$v" == "zfsbootmenu" || "$v" == "none" ]]
}

validate_is_zfs_topology() {
    local v; v="$(sanitize_id "${1-}")"
    [[ "$v" == "stripe" || "$v" == "mirror" || "$v" == "raidz1" || "$v" == "raidz2" || "$v" == "raidz3" ]]
}

validate_is_compression() {
    local v; v="$(sanitize_id "${1-}")"
    [[ "$v" == "zstd" || "$v" == "lz4" || "$v" == "lzjb" ]]
}

validate_is_dedup_toggle() {
    local v; v="$(sanitize_id "${1-}")"
    [[ "$v" == "0" || "$v" == "1" || "$v" == "on" || "$v" == "off" ]]
}

validate_is_dataset_preset() {
    local v; v="$(sanitize_id "${1-}")"
    [[ "$v" == "default" || "$v" == "server" || "$v" == "custom" ]]
}

validate_net_dns_list_optional() {
    # Space-separated IPv4 list (can be empty)
    local list; list="$(sanitize_ws "${1-}")"
    if [[ -z "$list" ]]; then
        return 0
    fi
    local item
    while IFS= read -r item; do
        item="$(sanitize_ws "$item")"
        if [[ -z "$item" ]]; then
            continue
        fi
        if ! validate_is_ipv4 "$item"; then
            return 1
        fi
    done < <(printf '%s' "$list" | tr ' ' '\n' | sed -E '/^[[:space:]]*$/d')
}

validate_preflight_tools_minimal() {
    # Single responsibility: ensure minimal commands used by installer are present
    # Returns 0 only if all mandatory tools exist.
    local missing=0

    local cmds
    cmds="sed awk grep printf mkdir mount umount lsblk"
    local c
    for c in $cmds; do
        if ! command -v "$c" >/dev/null 2>&1; then
            stderr "Erro: ferramenta obrigatória ausente: $c"
            missing=$((missing + 1))
        fi
    done

    if (( missing > 0 )); then
        return 1
    fi
}

validate_network_config_from_env() {
    # Single responsibility: validate network state variables loaded by router state.env
    # Expected vars:
    #   install_net_method=dhcp|manual
    #   install_net_ip, install_net_mask (cidr), install_net_gw, install_net_dns
    local method; method="$(sanitize_id "${install_net_method-}")"
    if [[ -z "$method" ]]; then
        stderr "Erro: install_net_method não definido."
        return 1
    fi
    if [[ "$method" != "dhcp" && "$method" != "manual" ]]; then
        stderr "Erro: install_net_method inválido: $method"
        return 1
    fi

    if [[ "$method" == "manual" ]]; then
        local ip mask gw dns
        ip="$(sanitize_ws "${install_net_ip-}")"
        mask="$(sanitize_ws "${install_net_mask-}")"
        gw="$(sanitize_ws "${install_net_gw-}")"
        dns="$(sanitize_ws "${install_net_dns-}")"

        if ! validate_is_ipv4 "$ip"; then
            stderr "Erro: IP inválido: $ip"
            return 1
        fi
        if ! validate_is_cidr "$mask"; then
            stderr "Erro: CIDR inválido: $mask"
            return 1
        fi
        if ! validate_is_ipv4 "$gw"; then
            stderr "Erro: Gateway inválido: $gw"
            return 1
        fi
        if ! validate_net_dns_list_optional "$dns"; then
            stderr "Erro: DNS inválido: $dns"
            return 1
        fi
    fi

    local proxy
    proxy="$(sanitize_ws "${install_proxy-}")"
    if ! validate_is_proxy_optional "$proxy"; then
        stderr "Erro: Proxy inválido: $proxy"
        return 1
    fi
}

validate_identity_from_env() {
    # Single responsibility: validate hostname/domain variables
    local hn dom
    hn="$(sanitize_ws "${install_hostname-}")"
    dom="$(sanitize_ws "${install_domain-}")"

    if ! validate_is_hostname "$hn"; then
        stderr "Erro: Hostname inválido: $hn"
        return 1
    fi
    if ! validate_is_domain_optional "$dom"; then
        stderr "Erro: Domínio inválido: $dom"
        return 1
    fi
}

validate_user_from_env() {
    # Single responsibility: validate user and admin policy variables
    local user full policy
    user="$(sanitize_ws "${install_username-}")"
    full="$(sanitize_ws "${install_user_fullname-}")"
    policy="$(sanitize_id "${install_admin_policy-}")"

    if [[ -z "$full" ]]; then
        stderr "Erro: Nome completo vazio."
        return 1
    fi
    if ! validate_is_username "$user"; then
        stderr "Erro: Username inválido: $user"
        return 1
    fi
    if [[ "$policy" != "sudo" && "$policy" != "root" ]]; then
        stderr "Erro: Política admin inválida: $policy"
        return 1
    fi
}

validate_time_from_env() {
    # Single responsibility: validate timezone and ntp flags
    local tz ntp
    tz="$(sanitize_ws "${install_tz-}")"
    ntp="$(sanitize_ws "${install_ntp-0}")"

    if ! validate_is_tz "$tz"; then
        stderr "Erro: Timezone inválido: $tz"
        return 1
    fi
    if ! validate_is_bool01 "$ntp"; then
        stderr "Erro: install_ntp inválido: $ntp"
        return 1
    fi
}

validate_storage_from_env() {
    # Single responsibility: validate disk target and wipe confirmation
    local disk wipe
    disk="$(sanitize_path "${install_disk-}")"
    wipe="$(sanitize_ws "${install_wipe_confirmed-0}")"
    if [[ -z "$disk" ]]; then
        stderr "Erro: install_disk vazio."
        return 1
    fi
    if ! validate_is_bool01 "$wipe"; then
        stderr "Erro: install_wipe_confirmed inválido: $wipe"
        return 1
    fi
    if [[ "$wipe" != "1" ]]; then
        stderr "Erro: wipe não confirmado."
        return 1
    fi
}

validate_zfs_from_env() {
    # Single responsibility: validate ZFS strategy/topology/properties selections
    local strategy topo pool comp dedup preset
    strategy="$(sanitize_id "${install_zfs_strategy-}")"
    topo="$(sanitize_id "${zfs_topology-}")"
    pool="$(sanitize_ws "${zfs_pool_name-}")"
    comp="$(sanitize_id "${zfs_compression-}")"
    dedup="$(sanitize_id "${zfs_dedup-}")"
    preset="$(sanitize_id "${zfs_dataset_preset-}")"

    if ! validate_is_zfs_strategy "$strategy"; then
        stderr "Erro: estratégia ZFS inválida: $strategy"
        return 1
    fi

    if [[ "$strategy" == "auto" ]]; then
        if ! validate_is_zfs_topology "$topo"; then
            stderr "Erro: topologia ZFS inválida: $topo"
            return 1
        fi
        if [[ -z "$pool" ]]; then
            stderr "Erro: nome do pool vazio."
            return 1
        fi
        if ! printf '%s' "$pool" | grep -Eq '^[A-Za-z][A-Za-z0-9_.:-]{0,47}$'; then
            stderr "Erro: nome do pool inválido: $pool"
            return 1
        fi
        if ! validate_is_compression "$comp"; then
            stderr "Erro: compressão inválida: $comp"
            return 1
        fi
        if ! validate_is_dedup_toggle "$dedup"; then
            stderr "Erro: dedup inválido: $dedup"
            return 1
        fi
        if ! validate_is_dataset_preset "$preset"; then
            stderr "Erro: preset datasets inválido: $preset"
            return 1
        fi
    fi
}

validate_boot_from_env() {
    # Single responsibility: validate bootloader selection and optional kernel params
    local bl
    bl="$(sanitize_id "${bootloader-}")"
    if [[ -z "$bl" ]]; then
        stderr "Erro: bootloader não definido."
        return 1
    fi
    if ! validate_is_bootloader "$bl"; then
        stderr "Erro: bootloader inválido: $bl"
        return 1
    fi
}

validate_all_checkpoint() {
    # Single responsibility: validate whole config at review checkpoint
    validate_preflight_tools_minimal || return 1
    validate_identity_from_env || return 1
    validate_network_config_from_env || return 1
    validate_time_from_env || return 1
    validate_user_from_env || return 1
    validate_storage_from_env || return 1
    validate_zfs_from_env || return 1
    validate_boot_from_env || return 1
}
