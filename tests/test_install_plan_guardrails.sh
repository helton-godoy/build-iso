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

echo "[1/3] bloquear sobreposição de discos dados/auxiliar"
plan_set_data_vdevs "type=raidz1,disks=/dev/vda,/dev/vdb,/dev/vdc"
plan_set_aux_vdev "cache" "single" "/dev/vdb"
if plan_validate_aux_guardrails; then
	echo "FAIL: deveria bloquear sobreposição"
	exit 1
fi

echo "[2/3] exigir mirror de log com 2 discos"
plan_set_aux_vdev "cache" "single" ""
plan_set_aux_vdev "log" "mirror" "/dev/vdd"
if plan_validate_aux_guardrails; then
	echo "FAIL: log mirror com 1 disco deveria falhar"
	exit 1
fi

echo "[3/3] permitir configuração válida"
plan_set_aux_vdev "log" "mirror" "/dev/vdd,/dev/vde"
plan_set_aux_vdev "spare" "single" "/dev/vdf"
plan_validate_aux_guardrails

echo "PASS: test_install_plan_guardrails.sh"
