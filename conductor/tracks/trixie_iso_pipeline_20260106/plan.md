# Plan: Pipeline de Build ISO Debian (Trixie) com ZFS e Teste Automatizado

## Phase 1: Arquitetura de Diretórios e Organização [checkpoint: 86f4f8c]
- [x] **Task: Definir e documentar a estrutura de diretórios do projeto** 511f615
- [x] **Task: Refatorar estrutura atual para limpar a raiz** 4adfec4
- [x] **Task: Conductor - User Manual Verification 'Arquitetura e Organização' (Protocol in workflow.md)**

## Phase 2: Auditoria e Reconhecimento
- [x] **Task: Auditar arquivos existentes e estado atual** 9df517b
- [ ] **Task: Conductor - User Manual Verification 'Auditoria' (Protocol in workflow.md)**

## Phase 3: Ambiente de Build (Docker & Orquestração) [checkpoint: bc6a414]
- [x] **Task: Configurar/Atualizar Dockerfile para Debian Trixie**
- [x] **Task: Ajustar configurações do live-build para Trixie**
- [x] **Task: Validar script de orquestração `scripts/build-iso-in-docker.sh`** ba043bb
- [x] **Task: Conductor - User Manual Verification 'Ambiente de Build' (Protocol in workflow.md)**

## Phase 4: Integração ZFS e Configuração do Sistema [checkpoint: 0e9e698]
- [x] **Task: Refinar listas de pacotes (Package Lists)** 5039288
- [x] **Task: Implementar hook para compilação DKMS do ZFS** ac0deaa
- [x] **Task: Conductor - User Manual Verification 'Integração ZFS' (Protocol in workflow.md)**

## Phase 5: Implementação do Instalador e Injeção de Binários
- [x] **Task: Refinar o script de instalação `scripts/install.sh`** 3657819
- [x] **Task: Injeção de arquivos e permissões** 9b98d8e
    - [x] Garantir que os binários do ZBM em `zbm-binaries/` sejam injetados em `config/includes.chroot/usr/share/zfsbootmenu/`.
- [ ] **Task: Conductor - User Manual Verification 'Instalador e Injeção' (Protocol in workflow.md)**

## Phase 6: Validação Automatizada
- [ ] **Task: Implementar `scripts/test-iso.sh`**
- [ ] **Task: Realizar teste de ponta a ponta**
- [ ] **Task: Conductor - User Manual Verification 'Validação Automatizada' (Protocol in workflow.md)**