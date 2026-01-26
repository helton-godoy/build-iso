#!/usr/bin/env python3
"""
Smart Commit System v3 - Intent-Based Grouping
==============================================
Groups changes by semantic intent and creates atomic commits per intent group.
Now handles staging automatically.
"""

import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path

# Configurações de Mapeamento Semântico
SCOPE_MAP = {
    "include/usr/local/bin/installer": "installer",
    "scripts": "build",
    "tests": "test",
    "config": "config",
    ".agent": "agent-os",
    "include/usr/share/zfsbootmenu": "zbm",
}

TYPE_MAP = {
    ".md": "docs",
    ".bats": "test",
    ".sh": "feat",
    ".py": "feat",
    ".conf": "chore",
}


def run_command(cmd):
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_changed_files():
    # Detectar Unstaged (Modified + Untracked)
    # --porcelain imprime:  M file.txt (Modified)  ?? newfile.txt (Untracked)
    output = run_command("git status --porcelain")
    files = []
    if output:
        for line in output.splitlines():
            # Pega o caminho do arquivo (segunda coluna em diante)
            path = line[3:].strip()
            # Remove aspas se houver (git retorna nomes com espaços entre aspas)
            path = path.strip('"')
            files.append(path)
    return files


def get_diff_content(file_path):
    # Tenta diff do arquivo no disco vs index (unstaged)
    # Se não houver output, tenta diff cached (se já estiver staged por algum motivo)
    diff = run_command(f"git diff {file_path}")
    if not diff:
        diff = run_command(f"git diff --cached {file_path}")
    return diff


def extract_intent_from_diff(diff):
    if not diff:
        return None
    # Padrão: + # [commit] tipo: mensagem
    pattern = r"^\+\s*[\#\/\/\;\-]+\s*\[commit\]\s*(\w+):\s*(.*)"
    matches = re.findall(pattern, diff, re.MULTILINE)
    return matches


def classify_file(file_path):
    diff = get_diff_content(file_path)

    # 1. Intent Tags (Prioridade Máxima)
    intents = extract_intent_from_diff(diff)
    if intents:
        # Pega a última intenção definida no arquivo
        ctype, msg = intents[-1]
        return ctype, msg, "intent_tag"

    # 2. Heurística
    path = Path(file_path)
    ext = path.suffix
    ctype = TYPE_MAP.get(ext, "chore")

    if diff:
        if any(word in diff.upper() for word in ["FIX", "BUG", "ERROR"]):
            ctype = "fix"
        elif any(word in diff.upper() for word in ["REFACTOR", "OPTIMIZE"]):
            ctype = "refactor"

    return ctype, None, "heuristic"


def get_scope(file_list):
    # Define o escopo dominante de uma lista de arquivos
    scopes = []
    for f in file_list:
        found = False
        for prefix, scope in SCOPE_MAP.items():
            if f.startswith(prefix):
                scopes.append(scope)
                found = True
                break
        if not found:
            scopes.append("core")

    if not scopes:
        return "core"
    return max(set(scopes), key=scopes.count)


def perform_commit(files, ctype, description, context_msg=""):
    print(f"📦 Staging {len(files)} file(s) for '{ctype}: {description}'...")

    # 1. Stage files
    # Usar -- para evitar problemas com nomes de arquivos começando com -
    files_str = " ".join(f'"{f}"' for f in files)
    run_command(f"git add -- {files_str}")

    # 2. Commit
    scope = get_scope(files)
    header = f"{ctype}({scope}): {description}"

    body = context_msg
    body += "\n\n### Semantic Context\nFiles affected:\n"
    for f in files:
        body += f"- {f}\n"

    print(f"🚀 Committing: {header}")
    result = run_command(f'git commit -m "{header}" -m "{body}" --no-verify')

    if result:
        # Log Knowledge
        log_entry = {
            "timestamp": subprocess.check_output(["date", "+%s"]).decode().strip(),
            "type": ctype,
            "scope": scope,
            "files": files,
            "message": header,
        }
        with open(".agent/logs/knowledge_base.jsonl", "a") as log:
            log.write(json.dumps(log_entry) + "\n")
        return True
    return False


def main():
    print("🤖 Agent Smart Commit System v3 (Grouped)")

    changed_files = get_changed_files()
    if not changed_files:
        print("ℹ️ No changes found.")
        return

    print(f"Found {len(changed_files)} changed file(s).")

    # Agrupamento
    # Chave: (tipo, mensagem_explicita) -> Lista de arquivos
    # Se mensagem_explicita for None, agrupa por (tipo, "generic")
    groups = defaultdict(list)

    for f in changed_files:
        ctype, msg, source = classify_file(f)

        if source == "intent_tag":
            # Agrupa pela mensagem exata (ex: todos arquivos da mesma feature taggeada)
            key = (ctype, msg)
        else:
            # Agrupa por tipo genérico
            key = (ctype, None)

        groups[key].append(f)

    # Executar Commits
    for (ctype, msg), files in groups.items():
        if msg:
            # Commit específico (Intent Tag)
            perform_commit(files, ctype, msg)
        else:
            # Commit genérico
            get_scope(files)
            if len(files) == 1:
                desc = f"update {Path(files[0]).name}"
            else:
                desc = f"update {len(files)} files"
            perform_commit(files, ctype, desc)

    print("✅ All groups processed.")


if __name__ == "__main__":
    main()
