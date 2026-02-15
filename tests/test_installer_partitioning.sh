#!/usr/bin/env bash
#
# test_installer_partitioning.sh - Teste de particionamento em VM
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config-overrides/config/includes.chroot/usr/local/lib/installer/libs/partitioning.sh"
source "${SCRIPT_DIR}/../config-overrides/config/includes.chroot/usr/local/lib/installer/libs/disk-utils.sh"

TEST_DISK="${TEST_DISK:-/dev/vda}"
LOG_FILE="/tmp/test_partitioning.log"

echo "=== Teste de Particionamento ==="
echo "Disco de teste: $TEST_DISK"
echo

# Verifica se disco existe
if [[ ! -b "$TEST_DISK" ]]; then
	echo "ERRO: Disco $TEST_DISK não encontrado"
	echo "Discos disponíveis:"
	disk_list_available || true
	exit 1
fi

# Log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "1. Listando discos disponíveis..."
disk_list_available
echo

echo "2. Limpando disco..."
partition_wipe_disk "$TEST_DISK"
echo "✓ Disco limpo"
echo

echo "3. Criando partições GPT..."
partition_create_gpt "$TEST_DISK"
echo "✓ Partições criadas"
echo

echo "4. Verificando partições..."
partition_info "$TEST_DISK"
echo

echo "5. Formatando ESP..."
partition_format_esp "$(partition_get_esp)"
echo "✓ ESP formatado"
echo

echo "6. Verificando layout..."
partition_verify "$TEST_DISK"
echo

echo "=== Teste concluído ==="
echo "Log salvo em: $LOG_FILE"
