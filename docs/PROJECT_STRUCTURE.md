# Estrutura do Projeto `build-iso`

Este documento descreve a organização de diretórios do projeto e serve como guia para novos colaboradores e para a automação do pipeline.

## Diretórios Raiz

### Fontes e Configurações

- **`config/`**: Contém a configuração do `live-build`. É aqui que definimos pacotes, hooks e arquivos a serem incluídos na ISO.
- **`docker/`**: Arquivos relacionados ao ambiente de build em container (Dockerfile).
- **`scripts/`**: Scripts de automação para build, download de binários, instalação e testes.
- **`conductor/`**: Metadados, especificações e planos de desenvolvimento (Conductor framework).
- **`docs/`**: Documentação técnica e arquitetural do projeto.
- **`auto/`**: Scripts de automação do `live-build`.
- **`tests/`**: Suite de testes automatizados (Bash scripts).
- **`plans/`**: Blueprints arquiteturais e propostas iniciais do projeto.

### Artefatos e Processamento (Encapsulados)

Para manter a raiz do projeto limpa e intuitiva, todos os arquivos gerados pelo processamento do Docker e do `live-build` ficam confinados em um subdiretório do Docker ou em áreas de trabalho temporárias.

- **`docker/artifacts/`**: Diretório base para todos os artefatos de build.
  - **`build/`**: Arquivos temporários de build (chroot, binary, local).
  - **`cache/`**: Cache de pacotes e bootstrap.
  - **`dist/`**: Imagens ISO finalizadas e prontas para uso.
  - **`logs/`**: Logs de todas as etapas do processo.

- **`work/`**: Diretório de trabalho local para desenvolvimento e testes (ignorado pelo Git).
  - **`work/vm/`**: Armazena discos virtuais e arquivos temporários do QEMU).

- **`zbm-binaries/`**: Binários do ZFSBootMenu baixados externamente (não commitados).

## Guia para Colaboradores

- **Onde criar novos scripts?** Sempre em `scripts/`.
- **Onde adicionar pacotes na ISO?** Em `config/package-lists/`.
- **Onde adicionar arquivos customizados na ISO?** Em `config/includes.chroot/`.
- **Como tratar saídas de scripts?** Utilize o diretório `docker/artifacts/` para qualquer arquivo gerado por processamento. O script `build-iso-in-docker.sh` gerencia isso automaticamente via links simbólicos e mapeamento de volumes.

---
Última atualização: 06/01/2026
