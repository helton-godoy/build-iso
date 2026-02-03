# Variáveis
PROJECT_NAME = build-iso
SCRIPTS_DIR = scripts
BUILD_DIR = build
LOGS_DIR = logs
OUTPUT_DIR = output
CONFIG_OVERRIDES = config-overrides/config

# Comandos
DOCKER_BUILD_SCRIPT = $(SCRIPTS_DIR)/build-iso-in-docker.sh
VM_SETUP_SCRIPT = $(SCRIPTS_DIR)/vm/vm-setup.sh
VM_START_ISO_SCRIPT = $(SCRIPTS_DIR)/vm/vm-start-test-boot-iso.sh

.PHONY: all build clean test-iso setup-vm download-deps prepare help

all: build

help:
	@echo "Comandos disponíveis:"
	@echo "  make setup-vm      - Instala dependências de virtualização"
	@echo "  make download-deps - Baixa binários do ZFSBootMenu e Gum"
	@echo "  make build         - Inicia o build da ISO via Docker"
	@echo "  make test-iso      - Testa o boot da ISO via QEMU"
	@echo "  make clean         - Remove artefatos de build"

prepare:
	@echo "Preparando ambiente e isolando build..."
	@mkdir -p $(BUILD_DIR) $(LOGS_DIR) $(OUTPUT_DIR)
	@# Sincroniza a base da configuração
	@rsync -av --exclude='include.*' --exclude='package.lists' config-overrides/config/ $(BUILD_DIR)/config/
	@# Sincroniza e mapeia nomes amigáveis (singular.dot) para o padrão live-build (plural/dash)
	@mkdir -p $(BUILD_DIR)/config/package-lists $(BUILD_DIR)/config/includes.chroot $(BUILD_DIR)/config/includes.binary
	@rsync -av --delete config-overrides/config/package.lists/ $(BUILD_DIR)/config/package-lists/
	@rsync -av --delete config-overrides/config/include.chroot/ $(BUILD_DIR)/config/includes.chroot/
	@rsync -av --delete config-overrides/config/include.binary/ $(BUILD_DIR)/config/includes.binary/
	@rsync -av --delete config-overrides/auto/ $(BUILD_DIR)/auto/
	@# Garante que auto/config seja executável
	@chmod +x $(BUILD_DIR)/auto/*
	@# Remove arquivos/links legados na raiz se existirem para manter o isolamento
	@sudo rm -rf config binary cache local .build chroot

setup-vm:
	@echo "Instalando dependências de VM..."
	bash $(VM_SETUP_SCRIPT)

download-deps: prepare
	@echo "Baixando dependências (ZFSBootMenu, Gum)..."
	bash $(SCRIPTS_DIR)/download-zfsbootmenu.sh
	bash $(SCRIPTS_DIR)/download-gum.sh

build: prepare
	@echo "Iniciando build da ISO no Docker..."
	bash $(DOCKER_BUILD_SCRIPT)

test-iso:
	@echo "Iniciando teste de boot da ISO..."
	bash $(VM_START_ISO_SCRIPT)

clean:
	@echo "Limpando artefatos de build..."
	sudo rm -rf $(BUILD_DIR) $(LOGS_DIR) $(OUTPUT_DIR) .build chroot
	sudo rm -rf config binary cache local
