#!/usr/bin/env bash
set -euo pipefail

HOOK_FILE="config/hooks/live/0100-compile-zfs-dkms.hook.chroot"

echo "Verificando hook de compilação ZFS..."

if [[ -f "$HOOK_FILE" ]]; then
    echo "PASS: Hook existe."
else
    echo "FAIL: Hook não encontrado."
    exit 1
fi

if [[ -x "$HOOK_FILE" ]]; then
    echo "PASS: Hook tem permissão de execução."
else
    echo "FAIL: Hook não é executável."
    exit 1
fi

# Verificar se comandos críticos estão presentes no hook
if grep -q "dkms autoinstall" "$HOOK_FILE" && grep -q "update-initramfs" "$HOOK_FILE"; then
    echo "PASS: Hook contém comandos DKMS e initramfs."
else
    echo "FAIL: Hook está incompleto."
    exit 1
fi

echo "Validação do hook ZFS concluída com sucesso!"
exit 0