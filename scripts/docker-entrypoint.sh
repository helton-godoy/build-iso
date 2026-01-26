#!/bin/bash
set -euo pipefail

echo "==> Iniciando build da ISO Debian ${DEBIAN_VERSION} com ZFSBootMenu"
echo "==> Configuração:"
echo "    -> ISO Name: ${ISO_NAME}"
echo "    -> Arch: ${ARCH}"
echo "    -> Locale: ${LOCALE}"
echo "    -> Mirror: ${MIRROR_CHROOT}"

cd /build

# Limpar builds anteriores
if [ -d "live-build-config" ]; then
	echo "==> Limpando configurações anteriores..."
	# Tentar limpar com força bruta, ignorando erros de montagem primeiro
	rm -rf live-build-config || {
		echo "[AVISO] Falha ao remover 'live-build-config' simples. Tentando limpeza mais profunda..."
		find live-build-config -mindepth 1 -delete || echo "[ERRO CRÍTICO] Não é possível limpar o diretório de trabalho."
	}
fi

# Copiar pacote kmscon customizado para packages.chroot
echo "==> Preparando pacote kmscon customizado..."
mkdir -p /build/config/packages.chroot

# Prioridade: 1) Cache montado, 2) /opt (compilado no Docker)
if [ -f "/cache/debs/${KMSCON_DEB_NAME}" ]; then
	echo "===> Usando kmscon do CACHE"
	cp "/cache/debs/${KMSCON_DEB_NAME}" /build/config/packages.chroot/
	dpkg-deb -I "/build/config/packages.chroot/${KMSCON_DEB_NAME}"
elif [ -f "/opt/${KMSCON_DEB_NAME}" ]; then
	echo "===> Usando kmscon COMPILADO"
	cp "/opt/${KMSCON_DEB_NAME}" /build/config/packages.chroot/
	dpkg-deb -I "/build/config/packages.chroot/${KMSCON_DEB_NAME}"

	# Salvar no cache para futuros builds
	if [ -d "/cache/debs" ]; then
		echo "===> Salvando kmscon no CACHE para futuros builds"
		cp "/opt/${KMSCON_DEB_NAME}" "/cache/debs/"
	fi
else
	echo "AVISO: Pacote kmscon customizado (${KMSCON_DEB_NAME}) não encontrado!"
	echo "       Verifique se o cache ou a compilação funcionou."
fi

# Executar script de configuração
if [ -f "/build/config/configure-live-build.sh" ]; then
	echo "==> Executando configuração do live-build..."
	bash /build/config/configure-live-build.sh
else
	echo "ERRO: Script de configuração não encontrado!"
	exit 1
fi

# Copiar arquivos de saída
if [ -d "live-build-config" ]; then
	echo "==> Copiando ISO gerada para /output..."
	find live-build-config -name "*.iso" -exec cp {} /output/ \;
	find live-build-config -name "*.packages" -exec cp {} /output/ \;
	find live-build-config -name "*.sha256" -exec cp {} /output/ \;

	# Copiar logs
	if [ -f "live-build-config/build.log" ]; then
		cp live-build-config/build.log /output/
	fi

	echo "==> Build concluído com sucesso!"
else
	echo "ERRO: Diretório de build não encontrado!"
	exit 1
fi
