---
type: doc
name: data-flow
description: How data moves through the system and external integrations
category: data-flow
generated: 2026-01-25
status: unfilled
scaffoldVersion: "2.0.0"
---

## Data Flow & Integrations

O fluxo de dados neste projeto segue um pipeline sequencial de construção de ISO. Os dados de entrada incluem parâmetros de configuração e URLs de repositórios Debian. O sistema processa esses dados através de etapas de validação, download, instalação e configuração, produzindo uma imagem ISO final.

## Module Dependencies

- **build-debian-trixie-zbm.sh** → `components/*.sh`, `lib/*.sh`
- **components/01-validate.sh** → `lib/validation.sh`, `lib/logging.sh`
- **components/02-partition.sh** → `lib/error.sh`, `lib/logging.sh`
- **components/03-pool.sh** → `lib/logging.sh`
- **components/04-datasets.sh** → `lib/logging.sh`
- **components/05-extract.sh** → `lib/chroot.sh`, `lib/logging.sh`
- **components/06-chroot-configure.sh** → `lib/chroot.sh`, `lib/logging.sh`
- **components/07-bootloader.sh** → `lib/logging.sh`
- **components/08-cleanup.sh** → `lib/logging.sh`

## Service Layer

O projeto não utiliza uma camada de serviços tradicional, mas os componentes funcionam como serviços modulares:

- [01-validate.sh](include/usr/local/bin/installer/components/01-validate.sh) - Validação de pré-requisitos
- [02-partition.sh](include/usr/local/bin/installer/components/02-partition.sh) - Particionamento de disco
- [03-pool.sh](include/usr/local/bin/installer/components/03-pool.sh) - Criação de pool ZFS
- [04-datasets.sh](include/usr/local/bin/installer/components/04-datasets.sh) - Configuração de datasets
- [05-extract.sh](include/usr/local/bin/installer/components/05-extract.sh) - Extração do sistema base
- [06-chroot-configure.sh](include/usr/local/bin/installer/components/06-chroot-configure.sh) - Configuração do sistema
- [07-bootloader.sh](include/usr/local/bin/installer/components/07-bootloader.sh) - Instalação do bootloader
- [08-cleanup.sh](include/usr/local/bin/installer/components/08-cleanup.sh) - Limpeza final

## High-level Flow

1. **Entrada**: Parâmetros de configuração (tamanho do disco, versão Debian, etc.)
2. **Validação**: Verificação de pré-requisitos do sistema
3. **Particionamento**: Criação de partições no disco virtual
4. **ZFS Setup**: Criação de pool e datasets ZFS
5. **Sistema Base**: Download e extração do Debian base via debootstrap
6. **Configuração**: Instalação de pacotes e configuração do sistema
7. **Bootloader**: Instalação do ZFS Boot Menu
8. **Saída**: Imagem ISO final

## Internal Movement

Os dados são passados entre componentes através de variáveis de ambiente e arquivos temporários. Cada componente registra seu progresso usando a biblioteca de logging compartilhada.

## External Integrations

- **Debian Repositories**: Download de pacotes via debootstrap e apt
- **ZFS Tools**: Utilitários do sistema ZFS para gerenciamento de pools
- **System Tools**: parted, mount, chroot para manipulação do sistema

## Observability & Failure Modes

O sistema utiliza logging extensivo através da biblioteca `lib/logging.sh`. Em caso de falha, os componentes registram erros detalhados e o processo é interrompido. Não há mecanismo de retry automático implementado.
