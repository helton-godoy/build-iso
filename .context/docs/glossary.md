---
type: doc
name: glossary
description: Project terminology, type definitions, domain entities, and business rules
category: glossary
generated: 2026-01-25
status: unfilled
scaffoldVersion: "2.0.0"
---

## Glossary & Domain Concepts

Este documento define termos específicos do projeto de construção de ISOs Debian com ZFS.

## Type Definitions

Como projeto em Bash, não há definições de tipos formais, mas as seguintes variáveis são usadas consistentemente:

- `DISK_SIZE`: Tamanho do disco virtual em GB
- `POOL_NAME`: Nome do pool ZFS
- `HOSTNAME`: Nome do host do sistema instalado

## Enumerations

Não aplicável - projeto usa scripts Bash sem enums.

## Core Terms

- **ISO**: Imagem de instalação do Debian
- **ZFS**: Sistema de arquivos avançado usado para o sistema raiz
- **ZFS Boot Menu**: Bootloader especializado para sistemas ZFS
- **Debootstrap**: Ferramenta para instalar um sistema Debian básico
- **Chroot**: Ambiente isolado para configuração do sistema

## Acronyms & Abbreviations

- **ZBM**: ZFS Boot Menu
- **EFI**: Extensible Firmware Interface (para boot UEFI)
- **GRUB**: Grand Unified Bootloader (alternativa ao ZBM)

## Personas / Actors

- **Desenvolvedor**: Mantém e aprimora os scripts de construção
- **Usuário Final**: Utiliza a ISO para instalar Debian com ZFS
- **Administrador de Sistema**: Configura e mantém sistemas ZFS

## Domain Rules & Invariants

- Sistema deve ser compatível com Debian Trixie
- ZFS deve ser a versão estável mais recente
- ISO deve ser bootável em sistemas UEFI e legacy
- Todos os componentes devem ter tratamento de erros adequado
