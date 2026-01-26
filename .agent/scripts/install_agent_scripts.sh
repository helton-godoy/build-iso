#!/bin/bash
# .agent/scripts/install_agent_scripts.sh
# Instalador automático para os scripts do Antigravity Kit
# Verifica dependências, instala se necessário e configura monitoramento

set -e # Parar em erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções de log
log_info() {
	echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se comando existe
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Instalar pacote se não existir
install_if_missing() {
	local package=$1
	local description=$2
	local check_command=${3:-$package} # Comando para verificar, padrão é o nome do pacote

	if command_exists "$check_command"; then
		log_success "$description já está instalado"
		return 0
	fi

	log_info "Instalando $description..."
	if command -v apt >/dev/null 2>&1; then
		sudo apt update && sudo apt install -y "$package"
	elif command -v yum >/dev/null 2>&1; then
		sudo yum install -y "$package"
	elif command -v dnf >/dev/null 2>&1; then
		sudo dnf install -y "$package"
	elif command -v pacman >/dev/null 2>&1; then
		sudo pacman -S --noconfirm "$package"
	else
		log_error "Gerenciador de pacotes não suportado. Instale $description manualmente."
		return 1
	fi

	if command_exists "$check_command"; then
		log_success "$description instalado com sucesso"
	else
		log_error "Falha ao instalar $description"
		return 1
	fi
}

# Verificar e instalar dependências
check_dependencies() {
	log_info "Verificando dependências do sistema..."

	# Python 3
	install_if_missing python3 "Python 3"

	# Git
	install_if_missing git "Git"

	# inotify-tools (para monitoramento de arquivos)
	install_if_missing inotify-tools "inotify-tools" inotifywait

	# Node.js e npm (opcional, para auto_preview)
	if ! command_exists node || ! command_exists npm; then
		log_warning "Node.js/npm não encontrado. auto_preview.py pode não funcionar completamente."
		log_info "Instalando Node.js e npm..."
		if command -v apt >/dev/null 2>&1; then
			curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
			sudo apt-get install -y nodejs
		else
			log_warning "Instale Node.js manualmente para funcionalidade completa do auto_preview"
		fi
	else
		log_success "Node.js e npm já estão instalados"
	fi

	# Verificar se estamos em um repositório git
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		log_error "Este diretório não é um repositório Git. Os scripts de commit não funcionarão."
		exit 1
	fi

	log_success "Todas as dependências verificadas"
}

# Tornar scripts executáveis
make_scripts_executable() {
	log_info "Tornando scripts executáveis..."

	local scripts=(
		"auto_preview.py"
		"autocommit_watcher.sh"
		"checklist.py"
		"sentinel.sh"
		"session_manager.py"
		"smart_commit.py"
		"task_router.py"
		"verify_all.py"
	)

	for script in "${scripts[@]}"; do
		if [[ -f $script ]]; then
			chmod +x "$script"
			log_success "$script tornado executável"
		else
			log_warning "$script não encontrado"
		fi
	done
}

# Criar diretórios necessários
create_directories() {
	log_info "Criando diretórios necessários..."

	mkdir -p .agent/logs
	mkdir -p .agent/tmp

	log_success "Diretórios criados"
}

# Configurar monitoramento automático
setup_monitoring() {
	log_info "Configurando monitoramento automático..."

	# Parar qualquer instância existente
	pkill -f "sentinel.sh" || true
	pkill -f "autocommit_watcher.sh" || true

	# Tentar aumentar limite de inotify se necessário
	CURRENT_INSTANCES=$(find /proc/*/fd -lname anon_inode:inotify 2>/dev/null | wc -l)
	CURRENT_LIMIT=$(cat /proc/sys/fs/inotify/max_user_instances)
	if [[ $CURRENT_INSTANCES -ge $((CURRENT_LIMIT - 10)) ]]; then
		log_warning "Muitos watchers inotify em uso (${CURRENT_INSTANCES}/${CURRENT_LIMIT}). Tentando aumentar limite..."
		if echo 256 | sudo tee /proc/sys/fs/inotify/max_user_instances >/dev/null 2>&1; then
			log_success "Limite de inotify aumentado para 256"
		else
			log_warning "Não foi possível aumentar limite de inotify. O sentinel pode falhar."
		fi
	fi

	# Iniciar sentinel em background
	log_info "Iniciando Agent Sentinel..."
	nohup ./sentinel.sh >.agent/logs/sentinel.out 2>&1 &

	# Salvar PID
	echo $! >.agent/sentinel.pid

	sleep 2

	# Verificar se está rodando
	if kill -0 $(cat .agent/sentinel.pid) 2>/dev/null; then
		log_success "Agent Sentinel iniciado (PID: $(cat .agent/sentinel.pid))"
	else
		log_error "Falha ao iniciar Agent Sentinel"
		log_info "Verifique .agent/logs/sentinel.out para detalhes"
		return 1
	fi

	log_success "Monitoramento configurado"
}

# Testar instalação
test_installation() {
	log_info "Testando instalação..."

	# Testar session_manager.py
	if python3 session_manager.py status >/dev/null 2>&1; then
		log_success "session_manager.py funcionando"
	else
		log_warning "session_manager.py pode ter problemas"
	fi

	# Testar task_router.py
	if python3 task_router.py "test query" >/dev/null 2>&1; then
		log_success "task_router.py funcionando"
	else
		log_warning "task_router.py pode ter problemas"
	fi

	# Verificar se sentinel está rodando
	if [[ -f .agent/sentinel.pid ]] && kill -0 $(cat .agent/sentinel.pid) 2>/dev/null; then
		log_success "Sentinel está ativo"
	else
		log_warning "Sentinel pode não estar rodando"
	fi

	log_success "Testes concluídos"
}

# Função principal
main() {
	echo
	echo "🤖 ANTIGRAVITY KIT - INSTALADOR DE SCRIPTS"
	echo "=========================================="
	echo

	# Verificar se estamos no diretório correto
	if [[ ! -f "sentinel.sh" ]] || [[ ! -f "smart_commit.py" ]]; then
		log_error "Execute este script dentro do diretório .agent/scripts/"
		exit 1
	fi

	check_dependencies
	make_scripts_executable
	create_directories
	setup_monitoring
	test_installation

	echo
	log_success "INSTALAÇÃO CONCLUÍDA! ✨"
	echo
	echo "Scripts disponíveis:"
	echo "  • python3 auto_preview.py [start|stop|status] [porta]"
	echo "  • python3 checklist.py . [--url URL]"
	echo "  • python3 session_manager.py [status|info] [caminho]"
	echo "  • python3 smart_commit.py"
	echo '  • python3 task_router.py "sua tarefa"'
	echo "  • python3 verify_all.py . --url URL"
	echo
	echo "Monitoramento ativo:"
	echo "  • Sentinel rodando em background (PID: $(cat .agent/sentinel.pid))"
	echo "  • Commits automáticos ativados"
	echo
	echo "Logs em: .agent/logs/"
	echo
}

# Executar se chamado diretamente
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
	main "$@"
fi
