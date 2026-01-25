#!/bin/bash

# Configurações
WATCH_DIR="$(pwd)"
COMMIT_SCRIPT=".agent/scripts/smart_commit.py"
DEBOUNCE_SECONDS=10
IGNORE_PATTERN="(\.git|node_modules|\.agent/tmp|__pycache__|\.trunk|build/|output/)"

echo "🤖 Agent Sentinel ativado."
echo "👀 Monitorando: $WATCH_DIR"
echo "⏳ Tempo de estabilização (debounce): ${DEBOUNCE_SECONDS}s"

# Arquivo de timestamp para controle de debounce
LAST_CHANGE_FILE="/tmp/agent_sentinel_last_change"
touch "$LAST_CHANGE_FILE"

# Função para realizar o commit
perform_commit() {
	# Verifica se o script de commit existe
	if [ -f "$COMMIT_SCRIPT" ]; then
		echo "⚡ Estabilização detectada. Executando smart_commit..."
		python3 "$COMMIT_SCRIPT"
	else
		echo "❌ Erro: $COMMIT_SCRIPT não encontrado!"
	fi
}

# Loop de Monitoramento
# -m: monitor contínuo
# -r: recursivo
# -e: eventos de fechar escrita, mover, criar, deletar
inotifywait -m -r -e close_write -e moved_to -e create -e delete --exclude "$IGNORE_PATTERN" --format "%w%f" "$WATCH_DIR" | while read FILE; do
	# Ignora o próprio arquivo de log ou arquivos temporários do sistema
	if [[ $FILE == *".git"* ]]; then continue; fi

	# Atualiza o timestamp da última mudança
	CURRENT_TIME=$(date +%s)
	echo "$CURRENT_TIME" >"$LAST_CHANGE_FILE"

	# Inicia (em background) o verificador de debounce
	(
		sleep $DEBOUNCE_SECONDS

		# Lê o timestamp salvo
		SAVED_TIME=$(cat "$LAST_CHANGE_FILE")
		NOW=$(date +%s)

		# Se a diferença entre AGORA e a ÚLTIMA MUDANÇA for maior ou igual ao debounce,
		# significa que ninguém tocou nos arquivos nesse intervalo.
		DIFF=$((NOW - SAVED_TIME))

		if [ "$DIFF" -ge "$DEBOUNCE_SECONDS" ]; then
			# Garante que não estamos executando múltiplos commits simultâneos (race condition simples)
			LOCK_FILE="/tmp/agent_sentinel_commit.lock"
			if mkdir "$LOCK_FILE" 2>/dev/null; then
				# Verifica se há algo para commitar (git status) para evitar commits vazios ou de logs
				if git status --porcelain | grep -q .; then
					perform_commit
				fi
				rm -rf "$LOCK_FILE"
			fi
		fi
	) &
done
