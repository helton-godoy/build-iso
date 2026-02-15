#!/usr/bin/env bash
# @TEST_SCRIPT: test_installer_zfs.sh
# @TEST_CATEGORY: installer-zfs
# @TEST_DESC: Teste de integração ZFS - valida criação de pool, datasets e propriedades
# @TEST_DEP: zfs, zpool, zfs-setup.sh
# @TEST_ENV: TEST_DEVICE=/dev/vda3, POOL_NAME=testzroot
# @TEST_TARGETS: config-overrides/config/includes.chroot/usr/local/lib/installer/libs/zfs-utils.sh
# @TEST_DESTRUCTIVE: true - requer dispositivo de teste
# @TEST_EXIT: 0=ZFS configurado corretamente, 1=falha na criação/verificação

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config-overrides/config/includes.chroot/usr/local/lib/installer/libs/zfs-utils.sh"

TEST_DEVICE="${TEST_DEVICE:-/dev/vda3}"
POOL_NAME="${POOL_NAME:-testzroot}"
LOG_FILE="/tmp/test_zfs.log"

echo "=== Teste de Estrutura ZFS ==="
echo "Dispositivo: $TEST_DEVICE"
echo "Pool: $POOL_NAME"
echo

# Log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "1. Verificando se dispositivo existe..."
if [[ ! -b "$TEST_DEVICE" ]]; then
  echo "ERRO: Dispositivo $TEST_DEVICE não encontrado"
  exit 1
fi
echo "✓ Dispositivo encontrado"
echo

echo "2. Criando pool ZFS..."
zfs_create_pool "$TEST_DEVICE" "$POOL_NAME"
echo "✓ Pool criado"
echo

echo "3. Verificando pool..."
if zfs_pool_exists "$POOL_NAME"; then
  echo "✓ Pool existe"
  zpool list "$POOL_NAME"
else
  echo "ERRO: Pool não encontrado"
  exit 1
fi
echo

echo "4. Criando datasets..."
zfs_create_datasets "$POOL_NAME"
echo "✓ Datasets criados"
echo

echo "5. Listando estrutura..."
zfs_list_datasets "$POOL_NAME"
echo

echo "6. Verificando propriedades..."
echo "zroot/ROOT properties:"
zfs get canmount,mountpoint,org.zfsbootmenu:commandline "${POOL_NAME}/ROOT"
echo

echo "zroot/ROOT/debian properties:"
zfs get canmount,mountpoint,org.zfsbootmenu:commandline "${POOL_NAME}/ROOT/debian"

CMDLINE=$(zfs get -H -o value org.zfsbootmenu:commandline "${POOL_NAME}/ROOT/debian" 2>/dev/null || true)
if [[ "$CMDLINE" != *"root=zfs:"* ]]; then
  echo "ERRO: cmdline ZBM em ROOT/debian sem root=zfs"
  exit 1
fi

echo "✓ cmdline ZBM em ROOT/debian contém root=zfs"
echo

echo "7. Limpando (exportando pool)..."
zfs_export_pool "$POOL_NAME"
echo "✓ Pool exportado"
echo

echo "=== Teste concluído ==="
echo "Log salvo em: $LOG_FILE"
