#!/usr/bin/env bash
#
# install-manager.sh - Orquestrador principal do DEBIAN_ZFS Installer
# Modularized to orchestrate all installation components
# Uses: lib/logging.sh, lib/validation.sh
#

set -euo pipefail

# =============================================================================
# VARIÁVEIS GLOBAIS
# =============================================================================

# Importar bibliotecas
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
#LIB_DIR="/usr/local/lib"
export LIB_DIR

# Diretório do script (para carregar componentes)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/validation.sh"

readonly COLOR_PRIMARY="\033[0;34m"
readonly COLOR_SECONDARY="\033[0;35m"

section_header() {
	echo ""
	echo "─── $1 ──────────────────────────────────────────────────────────"
}

# Variáveis globais para componentes
declare PROFILE="${PROFILE:-Server}"
declare POOL_NAME="zroot"
declare MOUNT_POINT="${MOUNT_POINT:-/mnt/target}"
declare RAID_TOPOLOGY=""
declare ASHIFT=12
declare COMPRESSION="zstd"
declare CHECKSUM="on"
declare COPIES=1
declare HDSIZE=""
declare ENCRYPTION="off"
declare ENCRYPTION_PASSPHRASE=""

# Variáveis de usuário (serão populados)
declare HOSTNAME=""
declare USERNAME=""
declare ROOT_PASS=""
declare USER_PASS=""

# Lista de componentes em ordem de execução
declare -a COMPONENTS=(
	"components/01-validate.sh"
	"components/02-partition.sh"
	"components/03-pool.sh"
	"components/04-datasets.sh"
	"components/05-extract.sh"
	"components/06-chroot-configure.sh"
	"components/07-bootloader.sh"
	"components/08-cleanup.sh"
)

# =============================================================================
# FUNÇÕES DE INTERFACE DO USUÁRIO
# =============================================================================

# Screen de boas-vindas com DEBIAN_ZFS
welcome_screen() {
	local gum_path="${LIB_DIR}/../gum/gum"

	if [[ ! -f "${gum_path}" ]]; then
		log_warn "GUM não encontrado em ${gum_path}, usando echo..."
		cat <<'EOF'
╔════════════════════════════════════════════════════╗
║                                                    ║
║      🌌 DEBIAN_ZFS - Instalador Oficial             ║
║                                                    ║
║      Debian + ZFS-on-Root + ZFSBootMenu            ║
║                                                    ║
║      Versão: 1.0 (Modularizado)                    ║
║                                                    ║
╚════════════════════════════════════════════════════╝

Este assistente irá guiá-lo através da instalação do Debian com
**ZFS-on-Root** e **ZFSBootMenu**.

⚠️  Aviso: Este processo é DESTRUTIVO para os discos selecionados.

EOF
	else
		"${gum_path}" gum format \
			--foreground "${COLOR_PRIMARY}" \
			--align center \
			--margin "0 2" \
			-- "
	🌌 DEBIAN_ZFS
	
	Instalador Oficial

	Debian + ZFS-on-Root + ZFSBootMenu

	Versão 1.0 (Modularizado)" \
			--foreground "${COLOR_SECONDARY}" \
			--align center \
			--margin "1 2" \
			-- "Este assistente irá guiá-lo através da instalação do Debian com
	**ZFS-on-Root** e **ZFSBootMenu**.

	⚠️  Aviso: Este processo é DESTRUTIVO para os discos selecionados." \
			--align center \
			--margin "1 2" \
			--height 10
	fi

	if ! "${gum_path}" gum confirm \
		--prompt "Deseja iniciar a jornada de instalação?" \
		--default yes; then
		log_info "Instalação cancelada pelo usuário"
		exit 0
	fi

	log_info "Iniciando instalação DEBIAN_ZFS..."
}

# Selecionar disco(s)
select_disks() {
	local disks
	section_header "Seleção de Discos"

	# Listar discos disponíveis
	disks=$(lsblk -d -n -o NAME,SIZE,MODEL -e 7,11 |
		awk '{printf "/dev/%s (%s - %s)\\n", $1, $2, substr($0, index($0,$3))}')

	if [[ -z "${disks}" ]]; then
		log_error "Nenhum disco adequado encontrado"
		gum format -- "> ⚠️ Erro Crítico" \
			--margin "1 2" \
			-- "Nenhum disco adequado para instalação foi encontrado pelo lsblk." \
			--align center \
			--width 70
		exit 1
	fi

	# Seleção com checkbox via gum (múltiplos discos podem ser selecionados)
	local raw_selection

	local selected_prefix
	selected_prefix="[$(gum style --foreground "${COLOR_SUCCESS}" "X")] "

	if ! raw_selection=$(echo -n "${disks}" | "${gum_path}" gum choose \
		--header "Selecione o(s) disco(s) (ESPAÇO para marcar, ENTER para confirmar):" \
		--no-limit \
		--cursor="> " \
		--selected-prefix="${selected_prefix}" \
		--unselected-prefix="[ ] " \
		--cursor-prefix="[ ] " \
		--selected.foreground=""); then
		log_error "Seleção de discos cancelada pelo usuário"
		exit 0
	fi

	# Processar cada linha selecionada
	declare -a selected_disks=()
	while IFS= read -r sel; do
		[[ -z "${sel}" ]] && continue

		log_info "Processando linha: '${sel}'"

		# Extrair caminho do dispositivo de forma robusta
		local dev
		dev=$(echo "${sel}" | grep -oE '/dev/[a-z0-9]+(/[a-z0-9/]+|n)[0-9]+' | head -n 1)

		if [[ -n "${dev}" ]] && [[ -b "${dev}" ]]; then
			selected_disks+=("${dev}")
			gum format -- "✓ Selecionado: **${dev}**"
			log_info "Dispositivo extraído com sucesso: ${dev}"
		else
			log_warn "Falha ao extrair dispositivo válido de: '${sel}'"
		fi
	done <<<"${raw_selection}"

	if [[ ${#selected_disks[@]} -eq 0 ]]; then
		log_error "Não foi possível identificar dispositivos válidos na sua seleção"
		exit 1
	fi

	# Validar discos selecionados
	for disk in "${selected_disks[@]}"; do
		if [[ ! -b "${disk}" ]]; then
			log_error "Dispositivo inválido: ${disk}"
			exit 1
		fi

		# Verificar tamanho mínimo (20GB)
		local size_gb
		size_gb=$(lsblk -b -o SIZE -n -d "${disk}" | awk '{printf "%.0f", $1/1024/1024/1024}')

		if ((size_gb < 20)); then
			log_warn "Disco ${disk} muito pequeno: ${size_gb}GB < 20GB mínimo"
			gum format -- "> ⚠️ Aviso" \
				-- "Disco ${disk} é muito pequeno: ${size_gb}GB." \
				-- "Recomendado mínimo: 20GB" \
				-- "Continuar mesmo assim?" \
				--default yes || {
				log_info "Instalação cancelada: disco muito pequeno"
				exit 1
			}
		fi
	done

	# Confirmar destruição
	gum format -- "⚠️ ALERTA DE SEGURANÇA" \
		--margin "1 2" \
		-- "TODOS OS DADOS nos discos selecionados serão APAGADOS permanentemente." \
		-- "" \
		-- "Discos: **${selected_disks[*]}**" \
		-- "" \
		--align center \
		--width 70

	if ! "${gum_path}" gum confirm \
		--prompt "Tem certeza absoluta que deseja prosseguir?" \
		--default no; then
		log_info "Instalação cancelada pelo usuário"
		exit 0
	fi

	log_info "Discos selecionados: ${selected_disks[*]}"

	# Exportar variáveis globais para uso dos componentes
	SELECTED_DISKS=("${selected_disks[@]}")
	export SELECTED_DISKS
}

# Coletar informações do sistema (hostname, usuários, etc)
collect_system_info() {
	section_header "Identidade do Sistema"

	# Hostname
	HOSTNAME=$("${gum_path}" gum input \
		--prompt " 🏷️  Hostname: " \
		--placeholder "Ex: DEBIAN_ZFS" --value "DEBIAN_ZFS")

	if [[ -z "${HOSTNAME}" ]]; then
		log_error "Hostname não pode ser vazio"
		exit 1
	fi

	# Perfil de instalação
	PROFILE=$("${gum_path}" gum choose \
		--header "Selecione o perfil de instalação:" \
		--selected "Server" \
		"Server" "Workstation" \
		"Minimal")

	log_info "Perfil selecionado: ${PROFILE}"

	# Senhas
	ROOT_PASS=$("${gum_path}" gum input \
		--prompt " 🛡️  Senha (root): " \
		--password)

	USERNAME=$("${gum_path}" gum input \
		--prompt " 👤 Usuário: " \
		--placeholder "Ex: admin" --value "admin")

	USER_PASS=$("${gum_path}" gum input \
		--prompt " 🔑 Senha (${USERNAME}): " \
		--password)

	# Validações básicas
	if [[ -z "${ROOT_PASS}" ]]; then
		log_error "Senha do root não pode ser vazia"
		exit 1
	fi

	if [[ ${#ROOT_PASS} -lt 6 ]]; then
		log_error "Senha do root muito curta (mínimo 6 caracteres)"
		exit 1
	fi

	if [[ -z "${USER_PASS}" ]]; then
		log_error "Senha do usuário não pode ser vazia"
		exit 1
	fi

	if [[ ${#USER_PASS} -lt 6 ]]; then
		log_error "Senha do usuário muito curta (mínimo 6 caracteres)"
		exit 1
	fi

	log_info "Informações do sistema coletadas"
}

# Opções ZFS avançadas (opcional - podem ser padronizados)
collect_zfs_options() {
	section_header "Configurações ZFS Avançadas (Opcional)"

	ASHIFT=$("${gum_path}" gum choose \
		--header "Selecione ashift (tamanho do setor):" \
		--selected "12" \
		"9" "12" "13" "14" \
		--selected "12" || echo "12")
	COMPRESSION=$("${gum_path}" gum choose \
		--header "Selecione compressão:" \
		--selected "zstd" \
		"off" "lz4" "zstd" "gzip" \
		--selected "zstd" || echo "zstd")
	CHECKSUM=$("${gum_path}" gum choose \
		--header "Selecione checksum:" \
		--selected "on" \
		"on" "off" "sha256" "sha512" \
		--selected "on" || echo "on")
	COPIES=$("${gum_path}" gum choose \
		--header "Selecione cópias (redundância):" \
		--selected "1" \
		"1" "2" "3" \
		--selected "1" || echo "1")
	# Opções de criptografia (só se disponível no kernel)
	if [[ -f "/proc/crypto" ]]; then
		ENCRYPTION=$("${gum_path}" gum choose \
			--header "Deseja habilitar criptografia nativa ZFS?" \
			--selected "off" \
			"on" "off" \
			--selected "off" || echo "off")

		if [[ "${ENCRYPTION}" == "on" ]]; then
			ENCRYPTION_PASSPHRASE=$("${gum_path}" gum input \
				--password --prompt "Digite a passphrase do pool ZFS:" \
				--placeholder "Passphrase")

			local confirm_pass
			confirm_pass=$("${gum_path}" gum input \
				--password --prompt "Confirme a passphrase:" \
				--placeholder "Passphrase")

			if [[ "${ENCRYPTION_PASSPHRASE}" != "${confirm_pass}" ]]; then
				log_error "As passphrases não coincidem"
				return 1
			fi

			if [[ ${#ENCRYPTION_PASSPHRASE} -lt 8 ]]; then
				log_error "Passphrase muito curta (mínimo 8 caracteres)"
				return 1
			fi
		fi
	fi

	# Tamanho máximo do disco (opcional)
	HDSIZE=$("${gum_path}" gum input \
		--prompt "Limite de tamanho do disco em GB (opcional, pressione Enter para ignorar):" \
		--placeholder "")
	if [[ -n "${HDSIZE}" ]]; then
		log_info "Usando tamanho total de disco para cada disco"
	else
		log_info "Usando tamanho limitado: ${HDSIZE}GB por disco"
	fi

	log_info "Configurações ZFS: ashift=${ASHIFT}, compression=${COMPRESSION}, checksum=${CHECKSUM}, copies=${COPIES}${HDSIZE:+, hdsize=${HDSIZE}}"
}

# Selecionar topologia RAID (apenas se múltiplos discos)
select_topology() {
	local num_disks=${#selected_disks[@]}
	local options=()

	case ${num_disks} in
	1)
		options=("Single")
		;;
	2)
		options=("Mirror" "Stripe")
		;;
	3)
		options=("Mirror" "RAIDZ1" "Stripe")
		;;
	4)
		options=("Mirror" "RAIDZ1" "RAIDZ2" "Stripe")
		;;
	*)
		options=("Mirror" "RAIDZ1" "RAIDZ2" "RAIDZ3" "Stripe")
		;;
	esac

	RAID_TOPOLOGY=$("${gum_path}" gum choose \
		--header "Selecione a topologia RAID:" \
		"${options[@]}" \
		--selected "Mirror" || echo "Mirror")

	log_info "Topologia selecionada: ${RAID_TOPOLOGY}"
}

# Resumo final antes de iniciar
show_installation_summary() {
	local gum_path="${LIB_DIR}/../gum/gum"

	local summary_text
	summary_text="$(
		cat <<EOF
$(gum style --foreground "${COLOR_SECONDARY}" --bold "🌍 GERAL")
 • Discos:     ${SELECTED_DISKS[*]}
 • Topologia:  ${RAID_TOPOLOGY}
 • Hostname:   ${HOSTNAME}
 • Perfil:     ${PROFILE}
 • Usuário:    ${USERNAME}

$(gum style --foreground "${COLOR_SECONDARY}" --bold "⚡ ZFS")
 • Pool:       ${POOL_NAME}
 • ashift:     ${ASHIFT}
 • compress:   ${COMPRESSION}
 • checksum:   ${CHECKSUM}
 • copies:     ${COPIES}
 • Crypto:     ${ENCRYPTION}
EOF
	)"

	"${gum_path}" gum format \
		--width 70 \
		--align left \
		"📋 RESUMO DA INSTALAÇÃO" "" \
		"${summary_text}"

	if ! "${gum_path}" gum confirm \
		--prompt "As configurações estão corretas? Iniciar instalação?" \
		--default yes; then
		log_info "Instalação cancelada pelo usuário"
		exit 0
	fi
}

# =============================================================================
# EXECUÇÃO SEQUENCIAL DOS COMPONENTES
# =============================================================================

# Executar componentes em ordem
execute_components() {
	log_section "=== Iniciando Instalação Sequencial ==="

	local failed=0

	# 1. Validações
	log_step "Fase 1: Validações..."
	if ! source "${SCRIPT_DIR}/components/01-validate.sh"; then
		log_error "Falha no componente 01-validate.sh"
		failed=1
	fi

	# 2. Particionamento
	log_step "Fase 2: Particionamento..."
	if ! source "${SCRIPT_DIR}/components/02-partition.sh"; then
		log_error "Falha no componente 02-partition.sh"
		failed=1
	fi

	# 3. Pool ZFS
	log_step "Fase 3: Criando Pool ZFS..."
	if ! source "${SCRIPT_DIR}/components/03-pool.sh"; then
		log_error "Falha no componente 03-pool.sh"
		failed=1
	fi

	# 4. Datasets ZFS
	log_step "Fase 4: Criando Datasets..."
	if ! source "${SCRIPT_DIR}/components/04-datasets.sh"; then
		log_error "Falha no componente 04-datasets.sh"
		failed=1
	fi

	# 5. Extração do sistema
	log_step "Fase 5: Extraindo Sistema..."
	if ! source "${SCRIPT_DIR}/components/05-extract.sh"; then
		log_error "Falha no componente 05-extract.sh"
		failed=1
	fi

	# 6. Configurações em chroot
	log_step "Fase 6: Configurando Sistema..."
	if ! source "${SCRIPT_DIR}/components/06-chroot-configure.sh"; then
		log_error "Falha no componente 06-chroot-configure.sh"
		failed=1
	fi

	# 7. Bootloaders (ZFSBootMenu + Syslinux/EFI)
	log_step "Fase 7: Instalando Bootloaders..."
	if ! source "${SCRIPT_DIR}/components/07-bootloader.sh"; then
		log_error "Falha no componente 07-bootloader.sh"
		failed=1
	fi

	# 8. Limpeza final
	log_step "Fase 8: Limpeza Final..."
	if ! source "${SCRIPT_DIR}/components/08-cleanup.sh"; then
		log_error "Falha no componente 08-cleanup.sh"
		failed=1
	fi

	# Verificar se tudo ocorreu com sucesso
	if [[ ${failed} -eq 0 ]]; then
		log_success "=== Instalação concluída com sucesso ==="
		log_info "Sistema pronto para reboot"
		gum format -- "🎉 Instalação DEBIAN_ZFS concluída!"
		return 0
	else
		log_error "=== Falhas detectadas na instalação ==="
		gum format -- "❌ Instalação falhou"
		gum format -- " o log em ${LOG_FILE}"
		return 1
	fi
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
	# Verificar se está rodando como root
	if [[ ${EUID} -ne 0 ]]; then
		gum format -- " Erro: Este script precisa ser executado como root." \
			--align center \
			--width 70
		exit 1
	fi

	# Verificar módulo ZFS
	if [[ ! -d /sys/module/zfs ]] && ! grep -qw "^zfs " /proc/modules; then
		gum format -- " Erro: Módulo ZFS não carregado." \
			--align center \
			--width 70
		exit 1
	fi

	# Carregar gum
	local gum_path="${LIB_DIR}/../gum/gum"
	if [[ ! -f "${gum_path}" ]]; then
		gum format -- " Erro: GUM não encontrado em ${gum_path}." \
			--align center \
			--width 70
		exit 1
	fi

	# Inicializar logging
	log_init

	# Exibir tela de boas-vindas
	welcome_screen

	# Selecionar disco(s)
	select_disks

	# Coletar informações do sistema
	collect_system_info

	# Opções ZFS avançadas (opcional)
	collect_zfs_options

	# Selecionar topologia RAID (se aplicável)
	if [[ ${#SELECTED_DISKS[@]} -gt 1 ]]; then
		select_topology
	fi

	# Resumo antes de iniciar
	show_installation_summary

	# Executar todos componentes sequencialmente
	if ! execute_components; then
		log_error "Instalação falhou"
		exit 1
	fi

	# Tudo concluido
	gum format \
		--align center \
		--margin "2 2" \
		--height 8 \
		-- "
	🎉 Instalacao DEBIAN_ZFS concluida com sucesso!
	Sistema pronto para reinicializar.
	Pressione ENTER para reiniciar.
	"

	log_info "Instalacao concluida com sucesso"
	sync
	log_info "Aguardando log em \${LOG_FILE}"

	exit 0
}

# Executar main se script for executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
