# Makefile para Build ISO Debian ZFS
# Simplificado para delegar tarefas para os scripts em tools/ e qemu/

.PHONY: all build prepare vm-check vm-uefi vm-bios clean help test

# Target padrão
all: build

help:
	@echo "Targets disponíveis:"
	@echo "  build       - Prepara dependências e constrói a imagem ISO"
	@echo "  prepare     - Baixa todas as dependências necessárias (idempotente)"
	@echo "  vm-check    - Verifica dependências para rodar a VM de teste"
	@echo "  vm-uefi     - Inicia a VM em modo UEFI com a última ISO gerada"
	@echo "  vm-bios     - Inicia a VM em modo BIOS com a última ISO gerada"
	@echo "  clean       - Limpa artefatos de build (docker/artifacts/)"
	@echo "  test        - Executa a suite de testes automatizados"

prepare:
	@echo "Verificando dependências..."
	./tools/download-zfsbootmenu.sh
	./tools/download-gum.sh

build: prepare
	@echo "Iniciando build..."
	./docker/tools/build-iso-in-docker.sh

vm-check:
	./qemu/tools/vm.sh --check

vm-uefi:
	./qemu/tools/vm.sh --start-uefi

vm-bios:
	./qemu/tools/vm.sh --start-bios

clean:
	@echo "Limpando artefatos..."
	rm -rf docker/work docker/dist docker/logs
	# Mantém o cache para acelerar builds futuros
	# rm -rf docker/cache 

test:
	@echo "Executando testes..."
	# Executa todos os scripts de teste em tests/
	for t in tests/*.sh; do \
		echo ">>> Executando $$t"; \
		./$$t || exit 1; \
	done
