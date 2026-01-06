#!/usr/bin/env bash
#
# test-iso.sh - Testa a ISO gerada usando QEMU
#

set -euo pipefail

# Diretório onde a ISO é gerada pelo pipeline Docker
DIST_DIR="docker/artifacts/dist"
MEM="2G"
CPUS="2"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

OVMF_PATH=""

check_dependencies() {
    local missing=0

    echo -e "${GREEN}[INFO]${NC} Verificando dependências..."

    if ! command -v qemu-system-x86_64 &> /dev/null; then
        echo -e "${RED}[ERRO]${NC} qemu-system-x86_64 não encontrado. Instale o pacote 'qemu-system-x86'."
        missing=$((missing + 1))
    fi

    if [[ ! -e /dev/kvm ]]; then
        echo -e "${YELLOW}[AVISO]${NC} /dev/kvm não encontrado. A VM rodará sem aceleração de hardware (KVM)."
    fi

    # Caminhos comuns do OVMF em Debian/Ubuntu
    local ovmf_paths=(
        "/usr/share/OVMF/OVMF_CODE.fd"
        "/usr/share/ovmf/OVMF.fd"
        "/usr/share/qemu/OVMF.fd"
        "/usr/share/OVMF/OVMF.fd"
    )

    for path in "${ovmf_paths[@]}"; do
        if [[ -f "$path" ]]; then
            OVMF_PATH="$path"
            break
        fi
    done

    if [[ -z "$OVMF_PATH" ]]; then
        echo -e "${YELLOW}[AVISO]${NC} Binário OVMF não encontrado. Boot UEFI não funcionará."
    else
        echo -e "${GREEN}[OK]${NC} OVMF encontrado em: $OVMF_PATH"
    fi

    return $missing
}

show_usage() {
    cat <<EOF
Uso: $(basename "$0") [Opções] [uefi|bios]

Opções:
    --check-deps            Apenas verifica se as dependências estão instaladas e sai
    --create-disk FILE      Cria um disco virtual QCOW2 de 20GB no caminho especificado
    --disk FILE             Usa o disco especificado (anexa à VM)
    --dry-run               Apenas imprime o comando QEMU que seria executado
    uefi                    Testa boot usando UEFI (requer OVMF instalado)
    bios                    Testa boot usando Legacy BIOS (padrão)
EOF
}

run_qemu() {
    local mode="${1:-bios}"
    local qemu_args=(
        "-m" "$MEM"
        "-smp" "$CPUS"
        "-cdrom" "$ISO_FILE"
        "-boot" "d"
        "-net" "nic" "-net" "user"
        "-vga" "virtio"
    )

    # Adicionar suporte a KVM se disponível
    if [[ -e /dev/kvm ]]; then
        qemu_args+=("-enable-kvm" "-cpu" "host")
    fi

    # Anexar disco se especificado
    if [[ -n "$DISK_FILE" ]]; then
        qemu_args+=("-drive" "file=$DISK_FILE,format=qcow2,if=virtio")
    fi

    if [[ "$mode" == "uefi" ]]; then
        echo -e "${GREEN}[INFO]${NC} Iniciando em modo UEFI..."
        if [[ -n "$OVMF_PATH" ]]; then
            if [[ "$OVMF_PATH" == *"OVMF_CODE.fd" ]]; then
                qemu_args+=("-drive" "if=pflash,format=raw,readonly=on,file=$OVMF_PATH")
            else
                qemu_args+=("-bios" "$OVMF_PATH")
            fi
        else
            echo -e "${RED}[ERRO]${NC} UEFI solicitado mas OVMF não encontrado. Abortando."
            exit 1
        fi
    else
        echo -e "${GREEN}[INFO]${NC} Iniciando em modo Legacy BIOS..."
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "qemu-system-x86_64 ${qemu_args[*]}"
        return 0
    fi

    echo -e "${GREEN}[INFO]${NC} Pressione Ctrl+C para encerrar o QEMU."
    qemu-system-x86_64 "${qemu_args[@]}"
}

# Parsing simplificado de argumentos
CHECK_ONLY=false
CREATE_DISK=""
DISK_FILE=""
DRY_RUN=false
MODE="bios"

while [[ $# -gt 0 ]]; do
    case $1 in
        --check-deps)
            CHECK_ONLY=true
            shift
            ;;
        --create-disk)
            CREATE_DISK="$2"
            DISK_FILE="$2"
            shift 2
            ;;
        --disk)
            DISK_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        uefi|bios)
            MODE="$1"
            shift
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
done

if [[ "$CHECK_ONLY" == "true" ]]; then
    check_dependencies
    exit $?
fi

check_dependencies || true # Não aborta se apenas o KVM estiver faltando, mas qemu existir

if [[ -n "$CREATE_DISK" ]]; then
    if [[ -f "$CREATE_DISK" ]]; then
        echo -e "${YELLOW}[AVISO]${NC} Disco '$CREATE_DISK' já existe. Pulando criação."
    else
        echo -e "${GREEN}[INFO]${NC} Criando disco virtual de 20GB em: $CREATE_DISK"
        qemu-img create -f qcow2 "$CREATE_DISK" 20G
    fi
fi

ISO_FILE=$(ls "$DIST_DIR"/*.iso 2>/dev/null | head -n 1) || ISO_FILE=""

if [[ "$DRY_RUN" == "false" ]]; then
    if [[ -z "$ISO_FILE" ]]; then
        echo -e "${RED}[ERRO]${NC} Nenhuma ISO encontrada em $DIST_DIR/."
        exit 1
    fi
    echo -e "${GREEN}[INFO]${NC} Testando ISO: $ISO_FILE"
else
    # Para o dry-run não falhar sem a ISO
    if [[ -z "$ISO_FILE" ]]; then
        ISO_FILE="DUMMY_ISO"
    fi
fi

run_qemu "$MODE"