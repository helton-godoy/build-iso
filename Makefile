# Variáveis
PROJECT_NAME = build-iso
SCRIPTS_DIR = scripts
DOCKER_DIR = scripts/docker
BUILD_DIR = build
LOGS_DIR = logs
OUTPUT_DIR = output
CONFIG_OVERRIDES = config-overrides

# Nome da imagem Docker
DOCKER_IMAGE_NAME = zbm-iso-builder

.PHONY: all build clean test-iso setup-vm download-deps prepare help download-zbm setup-docker build-iso

all: build-iso

help:
	@echo "Comandos disponíveis:"
	@echo "  make download-zbm  - Baixa binários do ZFSBootMenu"
	@echo "  make setup-docker  - Constrói a imagem Docker do builder"
	@echo "  make build-iso     - Inicia o build da ISO (depende de download-zbm e setup-docker)"
	@echo "  make clean         - Remove artefatos de build"

# Cria diretórios de trabalho se não existirem
prepare:
	@mkdir -p $(LOGS_DIR) $(OUTPUT_DIR)

# Executa o download dos binários ZFSBootMenu
download-zbm: prepare
	@echo "Baixando dependências do ZFSBootMenu..."
	@chmod +x $(SCRIPTS_DIR)/download-zfsbootmenu.sh
	bash $(SCRIPTS_DIR)/download-zfsbootmenu.sh

# Constrói a imagem Docker do Builder
setup-docker:
	@echo "Construindo imagem Docker: $(DOCKER_IMAGE_NAME)..."
	docker build -t $(DOCKER_IMAGE_NAME) -f $(DOCKER_DIR)/Dockerfile $(DOCKER_DIR)

# Roda o processo de build dentro do container
build-iso: download-zbm setup-docker
	@echo "Iniciando build da ISO..."
	docker run --rm --privileged \
		-v "$(shell pwd):/build" \
		$(DOCKER_IMAGE_NAME)

clean:
	@echo "Limpando artefatos de build..."
	sudo rm -rf $(LOGS_DIR) $(OUTPUT_DIR) live-build-workspace
	# Limpar workspace do live-build se criado localmente (embora agora seja interno ao container, o volume mapeado pode ter sobras)
