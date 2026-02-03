# 001 - Plan: Refatoração e Ajuste de Caminhos (`main-v5`)

Este plano foca em garantir que todos os scripts de automação funcionem perfeitamente na nova estrutura de diretórios, utilizando a branch `main-v5`.

## Proposed Changes

### Branching
- Criação e uso da branch `main-v5` para isolar as mudanças de refatoração.

### Scripts de Automação

#### [MODIFY] scripts/download-zfsbootmenu.sh
- Ajustar caminhos de saída para `zbm-binaries/` (ou conforme preferência, talvez dentro de [build/](file:///home/helton/git/build-iso/.build) ou [cache/](file:///home/helton/git/build-iso/cache)).

#### [MODIFY] scripts/download-gum.sh
- Garantir que o binário vá para um local acessível durante o build (ex: `config-overrides/config/include.chroot/usr/bin/`).

#### [MODIFY] scripts/vm/vm-start-test-boot-iso.sh
- Corrigir o caminho da ISO para apontar para `output/*.iso`.
- Garantir detecção correta de OVMF.

#### [MODIFY] scripts/build-iso-in-docker.sh
- Validar se a injeção de binários (ZBM, Gum) está apontando para os novos diretórios.

---

## Verification Plan

### Automated Tests
- `make download-deps`
- `make build`
- `make test-iso`

### Manual Verification
- Validar se as ISOs são geradas em `output/`.
- Validar se os logs em `logs/` são legíveis e completos.
