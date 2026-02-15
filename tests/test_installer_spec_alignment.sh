#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZBM_LIB="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/zbm-install.sh"
DISK_LIB="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/disk-utils.sh"
WELCOME_STEP="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/welcome.sh"
POST_INSTALL_STEP="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/post_install.sh"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local desc="$3"

  if grep -Eq "$pattern" "$file"; then
    echo "✓ ${desc}"
  else
    echo "✗ ${desc}"
    echo "  Arquivo: ${file}"
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local desc="$3"

  if grep -Eq "$pattern" "$file"; then
    echo "✗ ${desc}"
    echo "  Arquivo: ${file}"
    exit 1
  else
    echo "✓ ${desc}"
  fi
}

echo "=== Validação estática de aderência do instalador ==="

assert_contains "$DISK_LIB" '^MIN_DISK_SIZE_GB=20$' \
  "Filtro mínimo de disco configurado para 20GB"

assert_contains "$WELCOME_STEP" 'Modo: \$\(firmware_get_mode\)' \
  "Welcome exibe modo de firmware dinamicamente"

assert_contains "$ZBM_LIB" 'root=zfs:\$\{pool\}/ROOT/debian' \
  "Cmdline ZBM inclui root=zfs para dataset bootável"

assert_contains "$ZBM_LIB" 'org\.zfsbootmenu:commandline="\$cmdline" "\$\{pool\}/ROOT/debian"' \
  "Cmdline aplicado no dataset ROOT/debian"

assert_contains "$POST_INSTALL_STEP" 'zbm_configure_bios "\$disk" "\$part_efi" "\$target"' \
  "Pós-instalação chama configuração de boot BIOS"

assert_not_contains "$POST_INSTALL_STEP" 'zbm_configure_bios .*\|\| true' \
  "Falhas de boot BIOS não são mascaradas com || true"

echo "=== OK: requisitos estáticos atendidos ==="
