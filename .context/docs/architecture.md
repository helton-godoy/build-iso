---
type: doc
name: architecture
description: System architecture, layers, patterns, and design decisions
category: architecture
generated: 2026-01-25
status: unfilled
scaffoldVersion: "2.0.0"
---

## Architecture Notes

Este projeto é um conjunto de scripts Bash para construir uma imagem ISO do Debian com suporte ao ZFS Boot Menu. O sistema é projetado como um pipeline linear de scripts modulares que executam etapas sequenciais de validação, particionamento, instalação e configuração.

## System Architecture Overview

O sistema segue uma arquitetura de pipeline linear, onde o script principal `build-debian-trixie-zbm.sh` orquestra a execução de componentes modulares. Cada componente é um script Bash independente responsável por uma fase específica do processo de construção da ISO.

O fluxo principal envolve:
1. Validação de pré-requisitos
2. Particionamento do disco
3. Criação de pool ZFS
4. Extração e configuração do sistema base
5. Instalação do bootloader
6. Limpeza final

## Architectural Layers

- **Scripts Principais**: Scripts de orquestração (`build-debian-trixie-zbm.sh`)
- **Componentes**: Scripts modulares para cada fase (`include/usr/local/bin/installer/components/`)
- **Bibliotecas**: Utilitários compartilhados (`include/usr/local/bin/installer/lib/`)
- **Recursos**: Arquivos estáticos e binários (`include/usr/share/zfsbootmenu/`)

## Detected Design Patterns

| Pattern | Confidence | Locations | Description |
|---------|------------|-----------|-------------|
| Pipeline | 95% | `build-debian-trixie-zbm.sh` | Sequência linear de etapas de processamento |
| Modular Components | 90% | `components/*.sh` | Scripts independentes para cada fase |
| Library Pattern | 85% | `lib/*.sh` | Funções utilitárias compartilhadas |

## Entry Points

- [`build-debian-trixie-zbm.sh`](build-debian-trixie-zbm.sh) - Script principal de construção da ISO

## Public API

O projeto não expõe uma API pública formal, sendo executado via linha de comando.

## Internal System Boundaries

- **Validação**: Verificação de pré-requisitos do sistema
- **Particionamento**: Manipulação de discos e partições
- **ZFS**: Gerenciamento de pools e datasets ZFS
- **Sistema Base**: Instalação e configuração do Debian
- **Bootloader**: Configuração do ZFS Boot Menu

## External Service Dependencies

- Debian repositories (debootstrap)
- ZFS tools
- System utilities (parted, mount, etc.)

## Key Decisions & Trade-offs

- **Bash puro**: Escolha por simplicidade e portabilidade sobre linguagens mais modernas
- **Modularidade**: Scripts separados para facilitar manutenção e teste
- **ZFS focado**: Especialização em ZFS para sistemas de arquivos avançados

## Top Directories Snapshot

- `include/usr/local/bin/installer/components/` - 8 componentes de instalação
- `include/usr/local/bin/installer/lib/` - 5 bibliotecas utilitárias
- `include/usr/share/zfsbootmenu/` - Recursos do bootloader
- `scripts/` - Scripts auxiliares
- `tests/` - Testes automatizados

## Related Resources

- [Project Overview](project-overview.md)
- [Data Flow](data-flow.md)
- [Development Workflow](development-workflow.md)
