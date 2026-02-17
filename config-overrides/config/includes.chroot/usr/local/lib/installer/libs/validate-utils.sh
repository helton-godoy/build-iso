#!/usr/bin/env bash
# @INST_LIB_NAME: validate-utils
# @INST_DESC: Funções de validação de dados (IP, Hostname, Regex) para pre-flight.

set -euo pipefail

validate_all_checkpoint() {
	# Stub de validação. Implementar lógica real conforme necessidade.
	# Retorna 0 se tudo ok, 1 se falha.
	# Pode verificar se variáveis de estado essenciais estão definidas.

	local pool
	pool="$(state_kv_get zfs_pool_name 2>/dev/null || true)"
	if [[ -z "$pool" ]]; then
		return 0 # Permite passar se ainda não configurado, ou 1 se for checkpoint final
	fi
	return 0
}

validate_disk_selection() {
	local disk="$1"
	if [[ ! -b "$disk" ]]; then
		return 1
	fi
	return 0
}
