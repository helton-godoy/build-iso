#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-uefi}"
VM_NAME="nas-test-${MODE}"
SOCKET_PATH="/tmp/${VM_NAME}.sock"
SSH_USER="${SSH_USER:-root}"
SSH_PASSWORD="${VM_SSH_PASSWORD:-x}"
AUTO_BOOTSTRAP_SSH="${AUTO_BOOTSTRAP_SSH:-true}"

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

	network="$(virsh domiflist "$VM_NAME" 2>/dev/null | awk '$2=="network" && $3!="--" {print $3; exit}')"
	if [[ -z "$network" ]]; then
		return 1
	fi

	leases="$(virsh net-dhcp-leases "$network" 2>/dev/null || true)"
	vm_mac="$(virsh domiflist "$VM_NAME" 2>/dev/null | awk '$2=="network" && $5!="" {print tolower($5); exit}')"

	if [[ -z "$leases" || -z "$vm_mac" ]]; then
		return 1
	fi

	ip="$(printf '%s\n' "$leases" | awk -v mac="$vm_mac" 'tolower($2)==mac {sub(/\/.*/, "", $5); print $5; exit}')"
	[[ -n "$ip" ]] || return 1
	printf '%s\n' "$ip"
}

serial_send() {
	local cmd="$1"
	[[ -S "$SOCKET_PATH" ]] || return 1
	printf '\025%s\n' "$cmd" | nc -U -w 3 "$SOCKET_PATH" >/dev/null 2>&1 || return 1
}

bootstrap_vm_ssh() {
	local vm_ip="${VM_IP:-}"
	local pubkey=""

	ensure_local_ssh_key
	pubkey="$(<"$HOME/.ssh/id_ed25519.pub")"

	if [[ -z "$vm_ip" ]]; then
		vm_ip="$(detect_vm_ip || true)"
		if [[ -n "$vm_ip" ]]; then
			VM_IP="$vm_ip"
			export VM_IP
		fi
	fi

	if [[ -n "$vm_ip" ]] && ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=3 "${SSH_USER}@${vm_ip}" "exit" >/dev/null 2>&1; then
		return 0
	fi

	if [[ ! -S "$SOCKET_PATH" ]]; then
		return 0
	fi

	serial_send "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
	serial_send "grep -qxF '$pubkey' /root/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' '$pubkey' >> /root/.ssh/authorized_keys"
	serial_send "chmod 600 /root/.ssh/authorized_keys"
	serial_send "echo 'root:${SSH_PASSWORD}' | chpasswd"
	serial_send "grep -q '^PermitRootLogin' /etc/ssh/sshd_config && sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config"
	serial_send "grep -q '^PasswordAuthentication' /etc/ssh/sshd_config && sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config"
	serial_send "systemctl restart ssh || service ssh restart || true"

	if [[ -z "${VM_IP:-}" ]]; then
		VM_IP="$(detect_vm_ip || true)"
		export VM_IP
	fi

	if command -v sshpass >/dev/null 2>&1 && [[ -n "${VM_IP:-}" ]]; then
		sshpass -p "$SSH_PASSWORD" ssh-copy-id -f -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${SSH_USER}@${VM_IP}" >/dev/null 2>&1 || true
	fi
}

runner=()
if [[ -z "${VM_IP:-}" ]] && sudo -n true >/dev/null 2>&1; then
	runner=(sudo -n)
fi

if [[ "$AUTO_BOOTSTRAP_SSH" == "true" ]]; then
	bootstrap_vm_ssh || true
fi

if [[ -n "${VM_CMD:-}" ]]; then
	if ((${#runner[@]} > 0)); then
		env VM_IP="${VM_IP:-}" USE_SSH=true \
			sudo -n --preserve-env=VM_IP,USE_SSH "$SCRIPT_DIR/vm-connent-ssh.sh" "$MODE" "$VM_CMD"
	else
		env VM_IP="${VM_IP:-}" USE_SSH=true "$SCRIPT_DIR/vm-connent-ssh.sh" "$MODE" "$VM_CMD"
	fi
else
	if ((${#runner[@]} > 0)); then
		env VM_IP="${VM_IP:-}" sudo -n --preserve-env=VM_IP "$SCRIPT_DIR/vm-connent-ssh.sh" "$MODE"
	else
		env VM_IP="${VM_IP:-}" "$SCRIPT_DIR/vm-connent-ssh.sh" "$MODE"
	fi
fi
