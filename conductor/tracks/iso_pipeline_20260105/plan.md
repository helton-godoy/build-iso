# Plano da Trilha: Pipeline de Build ISO

## Fase 1: Configuração do Ambiente de Build (Docker) [checkpoint: a63bf76]

Esta fase foca em preparar o ambiente isolado onde o `live-build` será executado.

- [x] Task: Criar `Dockerfile` para o ambiente de build 20284e7
  - _Contexto:_ Criar um arquivo `docker/Dockerfile` baseado em `debian:trixie-slim`.
  - _Detalhes:_ Instalar `live-build`, `git`, `curl` e dependências básicas.
- [x] Task: Criar script wrapper `scripts/build-iso-in-docker.sh` [commit: e8ce04e]
  - _Contexto:_ Script que constrói a imagem Docker (se necessário) e roda o container montando o diretório do projeto.
  - _Detalhes:_ Deve garantir que os artefatos gerados pertençam ao usuário do host.
- [x] Task: Conductor - User Manual Verification 'Configuração do Ambiente de Build (Docker)' (Protocol in workflow.md)

## Fase 2: Configuração do Debian Live-Build [checkpoint: 7e2017f]

Nesta fase, configuraremos os parâmetros do `lb config` e a lista de pacotes.

- [x] Task: Inicializar configuração do Live-Build [commit: 3c57dde]
  - _Contexto:_ Criar estrutura `config/` usando `lb config` via container.
  - _Detalhes:_ Definir `--distribution trixie`, `--archive-areas "main contrib non-free non-free-firmware"`, `--binary-images iso-hybrid`.
- [x] Task: Definir listas de pacotes (ZFS e Utils) [commit: dae38d3]
  - _Contexto:_ Criar `config/package-lists/zfs.list.chroot` e `tools.list.chroot`.
  - _Detalhes:_ Incluir `zfs-dkms`, `zfsutils-linux`, `gdisk`, `dosfstools`, `efibootmgr`.
- [x] Task: Integrar binários ZFSBootMenu via Hook [commit: d16de8f]
  - _Contexto:_ Criar um hook em `config/hooks/live/` para copiar os arquivos de `./zbm-binaries` para dentro da imagem live.
  - _Detalhes:_ Garantir que o script de download rodou antes ou rodar dentro do hook.
- [x] Task: Conductor - User Manual Verification 'Configuração do Debian Live-Build' (Protocol in workflow.md)

## Fase 3: Execução e Validação [checkpoint: 9ae5f12]

Executar o build completo e verificar a integridade básica do artefato.

- [x] Task: Executar Build Completo [commit: b9b8365]
- [x] Task: Verificação Estrutural da ISO [commit: b27264e]
- [x] Task: Conductor - User Manual Verification 'Execução e Validação' (Protocol in workflow.md)
