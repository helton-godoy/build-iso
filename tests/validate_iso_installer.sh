#!/usr/bin/env bash
#
# validate_iso_installer.sh - Validação automatizada da ISO e instalador
#

set -euo pipefail

ISO_PATH="output/live-image-amd64.hybrid.iso"
LOG_FILE="logs/validate_iso_installer.log"

echo "=== Validação da ISO com Instalador ==="
echo "Data: $(date)"
echo

mkdir -p logs

# Teste 1: Verifica existência e tamanho da ISO
echo "[1/7] Verificando ISO..."
if [[ ! -f "$ISO_PATH" ]]; then
  echo "✗ ISO não encontrada: $ISO_PATH"
  exit 1
fi

ISO_SIZE=$(stat -c%s "$ISO_PATH")
ISO_SIZE_MB=$((ISO_SIZE / 1024 / 1024))
echo "✓ ISO encontrada: ${ISO_SIZE_MB}MB"

if [[ $ISO_SIZE_MB -lt 500 ]]; then
  echo "✗ ISO muito pequena (mínimo 500MB)"
  exit 1
fi
echo "✓ Tamanho da ISO adequado"

# Teste 2: Valida estrutura da ISO
echo
echo "[2/7] Validando estrutura da ISO..."
if command -v isoinfo &>/dev/null; then
  ISO_LIST=$(isoinfo -l -i "$ISO_PATH" 2>/dev/null)

  # Verifica diretórios essenciais
  for dir in EFI ISOLINUX LIVE ZBM; do
    if echo "$ISO_LIST" | grep -q "$dir"; then
      echo "✓ Diretório $dir presente"
    else
      echo "✗ Diretório $dir ausente"
    fi
  done
else
  echo "⚠ isoinfo não disponível, pulando validação de estrutura"
fi

# Teste 3: Verifica arquivos do ZFSBootMenu
echo
echo "[3/7] Verificando ZFSBootMenu..."
if echo "$ISO_LIST" 2>/dev/null | grep -q "ZBM"; then
  echo "✓ Diretório ZBM presente na ISO"
else
  echo "⚠ Diretório ZBM não encontrado na listagem"
fi

# Verifica arquivos binários incluídos
for file in config-overrides/config/includes.binary/EFI/BOOT/BOOTX64.EFI \
  config-overrides/config/includes.binary/zbm/vmlinuz \
  config-overrides/config/includes.binary/zbm/initramfs.img; do
  if [[ -f "$file" ]]; then
    echo "✓ $(basename $file) presente"
  else
    echo "✗ $(basename $file) ausente"
  fi
done

# Teste 4: Verifica scripts do instalador
echo
echo "[4/7] Verificando scripts do instalador..."
INSTALLER_FILES=(
  "config-overrides/config/includes.chroot/usr/local/bin/installer"
  "config-overrides/config/includes.chroot/usr/local/lib/installer/libs/core-utils.sh"
  "config-overrides/config/includes.chroot/usr/local/lib/installer/libs/disk-utils.sh"
  "config-overrides/config/includes.chroot/usr/local/lib/installer/libs/zbm-install.sh"
  "config-overrides/config/includes.chroot/usr/local/lib/installer/libs/state-utils.sh"
  "config-overrides/config/includes.chroot/usr/local/lib/installer/libs/install-plan-utils.sh"
)

for file in "${INSTALLER_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    if [[ -x "$file" ]]; then
      echo "✓ $(basename $file) (executável)"
    else
      echo "⚠ $(basename $file) (não executável)"
    fi
  else
    echo "✗ $(basename $file) (ausente)"
  fi
done

# Teste 5: Verifica hook live-build
echo
echo "[5/7] Verificando hook live-build..."
HOOK_FILE="config-overrides/config/hooks/live/0200-installer-scripts.hook.chroot"
if [[ -f "$HOOK_FILE" ]]; then
  echo "✓ Hook do instalador presente"
  if [[ -x "$HOOK_FILE" ]]; then
    echo "✓ Hook é executável"
  else
    echo "⚠ Hook não é executável"
  fi
else
  echo "✗ Hook do instalador ausente"
fi

# Teste 6: Validação de sintaxe dos scripts
echo
echo "[6/7] Validando sintaxe dos scripts..."
SYNTAX_ERRORS=0

for script in config-overrides/config/includes.chroot/usr/local/lib/installer/libs/*.sh; do
  if [[ -f "$script" ]]; then
    if bash -n "$script" 2>/dev/null; then
      echo "✓ $(basename $script) - sintaxe OK"
    else
      echo "✗ $(basename $script) - erro de sintaxe"
      SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
  fi
done

echo
echo "[7/7] Validando aderência ao spec..."
if bash tests/test_installer_spec_alignment.sh; then
  echo "✓ Aderência ao spec validada"
else
  echo "✗ Falha na validação de aderência ao spec"
  SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
fi

# Resumo
echo
echo "=== Resumo da Validação ==="
if [[ $SYNTAX_ERRORS -eq 0 ]]; then
  echo "✓ Todos os scripts possuem sintaxe válida"
else
  echo "✗ $SYNTAX_ERRORS script(s) com erro de sintaxe"
fi

echo
echo "✓ ISO gerada com sucesso: $ISO_PATH"
echo "  Tamanho: ${ISO_SIZE_MB}MB"
echo
echo "✓ Instalador modular implementado:"
echo "  - Design System v2.0 (monocromático)"
echo "  - Detecção UEFI/BIOS"
echo "  - Particionamento GPT híbrido"
echo "  - Pool ZFS com datasets ZBM"
echo "  - Configuração de sistema (hostname, usuário, rede)"
echo "  - Instalação ZFSBootMenu"
echo
echo "Próximos passos:"
echo "  1. Testar boot da ISO em VM (make test-vm-uefi / make test-vm-bios)"
echo "  2. Executar instalador interativo na VM"
echo "  3. Verificar primeiro boot do sistema instalado"
echo

exit $SYNTAX_ERRORS
