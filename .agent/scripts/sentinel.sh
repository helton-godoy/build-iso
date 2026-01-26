#!/bin/bash

# Configurações
# Navegar para o diretório raiz do projeto
cd "$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")" || exit
PROJECT_DIR="$(pwd)"
WATCH_DIR="${PROJECT_DIR}"
COMMIT_SCRIPT=".agent/scripts/smart_commit.py"
# Aumentado para 25s para dar tempo do agente "pensar" entre arquivos
DEBOUNCE_SECONDS=25
IGNORE_PATTERN="(\.git|node_modules|\.agent/tmp|__pycache__|\.trunk|build/|output/|\.lock$)"

echo "🤖 Agent Sentinel v2 ativado."
echo "👀 Monitorando: ${WATCH_DIR}"
echo "⏳ Tempo de estabilização (debounce): ${DEBOUNCE_SECONDS}s"

# Verificar limite de inotify
CURRENT_LIMIT=$(cat /proc/sys/fs/inotify/max_user_instances)
echo "📊 Limite inotify: ${CURRENT_LIMIT} instâncias"

# Arquivo de timestamp para controle de debounce
LAST_CHANGE_FILE=".agent/tmp/sentinel_last_change"
LOCK_FILE="/tmp/agent_sentinel_commit.lock"
mkdir -p .agent/tmp
touch "${LAST_CHANGE_FILE}"

# Função para verificar se é seguro comitar
is_safe_to_commit() {
	# 1. Verifica se há arquivos vazios (0 bytes) rastreados ou modificados
	# Isso evita comitar arquivos que acabaram de ser criados mas ainda não têm conteúdo
	EMPTY_FILES=$(find . -maxdepth 4 -type f -size 0c ! -path "./.git/*" ! -path "./.agent/tmp/*")

	if [[ -n ${EMPTY_FILES} ]]; then
		echo "⚠️  Commit adiado: Arquivos vazios detectados (processamento incompleto?):"
		echo "${EMPTY_FILES}" | head -n 3
		return 1
	fi

	# 2. Verifica se o Git está bloqueado (index.lock existe)
	if [[ -f ".git/index.lock" ]]; then
		echo "⚠️  Commit adiado: Git está bloqueado (index.lock existe)."
		return 1
	fi

	return 0
}

perform_commit() {
	if [[ -f ${COMMIT_SCRIPT} ]]; then
		if is_safe_to_commit; then
			echo "⚡ Estabilização (${DEBOUNCE_SECONDS}s) concluída. Executando smart_commit..."
			python3 "${COMMIT_SCRIPT}"
		else
			echo "⏳ Segurança falhou. Aguardando próximo ciclo..."
			# Atualiza o timestamp para tentar novamente em breve sem esperar evento de disco
			date +%s >"${LAST_CHANGE_FILE}"
		fi
	else
		echo "❌ Erro: ${COMMIT_SCRIPT} não encontrado!"
	fi
}

# Loop de Monitoramento
# close_write: Garante que o arquivo foi salvo e fechado (melhor que modify)
if ! inotifywait -m -r -e close_write -e moved_to -e create -e delete --exclude "${IGNORE_PATTERN}" --format "%w%f" "${WATCH_DIR}" 2>/tmp/sentinel_error.log; then
	echo "❌ Erro ao inicializar inotify. Possíveis causas:"
	echo "   - Muitos watchers em uso (limite: ${CURRENT_LIMIT})"
	echo "   - Execute: sudo sysctl -w fs.inotify.max_user_instances=256"
	echo "   - Ou reinicie processos que usam inotify"
	cat /tmp/sentinel_error.log 2>/dev/null
	exit 1
fi | while read FILE; do
	# Ignora logs do próprio sentinel
	if [[ ${FILE} == *".agent/tmp"* ]]; then continue; fi

	# Atualiza o timestamp da última mudança
	date +%s >"${LAST_CHANGE_FILE}"

	# Inicia verificação em background
	(
		sleep "${DEBOUNCE_SECONDS}"

		SAVED_TIME=$(cat "${LAST_CHANGE_FILE}")
		NOW=$(date +%s)
		DIFF=$((NOW - SAVED_TIME))

		# Se passou o tempo de debounce E ninguém tocou no timestamp recentemente
		if [[ ${DIFF} -ge ${DEBOUNCE_SECONDS} ]]; then
			# Tenta adquirir lock de execução (mutex simples)
			if mkdir "${LOCK_FILE}" 2>/dev/null; then
				# Verifica se há mudanças reais para comitar
				if git status --porcelain | grep -q .; then
					perform_commit
				fi
				rm -rf "${LOCK_FILE}"
			fi
		fi
	) &
done
