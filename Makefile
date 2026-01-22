.PHONY: all build prepare vm-check vm-uefi vm-bios vm-test-uefi vm-test-bios vm-raidz1 vm-raidz2 vm-raidz3 clean fix-permissions help test

help:
	@./qemu/tools/vm.sh --help | sed 's/🌌 AURORA OS - VM MANAGER/🌌 AURORA OS - BUILD SYSTEM/'
	@echo ""
	@echo "Build Commands:"
	@echo "  make build           - Constrói a imagem ISO (Docker)"
	@echo "  make prepare         - Baixa dependências (ZBM, Gum)"
	@echo "  make clean           - Limpa TUDO (Build e VM)"
	@echo "  make fix-permissions - Corrige permissões em docker/"
	@echo "  make test            - Executa testes"
	@echo ""
	@echo "Automated VM Commands:"
	@echo "  make vm-uefi        - Boot ISO em modo UEFI"
	@echo "  make vm-bios        - Boot ISO em modo BIOS"
	@echo "  make vm-test-uefi   - Boot pelo DISCO em modo UEFI (Validação pós-instalação)"
	@echo "  make vm-test-bios   - Boot pelo DISCO em modo BIOS (Validação pós-instalação)"
	@echo "  make vm-raidz1      - Boot ISO UEFI com 3 discos (Teste RAID-Z1)"
	@echo "  make vm-raidz2      - Boot ISO UEFI com 4 discos (Teste RAID-Z2)"
	@echo "  make vm-raidz3      - Boot ISO UEFI com 5 discos (Teste RAID-Z3)"
	@echo ""
	@echo "📋 Requisitos de Permissão:"
	@echo "  - Docker instalado e usuário no grupo docker"
	@echo "  - Permissões de escrita em ./docker/ ou fallback para /tmp"
	@echo "  - Não requer privilégios de root (sem --privileged)"

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

vm-test-uefi:
	@./qemu/tools/vm.sh --start-uefi --boot-disk

vm-test-bios:
	@./qemu/tools/vm.sh --start-bios --boot-disk

vm-raidz1:
	@./qemu/tools/vm.sh --start-uefi --disks 3

vm-raidz2:
	@./qemu/tools/vm.sh --start-uefi --disks 4

vm-raidz3:
	@./qemu/tools/vm.sh --start-uefi --disks 5

fix-permissions:
	@echo "ℹ Corrigindo permissões em docker/..."
	@sudo chown -R $(USER):$(USER) docker/ include/
	@echo "✔ Permissões corrigidas."

clean:
	@./docker/tools/build-iso-in-docker.sh --clean
	@./qemu/tools/vm.sh --clean

test:
	@echo "ℹ Executando testes..."
	@for t in tests/*.sh; do \
		echo ">>> $$t"; \
		./$$t || exit 1; \
	done
