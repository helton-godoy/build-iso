#!/bin/bash
# .agent/scripts/autocommit_watcher.sh
# Monitora mudanças no diretório e dispara o smart_commit.py
# Logs em: .agent/logs/autocommit.log

PROJECT_DIR="$(pwd)"
LOG_FILE="${PROJECT_DIR}/.agent/logs/autocommit.log"
COMMIT_SCRIPT="${PROJECT_DIR}/.agent/scripts/smart_commit.py"
DEBOUNCE_SECONDS=30

# Função de Log
log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"${LOG_FILE}"
}

log "=== Iniciando Autocommit Watcher ==="

# Verificar dependências
if ! command -v inotifywait >/dev/null; then
	log "ERRO: inotifywait não encontrado. Instale inotify-tools."
	exit 1
fi

# Matar instâncias antigas deste script ou inotifywait lançados por nós
# (Cuidado para não matar processos de outros usuários se compartilhado, mas aqui assumimos single user)
pkill -f "inotifywait.*autocommit_watcher" || true

log "Monitorando: ${PROJECT_DIR}"

# Loop principal de monitoramento
# Exclui .git, node_modules, build artifacts, logs
inotifywait -m -r \
	-e close_write -e moved_to -e create -e delete \
	--exclude '(\.git/|node_modules/|\.agent/logs/|\.agent/tmp/|build/|output/|cache/|\.trunk/)' \
	--format '%w%f' \
	"${PROJECT_DIR}" | while read -r file; do

	log "Mudança detectada: ${file}"

	# Lógica de Debounce simples:
	# Cria um arquivo de flag com timestamp. Um loop separado verifica a inatividade.
	# Mas para simplificar em um script bash único sem complexidade de PID:
	# Vamos apenas registrar que houve mudança.

	# Criar arquivo de sinalização
	touch "${PROJECT_DIR}/.agent/tmp/dirty_signal"
done &

INOTIFY_PID=$!
log "Processo inotifywait iniciado (PID: ${INOTIFY_PID})"

# Loop de Commit (Debounce Logic)
while true; do
	sleep 5

	SIGNAL_FILE="${PROJECT_DIR}/.agent/tmp/dirty_signal"

	if [[ -f ${SIGNAL_FILE} ]]; then
		# Verificar idade do sinal
		LAST_CHANGE=$(stat -c %Y "${SIGNAL_FILE}")
		NOW=$(date +%s)
		AGE=$((NOW - LAST_CHANGE))

		if [[ ${AGE} -ge ${DEBOUNCE_SECONDS} ]]; then
			log "Período de silêncio detectado (${AGE}s). Disparando commit..."

			# Remover sinal antes de commitar para não entrar em loop infinito
			# se o commit gerar arquivos (embora devêssemos ignorar .git)
			rm -f "${SIGNAL_FILE}"

			if [[ -f ${COMMIT_SCRIPT} ]]; then
				log "Executando smart_commit.py..."
				# Capturar saída do script de commit
				OUTPUT=$(python3 "${COMMIT_SCRIPT}" 2>&1)
				EXIT_CODE=$?

				log "Resultado Commit (${EXIT_CODE}):"
				echo "${OUTPUT}" >>"${LOG_FILE}"
			else
				log "ERRO: Script de commit não encontrado: ${COMMIT_SCRIPT}"
			fi
		fi
	fi
done
