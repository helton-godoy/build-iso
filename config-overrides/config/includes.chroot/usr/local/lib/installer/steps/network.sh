#!/usr/bin/env bash
# @INST_STEP_ID: network
# @INST_STEP_FLOW: prev=identity, next=time
# @INST_STATE: install_net_method, install_net_ip, install_net_mask, install_net_gw, install_net_dns, install_proxy
step_network() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Rede"
	local method
	method="$(ui_select "Método de configuração:" "dhcp" "manual")"
	method="$(sanitize_id "$method")"
	if [[ -z "$method" ]]; then
		method="dhcp"
	fi
	state_kv_set "install_net_method" "$method" || return 1

	if [[ "$method" == "manual" ]]; then
		local ip mask gw dns
		ip="$(ui_input "Endereço IP:" "192.168.1.10")"
		mask="$(ui_input "Máscara/CIDR:" "24")"
		gw="$(ui_input "Gateway:" "192.168.1.1")"
		dns="$(ui_input "DNS (separado por espaço):" "1.1.1.1 8.8.8.8")"

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
	proxy="$(ui_input "Proxy (opcional):" "http://user:pass@proxy:3128")"
	proxy="$(sanitize_ws "$proxy")"
	state_kv_set "install_proxy" "$proxy" || return 1
}
