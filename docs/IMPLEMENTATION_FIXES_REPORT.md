# Relatório de Correções e Refinamentos

**Data:** 2026-02-14
**Change:** iso-build

## 1. Requisitos Atualizados

### Multi-disco
- **Spec:** `specs/disk-detection/spec.md` atualizado para permitir seleção múltipla.
- **Design:** `design.md` atualizado para refletir suporte a RAID.
- **Código:** `zfs_auto_topology.sh` já suportava, `disk-utils.sh` suporta seleção múltipla.

### Tamanho Mínimo de Disco
- **Requisito:** 20GB.
- **Correção:** `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/disk-utils.sh` linha 9: `MIN_DISK_SIZE_GB=20`.

### Detecção de Firmware
- **Requisito:** Exibição dinâmica no Welcome.
- **Correção:** `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/welcome.sh` usa `firmware_get_mode`.

### Suporte BIOS Legacy
- **Requisito:** Boot funcional em BIOS.
- **Implementação:**
    - `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/zbm-install.sh`: Adicionada função `zbm_configure_bios` (instala Syslinux MBR e loader).
    - `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/post_install.sh`: Chamada condicional para `zbm_configure_bios`.

## 2. Testes Atualizados
- `tests/test_installer_partitioning.sh`: Caminhos corrigidos.
- `tests/test_installer_zfs.sh`: Caminhos corrigidos.

## 3. Status
Todas as correções solicitadas foram implementadas e os artefatos OpenSpec foram sincronizados.
