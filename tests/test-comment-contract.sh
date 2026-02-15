#!/usr/bin/env bash
# @TEST_SCRIPT: test-comment-contract - Valida contrato PDS-Bash
# @TEST_CATEGORY: validation
# @TEST_DEP: bash, python3
# @TEST_COVERS: docs/COMMENT_PROTOCOL_PDS_BASH.md, tags @ID/@STEP/@REQ/@FAIL
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔍 Validando contrato de comentários PDS-Bash..."

tmp_files="$(mktemp)"
(find "$ROOT_DIR" -type f -name "*.sh" \
  -not -path "*/.git/*" \
  -not -path "*/live-build-workspace/*" \
  -not -path "*/archived/*" \
  -not -path "*/.opencode/*" \
  -not -path "*/output/*" \
  2>/dev/null || true) |
  sort >"$tmp_files"

python3 - "$tmp_files" <<'PY'
import re
import sys

files_list = sys.argv[1]

tag_re = re.compile(r'^\s*#\s*@([A-Z_]+):\s*(.*)\s*$')

ids = {}
errors = []

req_refs = []
fail_refs = []

def norm_id(v: str) -> str:
    return re.sub(r'[^A-Za-z0-9_:-]', '_', v.strip())

with open(files_list, encoding='utf-8') as f:
    files = [ln.strip() for ln in f if ln.strip()]

for path in files:
    current_id = None
    id_has_step = {}
    with open(path, encoding='utf-8') as fin:
        for ln, line in enumerate(fin, 1):
            m = tag_re.match(line)
            if not m:
                continue
            tag, val = m.group(1), m.group(2).strip()

            if tag in ('ID', 'INST_STEP_ID'):
                current_id = norm_id(val)
                key = (path, current_id)
                if current_id in ids:
                    old = ids[current_id]
                    errors.append(f"ID duplicado '{current_id}' em {path}:{ln} (já definido em {old[0]}:{old[1]})")
                else:
                    ids[current_id] = (path, ln)
                if tag == 'ID':
                    id_has_step[current_id] = False

            elif tag == 'STEP' and current_id:
                id_has_step[current_id] = True

            elif tag == 'REQ' and current_id:
                for item in [x.strip() for x in val.split(',') if x.strip()]:
                    req_refs.append((path, ln, current_id, norm_id(item)))

            elif tag == 'FAIL' and current_id:
                for item in [x.strip() for x in val.split(',') if x.strip()]:
                    fail_refs.append((path, ln, current_id, norm_id(item)))

    for _id, has_step in id_has_step.items():
        if not has_step:
            src = ids.get(_id, (path, '?'))
            errors.append(f"@ID '{_id}' sem @STEP correspondente em {src[0]}:{src[1]}")

for path, ln, src, dst in req_refs:
    if dst not in ids:
        errors.append(f"@REQ inválido em {path}:{ln}: '{dst}' não encontrado (origem={src})")

for path, ln, src, dst in fail_refs:
    if dst not in ids:
        errors.append(f"@FAIL inválido em {path}:{ln}: '{dst}' não encontrado (origem={src})")

if errors:
    print("❌ Falhas no contrato PDS-Bash:")
    for e in errors:
        print(f" - {e}")
    sys.exit(1)

print(f"✅ Contrato PDS-Bash válido ({len(ids)} IDs mapeados)")
PY

rm -f "$tmp_files"
