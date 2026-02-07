#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: install-utils.sh
# Purpose: debootstrap, APT config, bind mounts for chroot, package installation (kernel+zfs), fstab helpers
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

INSTALLUTILS_TARGET_ROOT_DEFAULT="/mnt"
INSTALLUTILS_APT_PROXY_FILE_DEFAULT="/etc/apt/apt.conf.d/99proxy"
INSTALLUTILS_APT_RETRIES_FILE_DEFAULT="/etc/apt/apt.conf.d/80retries"
INSTALLUTILS_SOURCES_LIST_DEFAULT="/etc/apt/sources.list"
INSTALLUTILS_FSTAB_DEFAULT="/etc/fstab"

stderr() { printf '%s\n' "$*" >&2; }
stdout() { printf '%s' "$*"; }

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

sanitize_uint() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    if ! printf '%s' "$in" | grep -Eq '^[0-9]+$'; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in"
}

sanitize_proxy() {
    local in; in="$(sanitize_ws "${1-}")"
    if [[ -z "$in" ]]; then
        printf '%s' ""
        return
    fi
    if ! printf '%s' "$in" | grep -Eq '^(https?://)?[^[:space:]]+$'; then
        printf '%s' ""
        return
    fi
    printf '%s' "$in"
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

installutils_loaded() { :; }

installutils_chroot_run() {
    # Single responsibility: run a command in chroot with sanitized env
    # Args: target_root cmd
    local root; root="$(sanitize_path "${1-}")"
    local cmd; cmd="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
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

    if ! chroot "$root" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin /bin/bash -lc "$cmd" >/dev/null 2>&1; then
        stderr "Erro: chroot falhou: $cmd"
        return 1
    fi
}

installutils_bind_mounts() {
    # Single responsibility: bind mount /dev,/proc,/sys,/run into target
    # Args: target_root extra_mounts_csv(optional) (unused placeholder for extensibility)
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi

    require_cmd mkdir || return 1
    require_cmd mount || return 1

    mkdir -p "$root/dev" "$root/proc" "$root/sys" "$root/run"

    if command -v mountpoint >/dev/null 2>&1; then
        mountpoint -q "$root/dev" 2>/dev/null || mount --bind /dev "$root/dev" >/dev/null 2>&1 || return 1
        mountpoint -q "$root/proc" 2>/dev/null || mount -t proc proc "$root/proc" >/dev/null 2>&1 || return 1
        mountpoint -q "$root/sys" 2>/dev/null || mount -t sysfs sys "$root/sys" >/dev/null 2>&1 || return 1
        mountpoint -q "$root/run" 2>/dev/null || mount --bind /run "$root/run" >/dev/null 2>&1 || return 1
        return 0
    fi

    mount --bind /dev "$root/dev" >/dev/null 2>&1 || return 1
    mount -t proc proc "$root/proc" >/dev/null 2>&1 || return 1
    mount -t sysfs sys "$root/sys" >/dev/null 2>&1 || return 1
    mount --bind /run "$root/run" >/dev/null 2>&1 || return 1
}

installutils_bind_umounts() {
    # Single responsibility: unmount bind mounts in reverse order (best-effort)
    # Args: target_root extra_mounts_csv(optional) (unused placeholder for extensibility)
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    require_cmd umount || return 1

    if command -v mountpoint >/dev/null 2>&1; then
        mountpoint -q "$root/run" 2>/dev/null && umount "$root/run" >/dev/null 2>&1 || true
        mountpoint -q "$root/sys" 2>/dev/null && umount "$root/sys" >/dev/null 2>&1 || true
        mountpoint -q "$root/proc" 2>/dev/null && umount "$root/proc" >/dev/null 2>&1 || true
        mountpoint -q "$root/dev" 2>/dev/null && umount "$root/dev" >/dev/null 2>&1 || true
        return 0
    fi

    umount "$root/run" >/dev/null 2>&1 || true
    umount "$root/sys" >/dev/null 2>&1 || true
    umount "$root/proc" >/dev/null 2>&1 || true
    umount "$root/dev" >/dev/null 2>&1 || true
}

installutils_write_apt_proxy_conf() {
    # Single responsibility: write apt proxy config into target (optional)
    # Args: target_root proxy_url
    local root; root="$(sanitize_path "${1-}")"
    local proxy; proxy="$(sanitize_proxy "${2-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/apt/apt.conf.d"

    local file
    file="$(sanitize_path "$root$INSTALLUTILS_APT_PROXY_FILE_DEFAULT")"

    if [[ -z "$proxy" ]]; then
        rm -f "$file" >/dev/null 2>&1 || true
        return 0
    fi

    {
        printf 'Acquire::http::Proxy "%s";\n' "$proxy"
        printf 'Acquire::https::Proxy "%s";\n' "$proxy"
    } >"$file"
}

installutils_apt_configure_retries() {
    # Single responsibility: set apt retries/timeouts in target
    # Args: target_root retries timeout_seconds
    local root; root="$(sanitize_path "${1-}")"
    local retries; retries="$(sanitize_uint "${2-5}")"
    local timeout; timeout="$(sanitize_uint "${3-30}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$retries" ]]; then
        retries="5"
    fi
    if [[ -z "$timeout" ]]; then
        timeout="30"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/apt/apt.conf.d"

    local file
    file="$(sanitize_path "$root$INSTALLUTILS_APT_RETRIES_FILE_DEFAULT")"
    {
        printf 'Acquire::Retries "%s";\n' "$retries"
        printf 'Acquire::http::Timeout "%s";\n' "$timeout"
        printf 'Acquire::https::Timeout "%s";\n' "$timeout"
    } >"$file"
}

installutils_write_sources_list() {
    # Single responsibility: write sources.list into target
    # Args: target_root suite mirror components
    local root; root="$(sanitize_path "${1-}")"
    local suite; suite="$(sanitize_ws "${2-stable}")"
    local mirror; mirror="$(sanitize_ws "${3-http://deb.debian.org/debian}")"
    local comps; comps="$(sanitize_ws "${4-main}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$suite" ]]; then
        suite="stable"
    fi
    if [[ -z "$mirror" ]]; then
        mirror="http://deb.debian.org/debian"
    fi
    if [[ -z "$comps" ]]; then
        comps="main"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/apt"

    local file
    file="$(sanitize_path "$root$INSTALLUTILS_SOURCES_LIST_DEFAULT")"
    {
        printf 'deb %s %s %s\n' "$mirror" "$suite" "$comps"
        printf 'deb %s %s-updates %s\n' "$mirror" "$suite" "$comps"
        printf 'deb http://security.debian.org/debian-security %s-security %s\n' "$suite" "$comps"
    } >"$file"
}

installutils_debootstrap_base() {
    # Single responsibility: run debootstrap into target root
    # Args: target_root suite mirror include_csv(optional)
    local root; root="$(sanitize_path "${1-}")"
    local suite; suite="$(sanitize_ws "${2-stable}")"
    local mirror; mirror="$(sanitize_ws "${3-http://deb.debian.org/debian}")"
    local include; include="$(sanitize_ws "${4-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$suite" ]]; then
        suite="stable"
    fi
    if [[ -z "$mirror" ]]; then
        mirror="http://deb.debian.org/debian"
    fi

    require_cmd mkdir || return 1
    require_cmd debootstrap || return 1

    mkdir -p "$root"

    local args=()
    if [[ -n "$include" ]]; then
        args+=("--include=$include")
    fi

    if ! debootstrap "${args[@]}" "$suite" "$root" "$mirror" >/dev/null 2>&1; then
        stderr "Erro: debootstrap falhou."
        return 1
    fi
}

installutils_apt_install_packages() {
    # Single responsibility: install packages in target root
    # Args: target_root "pkg1 pkg2 ..."
    local root; root="$(sanitize_path "${1-}")"
    local pkgs; pkgs="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$pkgs" ]]; then
        return 0
    fi

    installutils_chroot_run "$root" "apt-get update" || return 1
    installutils_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ${pkgs}" || return 1
}

installutils_install_kernel_and_zfs() {
    # Single responsibility: install kernel + zfs packages inside target
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi

    installutils_chroot_run "$root" "apt-get update" || return 1

    # Base essentials
    installutils_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install linux-image-amd64 initramfs-tools systemd-sysv" || return 1

    # ZFS on Linux in Debian: packages commonly zfsutils-linux, zfs-dkms
    # Best-effort: try to install both; allow DKMS failures to be surfaced to caller.
    if ! installutils_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install zfsutils-linux zfs-initramfs"; then
        # Try alternative common set
        installutils_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install zfsutils-linux zfs-dkms" || return 1
    fi

    # Ensure locales configured enough for apt
    installutils_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install locales" || true
}

installutils_write_fstab_stub_for_efi() {
    # Single responsibility: write ESP entry into /etc/fstab (idempotent by device path)
    # Args: target_root esp_part mountpoint_inside_target
    local root; root="$(sanitize_path "${1-}")"
    local esp; esp="$(sanitize_path "${2-}")"
    local mp; mp="$(sanitize_path "${3-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$esp" ]]; then
        stderr "Erro: esp_part vazio."
        return 1
    fi
    if [[ -z "$mp" ]]; then
        mp="/boot/efi"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc"

    local fstab
    fstab="$(sanitize_path "$root$INSTALLUTILS_FSTAB_DEFAULT")"
    if [[ ! -f "$fstab" ]]; then
        : >"$fstab"
    fi

    if grep -Fq "$esp" "$fstab" 2>/dev/null; then
        return 0
    fi

    printf '%s\t%s\tvfat\tumask=0077\t0\t1\n' "$esp" "$mp" >>"$fstab"
}
