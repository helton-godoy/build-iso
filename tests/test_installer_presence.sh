#!/usr/bin/env bash
set -euo pipefail

INSTALLER="config-overrides/config/includes.chroot/usr/local/bin/installer"

echo "Verificando presença do instalador interativo..."

if [[ -f "$INSTALLER" ]]; then
	echo "PASS: Instalador existe em config-overrides/config/includes.chroot/."
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

if grep -q "gum" "$INSTALLER"; then
	echo "PASS: Instalador utiliza gum para interface interativa."
else
	echo "FAIL: Instalador não contém referência ao gum (UI framework)."
	exit 1
fi

echo "Validação do instalador concluída com sucesso!"
exit 0
