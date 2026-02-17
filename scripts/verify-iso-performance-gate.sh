#!/usr/bin/env bash
# @DEV_SCRIPT_ID: verify-iso-performance-gate
# @DEV_SCRIPT_FLOW: compara baseline/current e aplica limites de regressão
# @DEV_SCRIPT_DESC: Gate de performance da ISO com métricas versionadas.

set -euo pipefail

MAX_ISO_SIZE_GROWTH_PCT="${MAX_ISO_SIZE_GROWTH_PCT:-10}"
MAX_BUILD_TIME_REGRESSION_PCT="${MAX_BUILD_TIME_REGRESSION_PCT:-15}"
MAX_BOOT_TIME_REGRESSION_PCT="${MAX_BOOT_TIME_REGRESSION_PCT:-15}"
MAX_INSTALL_TIME_REGRESSION_PCT="${MAX_INSTALL_TIME_REGRESSION_PCT:-15}"

shopt -s nullglob
baseline_files=(output/iso-metrics/baseline*.json)
shopt -u nullglob

if [[ ${#baseline_files[@]} -eq 0 ]]; then
  printf '[ERR] nenhum arquivo baseline encontrado em output/iso-metrics/.\n' >&2
  exit 1
fi

python3 - <<'PY'
import json
import os
import sys
from pathlib import Path

metrics_dir = Path("output/iso-metrics")
baseline_files = sorted(metrics_dir.glob("baseline*.json"))
if not baseline_files:
    print("[ERR] nenhum baseline encontrado")
    sys.exit(1)

thresholds = {
    "iso_size_bytes": float(os.environ["MAX_ISO_SIZE_GROWTH_PCT"]),
    "build_time_seconds": float(os.environ["MAX_BUILD_TIME_REGRESSION_PCT"]),
    "boot_time_seconds": float(os.environ["MAX_BOOT_TIME_REGRESSION_PCT"]),
    "install_time_seconds": float(os.environ["MAX_INSTALL_TIME_REGRESSION_PCT"]),
}

failures = []
checks = []

for baseline_path in baseline_files:
    suffix = baseline_path.name[len("baseline") : -len(".json")]
    current_path = metrics_dir / f"current{suffix}.json"
    if not current_path.exists():
        failures.append(f"par ausente: {current_path.name} para {baseline_path.name}")
        continue

    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    current = json.loads(current_path.read_text(encoding="utf-8"))
    scope = suffix or "-all"

    for key, threshold in thresholds.items():
        base_val = baseline.get(key)
        curr_val = current.get(key)
        if base_val in (None, "", 0) or curr_val in (None, ""):
            checks.append(f"[WARN] {scope} {key}: métrica ausente, gate não aplicado")
            continue

        growth_pct = ((float(curr_val) - float(base_val)) / float(base_val)) * 100.0
        checks.append(
            f"[INFO] {scope} {key}: base={base_val} atual={curr_val} variacao={growth_pct:.2f}% limite={threshold:.2f}%"
        )
        if growth_pct > threshold:
            failures.append(f"{scope} {key} excedeu limite ({growth_pct:.2f}% > {threshold:.2f}%)")

for line in checks:
    print(line)

if failures:
    print("[ERR] gate de performance reprovado:")
    for item in failures:
        print(f"  - {item}")
    sys.exit(1)

print("[OK] gate de performance aprovado")
PY
