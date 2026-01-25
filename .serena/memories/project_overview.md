# Build-ISO Project Overview

## Propósito

Sistema automatizado para gerar imagens ISO personalizadas do **Debian Trixie (testing)** com:

- **kmscon customizado** (terminal avançado com suporte a truecolor e emojis)
- **ZFSBootMenu** para boot em sistemas ZFS
- Suporte dual-boot: **BIOS Legacy + UEFI**
- Localização PT-BR completa (idioma, teclado ABNT2, timezone America/Sao_Paulo)

## Stack Tecnológica

- **Docker**: Ambiente de build isolado e reprodutível
- **live-build**: Ferramenta oficial Debian para criação de ISOs live
- **Shell Script (Bash)**: Scripts de automação
- **ZFS**: Sistema de arquivos enterprise
- **kmscon**: Terminal moderno com GPU acceleration (DRM/KMS)

## Arquitetura de Build

1. **Multi-stage Dockerfile**:
   - Estágio 1: Compilação do kmscon customizado (v9.3+)
   - Estágio 2: Ambiente de build da ISO

2. **Script Principal**: `debian_trixie_builder-v2.sh` (~1316 linhas)
   - Gera Dockerfile, entrypoint, e configuração do live-build
   - Executa build completo em container Docker privilegiado

## Estrutura de Diretórios

```
build-iso/
├── Dockerfile              # Multi-stage para kmscon + build env
├── docker-entrypoint.sh    # Script de entrada do container
├── debian_trixie_builder-v2.sh  # Script principal de build
├── config/                 # Configurações do live-build
│   ├── configure-live-build.sh
│   ├── hooks/             # Hooks de personalização
│   └── includes.chroot/   # Arquivos para incluir no sistema
├── include/               # Arquivos incluídos na ISO
│   └── usr/              # Estrutura do sistema de arquivos
├── live-build-config/    # Diretório de trabalho do live-build
├── build/                # Diretório temporário de build
└── output/               # ISOs e checksums gerados
```

## Usuário Padrão da ISO

- **Username**: debian
- **Password**: live
- **Sudo**: NOPASSWD habilitado
