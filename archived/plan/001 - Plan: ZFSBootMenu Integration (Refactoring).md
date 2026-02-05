# 001 - Plan: ZFSBootMenu Integration (Refactoring)

## Goal Description

Refactor the ISO build process to make **ZFSBootMenu (ZBM)** the primary bootloader.

- **UEFI Systems**: Load ZBM directly via `BOOTX64.EFI`.
- **BIOS Systems**: Use **Syslinux** as a bridge to load the ZBM kernel and initramfs immediately.

Reference: User provided research notes "Como configurar o live-build do Debian para incluir ZFSBootMenu...".

## Proposed Changes

### 1. Directory Structure & File Placement

We will update scripts to place ZBM binaries in locations that `live-build` creates in the ISO root.

- **UEFI Executable**: `config-overrides/config/include.binary/EFI/BOOT/BOOTX64.EFI`
- **BIOS Components**: `config-overrides/config/include.binary/zbm/vmlinuz` & `initramfs.img`
- **Bootloader Config**: `config-overrides/config/bootloaders/isolinux/isolinux.cfg`

### 2. Script Updates

#### [MODIFY] [scripts/download-zfsbootmenu.sh](file:///home/helton/git/build-iso/scripts/download-zfsbootmenu.sh)

- Update logic to download specifically:
  - EFI Release -> `.../EFI/BOOT/BOOTX64.EFI`
  - BIOS Release Components -> `.../zbm/vmlinuz` and `.../zbm/initramfs.img`
- Ensure target directories exist.

#### [NEW] [config-overrides/config/bootloaders/isolinux/isolinux.cfg](file:///home/helton/git/build-iso/config-overrides/config/bootloaders/isolinux/isolinux.cfg)

- Content:

  ```syslinux
  UI menu.c32
  PROMPT 0
  TIMEOUT 30
  MENU TITLE ZFSBootMenu BIOS Bridge
  LABEL zfsbootmenu
      MENU LABEL Start ZFSBootMenu
      KERNEL /zbm/vmlinuz
      APPEND initrd=/zbm/initramfs.img zbm.import_policy=hostid console=tty0
  ```

#### [MODIFY] [scripts/docker/Dockerfile](file:///home/helton/git/build-iso/scripts/docker/Dockerfile)

- Update base image to `debian:trixie-slim`.
- Install dependencies: `live-build`, `curl`, `syslinux-common`, `isolinux`, `xorriso`, `mtools`, `dosfstools`, `kmod`.

#### [MODIFY] [scripts/docker/entrypoint.sh](file:///home/helton/git/build-iso/scripts/docker/entrypoint.sh)

- Copy `config-overrides/*` to `/build/config/`.
- Run `lb config` with `--binary-images iso-hybrid`.
- Run `lb build`.

#### [MODIFY] [Makefile](file:///home/helton/git/build-iso/Makefile)

- Add `setup-docker` target.
- Update `build-iso` to depend on `download-zbm` and `setup-docker`.

## Verification Plan

### Automated

1. `make download-zbm`: Check if files exist in `config-overrides/config/include.binary/`.
2. `make build-iso`: Check if `output/*.iso` is created.

### Manual

- Inspect ISO contents (using `mount -o loop` or 7zip) to verify `/EFI/BOOT/BOOTX64.EFI` and `/zbm/` exist.
