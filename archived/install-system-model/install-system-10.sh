#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: net-utils.sh
# Purpose: network discovery/configuration helpers (DHCP/manual), connectivity checks, proxy env
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

NETUTILS_ALLOWED_IF_RE_DEFAULT='^[a-zA-Z0-9_.:-]{1,32}$'
NETUTILS_ALLOWED_IPV4_RE_DEFAULT='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
NETUTILS_ALLOWED_CIDR_RE_DEFAULT='^([0-9]|[12][0-9]|3[0-2])$'
NETUTILS_ALLOWED_PROXY_RE_DEFAULT='^(https?://)?[^[:space:]]+$'
NETUTILS_DEFAULT_TEST_HOST="deb.debian.org"
NETUTILS_DEFAULT_TEST_IP="1.1.1.1"

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

netutils_loaded() { :; }

netutils_is_iface() {
    local ifc; ifc="$(sanitize_ws "${1-}")"
    [[ -n "$ifc" && "$ifc" =~ $NETUTILS_ALLOWED_IF_RE_DEFAULT ]]
}

netutils_is_ipv4() {
    local ip; ip="$(sanitize_ws "${1-}")"
    [[ -n "$ip" && "$ip" =~ $NETUTILS_ALLOWED_IPV4_RE_DEFAULT ]]
}

netutils_is_cidr() {
    local cidr; cidr="$(sanitize_ws "${1-}")"
    [[ -n "$cidr" && "$cidr" =~ $NETUTILS_ALLOWED_CIDR_RE_DEFAULT ]]
}

netutils_is_proxy_optional() {
    local p; p="$(sanitize_ws "${1-}")"
    if [[ -z "$p" ]]; then
        return 0
    fi
    [[ "$p" =~ $NETUTILS_ALLOWED_PROXY_RE_DEFAULT ]]
}

netutils_list_ifaces() {
    # Single responsibility: list usable network interfaces (excluding lo)
    require_cmd ip || return 1
    ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | sed -E 's/@.*$//' | grep -Ev '^lo$' || true
}

netutils_iface_link_up() {
    # Single responsibility: bring interface link up
    # Args: iface
    local ifc; ifc="$(sanitize_ws "${1-}")"
    if ! netutils_is_iface "$ifc"; then
        stderr "Erro: interface inválida: $ifc"
        return 1
    fi
    require_cmd ip || return 1
    ip link set dev "$ifc" up >/dev/null 2>&1 || return 1
}

netutils_dhcp_acquire() {
    # Single responsibility: request DHCP lease (best-effort)
    # Args: iface
    local ifc; ifc="$(sanitize_ws "${1-}")"
    if ! netutils_is_iface "$ifc"; then
        stderr "Erro: interface inválida: $ifc"
        return 1
    fi

    netutils_iface_link_up "$ifc" || return 1

    if command -v dhclient >/dev/null 2>&1; then
        dhclient -v -1 "$ifc" >/dev/null 2>&1 || return 1
        return 0
    fi
    if command -v udhcpc >/dev/null 2>&1; then
        udhcpc -i "$ifc" -n -q >/dev/null 2>&1 || return 1
        return 0
    fi

    stderr "Erro: nenhum cliente DHCP encontrado (dhclient/udhcpc)."
    return 1
}

netutils_set_ipv4_manual() {
    # Single responsibility: set IPv4 addr and gateway
    # Args: iface ip cidr gateway
    local ifc; ifc="$(sanitize_ws "${1-}")"
    local ipaddr; ipaddr="$(sanitize_ws "${2-}")"
    local cidr; cidr="$(sanitize_ws "${3-}")"
    local gw; gw="$(sanitize_ws "${4-}")"

    if ! netutils_is_iface "$ifc"; then
        stderr "Erro: interface inválida: $ifc"
        return 1
    fi
    if ! netutils_is_ipv4 "$ipaddr"; then
        stderr "Erro: IP inválido: $ipaddr"
        return 1
    fi
    if ! netutils_is_cidr "$cidr"; then
        stderr "Erro: CIDR inválido: $cidr"
        return 1
    fi
    if ! netutils_is_ipv4 "$gw"; then
        stderr "Erro: gateway inválido: $gw"
        return 1
    fi

    require_cmd ip || return 1

    netutils_iface_link_up "$ifc" || return 1
    ip addr flush dev "$ifc" >/dev/null 2>&1 || true
    ip addr add "${ipaddr}/${cidr}" dev "$ifc" >/dev/null 2>&1 || return 1
    ip route replace default via "$gw" dev "$ifc" >/dev/null 2>&1 || return 1
}

netutils_write_resolv_conf() {
    # Single responsibility: write resolv.conf in current environment (installer)
    # Args: dns_list_space_separated
    local dns; dns="$(sanitize_ws "${1-}")"
    if [[ -z "$dns" ]]; then
        return 0
    fi
    local file
    file="/etc/resolv.conf"

    if [[ -L "$file" ]]; then
        return 0
    fi

    : >"$file"
    local ip
    while IFS= read -r ip; do
        ip="$(sanitize_ws "$ip")"
        if [[ -z "$ip" ]]; then
            continue
        fi
        if ! netutils_is_ipv4 "$ip"; then
            stderr "Erro: DNS inválido: $ip"
            return 1
        fi
        printf 'nameserver %s\n' "$ip" >>"$file"
    done < <(printf '%s' "$dns" | tr ' ' '\n' | sed -E '/^[[:space:]]*$/d')
}

netutils_export_proxy_env() {
    # Single responsibility: export proxy variables for current environment
    # Args: proxy_url
    local proxy; proxy="$(sanitize_ws "${1-}")"
    if [[ -z "$proxy" ]]; then
        return 0
    fi
    if ! netutils_is_proxy_optional "$proxy"; then
        stderr "Erro: proxy inválido: $proxy"
        return 1
    fi
    export http_proxy="$proxy"
    export https_proxy="$proxy"
    export HTTP_PROXY="$proxy"
    export HTTPS_PROXY="$proxy"
}

netutils_connectivity_check() {
    # Single responsibility: perform basic connectivity checks (ICMP and DNS/HTTP best-effort)
    # Args: test_host(optional) test_ip(optional)
    local host; host="$(sanitize_ws "${1-}")"
    local ip; ip="$(sanitize_ws "${2-}")"
    if [[ -z "$host" ]]; then
        host="$NETUTILS_DEFAULT_TEST_HOST"
    fi
    if [[ -z "$ip" ]]; then
        ip="$NETUTILS_DEFAULT_TEST_IP"
    fi

    if command -v ping >/dev/null 2>&1; then
        if ! ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
            return 1
        fi
    fi

    if command -v getent >/dev/null 2>&1; then
        if ! getent ahosts "$host" >/dev/null 2>&1; then
            return 1
        fi
    fi

    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsS --max-time 4 "https://${host}/" >/dev/null 2>&1; then
            return 1
        fi
    fi
}
