#!/usr/bin/env bash
#
# test_iso_qemu.sh - Teste de boot da ISO com QEMU (sem libvirt)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISO_PATH="${PROJECT_DIR}/output/live-image-amd64.hybrid.iso"
TEST_DIR="${PROJECT_DIR}/scripts/vm/disks"
LOG_FILE="${PROJECT_DIR}/logs/test_qemu.log"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
	echo -e "${GREEN}[TEST]${NC} $*"
}

error() {
	echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Verifica pré-requisitos
check_prerequisites() {
	log "Verificando pré-requisitos..."

	if [[ ! -f "$ISO_PATH" ]]; then
		error "ISO não encontrada: $ISO_PATH"
		exit 1
	fi

	if ! command -v qemu-system-x86_64 &>/dev/null; then
		error "qemu-system-x86_64 não encontrado"
		exit 1
	fi

	if [[ ! -r /dev/kvm ]]; then
		log "AVISO: /dev/kvm não disponível, VM será lenta"
	fi

	mkdir -p "$TEST_DIR"/{uefi,bios}
	log "✓ Pré-requisitos OK"
}

# Cria disco de teste
create_test_disk() {
	local mode="$1"
	local disk_path="${TEST_DIR}/${mode}/test-disk.qcow2"

	if [[ ! -f "$disk_path" ]]; then
		log "Criando disco de teste (${mode}): 20GB"
		qemu-img create -f qcow2 "$disk_path" 20G
	else
		log "Disco já existe: $disk_path"
	fi

	echo "$disk_path"
}

# Testa boot UEFI
test_uefi() {
	log "=== Teste de Boot UEFI ==="

	local disk
	disk=$(create_test_disk "uefi")

	# Verifica se OVMF está disponível
	local ovmf_path="/usr/share/OVMF/OVMF_CODE.fd"
	if [[ ! -f "$ovmf_path" ]]; then
		ovmf_path="/usr/share/qemu/OVMF.fd"
	fi

	if [[ ! -f "$ovmf_path" ]]; then
		log "AVISO: OVMF não encontrado, usando modo BIOS para teste"
		return 1
	fi

	log "Iniciando VM UEFI (timeout: 60s)..."

	# Inicia VM em background
	timeout 60 qemu-system-x86_64 \
		-name "test-uefi" \
		-m 2048 \
		-smp 2 \
		-enable-kvm 2>/dev/null || true \
		-bios "$ovmf_path" \
		-cdrom "$ISO_PATH" \
		-drive file="$disk",format=qcow2,if=virtio \
		-netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
		-nographic \
		-serial mon:stdio \
		-no-reboot \
		2>&1 | tee -a "$LOG_FILE" | head -100 &

	local vm_pid=$!
	sleep 30

	# Verifica se VM ainda está rodando
	if kill -0 $vm_pid 2>/dev/null; then
		log "✓ VM UEFI iniciou com sucesso (PID: $vm_pid)"
		kill $vm_pid 2>/dev/null || true
		wait $vm_pid 2>/dev/null || true
		return 0
	else
		error "✗ VM UEFI falhou ao iniciar"
		return 1
	fi
}

# Testa boot BIOS
test_bios() {
	log "=== Teste de Boot BIOS ==="

	local disk
	disk=$(create_test_disk "bios")

	log "Iniciando VM BIOS (timeout: 60s)..."

	# Inicia VM em background
	timeout 60 qemu-system-x86_64 \
		-name "test-bios" \
		-m 2048 \
		-smp 2 \
		-enable-kvm 2>/dev/null || true \
		-cdrom "$ISO_PATH" \
		-drive file="$disk",format=qcow2,if=virtio \
		-netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
		-nographic \
		-serial mon:stdio \
		-no-reboot \
		2>&1 | tee -a "$LOG_FILE" | head -100 &

	local vm_pid=$!
	sleep 30

	# Verifica se VM ainda está rodando
	if kill -0 $vm_pid 2>/dev/null; then
		log "✓ VM BIOS iniciou com sucesso (PID: $vm_pid)"
		kill $vm_pid 2>/dev/null || true
		wait $vm_pid 2>/dev/null || true
		return 0
	else
		error "✗ VM BIOS falhou ao iniciar"
		return 1
	fi
}

# Valida estrutura da ISO
validate_iso() {
	log "=== Validação da ISO ==="

	local iso_size
	iso_size=$(stat -c%s "$ISO_PATH")

	log "Tamanho da ISO: $((iso_size / 1024 / 1024))MB"

	if [[ $iso_size -lt 1000000000 ]]; then
		error "ISO muito pequena (esperado >1GB)"
		return 1
	fi

	# Verifica conteúdo
	if command -v isoinfo &>/dev/null; then
		log "Verificando estrutura da ISO..."
		isoinfo -l -i "$ISO_PATH" 2>/dev/null | head -50 || true
	fi

	log "✓ ISO validada"
	return 0
}

# Menu principal
main() {
	log "Iniciando testes de ISO com QEMU"
	log "ISO: $ISO_PATH"

	check_prerequisites
	validate_iso

	echo
	read -p "Deseja testar boot UEFI? (s/N): " test_uefi_answer
	if [[ "$test_uefi_answer" =~ ^[Ss]$ ]]; then
		test_uefi || true
	fi

	echo
	read -p "Deseja testar boot BIOS? (s/N): " test_bios_answer
	if [[ "$test_bios_answer" =~ ^[Ss]$ ]]; then
		test_bios || true
	fi

	log "=== Testes concluídos ==="
	log "Log salvo em: $LOG_FILE"
}

# Se executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
