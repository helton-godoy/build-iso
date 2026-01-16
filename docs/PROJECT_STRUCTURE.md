# Estrutura do Projeto `build-iso`

Este documento descreve a organização de diretórios do projeto e serve como guia para novos colaboradores e para a automação do pipeline.

## Diretórios Raiz

### Fontes e Configurações

- **`docker/`**: Configuração do `live-build` e ambiente Docker.
  - **`config/`**: Configurações do live-build (package-lists, hooks, includes).
  - **`tools/`**: Script `build-iso-in-docker.sh`.
  - **`work/`**: Workspace de build (gerado).
  - **`dist/`**: ISOs finalizadas (gerado).
- **`include/`**: Overlay de arquivos a serem incluídos na ISO.
  - **`usr/local/bin/`**: Scripts (`install-system.sh`, `gum`).
  - **`usr/share/zfsbootmenu/`**: Binários ZFSBootMenu.
- **`tools/`**: Scripts auxiliares (`download-zfsbootmenu.sh`).
- **`tests/`**: Suite de testes automatizados (Bash scripts).
- **`docs/`**: Documentação técnica e arquitetural.
- **`qemu/`**: Scripts para testes em QEMU.
- **`conductor/`**: Metadados do framework Conductor.

### Artefatos e Build

- **`docker/dist/`**: Imagens ISO finalizadas.
- **`docker/work/`**: Arquivos temporários de build.
- **`docker/logs/`**: Logs do processo de build.

## Fluxo de Build

```
tools/download-zfsbootmenu.sh
        ↓
include/usr/share/zfsbootmenu/ (binários EFI)
        ↓
docker/tools/build-iso-in-docker.sh
        ↓
docker/dist/live-image-amd64.hybrid.iso
```

## Guia para Colaboradores

- **Scripts auxiliares:** `tools/`
- **DEBIAN_ZFS** `include/usr/local/bin/install-system.sh`
- **Pacotes na ISO:** `docker/config/package-lists/`
- **Overlay de arquivos:** `include/`
- **Configuração live-build:** `docker/config/`

---

Última atualização: 08/01/2026
