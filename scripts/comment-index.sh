#!/usr/bin/env bash
# @DEV_SCRIPT: comment-index - Gera índice semântico e grafo Mermaid
# @DEV_CATEGORY: docs
# @DEV_DEP: bash, find, awk, python3
# @DEV_INPUT: --root, --out-dir, --format
# @DEV_OUTPUT: comment-index.txt, comment-index.jsonl, comment-flow.mmd
set -euo pipefail

ROOT="${ROOT:-.}"
OUT_DIR="${OUT_DIR:-output/comment-index}"
FORMAT="${FORMAT:-all}"

usage() {
	cat <<'EOF'
Usage: scripts/comment-index.sh [--root PATH] [--out-dir DIR] [--format all|index|graph]

Outputs:
  <out-dir>/comment-index.txt
  <out-dir>/comment-index.jsonl
  <out-dir>/comment-flow.mmd
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--root)
		ROOT="$2"
		shift 2
		;;
	--out-dir)
		OUT_DIR="$2"
		shift 2
		;;
	--format)
		FORMAT="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		printf 'Unknown argument: %s\n' "$1" >&2
		usage
		exit 2
		;;
	esac
done

mkdir -p "$OUT_DIR"

tmp_files="$(mktemp)"
(find "$ROOT" -type f -name "*.sh" \
	-not -path "*/.git/*" \
	-not -path "*/live-build-workspace/*" \
	-not -path "*/archived/*" \
	-not -path "*/.opencode/*" \
	-not -path "*/output/*" \
	2>/dev/null || true) |
	sort >"$tmp_files"

index_txt="$OUT_DIR/comment-index.txt"
index_jsonl="$OUT_DIR/comment-index.jsonl"
flow_mmd="$OUT_DIR/comment-flow.mmd"

generate_index() {
	: >"$index_txt"
	while IFS= read -r f; do
		rel="${f#"${ROOT}"/}"
		awk -v file="$rel" '
      match($0, /^[[:space:]]*#[[:space:]]*@([A-Z_]+):[[:space:]]*(.*)$/, m) {
        printf "%s:%d:@%s:%s\n", file, NR, m[1], m[2]
      }
    ' "$f" >>"$index_txt"
	done <"$tmp_files"

	python3 - "$index_txt" "$index_jsonl" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding='utf-8') as fin, open(dst, 'w', encoding='utf-8') as fout:
    for raw in fin:
        raw = raw.rstrip('\n')
        if not raw:
            continue
        file, line, tag, value = raw.split(':', 3)
        obj = {
            'file': file,
            'line': int(line),
            'tag': tag,
            'value': value,
        }
        fout.write(json.dumps(obj, ensure_ascii=False) + '\n')
PY
}

generate_graph() {
	python3 - "$tmp_files" "$flow_mmd" <<'PY'
import re
import sys

files_path, out_path = sys.argv[1], sys.argv[2]

tag_re = re.compile(r'^\s*#\s*@([A-Z_]+):\s*(.*)\s*$')

nodes = {}
edges = set()

def norm_id(v: str) -> str:
    return re.sub(r'[^A-Za-z0-9_:-]', '_', v.strip())

def add_req_edge(a: str, b: str):
    if a and b and a not in ('-', 'none', 'null') and b not in ('-', 'none', 'null'):
        edges.add((a, b, 'req'))

def add_fail_edge(a: str, b: str):
    if a and b and b not in ('-', 'none', 'null'):
        edges.add((a, b, 'fail'))

with open(files_path, encoding='utf-8') as f:
    files = [ln.strip() for ln in f if ln.strip()]

for path in files:
    current_id = None
    current_inst = None

    with open(path, encoding='utf-8') as fin:
        for line in fin:
            m = tag_re.match(line)
            if not m:
                continue
            tag, val = m.group(1), m.group(2).strip()

            if tag == 'ID':
                current_id = norm_id(val)
                nodes.setdefault(current_id, current_id)
            elif tag == 'STEP' and current_id:
                nodes[current_id] = val
            elif tag == 'REQ' and current_id:
                for item in [x.strip() for x in val.split(',') if x.strip()]:
                    add_req_edge(norm_id(item), current_id)
            elif tag == 'FAIL' and current_id:
                for item in [x.strip() for x in val.split(',') if x.strip()]:
                    add_fail_edge(current_id, norm_id(item))

            elif tag == 'INST_STEP_ID':
                current_inst = norm_id(val)
                nodes.setdefault(current_inst, current_inst)
            elif tag in ('INST_STEP_DESC', 'INST_DESC') and current_inst:
                if nodes.get(current_inst, current_inst) == current_inst:
                    nodes[current_inst] = val
            elif tag == 'INST_STEP_FLOW' and current_inst:
                prev = ''
                nxt = ''
                for token in val.split():
                    if token.startswith('prev='):
                        prev = token.split('=', 1)[1]
                    elif token.startswith('next='):
                        nxt = token.split('=', 1)[1]
                if prev:
                    add_req_edge(norm_id(prev), current_inst)
                if nxt:
                    add_req_edge(current_inst, norm_id(nxt))

with open(out_path, 'w', encoding='utf-8') as out:
    out.write('graph TD\n')
    for node_id in sorted(nodes):
        label = nodes[node_id].replace('"', "'")
        out.write(f'  {node_id}["{label}"]\n')
    for a, b, et in sorted(edges):
        if et == 'fail':
            out.write(f'  {a} -. FAIL .-> {b}\n')
        else:
            out.write(f'  {a} --> {b}\n')
PY
}

case "$FORMAT" in
all)
	generate_index
	generate_graph
	;;
index)
	generate_index
	;;
graph)
	generate_graph
	;;
*)
	printf 'Formato inválido: %s\n' "$FORMAT" >&2
	exit 2
	;;
esac

rm -f "$tmp_files"
printf '✅ Índice gerado em %s\n' "$OUT_DIR"
