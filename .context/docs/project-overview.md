---
type: doc
name: project-overview
description: High-level overview of the project, its purpose, and key components
category: overview
generated: 2026-01-25
status: unfilled
scaffoldVersion: "2.0.0"
---

## Project Overview

Este projeto fornece scripts automatizados para construir imagens ISO do Debian com suporte completo ao ZFS como sistema de arquivos raiz. Ele simplifica a criação de sistemas Debian otimizados para ZFS, incluindo o ZFS Boot Menu para boot confiável.

## Codebase Reference

> **Análise Detalhada**: Para contagens completas de símbolos, camadas de arquitetura e gráficos de dependências, consulte [`codebase-map.json`](./codebase-map.json).

## Quick Facts

- **Raiz**: `/home/helton/git/build-iso`
- **Linguagens**: Bash (scripts principais), alguns utilitários em outras linguagens
- **Entrada Principal**: `build-debian-trixie-zbm.sh`
- **Análise Completa**: [`codebase-map.json`](./codebase-map.json)

## Entry Points

- [`build-debian-trixie-zbm.sh`](build-debian-trixie-zbm.sh) - Script principal de construção da ISO

## Key Exports

O projeto não exporta bibliotecas, mas produz artefatos como ISOs e checksums.

## File Structure & Code Organization

- `include/` — Arquivos a serem incluídos na ISO final
- `scripts/` — Scripts auxiliares e de teste
- `tests/` — Testes automatizados
- `cache/` — Cache de downloads e builds
- `plans/` — Planos de desenvolvimento

## Technology Stack Summary

- **Linguagem Principal**: Bash
- **Sistema Operacional**: Linux
- **Ferramentas**: debootstrap, ZFS tools, parted
- **Build**: Scripts nativos sem sistemas de build complexos

## Getting Started Checklist

1. Clonar o repositório
2. Executar `./build-debian-trixie-zbm.sh` para construir uma ISO
3. Verificar os testes com `./tests/test_installer.bats`
4. Revisar a documentação em `.context/docs/`

## Next Steps

Para contribuir, consulte o [Development Workflow](development-workflow.md) e [Tooling](tooling.md).
