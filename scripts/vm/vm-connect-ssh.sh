#!/usr/bin/env bash
# =============================================================================
# @DEV_SCRIPT: vm-connect-ssh - Conexão SSH com detecção automática de IP
# @DEV_CATEGORY: vm
# @DEV_DEP: ssh, virsh, nc
# @DEV_INPUT: $1=mode (uefi|bios), $2=command (opcional), USE_SSH, VM_IP
# @DEV_OUTPUT: Sessão SSH interativa ou saída de comando
# =============================================================================
# Script de Conexão SSH Automatizada para VMs de Teste
# Suporta: detecção de rede, obtenção de IP, cópia de chave SSH e fallback serial
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Configurações
# -----------------------------------------------------------------------------
MODE="${1:-uefi}"
VM_NAME="nas-test-${MODE}"
SOCKET_PATH="/tmp/${VM_NAME}.sock"
TIMEOUT="${VM_SERIAL_TIMEOUT:-3}"
DHCP_TIMEOUT="${VM_DHCP_TIMEOUT:-12}"
IP_DETECT_ATTEMPTS="${VM_IP_DETECT_ATTEMPTS:-6}"
IP_DETECT_INTERVAL="${VM_IP_DETECT_INTERVAL:-1}"
SSH_USER="${SSH_USER:-root}"

is_vm_running() {
	local vm_name="$1"
	virsh list --state-running --name 2>/dev/null | grep -Fxq "$vm_name"
}

# -----------------------------------------------------------------------------
# Funções de Detecção de Rede e IP
# -----------------------------------------------------------------------------

# Detecta o nome da rede associada à VM
# Argumentos: $1 - nome da VM
# Retorna: string com nome da rede ou erro
detect_vm_network() {
	local vm_name="$1"
	local network=""

	# Obtém lista de interfaces da VM
	local interfaces
	interfaces=$(virsh domiflist "$vm_name" 2>/dev/null) || {
		echo "❌ Erro: Não foi possível listar interfaces da VM '$vm_name'" >&2
		return 1
	}

	# Parse robusto independente de locale.
	# Linha válida esperada: <iface> network <nome-da-rede> <modelo> <mac>
	network="$(printf '%s\n' "$interfaces" | awk '$2=="network" && $3!="--" {print $3; exit}')"

	if [[ -z "$network" ]]; then
		echo "❌ Erro: Nenhuma rede encontrada para VM '$vm_name'" >&2
		return 1
	fi

	echo "$network"
}

# Obtém o IP da VM a partir do lease DHCP
# Argumentos: $1 - nome da VM, $2 - nome da rede
# Retorna: IP sem máscara ou erro
get_vm_ip() {
	local vm_name="$1"
	local network="$2"
	local ip=""
	local attempts=1

	while [[ $attempts -le $IP_DETECT_ATTEMPTS ]]; do
		ip="$(virsh domifaddr "$vm_name" 2>/dev/null | awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}')"
		if [[ -n "$ip" ]]; then
			echo "$ip"
			return 0
		fi

		attempts=$((attempts + 1))
		sleep "$IP_DETECT_INTERVAL"
	done

	# Aguarda lease DHCP com timeout
	local elapsed=0
	while [[ $elapsed -lt $DHCP_TIMEOUT ]]; do
		# Obtém leases DHCP da rede
		local leases
		leases=$(virsh net-dhcp-leases "$network" 2>/dev/null) || {
			echo "⚠️  Erro ao obter leases DHCP da rede '$network'" >&2
			sleep 2
			elapsed=$((elapsed + 2))
			continue
		}

		# Encontra IP correspondente ao MAC da VM
		local vm_mac
		vm_mac=$(virsh domiflist "$vm_name" 2>/dev/null | awk '$2=="network" && $5!="" {print tolower($5); exit}')

		if [[ -z "$vm_mac" ]]; then
			echo "⚠️  Erro: Não foi possível obter MAC da VM '$vm_name'" >&2
			sleep 2
			elapsed=$((elapsed + 2))
			continue
		fi

		ip="$(printf '%s\n' "$leases" | awk -v mac="$vm_mac" 'tolower($2)==mac {sub(/\/.*/, "", $5); print $5; exit}')"
		if [[ -n "$ip" ]]; then
			echo "$ip"
			return 0
		fi

		sleep "$IP_DETECT_INTERVAL"
		elapsed=$((elapsed + IP_DETECT_INTERVAL))
	done

	if [[ -z "$ip" ]]; then
		echo "❌ Erro: IP não encontrado para VM '$vm_name' (timeout: ${DHCP_TIMEOUT}s)" >&2
		return 1
	fi
}

# -----------------------------------------------------------------------------
# Funções SSH
# -----------------------------------------------------------------------------

# Verifica se SSH está disponível no destino
# Argumentos: $1 - IP, $2 - usuário
# Retorna: 0 se disponível, 1 caso contrário
check_ssh_available() {
	local ip="$1"
	local user="${2:-$SSH_USER}"

	# Tenta conexão SSH rápida para verificar disponibilidade
	timeout 5 ssh -o "BatchMode=yes" \
		-o "StrictHostKeyChecking=no" \
		-o "ConnectTimeout=3" \
		"${user}@${ip}" "exit" 2>/dev/null
}

# Copia chave SSH para a VM
# Argumentos: $1 - IP, $2 - usuário
# Retorna: 0 se sucesso, 1 caso contrário
copy_ssh_key() {
	local ip="$1"
	local user="${2:-$SSH_USER}"

	echo "🔐 Copiando chave SSH para ${user}@${ip}..."

	# Verifica se já existe chave pública
	if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
		if [[ ! -f ~/.ssh/id_rsa ]]; then
			echo "📝 Gerando nova chave SSH..."
			ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa -q
		else
			echo "📝 Usando chave existente..."
			ssh-keygen -y -f ~/.ssh/id_rsa >~/.ssh/id_rsa.pub 2>/dev/null || true
		fi
	fi

	# Copia a chave
	ssh-copy-id -o "StrictHostKeyChecking=no" \
		-o "BatchMode=yes" \
		"${user}@${ip}" 2>&1 || {
		echo "❌ Erro ao copiar chave SSH" >&2
		return 1
	}

	echo "✅ Chave SSH copiada com sucesso!"
	return 0
}

# Conecta via SSH à VM
# Argumentos: $1 - IP, $2 - usuário
# Retorna: executa conexão SSH interativa
ssh_connect() {
	local ip="$1"
	local user="${2:-$SSH_USER}"

	echo "🔌 Conectando via SSH: ${user}@${ip}"
	ssh -o "StrictHostKeyChecking=no" \
		-o "ServerAliveInterval=60" \
		"${user}@${ip}"
}

# -----------------------------------------------------------------------------
# Funções de Fallback Serial
# -----------------------------------------------------------------------------

# Verifica se socket serial existe
check_socket() {
	[[ -S "$SOCKET_PATH" ]]
}

# Conecta via socket serial (fallback)
connect_serial() {
	local command="${1:-}"

	if [[ -n "$command" ]]; then
		echo "📡 Enviando comando via serial: $command"
		# Ctrl+U limpa a linha corrente no shell remoto e evita comandos corrompidos.
		printf '\025%s\n' "$command" | nc -U -w "$TIMEOUT" "$SOCKET_PATH"
	else
		echo "📡 Conectando ao console serial (Ctrl+C para sair)..."
		nc -U "$SOCKET_PATH"
	fi
}

# -----------------------------------------------------------------------------
# Fluxo Principal com SSH
# -----------------------------------------------------------------------------

# Fluxo principal que tenta SSH primeiro, fallback para serial
main_with_ssh() {
	local use_ssh="${USE_SSH:-false}"

	# Se modo SSH explícito ou argumentos fornecidos
	if [[ "$use_ssh" == "true" || -n "${1:-}" ]]; then
		execute_ssh_flow "$@"
	else
		# Modo padrão: tenta socket primeiro
		execute_default_flow "$@"
	fi
}

# Executa fluxo SSH
execute_ssh_flow() {
	local command="${1:-}"
	local ip="${VM_IP:-}"

	if [[ -n "$ip" ]]; then
		echo "🌐 Usando VM_IP informado: $ip"
	else
		# 1. Verifica se VM está rodando
		echo "🔍 Verificando VM '$VM_NAME'..."
		if ! is_vm_running "$VM_NAME"; then
			echo "❌ VM '$VM_NAME' não está rodando"
			echo "   Inicie a VM primeiro com: ./vm-start-test-${MODE}.sh"
			exit 1
		fi

		# 2. Detecta rede
		echo "🌐 Detectando rede da VM..."
		local network
		network=$(detect_vm_network "$VM_NAME") || exit 1
		echo "   Rede: $network"

		# 3. Obtém IP
		echo "📡 Obtendo IP da VM..."
		ip=$(get_vm_ip "$VM_NAME" "$network") || {
			echo "⚠️  IP não obtido, usando fallback serial..."
			connect_serial "$command"
			return
		}
		echo "   IP: $ip"
	fi

	# 4. Verifica disponibilidade SSH
	if ! check_ssh_available "$ip"; then
		echo "⚠️  SSH não disponível em ${ip}"
		echo "   O serviço SSH pode não estar rodando na VM"

		# Oferece copiar chave ou usar serial
		if [[ -t 0 ]]; then
			echo -n "   Deseja tentar copiar chave SSH? [s/N]: "
			read -r resposta
			if [[ "$resposta" =~ ^[Ss]$ ]]; then
				copy_ssh_key "$ip" || {
					echo "❌ Falha ao copiar chave SSH"
					connect_serial "$command"
					return
				}

				# Tenta conectar novamente
				if ! check_ssh_available "$ip"; then
					echo "❌ SSH ainda não disponível após cópia de chave"
					connect_serial "$command"
					return
				fi
			else
				connect_serial "$command"
				return
			fi
		else
			connect_serial "$command"
			return
		fi
	fi

	# 5. Copia chave se necessário
	if [[ -n "${FORCE_SSH_KEY:-}" ]] || ! ssh -o "BatchMode=yes" "${SSH_USER}@${ip}" "exit" 2>/dev/null; then
		copy_ssh_key "$ip" || echo "⚠️  Falha ao copiar chave (pode já estar instalada)"
	fi

	# 6. Conecta ou executa comando
	if [[ -n "$command" ]]; then
		echo "🤖 Executando comando em ${SSH_USER}@${ip}: $command"
		ssh -o "StrictHostKeyChecking=no" "${SSH_USER}@${ip}" "$command"
	else
		ssh_connect "$ip"
	fi
}

# Fluxo padrão (socket primeiro)
execute_default_flow() {
	local command="${1:-}"

	if [[ -n "${VM_IP:-}" ]]; then
		execute_ssh_flow "$command"
		return
	fi

	# Tenta socket primeiro
	if check_socket; then
		connect_serial "$command"
		return
	fi

	# Socket não existe, tenta SSH como fallback
	echo "⚠️  Socket não encontrado em $SOCKET_PATH"
	echo "   Tentando conexão SSH..."

	# Verifica se VM está rodando
	if ! is_vm_running "$VM_NAME"; then
		echo "❌ VM '$VM_NAME' não está rodando"
		echo "   Inicie a VM primeiro com: ./vm-start-test-${MODE}.sh"
		exit 1
	fi

	# Tenta obter IP e conectar via SSH
	local network
	network=$(detect_vm_network "$VM_NAME") || {
		echo "❌ Não foi possível detectar rede"
		exit 1
	}

	local ip
	ip=$(get_vm_ip "$VM_NAME" "$network") || {
		echo "❌ Não foi possível obter IP da VM"
		exit 1
	}

	# Verifica/copia chave e conecta
	if ! check_ssh_available "$ip"; then
		copy_ssh_key "$ip" || echo "⚠️  Não foi possível copiar chave SSH"
	fi

	if [[ -n "$command" ]]; then
		ssh -o "StrictHostKeyChecking=no" "${SSH_USER}@${ip}" "$command"
	else
		ssh_connect "$ip"
	fi
}

# -----------------------------------------------------------------------------
# Funções de Help e Interfaces
# -----------------------------------------------------------------------------

show_help() {
	cat <<EOF
Uso: $0 [mode] [command]

Conecta a VMs de teste via SSH ou console serial.

Argumentos:
  mode      Modo de boot: uefi (padrão) ou bios
  command   Opcional. Se fornecido, envia comando e sai.
            Se vazio, abre console interativo.

Variáveis de ambiente:
  USE_SSH=true      Força uso de SSH em vez de socket
  FORCE_SSH_KEY=true    Força recópia de chave SSH
  SSH_USER=root     Usuário para conexão SSH (padrão: root)

Exemplos:
  # Conectar interativamente via socket (padrão)
  $0 uefi

  # Executar comando via SSH
  $0 uefi 'lsblk'

  # Forçar modo SSH
  USE_SSH=true $0 bios 'zpool status'

  # Copiar chave SSH e conectar
  FORCE_SSH_KEY=true $0 uefi

Scripts relacionados:
  vm-start-test-uefi.sh  - Inicia VM em modo UEFI
  vm-start-test-bios.sh  - Inicia VM em modo BIOS
  vm-connect-socket.sh   - Conexão serial pura
EOF
}

# -----------------------------------------------------------------------------
# Entry Point
# -----------------------------------------------------------------------------

# Parseia argumentos
case "${1:-}" in
--help | -h)
	show_help
	exit 0
	;;
uefi | bios)
	MODE="$1"
	VM_NAME="nas-test-${MODE}"
	SOCKET_PATH="/tmp/${VM_NAME}.sock"
	shift
	;;
esac

# Executa fluxo principal
main_with_ssh "$@"
