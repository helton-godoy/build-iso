#!/usr/bin/env bash
# @INST_LIB_NAME: install-utils
# @INST_DESC: Utilitários de implantação base (debootstrap, apt, mounts).

set -euo pipefail

# @ID: INSTALLUTILS_OFFLINE_CANDIDATES
# @STEP: Resolve candidatos locais de squashfs para instalação offline.
# @DATA: IN install_offline_squashfs
installutils_offline_squashfs_candidates() {
  local custom
  custom="$(sanitize_path "$(state_kv_get install_offline_squashfs)")"

  if [[ -n "$custom" ]]; then
    printf '%s\n' "$custom"
  fi

  printf '%s\n' \
    "/run/live/medium/live/filesystem.squashfs" \
    "/cdrom/live/filesystem.squashfs" \
    "/live/filesystem.squashfs"
}

# @ID: INSTALLUTILS_REQUIRE_OFFLINE_SQUASHFS
# @STEP: Valida pré-condição offline e retorna artefato squashfs local.
# @REQ: INSTALLUTILS_OFFLINE_CANDIDATES
# @FAIL: INSTALLUTILS_OFFLINE_MISSING
# @DATA: OUT install_offline_squashfs_resolved
installutils_require_offline_squashfs() {
  local candidate
  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    if [[ -f "$candidate" ]]; then
      state_kv_set "install_offline_squashfs_resolved" "$candidate" || true
      log_line "INFO" "offline_source: usando squashfs local em $candidate"
      printf '%s' "$candidate"
      return 0
    fi
  done < <(installutils_offline_squashfs_candidates)

  # @ID: INSTALLUTILS_OFFLINE_MISSING
  # @STEP: Falha quando modo offline não encontra filesystem.squashfs local.
  # @REQ: INSTALLUTILS_REQUIRE_OFFLINE_SQUASHFS
  # @DATA: OUT STDERR
  stderr "Modo offline ativo, mas nenhum filesystem.squashfs local foi encontrado."
  return 1
}

# @ID: INSTALLUTILS_OFFLINE_EXTRACT
# @STEP: Extrai rootfs local do squashfs para target sem uso de rede.
# @REQ: INSTALLUTILS_REQUIRE_OFFLINE_SQUASHFS
# @FAIL: INSTALLUTILS_OFFLINE_EXTRACT_FAILED
# @DATA: IN target, squashfs_path
installutils_extract_offline_rootfs() {
  local target="$1"
  local squashfs_path="$2"

  if ! command -v unsquashfs >/dev/null 2>&1; then
    # @ID: INSTALLUTILS_OFFLINE_EXTRACT_FAILED
    # @STEP: Falha de extração offline quando dependência unsquashfs está ausente.
    # @REQ: INSTALLUTILS_OFFLINE_EXTRACT
    # @DATA: OUT STDERR
    stderr "Erro: unsquashfs não encontrado para modo offline."
    return 1
  fi

  mkdir -p "$target"
  unsquashfs -f -d "$target" "$squashfs_path" >/dev/null
}

installutils_write_sources_list() {
  local target="$1"
  local suite="$2"
  local mirror="$3"
  local components="$4"

  mkdir -p "$target/etc/apt"
  cat >"$target/etc/apt/sources.list" <<EOF
deb $mirror $suite $components
deb $mirror $suite-updates $components
deb http://security.debian.org/debian-security $suite-security $components
EOF
}

installutils_apt_configure_retries() {
  local target="$1"
  local retries="$2"
  local timeout="$3"

  mkdir -p "$target/etc/apt/apt.conf.d"
  cat >"$target/etc/apt/apt.conf.d/99retries" <<EOF
Acquire::Retries "$retries";
Acquire::http::Timeout "$timeout";
EOF
}

installutils_write_apt_proxy_conf() {
  local target="$1"
  local proxy="$2"

  if [[ -n "$proxy" ]]; then
    echo "Acquire::http::Proxy \"$proxy\";" >"$target/etc/apt/apt.conf.d/01proxy"
  fi
}

installutils_debootstrap_base() {
  local target="$1"
  local suite="$2"
  local mirror="$3"
  local include="$4"

  # Verifica se debootstrap está instalado
  if ! command -v debootstrap >/dev/null; then
    stderr "Erro: debootstrap não encontrado."
    return 1
  fi

  debootstrap --arch=amd64 --include="$include" "$suite" "$target" "$mirror"
}

installutils_bind_mounts() {
  local target="$1"

  mount --bind /dev "$target/dev"
  mount --bind /proc "$target/proc"
  mount --bind /sys "$target/sys"
  mount --bind /run "$target/run" 2>/dev/null || true
}

installutils_install_kernel_and_zfs() {
  local target="$1"
  local source_mode="${2-online}"

  if [[ "$source_mode" == "offline" ]]; then
    log_line "INFO" "offline_source: pulando apt install de kernel/zfs (esperado via imagem local)"
    return 0
  fi

  # Atualiza repositórios
  chroot "$target" apt-get update

  # Instala headers do kernel, zfs e initramfs
  # ZFS on Linux requer contrib non-free (já configurado em sources.list)

  # Instala linux-image-amd64 e linux-headers-amd64
  chroot "$target" apt-get install -y linux-image-amd64 linux-headers-amd64 zfs-dkms zfsutils-linux

  # ZFSBootMenu requer que geremos initramfs compatível
  # Mas aqui instalamos apenas o básico. A configuração do ZBM vem depois ou via zbm-install
}

installutils_write_fstab_stub_for_efi() {
  local target="$1"
  local efi_dev="$2"
  local mount_point="$3"
  local uuid

  if [[ ! -b "$efi_dev" ]]; then
    uuid="UNKNOWN"
  else
    uuid=$(blkid -s UUID -o value "$efi_dev" 2>/dev/null || echo "UNKNOWN")
  fi

  mkdir -p "$target/etc"
  if [[ ! -f "$target/etc/fstab" ]]; then
    echo "# /etc/fstab: static file system information" >"$target/etc/fstab"
  fi

  # Adiciona apenas se não existir
  if ! grep -q "$mount_point" "$target/etc/fstab"; then
    echo "UUID=$uuid $mount_point vfat defaults 0 2" >>"$target/etc/fstab"
  fi
}
