#!/usr/bin/env bash
step_network() {
    ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
    ui_section "Rede"
    local method
    if ! method="$(ui_select "Método de configuração:" "dhcp" "manual")"; then
        return 1
    fi
    method="$(sanitize_id "$method")"
    if [[ -z "$method" ]]; then
        method="dhcp"
    fi
    state_kv_set "install_net_method" "$method" || return 1

    if [[ "$method" == "manual" ]]; then
        local ip mask gw dns
        if ! ip="$(ui_input "Endereço IP:" "192.168.1.10")"; then
            return 1
        fi
        if ! mask="$(ui_input "Máscara/CIDR:" "24")"; then
            return 1
        fi
        if ! gw="$(ui_input "Gateway:" "192.168.1.1")"; then
            return 1
        fi
        dns="$(ui_input "DNS (separado por espaço):" "1.1.1.1 8.8.8.8" || true)"

        ip="$(sanitize_ws "$ip")"
        mask="$(sanitize_ws "$mask")"
        gw="$(sanitize_ws "$gw")"
        dns="$(sanitize_ws "$dns")"

        state_kv_set "install_net_ip" "$ip" || return 1
        state_kv_set "install_net_mask" "$mask" || return 1
        state_kv_set "install_net_gw" "$gw" || return 1
        state_kv_set "install_net_dns" "$dns" || return 1
    fi

    local proxy
    proxy="$(ui_input "Proxy (opcional):" "http://user:pass@proxy:3128" || true)"
    proxy="$(sanitize_ws "$proxy")"
    state_kv_set "install_proxy" "$proxy" || return 1
}
