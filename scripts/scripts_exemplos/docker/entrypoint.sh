#!/bin/bash
set -e

# Carrega variáveis de ambiente do .env se existir
if [ -f /project/config/.env ]; then
	echo "📋 Carregando configurações de /project/config/.env..."
	export $(grep -v '^#' /project/config/.env | xargs)
	echo "   Hostname: ${ISO_HOSTNAME:-debian-nas}"
	echo "   Mirror: ${DEBIAN_MIRROR:-http://ftp.br.debian.org/debian/}"
fi

# Cria o diretório de trabalho se não existir
mkdir -p /project/build/auto

# Sincroniza as customizações para a pasta de trabalho do live-build
rsync -av /project/config-overrides/config/ /project/build/config/

cd /project/build

# Executa o config se não existir
if [ ! -d ".build" ]; then
	echo "🔧 Configurando live-build com auto/config..."
	# Copia o auto/config do projeto para o local correto
	cp /project/config-overrides/auto/config auto/config
	chmod +x auto/config
	# Executa o script de configuração do projeto
	./auto/config
fi

echo "🏗️ Iniciando build da ISO..."
lb build 2>&1 | tee /project/logs/build-$(date +%Y%m%d).log

# Move o resultado para a pasta de output
mv *.iso /project/output/ 2>/dev/null || true

echo "✅ Build concluído! ISO disponível em /project/output/"
