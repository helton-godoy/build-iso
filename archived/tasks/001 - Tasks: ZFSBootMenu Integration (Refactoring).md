# 001 - Tasks: ZFSBootMenu Integration (Refactoring)

- [ ] **Infrastructure & Scripts**
  - [x] Update [scripts/download-zfsbootmenu.sh](file:///home/helton/git/build-iso/scripts/download-zfsbootmenu.sh) to download ZBM binaries to `config-overrides/config/include.binary/` (EFI and BIOS components) <!-- id: 0 -->
  - [x] Create/Configure `isolinux.cfg` for BIOS bridge to ZBM <!-- id: 1 -->
  - [x] Update [scripts/docker/Dockerfile](file:///home/helton/git/build-iso/scripts/docker/Dockerfile) with `live-build`, `syslinux`, `xorriso`, `mtools`, `kmod` <!-- id: 2 -->
  - [x] Update [scripts/docker/entrypoint.sh](file:///home/helton/git/build-iso/scripts/docker/entrypoint.sh) to sync `config-overrides` and run `lb config/build` <!-- id: 3 -->
  - [x] Update [Makefile](file:///home/helton/git/build-iso/Makefile) to integrate new workflow (`download-zbm`, `setup-docker`, `build-iso`) <!-- id: 4 -->

- [ ] **Verification**
  - [x] Run `make download-zbm` and verify file placement <!-- id: 5 -->
  - [/] Run `make build-iso` and verify successful ISO generation <!-- id: 6 -->
  - [ ] (Optional) Test boot in UEFI and BIOS modes <!-- id: 7 -->
