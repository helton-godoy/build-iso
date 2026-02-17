#!/usr/bin/env bash
# @INST_LIB_NAME: net-utils
# @INST_DESC: Configuração de interfaces de rede (DHCP/Estático) no sistema alvo.

set -euo pipefail

# Adapters
netutils_configure_dhcp() {
	local target="$1"

	# Criar arquivo de interfaces para DHCP padrão
	cat >"${target}/etc/network/interfaces" <<'EOF'
# This file describes the network interfaces available on your system
# and how to activate them.

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug ens4
iface ens4 inet dhcp
EOF
}

netutils_configure_static() {
	local target="$1"
	local interface="$2"
	local ip="$3"
	local mask="$4" # CIDR or Mask
	local gw="$5"
	local dns="$6"

	# Se mask for CIDR (ex: 24), ok. Se for IP, precisa converter?
	# O arquivo interfaces suporta "netmask 255.255.255.0"? Sim.
	# Suporta CIDR no address? "address 192.168.1.10/24"? Sim.
	# Mas vamos assumir input do usuário. steps/network.sh usa ui_input "Máscara/CIDR:".

	cat >"${target}/etc/network/interfaces" <<EOF
# This file describes the network interfaces available on your system
# and how to activate them.

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $interface
allow-hotplug $interface
iface $interface inet static
    address $ip
    netmask $mask
    gateway $gw
EOF

	if [[ -n "$dns" ]]; then
		# Check if resolvconf or systemd-resolved?
		# Standard Debian uses /etc/resolv.conf symlink or generated.
		# interfaces dns-* options require resolvconf package.
		echo "    dns-nameservers $dns" >>"${target}/etc/network/interfaces"
	fi
}
