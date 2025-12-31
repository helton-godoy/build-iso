#!/bin/bash
set -e

echo "[LIVE CONFIG] Iniciando configuração de rede com systemd-networkd..."

# Detecta a primeira interface Ethernet disponível
INTERFACE=$(ip -o link show | awk -F': ' '/en/{print $2; exit}')
# Fallback se não achar 'en*'
if [[ -z ${INTERFACE} ]]; then
	INTERFACE=$(ip -o link show | awk -F': ' '/eth/{print $2; exit}')
fi

# Define variáveis padrão (podem ser sobrescritas)
USE_DHCP="${USE_DHCP:-yes}" # yes ou no
STATIC_IP="${STATIC_IP:-10.24.8.99/24}"
GATEWAY="${GATEWAY:-10.24.8.1}"
DNS1="${DNS1:-10.24.16.201}"
DNS2="${DNS2:-10.24.16.200}"

# Cria diretório de configuração
mkdir -p /etc/systemd/network

# Gera arquivo de configuração da interface
if [[ -n ${INTERFACE} ]]; then
	if [[ ${USE_DHCP} == "yes" ]]; then
		cat <<EOF >/etc/systemd/network/20-"${INTERFACE}".network
[Match]
Name=${INTERFACE}

[Network]
DHCP=yes
EOF
	else
		cat <<EOF >/etc/systemd/network/20-"${INTERFACE}".network
[Match]
Name=${INTERFACE}

[Network]
Address=${STATIC_IP}
Gateway=${GATEWAY}
DNS=${DNS1}
DNS=${DNS2}
EOF
	fi

	# Ativa serviços de rede e DNS
	systemctl enable systemd-networkd
	systemctl enable systemd-resolved

	# Garante que o resolv.conf aponte para o resolved
	ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
	echo "[LIVE CONFIG] Rede configurada para interface ${INTERFACE} com ${USE_DHCP^^}."
else
	echo "[LIVE CONFIG] Nenhuma interface Ethernet encontrada."
fi
