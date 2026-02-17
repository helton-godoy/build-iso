#!/usr/bin/env bash
# @INST_FILE: ui-validation.sh
# @INST_LIB_NAME: ui-validation
# @INST_DESC: Funções de validação para entrada de dados do usuário no instalador.
# @INST_DEP: bash>=4.0

set -euo pipefail

# ═══════════════════════════════════════════════════════════
# FUNÇÕES DE VALIDAÇÃO
# ═══════════════════════════════════════════════════════════
# Retorno: 0 = válido, 1 = inválido
# Mensagens de erro via stderr

# @INST_FUNC: validate_hostname
# @INST_DESC: Valida hostname conforme RFC 1123.
# @INST_ARGS: $1 = hostname
# @INST_RETURN: 0 se válido, 1 se inválido
validate_hostname() {
	local hostname="$1"

	# Hostname vazio é inválido
	if [[ -z "$hostname" ]]; then
		echo "Erro: Hostname não pode ser vazio." >&2
		return 1
	fi

	# RFC 1123: máximo 253 caracteres
	if [[ "${#hostname}" -gt 253 ]]; then
		echo "Erro: Hostname muito longo (máximo 253 caracteres)." >&2
		return 1
	fi

	# RFC 1123: apenas letras (a-z, A-Z), números (0-9) e hífen (-)
	# Não pode começar ou terminar com hífen
	# Cada label (entre pontos) pode ter até 63 caracteres
	if ! echo "$hostname" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'; then
		echo "Erro: Hostname inválido. Use apenas letras, números e hífen." >&2
		echo "       Não pode começar ou terminar com hífen." >&2
		return 1
	fi

	return 0
}

# @INST_FUNC: validate_domain
# @INST_DESC: Valida FQDN (Fully Qualified Domain Name).
# @INST_ARGS: $1 = domain
# @INST_RETURN: 0 se válido, 1 se inválido
validate_domain() {
	local domain="$1"

	# Domínio vazio é permitido (opcional)
	if [[ -z "$domain" ]]; then
		return 0
	fi

	# FQDN: máximo 253 caracteres
	if [[ "${#domain}" -gt 253 ]]; then
		echo "Erro: Domínio muito longo (máximo 253 caracteres)." >&2
		return 1
	fi

	# FQDN: deve ter pelo menos um ponto e um TLD válido
	if ! echo "$domain" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'; then
		echo "Erro: Domínio inválido. Formato esperado: exemplo.com" >&2
		return 1
	fi

	return 0
}

# @INST_FUNC: validate_username
# @INST_DESC: Valida nome de usuário do sistema UNIX.
# @INST_ARGS: $1 = username
# @INST_RETURN: 0 se válido, 1 se inválido
validate_username() {
	local username="$1"

	# Username vazio é inválido
	if [[ -z "$username" ]]; then
		echo "Erro: Nome de usuário não pode ser vazio." >&2
		return 1
	fi

	# UNIX username: máximo 32 caracteres
	if [[ "${#username}" -gt 32 ]]; then
		echo "Erro: Nome de usuário muito longo (máximo 32 caracteres)." >&2
		return 1
	fi

	# UNIX username: deve começar com letra minúscula
	# Pode conter letras minúsculas, números, hífen e underscore
	# Não pode terminar com hífen
	if ! echo "$username" | grep -qE '^[a-z][a-z0-9_-]{0,30}[a-z0-9]?$'; then
		echo "Erro: Nome de usuário inválido." >&2
		echo "       Deve começar com letra minúscula e usar apenas:" >&2
		echo "       letras minúsculas, números, hífen e underscore." >&2
		return 1
	fi

	# Usernames reservados
	local reserved_users=(
		"root" "daemon" "bin" "sys" "sync" "games" "man" "lp"
		"mail" "news" "uucp" "proxy" "www-data" "backup" "list"
		"irc" "gnats" "nobody" "systemd-network" "systemd-resolve"
		"messagebus" "systemd-timesync" "syslog" "uuidd"
	)

	local reserved
	for reserved in "${reserved_users[@]}"; do
		if [[ "$username" == "$reserved" ]]; then
			echo "Erro: Nome de usuário '$username' é reservado pelo sistema." >&2
			return 1
		fi
	done

	return 0
}

# @INST_FUNC: validate_ip
# @INST_DESC: Valida endereço IPv4 ou IPv6.
# @INST_ARGS: $1 = ip_address
# @INST_RETURN: 0 se válido, 1 se inválido
validate_ip() {
	local ip="$1"

	# IP vazio é inválido
	if [[ -z "$ip" ]]; then
		echo "Erro: Endereço IP não pode ser vazio." >&2
		return 1
	fi

	# Valida IPv4
	if echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
		local -a octets
		IFS='.' read -r -a octets <<<"$ip"

		local octet
		for octet in "${octets[@]}"; do
			# Remove zeros à esquerda para validar numericamente
			octet=$((10#$octet))
			if ((octet < 0 || octet > 255)); then
				echo "Erro: Endereço IPv4 inválido. Octeto fora do intervalo (0-255)." >&2
				return 1
			fi
		done

		return 0
	fi

	# Valida IPv6 (simplificado - aceita formato completo e comprimido)
	if echo "$ip" | grep -qiE '^([0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}$'; then
		# Validação básica de IPv6
		# Aceita formatos como: 2001:db8::1, ::1, fe80::1
		return 0
	fi

	# IPv6 com compressão dupla
	if echo "$ip" | grep -qiE '^::([0-9a-f]{0,4}:){0,6}[0-9a-f]{0,4}$'; then
		return 0
	fi

	# IPv6 com compressão no meio
	if echo "$ip" | grep -qiE '^([0-9a-f]{0,4}:){1,6}:([0-9a-f]{0,4}:){0,5}[0-9a-f]{0,4}$'; then
		return 0
	fi

	echo "Erro: Endereço IP inválido. Use formato IPv4 ou IPv6." >&2
	return 1
}

# @INST_FUNC: validate_timezone
# @INST_DESC: Valida timezone do sistema.
# @INST_ARGS: $1 = timezone (ex: America/Sao_Paulo)
# @INST_RETURN: 0 se válido, 1 se inválido
validate_timezone() {
	local timezone="$1"

	# Timezone vazio é inválido
	if [[ -z "$timezone" ]]; then
		echo "Erro: Timezone não pode ser vazio." >&2
		return 1
	fi

	# Verifica se o timezone existe no sistema
	# Diretório padrão de timezones: /usr/share/zoneinfo/
	local timezone_path="/usr/share/zoneinfo/$timezone"

	if [[ ! -f "$timezone_path" ]]; then
		echo "Erro: Timezone '$timezone' não encontrado." >&2
		echo "       Verifique /usr/share/zoneinfo/ para opções válidas." >&2
		return 1
	fi

	# Valida formato (Continente/Cidade ou Continente/Região/Cidade)
	if ! echo "$timezone" | grep -qE '^[A-Z][a-zA-Z]+(/[A-Z][a-zA-Z_+-]+){1,2}$'; then
		echo "Erro: Formato de timezone inválido." >&2
		echo "       Formato esperado: Continente/Cidade (ex: America/Sao_Paulo)" >&2
		return 1
	fi

	return 0
}

# @INST_FUNC: validate_disk_path
# @INST_DESC: Valida caminho de dispositivo de disco.
# @INST_ARGS: $1 = disk_path (ex: /dev/sda)
# @INST_RETURN: 0 se válido, 1 se inválido
validate_disk_path() {
	local disk_path="$1"

	# Disk path vazio é inválido
	if [[ -z "$disk_path" ]]; then
		echo "Erro: Caminho do disco não pode ser vazio." >&2
		return 1
	fi

	# Deve começar com /dev/
	if ! echo "$disk_path" | grep -qE '^/dev/'; then
		echo "Erro: Caminho do disco deve começar com /dev/" >&2
		return 1
	fi

	# Verifica se é um dispositivo de bloco
	if [[ ! -b "$disk_path" ]]; then
		echo "Erro: '$disk_path' não é um dispositivo de bloco válido." >&2
		return 1
	fi

	# Verifica se não é uma partição (simplificado)
	# Partições geralmente terminam com números (ex: /dev/sda1)
	# mas alguns discos NVMe usam formato /dev/nvme0n1p1
	if echo "$disk_path" | grep -qE '(p[0-9]+|[0-9]+)$'; then
		echo "Aviso: '$disk_path' parece ser uma partição, não um disco." >&2
		echo "       Deseja continuar? (Normalmente espera-se um disco inteiro)" >&2
		# Não retorna erro, apenas aviso - deixa a decisão para o usuário
	fi

	return 0
}
