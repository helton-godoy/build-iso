# Plano da Trilha: Pipeline de Build ISO

## Fase 1: Configuração do Ambiente de Build (Docker) [checkpoint: a63bf76]
Esta fase foca em preparar o ambiente isolado onde o `live-build` será executado.

- [x] Task: Criar `Dockerfile` para o ambiente de build 20284e7
  - *Contexto:* Criar um arquivo `docker/Dockerfile` baseado em `debian:trixie-slim`.
  - *Detalhes:* Instalar `live-build`, `git`, `curl` e dependências básicas.
- [x] Task: Criar script wrapper `scripts/build-iso-in-docker.sh` [commit: e8ce04e]
  - *Contexto:* Script que constrói a imagem Docker (se necessário) e roda o container montando o diretório do projeto.
  - *Detalhes:* Deve garantir que os artefatos gerados pertençam ao usuário do host.
- [x] Task: Conductor - User Manual Verification 'Configuração do Ambiente de Build (Docker)' (Protocol in workflow.md)

## Fase 2: Configuração do Debian Live-Build
Nesta fase, configuraremos os parâmetros do `lb config` e a lista de pacotes.

- [ ] Task: Inicializar configuração do Live-Build
  - *Contexto:* Criar estrutura `config/` usando `lb config` via container.
  - *Detalhes:* Definir `--distribution trixie`, `--archive-areas "main contrib non-free-firmware"`, `--binary-images iso-hybrid`.
- [ ] Task: Definir listas de pacotes (ZFS e Utils)
  - *Contexto:* Criar `config/package-lists/zfs.list.chroot` e `tools.list.chroot`.
  - *Detalhes:* Incluir `zfs-dkms`, `zfsutils-linux`, `gdisk`, `dosfstools`, `efibootmgr`.
- [ ] Task: Integrar binários ZFSBootMenu via Hook
  - *Contexto:* Criar um hook em `config/hooks/live/` para copiar os arquivos de `./zbm-binaries` para dentro da imagem live.
  - *Detalhes:* Garantir que o script de download rodou antes ou rodar dentro do hook.
- [ ] Task: Conductor - User Manual Verification 'Configuração do Debian Live-Build' (Protocol in workflow.md)

## Fase 3: Execução e Validação
Executar o build completo e verificar a integridade básica do artefato.

- [ ] Task: Executar Build Completo
  - *Contexto:* Rodar `scripts/build-iso-in-docker.sh` e monitorar logs.
  - *Detalhes:* Corrigir dependências quebradas ou erros de build do DKMS se surgirem.
- [ ] Task: Verificação Estrutural da ISO
  - *Contexto:* Montar a ISO gerada em loopback e listar arquivos.
  - *Detalhes:* Confirmar presença de `pool/` (pacotes), initrd e kernel.
- [ ] Task: Conductor - User Manual Verification 'Execução e Validação' (Protocol in workflow.md)
