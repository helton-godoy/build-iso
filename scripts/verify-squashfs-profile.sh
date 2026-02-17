#!/usr/bin/env bash
# @DEV_SCRIPT_ID: verify-squashfs-profile
# @DEV_SCRIPT_FLOW: valida perfil esperado vs artefato squashfs
# @DEV_SCRIPT_DESC: Garante consistência do perfil de compressão squashfs.

set -euo pipefail

squashfs_file="${SQUASHFS_FILE:-live-build-workspace/binary/live/filesystem.squashfs}"
profile_file="${SQUASHFS_PROFILE_FILE:-output/metrics/squashfs-profile.env}"
expected="${EXPECTED_SQUASHFS_COMPRESSION_TYPE:-}"

if [[ -f "$profile_file" ]]; then
  # shellcheck disable=SC1090
  source "$profile_file"
fi

if [[ -z "$expected" ]]; then
  expected="${SQUASHFS_COMPRESSION_TYPE:-}"
fi

if [[ -z "$expected" ]]; then
  printf '[ERR] tipo de compressão esperado não definido.\n' >&2
  exit 1
fi

if [[ ! -f "$squashfs_file" ]]; then
  printf '[ERR] arquivo squashfs não encontrado: %s\n' "$squashfs_file" >&2
  exit 1
fi

if ! command -v unsquashfs >/dev/null 2>&1; then
  printf '[ERR] unsquashfs não encontrado para validação de perfil.\n' >&2
  exit 1
fi

actual="$(unsquashfs -s "$squashfs_file" | awk -F': *' '/Compression/{print tolower($2); exit}')"

if [[ -z "$actual" ]]; then
  printf '[ERR] não foi possível detectar compressão do squashfs.\n' >&2
  exit 1
fi

if [[ "$actual" != "${expected,,}" ]]; then
  printf '[ERR] compressão divergente: esperado=%s atual=%s\n' "$expected" "$actual" >&2
  exit 1
fi

printf '[OK] perfil squashfs validado: %s\n' "$actual"
