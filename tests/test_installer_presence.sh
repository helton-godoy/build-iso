#!/usr/bin/env bash
set -euo pipefail

INSTALLER="config/includes.chroot/usr/local/bin/install-zfs-debian"

echo "Verificando presença do instalador interativo..."

if [[ -f "$INSTALLER" ]]; then
    echo "PASS: Instalador existe em config/includes.chroot/."
else
    echo "FAIL: Instalador não encontrado."
    exit 1
fi

if [[ -x "$INSTALLER" ]]; then
    echo "PASS: Instalador é executável."
else
    echo "FAIL: Instalador não tem permissão de execução."
    exit 1
fi

if grep -q "rsync" "$INSTALLER"; then
    echo "PASS: Instalador utiliza rsync para cópia do sistema."
else
    echo "FAIL: Instalador não contém lógica de rsync."
    exit 1
fi

echo "Validação do instalador concluída com sucesso!"
exit 0
