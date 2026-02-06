#!/usr/bin/env bash
#
# firmware-detection.sh - Detecção de modo de boot (UEFI/BIOS)
#

set -euo pipefail

# Variáveis globais exportadas
FIRMWARE_MODE=""
IS_EFI=false

# ============================================================================
# FUNÇÕES PÚBLICAS
# ============================================================================

# Detecta se o sistema está rodando em modo UEFI ou BIOS Legacy
# Retorna: Define FIRMWARE_MODE="UEFI" ou "BIOS", IS_EFI=true/false
firmware_detect() {
	if [[ -d /sys/firmware/efi ]] && [[ -n "$(ls -A /sys/firmware/efi 2>/dev/null)" ]]; then
		FIRMWARE_MODE="UEFI"
		IS_EFI=true
	else
		FIRMWARE_MODE="BIOS"
		IS_EFI=false
	fi
}

# Retorna o modo de boot detectado
# Output: "UEFI" ou "BIOS"
firmware_get_mode() {
	if [[ -z "$FIRMWARE_MODE" ]]; then
		firmware_detect
	fi
	echo "$FIRMWARE_MODE"
}

# Verifica se está em modo EFI
# Output: "true" ou "false"
firmware_is_efi() {
	if [[ -z "$FIRMWARE_MODE" ]]; then
		firmware_detect
	fi
	if [[ "$IS_EFI" == true ]]; then
		echo "true"
	else
		echo "false"
	fi
}

# Exibe informações detalhadas sobre o firmware
firmware_info() {
	if [[ -z "$FIRMWARE_MODE" ]]; then
		firmware_detect
	fi

	echo "Modo de Boot: $FIRMWARE_MODE"

	if [[ "$IS_EFI" == true ]]; then
		if [[ -d /sys/firmware/efi/efivars ]]; then
			echo "EFIVars disponíveis: Sim"
		else
			echo "EFIVars disponíveis: Não"
		fi

		if command -v efibootmgr &>/dev/null; then
			echo "efibootmgr disponível: Sim"
		else
			echo "efibootmgr disponível: Não"
		fi
	fi
}

# ============================================================================
# TESTE UNITÁRIO (quando executado diretamente)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "
	=== Teste de Detecção de Firmware ===
	
	"

	firmware_detect

	echo "
	Modo detectado: $(firmware_get_mode)
	É EFI: $(firmware_is_efi)
	
	=== Informações Detalhadas ===
	"
	firmware_info
fi
