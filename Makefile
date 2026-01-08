.PHONY: all build prepare vm-check vm-uefi vm-bios clean help test

help:
	@./qemu/tools/vm.sh --help | sed 's/🌌 AURORA OS - VM MANAGER/🌌 AURORA OS - BUILD SYSTEM/'
	@echo ""
	@echo "Build Commands:"
	@echo "  make build       - Constrói a imagem ISO (Docker)"
	@echo "  make prepare     - Baixa dependências (ZBM, Gum)"
	@echo "  make clean       - Limpa TUDO (Build e VM)"
	@echo "  make test        - Executa testes"

all: build

prepare:
	@echo "ℹ Preparando dependências..."
	@./tools/download-zfsbootmenu.sh
	@./tools/download-gum.sh

build: prepare
	@./docker/tools/build-iso-in-docker.sh

vm-check:
	@./qemu/tools/vm.sh --check

vm-uefi:
	@./qemu/tools/vm.sh --start-uefi

vm-bios:
	@./qemu/tools/vm.sh --start-bios

clean:
	@./docker/tools/build-iso-in-docker.sh --clean
	@./qemu/tools/vm.sh --clean

test:
	@echo "ℹ Executando testes..."
	@for t in tests/*.sh; do \n		echo ">>> $$t"; \n		./$$t || exit 1; \n	done
