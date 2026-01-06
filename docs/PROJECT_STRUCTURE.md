# Estrutura do Projeto `build-iso`

Este documento descreve a organização de diretórios do projeto e serve como guia para novos colaboradores e para a automação do pipeline.

## Diretórios Raiz

### Fontes e Configurações
- **`config/`**: Contém a configuração do `live-build`. É aqui que definimos pacotes, hooks e arquivos a serem incluídos na ISO.
- **`docker/`**: Arquivos relacionados ao ambiente de build em container (Dockerfile).
- **`scripts/`**: Scripts de automação para build, download de binários, instalação e testes.
- **`conductor/`**: Metadados, especificações e planos de desenvolvimento (Conductor framework).
- **`docs/`**: Documentação técnica e arquitetural do projeto.

### Artefatos e Processamento (Gerados)
Estes diretórios devem ser mantidos limpos e são ignorados pelo Git (exceto quando indicado).

- **`build/`**: Arquivos temporários gerados durante o processo de construção da ISO (ex: chroot, binary).
- **`cache/`**: Cache de pacotes (.deb) e do bootstrap do Debian para acelerar builds subsequentes.
- **`dist/`**: Local de destino das imagens ISO finalizadas e prontas para distribuição.
- **`logs/`**: Logs detalhados de cada etapa do pipeline de build.
- **`zbm-binaries/`**: Binários do ZFSBootMenu baixados externamente.

## Guia para Colaboradores

- **Onde criar novos scripts?** Sempre em `scripts/`. Use nomes descritivos e garanta que o script suporte os diretórios de saída definidos acima.
- **Onde adicionar pacotes na ISO?** Em `config/package-lists/`. Use arquivos separados por categoria (ex: `zfs.list.chroot`).
- **Onde adicionar arquivos customizados na ISO?** Em `config/includes.chroot/`. Siga a estrutura de diretórios do Linux (ex: `usr/local/bin/`).
- **Como tratar saídas de scripts?** Nunca escreva arquivos de saída ou logs na raiz do projeto. Use as variáveis de ambiente ou parâmetros para direcionar para `dist/` ou `logs/`.

---
*Última atualização: 06/01/2026*
