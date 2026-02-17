#!/usr/bin/env bash
# =============================================================================
# @DEV_SCRIPT: vm-start-test-all - Executa testes UEFI + BIOS em paralelo
# @DEV_CATEGORY: vm
# @DEV_DEP: vm-start-test-boot-iso.sh, vm-connect-agent-llm.sh
# @DEV_INPUT: output/*.iso
# @DEV_OUTPUT: logs/test-*/boot-{uefi,bios}.log
# @DEV_MAKEFILE: test-vm-all
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="logs/test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

echo "🧪 Iniciando Bateria de Testes Simultâneos (BIOS & UEFI)..."
echo "📂 Logs desta sessão: $LOG_DIR"

# @DEV_FUNC: run_test - Inicia VM e captura log de boot inicial
run_test() {
	local MODE=$1
	local started ended elapsed
	started=$(date +%s)
	echo "⚙️  Preparando instância $MODE..."

	# Inicia a VM (o script já faz a limpeza interna)
	"$SCRIPT_DIR/vm-start-test-boot-iso.sh" "$MODE" >"$LOG_DIR/start-$MODE.log" 2>&1

	# Captura os primeiros 30 segundos de boot via socket para o Agente
	echo "📡 Capturando log de boot inicial ($MODE)..."
	timeout 30s "$SCRIPT_DIR/vm-connect-agent-llm.sh" "$MODE" >"$LOG_DIR/boot-$MODE.log" 2>&1 || true
	ended=$(date +%s)
	elapsed=$((ended - started))
	printf '{"mode":"%s","boot_capture_seconds":%s}\n' "$MODE" "$elapsed" >"$LOG_DIR/metrics-$MODE.json"

	echo "✅ Instância $MODE pronta."
}

# Dispara as duas VMs em paralelo
run_test "uefi" &
run_test "bios" &

# Aguarda os processos terminarem
wait

echo "----------------------------------------------------------"
echo "🚀 Ambas as VMs estão rodando!"
echo "🤖 Agente, você pode analisar os logs iniciais em:"
echo "   - $LOG_DIR/boot-uefi.log"
echo "   - $LOG_DIR/boot-bios.log"
echo "----------------------------------------------------------"
echo "Use 'make vm-connect-uefi' ou 'make vm-connect-bios' para interagir."
