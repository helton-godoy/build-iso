#!/bin/bash

# =========================================================================
#
#         SCRIPT REFATORADO PARA INSTALAÇÃO DO DEBIAN COM ZFS
#
# Descrição:
# Este script automatiza a instalação de um sistema Debian (Bookworm)
# utilizando ZFS como sistema de arquivos raiz. A versão foi refatorada
# para usar funções, tornando o código mais modular e legível.
#
# =========================================================================


# --- Configurações Globais -----------------------------------------------------------#

#=======================================================================================
# Garante que o script pare se qualquer comando falhar.
#=======================================================================================

set -e

clear


#=======================================================================================
# Variáveis que armazenam as escolhas do usuário e são usadas em várias funções.
#=======================================================================================

declare -a SELECTED_DISKS=()

DEBIAN_RELEASE=${DEBIAN_RELEASE:-"trixie"}

HOSTNAME=${HOSTNAME:-"debian-zfs-dados"}

ZFS_POOL="rpool"

LANG="pt_BR.UTF-8"

LC_ALL="pt_BR.UTF-8"

TIMEZONE="America/Cuiaba"

# === Preparação do disco de instalação:

BOOT_CHOICE=""

ENCRYPT_CHOICE=""

RAID_TYPE=""

EFI_PARTITION_NUMBER=2


# --- Funções Auxiliares --------------------------------------------------------------#


# --- CORES PARA OUTPUT ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# --- Estilos de Fonte ---
BOLD="\033[1m"       # Texto em negrito
DIM="\033[2m"        # Texto com brilho reduzido (nem sempre suportado)
ITALIC="\033[3m"     # Texto em itálico (nem sempre suportado)
UNDERLINE="\033[4m"  # Texto sublinhado
BLINK="\033[5m"      # Texto piscando (nem sempre suportado)
REVERSE="\033[7m"    # Inverte as cores de fundo e da fonte
HIDDEN="\033[8m"     # Texto oculto (útil para senhas)

# --- Cores de Fundo (Background) ---
BG_BLACK="\033[40m"
BG_RED="\033[41m"
BG_GREEN="\033[42m"
BG_YELLOW="\033[43m"
BG_BLUE="\033[44m"
BG_PURPLE="\033[45m"
BG_CYAN="\033[46m"
BG_LIGHT_GRAY="\033[47m"

#=======================================================================================
# Exibe um cabeçalho formatado para separar as seções da instalação.
# Argumento:
#   $1: A string de texto a ser exibida como título da seção.
#=======================================================================================

function exibir_cabecalho() {
    echo -e "${GREEN}"
    echo -e "==============================================================="
    echo -e "=== $1"
    echo -e "==============================================================="
    echo -e "${RESET}"

}


# --- FUNÇÕES DE LOG ---
log_info() {
    echo -e "${BLUE}INFO: $1${RESET}"
}

log_success() {
    echo -e "${GREEN}SUCESSO: $1${RESET}"
}

log_warn() {
    echo -e "${YELLOW}AVISO: $1${RESET}"
}

log_error() {
    echo -e "${RED}ERRO: $1${RESET}" >&2
    exit 1
}

# =========================================================================
# Faz a preparação inicial para a instalação.
# =========================================================================

# === Verifica se foi iniciado o script foi iniciado como root:

function check_root() {

    if [[ $EUID -ne 0 ]]; then

        log_error "Erro: Este script deve ser executado como root."

        exit 1

    fi

}


#=======================================================================================
# Configura idioma:
#=======================================================================================

function configure_locale() {

    log_info "Configurando locale no ambiente live..."

    if ! locale -a | grep -q "$LANG"; then

        DEBIAN_FRONTEND=noninteractive apt-get install -qqy locales > /dev/null 2>&1

        #============================================================================================
        #
        # sed: É um editor de fluxo de texto usado para fazer alteração.
        # 
        # -i: Esta opção faz com que o sed altere o arquivo diretamente (in-place). 
        #     Cuidado ao usar esta opção, pois pode haver perda de dados se algo der errado. 
        #     É recomendável fazer um backup do arquivo antes de usar -i.
        # 
        # '/pt_BR.UTF-8/: Este é o padrão que o sed procurará no arquivo. 
        #                 Ele irá procurar por linhas que contenham a string pt_BR.UTF-8.
        # 
        # s/^#//: Esta é a expressão de substituição.
        # 
        # s/: Indica que estamos fazendo uma substituição.
        # 
        # ^#: Significa que estamos procurando por um caractere '#' no início da linha (comentário).
        # 
        # //: Significa que estamos substituindo o caractere '#' por nada (removendo-o). 
        #
        #============================================================================================

        sed -i '/pt_BR.UTF-8/s/^#//' /etc/locale.gen

        locale-gen > /dev/null 2>&1

    fi

    export LANG="$LANG" 

    update-locale LANG="$LANG"

}

#=======================================================================================
# Detecta tipo do firmware usado no boot da instalação:
#=======================================================================================

function detect_boot_mode() {

    if [[ -d /sys/firmware/efi ]]; then
    
        BOOT_MODE="uefi"
    
    else
    
        BOOT_MODE="bios"
    
    fi
        
}


#=======================================================================================
# Ativa repositório dos pacotes necessários para a instalação:
#=======================================================================================

function config_repository() {

    log_info "Configurando repositórios APT..."
    
    cat > /etc/apt/sources.list <<EOL
deb http://deb.debian.org/debian $DEBIAN_RELEASE main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian $DEBIAN_RELEASE main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security $DEBIAN_RELEASE-security main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian-security $DEBIAN_RELEASE-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $DEBIAN_RELEASE-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian $DEBIAN_RELEASE-updates main contrib non-free non-free-firmware
EOL
    
    apt-get update -qq > /dev/null 2>&1 || { log_error "Erro ao atualizar repositórios APT."; exit 1; }

}


#=======================================================================================
# Instala dependências do instalador:
#=======================================================================================

function install_dependency() {
    
    log_info "Instalando dependências..."
    
    DEBIAN_FRONTEND=noninteractive apt-get install -qqy \
        dpkg-dev                                        \
        build-essential                                 \
        linux-headers-$(uname -r)                       \
        dkms                                            \
        zfs-dkms                                        \
        libpam-zfs                                      \
        libzfsbootenv1linux                             \
        libzfslinux-dev                                 \
        gdisk                                           \
        zfsutils-linux                                  \
        zfs-initramfs                                   \
        debootstrap                                     \
        dosfstools                                      \
        systemd-timesyncd                               \
        console-setup                                   \
        zstd                                            \
        lz4                                             \
        lzop  > /dev/null 2>&1 || {
    
        log_error "Erro ao instalar dependências. Verifique os repositórios e a conexão com a internet."
    
        exit 1
    
    }
    
    log_info "Instalando módulo ZFS"
    
    dkms autoinstall
    
    modprobe zfs
}


#=======================================================================================
# Ajusta fuso horário:
#=======================================================================================

function config_timesync() {

    log_info "Configurando systemd-timesyncd e fuso horário..."
    
    if ! grep -q "^NTP=a.st1.ntp.br" /etc/systemd/timesyncd.conf; then
    
        echo "NTP=a.st1.ntp.br" >> /etc/systemd/timesyncd.conf
    
        log_success "Systemd-timesyncd configurado."
    
    else
    
        log_warn "Systemd-timesyncd já configurado."
    
    fi
    
    timedatectl set-ntp true
    
    timedatectl set-timezone "$TIMEZONE"
    
    systemctl restart systemd-timesyncd

}


# --- Funções de Instalação -----------------------------------------------------------#


#=======================================================================================
# Detecta os discos físicos disponíveis no sistema, ignorando dispositivos de loop e CD-ROMs.
# A função tenta dois métodos de detecção para maior compatibilidade.
# Saída:
#   Imprime a lista de nomes de discos (ex: sda sdb) para a saída padrão.
#=======================================================================================

function detectar_discos() {

    exibir_cabecalho "1. Detectando Discos Disponíveis"
    
    local DISKS

    DISKS=$(lsblk -ndo NAME,TYPE | grep "disk" | awk '{print $1}')


    if [ -z "$DISKS" ]; then

        log_warn "Aviso: Tentando método alternativo de detecção de discos..." >&2

        DISKS=$(lsblk -ndo NAME | grep -vE "loop|sr" | grep -E "^[shv]d[a-z]$" || true)

    fi


    if [ -z "$DISKS" ]; then

        log_error "ERRO: Nenhum disco físico foi encontrado. Abortando." >&2

        exit 1

    fi
    
    echo "$DISKS"
}

#=======================================================================================
# Apresenta ao usuário a lista de discos detectados e captura sua seleção.
# Argumento:
#   $1: Uma string contendo os nomes dos discos disponíveis, separados por espaços.
#=======================================================================================

function selecionar_discos_usuario() {

    local AVAILABLE_DISKS=$1

    local COUNTER=1

    declare -A DISK_MAP

    log_warn "Discos encontrados no sistema:"

    for DISK in $AVAILABLE_DISKS; do

        if [ -b "/dev/$DISK" ]; then

            local DISK_INFO

            DISK_INFO=$(lsblk -ndo SIZE,MODEL /dev/"$DISK")

            printf "%2d) %-10s %s\n" "$COUNTER" "$DISK" "$DISK_INFO"

            DISK_MAP[$COUNTER]="/dev/$DISK"

            ((COUNTER++))

        fi

    done


    if [ ${#DISK_MAP[@]} -eq 0 ]; then

        log_error "Nenhum disco válido pôde ser mapeado para seleção." >&2

        exit 1

    fi


    echo
    read -rp "Digite os números dos discos para a instalação, separados por espaços (ex: 1 2): " USER_SELECTION


    for NUM in $USER_SELECTION; do

        if [[ -v DISK_MAP[$NUM] ]]; then

            SELECTED_DISKS+=("${DISK_MAP[$NUM]}")

        else

            log_warn "Aviso: O número '$NUM' é inválido e será ignorado." >&2

        fi

    done


    if [ ${#SELECTED_DISKS[@]} -eq 0 ]; then

        log_error "Nenhum disco foi selecionado. Abortando." >&2

        exit 1

    fi
    

    echo
    log_warn "Discos selecionados para a instalação:"

    for DISK in "${SELECTED_DISKS[@]}"; do

        echo "  - $DISK"

    done

}

#=======================================================================================
# Coleta as principais opções de configuração do usuário: tipo de boot,
# criptografia do pool principal (rpool) e o tipo de RAID para múltiplos discos.
#=======================================================================================

function obter_configuracoes_usuario() {

    exibir_cabecalho "2. Configurações da Instalação"

    printf "\n %10s %-10s \n\n" "[1] BIOS" "[2] UEFI"
    
    log_warn "Foi identificado que computador está usando => ${BLINK} ${BOOT_MODE^^} ${RESET}\n "
    
    read -rp "Escolha do tipo de boot que deseja usar: " BOOT_CHOICE
    
    read -rp "Deseja usar criptografia para o pool principal (rpool)? [s/N]: " ENCRYPT_CHOICE
    
    ENCRYPT_CHOICE=${ENCRYPT_CHOICE,,}
    
    if [ ${#SELECTED_DISKS[@]} -gt 1 ]; then
    
        echo   
        echo "Para os ${#SELECTED_DISKS[@]} discos selecionados, como deseja configurar o ZFS?"
    
        echo "  1) MIRROR             - 2 discos (raid1), 4/8/10... (raid10)"
    
        echo "  2) RAIDZ1             - 3+ discos (raid5)"
    
        echo "  3) RAIDZ2             - 4+ discos (raid6)"
    
        read -rp "Digite sua escolha: " RAID_CHOICE

        case "$RAID_CHOICE" in
    
            1) RAID_TYPE="mirror" ;;
    
            2) RAID_TYPE="raidz1" ;;
    
            3) RAID_TYPE="raidz2" ;;
    
            *)
                echo "Aviso: Escolha inválida. Usando 'mirror' como padrão." >&2
    
                RAID_TYPE="mirror"
                ;;
        esac
    fi
}

#=======================================================================================
# Exibe um aviso final sobre a perda de dados e pede uma confirmação explícita
# do usuário para continuar com o processo destrutivo.
#=======================================================================================

function confirmar_operacao_destrutiva() {

    exibir_cabecalho "3. Confirmação Final"

    log_warn "ATENÇÃO: TODOS OS DADOS NOS SEGUINTES DISCOS SERÃO APAGADOS PERMANENTEMENTE:"

    for DISK in "${SELECTED_DISKS[@]}"; do

        echo "  - $DISK"

    done

    echo

    read -rp "Você tem certeza absoluta que deseja continuar? Digite 'sim' para confirmar: " CONFIRMATION

    if [[ "${CONFIRMATION}" != "sim" ]]; then

        log_warn "Operação cancelada pelo usuário. O sistema não foi modificado."

        exit 0

    fi

}

#=======================================================================================
# Limpa completamente os discos selecionados e cria as partições necessárias para
# o boot (BIOS ou UEFI) e para os pools ZFS (bpool e rpool).
#=======================================================================================

function limpar_e_particionar_discos() {

    exibir_cabecalho "4. Particionando Discos"
    
    for disk_path in "${SELECTED_DISKS[@]}"; do
    
        log_info "Processando disco: $disk_path"
        
        sgdisk --zap-all "$disk_path" >/dev/null 2>&1   # === Limpa tabelas de partição e metadados antigos
       
        sgdisk -Z "$disk_path" >/dev/null 2>&1          # === Cria a tabela de partição GPT


        
        if [[ "$BOOT_CHOICE" == "1" ]]; # === Particionamento para BIOS (Legacy)

        then

            log_info "  - Criando partição de Boot BIOS..."

            sgdisk -a1 -n1:24K:+1000K -t1:EF02 "$disk_path" # === Partição de Boot BIOS

            log_info "  - Criando partição para bpool (1GB)..."

            sgdisk -n3:0:+1G -t3:BF01 "$disk_path"          # === Partição bpool (/boot)

            log_info "  - Criando partição para rpool (restante)..."

            sgdisk -n4:0:0 -t4:BF00 "$disk_path"            # === Partição rpool (/)

        
        
        elif [[ "$BOOT_CHOICE" == "2" ]]; # === Particionamento para UEFI:

        then

            log_info "  - Criando partição EFI (512MB)..."

            sgdisk -n2:1M:+512M -t2:EF00 "$disk_path"       # === Partição de Sistema EFI

            log_info "  - Criando partição para bpool (1GB)..."

            sgdisk -n3:0:+1G -t3:BF01 "$disk_path"          # === Partição bpool (/boot)

            log_info "  - Criando partição para rpool (restante)..."

            sgdisk -n4:0:0 -t4:BF00 "$disk_path"            # === Partição rpool (/)

        fi
       
        log_success "Particionamento em $disk_path concluído."

    done

}

#=======================================================================================
# Constrói a lista de dispositivos e cria os pools ZFS (bpool para /boot e rpool para /).
#=======================================================================================

function criar_pools_zfs() {

    exibir_cabecalho "5. Criando Pools ZFS"

    local BPOOL_DEVICES=""
    
    local RPOOL_DEVICES=""
    
    local BPOOL_PART_NUM=3
    
    local RPOOL_PART_NUM=4

    
    # === Constrói a string de dispositivos para o zpool create:

    if [ ${#SELECTED_DISKS[@]} -eq 1 ]; then

        BPOOL_DEVICES="${SELECTED_DISKS[0]}${BPOOL_PART_NUM}"
    
        RPOOL_DEVICES="${SELECTED_DISKS[0]}${RPOOL_PART_NUM}"
    
    else
    
        BPOOL_DEVICES="$RAID_TYPE"
    
        RPOOL_DEVICES="$RAID_TYPE"
    
        for disk_path in "${SELECTED_DISKS[@]}"; do
    
            BPOOL_DEVICES+=" ${disk_path}${BPOOL_PART_NUM}"
    
            RPOOL_DEVICES+=" ${disk_path}${RPOOL_PART_NUM}"
    
        done
    
    fi
    

    log_info "Aguarde, os pools ZFS estão sendo criados..."
    
    # === Cria bpool (para /boot):
    
    zpool create -f             \
        -o ashift=12            \
        -o autotrim=on          \
        -O acltype=posixacl     \
        -O xattr=sa             \
        -O compression=lz4      \
        -O normalization=formD  \
        -O relatime=on          \
        -O canmount=off         \
        -O mountpoint=/boot     \
        -R /mnt                 \
    bpool ${BPOOL_DEVICES}

    
    
    # === Define opções comuns para rpool:
    
    local rpool_opts="-f -o ashift=12 -o autotrim=on"

    rpool_opts+=" -O acltype=posixacl -O xattr=sa -O dnodesize=auto"

    rpool_opts+=" -O compression=zstd -O normalization=formD -O relatime=on"

    rpool_opts+=" -O canmount=off -O mountpoint=/ -R /mnt"

    
    
    # === Adiciona opções de criptografia se solicitado:

    if [[ "$ENCRYPT_CHOICE" == "s" ]]; then

        log_info "  - Criando rpool criptografado..."

        rpool_opts+=" -O encryption=on -O keylocation=prompt -O keyformat=passphrase"

    else

        log_info "  - Criando rpool não criptografado..."

    fi
    

    zpool create ${rpool_opts} rpool ${RPOOL_DEVICES}  # === Cria rpool (para /)

    log_success "Pools ZFS criados com sucesso."

}

#=======================================================================================
# Cria os datasets ZFS e instala o sistema Debian base usando 'debootstrap'.
#=======================================================================================

function instalar_sistema_base() {

    exibir_cabecalho "6. Instalando o Sistema Debian Base"

    # === Criação dos datasets ZFS:

    zfs create -o canmount=off -o mountpoint=none rpool/ROOT

    zfs create -o canmount=off -o mountpoint=none bpool/BOOT

    zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/debian

    zfs mount rpool/ROOT/debian

    zfs create -o mountpoint=/boot bpool/BOOT/debian

    log_info "Iniciando 'debootstrap' para instalar o Debian Bookworm (isso pode levar alguns minutos)..."

    debootstrap bookworm /mnt >/dev/null 2>&1

    # === Copia o cache do zpool para o novo sistema para que ele possa importar os pools no boot:

    mkdir -p /mnt/etc/zfs

    cp /etc/zfs/zpool.cache /mnt/etc/zfs/ || true
    
    log_success "Instalação do sistema base concluída."

}

#=======================================================================================
# Prepara e executa um script de configuração dentro do ambiente chroot
# para instalar o kernel, ZFS, GRUB e outras configurações essenciais.
#=======================================================================================

function configurar_sistema_chroot() {

    exibir_cabecalho "7. Configurando o Sistema (Chroot)"

    # === Prepara o ambiente para o chroot:
    
    mount --make-private --rbind /dev  /mnt/dev
    
    mount --make-private --rbind /proc /mnt/proc
    
    mount --make-private --rbind /sys  /mnt/sys

    
    
    # === Cria o script que será executado dentro do chroot: 
    
    local CHROOT_SCRIPT_PATH="/tmp/chroot_config.sh"
    
    cat << CHROOT_EOF > "/mnt${CHROOT_SCRIPT_PATH}"
#!/bin/bash

set -e

#=======================================================================================
# Importa as variáveis passadas como argumento
#=======================================================================================

BOOT_CHOICE="$1"

shift

SELECTED_DISKS_ARRAY=("$@")

EFI_PARTITION_NUMBER=2


#=======================================================================================
# Atualiza pacotes do repositório Debian
#=======================================================================================

DEBIAN_FRONTEND=noninteractive apt-get upgrade -qq >/dev/null 2>&1


#=======================================================================================
# Instalação do Kernel e suporte ao ZFS
#=======================================================================================

function install_system_packages() {
DEBIAN_FRONTEND=noninteractive apt-get install -qqy \
    dpkg-dev                                        \
    build-essential                                 \
    linux-image-amd64                               \
    linux-headers-$(uname -r)                       \
    dkms                                            \
    zfs-dkms                                        \
    zfs-initramfs                                   \
    zfsutils-linux                                  \
    dosfstools                                      \
    zstd                                            \
    lz4                                             \
lzop >/dev/null 2>&1

dkms autoinstall    # === Compila módulo ZFS

modprobe zfs        # === Ativa módulo ZFS

#=======================================================================================
# Configuração de locale
#=======================================================================================

log_info "Configurando idioma ${LANG}."

DEBIAN_FRONTEND=noninteractive apt-get install -qqy locales >/dev/null 2>&1 && \
sed -i '/"${LANG}"/s/^#//' /etc/locale.gen                                  && \
locale-gen                                                                  && \
update-locale LANG="${LANG}"                                                || \
log_error "Falha ao configurar o idioma, abortando instalador!"



#=======================================================================================
# Configura timezone
#=======================================================================================

# === Verifica se a variável TIMEZONE está setada:

if [ -z "${TIMEZONE}" ]; then
  
  log_error "Variável TIMEZONE não está definida!"
  
  exit 1

fi

# === Verifica se o arquivo correspondente ao timezone existe:

if [ ! -f "/usr/share/zoneinfo/${TIMEZONE}" ]; then

  log_error "Timezone ${TIMEZONE} inválido!"

  exit 1

fi

ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime

dpkg-reconfigure --frontend noninteractive tzdata


#=======================================================================================
# Instalação pacote correto do GRUB dependendo do tipo de boot selecionado
#=======================================================================================

if [[ "${BOOT_CHOICE}" == "1" ]]; then

    apt-get install --yes grub-pc >/dev/null 2>&1   # === Caso escolhido BIOS

elif [[ "${BOOT_CHOICE}" == "2" ]]; then

    apt-get install --yes grub-efi-amd64 shim-signed >/dev/null 2>&1    # === Caso escolhido UEFI

fi


#=======================================================================================
# Definir a senha de root
#=======================================================================================

echo "Por favor, defina a senha para o usuário 'root':"

passwd

#=======================================================================================
# Configura o GRUB para encontrar o sistema de arquivos raiz ZFS
#=======================================================================================

sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="root=ZFS=rpool\/ROOT\/debian"/' /etc/default/grub

update-grub

#=======================================================================================
# Instala o bootloader GRUB nos discos dependendo do tipo de boot selecionado
#=======================================================================================

if [[ "${BOOT_CHOICE}" == "1" ]]; then

    for DISK in "${SELECTED_DISKS_ARRAY[@]}"; do

        grub-install "${DISK}"

    done

elif [[ "$BOOT_CHOICE" == "2" ]]; then

    for DISK in "${SELECTED_DISKS_ARRAY[@]}"; do

        EFI_PART="${DISK}${EFI_PARTITION_NUMBER}"

        mkdir -p /boot/efi

        mount "${EFI_PART}" /boot/efi

        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck

        umount /boot/efi

    done

fi


#=======================================================================================
# Ajustes finais para a montagem do ZFS
#=======================================================================================

zfs set cachefile=/etc/zfs/zpool.cache bpool
zfs set cachefile=/etc/zfs/zpool.cache rpool
zpool set cachefile=/etc/zfs/zpool.cache bpool
zpool set cachefile=/etc/zfs/zpool.cache rpool

zfs list -t filesystem -o name,mountpoint,canmount > /dev/null

zfs set canmount=noauto rpool/ROOT/debian
zfs set canmount=noauto bpool/BOOT

rm "$0" # Remove o próprio script ao finalizar

CHROOT_EOF

    chmod +x "/mnt${CHROOT_SCRIPT_PATH}"

    log_info "Entrando no ambiente chroot para a configuração final..."
    # Passa as variáveis como argumentos para o script
    chroot /mnt bash "${CHROOT_SCRIPT_PATH}" "$BOOT_CHOICE" "${SELECTED_DISKS[@]}"

    log_success "Configuração no chroot concluída."
}

#=======================================================================================
# Limpeza final: desmonta todos os sistemas de arquivos e exporta os pools ZFS
# para garantir um desligamento limpo antes do primeiro boot.
#=======================================================================================

function finalizar_instalacao() {

    exibir_cabecalho "8. Finalizando a Instalação"

    # Verificar e forçar desmontagem
    umount -lf /mnt/boot/efi 2>/dev/null || true
    umount -lf /mnt/boot 2>/dev/null || true
    umount -lR /mnt/dev 2>/dev/null || true
    umount -lR /mnt/proc 2>/dev/null || true
    umount -lR /mnt/sys 2>/dev/null || true


    # === Desmonta todos os sistemas de arquivos montados em /mnt:

    mount | grep -w /mnt | awk '{print $3}' | sort -r | xargs -r umount -l
    
    zfs umount -a || true
    
    zpool export -a # === Exporta os pools

    echo
    echo "*****************************************************"
    echo "**                                                 **"
    echo "** Instalação concluída com sucesso!               **"
    echo "**                                                 **"
    echo "** Lembre-se de remover a mídia de instalação      **"
    echo "** antes de reiniciar o sistema.                   **"
    echo "**                                                 **"
    echo "*****************************************************"
    echo
}

# --- Função Principal de Execução ---

function main() {

    # 0. Pre-install:
    check_root
    configure_locale
    detect_boot_mode
    config_repository
    install_dependency
    config_timesync

    # 1. Detecta e permite a seleção dos discos
    local available_disks
    available_disks=$(detectar_discos)
    selecionar_discos_usuario "$available_disks"

    # 2. Obtém as configurações de boot, criptografia e RAID
    obter_configuracoes_usuario

    # 3. Pede a confirmação final antes de apagar os dados
    confirmar_operacao_destrutiva

    # 4. Limpa e particiona os discos selecionados
    limpar_e_particionar_discos

    # 5. Cria os pools ZFS (bpool e rpool)
    criar_pools_zfs

    # 6. Instala o sistema Debian base com debootstrap
    instalar_sistema_base

    # 7. Configura o sistema dentro do ambiente chroot
    configurar_sistema_chroot

    # 8. Desmonta os pools e finaliza
    finalizar_instalacao
}

# --- Ponto de Entrada do Script ---
# A execução do script começa aqui, chamando a função principal.
main
