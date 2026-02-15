#!/usr/bin/env bash
# @INST_LIB_NAME: zbm-install
# @INST_DESC: Automacao do deploy do binario ZFSBootMenu e registro de boot.
# @INST_DEP: efibootmgr, cp, syslinux, dd

set -euo pipefail

ZBM_BIN_DIR="/usr/share/zfsbootmenu"
EFI_DIR="/boot/efi"
POOL_NAME="zroot"

zbm_install() {
  local esp_part="$1"
  local target="${2:-/mnt}"
  local pool="${3:-$POOL_NAME}"

  if [[ ! -b "$esp_part" ]]; then
    return 1
  fi

  mkdir -p "${target}${EFI_DIR}"
  mount "$esp_part" "${target}${EFI_DIR}"
  mkdir -p "${target}${EFI_DIR}/EFI/ZBM"

  if [[ -d "$ZBM_BIN_DIR" ]]; then
    if [[ -f "${ZBM_BIN_DIR}/zfsbootmenu.EFI" ]]; then
      cp "${ZBM_BIN_DIR}/zfsbootmenu.EFI" "${target}${EFI_DIR}/EFI/ZBM/"
    elif [[ -f "${ZBM_BIN_DIR}/BOOTX64.EFI" ]]; then
      cp "${ZBM_BIN_DIR}/BOOTX64.EFI" "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI"
    fi

    if [[ -f "${ZBM_BIN_DIR}/vmlinuz" ]]; then
      cp "${ZBM_BIN_DIR}/vmlinuz" "${target}${EFI_DIR}/EFI/ZBM/"
    fi

    if [[ -f "${ZBM_BIN_DIR}/initramfs.img" ]]; then
      cp "${ZBM_BIN_DIR}/initramfs.img" "${target}${EFI_DIR}/EFI/ZBM/"
    fi
  fi

  if [[ ! -f "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI" ]]; then
    if [[ -f "/zbm/vmlinuz" ]]; then
      mkdir -p "${target}${EFI_DIR}/EFI/ZBM"
      cp /zbm/vmlinuz "${target}${EFI_DIR}/EFI/ZBM/" 2>/dev/null || true
      cp /zbm/initramfs.img "${target}${EFI_DIR}/EFI/ZBM/" 2>/dev/null || true
    fi
  fi

  sync
}

zbm_configure_efi() {
  local disk="$1"
  local part_num="$2"

  if ! command -v efibootmgr &>/dev/null; then
    return 1
  fi

  efibootmgr --create \
    --disk "$disk" \
    --part "$part_num" \
    --label "ZFSBootMenu" \
    --loader "\\EFI\\ZBM\\zfsbootmenu.EFI" \
    --verbose || true
}

zbm_configure_bios() {
  local disk="$1"
  local esp_part="$2"
  local target="${3:-/mnt}"
  local mbr_bin="/usr/lib/syslinux/mbr/gptmbr.bin"
  local syslinux_cfg="${target}${EFI_DIR}/syslinux.cfg"

  if [[ ! -b "$disk" || ! -b "$esp_part" ]]; then
    return 1
  fi

  if [[ ! -f "$mbr_bin" ]]; then
    echo "AVISO: gptmbr.bin nao encontrado. Boot BIOS pode falhar."
    return 1
  fi

  if ! command -v syslinux &>/dev/null; then
    echo "AVISO: syslinux nao encontrado. Boot BIOS pode falhar."
    return 1
  fi

  dd if="$mbr_bin" of="$disk" bs=440 count=1 conv=notrunc 2>/dev/null || true
  syslinux --install "$esp_part" 2>/dev/null || true

  mkdir -p "$(dirname "$syslinux_cfg")"
  cat <<EOF >"$syslinux_cfg"
DEFAULT zfsbootmenu
PROMPT 0
TIMEOUT 0

LABEL zfsbootmenu
    LINUX /EFI/ZBM/vmlinuz
    INITRD /EFI/ZBM/initramfs.img
    APPEND zbm.prefer_policy=hostid quiet loglevel=0
EOF
}

zbm_configure_zfs_properties() {
  local pool="${1:-$POOL_NAME}"
  local hostid="${2:-}"

  if [[ -z "$hostid" ]]; then
    if [[ -f /etc/hostid ]]; then
      hostid=$(dd if=/etc/hostid bs=1 skip=0 count=4 2>/dev/null | od -A x -t x1 | head -1 | awk '{print $2$3$4$5}')
    else
      hostid=$(hostid 2>/dev/null || echo "00000000")
    fi
  fi

  local cmdline="quiet loglevel=4 root=zfs:${pool}/ROOT/debian"
  if [[ -n "$hostid" && "$hostid" != "00000000" ]]; then
    cmdline="${cmdline} spl.spl_hostid=0x${hostid}"
  fi

  zfs set org.zfsbootmenu:commandline="$cmdline" "${pool}/ROOT/debian"
  zpool set bootfs="${pool}/ROOT/debian" "$pool"
}

zbm_generate_hostid() {
  local target="${1:-}"

  if [[ -n "$target" && -d "$target" ]]; then
    zgenhostid -f -o "${target}/etc/hostid"
  else
    zgenhostid -f
  fi
}

zbm_get_hostid() {
  local target="${1:-}"
  local hostid_file="${target}/etc/hostid"

  if [[ -f "$hostid_file" ]]; then
    dd if="$hostid_file" bs=1 skip=0 count=4 2>/dev/null | od -A x -t x1 | head -1 | awk '{print $2$3$4$5}'
  else
    hostid 2>/dev/null | tr -d ' ' || echo "00000000"
  fi
}

zbm_setup_fallback() {
  local esp_part="$1"
  local target="${2:-/mnt}"

  if [[ ! -b "$esp_part" ]]; then
    return 1
  fi

  mkdir -p "${target}${EFI_DIR}/EFI/BOOT"
  if [[ -f "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI" ]]; then
    cp "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI" \
      "${target}${EFI_DIR}/EFI/BOOT/BOOTX64.EFI"
  fi
}

zbm_unmount_esp() {
  local target="${1:-/mnt}"
  umount "${target}${EFI_DIR}" 2>/dev/null || true
}

zbm_verify() {
  local target="${1:-/mnt}"
  local errors=0

  if [[ ! -f "${target}${EFI_DIR}/EFI/ZBM/zfsbootmenu.EFI" ]]; then
    echo "AVISO: ZFSBootMenu EFI nao encontrado"
    errors=$((errors + 1))
  fi

  if zpool list "$POOL_NAME" &>/dev/null; then
    local bootfs
    bootfs=$(zpool get -H -o value bootfs "$POOL_NAME" 2>/dev/null || echo "-")
    if [[ "$bootfs" == "-" ]]; then
      echo "AVISO: bootfs nao configurado no pool"
      errors=$((errors + 1))
    fi
  fi

  return "$errors"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "=== Teste de Instalacao ZFSBootMenu ==="
  echo
  echo "Funcoes disponiveis:"
  echo "  zbm_install <esp_partition> [target] [pool]"
  echo "  zbm_configure_efi <disk> <part_num>"
  echo "  zbm_configure_bios <disk> <esp_part> [target]"
  echo "  zbm_configure_zfs_properties [pool] [hostid]"
  echo "  zbm_generate_hostid [target]"
  echo "  zbm_setup_fallback <esp_partition> [target]"
  echo "  zbm_verify [target]"
fi
