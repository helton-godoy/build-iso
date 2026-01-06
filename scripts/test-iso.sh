#!/usr/bin/env bash
#
# test-iso.sh - Testa a ISO gerada usando QEMU
#

set -euo pipefail

DIST_DIR="dist"
ISO_FILE=$(ls "$DIST_DIR"/*.iso 2>/dev/null | head -n 1)
MEM="2G"
CPUS="2"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [[ -z "$ISO_FILE" ]]; then
    echo -e "${RED}[ERRO]${NC} Nenhuma ISO encontrada em $DIST_DIR/."
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} Testando ISO: $ISO_FILE"

show_usage() {
    cat <<EOF
Uso: $(basename "$0") [uefi|bios]

Opções:
    uefi    Testa boot usando UEFI (requer OVMF instalado)
    bios    Testa boot usando Legacy BIOS (padrão)
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
