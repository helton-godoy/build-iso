#!/usr/bin/env bash
set -euo pipefail

# Configurações
MODE=${1:-uefi}
VM_NAME="nas-test-$MODE"
SOCKET_PATH="/tmp/${VM_NAME}.sock"
TIMEOUT=5

# 1. Verifica se o socket existe (se a VM foi iniciada com o script anterior)
if [ ! -S "$SOCKET_PATH" ]; then
	echo "❌ Socket não encontrado em $SOCKET_PATH"
	echo "Certifique-se de que a VM '$VM_NAME' está rodando."
	exit 1
fi

# 2. Modo de operação
# Se houver um segundo argumento, envia como comando.
# Se não, apenas escuta o que está acontecendo na serial.
COMMAND=${2:-""}

if [ -n "$COMMAND" ]; then
	echo "🤖 Enviando comando para $VM_NAME: $COMMAND"
	# Envia o comando e fecha a conexão após 1 segundo para ler a resposta
	echo "$COMMAND" | nc -U -w "$TIMEOUT" "$SOCKET_PATH"
else
	echo "🎧 Escutando console serial de $VM_NAME (Ctrl+C para sair)..."
	nc -U "$SOCKET_PATH"
fi

show_help() {
	echo "Usage: $0 [mode] [command]"
	echo ""
	echo "Modes: uefi, bios"
	echo "Command: Optional. If provided, sends to VM and exits. If empty, opens interactive listen mode."
	echo ""
	echo "Example for Agents: ./connect-agent.sh uefi 'lsblk --json'"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	show_help
	exit 0
fi
