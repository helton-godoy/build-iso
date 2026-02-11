# =============================================================================
# BUILD-ISO: Automação de implantação Debian com ZFS-on-root e ZFSBootMenu
# =============================================================================
# Organiza todos os comandos de build, deploy e testes da imagem live-build
# =============================================================================

# -----------------------------------------------------------------------------
# Variáveis de Configuração
# -----------------------------------------------------------------------------
PROJECT_NAME  = build-iso
SCRIPTS_DIR   = scripts
DOCKER_DIR     = scripts/docker
VM_DIR         = scripts/vm
VM_DISKS_DIR   = scripts/vm/disks
BUILD_DIR      = build
LOGS_DIR       = logs
OUTPUT_DIR     = output
CONFIG_OVERRIDES = config-overrides

# Nome da imagem Docker
DOCKER_IMAGE_NAME = zbm-iso-builder

# VM Configuration
VM_NAME_UEFI  = nas-test-uefi
VM_NAME_BIOS  = nas-test-bios
VM_SOCKET_UEFI = /tmp/$(VM_NAME_UEFI).sock
VM_SOCKET_BIOS = /tmp/$(VM_NAME_BIOS).sock
VM_DISK_PATH_UEFI = scripts/vm/disks/uefi/installed-system.qcow2
VM_DISK_PATH_BIOS = scripts/vm/disks/bios/installed-system.qcow2

# -----------------------------------------------------------------------------
# Targets Phony (sempre executados)
# -----------------------------------------------------------------------------
.PHONY: all help build download-zbm setup-docker build-iso clean
.PHONY: setup-vm vm-list vm-destroy vm-destroy-all
.PHONY: test-vm-uefi test-vm-bios test-vm-all vm-connect-uefi vm-connect-bios
.PHONY: vm-boot-disk-uefi vm-boot-disk-bios
.PHONY: docs docs-installer docs-dev docs-tests docs-all docs-markdown docs-stats verify-docs
.PHONY: validate-ad ad-precheck validate-configs lint
.PHONY: plan-list plan-archive

# -----------------------------------------------------------------------------
# Targets Principais
# -----------------------------------------------------------------------------

all: build-iso
	@echo "✅ Build completo! Use 'make test-vm-all' para testar a ISO."

help:
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "  $(PROJECT_NAME) - Build, Deploy & Test Automation"
	@echo "════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "📦 BUILD & DEPLOY:"
	@echo "  make download-zbm  - Baixa binários do ZFSBootMenu"
	@echo "  make setup-docker  - Constrói a imagem Docker do builder"
	@echo "  make build-iso     - Inicia o build da ISO"
	@echo ""
	@echo "🖥️  VM SETUP:"
	@echo "  make setup-vm         - Instala dependências de virtualização"
	@echo ""
	@echo "🧪 VM TESTES:"
	@echo "  make test-vm-uefi     - Inicia VM em modo UEFI"
	@echo "  make test-vm-bios     - Inicia VM em modo BIOS"
	@echo "  make test-vm-all      - Inicia VMs UEFI + BIOS simultaneamente"
	@echo ""
	@echo "💾 VM BOOT DISCO:"
	@echo "  make vm-boot-disk-uefi - Inicia VM a partir de disco (UEFI)"
	@echo "  make vm-boot-disk-bios - Inicia VM a partir de disco (BIOS)"
	@echo ""
	@echo "🔌 VM CONEXÃO:"
	@echo "  make vm-connect-uefi  - Conecta ao console serial UEFI"
	@echo "  make vm-connect-bios  - Conecta ao console serial BIOS"
	@echo ""
	@echo "🧹 LIMPEZA:"
	@echo "  make clean            - Remove artefatos de build e VMs"
	@echo ""
	@echo "📖 DOCUMENTAÇÃO:"
	@echo "  make docs             - Exibe toda a documentação (instalador + dev + testes)"
	@echo "  make docs-installer   - Exibe apenas documentação do instalador (@INST)"
	@echo "  make docs-dev         - Exibe apenas scripts de desenvolvimento (@DEV)"
	@echo "  make docs-tests       - Exibe apenas scripts de teste (@TEST)"
	@echo "  make docs-markdown    - Gera documentação completa em Markdown"
	@echo "  make docs-stats       - Estatísticas de cobertura de documentação"
	@echo "  make verify-docs      - Valida a integridade de todas as tags"
	@echo ""
	@echo "🔐 NAS / SAMBA / AD:"
	@echo "  make validate-ad      - Executa validação AD/SMB (Linux-side)"
	@echo "  make ad-precheck      - Executa precheck AD no fileserver"
	@echo "  make validate-configs - Valida JSON/YAML de configuração"
	@echo "  make lint             - Executa shellcheck em scripts"
	@echo ""
	@echo "📋 PLANEJAMENTO:"
	@echo "  make plan-list        - Lista planos ativos com status"
	@echo "  make plan-archive     - Arquiva plano concluído (FILE=plan/NNN-*.md)"
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════"

# -----------------------------------------------------------------------------
# Build Targets
# -----------------------------------------------------------------------------

prepare:
	@mkdir -p $(LOGS_DIR) $(OUTPUT_DIR)

download-zbm: prepare
	@echo "📥 Baixando dependências do ZFSBootMenu..."
	@chmod +x $(SCRIPTS_DIR)/download-zfsbootmenu.sh
	@bash $(SCRIPTS_DIR)/download-zfsbootmenu.sh

setup-docker:
	@echo "🐳 Construindo imagem Docker: $(DOCKER_IMAGE_NAME)..."
	@docker build -t $(DOCKER_IMAGE_NAME) -f $(DOCKER_DIR)/Dockerfile $(DOCKER_DIR)

build-iso: download-zbm setup-docker
	@echo "🔨 Iniciando build da ISO..."
	@docker run --rm --privileged \
		-v "$(CURDIR):/build" \
		$(DOCKER_IMAGE_NAME)

# -----------------------------------------------------------------------------
# VM Setup Targets
# -----------------------------------------------------------------------------

setup-vm:
	@echo "🔧 Instalando dependências de virtualização..."
	@chmod +x $(VM_DIR)/vm-setup.sh
	@bash $(VM_DIR)/vm-setup.sh


vm-list:
	@echo "📋 VMs em execução:"
	@virsh --connect qemu:///system list --all

vm-destroy:
	@echo "🛑 Destruindo VMs..."
	@for vm in $$(virsh --connect qemu:///system list --all --name 2>/dev/null | grep -E '^nas-test-(uefi|bios)$$'); do \
		virsh --connect qemu:///system destroy "$vm" >/dev/null 2>&1 || true; \
		virsh --connect qemu:///system undefine "$vm" --nvram --remove-all-storage >/dev/null 2>&1 || true; \
		done
	@echo "✅ VMs destruídas."

vm-destroy-all: vm-destroy

# -----------------------------------------------------------------------------
# VM Test Targets
# -----------------------------------------------------------------------------

test-vm-uefi:
	@echo "🚀 Iniciando VM de teste (UEFI)..."
	@chmod +x $(VM_DIR)/vm-start-test-boot-iso.sh
	@bash $(VM_DIR)/vm-start-test-boot-iso.sh uefi

test-vm-bios:
	@echo "🚀 Iniciando VM de teste (BIOS)..."
	@chmod +x $(VM_DIR)/vm-start-test-boot-iso.sh
	@bash $(VM_DIR)/vm-start-test-boot-iso.sh bios

test-vm-all:
	@echo "🧪 Iniciando bateria de testes (UEFI + BIOS)..."
	@chmod +x $(VM_DIR)/vm-start-test-all.sh
	@bash $(VM_DIR)/vm-start-test-all.sh

# -----------------------------------------------------------------------------
# VM Boot Disk Targets
# -----------------------------------------------------------------------------

vm-boot-disk-uefi:
	@echo "💾 Iniciando VM a partir de disco (UEFI)..."
	@chmod +x $(VM_DIR)/vm-start-test-boot-disk.sh
	@bash $(VM_DIR)/vm-start-test-boot-disk.sh -f uefi $(VM_DISK_PATH_UEFI)

vm-boot-disk-bios:
	@echo "💾 Iniciando VM a partir de disco (BIOS)..."
	@chmod +x $(VM_DIR)/vm-start-test-boot-disk.sh
	@bash $(VM_DIR)/vm-start-test-boot-disk.sh -f bios $(VM_DISK_PATH_BIOS)

# -----------------------------------------------------------------------------
# VM Connection Targets
# -----------------------------------------------------------------------------

vm-connect-uefi:
	@echo "🔌 Conectando ao console serial (UEFI)..."
	@chmod +x $(VM_DIR)/vm-connect-agent-llm.sh
	@VM_CMD="$(VM_CMD)" VM_IP="$(VM_IP)" bash $(VM_DIR)/vm-connect-agent-llm.sh uefi

vm-connect-bios:
	@echo "🔌 Conectando ao console serial (BIOS)..."
	@chmod +x $(VM_DIR)/vm-connect-agent-llm.sh
	@VM_CMD="$(VM_CMD)" VM_IP="$(VM_IP)" bash $(VM_DIR)/vm-connect-agent-llm.sh bios

# -----------------------------------------------------------------------------
# Cleanup Targets
# -----------------------------------------------------------------------------

clean:
	@echo "🧹 Limpando artefatos de build..."
	@sudo rm -rf $(LOGS_DIR) $(OUTPUT_DIR) live-build-workspace
	@$(MAKE) vm-destroy
	@echo "✅ Limpeza completa!"

# -----------------------------------------------------------------------------
# Documentation Targets
# -----------------------------------------------------------------------------

docs:
	@bash $(SCRIPTS_DIR)/extract-docs.sh --all

docs-installer:
	@bash $(SCRIPTS_DIR)/extract-docs.sh --installer

docs-dev:
	@bash $(SCRIPTS_DIR)/extract-docs.sh --dev

docs-tests:
	@bash $(SCRIPTS_DIR)/extract-docs.sh --tests

docs-all: docs

docs-markdown:
	@mkdir -p $(OUTPUT_DIR)
	@bash $(SCRIPTS_DIR)/extract-docs.sh --markdown --all > $(OUTPUT_DIR)/docs-$(shell date +%Y%m%d).md
	@echo "📄 Documentação gerada em: $(OUTPUT_DIR)/docs-$(shell date +%Y%m%d).md"

docs-stats:
	@bash $(SCRIPTS_DIR)/extract-docs.sh --stats

verify-docs:
	@echo "🔍 Validando metadados da documentação..."
	@chmod +x tests/test-docs.sh
	@bash tests/test-docs.sh

# -----------------------------------------------------------------------------
# NAS / Samba / AD Targets
# -----------------------------------------------------------------------------

ARTIFACTS_DIR = artifacts

validate-ad:
	@echo "🔐 Executando validação AD/SMB (Linux-side)..."
	@bash $(ARTIFACTS_DIR)/scripts/validate_ad_smb.sh

ad-precheck:
	@echo "🔍 Executando precheck AD no fileserver..."
	@bash $(ARTIFACTS_DIR)/scripts/ad_precheck_fileserver.sh

validate-configs:
	@echo "📋 Validando configurações (JSON/YAML)..."
	@python3 -m json.tool $(ARTIFACTS_DIR)/installer/vdev_planner_spec.json > /dev/null && echo "  ✅ vdev_planner_spec.json"
	@python3 -m json.tool labels/labels.json > /dev/null && echo "  ✅ labels.json"
	@python3 -c "import yaml; yaml.safe_load(open('.pre-commit-config.yaml'))" && echo "  ✅ .pre-commit-config.yaml"
	@python3 -c "import yaml; yaml.safe_load(open('.github/workflows/lint.yml'))" && echo "  ✅ lint.yml"
	@python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pr-labeler.yml'))" && echo "  ✅ pr-labeler.yml"
	@python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build.yml'))" && echo "  ✅ build.yml"
	@echo "✅ Todas as configurações válidas!"

lint:
	@echo "🔍 Executando lint (shellcheck)..."
	@find scripts/ artifacts/scripts/ -name '*.sh' -exec shellcheck {} +
	@echo "✅ Lint OK!"

# -----------------------------------------------------------------------------
# Planejamento
# -----------------------------------------------------------------------------

plan-list:
	@echo "📋 Planos ativos:"
	@echo "────────────────────────────────────────────────────────────────"
	@for f in plan/*.md; do \
		name=$$(basename -- "$$f"); \
		if [ "$$name" = "README.md" ]; then continue; fi; \
		status=$$(grep -m1 '^\*\*Status:\*\*' "$$f" 2>/dev/null | sed 's/.*\*\* //'); \
		if [ -z "$$status" ]; then status="(sem status)"; fi; \
		printf "  %-16s %s\n" "$$status" "$$name"; \
	done
	@echo "────────────────────────────────────────────────────────────────"

plan-archive:
	@test -n "$(FILE)" || (echo "❌ Uso: make plan-archive FILE=plan/NNN-*.md" && exit 1)
	@test -f "$(FILE)" || (echo "❌ Arquivo não encontrado: $(FILE)" && exit 1)
	@mkdir -p archived/plan
	@mv "$(FILE)" archived/plan/
	@echo "✅ Arquivado: $(FILE) → archived/plan/"
