## Why

O projeto **build-iso** está na Fase 2 (Build ISO) com infraestrutura básica implementada, mas falta a **peça central**: o script instalador interativo que será executado pelo usuário após o boot da ISO Live.

Atualmente:
- ✅ ISO bootável gerada com módulos ZFS pré-compilados
- ✅ ZFSBootMenu injetado na ISO
- ❌ **Nenhum instalador** — o usuário precisa executar comandos manualmente

O instalador é crítico para atingir o marco **M2 (07/02/2026)**: "Installer automatizado implementado".

## What Changes

- **Novo script `install-zfs-debian`**: Instalador interativo TTY usando o Design System v2.0 monocromático com `gum`
- **Detecção automática de firmware**: Identificação UEFI vs Legacy BIOS
- **Particionamento híbrido**: ESP (512MB) + BIOS Boot (1MB) + ZFS para suporte dual-boot
- **Criação de pool ZFS**: `zroot` com datasets otimizados para Debian + ZFSBootMenu
- **Configuração de sistema**: Hostname, usuário, timezone, locales
- **Integração com ZFSBootMenu**: Instalação e configuração do bootloader

## Capabilities

### New Capabilities

- `installer-ui`: Sistema de interface do instalador usando Design System v2.0 monocromático (hero, sections, cards, progress, forms, selectors)
- `disk-detection`: Detecção e listagem de discos disponíveis com informações (tamanho, modelo, tipo)
- `firmware-detection`: Identificação automática do modo de boot (UEFI/BIOS)
- `partitioning`: Particionamento GPT híbrido (ESP + BIOS Boot + ZFS)
- `zfs-setup`: Criação de pool e datasets ZFS otimizados
- `system-config`: Configuração de hostname, usuário, timezone, locales
- `zbm-install`: Instalação e configuração do ZFSBootMenu

### Modified Capabilities

_(Nenhuma capability existente será modificada — este é um novo subsistema)_

## Impact

| Área | Impacto |
|------|---------|
| **Novos arquivos** | `scripts/install-zfs-debian`, `scripts/lib/fileserver-ds.sh`, `scripts/lib/installer/*.sh` |
| **Dependências ISO** | `gum` (charmbracelet), `gdisk`, `efibootmgr`, `dosfstools` |
| **Hooks live-build** | Hook para incluir scripts de instalação em `/usr/local/bin/` |
| **Documentação** | Guia de uso do instalador |
| **Testes** | Scripts de teste para cada capability (`test_installer_*.sh`) |
