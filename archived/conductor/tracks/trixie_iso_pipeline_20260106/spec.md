# Specification: Pipeline de Build ISO Debian (Trixie) com ZFS e Teste Automatizado

## Overview

Implementar o pipeline completo de construção de uma imagem ISO Live do Debian Trixie (Testing), otimizada para instalação de sistemas com ZFS-on-root e ZFSBootMenu. O projeto foca em uma arquitetura de "Build Factory" em Docker e uma organização de diretórios limpa e intuitiva para facilitar a automação e colaboração.

## Functional Requirements

- **Arquitetura de Diretórios:** Limpar a raiz do projeto, movendo logs, caches e artefatos de build para diretórios específicos (`logs/`, `cache/`, `dist/`).
- **Documentação de Estrutura:** Criar guia para novos colaboradores sobre a organização do projeto.
- **Build Factory (Docker):** Criar/Atualizar `Dockerfile` baseado em Debian Trixie com todas as dependências de build (`live-build`, `dkms`, etc.).
- **Configuração Live-Build:**
  - Usar distribuição `trixie` e arquitetura `amd64`.
  - Repositórios: `main`, `contrib`, `non-free`, `non-free-firmware`.
  - Garantir compilação e persistência do módulo ZFS na ISO.
- **Instalador Interativo:** Refinar o script `install-zfs-debian` para suporte a boot híbrido (UEFI/BIOS) e configuração guiada de ZFS.
- **Validação Automatizada:** Implementar `scripts/test-iso.sh` com QEMU para validar o boot da ISO gerada.

## Non-Functional Requirements

- **Organização:** Raiz do projeto livre de arquivos temporários e de processamento.
- **Reprodutibilidade:** Build consistente via Docker.
- **Instalação Offline:** ISO autossuficiente para instalação do sistema.

## Acceptance Criteria

1. Estrutura de diretórios refatorada e documentada em `docs/PROJECT_STRUCTURE.md`.
2. O comando `./scripts/build-iso-in-docker.sh` gera uma ISO Debian Trixie funcional.
3. A ISO gerada contém os módulos de kernel do ZFS pré-compilados.
4. O script `scripts/test-iso.sh` valida com sucesso o boot da ISO em UEFI e BIOS.

## Out of Scope

- Implementação de GUI para o instalador.
- Suporte a arquiteturas não-x86_64.
