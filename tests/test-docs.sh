#!/usr/bin/env bash
# @TEST_SCRIPT: test-docs.sh
# @TEST_CATEGORY: validation
# @TEST_DESC: Valida a integridade da documentação embarcada (@INST, @DEV, @TEST)
# @TEST_DEP: grep, awk, find
# @TEST_TARGETS: installer/steps/*.sh, installer/libs/*.sh, scripts/*.sh, tests/*.sh
# @TEST_EXIT: 0=todas as tags válidas, 1=inconsistências encontradas

set -euo pipefail

INSTALLER_DIR="config-overrides/config/includes.chroot/usr/local/lib/installer"
SCRIPTS_DIR="scripts"
TESTS_DIR="tests"
EXIT_CODE=0

# Cores
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
BOLD="\033[1m"
RESET="\033[0m"

# Contadores
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

log_err() {
	echo -e "${RED}[FAIL]${RESET} $1"
	EXIT_CODE=1
	FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

log_ok() {
	echo -e "${GREEN}[PASS]${RESET} $1"
	PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

log_warn() {
	echo -e "${YELLOW}[WARN]${RESET} $1"
	WARNINGS=$((WARNINGS + 1))
}

log_info() {
	echo -e "${CYAN}[INFO]${RESET} $1"
}

header() {
	echo ""
	echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
	echo -e "${BOLD}${CYAN}  $1${RESET}"
	echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
}

subheader() {
	echo ""
	echo -e "${BOLD}── $1 ──${RESET}"
}

# ============================================================================
# VALIDAÇÃO: INSTALADOR STEPS (@INST_STEP_*)
# ============================================================================
validate_installer_steps() {
	header "VALIDAÇÃO: INSTALADOR STEPS"

	[[ ! -d "$INSTALLER_DIR/steps" ]] && {
		log_warn "Diretório de steps não encontrado: $INSTALLER_DIR/steps"
		return
	}

	local all_ids=""

	# Primeiro passo: coletar todos os IDs
	for f in "$INSTALLER_DIR"/steps/*.sh; do
		[[ -f "$f" ]] || continue
		local id
		id=$(grep -oP '(?<=@INST_STEP_ID: )\S+' "$f" 2>/dev/null || true)
		if [[ -n "$id" ]]; then
			all_ids="$all_ids $id"
		fi
	done

	# Segundo passo: validar cada step
	for f in "$INSTALLER_DIR"/steps/*.sh; do
		[[ -f "$f" ]] || continue
		local base
		base=$(basename "$f")
		TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

		# Verifica @INST_STEP_ID obrigatório
		if ! grep -q "@INST_STEP_ID" "$f"; then
			log_err "$base: Falta tag @INST_STEP_ID obrigatória"
			continue
		fi

		# Verifica @INST_STEP_FLOW obrigatório
		if ! grep -q "@INST_STEP_FLOW" "$f"; then
			log_err "$base: Falta tag @INST_STEP_FLOW obrigatória"
			continue
		fi

		# Valida referências no FLOW
		local flow
		flow=$(grep -oP '(?<=@INST_STEP_FLOW: ).*' "$f" 2>/dev/null || true)
		if [[ -n "$flow" ]]; then
			# Extrai IDs referenciados
			local refs
			refs=$(echo "$flow" | grep -oP '(?<=prev=|next=)[a-zA-Z_|]+' | tr '|' '\n' | sort -u)

			for ref in $refs; do
				if [[ "$ref" != "none" && "$ref" != "-" && -n "$ref" ]]; then
					if ! echo "$all_ids" | grep -qw "$ref"; then
						log_err "$base: Referência a step ID inexistente: '$ref'"
						continue 2
					fi
				fi
			done
		fi

		log_ok "$base: Tags @INST_STEP_* válidas"
	done
}

# ============================================================================
# VALIDAÇÃO: INSTALADOR LIBS (@INST_LIB_*)
# ============================================================================
validate_installer_libs() {
	header "VALIDAÇÃO: INSTALADOR LIBS"

	[[ ! -d "$INSTALLER_DIR/libs" ]] && {
		log_warn "Diretório de libs não encontrado: $INSTALLER_DIR/libs"
		return
	}

	for f in "$INSTALLER_DIR"/libs/*.sh; do
		[[ -f "$f" ]] || continue
		local base
		base=$(basename "$f")
		TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

		# Verifica @INST_LIB_NAME obrigatório para libs
		if ! grep -q "@INST_LIB_NAME" "$f"; then
			log_warn "$base: Recomendado ter @INST_LIB_NAME"
			continue
		fi

		log_ok "$base: Tags @INST_LIB_* presentes"
	done
}

# ============================================================================
# VALIDAÇÃO: SCRIPTS DE DESENVOLVIMENTO (@DEV_*)
# ============================================================================
validate_dev_scripts() {
	header "VALIDAÇÃO: SCRIPTS DE DESENVOLVIMENTO"

	[[ ! -d "$SCRIPTS_DIR" ]] && {
		log_warn "Diretório de scripts não encontrado: $SCRIPTS_DIR"
		return
	}

	while IFS= read -r f; do
		[[ -f "$f" ]] || continue
		local base
		base=$(basename "$f")
		TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

		# Verifica @DEV_SCRIPT obrigatório
		if ! grep -q "@DEV_SCRIPT" "$f"; then
			log_warn "$base: Falta tag @DEV_SCRIPT"
			continue
		fi

		# Verifica @DEV_DESC obrigatório
		if ! grep -q "@DEV_DESC" "$f"; then
			log_warn "$base: Recomendado ter @DEV_DESC"
			continue
		fi

		# Verifica @DEV_CATEGORY obrigatório
		if ! grep -q "@DEV_CATEGORY" "$f"; then
			log_warn "$base: Recomendado ter @DEV_CATEGORY"
			continue
		fi

		log_ok "$base: Tags @DEV_* válidas"
	done < <(find "$SCRIPTS_DIR" -name "*.sh" -type f 2>/dev/null)
}

# ============================================================================
# VALIDAÇÃO: TESTES (@TEST_*)
# ============================================================================
validate_test_scripts() {
	header "VALIDAÇÃO: SCRIPTS DE TESTE"

	[[ ! -d "$TESTS_DIR" ]] && {
		log_warn "Diretório de testes não encontrado: $TESTS_DIR"
		return
	}

	for f in "$TESTS_DIR"/*.sh; do
		[[ -f "$f" ]] || continue
		local base
		base=$(basename "$f")
		TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

		# Verifica @TEST_SCRIPT obrigatório
		if ! grep -q "@TEST_SCRIPT" "$f"; then
			log_warn "$base: Falta tag @TEST_SCRIPT"
			continue
		fi

		# Verifica @TEST_CATEGORY obrigatório
		if ! grep -q "@TEST_CATEGORY" "$f"; then
			log_warn "$base: Recomendado ter @TEST_CATEGORY"
			continue
		fi

		# Verifica @TEST_DESC obrigatório
		if ! grep -q "@TEST_DESC" "$f"; then
			log_warn "$base: Recomendado ter @TEST_DESC"
			continue
		fi

		log_ok "$base: Tags @TEST_* válidas"
	done
}

# ============================================================================
# VALIDAÇÃO: SINTAXE DOS SCRIPTS
# ============================================================================
validate_syntax() {
	header "VALIDAÇÃO: SINTAXE BASH"

	local dirs=("$INSTALLER_DIR/libs" "$INSTALLER_DIR/steps" "$SCRIPTS_DIR" "$TESTS_DIR")

	for dir in "${dirs[@]}"; do
		[[ -d "$dir" ]] || continue

		while IFS= read -r f; do
			[[ -f "$f" ]] || continue
			local base
			base=$(basename "$f")
			TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

			if bash -n "$f" 2>/dev/null; then
				log_ok "$base: Sintaxe válida"
			else
				log_err "$base: Erro de sintaxe Bash"
			fi
		done < <(find "$dir" -name "*.sh" -type f 2>/dev/null)
	done
}

# ============================================================================
# SUMÁRIO
# ============================================================================
print_summary() {
	header "SUMÁRIO"

	echo ""
	echo -e "  ${BOLD}Total de verificações:${RESET}  $TOTAL_CHECKS"
	echo -e "  ${GREEN}Passou:${RESET}                 $PASSED_CHECKS"
	echo -e "  ${RED}Falhou:${RESET}                 $FAILED_CHECKS"
	echo -e "  ${YELLOW}Avisos:${RESET}                 $WARNINGS"
	echo ""

	if [[ $EXIT_CODE -eq 0 ]]; then
		echo -e "${GREEN}${BOLD}✓ Todas as validações passaram!${RESET}"
	else
		echo -e "${RED}${BOLD}✗ Encontradas inconsistências na documentação.${RESET}"
	fi

	echo ""
}

# ============================================================================
# MAIN
# ============================================================================
main() {
	echo ""
	echo -e "${BOLD}Iniciando validação da documentação embarcada...${RESET}"

	validate_installer_steps
	validate_installer_libs
	validate_dev_scripts
	validate_test_scripts

	# Validação de sintaxe opcional (comentar se muito lento)
	# validate_syntax

	print_summary

	exit $EXIT_CODE
}

main "$@"
