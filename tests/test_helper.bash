#!/bin/bash

setup_test_env() {
	if [[ -n ${PROJECT_ROOT-} ]]; then
		: # Já definido, não fazer nada
	elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		PROJECT_ROOT="$(git rev-parse --show-toplevel)"
	else
		# Fallback para ambiente Docker ou sem git
		PROJECT_ROOT="/app"
		# Ou se preferir usar o diretório atual: PROJECT_ROOT="$(pwd)"
		if [[ ! -d "${PROJECT_ROOT}/tests" ]]; then
			PROJECT_ROOT="$(pwd)"
		fi
	fi
	export PROJECT_ROOT

	export INSTALLER_ROOT="${PROJECT_ROOT}/include/usr/local/bin/installer" export LIB_DIR="${INSTALLER_ROOT}/lib"
	export COMPONENTS_DIR="${INSTALLER_ROOT}/components"

	# Injetar nossos mocks no PATH
	export PATH="${PROJECT_ROOT}/tests/bin:${PATH}"

	# Arquivo de log de chamadas
	export MOCK_CALL_LOG="/tmp/mock_calls.log"
	rm -f "${MOCK_CALL_LOG}"

	# Configurações do instalador
	export LOG_FILE="/tmp/installer.log"
	export LOG_LEVEL="DEBUG"
	rm -f "${LOG_FILE}"
}

# Função auxiliar para verificar se um comando foi chamado com argumentos específicos
assert_called() {
	local expected="$1"
	if grep -q "${expected}" "${MOCK_CALL_LOG}"; then
		return 0
	else
		echo "Erro: Chamada '${expected}' não encontrada no log de mocks."
		echo "Chamadas registradas:"
		cat "${MOCK_CALL_LOG}"
		return 1
	fi
}
