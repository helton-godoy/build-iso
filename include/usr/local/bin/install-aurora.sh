#!/usr/bin/env bash
#
# install-aurora.sh - Instalador Aurora OS (Debian + ZFS-on-Root + ZFSBootMenu)
# Versão: 1.0
# Desenvolvido para Aurora OS
#

set -euo pipefail

# =============================================================================
# CONFIGURAÇÕES GLOBAIS
# =============================================================================

readonly SCRIPT_NAME="Aurora OS Installer"
readonly SCRIPT_VERSION="1.0"
readonly POOL_NAME="zroot"
readonly ZBM_BIN_DIR="/usr/share/zfsbootmenu"
readonly MOUNT_POINT="/mnt/target"
readonly LOG_FILE="/var/log/aurora-installer.log"

# Variáveis globais (serão populadas durante a execução)
declare -a SELECTED_DISKS=()
declare RAID_TOPOLOGY=""
declare ASHIFT=12
declare COMPRESSION="zstd"
declare CHECKSUM="on"
declare COPIES=1
declare HDSIZE=""
declare SQUASHFS_PATH=""
declare ENCRYPTION="off"
declare ENCRYPTION_PASSPHRASE=""
declare PROFILE="Server"

# --- Sistema de Design Aurora ---
readonly COLOR_PRIMARY="#5f5faf"   # Roxo Aurora
readonly COLOR_SECONDARY="#00afaf" # Ciano
readonly COLOR_SUCCESS="#00af00"   # Verde
readonly COLOR_ERROR="#af0000"     # Vermelho
readonly COLOR_WARNING="#ffaf00"   # Laranja
readonly COLOR_INFO="#5fafff"      # Azul Claro
readonly COLOR_BORDER="#afafff"    # Borda Suave
readonly UI_WIDTH=70

# =============================================================================
# MÓDULO: UTILITÁRIOS DE INTERFACE
# =============================================================================

# Renderizar uma caixa estilizada
# Uso: styled_box "Título" "Mensagem" [cor_borda]
styled_box() {
	local title="$1"
	local msg="$2"
	local color="${3:-$COLOR_PRIMARY}"

	clear
	gum style \
		--border rounded \
		--border-foreground "$color" \
		--padding "1 2" \
		--margin "1 1" \
		--width "$UI_WIDTH" \
		"$(gum style --foreground "$color" --bold "$title")\n\n$msg"
}

# Renderizar um cabeçalho de seção
# Uso: section_header "Título da Seção"
section_header() {
	gum style \
		--foreground "$COLOR_PRIMARY" \
		--bold \
		--margin "1 0 0 0" \
		"─── $1 ──────────────────────────────────────────────────────────" | cut -c1-"$UI_WIDTH"
}

# =============================================================================
# MÓDULO: LOGGING
# =============================================================================

# Log de informações
# Uso: log "Mensagem de log"
log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >>"$LOG_FILE"
}

# Log de erro e saída
# Uso: error_exit "Mensagem de erro"
error_exit() {
	styled_box "❌ ERRO CRÍTICO" "$*" "$COLOR_ERROR"
	log "ERROR: $*"
	cleanup
	exit 1
}

# =============================================================================
# MÓDULO: CLEANUP
# =============================================================================

# Função de limpeza executada em caso de erro ou interrupção
cleanup() {
	log "Iniciando limpeza..."
	sync

	# Desmontar ESP se estiver montado
	if mountpoint -q "$MOUNT_POINT/boot/efi"; then
		log "Desmontando $MOUNT_POINT/boot/efi"
		umount "$MOUNT_POINT/boot/efi" 2>/dev/null || true
	fi

	# Desmontar sistemas virtuais se estiverem montados
	for dir in dev proc sys run; do
		if mountpoint -q "$MOUNT_POINT/$dir"; then
			log "Desmontando $MOUNT_POINT/$dir"
			umount -l "$MOUNT_POINT/$dir" 2>/dev/null || true
		fi
	done

	# Desmontar root se estiver montado
	if mountpoint -q "$MOUNT_POINT"; then
		log "Desmontando $MOUNT_POINT"
		umount -l "$MOUNT_POINT" 2>/dev/null || true
	fi

	# Exportar pool ZFS se existir
	if zpool list "$POOL_NAME" >/dev/null 2>&1; then
		log "Exportando pool $POOL_NAME"
		zpool export "$POOL_NAME" 2>/dev/null || true
	fi

	log "Limpeza concluída."
}

# Configurar trap para capturar sinais
trap cleanup ERR SIGINT SIGTERM

# =============================================================================
# MÓDULO: PRÉ-REQUISITOS
# =============================================================================

# Verificar se está rodando como root
check_root() {
	if [[ $EUID -ne 0 ]]; then
		error_exit "Este script precisa ser executado como root."
	fi
	log "Verificação de root: OK"
}

# Carregar módulo ZFS
load_zfs_module() {
	# Verificação mais robusta usando /sys/module e /proc/modules
	if [[ ! -d /sys/module/zfs ]] || ! grep -qw "^zfs " /proc/modules; then
		log "Carregando módulo ZFS..."
		sync
		if ! modprobe zfs 2>>"$LOG_FILE"; then
			error_exit "Falha ao carregar o módulo ZFS. Verifique se o ZFS está instalado corretamente."
		fi
		log "Módulo ZFS carregado com sucesso."
	else
		log "Módulo ZFS já está carregado."
	fi
}

# Verificar comandos ZFS
check_zfs_commands() {
	local missing_commands=()

	if ! command -v zpool >/dev/null 2>&1; then
		missing_commands+=("zpool")
	fi

	if ! command -v zfs >/dev/null 2>&1; then
		missing_commands+=("zfs")
	fi

	if [[ ${#missing_commands[@]} -gt 0 ]]; then
		error_exit "Comandos ZFS não encontrados: ${missing_commands[*]}. Pacote zfsutils-linux não instalado?"
	fi

	log "Comandos ZFS verificados: OK"
}

# Testar funcionalidade zpool
test_zpool() {
	if ! zpool version >>"$LOG_FILE" 2>&1; then
		error_exit "Comando zpool não funcionou. Módulo ZFS pode estar corrompido."
	fi
	log "Teste zpool version: OK"
}

# Verificar memória disponível
check_memory() {
	local mem_kb mem_gb mem_mb

	mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	mem_gb=$((mem_kb / 1024 / 1024))
	mem_mb=$((mem_kb / 1024))

	log "Memória detectada: ${mem_mb}MB (${mem_gb}GB)"

	if [[ $mem_gb -lt 2 ]]; then
		gum format -- "> ⚠️ Aviso: Memória baixa detectada (${mem_mb}MB). ZFS recomenda 2GB+."
		log "AVISO: Memória baixa: ${mem_mb}MB"
	fi
}

# Verificar comandos necessários
check_required_commands() {
	local commands=("gum" "wipefs" "sgdisk" "mkfs.vfat" "efibootmgr" "unsquashfs" "rsync")
	local missing=()

	for cmd in "${commands[@]}"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=("$cmd")
		fi
	done

	if [[ ${#missing[@]} -gt 0 ]]; then
		error_exit "Comandos necessários não encontrados: ${missing[*]}"
	fi

	log "Comandos necessários verificados: OK"
}

# Executar todas as verificações de pré-requisitos
preflight_checks() {
	log "Executando verificações de pré-requisitos..."

	check_root
	load_zfs_module
	check_zfs_commands
	test_zpool
	check_memory
	check_required_commands

	log "Verificações de pré-requisitos concluídas."
	sync
}

# =============================================================================
# MÓDULO: INTERFACE TUI
# =============================================================================

welcome_screen() {
	styled_box "🌌 AURORA OS" "Bem-vindo ao instalador oficial do **Aurora OS**.\n\nEste assistente irá guiá-lo através da instalação do Debian com\n**ZFS-on-Root** e **ZFSBootMenu**.\n\n> *Aviso: Este processo é destrutivo para os discos selecionados.*" "$COLOR_PRIMARY"
	gum confirm "Deseja iniciar a jornada de instalação?" || exit 0
}

select_disks() {
	local disks
	section_header "Seleção de Discos"

	disks=$(lsblk -d -n -o NAME,SIZE,MODEL -e 7,11 | awk '{printf "/dev/%s (%s - %s)\n", $1, $2, substr($0, index($0,$3))}')

	local raw_selection
	mapfile -t raw_selection < <(echo "$disks" | gum choose --header "Selecione o(s) disco(s) de destino (Espaço para marcar):" --no-limit)

	if [[ ${#raw_selection[@]} -eq 0 ]]; then
		error_exit "Nenhum disco selecionado."
	fi

	SELECTED_DISKS=()
	for sel in "${raw_selection[@]}"; do
		[[ -z "$sel" ]] && continue
		local dev
		dev=$(echo "$sel" | awk '{print $1}')
		if [[ -n "$dev" ]]; then
			SELECTED_DISKS+=("$dev")
			gum format -- "✓ Selecionado: **$dev**"
		fi
	done

	if [[ ${#SELECTED_DISKS[@]} -eq 0 ]]; then
		error_exit "Falha ao extrair nomes de dispositivos dos discos selecionados."
	fi

	styled_box "⚠️ ALERTA DE SEGURANÇA" "TODOS OS DADOS nos discos selecionados serão APAGADOS permanentEMENTE.\n\nDiscos: **${SELECTED_DISKS[*]}**" "$COLOR_WARNING"
	gum confirm "Tem certeza absoluta que deseja prosseguir?" || exit 0

	log "Discos selecionados: ${SELECTED_DISKS[*]}"
}

collect_info() {
	section_header "Identidade do Sistema"
	HOSTNAME=$(gum input --prompt " 🏷️  Hostname: " --placeholder "Ex: aurora" --value "aurora")
	USERNAME=$(gum input --prompt " 👤 Usuário:  " --placeholder "Ex: admin" --value "admin")

	section_header "Configurações de Segurança"
	USER_PASS=$(gum input --prompt " 🔑 Senha ($USERNAME): " --password --placeholder "Digite a senha do usuário")
	ROOT_PASS=$(gum input --prompt " 🛡️  Senha (root):     " --password --placeholder "Digite a senha do root")

	if [[ -z "$USER_PASS" || -z "$ROOT_PASS" ]]; then
		error_exit "As senhas não podem ser vazias."
	fi

	# Validar comprimento mínimo da senha
	if [[ ${#USER_PASS} -lt 6 ]]; then
		error_exit "A senha do usuário deve ter pelo menos 6 caracteres."
	fi
	if [[ ${#ROOT_PASS} -lt 6 ]]; then
		error_exit "A senha do root deve ter pelo menos 6 caracteres."
	fi

	log "Coletadas informações: hostname=$HOSTNAME, username=$USERNAME"
}

confirm_installation() {
	local disk_list
	disk_list=$(
		IFS=$'\n'
		echo "${SELECTED_DISKS[*]}"
	)

	local summary_text
	summary_text="
$(gum style --foreground "$COLOR_SECONDARY" --bold "🌍 GERAL")
• Discos:     ${SELECTED_DISKS[*]}
• Topologia:  $RAID_TOPOLOGY
• Hostname:   $HOSTNAME
• Usuário:    $USERNAME
• Perfil:     $PROFILE

$(gum style --foreground "$COLOR_SECONDARY" --bold "⚡ ZFS")
• Pool:       $POOL_NAME
• ashift:     $ASHIFT
• compress:   $COMPRESSION
• checksum:   $CHECKSUM
• copies:     $COPIES
• Crypto:     $ENCRYPTION
"

	styled_box "📋 RESUMO DA INSTALAÇÃO" "$summary_text" "$COLOR_INFO"
	gum confirm "As configurações estão corretas? Iniciar instalação?" || exit 0
}

# Selecionar topologia RAID
select_topology() {
	local num_disks=${#SELECTED_DISKS[@]}
	local options=()

	case $num_disks in
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

	RAID_TOPOLOGY=$(echo "${options[@]}" | tr ' ' '\n' | gum choose --header "Selecione a topologia RAID:")
	log "Topologia selecionada: $RAID_TOPOLOGY"
}

# Configurar opções ZFS avançadas
configure_zfs_options() {
	section_header "Configuração ZFS Avançada"

	ASHIFT=$(gum choose --header "Selecione ashift (tamanho do setor):" \
		"9" "12" "13" "14" \
		--selected "12" || echo "12")

	COMPRESSION=$(gum choose --header "Selecione compressão:" \
		"off" "lz4" "zstd" "gzip" \
		--selected "zstd" || echo "zstd")

	CHECKSUM=$(gum choose --header "Selecione checksum:" \
		"on" "off" "sha256" "sha512" \
		--selected "on" || echo "on")

	COPIES=$(gum choose --header "Selecione cópias (redundância):" \
		"1" "2" "3" \
		--selected "1" || echo "1")

	HDSIZE=$(gum input --prompt "Limite de tamanho do disco em GB (opcional, pressione Enter para ignorar):" --placeholder "" || echo "")

	if [[ -n "$HDSIZE" ]]; then
		# Validar que HDSIZE é um número
		if ! [[ "$HDSIZE" =~ ^[0-9]+$ ]]; then
			error_exit "HDSIZE deve ser um número inteiro positivo."
		fi

		gum format -- "> Será usado apenas os primeiros ${HDSIZE}GB de cada disco"
	fi

	# Seleção de Perfil
	PROFILE=$(gum choose --header "Selecione o perfil de instalação:" \
		"Server" "Workstation" \
		--selected "Server" || echo "Server")

	# Configuração de Criptografia
	ENCRYPTION=$(gum choose --header "Deseja habilitar criptografia nativa ZFS?" \
		"off" "on" \
		--selected "off" || echo "off")

	if [[ "$ENCRYPTION" == "on" ]]; then
		ENCRYPTION_PASSPHRASE=$(gum input --password --prompt "Digite a passphrase do pool ZFS:" --placeholder "Passphrase")
		local confirm_pass
		confirm_pass=$(gum input --password --prompt "Confirme a passphrase:" --placeholder "Passphrase")

		if [[ "$ENCRYPTION_PASSPHRASE" != "$confirm_pass" ]]; then
			error_exit "As passphrases não coincidem."
		fi

		if [[ ${#ENCRYPTION_PASSPHRASE} -lt 8 ]]; then
			error_exit "A passphrase de criptografia deve ter pelo menos 8 caracteres."
		fi
	fi

	log "Opções ZFS: ashift=$ASHIFT, compression=$COMPRESSION, checksum=$CHECKSUM, copies=$COPIES${HDSIZE:+, hdsize=$HDSIZE}, encryption=$ENCRYPTION, profile=$PROFILE"
}

# =============================================================================
# MÓDULO: PREPARAÇÃO DO DISCO
# =============================================================================

# Limpar completamente um disco
wipe_disk() {
	local disk=$1

	log "Limpando disco $disk..."

	if ! wipefs -a "$disk" >>"$LOG_FILE" 2>&1; then
		error_exit "Falha ao executar wipefs em $disk"
	fi

	if ! sgdisk --zap-all "$disk" >>"$LOG_FILE" 2>&1; then
		error_exit "Falha ao executar sgdisk --zap-all em $disk"
	fi

	sync
	log "Disco $disk limpo com sucesso"
}

# Determinar sufixo de partição (para /dev/sdX vs /dev/nvme0n1)
get_part_suffix() {
	local disk=$1

	if [[ $disk =~ /dev/nvme ]]; then
		echo "p"
	else
		echo ""
	fi
}

# Particionar um disco específico
partition_disk() {
	local disk=$1
	local part_suffix
	part_suffix=$(get_part_suffix "$disk")

	log "Particionando disco $disk..."

	sgdisk -n 1:2048:+1M -t 1:EF02 -c 1:'BIOS Boot' "$disk" >>"$LOG_FILE" 2>&1 || error_exit "Falha ao criar partição BIOS Boot em $disk"
	sgdisk -n 2:0:+512M -t 2:EF00 -c 2:'EFI System' "$disk" >>"$LOG_FILE" 2>&1 || error_exit "Falha ao criar partição EFI em $disk"

	if [[ -n "$HDSIZE" ]]; then
		local hdsize_bytes=$((HDSIZE * 1024 * 1024 * 1024 / 512))
		sgdisk -n 3:0:+${hdsize_bytes} -t 3:BF00 -c 3:'ZFS Root' "$disk" >>"$LOG_FILE" 2>&1 || error_exit "Falha ao criar partição ZFS em $disk com hdsize"
	else
		sgdisk -n 3:0:0 -t 3:BF00 -c 3:'ZFS Root' "$disk" >>"$LOG_FILE" 2>&1 || error_exit "Falha ao criar partição ZFS em $disk"
	fi

	partprobe "$disk" >>"$LOG_FILE" 2>&1 || error_exit "Falha ao executar partprobe em $disk"
	sync
	log "Particionamento de $disk concluído"
}

# Preparar todos os discos selecionados
prepare_disks() {
	gum format -- "### Preparando Discos"

	for disk in "${SELECTED_DISKS[@]}"; do
		local disk_title
		if [[ -n "$HDSIZE" ]]; then
			disk_title="$disk (${HDSIZE}GB)"
		else
			disk_title="$disk"
		fi

		# Construir comando de particionamento baseado em HDSIZE
		local partition_cmd
		if [[ -n "$HDSIZE" ]]; then
			local hdsize_bytes=$((HDSIZE * 1024 * 1024 * 1024 / 512))
			partition_cmd="
				wipefs -a '$disk'
				sgdisk --zap-all '$disk'
				sgdisk -n 1:2048:+1M -t 1:EF02 -c 1:'BIOS Boot' '$disk'
				sgdisk -n 2:0:+512M -t 2:EF00 -c 2:'EFI System' '$disk'
				sgdisk -n 3:0:+${hdsize_bytes} -t 3:BF00 -c 3:'ZFS Root' '$disk'
				partprobe '$disk'
				sleep 2
			"
		else
			partition_cmd="
				wipefs -a '$disk'
				sgdisk --zap-all '$disk'
				sgdisk -n 1:2048:+1M -t 1:EF02 -c 1:'BIOS Boot' '$disk'
				sgdisk -n 2:0:+512M -t 2:EF00 -c 2:'EFI System' '$disk'
				sgdisk -n 3:0:0 -t 3:BF00 -c 3:'ZFS Root' '$disk'
				partprobe '$disk'
				sleep 2
			"
		fi

		gum spin --spinner dot --title "Limpando e particionando $disk_title..." -- bash -c "$partition_cmd" || error_exit "Falha ao preparar disco $disk"
		log "Disco $disk preparado com sucesso"
	done

	gum format -- "✓ Todos os discos preparados com sucesso!"
	log "Preparação de discos concluída"
}

# =============================================================================
# MÓDULO: CONFIGURAÇÃO ZFS
# =============================================================================

# Coletar partições ZFS de todos os discos
get_zfs_partitions() {
	local -a zfs_parts=()

	log "Gerando lista de partições para discos: ${SELECTED_DISKS[*]}"
	for disk in "${SELECTED_DISKS[@]}"; do
		[[ -z "$disk" ]] && continue
		local part_suffix
		part_suffix=$(get_part_suffix "$disk")
		log "Disco: $disk, Sufixo: $part_suffix, Partição: ${disk}${part_suffix}3"
		zfs_parts+=("${disk}${part_suffix}3")
	done

	for part in "${zfs_parts[@]}"; do
		echo "$part"
	done
}

# Criar pool ZFS com topologia e opções selecionadas
create_pool() {
	local -a zfs_parts=()
	mapfile -t zfs_parts < <(get_zfs_partitions)

	if [[ ${#zfs_parts[@]} -eq 0 ]]; then
		error_exit "Nenhuma partição ZFS encontrada. Verifique se os discos foram particionados corretamente."
	fi

	log "Partições ZFS detectadas: ${zfs_parts[*]}"

	# Verificar se já existe pool com esse nome e exportar
	if zpool list "$POOL_NAME" >/dev/null 2>&1; then
		log "Pool $POOL_NAME já existe, tentando exportar..."
		zpool export "$POOL_NAME" 2>>"$LOG_FILE" || true
	fi

	# Limpar labels ZFS existentes nas partições
	for part in "${zfs_parts[@]}"; do
		zpool labelclear -f "$part" 2>>"$LOG_FILE" || true
	done

	gum format -- "### Criando Pool ZFS ($RAID_TOPOLOGY)"

	local pool_cmd=(
		zpool create -f
		-o "ashift=$ASHIFT"
		-o autotrim=on
		-O acltype=posixacl
		-O canmount=off
		-O "compression=$COMPRESSION"
		-O dnodesize=auto
		-O normalization=formD
		-O relatime=on
		-O xattr=sa
		-O mountpoint=none
		-O "checksum=$CHECKSUM"
		-O "copies=$COPIES"
		-R "$MOUNT_POINT"
	)

	# Construir argumentos de topologia
	local -a topology_args=()
	case $RAID_TOPOLOGY in
	Single)
		topology_args+=("$POOL_NAME" "${zfs_parts[0]}")
		;;
	Stripe)
		topology_args+=("$POOL_NAME" "${zfs_parts[@]}")
		;;
	Mirror)
		topology_args+=("$POOL_NAME" mirror "${zfs_parts[@]}")
		;;
	RAIDZ1)
		topology_args+=("$POOL_NAME" raidz1 "${zfs_parts[@]}")
		;;
	RAIDZ2)
		topology_args+=("$POOL_NAME" raidz2 "${zfs_parts[@]}")
		;;
	RAIDZ3)
		topology_args+=("$POOL_NAME" raidz3 "${zfs_parts[@]}")
		;;
	esac

	# Adicionar opções de criptografia se habilitado
	if [[ "$ENCRYPTION" == "on" ]]; then
		log "Habilitando criptografia nativa no pool..."
		pool_cmd+=(
			-O encryption=aes-256-gcm
			-O keyformat=passphrase
			-O keylocation=prompt
		)

		# Executar com pipe para a senha
		log "Executando zpool create com criptografia: ${pool_cmd[*]} ${topology_args[*]}"
		sync
		if ! echo "$ENCRYPTION_PASSPHRASE" | "${pool_cmd[@]}" "${topology_args[@]}" 2>>"$LOG_FILE"; then
			error_exit "Falha ao criar pool ZFS criptografado. Verifique $LOG_FILE."
		fi
	else
		log "Executando zpool create: ${pool_cmd[*]} ${topology_args[*]}"
		sync
		if ! "${pool_cmd[@]}" "${topology_args[@]}" 2>>"$LOG_FILE"; then
			error_exit "Falha ao criar pool ZFS. Verifique $LOG_FILE."
		fi
	fi

	log "Pool ZFS '$POOL_NAME' criado com sucesso em $RAID_TOPOLOGY"
	gum format -- "✓ Pool ZFS criado: $POOL_NAME ($RAID_TOPOLOGY)"
}

# Criar hierarquia de datasets ZFS
create_datasets() {
	gum format -- "### Criando Datasets ZFS"

	log "Criando dataset ROOT..."
	zfs create -o canmount=off -o mountpoint=none "$POOL_NAME/ROOT" 2>>"$LOG_FILE" ||
		error_exit "Falha ao criar dataset ROOT"

	log "Criando dataset ROOT/debian..."
	zfs create -o canmount=noauto -o mountpoint=/ -o com.sun:auto-snapshot=true "$POOL_NAME/ROOT/debian" 2>>"$LOG_FILE" ||
		error_exit "Falha ao criar dataset ROOT/debian"

	zfs mount "$POOL_NAME/ROOT/debian" 2>>"$LOG_FILE" ||
		error_exit "Falha ao montar dataset ROOT/debian"

	log "Criando dataset home..."
	zfs create -o mountpoint=/home -o com.sun:auto-snapshot=true "$POOL_NAME/home" 2>>"$LOG_FILE" ||
		error_exit "Falha ao criar dataset home"

	log "Criando dataset home/root..."
	zfs create -o mountpoint=/root "$POOL_NAME/home/root" 2>>"$LOG_FILE" ||
		error_exit "Falha ao criar dataset home/root"

	log "Criando dataset var..."
	zfs create -o mountpoint=/var -o canmount=off "$POOL_NAME/var" 2>>"$LOG_FILE" ||
		error_exit "Falha ao criar dataset var"

	log "Criando dataset var/log..."
	zfs create -o com.sun:auto-snapshot=true "$POOL_NAME/var/log" 2>>"$LOG_FILE" ||
		error_exit "Falha ao criar dataset var/log"

	log "Criando dataset var/cache..."
	zfs create -o com.sun:auto-snapshot=false "$POOL_NAME/var/cache" 2>>"$LOG_FILE" ||
		error_exit "Falha ao criar dataset var/cache"

	log "Criando dataset var/tmp..."
	zfs create -o com.sun:auto-snapshot=false "$POOL_NAME/var/tmp" 2>>"$LOG_FILE" ||
		error_exit "Falha ao criar dataset var/tmp"

	log "Configurando propriedade de linha de comando para ZFSBootMenu..."
	zfs set org.zfsbootmenu:commandline="quiet" "$POOL_NAME/ROOT/debian" 2>>"$LOG_FILE" ||
		error_exit "Falha ao configurar commandline do ZFSBootMenu"

	gum format -- "✓ Datasets ZFS criados com sucesso!"
	log "Todos os datasets ZFS criados com sucesso"
	sync
}

# =============================================================================
# MÓDULO: EXTRAÇÃO DO SISTEMA
# =============================================================================

# Validar existência do arquivo squashfs
validate_squashfs() {
	local squashfs_paths=(
		"/run/live/medium/live/filesystem.squashfs"
		"/lib/live/mount/medium/live/filesystem.squashfs"
		"/cdrom/live/filesystem.squashfs"
	)
	local found_path=""

	log "Buscando arquivo squashfs..."
	for path in "${squashfs_paths[@]}"; do
		if [[ -f "$path" ]]; then
			found_path="$path"
			log "Squashfs encontrado em: $found_path"
			break
		fi
	done

	if [[ -z "$found_path" ]]; then
		gum format -- "
## ❌ Arquivo Squashfs Não Encontrado

O instalador não conseguiu encontrar o arquivo \`filesystem.squashfs\`.
Este arquivo é necessário para extrair o sistema.

**Caminhos verificados:**
\`\`\`
${squashfs_paths[*]}
\`\`\`

**Possíveis causas:**
- ISO foi corrompida durante o download
- Boot não foi feito corretamente
- Diretório /live não foi montado

**Solução:**
1. Verifique o hash da ISO
2. Recrie a ISO usando os scripts de build
3. Tente novamente a instalação
		"
		error_exit "Arquivo squashfs não encontrado em nenhum dos caminhos esperados."
	fi

	# Exportar caminho encontrado para uso em outras funções
	export SQUASHFS_PATH="$found_path"
	gum format -- "✓ Arquivo squashfs encontrado: $SQUASHFS_PATH"
}

# Criar diretórios essenciais no sistema de destino
create_essential_dirs() {
	log "Criando diretórios essenciais..."

	mkdir -p "$MOUNT_POINT" || error_exit "Falha ao criar diretório $MOUNT_POINT"
	mkdir -p "$MOUNT_POINT/dev" || error_exit "Falha ao criar $MOUNT_POINT/dev"
	mkdir -p "$MOUNT_POINT/proc" || error_exit "Falha ao criar $MOUNT_POINT/proc"
	mkdir -p "$MOUNT_POINT/sys" || error_exit "Falha ao criar $MOUNT_POINT/sys"
	mkdir -p "$MOUNT_POINT/run" || error_exit "Falha ao criar $MOUNT_POINT/run"
	mkdir -p "$MOUNT_POINT/tmp" || error_exit "Falha ao criar $MOUNT_POINT/tmp"

	chmod 1777 "$MOUNT_POINT/tmp" || error_exit "Falha ao definir permissões em $MOUNT_POINT/tmp"

	log "Diretórios essenciais criados com sucesso"
	gum format -- "✓ Diretórios essenciais criados"
}

# Extrair sistema do arquivo squashfs
extract_system() {
	log "Iniciando extração do sistema de $SQUASHFS_PATH..."

	# Verificar novamente se o arquivo existe (segurança)
	if [[ ! -f "$SQUASHFS_PATH" ]]; then
		error_exit "Arquivo squashfs desapareceu: $SQUASHFS_PATH"
	fi

	gum format -- "### Extraindo Sistema"

	if ! gum spin --spinner dot --title "Extraindo sistema (isso pode levar alguns minutos)..." -- \
		unsquashfs -f -d "$MOUNT_POINT" "$SQUASHFS_PATH" 2>>"$LOG_FILE"; then
		error_exit "Falha ao extrair sistema do squashfs. Verifique $LOG_FILE para detalhes."
	fi

	log "Sistema extraído com sucesso em $MOUNT_POINT"

	# Verificar se a extração foi bem-sucedida checando arquivos críticos
	local critical_files=("$MOUNT_POINT/bin/bash" "$MOUNT_POINT/etc/passwd" "$MOUNT_POINT/usr/bin")
	local missing_files=()

	for file in "${critical_files[@]}"; do
		if [[ ! -e "$file" ]]; then
			missing_files+=("$file")
		fi
	done

	if [[ ${#missing_files[@]} -gt 0 ]]; then
		gum format -- "
## ⚠️ Aviso: Arquivos Críticos Ausentes

Após a extração, alguns arquivos críticos não foram encontrados:
\`\`\`
${missing_files[*]}
\`\`\`

A extração pode ter falhado parcialmente.
		"
		error_exit "Extração incompleta: ${missing_files[*]} não encontrados."
	fi

	gum format -- "✓ Sistema extraído com sucesso!"
}

# =============================================================================
# MÓDULO: CONFIGURAÇÃO CHROOT
# =============================================================================

# Montar sistemas de arquivos virtuais para chroot
mount_chroot_filesystems() {
	log "Montando sistemas de arquivos virtuais..."

	if ! mount --make-private --rbind /dev "$MOUNT_POINT/dev" 2>>"$LOG_FILE"; then
		error_exit "Falha ao montar /dev"
	fi

	if ! mount --make-private --rbind /proc "$MOUNT_POINT/proc" 2>>"$LOG_FILE"; then
		error_exit "Falha ao montar /proc"
	fi

	if ! mount --make-private --rbind /sys "$MOUNT_POINT/sys" 2>>"$LOG_FILE"; then
		error_exit "Falha ao montar /sys"
	fi

	if ! mount --make-private --rbind /run "$MOUNT_POINT/run" 2>>"$LOG_FILE"; then
		error_exit "Falha ao montar /run"
	fi

	log "Sistemas de arquivos virtuais montados com sucesso"
	gum format -- "✓ Sistemas de arquivos montados"
}

# Configurar hostname e /etc/hosts

# Configurar hostname e /etc/hosts
configure_hostname() {
	log "Configurando hostname: $HOSTNAME"

	if ! echo "$HOSTNAME" >"$MOUNT_POINT/etc/hostname" 2>>"$LOG_FILE"; then
		error_exit "Falha ao configurar /etc/hostname"
	fi

	if ! cat >"$MOUNT_POINT/etc/hosts" <<HOSTSEOF; then
127.0.0.1	localhost
127.0.1.1	$HOSTNAME
::1		localhost ip6-localhost ip6-loopback
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
HOSTSEOF
		error_exit "Falha ao configurar /etc/hosts"
	fi

	log "Hostname configurado com sucesso"
	gum format -- "✓ Hostname configurado: $HOSTNAME"
}
# Configurar usuários e senhas
configure_users() {
	log "Configurando usuários..."

	chroot "$MOUNT_POINT" /bin/bash -c "echo 'root:$ROOT_PASS' | chpasswd" 2>>"$LOG_FILE" ||
		error_exit "Falha ao definir senha do root"

	chroot "$MOUNT_POINT" /bin/bash -c "useradd -m -s /bin/bash -G sudo,dip,plugdev,cdrom '$USERNAME'" 2>>"$LOG_FILE" ||
		error_exit "Falha ao criar usuário $USERNAME"

	chroot "$MOUNT_POINT" /bin/bash -c "echo '$USERNAME:$USER_PASS' | chpasswd" 2>>"$LOG_FILE" ||
		error_exit "Falha ao definir senha do usuário $USERNAME"

	log "Usuários configurados com sucesso"
	gum format -- "✓ Usuários configurados"
}

# Configurar locale e timezone
configure_locales() {
	log "Configurando locale e timezone..."

	# Permitir seleção de locale
	local selected_locale
	selected_locale=$(gum choose --header "Selecione o locale:" \
		"pt_BR.UTF-8" \
		"en_US.UTF-8" \
		--selected "pt_BR.UTF-8")

	if [[ -z "$selected_locale" ]]; then
		selected_locale="pt_BR.UTF-8"
	fi

	if ! echo "$selected_locale UTF-8" >"$MOUNT_POINT/etc/locale.gen" 2>>"$LOG_FILE"; then
		error_exit "Falha ao configurar /etc/locale.gen"
	fi

	chroot "$MOUNT_POINT" locale-gen 2>>"$LOG_FILE" ||
		error_exit "Falha ao executar locale-gen"

	# Extrair código de linguagem (pt_BR, en_US, etc)
	local lang_code
	lang_code=$(echo "$selected_locale" | cut -d. -f1)

	chroot "$MOUNT_POINT" /bin/bash -c "update-locale LANG=$selected_locale LANGUAGE=$lang_code" 2>>"$LOG_FILE" ||
		error_exit "Falha ao executar update-locale"

	# Selecionar timezone
	local selected_timezone
	selected_timezone=$(gum input --prompt "Timezone:" --value "America/Sao_Paulo" --placeholder "America/Sao_Paulo")

	if [[ -n "$selected_timezone" ]]; then
		if ! echo "$selected_timezone" >"$MOUNT_POINT/etc/timezone" 2>>"$LOG_FILE"; then
			error_exit "Falha ao configurar /etc/timezone"
		fi

		chroot "$MOUNT_POINT" dpkg-reconfigure -f noninteractive tzdata 2>>"$LOG_FILE" ||
			error_exit "Falha ao reconfigurar tzdata"
	fi

	log "Locale e timezone configurados com sucesso"
	gum format -- "✓ Locale e timezone configurados"
}

# Configurar /etc/fstab

# Configurar /etc/fstab
configure_fstab() {
	log "Configurando /etc/fstab..."

	if ! cat >"$MOUNT_POINT/etc/fstab" <<FSTABEOF; then
# /etc/fstab: arquivo de configuração de sistemas de arquivos estáticos
#
# Use 'blkid' para imprimir o UUID de dispositivos
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
$POOL_NAME/ROOT/debian	/	zfs	defaults,noatime,xattr=sa	0	0
$POOL_NAME/home		/home	zfs	defaults,noatime,xattr=sa	0	0
$POOL_NAME/home/root	/root	zfs	defaults,noatime,xattr=sa	0	0
$POOL_NAME/var/log	/var/log	zfs	defaults,noatime,xattr=sa	0	0
$POOL_NAME/var/cache	/var/cache	zfs	defaults,noatime,xattr=sa	0	0
$POOL_NAME/var/tmp	/var/tmp	zfs	defaults,noatime,xattr=sa	0	0
tmpfs		/tmp		tmpfs	defaults,nosuid,nodev,noexec,mode=1777	0	0
FSTABEOF
		error_exit "Falha ao configurar /etc/fstab"
	fi

	log "/etc/fstab configurado com sucesso"
	gum format -- "✓ /etc/fstab configurado"
}
# Gerar /etc/hostid consistente com o pool
generate_hostid() {
	log "Gerando hostid..."

	chroot "$MOUNT_POINT" zgenhostid 2>>"$LOG_FILE" ||
		error_exit "Falha ao gerar hostid com zgenhostid"

	log "Hostid gerado"
	gum format -- "✓ Hostid gerado"
}

# Regenerar initramfs com suporte ZFS
update_initramfs() {
	log "Regenerando initramfs..."

	chroot "$MOUNT_POINT" update-initramfs -u -k all 2>>"$LOG_FILE" ||
		error_exit "Falha ao regenerar initramfs"

	log "Initramfs regenerado com sucesso"
	gum format -- "✓ Initramfs regenerado"
}

# =============================================================================
# MÓDULO: INSTALAÇÃO ZFSBOOTMENU
# =============================================================================

# Obter partição EFI do primeiro disco
get_efi_partition() {
	local disk=${SELECTED_DISKS[0]}
	local part_suffix
	part_suffix=$(get_part_suffix "$disk")

	echo "${disk}${part_suffix}2"
}

# Formatar partição EFI
format_esp() {
	local efi_part
	efi_part=$(get_efi_partition)

	log "Formatando partição EFI: $efi_part"

	mkfs.vfat -F 32 -n EFI "$efi_part" 2>>"$LOG_FILE" ||
		error_exit "Falha ao formatar partição EFI $efi_part"

	log "Partição EFI formatada com sucesso"
	gum format -- "✓ Partição EFI formatada"
}

# Montar ESP em /boot/efi
mount_esp() {
	local efi_part
	efi_part=$(get_efi_partition)

	log "Montando ESP em $MOUNT_POINT/boot/efi..."

	mkdir -p "$MOUNT_POINT/boot/efi" ||
		error_exit "Falha ao criar diretório $MOUNT_POINT/boot/efi"

	mount "$efi_part" "$MOUNT_POINT/boot/efi" 2>>"$LOG_FILE" ||
		error_exit "Falha ao montar ESP em $MOUNT_POINT/boot/efi"

	log "ESP montado com sucesso"
	gum format -- "✓ ESP montado em /boot/efi"
}

# Copiar binários do ZFSBootMenu
copy_zbm_binaries() {
	log "Copiando binários do ZFSBootMenu..."

	if [[ ! -d "$ZBM_BIN_DIR" ]]; then
		error_exit "Diretório ZFSBootMenu não encontrado: $ZBM_BIN_DIR"
	fi

	mkdir -p "$MOUNT_POINT/boot/efi/EFI/ZBM" ||
		error_exit "Falha ao criar diretório ZBM"

	cp "$ZBM_BIN_DIR"/vmlinuz*.EFI "$MOUNT_POINT/boot/efi/EFI/ZBM/zbm.efi" 2>>"$LOG_FILE" ||
		error_exit "Falha ao copiar binário ZBM"

	cp "$ZBM_BIN_DIR"/vmlinuz-signed*.EFI "$MOUNT_POINT/boot/efi/EFI/ZBM/zbm-signed.efi" 2>>"$LOG_FILE" || true

	cp "$ZBM_BIN_DIR"/*.EFI "$MOUNT_POINT/boot/efi/EFI/BOOT/" 2>>"$LOG_FILE" || true

	log "Binários ZFSBootMenu copiados com sucesso"
	gum format -- "✓ Binários ZFSBootMenu copiados"
}

# Configurar entrada EFI com efibootmgr
configure_efi() {
	log "Configurando entrada EFI..."

	# Verificar se é sistema UEFI
	if [[ ! -d /sys/firmware/efi ]]; then
		log "Sistema não é UEFI, pulando configuração EFI"
		gum format -- "> ⚠️ Sistema BIOS detectado - EFI não configurado"
		return 0
	fi

	# Verificar se efibootmgr está disponível
	if ! command -v efibootmgr >/dev/null 2>&1; then
		log "efibootmgr não encontrado, pulando configuração EFI"
		gum format -- "> ⚠️ efibootmgr não disponível - EFI não configurado"
		return 0
	fi

	efibootmgr -c -d "${SELECTED_DISKS[0]}" -p 2 \
		-L "Aurora OS" \
		-l "\EFI\ZBM\zbm.efi" \
		2>>"$LOG_FILE" || {
		log "Falha ao configurar entrada EFI"
		gum format -- "> ⚠️ Falha ao configurar entrada EFI - continue manualmente"
		return 0
	}

	log "Entrada EFI configurada com sucesso"
	gum format -- "✓ Entrada EFI configurada"
}

# Configurar propriedade de commandline para ZFSBootMenu
configure_commandline() {
	log "Configurando propriedade de commandline para ZFSBootMenu..."

	zfs set org.zfsbootmenu:commandline="quiet loglevel=4" "$POOL_NAME/ROOT/debian" 2>>"$LOG_FILE" ||
		error_exit "Falha ao configurar commandline do ZFSBootMenu"

	log "Propriedade commandline configurada com sucesso"
	gum format -- "✓ Propriedade ZFSBootMenu configurada"
}

# =============================================================================
# MÓDULO: FINALIZAÇÃO
# =============================================================================

# Criar snapshot inicial do sistema
create_snapshot() {
	log "Criando snapshot inicial do sistema..."

	# Verificar se snapshot já existe
	if zfs list -t snapshot | grep -q "$POOL_NAME/ROOT/debian@install"; then
		log "Snapshot @install já existe, removendo..."
		zfs destroy -r "$POOL_NAME/ROOT/debian@install" 2>>"$LOG_FILE" || true
	fi

	if ! zfs snapshot "$POOL_NAME/ROOT/debian@install" 2>>"$LOG_FILE"; then
		error_exit "Falha ao criar snapshot inicial"
	fi

	log "Snapshot inicial criado: $POOL_NAME/ROOT/debian@install"
	gum format -- "✓ Snapshot inicial criado"
}

# Desmontar todos os filesystems
unmount_all() {
	log "Desmontando filesystems..."

	# Desmontar sistemas virtuais primeiro
	for dir in dev proc sys run; do
		if mountpoint -q "$MOUNT_POINT/$dir"; then
			log "Desmontando $MOUNT_POINT/$dir"
			umount -l "$MOUNT_POINT/$dir" 2>>"$LOG_FILE" || true
		fi
	done

	# Desmontar ESP se estiver montado
	if mountpoint -q "$MOUNT_POINT/boot/efi"; then
		log "Desmontando $MOUNT_POINT/boot/efi"
		umount "$MOUNT_POINT/boot/efi" 2>>"$LOG_FILE" || true
	fi

	# Desmontar datasets ZFS em ordem inversa
	if mountpoint -q "$MOUNT_POINT/var/tmp"; then
		zfs umount "$POOL_NAME/var/tmp" 2>>"$LOG_FILE" || true
	fi
	if mountpoint -q "$MOUNT_POINT/var/cache"; then
		zfs umount "$POOL_NAME/var/cache" 2>>"$LOG_FILE" || true
	fi
	if mountpoint -q "$MOUNT_POINT/var/log"; then
		zfs umount "$POOL_NAME/var/log" 2>>"$LOG_FILE" || true
	fi
	if mountpoint -q "$MOUNT_POINT/home"; then
		zfs umount "$POOL_NAME/home" 2>>"$LOG_FILE" || true
	fi
	if mountpoint -q "$MOUNT_POINT/home/root"; then
		zfs umount "$POOL_NAME/home/root" 2>>"$LOG_FILE" || true
	fi
	if mountpoint -q "$MOUNT_POINT"; then
		zfs umount "$POOL_NAME/ROOT/debian" 2>>"$LOG_FILE" || true
	fi

	sync
	log "Filesystems desmontados"
	gum format -- "✓ Filesystems desmontados"
}

# Exportar pool ZFS
export_pool() {
	log "Exportando pool ZFS..."

	if zpool export "$POOL_NAME" 2>>"$LOG_FILE"; then
		log "Pool $POOL_NAME exportado com sucesso"
		gum format -- "✓ Pool ZFS exportado"
	else
		log "Aviso: Falha ao exportar pool $POOL_NAME"
		gum format -- "> ⚠️ Aviso: Não foi possível exportar o pool ZFS"
	fi
}

# Configuração de perfis e pacotes adicionais
configure_profile() {
	gum format -- "### Configurando Perfil: **$PROFILE**"
	log "Iniciando configuração do perfil $PROFILE..."

	if [[ "$PROFILE" == "Workstation" ]]; then
		log "Configurando Workstation (habilitando interface gráfica)..."
		if chroot "$MOUNT_POINT" command -v sddm >/dev/null 2>&1; then
			chroot "$MOUNT_POINT" systemctl enable sddm 2>>"$LOG_FILE" || true
		fi
	else
		log "Configurando Server (modo console)..."
		if chroot "$MOUNT_POINT" command -v sddm >/dev/null 2>&1; then
			chroot "$MOUNT_POINT" systemctl disable sddm 2>>"$LOG_FILE" || true
		fi
	fi
}

# Exibir mensagem de sucesso e instruções
success_message() {
	local encryption_note=""
	if [[ "$ENCRYPTION" == "on" ]]; then
		encryption_note="\n\n> 🔐 **Nota:** O ZFSBootMenu solicitará sua passphrase para desbloquear o sistema."
	fi

	local msg
	msg="O **Aurora OS** foi instalado com sucesso.\n\n"
	msg+="**Configuração Realizada:**\n"
	msg+="• Hostname:  $HOSTNAME\n"
	msg+="• Usuário:   $USERNAME\n"
	msg+="• Perfil:    $PROFILE\n"
	msg+="• Crypto:    $ENCRYPTION\n\n"
	msg+="**Próximos Passos:**\n"
	msg+="1. Remova a mídia de instalação\n"
	msg+="2. Reinicie o sistema\n"
	msg+="3. Selecione 'Aurora OS' no boot\n"
	msg+="$encryption_note\n\n"
	msg+="**Snapshots:**\n"
	msg+="Use ZFSBootMenu para gerenciar snapshots e rollbacks."

	styled_box "🎉 INSTALAÇÃO CONCLUÍDA" "$msg" "$COLOR_SUCCESS"
	log "=== Instalação concluída com sucesso ==="
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
	log "=== Iniciando $SCRIPT_NAME v$SCRIPT_VERSION ==="

	# Fase 1: Pré-requisitos
	preflight_checks

	# Fase 2: Interface TUI
	welcome_screen
	select_disks

	# Selecionar topologia se múltiplos discos
	if [[ ${#SELECTED_DISKS[@]} -gt 1 ]]; then
		select_topology
	else
		RAID_TOPOLOGY="Single"
		log "Único disco selecionado, topologia definida como Single"
	fi

	configure_zfs_options
	collect_info
	confirm_installation

	# Fase 3: Preparação do Disco
	prepare_disks

	# Fase 4: Configuração ZFS
	create_pool
	create_datasets

	# Fase 5: Extração do Sistema
	validate_squashfs
	create_essential_dirs
	extract_system

	# Fase 6: Configuração Chroot
	mount_chroot_filesystems
	configure_hostname
	configure_users
	configure_locales
	configure_profile
	configure_fstab
	generate_hostid
	update_initramfs

	# Fase 7: Instalação ZFSBootMenu
	format_esp
	mount_esp
	copy_zbm_binaries
	configure_efi
	configure_commandline

	# Fase 8: Finalização
	create_snapshot
	unmount_all
	export_pool
	success_message

	log "=== Instalação concluída ==="
}

main "$@"
