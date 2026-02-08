#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/core-utils.sh"
STATE="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/state-utils.sh"
PLAN="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/install-plan-utils.sh"
INSTALL_STEP="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/install.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export STATE_DIR="$TMP_DIR"
export STATE_FILE="$TMP_DIR/state.env"
export PROJECT_BOOT_ID="debian"

source "$CORE"
source "$STATE"
source "$PLAN"
source "$INSTALL_STEP"

ui_error() { printf 'ui_error: %s\n' "$*" >&2; }

echo "[1/3] preflight deve passar com assinatura consistente"
state_kv_set install_disk "/dev/vda"
state_kv_set install_disks "/dev/vda,/dev/vdb,/dev/vdc"
state_kv_set zfs_pool_name "zpool"
state_kv_set zfs_topology "raidz1"
state_kv_set zfs_compression "zstd"
state_kv_set zfs_dedup "off"
plan_set_data_vdevs "type=raidz1,disks=/dev/vda,/dev/vdb,/dev/vdc"
sig="$(plan_signature)"
state_kv_set install_plan_review_sig "$sig"
install_plan_preflight "raidz1" 3

echo "[2/3] preflight deve falhar com assinatura divergente"
state_kv_set zfs_compression "lz4"
if install_plan_preflight "raidz1" 3; then
	echo "FAIL: preflight deveria falhar por divergência de assinatura"
	exit 1
fi

echo "[3/3] preflight deve falhar por topologia inválida"
if install_plan_preflight "raidz2" 2; then
	echo "FAIL: raidz2 com 2 discos deveria falhar"
	exit 1
fi

echo "PASS: test_installer_flow_consistency.sh"
