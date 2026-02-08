#!/usr/bin/env bash
# @DEV_SCRIPT: extract-docs.sh
# @DEV_DESC: Extrai metadados de documentação (@INST_, @DEV_, @TEST_) para visualização,
#           validação e geração de documentação automatizada do projeto.
# @DEV_CATEGORY: documentação
# @DEV_DEP: grep, sed, bash
# @DEV_INPUT: Diretórios scripts/, tests/, instalador ou arquivo específico
# @DEV_OUTPUT: Documentação formatada em terminal ou markdown
# @DEV_MAKEFILE: docs, docs-installer, docs-dev, docs-tests, docs-all, docs-markdown

set -euo pipefail

# ============================================================================
# CONFIGURAÇÃO
# ============================================================================

INSTALLER_DIR="config-overrides/config/includes.chroot/usr/local/lib/installer"
SCRIPTS_DIR="scripts"
TESTS_DIR="tests"

# Cores para terminal
BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
RED="\033[31m"
RESET="\033[0m"

# Detecta se stdout é terminal
if [[ -t 1 ]]; then
	USE_COLOR=true
else
	USE_COLOR=false
	BOLD="" GREEN="" CYAN="" YELLOW="" MAGENTA="" RED="" RESET=""
fi

# ============================================================================
# @DEV_FUNC: header
# @DEV_DESC: Imprime cabeçalho de seção formatado
# @DEV_ARGS: $1 - Texto do cabeçalho
# ============================================================================
header() {
	echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
	echo -e "${BOLD}${CYAN}║  $1${RESET}"
	echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# ============================================================================
# @DEV_FUNC: subheader
# @DEV_DESC: Imprime subcabeçalho formatado
# @DEV_ARGS: $1 - Texto do subcabeçalho
# ============================================================================
subheader() {
	echo -e "\n${BOLD}${YELLOW}─── $1 ───${RESET}"
}

# ============================================================================
# @DEV_FUNC: extract_tags
# @DEV_DESC: Extrai tags de documentação de um arquivo
# @DEV_ARGS: $1 - Caminho do arquivo, $2 - Prefixo da tag (INST, DEV, TEST)
# @DEV_OUTPUT: Linhas contendo as tags encontradas
# ============================================================================
extract_tags() {
	local file="$1"
	local prefix="${2:-INST|DEV|TEST}"
	grep -E "@(${prefix})_[A-Z_]+" "$file" 2>/dev/null | sed 's/^[#[:space:]]*//' || true
}

# ============================================================================
# @DEV_FUNC: format_tag
# @DEV_DESC: Formata uma tag para exibição colorida
# @DEV_ARGS: $1 - Linha contendo a tag
# ============================================================================
format_tag() {
	local line="$1"
	local tag value

	# Extrai tag e valor
	if [[ "$line" =~ @([A-Z_]+):\ *(.*) ]]; then
		tag="${BASH_REMATCH[1]}"
		value="${BASH_REMATCH[2]}"
	else
		echo "  $line"
		return
	fi

	# Cores por tipo de tag
	local tag_color="$CYAN"
	case "$tag" in
	*_DESC | *_SCRIPT | *_LIB_NAME | *_STEP_ID)
		tag_color="$GREEN"
		;;
	*_TODO | *_CAUTION | *_DESTRUCTIVE)
		tag_color="$RED"
		;;
	*_DEP | *_TARGETS)
		tag_color="$YELLOW"
		;;
	*_FUNC)
		tag_color="$MAGENTA"
		;;
	esac

	printf "  ${tag_color}%-22s${RESET} %s\n" "@$tag:" "$value"
}

# ============================================================================
# @DEV_FUNC: process_file
# @DEV_DESC: Processa um arquivo e exibe suas tags formatadas
# @DEV_ARGS: $1 - Caminho do arquivo, $2 - Prefixo opcional (INST|DEV|TEST)
# ============================================================================
process_file() {
	local file="$1"
	local prefix="${2:-INST|DEV|TEST}"
	local base
	base=$(basename "$file")

	local tags
	tags=$(extract_tags "$file" "$prefix")

	# Só exibe se houver tags
	if [[ -z "$tags" ]]; then
		return
	fi

	echo -e "\n${BOLD}${GREEN}📄 $base${RESET}"
	echo -e "${YELLOW}────────────────────────────────────────${RESET}"

	while IFS= read -r line; do
		format_tag "$line"
	done <<<"$tags"
}

# ============================================================================
# @DEV_FUNC: process_directory
# @DEV_DESC: Processa todos os arquivos .sh de um diretório
# @DEV_ARGS: $1 - Diretório, $2 - Prefixo opcional, $3 - Recursivo (true/false)
# ============================================================================
process_directory() {
	local dir="$1"
	local prefix="${2:-INST|DEV|TEST}"
	local recursive="${3:-false}"

	if [[ ! -d "$dir" ]]; then
		echo -e "${RED}Diretório não encontrado: $dir${RESET}" >&2
		return 1
	fi

	if [[ "$recursive" == "true" ]]; then
		find "$dir" -name "*.sh" -type f | sort | while read -r f; do
			process_file "$f" "$prefix"
		done
	else
		shopt -s nullglob
		for f in "$dir"/*.sh; do
			[[ -f "$f" ]] && process_file "$f" "$prefix"
		done
		shopt -u nullglob
	fi
}

# ============================================================================
# @DEV_FUNC: generate_markdown
# @DEV_DESC: Gera documentação em formato Markdown
# @DEV_ARGS: $1 - Categoria (installer|dev|tests|all)
# @DEV_OUTPUT: Markdown formatado para stdout
# ============================================================================
generate_markdown() {
	local category="${1:-all}"

	echo "# Documentação Automatizada do Projeto"
	echo ""
	echo "> Gerado em: $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""
	echo "---"

	case "$category" in
	installer | all)
		echo ""
		echo "## Instalador - Bibliotecas"
		echo ""
		generate_markdown_section "$INSTALLER_DIR/libs" "INST"

		echo ""
		echo "## Instalador - Steps"
		echo ""
		generate_markdown_section "$INSTALLER_DIR/steps" "INST"
		;;
	esac

	case "$category" in
	dev | all)
		echo ""
		echo "## Scripts de Desenvolvimento"
		echo ""
		generate_markdown_section "$SCRIPTS_DIR" "DEV" true
		;;
	esac

	case "$category" in
	tests | all)
		echo ""
		echo "## Testes"
		echo ""
		generate_markdown_section "$TESTS_DIR" "TEST"
		;;
	esac
}

# ============================================================================
# @DEV_FUNC: generate_markdown_section
# @DEV_DESC: Gera seção Markdown para um diretório
# @DEV_ARGS: $1 - Diretório, $2 - Prefixo, $3 - Recursivo
# ============================================================================
generate_markdown_section() {
	local dir="$1"
	local prefix="${2:-DEV}"
	local recursive="${3:-false}"

	[[ ! -d "$dir" ]] && return

	local files
	if [[ "$recursive" == "true" ]]; then
		files=$(find "$dir" -name "*.sh" -type f | sort)
	else
		files=$(find "$dir" -maxdepth 1 -name "*.sh" -type f | sort)
	fi

	while IFS= read -r f; do
		[[ -z "$f" ]] && continue

		local base
		base=$(basename "$f")
		local tags
		tags=$(extract_tags "$f" "$prefix")

		[[ -z "$tags" ]] && continue

		echo "### \`$base\`"
		echo ""
		echo "| Tag | Valor |"
		echo "|-----|-------|"

		while IFS= read -r line; do
			if [[ "$line" =~ @([A-Z_]+):\ *(.*) ]]; then
				local tag="${BASH_REMATCH[1]}"
				local value="${BASH_REMATCH[2]}"
				echo "| \`@$tag\` | $value |"
			fi
		done <<<"$tags"

		echo ""
	done <<<"$files"
}

# ============================================================================
# @DEV_FUNC: show_stats
# @DEV_DESC: Exibe estatísticas de cobertura de documentação
# ============================================================================
show_stats() {
	header "ESTATÍSTICAS DE DOCUMENTAÇÃO"

	local total_scripts=0
	local documented_scripts=0

	# Conta scripts no instalador
	shopt -s nullglob
	for f in "$INSTALLER_DIR"/libs/*.sh "$INSTALLER_DIR"/steps/*.sh; do
		[[ -f "$f" ]] || continue
		total_scripts=$((total_scripts + 1))
		if grep -qE "@INST_" "$f" 2>/dev/null; then
			documented_scripts=$((documented_scripts + 1))
		fi
	done
	shopt -u nullglob

	# Conta scripts de desenvolvimento
	while IFS= read -r f; do
		[[ -f "$f" ]] || continue
		total_scripts=$((total_scripts + 1))
		if grep -qE "@DEV_" "$f" 2>/dev/null; then
			documented_scripts=$((documented_scripts + 1))
		fi
	done < <(find "$SCRIPTS_DIR" -name "*.sh" -type f 2>/dev/null)

	# Conta testes
	shopt -s nullglob
	for f in "$TESTS_DIR"/*.sh; do
		[[ -f "$f" ]] || continue
		total_scripts=$((total_scripts + 1))
		if grep -qE "@TEST_" "$f" 2>/dev/null; then
			documented_scripts=$((documented_scripts + 1))
		fi
	done
	shopt -u nullglob

	local percentage=0
	if ((total_scripts > 0)); then
		percentage=$((documented_scripts * 100 / total_scripts))
	fi

	echo ""
	echo -e "  ${BOLD}Total de scripts:${RESET}      $total_scripts"
	echo -e "  ${BOLD}Scripts documentados:${RESET}  $documented_scripts"
	echo -e "  ${BOLD}Cobertura:${RESET}             ${percentage}%"
	echo ""

	# Barra de progresso
	local bar_width=50
	local filled=$((percentage * bar_width / 100))
	local empty=$((bar_width - filled))

	printf "  ["
	printf "${GREEN}%${filled}s${RESET}" | tr ' ' '█'
	printf "${RED}%${empty}s${RESET}" | tr ' ' '░'
	printf "] ${percentage}%%\n"
}

# ============================================================================
# @DEV_FUNC: show_usage
# @DEV_DESC: Exibe ajuda de uso do script
# ============================================================================
show_usage() {
	cat <<EOF
${BOLD}Uso:${RESET} $(basename "$0") [OPÇÃO] [ARQUIVO]

${BOLD}Extrai e exibe documentação embarcada do projeto.${RESET}

${BOLD}OPÇÕES:${RESET}
  -i, --installer     Exibe documentação do instalador (@INST_)
  -d, --dev           Exibe documentação de scripts de dev (@DEV_)
  -t, --tests         Exibe documentação de testes (@TEST_)
  -a, --all           Exibe toda a documentação (padrão)
  -m, --markdown      Gera saída em formato Markdown
  -s, --stats         Exibe estatísticas de cobertura
  -h, --help          Exibe esta ajuda

${BOLD}EXEMPLOS:${RESET}
  $(basename "$0")                    # Exibe toda documentação
  $(basename "$0") -i                 # Apenas instalador
  $(basename "$0") -d                 # Apenas scripts de dev
  $(basename "$0") -t                 # Apenas testes
  $(basename "$0") -m -a > docs.md    # Gera Markdown completo
  $(basename "$0") arquivo.sh         # Exibe tags de um arquivo
  $(basename "$0") -s                 # Estatísticas de cobertura

${BOLD}TAGS SUPORTADAS:${RESET}
  @INST_*   Instalador (libs, steps)
  @DEV_*    Scripts de desenvolvimento
  @TEST_*   Scripts de teste
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
	local mode="all"
	local format="terminal"
	local target_file=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-i | --installer)
			mode="installer"
			shift
			;;
		-d | --dev)
			mode="dev"
			shift
			;;
		-t | --tests)
			mode="tests"
			shift
			;;
		-a | --all)
			mode="all"
			shift
			;;
		-m | --markdown)
			format="markdown"
			shift
			;;
		-s | --stats)
			show_stats
			exit 0
			;;
		-h | --help)
			show_usage
			exit 0
			;;
		-*)
			echo "Opção desconhecida: $1"
			show_usage
			exit 1
			;;
		*)
			target_file="$1"
			shift
			;;
		esac
	done

	# Processa arquivo específico
	if [[ -n "$target_file" ]]; then
		if [[ -f "$target_file" ]]; then
			process_file "$target_file"
		else
			echo -e "${RED}Erro: Arquivo '$target_file' não encontrado.${RESET}" >&2
			exit 1
		fi
		exit 0
	fi

	# Gera Markdown
	if [[ "$format" == "markdown" ]]; then
		generate_markdown "$mode"
		exit 0
	fi

	# Exibe documentação em terminal
	case "$mode" in
	installer)
		header "INSTALADOR - BIBLIOTECAS"
		process_directory "$INSTALLER_DIR/libs" "INST"
		header "INSTALADOR - STEPS"
		process_directory "$INSTALLER_DIR/steps" "INST"
		;;
	dev)
		header "SCRIPTS DE DESENVOLVIMENTO"
		process_directory "$SCRIPTS_DIR" "DEV" true
		;;
	tests)
		header "TESTES"
		process_directory "$TESTS_DIR" "TEST"
		;;
	all)
		header "INSTALADOR - BIBLIOTECAS"
		process_directory "$INSTALLER_DIR/libs" "INST"
		header "INSTALADOR - STEPS"
		process_directory "$INSTALLER_DIR/steps" "INST"
		header "SCRIPTS DE DESENVOLVIMENTO"
		process_directory "$SCRIPTS_DIR" "DEV" true
		header "TESTES"
		process_directory "$TESTS_DIR" "TEST"
		;;
	esac
}

main "$@"
