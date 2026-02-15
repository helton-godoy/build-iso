#!/usr/bin/env bash
# =============================================================================
# Validacao de Tags Semanticas
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALLER_DIR="$PROJECT_ROOT/config-overrides/config/includes.chroot/usr/local/lib/installer"

TAGS_REQUIRED="INST_STEP_ID INST_NEXT INST_PREV INST_FAIL INST_DATA INST_REQ"

echo "=============================================="
echo "  RELATORIO DE TAGS SEMANTICAS"
echo "=============================================="
echo ""

echo "Iniciando validacao de tags semanticas..."

total_files=0
files_with_issues=0
issues=""

while read -r file; do
  ((total_files++)) || true
  echo "Verificando: $file"
  
  missing=""
  for tag in $TAGS_REQUIRED; do
    if ! grep -q "@${tag}" "$file" 2>/dev/null; then
      missing="$missing @${tag}"
    fi
  done
  
  if [[ -n "$missing" ]]; then
    ((files_with_issues++)) || true
    issues="$issues\n$file:$missing"
  fi
done < <(find "$INSTALLER_DIR" -name "*.sh" -type f 2>/dev/null)

echo ""
echo "Total de arquivos analisados: $total_files"
echo "Arquivos com issues:         $files_with_issues"
echo ""

if [[ $files_with_issues -gt 0 ]]; then
  echo -e "Status: FALHA"
  echo -e "$issues"
  exit 1
else
  echo "Status: SUCESSO - Todas as tags obrigatorias estao presentes!"
  exit 0
fi
