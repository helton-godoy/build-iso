#!/usr/bin/env bash
# =============================================================================
# Validacao de Contrato AGENTS.md
# =============================================================================
# Verifica conformidade com AGENTS.md
# - Deteta variaveis globais proibidas (atribuicoes diretas fora de funcoes)
# - Confirma uso de 'local' para variaveis em funcoes
# - Valida que state_set/state_get e usado para persistencia
# =============================================================================

set -euo pipefail

# Configuracao
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALLER_DIR="$PROJECT_ROOT/config-overrides/config/includes.chroot/usr/local/lib/installer"

# Contadores
total_files=0
files_with_issues=0
issues_found=0
VERBOSE=false

# Issues encontradas
declare -a GLOBAL_VAR_ISSUES=()
declare -a NON_LOCAL_ISSUES=()
declare -a STATE_USAGE_ISSUES=()

# =============================================================================
# Funcoes
# =============================================================================

usage() {
	cat <<EOF
Uso: $(basename "$0") [OPCOES]

Valida conformidade com o contrato AGENTS.md.

OPCOES:
  -h, --help          Mostra esta ajuda
  -v, --verbose       Modo verboso
  -j, --json          Saida em formato JSON
  -o, --output FILE   Salva relatorio em arquivo

REGRAS VALIDADAS:
  1. Variaveis globais proibidas fora de funcoes
  2. Uso de 'local' para variaveis em funcoes
  3. Persistencia via state_set/state_get
  4. Shebang correto (#!/usr/bin/env bash)
  5. Uso de set -euo pipefail
EOF
}

log() {
	local level="$1"
	shift
	case "$level" in
	INFO) echo "[INFO] $*" ;;
	WARN) echo "[WARN] $*" >&2 ;;
	ERROR) echo "[ERROR] $*" >&2 ;;
	DEBUG) [[ "${VERBOSE:-false}" == "true" ]] && echo "[DEBUG] $*" ;;
	esac
}

# Detecta variaveis globais fora de funcoes (anti-padrao)
check_global_vars() {
	local file="$1"
	local in_function=false
	local func_name=""
	local line_num=0

	while IFS= read -r line; do
		((line_num++))

		# Ignora comentarios e linhas vazias
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// /}" ]] && continue

		# Detecta inicio de funcao
		if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?[a-z_][a-z0-9_]*[[:space:]]*\(\) ]]; then
			in_function=true
			func_name=$(echo "$line" | grep -oE '[a-z_][a-z0-9_]*' | head -1)
			continue
		fi

		# Detecta fim de funcao (palavra chave ou chave de fechamento)
		if [[ "$in_function" == true ]] && [[ "$line" =~ ^[[:space:]]*\} ]]; then
			in_function=false
			func_name=""
			continue
		fi

		# Se fora de funcao, verifica atribuicao de variavel
		if [[ "$in_function" == false ]]; then
			# Ignorashebang e export
			[[ "$line" =~ ^#! ]] && continue
			[[ "$line" =~ ^[[:space:]]*export[[:space:]]+ ]] && continue

			# Verifica atribuicao de variavel (NOME=valor)
			if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
				local var_name
				var_name=$(echo "$line" | cut -d'=' -f1 | xargs)
				# Ignora CONSTANTES (maiusculas) e variaveis de ambiente conhecidas
				if [[ ! "$var_name" =~ ^[A-Z_][A-Z0-9_]*$ ]] &&
					[[ "$var_name" != "PATH" ]] &&
					[[ "$var_name" != "HOME" ]] &&
					[[ "$var_name" != "USER" ]]; then
					GLOBAL_VAR_ISSUES+=("$(printf '%s:%d: Variavel global "%s" fora de funcao' "$file" "$line_num" "$var_name")")
				fi
			fi
		fi
	done <"$file"
}

# Verifica uso de local em funcoes
check_local_vars() {
	local file="$1"
	local line_num=0

	while IFS= read -r line; do
		((line_num++))

		# Detecta funcao
		if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?[a-z_][a-z0-9_]*[[:space:]]*\(\) ]]; then
			local func_name
			func_name=$(echo "$line" | grep -oE '[a-z_][a-z0-9_]*' | head -1)

			# Procura proximas linhas para atribuicoes sem local
			local next_lines=""
			next_lines=$(tail -n +$((line_num + 1)) "$file" | head -20)

			# Verifica atribuicoes de variavel sem local dentro da funcao
			while IFS= read -r inner_line; do
				# Para ao encontrar outra funcao ou chave de fechamento
				[[ "$inner_line" =~ ^[[:space:]]*\} ]] && break
				[[ "$inner_line" =~ ^[[:space:]]*(function[[:space:]]+) ]] && break

				# Verifica atribuicao sem local
				if [[ "$inner_line" =~ ^[[:space:]]*[a-z_][a-z0-9_]*= ]]; then
					if [[ ! "$inner_line" =~ local[[:space:]] ]]; then
						local var_name
						var_name=$(echo "$inner_line" | cut -d'=' -f1 | xargs)
						NON_LOCAL_ISSUES+=("$(printf '%s:%d: Variavel "%s" em funcao %s sem "local"' "$file" "$line_num" "$var_name" "$func_name")")
					fi
				fi
			done <<<"$next_lines"
		fi
	done <"$file"
}

# Verifica uso de state_set/state_get
check_state_usage() {
	local file="$1"

	# Verifica se o arquivo usa persistencia mas nao usa state_set/state_get
	if grep -qE '(declare|export).*=' "$file" 2>/dev/null; then
		if ! grep -qE 'state_(set|get)' "$file" 2>/dev/null; then
			STATE_USAGE_ISSUES+=("$(printf '%s: Arquivo usa variaveis mas nao usa state_set/state_get para persistencia' "$file")")
		fi
	fi
}

# Valida shebang e set -euo pipefail
check_shebang_and_traps() {
	local file="$1"
	local first_line
	local has_error=false

	read -r first_line <"$file"

	# Verifica shebang
	if [[ ! "$first_line" =~ ^#!/(usr/bin/env|bin/bash) ]]; then
		log WARN "Shebang invalido em $file: $first_line"
	fi

	# Verifica set -euo pipefail
	if ! grep -qE 'set -euo pipefail' "$file"; then
		log WARN "Falta "set -euo pipefail" em $file"
	fi
}

# Valida arquivo
validate_file() {
	local file="$1"

	((total_files++))

	log DEBUG "Validando: $file"

	# Executa todas as validacoes
	check_shebang_and_traps "$file"
	check_global_vars "$file"
	check_local_vars "$file"
	check_state_usage "$file"

	# Se encontrou issues, marca arquivo
	if [[ ${#GLOBAL_VAR_ISSUES[@]} -gt 0 ]] ||
		[[ ${#NON_LOCAL_ISSUES[@]} -gt 0 ]] ||
		[[ ${#STATE_USAGE_ISSUES[@]} -gt 0 ]]; then
		((files_with_issues++))
	fi
}

# Valida todos os arquivos
validate_all() {
	local -a shell_files=()

	log INFO "Iniciando validacao de contrato AGENTS.md..."

	# Procura por arquivos shell
	while IFS= read -r -d '' file; do
		shell_files+=("$file")
	done < <(find "$INSTALLER_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null || true)

	if [[ -f "$PROJECT_ROOT/config-overrides/config/includes.chroot/usr/local/bin/installer" ]]; then
		shell_files+=("$PROJECT_ROOT/config-overrides/config/includes.chroot/usr/local/bin/installer")
	fi

	if [[ ${#shell_files[@]} -eq 0 ]]; then
		log WARN "Nenhum arquivo shell encontrado"
		return 1
	fi

	log INFO "Encontrados ${#shell_files[@]} arquivos"

	for file in "${shell_files[@]}"; do
		validate_file "$file"
	done
}

# Gera relatorio
generate_report() {
	echo "=============================================="
	echo "  RELATORIO DE CONFORMIDADE AGENTS.MD"
	echo "=============================================="
	echo
	echo "Arquivos analisados:     $total_files"
	echo "Arquivos com issues:     $files_with_issues"
	echo

	if [[ ${#GLOBAL_VAR_ISSUES[@]} -gt 0 ]]; then
		echo "--- Variaveis Globais Proibidas (${#GLOBAL_VAR_ISSUES[@]}) ---"
		printf '%s\n' "${GLOBAL_VAR_ISSUES[@]}"
		echo
	fi

	if [[ ${#NON_LOCAL_ISSUES[@]} -gt 0 ]]; then
		echo "--- Variaveis sem 'local' em funcoes (${#NON_LOCAL_ISSUES[@]}) ---"
		printf '%s\n' "${NON_LOCAL_ISSUES[@]}"
		echo
	fi

	if [[ ${#STATE_USAGE_ISSUES[@]} -gt 0 ]]; then
		echo "--- Issues de Persistencia (${#STATE_USAGE_ISSUES[@]}) ---"
		printf '%s\n' "${STATE_USAGE_ISSUES[@]}"
		echo
	fi

	((issues_found = ${#GLOBAL_VAR_ISSUES[@]} + ${#NON_LOCAL_ISSUES[@]} + ${#STATE_USAGE_ISSUES[@]}))

	if [[ $issues_found -gt 0 ]]; then
		echo "Total de issues encontradas: $issues_found"
		echo "Status: FALHA"
		echo "Acao: Corrigir issues listadas acima"
		return 1
	else
		echo "Status: SUCESSO"
		echo "Todos os arquivos estao em conformidade com AGENTS.md!"
		return 0
	fi
}

# =============================================================================
# Main
# =============================================================================

VERBOSE=false
JSON_OUTPUT=false
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	-v | --verbose)
		VERBOSE=true
		shift
		;;
	-j | --json)
		JSON_OUTPUT=true
		shift
		;;
	-o | --output)
		OUTPUT_FILE="$2"
		shift 2
		;;
	*)
		echo "Opcao invalida: $1"
		usage
		exit 1
		;;
	esac
done

validate_all
generate_report

exit $?
