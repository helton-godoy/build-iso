set shell := ["bash", "-euo", "pipefail", "-c"]

# =============================================================================
# Justfile - Interface Central de Desenvolvimento
# =============================================================================

default:
  @just --list

help:
  make help

# =============================================================================
# Workflow de Desenvolvimento (Interativo)
# =============================================================================

# Realizar um commit semântico interativo
commit:
  @if command -v gum >/dev/null; then \
    TYPE=$(gum choose "feat" "fix" "docs" "style" "refactor" "perf" "test" "chore" "revert" --header "Selecione o tipo de mudança"); \
    SCOPE=$(gum input --placeholder "Escopo da mudança (opcional)"); \
    SUMMARY=$(gum input --placeholder "Resumo curto"); \
    DESCRIPTION=$(gum write --placeholder "Descrição detalhada (opcional)" --width 80); \
    if [[ -n "$SCOPE" ]]; then \
      COMMIT_MSG="$TYPE($SCOPE): $SUMMARY"; \
    else \
      COMMIT_MSG="$TYPE: $SUMMARY"; \
    fi; \
    if [[ -n "$DESCRIPTION" ]]; then \
      COMMIT_MSG="$COMMIT_MSG\n\n$DESCRIPTION"; \
    fi; \
    echo "Commit Message Preview:"; \
    echo "-----------------------"; \
    echo -e "$COMMIT_MSG"; \
    echo "-----------------------"; \
    if gum confirm "Commitar?"; then \
      git commit -m "$COMMIT_MSG"; \
    else \
      echo "Cancelado."; \
    fi; \
  else \
    echo "Erro: gum não encontrado. Instale o gum para usar este comando."; \
    exit 1; \
  fi

# =============================================================================
# Build & Testes
# =============================================================================

download-zbm:
  make download-zbm

setup-docker:
  make setup-docker

build-iso:
  make build-iso

clean:
  make clean

setup-vm:
  make setup-vm

test-vm-uefi:
  make test-vm-uefi

test-vm-bios:
  make test-vm-bios

test-vm-all:
  make test-vm-all

# =============================================================================
# Conectividade VM
# =============================================================================

vm-connect-uefi:
  make vm-connect-uefi

vm-connect-bios:
  make vm-connect-bios

# =============================================================================
# Qualidade e Validação
# =============================================================================

lint:
  make lint

validate-configs:
  make validate-configs

# Validação completa (pré-push)
check: lint validate-configs docs-verify
  @echo "✅ Todos os checks passaram!"

# =============================================================================
# Documentação
# =============================================================================

docs:
  make docs

# Verifica integridade da documentação
docs-verify:
  make verify-docs

# =============================================================================
# Planejamento
# =============================================================================

plan-list:
  make plan-list

plan-archive file:
  make plan-archive FILE="{{file}}"
