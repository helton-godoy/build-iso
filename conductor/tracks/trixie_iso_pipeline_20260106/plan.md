# Plan: Pipeline de Build ISO Debian (Trixie) com ZFS e Teste Automatizado

## Phase 1: Arquitetura de Diretórios e Organização
- [x] **Task: Definir e documentar a estrutura de diretórios do projeto** 511f615
    - [x] Criar/Atualizar `docs/PROJECT_STRUCTURE.md` detalhando a finalidade de cada diretório e onde novos artefatos devem ser criados.
    - [x] Definir locais padrão para logs (`logs/`), artefatos de build (`build/`), cache (`cache/`) e saídas finais (`dist/` ou `release/`).
- [x] **Task: Refatorar estrutura atual para limpar a raiz** 4adfec4
    - [x] Mover logs e arquivos temporários da raiz para seus diretórios apropriados.
    - [x] Atualizar `.gitignore` para refletir a nova estrutura e ignorar artefatos gerados.
    - [x] Ajustar scripts existentes para respeitar os novos caminhos de saída/entrada.
- [ ] **Task: Conductor - User Manual Verification 'Arquitetura e Organização' (Protocol in workflow.md)**

## Phase 2: Auditoria e Reconhecimento
- [ ] **Task: Auditar arquivos existentes e estado atual**
    - [ ] Verificar conteúdo de `config/`, `auto/` e scripts existentes à luz da nova estrutura.
    - [ ] Identificar o que já está implementado vs. o que precisa de ajuste para Trixie.
    - [ ] Atualizar este plano marcando tarefas já concluídas se aplicável.
- [ ] **Task: Conductor - User Manual Verification 'Auditoria' (Protocol in workflow.md)**

## Phase 3: Ambiente de Build (Docker & Orquestração)
- [ ] **Task: Configurar/Atualizar Dockerfile para Debian Trixie**
    - [ ] Garantir base image `debian:trixie`.
    - [ ] Verificar instalação de `live-build`, `live-config`, `dkms`, `linux-headers-amd64`, `build-essential`.
- [ ] **Task: Ajustar configurações do live-build para Trixie**
    - [ ] Atualizar `auto/config` para usar `--distribution trixie` e `--architectures amd64`.
    - [ ] Garantir repositórios: `main`, `contrib`, `non-free`, `non-free-firmware`.
- [ ] **Task: Validar script de orquestração `scripts/build-iso-in-docker.sh`**
    - [ ] Ajustar script para usar os novos diretórios de saída definidos na Phase 1.
    - [ ] Garantir que o script monta volumes corretamente e executa o build no container.
- [ ] **Task: Conductor - User Manual Verification 'Ambiente de Build' (Protocol in workflow.md)**

## Phase 4: Integração ZFS e Configuração do Sistema
- [ ] **Task: Configurar listas de pacotes (Package Lists)**
    - [ ] Criar/Validar `config/package-lists/zfs.list.chroot` com `zfs-dkms`, `zfsutils-linux`.
    - [ ] Criar/Validar `config/package-lists/tools.list.chroot` (ferramentas de disco/rede).
- [ ] **Task: Implementar hook para compilação DKMS do ZFS**
    - [ ] Garantir existência de hook para compilar módulos ZFS no kernel da ISO.
    - [ ] Verificar persistência dos módulos no sistema de arquivos final.
- [ ] **Task: Conductor - User Manual Verification 'Integração ZFS' (Protocol in workflow.md)**

## Phase 5: Implementação do Instalador e Injeção de Binários
- [ ] **Task: Desenvolver/Refinar o script de instalação `install-zfs-debian`**
    - [ ] Assegurar suporte a particionamento híbrido (UEFI/BIOS).
    - [ ] Implementar lógica de criação de pool/datasets ZFS.
    - [ ] Garantir cópia correta do sistema e configuração do ZFSBootMenu.
- [ ] **Task: Injeção de arquivos e permissões**
    - [ ] Organizar `config/includes.chroot/` para instalador e binários ZBM.
    - [ ] Definir permissões de execução.
- [ ] **Task: Conductor - User Manual Verification 'Instalador e Injeção' (Protocol in workflow.md)**

## Phase 6: Validação Automatizada
- [ ] **Task: Implementar `scripts/test-iso.sh`**
    - [ ] Criar script QEMU para teste de boot (UEFI e BIOS).
    - [ ] Ajustar script para buscar ISO no novo diretório de saída (`dist/` ou similar).
- [ ] **Task: Realizar teste de ponta a ponta**
    - [ ] Executar build completo da ISO Trixie.
    - [ ] Validar boot e funcionalidade básica em VM.
- [ ] **Task: Conductor - User Manual Verification 'Validação Automatizada' (Protocol in workflow.md)**