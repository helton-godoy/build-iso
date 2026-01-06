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
    )

    local ovmf_found=""
    for path in "${ovmf_paths[@]}"; do
        if [[ -f "$path" ]]; then
            ovmf_found="$path"
            break
        fi
    done

    if [[ -z "$ovmf_found" ]]; then
        echo -e "${YELLOW}[AVISO]${NC} Binário OVMF não encontrado. Boot UEFI não funcionará."
    else
        echo -e "${GREEN}[OK]${NC} OVMF encontrado em: $ovmf_found"
    fi

    return $missing
}

show_usage() {
    cat <<EOF
Uso: $(basename "$0") [Opções] [uefi|bios]

Opções:
    --check-deps    Apenas verifica se as dependências estão instaladas e sai
    uefi            Testa boot usando UEFI (requer OVMF instalado)
    bios            Testa boot usando Legacy BIOS (padrão)
EOF
}

# Parsing simplificado de argumentos
CHECK_ONLY=false
MODE="bios"

while [[ $# -gt 0 ]]; do
    case $1 in
        --check-deps)
            CHECK_ONLY=true
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

ISO_FILE=$(ls "$DIST_DIR"/*.iso 2>/dev/null | head -n 1)

if [[ -z "$ISO_FILE" ]]; then
    echo -e "${RED}[ERRO]${NC} Nenhuma ISO encontrada em $DIST_DIR/."
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} Testando ISO: $ISO_FILE"

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

    if [[ "$mode" == "uefi" ]]; then
        echo -e "${GREEN}[INFO]${NC} Iniciando em modo UEFI..."
        # Procurar caminho do OVMF no Debian
        if [[ -f "/usr/share/OVMF/OVMF_CODE.fd" ]]; then
            qemu_args+=("-drive" "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd")
        elif [[ -f "/usr/share/ovmf/OVMF.fd" ]]; then
             qemu_args+=("-bios" "/usr/share/ovmf/OVMF.fd")
        else
            echo -e "${RED}[AVISO]${NC} OVMF não encontrado. O boot UEFI pode falhar."
        fi
    else
        echo -e "${GREEN}[INFO]${NC} Iniciando em modo Legacy BIOS..."
    fi

    echo -e "${GREEN}[INFO]${NC} Pressione Ctrl+C para encerrar o QEMU."
    qemu-system-x86_64 "${qemu_args[@]}"
}

MODE="${1:-bios}"
if [[ "$MODE" != "uefi" && "$MODE" != "bios" ]]; then
    show_usage
    exit 1
fi

run_qemu "$MODE"
