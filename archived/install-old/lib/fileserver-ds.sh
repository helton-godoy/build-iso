#!/usr/bin/env bash
#
# fileserver-ds.sh - Design System v2.0 Monocromático para Fileserver Installer
#
# Paleta: Slate Blue monocromática
# Componentes: hero, sections, cards, progress, forms, selectors
#

set -euo pipefail

# ============================================================================
# PALETA DE CORES (Slate Blue Monocromático)
# ============================================================================

# Cores principais (Slate Blue)
DS_COLOR_PRIMARY="#6366f1"       # Indigo-500 (primário)
DS_COLOR_PRIMARY_LIGHT="#818cf8" # Indigo-400
DS_COLOR_PRIMARY_DARK="#4f46e5"  # Indigo-600

# Tons de cinza azulado
DS_COLOR_SLATE_50="#f8fafc"  # Fundo claro
DS_COLOR_SLATE_100="#f1f5f9" # Cards/sections
DS_COLOR_SLATE_200="#e2e8f0" # Bordas
DS_COLOR_SLATE_300="#cbd5e1" # Divisores
DS_COLOR_SLATE_400="#94a3b8" # Texto secundário
DS_COLOR_SLATE_500="#64748b" # Texto terciário
DS_COLOR_SLATE_600="#475569" # Texto principal
DS_COLOR_SLATE_700="#334155" # Headers
DS_COLOR_SLATE_800="#1e293b" # Títulos
DS_COLOR_SLATE_900="#0f172a" # Fundo escuro

# Cores de status
DS_COLOR_SUCCESS="#10b981" # Emerald-500
DS_COLOR_WARNING="#f59e0b" # Amber-500
DS_COLOR_ERROR="#ef4444"   # Red-500
DS_COLOR_INFO="#3b82f6"    # Blue-500

# ============================================================================
# CONFIGURAÇÕES GLOBAIS
# ============================================================================

DS_APP_NAME="FILESERVER INSTALLER"
DS_VERSION="2.0"

# ============================================================================
# COMPONENTES DE LAYOUT
# ============================================================================

# Limpa a tela e posiciona cursor no topo
ds_clear() {
	clear
}

# Renderiza o header principal estilizado
ds_hero() {
	local subtitle="${1:-}"

	echo
	gum style \
		--foreground "$DS_COLOR_PRIMARY" \
		--border double \
		--border-foreground "$DS_COLOR_PRIMARY" \
		--align center \
		--width 70 \
		--margin "0 0" \
		--padding "1 2" \
		"$(gum style --foreground "$DS_COLOR_PRIMARY" --bold "$DS_APP_NAME")" \
		"$(gum style --foreground "$DS_COLOR_SLATE_400" "v$DS_VERSION")" \
		"${subtitle:+$(gum style --foreground "$DS_COLOR_SLATE_500" "$subtitle")}"
	echo
}

# Inicia uma nova seção
ds_section() {
	local title="$1"
	local description="${2:-}"

	echo
	gum style --foreground "$DS_COLOR_PRIMARY" --bold "▸ $title"
	if [[ -n "$description" ]]; then
		gum style --foreground "$DS_COLOR_SLATE_400" "  $description"
	fi
	echo
}

# Renderiza um card com conteúdo
ds_card() {
	local content="$1"
	local status="${2:-}"

	local border_color="$DS_COLOR_SLATE_200"
	local status_line=""

	if [[ -n "$status" ]]; then
		case "$status" in
		success)
			status_line=$(gum style --foreground "$DS_COLOR_SUCCESS" "●")
			border_color="$DS_COLOR_SUCCESS"
			;;
		warning)
			status_line=$(gum style --foreground "$DS_COLOR_WARNING" "●")
			border_color="$DS_COLOR_WARNING"
			;;
		error)
			status_line=$(gum style --foreground "$DS_COLOR_ERROR" "●")
			border_color="$DS_COLOR_ERROR"
			;;
		info)
			status_line=$(gum style --foreground "$DS_COLOR_INFO" "●")
			border_color="$DS_COLOR_INFO"
			;;
		esac
	fi

	if [[ -n "$status_line" ]]; then
		gum style \
			--border normal \
			--border-foreground "$border_color" \
			--padding "1 2" \
			--margin "0 0 1 0" \
			"$status_line $content"
	else
		gum style \
			--border normal \
			--border-foreground "$border_color" \
			--padding "1 2" \
			--margin "0 0 1 0" \
			"$content"
	fi
}

# Divisor horizontal
ds_divider() {
	gum style --foreground "$DS_COLOR_SLATE_200" "─────────────────────────────────────────────────────────────"
}

# Espaçamento vertical
ds_spacer() {
	local lines="${1:-1}"
	for ((i = 0; i < lines; i++)); do
		echo
	done
}

# ============================================================================
# COMPONENTES DE TEXTO
# ============================================================================

ds_text() {
	local text="$1"
	gum style --foreground "$DS_COLOR_SLATE_600" "$text"
}

ds_text_muted() {
	local text="$1"
	gum style --foreground "$DS_COLOR_SLATE_400" "$text"
}

ds_text_bold() {
	local text="$1"
	gum style --foreground "$DS_COLOR_SLATE_700" --bold "$text"
}

ds_text_primary() {
	local text="$1"
	gum style --foreground "$DS_COLOR_PRIMARY" "$text"
}

ds_text_success() {
	local text="$1"
	gum style --foreground "$DS_COLOR_SUCCESS" "$text"
}

ds_text_warning() {
	local text="$1"
	gum style --foreground "$DS_COLOR_WARNING" "$text"
}

ds_text_error() {
	local text="$1"
	gum style --foreground "$DS_COLOR_ERROR" "$text"
}

# ============================================================================
# COMPONENTES DE FORMULÁRIO
# ============================================================================

# Input de texto estilizado
ds_input() {
	local placeholder="${1:-}"
	local default_value="${2:-}"

	local gum_opts=()
	gum_opts+=(--placeholder "$placeholder")
	gum_opts+=(--prompt.foreground "$DS_COLOR_PRIMARY")
	gum_opts+=(--placeholder.foreground "$DS_COLOR_SLATE_400")

	if [[ -n "$default_value" ]]; then
		gum_opts+=(--value "$default_value")
	fi

	gum input "${gum_opts[@]}"
}

# Input de senha
ds_password() {
	local placeholder="${1:-Senha}"

	gum input --password \
		--placeholder "$placeholder" \
		--prompt.foreground "$DS_COLOR_PRIMARY" \
		--placeholder.foreground "$DS_COLOR_SLATE_400"
}

# Confirmação sim/não
ds_confirm() {
	local message="$1"
	local affirmative="${2:-Sim}"
	local negative="${3:-Não}"

	# Se AUTOCONFIRM=1, pula a confirmação e retorna sucesso
	if [[ "${AUTOCONFIRM:-0}" == "1" ]]; then
		gum style --foreground "$DS_COLOR_SUCCESS" "✓ [AUTO-CONFIRMADO] $message"
		return 0
	fi

	gum confirm "$message" \
		--prompt.foreground "$DS_COLOR_SLATE_600" \
		--selected.background "$DS_COLOR_PRIMARY" \
		--selected.foreground "#ffffff" \
		--affirmative "$affirmative" \
		--negative "$negative"
}

# Seleção de opções única
ds_select() {
	local header="$1"
	shift

	gum choose \
		--header "$header" \
		--header.foreground "$DS_COLOR_SLATE_600" \
		--cursor.foreground "$DS_COLOR_PRIMARY" \
		--selected.foreground "$DS_COLOR_PRIMARY" \
		--cursor "> " \
		"$@"
}

# Seleção com preview (para discos, etc)
ds_select_with_preview() {
	local header="$1"
	shift

	# Recebe opções formatadas como "value|preview"
	local options=()
	for opt in "$@"; do
		options+=("$opt")
	done

	gum choose \
		--header "$header" \
		--header.foreground "$DS_COLOR_SLATE_600" \
		--cursor.foreground "$DS_COLOR_PRIMARY" \
		--selected.foreground "$DS_COLOR_PRIMARY" \
		--cursor "> " \
		"${options[@]}"
}

# ============================================================================
# COMPONENTES DE PROGRESSO
# ============================================================================

# Spinner para operações em andamento
ds_spinner() {
	local title="$1"
	shift

	gum spin \
		--spinner dot \
		--spinner.foreground "$DS_COLOR_PRIMARY" \
		--title "$title" \
		--title.foreground "$DS_COLOR_SLATE_600" \
		-- "$@"
}

# Barra de progresso (para operações com progresso conhecido)
ds_progress() {
	local percent="$1"
	local width=50
	local filled=$((percent * width / 100))
	local empty=$((width - filled))

	local bar=""
	for ((i = 0; i < filled; i++)); do
		bar+="█"
	done
	for ((i = 0; i < empty; i++)); do
		bar+="░"
	done

	gum style --foreground "$DS_COLOR_PRIMARY" "[$bar] $percent%"
}

# ============================================================================
# COMPONENTES DE FEEDBACK
# ============================================================================

ds_success() {
	local message="$1"
	echo
	gum style --foreground "$DS_COLOR_SUCCESS" "✓ $message"
	echo
}

ds_error() {
	local message="$1"
	echo
	gum style --foreground "$DS_COLOR_ERROR" "✗ $message"
	echo
}

ds_warning() {
	local message="$1"
	echo
	gum style --foreground "$DS_COLOR_WARNING" "⚠ $message"
	echo
}

ds_info() {
	local message="$1"
	echo
	gum style --foreground "$DS_COLOR_INFO" "ℹ $message"
	echo
}

# ============================================================================
# COMPONENTES ESPECIALIZADOS DO INSTALADOR
# ============================================================================

# Tela de boas-vindas
ds_welcome_screen() {
	local firmware_mode="$1"

	ds_clear
	ds_hero "Instalação Automatizada de Debian com ZFS"

	ds_card \
		"$(ds_text "Bem-vindo ao instalador oficial.")
$(ds_text_muted "Este assistente irá guiá-lo através da instalação do Debian")
$(ds_text_muted "com ZFS-on-Root e ZFSBootMenu.")

$(ds_text_warning "Aviso: Este processo é destrutivo para o disco selecionado.")" \
		"warning"

	echo
	ds_card \
		"$(ds_text_bold "Modo de Boot Detectado:")
$(ds_text "  $firmware_mode")" \
		"info"

	ds_spacer
}

# Tela de seleção de disco
ds_disk_select_screen() {
	ds_section "Seleção de Disco" "Escolha o disco onde o sistema será instalado"
}

# Tela de configuração
ds_config_screen() {
	ds_section "Configuração do Sistema" "Defina as configurações básicas do sistema"
}

# Tela de confirmação
ds_confirm_screen() {
	local disk="$1"
	local hostname="$2"
	local username="$3"

	ds_section "Confirmação" "Revise as configurações antes de prosseguir"

	ds_card \
		"$(ds_text_bold "Disco de Destino:")
$(ds_text "  $disk")

$(ds_text_bold "Hostname:")
$(ds_text "  $hostname")

$(ds_text_bold "Usuário:")
$(ds_text "  $username")" \
		"info"

	ds_spacer
	ds_card \
		"$(ds_text_error "⚠ TODOS OS DADOS NO DISCO SERÃO APAGADOS")
$(ds_text_muted "  Esta ação não pode ser desfeita.")" \
		"error"
}

# Tela de progresso da instalação
ds_install_progress_screen() {
	local step="$1"
	local total="$2"
	local description="$3"

	ds_clear
	ds_hero "Instalação em Progresso"

	local percent=$((step * 100 / total))
	ds_progress "$percent"

	echo
	ds_text "Etapa $step de $total: $description"
	ds_divider
}

# Tela de conclusão
ds_complete_screen() {
	ds_clear
	ds_hero "Instalação Concluída"

	ds_card \
		"$(ds_text_success "O sistema foi instalado com sucesso!")

$(ds_text "Próximos passos:")
$(ds_text "  1. Remova a mídia de instalação")
$(ds_text "  2. Reinicie o computador")
$(ds_text "  3. O sistema inicializará via ZFSBootMenu")" \
		"success"

	ds_spacer
}

# Log de operação
ds_log() {
	local message="$1"
	local level="${2:-info}"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	case "$level" in
	error) echo "[$timestamp] ERROR: $message" >&2 ;;
	warn) echo "[$timestamp] WARN: $message" >&2 ;;
	*) echo "[$timestamp] INFO: $message" ;;
	esac
}

# ============================================================================
# EXPORTAÇÃO
# ============================================================================

# Se este script for sourceado, as funções estarão disponíveis
# Se executado diretamente, mostra ajuda
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	ds_hero "Design System v2.0"
	ds_text "Este arquivo deve ser sourceado, não executado diretamente."
	ds_text "Use: source scripts/lib/fileserver-ds.sh"
	exit 1
fi
