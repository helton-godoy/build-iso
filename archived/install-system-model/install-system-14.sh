#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: setup-zbm-config.sh
# Purpose: generate ZFSBootMenu YAML config and build initramfs artifacts inside target
# Notes:
# - Designed to be lazy-loaded by installer-router.sh (as a dep)
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2
#
# This script assumes ZFSBootMenu packages/tools are available in the target root.
# It is best-effort and will fail loudly if mandatory commands are missing.

ZBM_TARGET_ROOT_DEFAULT="/mnt"
ZBM_CONFIG_PATH_DEFAULT="/etc/zfsbootmenu/config.yaml"
ZBM_EFI_DIR_DEFAULT="/boot/efi"
ZBM_BOOT_ID_DEFAULT="ZFSBootMenu"
ZBM_DRACUT_MODULES_DEFAULT="zfs systemd"
ZBM_KERNEL_CMDLINE_DEFAULT="quiet"
ZBM_GENERATOR_DEFAULT="dracut"

stderr() { printf '%s\n' "$*" >&2; }
stdout() { printf '%s\n' "$*"; }

sanitize_ws() {
    local in; in="${1-}"
    in="${in//$'\r'/}"
    in="${in//$'\n'/}"
    printf '%s' "$in" | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//'
}

sanitize_path() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in" | sed -E 's/[[:cntrl:]]+//g'
}

sanitize_id() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.:-]+/_/g; s/^_+//; s/_+$//'
}

require_cmd() {
    local cmd; cmd="$(sanitize_ws "${1-}")"
    if [[ -z "$cmd" ]]; then
        stderr "Erro: comando vazio."
        return 1
    fi
    if ! command -v "$cmd" >/dev/null 2>&1; then
        stderr "Erro: dependência ausente: $cmd"
        return 1
    fi
}

zbm_loaded() { :; }

zbm_chroot_run() {
    # Single responsibility: run command in chroot with sanitized environment
    # Args: target_root cmd
    local root; root="$(sanitize_path "${1-}")"
    local cmd; cmd="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$ZBM_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$cmd" ]]; then
        stderr "Erro: comando chroot vazio."
        return 1
    fi

    require_cmd chroot || return 1
    if [[ "$cmd" == *$'\n'* || "$cmd" == *$'\0'* ]]; then
        stderr "Erro: comando chroot contém caracteres inválidos."
        return 1
    fi

    if ! chroot "$root" /usr/bin/env -i "PATH=/usr/sbin:/usr/bin:/sbin:/bin" /bin/bash -lc "$cmd" >/dev/null 2>&1; then
        stderr "Erro: comando chroot falhou: $cmd"
        return 1
    fi
}

zbm_ensure_config_dir() {
    # Single responsibility: ensure config directory exists in target
    # Args: target_root config_path
    local root; root="$(sanitize_path "${1-}")"
    local path; path="$(sanitize_path "${2-}")"
    if [[ -z "$root" ]]; then
        root="$ZBM_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$path" ]]; then
        path="$ZBM_CONFIG_PATH_DEFAULT"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$(dirname -- "$root/$path")"
}

zbm_render_config_yaml() {
    # Single responsibility: render config.yaml content
    # Args: pool root_dataset efi_dir kernel_cmdline generator
    local pool; pool="$(sanitize_ws "${1-}")"
    local root_ds; root_ds="$(sanitize_ws "${2-}")"
    local efi_dir; efi_dir="$(sanitize_path "${3-}")"
    local cmdline; cmdline="$(sanitize_ws "${4-}")"
    local generator; generator="$(sanitize_id "${5-}")"

    if [[ -z "$efi_dir" ]]; then
        efi_dir="$ZBM_EFI_DIR_DEFAULT"
    fi
    if [[ -z "$cmdline" ]]; then
        cmdline="$ZBM_KERNEL_CMDLINE_DEFAULT"
    fi
    if [[ -z "$generator" ]]; then
        generator="$ZBM_GENERATOR_DEFAULT"
    fi

    # Basic YAML (minimal, extend in projeto.md)
    # Note: keep indentation stable.
    cat <<EOF
Global:
  ManageImages: true
  BootMountPoint: /boot
  DracutConfDir: /etc/zfsbootmenu/dracut.conf.d
  InitCPIO: false

EFI:
  ImageDir: ${efi_dir}/EFI/${ZBM_BOOT_ID_DEFAULT}
  Versions: false
  Enabled: true

Kernel:
  CommandLine: "${cmdline}"

ZFS:
  Pool: "${pool}"
  RootDataset: "${root_ds}"

Components:
  Generator: "${generator}"
EOF
}

zbm_write_config_yaml() {
    # Single responsibility: write ZFSBootMenu config.yaml into target
    # Args: target_root pool root_dataset efi_dir cmdline config_path generator
    local root; root="$(sanitize_path "${1-}")"
    local pool; pool="$(sanitize_ws "${2-}")"
    local root_ds; root_ds="$(sanitize_ws "${3-}")"
    local efi_dir; efi_dir="$(sanitize_path "${4-}")"
    local cmdline; cmdline="$(sanitize_ws "${5-}")"
    local cfg; cfg="$(sanitize_path "${6-}")"
    local generator; generator="$(sanitize_id "${7-}")"

    if [[ -z "$root" ]]; then
        root="$ZBM_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$cfg" ]]; then
        cfg="$ZBM_CONFIG_PATH_DEFAULT"
    fi
    if [[ -z "$efi_dir" ]]; then
        efi_dir="$ZBM_EFI_DIR_DEFAULT"
    fi
    if [[ -z "$generator" ]]; then
        generator="$ZBM_GENERATOR_DEFAULT"
    fi
    if [[ -z "$pool" || -z "$root_ds" ]]; then
        stderr "Erro: pool/root_dataset obrigatórios para ZBM."
        return 1
    fi

    zbm_ensure_config_dir "$root" "$cfg" || return 1

    local content
    content="$(zbm_render_config_yaml "$pool" "$root_ds" "$efi_dir" "$cmdline" "$generator")"
    if [[ -z "$(sanitize_ws "$content")" ]]; then
        stderr "Erro: conteúdo YAML vazio."
        return 1
    fi

    printf '%s\n' "$content" >"$root/$cfg"
}

zbm_install_packages_if_missing() {
    # Single responsibility: install ZFSBootMenu tooling in target (best-effort)
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$ZBM_TARGET_ROOT_DEFAULT"
    fi

    # Attempt to ensure dracut + zfsbootmenu (package names may vary; customize in projeto.md)
    zbm_chroot_run "$root" "apt-get update" || return 1

    # Try common names; do not fail hard on first miss, but fail if all attempts fail.
    local ok=0

    if zbm_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install dracut"; then
        ok=1
    fi

    # ZFSBootMenu package name may differ; try a few.
    if zbm_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install zfsbootmenu"; then
        ok=1
    elif zbm_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install zfsbootmenu-core"; then
        ok=1
    fi

    if [[ "$ok" != "1" ]]; then
        stderr "Erro: não foi possível instalar ferramentas ZFSBootMenu/dracut no target."
        return 1
    fi
}

zbm_generate_images() {
    # Single responsibility: generate ZFSBootMenu EFI images (build + install)
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$ZBM_TARGET_ROOT_DEFAULT"
    fi

    # Try generator command(s)
    if zbm_chroot_run "$root" "zbmctl generate"; then
        return 0
    fi
    if zbm_chroot_run "$root" "zfsbootmenu-generator"; then
        return 0
    fi
    if zbm_chroot_run "$root" "generate-zbm"; then
        return 0
    fi

    stderr "Erro: não foi possível gerar imagens ZFSBootMenu (zbmctl/generator ausentes)."
    return 1
}

zbm_install_efi_entries_optional() {
    # Single responsibility: create EFI entry via efibootmgr (requires UEFI runtime)
    # Args: target_root disk esp_part label loader_path
    local root; root="$(sanitize_path "${1-}")"
    local disk; disk="$(sanitize_path "${2-}")"
    local esp; esp="$(sanitize_path "${3-}")"
    local label; label="$(sanitize_ws "${4-}")"
    local loader; loader="$(sanitize_ws "${5-}")"

    if [[ -z "$root" ]]; then
        root="$ZBM_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$label" ]]; then
        label="$ZBM_BOOT_ID_DEFAULT"
    fi
    if [[ -z "$loader" ]]; then
        loader="\\EFI\\${ZBM_BOOT_ID_DEFAULT}\\vmlinuz.efi"
    fi

    if [[ ! -d /sys/firmware/efi ]]; then
        return 0
    fi

    if [[ -z "$disk" || -z "$esp" ]]; then
        stderr "Erro: disk/esp obrigatórios para efibootmgr."
        return 1
    fi

    require_cmd efibootmgr || return 1

    # Determine partition number from esp path
    local partnum
    partnum="$(printf '%s' "$esp" | sed -nE 's|^/dev/[^0-9]+([0-9]+)$|\1|p')"
    partnum="$(sanitize_ws "$partnum")"
    if [[ -z "$partnum" ]]; then
        # nvme/mmc pN
        partnum="$(printf '%s' "$esp" | sed -nE 's|^/dev/.*p([0-9]+)$|\1|p')"
    fi
    partnum="$(sanitize_ws "$partnum")"
    if [[ -z "$partnum" ]]; then
        stderr "Erro: não foi possível inferir número da partição ESP: $esp"
        return 1
    fi

    # Create entry (best-effort; duplicates are possible and should be handled by caller later)
    if ! efibootmgr -c -d "$disk" -p "$partnum" -L "$label" -l "$loader" >/dev/null 2>&1; then
        stderr "Erro: efibootmgr falhou ao criar entry."
        return 1
    fi
}

zbm_setup_all() {
    # Single responsibility: orchestrate ZFSBootMenu config + build
    # Args: target_root pool root_dataset efi_dir kernel_cmdline install_pkgs(1|0)
    local root; root="$(sanitize_path "${1-}")"
    local pool; pool="$(sanitize_ws "${2-}")"
    local root_ds; root_ds="$(sanitize_ws "${3-}")"
    local efi_dir; efi_dir="$(sanitize_path "${4-}")"
    local cmdline; cmdline="$(sanitize_ws "${5-}")"
    local install_pkgs; install_pkgs="$(sanitize_ws "${6-1}")"

    if [[ -z "$root" ]]; then
        root="$ZBM_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$efi_dir" ]]; then
        efi_dir="$ZBM_EFI_DIR_DEFAULT"
    fi
    if [[ "$install_pkgs" != "1" && "$install_pkgs" != "0" ]]; then
        install_pkgs="1"
    fi
    if [[ -z "$pool" || -z "$root_ds" ]]; then
        stderr "Erro: pool/root_dataset obrigatórios."
        return 1
    fi

    zbm_write_config_yaml "$root" "$pool" "$root_ds" "$efi_dir" "$cmdline" "$ZBM_CONFIG_PATH_DEFAULT" "$ZBM_GENERATOR_DEFAULT" || return 1
    if [[ "$install_pkgs" == "1" ]]; then
        zbm_install_packages_if_missing "$root" || return 1
    fi
    zbm_generate_images "$root" || return 1
}
