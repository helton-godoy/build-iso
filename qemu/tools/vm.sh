#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# vm.sh - Gerenciador de VM para Testes da ISO
#
# Suporta boot UEFI e BIOS (Legacy).
# Requer: qemu-system-x86_64, ovmf (para UEFI)
# ==============================================================================

# Diretórios
ISO_DIR="docker/dist"
VM_WORK_DIR="work/vm"

# Função para detectar OVMF
find_ovmf() {
    local type=$1 # CODE ou VARS
    local paths
    
    if [ "$type" == "CODE" ]; then
        paths=(
            "/usr/share/OVMF/OVMF_CODE_4M.fd"
            "/usr/share/OVMF/OVMF_CODE.fd"
            "/usr/share/ovmf/OVMF.fd"
            "/usr/share/qemu/OVMF.fd"
        )
    else
        paths=(
            "/usr/share/OVMF/OVMF_VARS_4M.fd"
            "/usr/share/OVMF/OVMF_VARS.fd"
            "/usr/share/ovmf/OVMF_VARS.fd"
        )
    fi

    for p in "${paths[@]}"; do
        if [ -f "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

# Tenta localizar os arquivos agora
OVMF_CODE=$(find_ovmf CODE || echo "")
OVMF_VARS=$(find_ovmf VARS || echo "")

# Configurações da VM (Padrões)
VM_MEMORY="4G"
VM_CPUS="2"
DISK_SIZE="20G"
VM_VGA="virtio-vga"
TEMPLATE_FILE="qemu/template-vm.json"

read_config() {
    if [ -f "$TEMPLATE_FILE" ] && command -v jq &> /dev/null; then
        echo "Lendo configurações de $TEMPLATE_FILE..."
        VM_MEMORY=$(jq -r '.memory // "4G"' "$TEMPLATE_FILE")
        VM_CPUS=$(jq -r '.cpus // 2' "$TEMPLATE_FILE")
        DISK_SIZE=$(jq -r '.disk_size // "20G"' "$TEMPLATE_FILE")
        VM_VGA=$(jq -r '.vga_device // "virtio-vga"' "$TEMPLATE_FILE")
    else
        echo "Usando configurações padrão (Template não encontrado ou jq ausente)."
    fi
}

DISK_IMG="$VM_WORK_DIR/disk.qcow2"

mkdir -p "$VM_WORK_DIR"

function usage() {
    echo "Uso: $0 [OPÇÃO]"
    echo ""
    echo "Opções:"
    echo "  --check        Verifica e instala dependências necessárias"
    echo "  --start-uefi   Inicia a VM em modo UEFI com a ISO mais recente"
    echo "  --start-bios   Inicia a VM em modo BIOS (Legacy) com a ISO mais recente"
    echo "  --clean        Remove disco e estados da VM"
    echo "  --help         Exibe esta ajuda"
    exit 1
}

function install_deps() {
    local packages=("$@")
    echo "Tentando instalar dependências faltantes: ${packages[*]}"
    
    if ! command -v sudo &> /dev/null; then
        echo "ERRO: 'sudo' não encontrado. Instale manualmente: ${packages[*]}"
        return 1
    fi

    echo "Solicitando permissão de superusuário..."
    if sudo apt-get update && sudo apt-get install -y "${packages[@]}"; then
        echo "Instalação concluída com sucesso."
        return 0
    else
        echo "ERRO: Falha na instalação automática."
        return 1
    fi
}

function check_deps() {
    echo "Verificando dependências..."
    local missing_pkgs=()
    
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        echo " [X] qemu-system-x86_64 não encontrado."
        missing_pkgs+=("qemu-system-x86" "qemu-utils")
    else
        echo " [OK] qemu-system-x86_64"
    fi

    if ! command -v jq &> /dev/null; then
        echo " [X] jq não encontrado (necessário para ler template)."
        missing_pkgs+=("jq")
    else
        echo " [OK] jq"
    fi

    if [ -z "$OVMF_CODE" ]; then
        echo " [X] Arquivo OVMF não encontrado."
        missing_pkgs+=("ovmf")
    else
        echo " [OK] OVMF (UEFI Firmware): $OVMF_CODE"
    fi

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo "Dependências faltantes detectadas."
        install_deps "${missing_pkgs[@]}"
        
        # Re-check após tentativa de instalação
        echo "Reverificando..."
        local recheck_fail=0
        if ! command -v qemu-system-x86_64 &> /dev/null; then recheck_fail=1; fi
        if ! command -v jq &> /dev/null; then recheck_fail=1; fi
        
        # Tenta encontrar novamente
        OVMF_CODE=$(find_ovmf CODE || echo "")
        if [ -z "$OVMF_CODE" ]; then recheck_fail=1; fi
        
        if [ $recheck_fail -eq 0 ]; then
            echo "Todas as dependências foram resolvidas!"
        else
            echo "Ainda faltam dependências. Por favor verifique manualmente."
            exit 1
        fi
    else
        echo "Todas as dependências satisfeitas."
    fi
}

function get_latest_iso() {
    local iso
    iso=$(ls -t "$ISO_DIR"/*.iso 2>/dev/null | head -n 1)
    if [ -z "$iso" ]; then
        echo "ERRO: Nenhuma ISO encontrada em $ISO_DIR."
        echo "Execute 'make build' primeiro."
        exit 1
    fi
    echo "$iso"
}

function prepare_disk() {
    if [ ! -f "$DISK_IMG" ]; then
        echo "Criando disco virtual de $DISK_SIZE em $DISK_IMG..."
        qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
    fi
}

function start_vm() {
    local mode=$1
    read_config
    local iso=$(get_latest_iso)
    
    prepare_disk
    
    echo "Iniciando VM ($mode)..."
    echo "ISO: $iso"
    echo "Disco: $DISK_IMG"
    echo "Memória: $VM_MEMORY | CPUs: $VM_CPUS | VGA: $VM_VGA"
    echo "Pressione Ctrl+C para encerrar a VM."

    local qemu_args=(
        -enable-kvm
        -m "$VM_MEMORY"
        -smp "$VM_CPUS"
        -drive "file=$DISK_IMG,format=qcow2"
        -cdrom "$iso"
        -net nic -net user
        -vga "$VM_VGA"
        -display gtk
    )

    if [ "$mode" == "UEFI" ]; then
        if [ ! -f "$OVMF_VARS" ]; then
             echo "ERRO CRÍTICO: Arquivo de variáveis UEFI ($OVMF_VARS) não encontrado."
             echo "Tente rodar --check novamente."
             exit 1
        fi
        
        # Copia vars para um arquivo temporário local para persistência de variáveis UEFI
        if [ ! -f "$VM_WORK_DIR/OVMF_VARS.fd" ]; then
            cp "$OVMF_VARS" "$VM_WORK_DIR/OVMF_VARS.fd"
        fi
        
        qemu_args+=(
            -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
            -drive "if=pflash,format=raw,file=$VM_WORK_DIR/OVMF_VARS.fd"
        )
    fi

    qemu-system-x86_64 "${qemu_args[@]}"
}

case "${1:-}" in
    --check)
        check_deps
        ;;
    --start-uefi)
        start_vm "UEFI"
        ;;
    --start-bios)
        start_vm "BIOS"
        ;;
    --clean)
        echo "Limpando diretório de trabalho da VM..."
        rm -rf "$VM_WORK_DIR"
        echo "Concluído."
        ;;
    *)
        usage
        ;;
esac