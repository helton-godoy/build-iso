---
type: doc
name: tooling
description: Scripts, IDE settings, automation, and developer productivity tips
category: tooling
generated: 2026-01-25
status: unfilled
scaffoldVersion: "2.0.0"
---

## Tooling & Productivity Guide

Este guia descreve as ferramentas e configurações necessárias para desenvolvimento eficiente no projeto.

## Required Tooling

- **Bash**: Shell principal, versão 4.0+
- **Bats**: Framework de testes para Bash
- **Git**: Controle de versão
- **ZFS tools**: Para manipulação de pools ZFS
- **debootstrap**: Para instalação base do Debian

## Recommended Automation

- **Testes**: Executar `./tests/test_installer.bats` antes de commits
- **Build**: `./build-debian-trixie-zbm.sh` para construir ISOs
- **Limpeza**: `./clean-build-artifacts.sh` para limpar builds

## IDE / Editor Setup

- **ShellCheck**: Para linting de scripts Bash
- **Bash language server**: Para autocompletar e navegação
- **EditorConfig**: Para consistência de formatação

## Productivity Tips

- Usar `set -euo pipefail` em scripts para tratamento robusto de erros
- Testar scripts em ambiente isolado antes de commit
- Manter bibliotecas em `lib/` para reutilização
- Documentar funções com comentários
