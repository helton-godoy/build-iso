# zbm-install Specification

## Purpose
TBD - created by archiving change iso-build. Update Purpose after archive.
## Requirements
### Requirement: Instalação Bootloader
O sistema MUST instalar o ZFSBootMenu na partição ESP para boot UEFI e configurar suporte para BIOS legado.

#### Scenario: Instalação UEFI
- **WHEN** sistema detectado como UEFI (ou híbrido)
- **THEN** copiar `vmlinuz-zfsbootmenu` e `initramfs-zfsbootmenu` para ESP
- **AND** configurar entrada de boot EFI via `efibootmgr`

#### Scenario: Suporte Legacy BIOS
- **WHEN** instalação finalizada
- **THEN** instalar `syslinux` ou configurar partição para boot legacy se necessário (nota: ZBM tipicamente usa refind ou syslinux para chainload em BIOS, ou boot direto do firmware se suportado)
- **AND** garantir flag `legacy_boot` ou similar se requerido pelo hardware

### Requirement: Configuração ZFSBootMenu
O sistema MUST configurar propriedades do ZFS para que o ZFSBootMenu encontre o kernel do Debian.

#### Scenario: Kernel Command Line
- **WHEN** o sistema é instalado
- **THEN** garantir que `org.zfsbootmenu:commandline` do dataset `zroot/ROOT/debian` tenha parâmetros corretos (`root=zfs:zroot/ROOT/debian`, `spl.spl_hostid=...`)

### Requirement: Hostid Persistente
O sistema MUST gerar e persistir um hostid único para o pool ZFS.

#### Scenario: Gerar Hostid
- **WHEN** configurar bootloader
- **THEN** gerar hostid de 8 dígitos
- **AND** salvar em `/etc/hostid` no sistema alvo
- **AND** passar parâmetro `spl.spl_hostid` na linha de comando do kernel

