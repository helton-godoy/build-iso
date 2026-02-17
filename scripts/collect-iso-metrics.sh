#!/usr/bin/env bash
# @DEV_SCRIPT_ID: collect-iso-metrics
# @DEV_SCRIPT_FLOW: mode=baseline|current, output=output/iso-metrics/{mode,mode-firmware}.json
# @DEV_SCRIPT_DESC: Coleta métricas básicas da ISO para baseline e regressão.

set -euo pipefail

mode="current"
iso_file=""
firmware="all"
label="manual"
out_dir="output/iso-metrics"
profile_file="output/metrics/squashfs-profile.env"
build_time_seconds=""
boot_time_seconds=""
install_time_seconds=""
logs_dir="logs"

latest_match() {
	local pattern="$1"
	local matches=()
	local match

	while IFS= read -r match; do
		[[ -n "$match" ]] && matches+=("$match")
	done < <(compgen -G "$pattern" || true)

	if [[ ${#matches[@]} -eq 0 ]]; then
		return 1
	fi

	printf '%s\n' "${matches[@]}" | sort | tail -n1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--mode)
		mode="${2:-}"
		shift 2
		;;
	--iso)
		iso_file="${2:-}"
		shift 2
		;;
	--firmware)
		firmware="${2:-all}"
		shift 2
		;;
	--label)
		label="${2:-manual}"
		shift 2
		;;
	--build-time)
		build_time_seconds="${2:-}"
		shift 2
		;;
	--boot-time)
		boot_time_seconds="${2:-}"
		shift 2
		;;
	--install-time)
		install_time_seconds="${2:-}"
		shift 2
		;;
	--logs-dir)
		logs_dir="${2:-logs}"
		shift 2
		;;
	--help | -h)
		cat <<'EOF'
Usage: collect-iso-metrics.sh [--mode baseline|current] [--iso PATH] [--firmware all|uefi|bios] [--label TEXT] [--build-time S] [--boot-time S] [--install-time S] [--logs-dir DIR]
EOF
		exit 0
		;;
	*)
		printf 'Argumento inválido: %s\n' "$1" >&2
		exit 2
		;;
	esac
done

if [[ -z "$iso_file" ]]; then
	shopt -s nullglob
	iso_candidates=(output/*.iso)
	shopt -u nullglob
	if [[ ${#iso_candidates[@]} -gt 0 ]]; then
		iso_file="${iso_candidates[0]}"
	fi
fi

if [[ -z "$iso_file" || ! -f "$iso_file" ]]; then
	printf 'ISO não encontrada. Informe --iso ou gere output/*.iso.\n' >&2
	exit 1
fi

if [[ -z "$build_time_seconds" ]]; then
	latest_build_log="$(latest_match "${logs_dir}"/live-build-*.log || true)"
	if [[ -n "$latest_build_log" && -f "$latest_build_log" ]]; then
		build_time_seconds="$(
			python3 - <<PY
import re
from datetime import datetime

path = "${latest_build_log}"
pattern = re.compile(r"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]")
first = None
last = None
with open(path, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        m = pattern.search(line)
        if not m:
            continue
        ts = datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
        if first is None:
            first = ts
        last = ts

if first is None or last is None:
    print("")
else:
    print(int((last - first).total_seconds()))
PY
		)"
	fi
fi

if [[ "$firmware" != "all" && -z "$boot_time_seconds" ]]; then
	latest_test_log_dir="$(latest_match "${logs_dir}"/test-* || true)"
	if [[ -n "$latest_test_log_dir" && -d "$latest_test_log_dir" ]]; then
		start_log="${latest_test_log_dir}/start-${firmware}.log"
		boot_log="${latest_test_log_dir}/boot-${firmware}.log"
		metrics_log="${latest_test_log_dir}/metrics-${firmware}.json"

		if [[ -f "$metrics_log" ]]; then
			boot_time_seconds="$(
				python3 - <<PY
import json
from pathlib import Path

path = Path("${metrics_log}")
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    data = {}
v = data.get("boot_capture_seconds")
print("" if v is None else int(v))
PY
			)"
		fi

		if [[ -f "$start_log" && -f "$boot_log" ]]; then
			boot_time_seconds="$(
				python3 - <<PY
import os
import re
from datetime import datetime

start_path = "${start_log}"
boot_path = "${boot_log}"
first_ts = None
pattern = re.compile(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})")
with open(start_path, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        m = pattern.search(line)
        if m:
            first_ts = datetime.strptime(m.group(1), "%Y-%m-%dT%H:%M:%S")
            break

if first_ts is None:
    print("")
else:
    end_ts = datetime.fromtimestamp(os.path.getmtime(boot_path))
    delta = int((end_ts - first_ts).total_seconds())
    print(max(delta, 0))
PY
			)"
		fi
	fi
fi

if [[ "$firmware" != "all" && -z "$install_time_seconds" ]]; then
	latest_test_log_dir="$(latest_match "${logs_dir}"/test-* || true)"
	if [[ -n "$latest_test_log_dir" && -d "$latest_test_log_dir" ]]; then
		boot_log="${latest_test_log_dir}/boot-${firmware}.log"
		if [[ -f "$boot_log" ]]; then
			install_time_seconds="$(
				python3 - <<PY
import re
from datetime import datetime

path = "${boot_log}"
start = None
end = None
re_start = re.compile(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}).*Entrando step=install")
re_end = re.compile(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}).*Step concluído: step=install")
with open(path, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        m1 = re_start.search(line)
        if m1 and start is None:
            start = datetime.strptime(m1.group(1), "%Y-%m-%dT%H:%M:%S")
        m2 = re_end.search(line)
        if m2:
            end = datetime.strptime(m2.group(1), "%Y-%m-%dT%H:%M:%S")

if start is None or end is None:
    print("")
else:
    print(max(int((end - start).total_seconds()), 0))
PY
			)"
		fi
	fi
fi

mkdir -p "$out_dir"

size_bytes="$(stat -c '%s' "$iso_file")"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

squashfs_type="unknown"
squashfs_level="unknown"
iso_type="unknown"
if [[ -f "$profile_file" ]]; then
	# shellcheck disable=SC1090
	source "$profile_file"
	squashfs_type="${SQUASHFS_COMPRESSION_TYPE:-unknown}"
	squashfs_level="${SQUASHFS_COMPRESSION_LEVEL:-unknown}"
	iso_type="${ISO_COMPRESSION_TYPE:-unknown}"
fi

python3 - <<PY
import json
from pathlib import Path

def parse_optional_int(raw):
    raw = (raw or "").strip()
    if not raw:
        return None
    return int(raw)

payload = {
    "timestamp": "${timestamp}",
    "mode": "${mode}",
    "label": "${label}",
    "firmware": "${firmware}",
    "iso_path": "${iso_file}",
    "iso_size_bytes": int("${size_bytes}"),
    "build_time_seconds": parse_optional_int("${build_time_seconds}"),
    "boot_time_seconds": parse_optional_int("${boot_time_seconds}"),
    "install_time_seconds": parse_optional_int("${install_time_seconds}"),
    "squashfs_compression_type": "${squashfs_type}",
    "squashfs_compression_level": "${squashfs_level}",
    "iso_compression_type": "${iso_type}",
}

suffix = "" if "${firmware}" == "all" else f"-{'${firmware}'}"
out = Path("${out_dir}") / f"${mode}{suffix}.json"
out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"[OK] métricas salvas em {out}")
PY
