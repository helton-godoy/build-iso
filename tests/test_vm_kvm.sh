#!/usr/bin/env bash
set -euo pipefail

echo "Iniciando teste de suporte a KVM e recursos..."

# Verifica se o script inclui -enable-kvm quando /dev/kvm existe
# Usaremos --dry-run para não lançar o QEMU de fato
if [[ -e /dev/kvm ]]; then
	if ./tools/test-iso.sh --dry-run | grep -q "\-enable-kvm"; then
		echo "PASS: KVM habilitado corretamente."
	else
		echo "FAIL: KVM disponível mas não habilitado no comando."
		exit 1
	fi
else
	echo "SKIP: KVM não disponível no host para teste real."
fi

# Verifica se RAM e CPUS estão sendo passados
if ./tools/test-iso.sh --dry-run | grep -q "\-m 2G" && ./tools/test-iso.sh --dry-run | grep -q "\-smp 2"; then
	echo "PASS: Recursos (RAM/CPU) configurados corretamente."
else
	echo "FAIL: Recursos não configurados conforme esperado."
	exit 1
fi
