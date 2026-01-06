# Plan: Pipeline de Build ISO Debian (Trixie) com ZFS e Teste Automatizado

## Phase 1: Arquitetura de Diretórios e Organização [checkpoint: 86f4f8c]
- [x] **Task: Definir e documentar a estrutura de diretórios do projeto** 511f615
- [x] **Task: Refatorar estrutura atual para limpar a raiz** 4adfec4
- [x] **Task: Conductor - User Manual Verification 'Arquitetura e Organização' (Protocol in workflow.md)**

## Phase 2: Auditoria e Reconhecimento
- [x] **Task: Auditar arquivos existentes e estado atual** 1e8d53c
    - [x] Verificar conteúdo de `config/`, `auto/` e scripts existentes à luz da nova estrutura.
    - [x] Identificar o que já está implementado vs. o que precisa de ajuste para Trixie.
    - [x] Atualizar este plano marcando tarefas já concluídas se aplicável.
- [ ] **Task: Conductor - User Manual Verification 'Auditoria' (Protocol in workflow.md)**

## Phase 3: Ambiente de Build (Docker & Orquestração)
- [x] **Task: Configurar/Atualizar Dockerfile para Debian Trixie** (Já validado na Phase 2)
- [x] **Task: Ajustar configurações do live-build para Trixie** (Já validado na Phase 2)
- [ ] **Task: Validar script de orquestração `scripts/build-iso-in-docker.sh`**
    - [ ] Garantir que o script monta volumes corretamente para `cache/`, `build/` e `logs/`.
- [ ] **Task: Conductor - User Manual Verification 'Ambiente de Build' (Protocol in workflow.md)**

## Phase 4: Integração ZFS e Configuração do Sistema
- [ ] **Task: Refinar listas de pacotes (Package Lists)**
    - [ ] Garantir `non-free-firmware` e drivers básicos em `tools.list.chroot`.
    - [ ] Validar dependências do ZFS para Trixie.
- [ ] **Task: Implementar hook para compilação DKMS do ZFS**
    - [ ] Criar hook em `config/hooks/live/` para compilar módulos ZFS no kernel da ISO.
- [ ] **Task: Conductor - User Manual Verification 'Integração ZFS' (Protocol in workflow.md)**

## Phase 5: Implementação do Instalador e Injeção de Binários
- [ ] **Task: Refinar o script de instalação `scripts/install.sh`**
    - [ ] Implementar a cópia do sistema via `rsync` ou `unsquashfs` do ambiente live.
    - [ ] Mover para `config/includes.chroot/usr/local/bin/install-system`.
- [ ] **Task: Injeção de arquivos e permissões**
    - [ ] Garantir que os binários do ZBM em `zbm-binaries/` sejam injetados em `config/includes.chroot/usr/share/zfsbootmenu/`.
- [ ] **Task: Conductor - User Manual Verification 'Instalador e Injeção' (Protocol in workflow.md)**

## Phase 6: Validação Automatizada
- [ ] **Task: Implementar `scripts/test-iso.sh`**
    - [ ] Criar script QEMU para teste de boot (UEFI e BIOS).
- [ ] **Task: Realizar teste de ponta a ponta**
- [ ] **Task: Conductor - User Manual Verification 'Validação Automatizada' (Protocol in workflow.md)**
