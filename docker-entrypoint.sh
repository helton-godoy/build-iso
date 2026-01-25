#!/bin/bash
set -euo pipefail

echo "==> Iniciando build da ISO Debian Trixie com ZFSBootMenu"

cd /build

# Limpar builds anteriores
# Limpar builds anteriores
if [[ -d "live-build-config" ]]; then
	echo "==> Limpando configurações anteriores..."
	# Tentar limpar com força bruta, ignorando erros de montagem primeiro
	rm -rf live-build-config || {
		echo "[AVISO] Falha ao remover 'live-build-config' simples. Tentando limpeza mais profunda..."
		# Se for um mount point preso, isso pode ajudar em alguns casos, mas no docker é mais sobre permissão ou arquivo aberto
		find live-build-config -mindepth 1 -delete || echo "[ERRO CRÍTICO] Não é possível limpar o diretório de trabalho."
	}
fi

# Copiar pacote kmscon customizado para packages.chroot
echo "==> Preparando pacote kmscon customizado..."
mkdir -p /build/config/packages.chroot
if [[ -f "/opt/kmscon-custom_9.3.0_amd64.deb" ]]; then
	cp /opt/kmscon-custom_9.3.0_amd64.deb /build/config/packages.chroot/
	echo "===> Pacote kmscon customizado copiado para packages.chroot"
	dpkg-deb -I /build/config/packages.chroot/kmscon-custom_9.3.0_amd64.deb
else
	echo "AVISO: Pacote kmscon customizado não encontrado em /opt/"
fi

# Executar script de configuração
if [[ -f "/build/config/configure-live-build.sh" ]]; then
	echo "==> Executando configuração do live-build..."
	bash /build/config/configure-live-build.sh
else
	echo "ERRO: Script de configuração não encontrado!"
	exit 1
fi

# Copiar arquivos de saída
if [[ -d "live-build-config" ]]; then
	echo "==> Copiando ISO gerada para /output..."
	find live-build-config -name "*.iso" -exec cp {} /output/ \;
	find live-build-config -name "*.packages" -exec cp {} /output/ \;
	find live-build-config -name "*.sha256" -exec cp {} /output/ \;

	# Copiar logs
	if [[ -f "live-build-config/build.log" ]]; then
		cp live-build-config/build.log /output/
	fi

	echo "==> Build concluído com sucesso!"
else
	echo "ERRO: Diretório de build não encontrado!"
	exit 1
fi
