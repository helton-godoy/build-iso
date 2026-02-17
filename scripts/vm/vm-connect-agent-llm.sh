#!/usr/bin/env bash
# =============================================================================
# @DEV_SCRIPT: vm-connect-agent-llm - Bootstrap SSH e conexão para agentes LLM
# @DEV_CATEGORY: vm
# @DEV_DEP: ssh, nc, virsh, sshpass (opcional)
# @DEV_INPUT: $1=mode (uefi|bios), VM_CMD, VM_IP, SSH_USER, SSH_PASSWORD, VM_LIVE_BOOT_WAIT
# @DEV_OUTPUT: Execução remota via SSH ou ajuda com IP para acesso interativo
# @DEV_MAKEFILE: vm-connect-uefi, vm-connect-bios
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-uefi}"
VM_NAME="nas-test-${MODE}"
SOCKET_PATH="/tmp/${VM_NAME}.sock"
SSH_USER="${SSH_USER:-root}"
SSH_PASSWORD="${VM_SSH_PASSWORD:-x}"
AUTO_BOOTSTRAP_SSH="${AUTO_BOOTSTRAP_SSH:-true}"
VM_LIVE_BOOT_WAIT="${VM_LIVE_BOOT_WAIT:-30}"
VM_STATE_DIR="${VM_STATE_DIR:-$SCRIPT_DIR/.cache}"
VM_STATE_FILE="${VM_STATE_FILE:-$VM_STATE_DIR/vm-ips.env}"
VM_IP_KEY="VM_IP_${MODE^^}"
VM_IP_DETECT_ATTEMPTS="${VM_IP_DETECT_ATTEMPTS:-6}"
VM_IP_DETECT_INTERVAL="${VM_IP_DETECT_INTERVAL:-1}"

usage() {
	cat <<EOF
Uso:
  $0 [uefi|bios]

Finalidade:
  - Otimizar o primeiro acesso SSH da VM de teste.
  - Descobrir/persistir o IP por firmware.
  - Executar comandos remotos de forma nao interativa para analise automatizada.

Parametro obrigatorio:
  VM_CMD="<comando>"  Comando executado dentro da VM via SSH.

Variaveis opcionais:
  VM_IP=<ip>                 Define IP explicito da VM.
  VM_LIVE_BOOT_WAIT=<seg>    Espera inicial para boot live ISO (padrao: ${VM_LIVE_BOOT_WAIT}).
  AUTO_BOOTSTRAP_SSH=<bool>  Habilita bootstrap SSH automatico (padrao: ${AUTO_BOOTSTRAP_SSH}).

Exemplos:
  VM_CMD="uname -a" bash scripts/vm/vm-connect-agent-llm.sh uefi
  VM_CMD="zpool status" bash scripts/vm/vm-connect-agent-llm.sh bios
EOF
}

ensure_state_file() {
	mkdir -p "$VM_STATE_DIR"
	touch "$VM_STATE_FILE"
}

load_cached_vm_ip() {
	local cached_ip=""

	ensure_state_file
	# shellcheck disable=SC1090
	source "$VM_STATE_FILE" || true
	cached_ip="${!VM_IP_KEY:-}"

	if [[ -z "${VM_IP:-}" && -n "$cached_ip" ]]; then
		VM_IP="$cached_ip"
		export VM_IP
	fi
}

persist_vm_ip() {
	local ip="$1"

	[[ -n "$ip" ]] || return 0
	ensure_state_file

	if grep -q "^${VM_IP_KEY}=" "$VM_STATE_FILE"; then
		sed -i "s|^${VM_IP_KEY}=.*|${VM_IP_KEY}=${ip}|" "$VM_STATE_FILE"
	else
		printf '%s=%s\n' "$VM_IP_KEY" "$ip" >>"$VM_STATE_FILE"
	fi
}

# @DEV_FUNC: ensure_local_ssh_key - Gera chave SSH local se não existir
ensure_local_ssh_key() {
	if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
		mkdir -p "$HOME/.ssh"
		chmod 700 "$HOME/.ssh"
		ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" -q
	fi

	if [[ ! -f "$HOME/.ssh/id_ed25519.pub" ]]; then
		ssh-keygen -y -f "$HOME/.ssh/id_ed25519" >"$HOME/.ssh/id_ed25519.pub"
	fi
}

detect_vm_ip() {
	local network=""
	local leases=""
	local vm_mac=""
	local ip=""
	local max_attempts="${VM_IP_DETECT_ATTEMPTS}"
	local sleep_seconds="${VM_IP_DETECT_INTERVAL}"
	local attempt=1

	ip="$(virsh domifaddr "$VM_NAME" 2>/dev/null | awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}')"
	if [[ -n "$ip" ]]; then
		printf '%s\n' "$ip"
		return 0
	fi

	while ((attempt <= max_attempts)); do
		ip="$(virsh domifaddr "$VM_NAME" 2>/dev/null | awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}')"
		if [[ -n "$ip" ]]; then
			printf '%s\n' "$ip"
			return 0
		fi

		network="$(virsh domiflist "$VM_NAME" 2>/dev/null | awk '$2=="network" && $3!="--" {print $3; exit}')"
		if [[ -z "$network" ]]; then
			attempt=$((attempt + 1))
			sleep "$sleep_seconds"
			continue
		fi

		leases="$(virsh net-dhcp-leases "$network" 2>/dev/null || true)"
		vm_mac="$(virsh domiflist "$VM_NAME" 2>/dev/null | awk '$2=="network" && $5!="" {print tolower($5); exit}')"

		if [[ -n "$leases" && -n "$vm_mac" ]]; then
			ip="$(printf '%s\n' "$leases" | awk -v mac="$vm_mac" 'tolower($2)==mac {sub(/\/.*/, "", $5); print $5; exit}')"
			if [[ -n "$ip" ]]; then
				printf '%s\n' "$ip"
				return 0
			fi
		fi

		attempt=$((attempt + 1))
		sleep "$sleep_seconds"
	done

	return 1
}

copy_key_via_ssh() {
	local vm_ip="$1"

	if ! command -v sshpass >/dev/null 2>&1; then
		return 1
	fi

	sshpass -p "$SSH_PASSWORD" ssh-copy-id -f -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
		"${SSH_USER}@${vm_ip}" >/dev/null 2>&1 || return 1

	check_ssh_ready "$vm_ip"
}

execute_remote_cmd_ssh() {
	local vm_ip="$1"
	local cmd="$2"

	ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
		"${SSH_USER}@${vm_ip}" "$cmd"
}

execute_remote_cmd_serial() {
	local cmd="$1"

	[[ -S "$SOCKET_PATH" ]] || return 1
	serial_send "$cmd"
}

serial_send() {
	local cmd="$1"
	[[ -S "$SOCKET_PATH" ]] || return 1
	printf '\025%s\n' "$cmd" | nc -U -w 3 "$SOCKET_PATH" >/dev/null 2>&1 || return 1
}

check_ssh_ready() {
	local ip="$1"
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
		"${SSH_USER}@${ip}" "exit" >/dev/null 2>&1
}

wait_for_live_boot() {
	local wait_seconds="$1"

	[[ "$wait_seconds" =~ ^[0-9]+$ ]] || return 0
	[[ -S "$SOCKET_PATH" ]] || return 0

	# @ID: VM-CONNECT-LIVE-BOOT-WAIT
	# @STEP: Aguardar boot inicial da ISO para evitar corrida no GRUB/sshd
	# @REQ: VM-CONNECT-SSH-BOOTSTRAP
	# @DATA: VM_LIVE_BOOT_WAIT segundos configuráveis por ambiente
	if ((wait_seconds > 0)); then
		sleep "$wait_seconds"
	fi
}

print_cmd_required_help() {
	local mode_target="vm-connect-${MODE}"
	local vm_ip_display="${VM_IP:-indisponivel}"
	local live_hostname_hint="debian-trixie-zbm-<tipo>-${MODE}"

	echo "CMD obrigatorio para analise automatizada via SSH."
	echo ""
	usage
	echo ""
	echo "Informacoes atuais da VM:"
	echo "  Modo: ${MODE}"
	echo "  VM: ${VM_NAME}"
	echo "  IP detectado: ${vm_ip_display}"
	echo "  Hostname live esperado: ${live_hostname_hint}"
	echo "  Estado IP cache: ${VM_STATE_FILE} (${VM_IP_KEY})"
	echo ""
	echo "Exemplo (Makefile):"
	echo "  make ${mode_target} CMD=\"hostname && uname -a\""
	echo ""
	echo "Acesso interativo manual (quando necessario):"
	echo "  VM_IP=${vm_ip_display} scripts/vm/vm-connect-ssh.sh ${MODE}"
}

bootstrap_vm_ssh() {
	local vm_ip="${VM_IP:-}"
	local pubkey=""

	# @ID: VM-CONNECT-SSH-BOOTSTRAP
	# @STEP: Preparar acesso SSH sem senha e persistir IP da VM por firmware
	# @REQ: VM-CONNECT-LIVE-BOOT-WAIT
	# @DATA: VM_IP_UEFI/VM_IP_BIOS em arquivo de estado local
	ensure_local_ssh_key
	load_cached_vm_ip
	pubkey="$(<"$HOME/.ssh/id_ed25519.pub")"

	if [[ -z "$vm_ip" && -n "${VM_IP:-}" ]]; then
		vm_ip="$VM_IP"
	fi

	if [[ -z "$vm_ip" ]]; then
		vm_ip="$(detect_vm_ip || true)"
		if [[ -n "$vm_ip" ]]; then
			VM_IP="$vm_ip"
			export VM_IP
			persist_vm_ip "$vm_ip"
		fi
	fi

	if [[ -n "$vm_ip" ]] && check_ssh_ready "$vm_ip"; then
		persist_vm_ip "$vm_ip"
		return 0
	fi

	if [[ -n "$vm_ip" ]] && copy_key_via_ssh "$vm_ip"; then
		VM_IP="$vm_ip"
		export VM_IP
		persist_vm_ip "$vm_ip"
		return 0
	fi

	if [[ ! -S "$SOCKET_PATH" ]]; then
		return 0
	fi

	wait_for_live_boot "$VM_LIVE_BOOT_WAIT"

	serial_send "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
	serial_send "grep -qxF '$pubkey' /root/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' '$pubkey' >> /root/.ssh/authorized_keys"
	serial_send "chmod 600 /root/.ssh/authorized_keys"
	serial_send "grep -q '^PermitRootLogin' /etc/ssh/sshd_config && sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config"
	serial_send "grep -q '^PasswordAuthentication' /etc/ssh/sshd_config && sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config"
	serial_send "systemctl restart ssh || service ssh restart || true"

	if [[ -z "${VM_IP:-}" ]]; then
		VM_IP="$(detect_vm_ip || true)"
		export VM_IP
	fi

	if [[ -n "${VM_IP:-}" ]]; then
		persist_vm_ip "$VM_IP"
	fi

	if [[ -n "${VM_IP:-}" ]]; then
		copy_key_via_ssh "$VM_IP" || true
	fi
}

case "$MODE" in
uefi | bios) ;;
*)
	usage
	exit 2
	;;
esac

load_cached_vm_ip

if [[ "$AUTO_BOOTSTRAP_SSH" == "true" ]]; then
	bootstrap_vm_ssh || true
fi

if [[ -z "${VM_CMD:-}" ]]; then
	if [[ -z "${VM_IP:-}" ]]; then
		VM_IP="$(detect_vm_ip || true)"
	fi
	if [[ -n "${VM_IP:-}" ]]; then
		persist_vm_ip "$VM_IP"
	fi
	print_cmd_required_help
	exit 2
fi

if [[ -n "${VM_IP:-}" ]]; then
	persist_vm_ip "$VM_IP"
fi

if [[ -n "${VM_IP:-}" ]] && check_ssh_ready "$VM_IP"; then
	execute_remote_cmd_ssh "$VM_IP" "$VM_CMD"
	exit 0
fi

if [[ -n "${VM_IP:-}" ]] && copy_key_via_ssh "$VM_IP"; then
	execute_remote_cmd_ssh "$VM_IP" "$VM_CMD"
	exit 0
fi

if execute_remote_cmd_serial "$VM_CMD"; then
	exit 0
fi

env VM_IP="${VM_IP:-}" USE_SSH=true "$SCRIPT_DIR/vm-connect-ssh.sh" "$MODE" "$VM_CMD"
