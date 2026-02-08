#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/core-utils.sh"
STATE="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/state-utils.sh"
PLAN="${ROOT_DIR}/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/install-plan-utils.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export STATE_DIR="$TMP_DIR"
export STATE_FILE="$TMP_DIR/state.env"

source "$CORE"
source "$STATE"
source "$PLAN"

echo "[1/4] gravar e ler valor com espaços"
state_kv_set install_user_fullname "helton godoy junior"
got="$(state_kv_get install_user_fullname)"
[[ "$got" == "helton godoy junior" ]]

echo "[2/4] carregar estado legado malformado sem quebrar"
printf 'legacy_name=ana maria\n' >"$STATE_FILE"
state_load
[[ "${legacy_name-}" == "ana maria" ]]

echo "[3/4] gerar assinatura de plano"
state_kv_set install_disk "/dev/vda"
state_kv_set install_disks "/dev/vda,/dev/vdb"
state_kv_set zfs_pool_name "zpool"
state_kv_set zfs_compression "zstd"
state_kv_set zfs_dedup "off"
plan_set_data_topology "mirror"
plan_set_data_vdevs "type=mirror,disks=/dev/vda,/dev/vdb"
sig="$(plan_signature)"
[[ -n "$sig" ]]

echo "[4/4] idempotência de escrita de chave"
state_kv_set install_disk "/dev/vdc"
got2="$(state_kv_get install_disk)"
[[ "$got2" == "/dev/vdc" ]]

echo "PASS: test_install_plan_state.sh"
