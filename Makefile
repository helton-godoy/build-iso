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

SQUASHFS_COMPRESSION_TYPE ?= zstd
SQUASHFS_COMPRESSION_LEVEL ?= 15
ISO_COMPRESSION_TYPE ?= xz

MAX_ISO_SIZE_GROWTH_PCT ?= 10
MAX_BUILD_TIME_REGRESSION_PCT ?= 15
MAX_BOOT_TIME_REGRESSION_PCT ?= 15
MAX_INSTALL_TIME_REGRESSION_PCT ?= 15

# Nome da imagem Docker
DOCKER_IMAGE_NAME = zbm-iso-builder

# VM Configuration
VM_NAME_UEFI  = nas-test-uefi
VM_NAME_BIOS  = nas-test-bios
VM_SOCKET_UEFI = /tmp/$(VM_NAME_UEFI).sock
VM_SOCKET_BIOS = /tmp/$(VM_NAME_BIOS).sock
VM_DISK_PATH_UEFI = scripts/vm/disks/uefi/installed-system.qcow2
VM_DISK_PATH_BIOS = scripts/vm/disks/bios/installed-system.qcow2
VM_LIVE_BOOT_WAIT ?= 30

# -----------------------------------------------------------------------------
# Targets Phony (sempre executados)
# -----------------------------------------------------------------------------
.PHONY: all help build download-zbm setup-docker build-iso clean
.PHONY: setup-vm vm-list vm-destroy vm-destroy-all
.PHONY: test-vm-uefi test-vm-bios test-vm-all vm-connect-uefi vm-connect-bios
.PHONY: vm-boot-disk-uefi vm-boot-disk-bios
.PHONY: docs docs-installer docs-dev docs-tests docs-all docs-markdown docs-stats verify-docs
.PHONY: comment-index comment-graph verify-comment-contract
.PHONY: iso-metrics-baseline iso-metrics-current verify-squashfs-profile verify-iso-performance verify-firmware-compat verify-iso-gates
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
	@echo "  make vm-connect-uefi CMD=\"<cmd>\" - Executa análise remota na VM UEFI"
	@echo "  make vm-connect-bios CMD=\"<cmd>\" - Executa análise remota na VM BIOS"
	@echo "  make vm-show-ip     - Exibe IPs em cache das VMs (UEFI/BIOS)"
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
	@echo "  make comment-index    - Gera índice semântico (TXT + JSONL) para RAG"
	@echo "  make comment-graph    - Gera grafo Mermaid do fluxo por comentários"
	@echo "  make verify-comment-contract - Valida contrato PDS-Bash"
	@echo "  make iso-metrics-baseline - Coleta baseline versionado de métricas ISO"
	@echo "  make iso-metrics-current - Coleta métricas correntes da ISO"
	@echo "  make verify-squashfs-profile - Valida compressor do filesystem.squashfs"
	@echo "  make verify-iso-performance - Aplica gate de regressão das métricas"
	@echo "  make verify-firmware-compat - Executa validação UEFI+BIOS"
	@echo "  make verify-iso-gates - Executa perfil, regressão e firmware"
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
		-e SQUASHFS_COMPRESSION_TYPE="$(SQUASHFS_COMPRESSION_TYPE)" \
		-e SQUASHFS_COMPRESSION_LEVEL="$(SQUASHFS_COMPRESSION_LEVEL)" \
		-e ISO_COMPRESSION_TYPE="$(ISO_COMPRESSION_TYPE)" \
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
iso-metrics-baseline: ## Coleta baseline versionado de métricas da ISO
	@echo "📊 Coletando baseline de métricas da ISO..."
	@bash scripts/collect-iso-metrics.sh --mode baseline --firmware all --label baseline
	@bash scripts/collect-iso-metrics.sh --mode baseline --firmware uefi --label baseline-uefi
	@bash scripts/collect-iso-metrics.sh --mode baseline --firmware bios --label baseline-bios

iso-metrics-current: ## Coleta métricas correntes da ISO
	@echo "📊 Coletando métricas correntes da ISO..."
	@bash scripts/collect-iso-metrics.sh --mode current --firmware all --label current
	@bash scripts/collect-iso-metrics.sh --mode current --firmware uefi --label current-uefi
	@bash scripts/collect-iso-metrics.sh --mode current --firmware bios --label current-bios

verify-squashfs-profile: ## Valida perfil de compressão do filesystem.squashfs
	@echo "🧩 Validando perfil de compressão SquashFS..."
	@EXPECTED_SQUASHFS_COMPRESSION_TYPE="$(SQUASHFS_COMPRESSION_TYPE)" \
	bash scripts/verify-squashfs-profile.sh

verify-iso-performance: ## Aplica gate de regressão nas métricas de ISO
	@echo "🚦 Validando gate de performance da ISO..."
	@MAX_ISO_SIZE_GROWTH_PCT="$(MAX_ISO_SIZE_GROWTH_PCT)" \
	MAX_BUILD_TIME_REGRESSION_PCT="$(MAX_BUILD_TIME_REGRESSION_PCT)" \
	MAX_BOOT_TIME_REGRESSION_PCT="$(MAX_BOOT_TIME_REGRESSION_PCT)" \
	MAX_INSTALL_TIME_REGRESSION_PCT="$(MAX_INSTALL_TIME_REGRESSION_PCT)" \
	bash scripts/verify-iso-performance-gate.sh

verify-firmware-compat: ## Executa validação obrigatória em UEFI+BIOS
	@echo "🧪 Validando compatibilidade de firmware (UEFI+BIOS)..."
	@$(MAKE) test-vm-all

verify-iso-gates: verify-squashfs-profile verify-iso-performance verify-firmware-compat ## Executa gates completos de promoção da ISO
	@echo "✅ Gates de ISO concluídos"

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
	@echo "🔌 Executando análise remota na VM UEFI..."
	@chmod +x $(VM_DIR)/vm-connect-agent-llm.sh
	@VM_CMD="$(CMD)" VM_IP="$(VM_IP)" VM_LIVE_BOOT_WAIT="$(VM_LIVE_BOOT_WAIT)" bash $(VM_DIR)/vm-connect-agent-llm.sh uefi

vm-connect-bios:
	@echo "🔌 Executando análise remota na VM BIOS..."
	@chmod +x $(VM_DIR)/vm-connect-agent-llm.sh
	@VM_CMD="$(CMD)" VM_IP="$(VM_IP)" VM_LIVE_BOOT_WAIT="$(VM_LIVE_BOOT_WAIT)" bash $(VM_DIR)/vm-connect-agent-llm.sh bios

vm-show-ip:
	@echo "📡 IPs em cache das VMs:"
	@STATE_FILE="$(VM_DIR)/.cache/vm-ips.env"; \
	if [ -f "$$STATE_FILE" ]; then \
	  grep -E '^VM_IP_(UEFI|BIOS)=' "$$STATE_FILE" || echo "Nenhum IP de VM encontrado no cache."; \
	  echo "Arquivo de estado: $$STATE_FILE"; \
	else \
	  echo "Cache ainda não existe. Execute vm-connect-uefi/bios com CMD para popular."; \
	  echo "Arquivo esperado: $$STATE_FILE"; \
	fi

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

comment-index:
	@mkdir -p $(OUTPUT_DIR)/comment-index
	@chmod +x scripts/comment-index.sh
	@ROOT=. OUT_DIR=$(OUTPUT_DIR)/comment-index FORMAT=index bash scripts/comment-index.sh
	@echo "📄 Índice: $(OUTPUT_DIR)/comment-index/comment-index.txt"
	@echo "📄 JSONL: $(OUTPUT_DIR)/comment-index/comment-index.jsonl"

comment-graph:
	@mkdir -p $(OUTPUT_DIR)/comment-index
	@chmod +x scripts/comment-index.sh
	@ROOT=. OUT_DIR=$(OUTPUT_DIR)/comment-index FORMAT=graph bash scripts/comment-index.sh
	@echo "📈 Grafo Mermaid: $(OUTPUT_DIR)/comment-index/comment-flow.mmd"

verify-comment-contract:
	@echo "🔎 Validando contrato de comentários (PDS-Bash)..."
	@chmod +x tests/test-comment-contract.sh
	@bash tests/test-comment-contract.sh

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
