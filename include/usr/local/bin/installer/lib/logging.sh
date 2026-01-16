#!/usr/bin/env bash
#
# lib/logging.sh - Biblioteca de logging avançado para DEBIAN_ZFS Installer
# Baseado em estratégias di-live
#

# Nível de log configurável
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Arquivo de log principal
LOG_FILE="${LOG_FILE:-/var/log/install-system.log}"

# Cores para saída no terminal
readonly COLOR_INFO="\033[0;36m"    # Azul claro
readonly COLOR_WARN="\033[0;33m"    # Amarelo
readonly COLOR_ERROR="\033[0;31m"   # Vermelho
readonly COLOR_DEBUG="\033[0;90m"   # Cinza escuro
readonly COLOR_RESET="\033[0m"      # Reset de cor
readonly COLOR_SUCCESS="\033[0;32m" # Verde

# =============================================================================
# FUNÇÕES DE LOGGING
# =============================================================================

# Log de informação
# Uso: log_info "Mensagem de info"
log_info() {
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo -e "${timestamp}] [INFO] $*" | tee -a "${LOG_FILE}"
}

# Log de aviso
# Uso: log_warn "Mensagem de aviso"
log_warn() {
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo -e "${timestamp}] [WARN] $*" | tee -a "${LOG_FILE}" >&2
}

# Log de erro
# Uso: log_error "Mensagem de erro"
log_error() {
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo -e "${timestamp}] [ERROR] $*" | tee -a "${LOG_FILE}" >&2
}

# Log de debug (só se LOG_LEVEL=DEBUG)
# Uso: log_debug "Mensagem de debug"
log_debug() {
	if [[ "${LOG_LEVEL}" != "DEBUG" ]]; then
		return 0
	fi

	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo -e "${timestamp}] [DEBUG] $*" >>"${LOG_FILE}"
}

# Log de comando com captura de saída
# Uso: log_command comando arg1 arg2
log_command() {
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	log_info "Executing: $*"

	local log_tmp
	log_tmp=$(mktemp)

	# Executar comando e capturar stdout/stderr
	"$@" > >(tee "${log_tmp}") 2>&1
	local exitcode=${PIPESTATUS[0]}

	# Verificar se houve erro
	if [[ ${exitcode} -ne 0 ]]; then
		log_error "Command failed with exit code ${exitcode}: $*"
		log_debug "  Last 10 lines from output:"
		tail -n 10 "${log_tmp}" | while IFS= read -r line; do
			log_debug "    OUTPUT: $line"
		done
	else
		log_debug "  Command succeeded"
	fi

	rm -f "${log_tmp}"

	return ${exitcode}
}

# Log de comando silencioso (sem output no terminal, apenas no log)
# Uso: log_silent comando arg1 arg2
log_silent() {
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo "${timestamp}] [CMD] $*" >>"${LOG_FILE}"

	"$@" >>"${LOG_FILE}" 2>&1
	local exitcode=$?

	if [[ ${exitcode} -ne 0 ]]; then
		log_error "Silent command failed with exit code ${exitcode}: $*"
	fi

	return ${exitcode}
}

# Log com indentação (para mostrar progresso)
# Uso: log_step "Passo 1: Descrição"
log_step() {
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	log_info "$*"
}

# Log de sucesso (com cor verde no terminal)
# Uso: log_success "Operação realizada com sucesso"
log_success() {
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo -e "${timestamp}] ${COLOR_SUCCESS}✓ SUCCESS: $*${COLOR_RESET}" | tee -a "${LOG_FILE}"
}

# Log de seção/cabeçalho
# Uso: log_section "=== Título da Seção ==="
log_section() {
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	log_info "$*"
}

# =============================================================================
# FUNÇÕES UTILITÁRIAS
# =============================================================================

# Inicializar log de um novo componente/etapa
# Uso: log_init_component "Nome do Componente"
log_init_component() {
	log_section "=== Iniciando: $* ==="
	sync
}

# Finalizar log de um componente/etapa
# Uso: log_end_component "Nome do Componente"
log_end_component() {
	log_success "=== Concluído: $* ==="
	sync
}

# Log de resumo de operação
# Uso: log_summary "Resumo" "Detalhes do que foi feito"
log_summary() {
	log_section "=== $1 ==="
	shift
	log_info "$*"
	log_section "=== Fim do Resumo ==="
}

# =============================================================================
# VALIDAÇÃO
# =============================================================================

# Verificar se arquivo de log existe e tem permissão de escrita
log_check_file() {
	if [[ ! -f "${LOG_FILE}" ]]; then
		touch "${LOG_FILE}" 2>/dev/null || {
			echo "FATAL: Não foi possível criar arquivo de log: ${LOG_FILE}" >&2
			exit 1
		}
	fi

	if [[ ! -w "${LOG_FILE}" ]]; then
		echo "FATAL: Arquivo de log não tem permissão de escrita: ${LOG_FILE}" >&2
		exit 1
	fi
}

# Rotina de inicialização da biblioteca de logging
log_init() {
	log_check_file

	log_info "=== Biblioteca de Logging Inicializada ==="
	log_info "Nível de log: ${LOG_LEVEL}"
	log_info "Arquivo de log: ${LOG_FILE}"
	log_info "====================================="
}

# Função de erro crítico com saída
error_exit() {
	log_error "$1"
	log_info "Verifique ${LOG_FILE} para detalhes"
	exit 1
}

# Executar inicialização automaticamente ao carregar a biblioteca
log_init
