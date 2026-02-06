#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: install-utils.sh
# Purpose: base system install helpers (debootstrap/apt), mount binding, chroot exec, progress framing
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

INSTALLUTILS_TARGET_ROOT_DEFAULT="/mnt"
INSTALLUTILS_DEBIAN_SUITE_DEFAULT="stable"
INSTALLUTILS_DEBIAN_MIRROR_DEFAULT="http://deb.debian.org/debian"
INSTALLUTILS_APT_RETRIES_DEFAULT="5"
INSTALLUTILS_APT_TIMEOUT_DEFAULT="30"
INSTALLUTILS_BIND_MOUNTS_DEFAULT="/dev /proc /sys /run"

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

installutils_detect_proxy_env() {
    local p
    p="$(sanitize_ws "${install_proxy-}")"
    if [[ -z "$p" ]]; then
        printf '%s' ""
        return
    fi
    printf '%s' "$p"
}

installutils_write_apt_proxy_conf() {
    # Single responsibility: write apt proxy configuration in target
    # Args: target_root proxy_url
    local root; root="$(sanitize_path "${1-}")"
    local proxy; proxy="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$proxy" ]]; then
        return 0
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/apt/apt.conf.d"

    local file
    file="$(sanitize_path "$root/etc/apt/apt.conf.d/00proxy")"
    printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' "$proxy" "$proxy" >"$file"
}

installutils_write_sources_list() {
    # Single responsibility: write sources.list (simple stable baseline)
    # Args: target_root suite mirror components
    local root; root="$(sanitize_path "${1-}")"
    local suite; suite="$(sanitize_ws "${2-}")"
    local mirror; mirror="$(sanitize_ws "${3-}")"
    local comps; comps="$(sanitize_ws "${4-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$suite" ]]; then
        suite="$INSTALLUTILS_DEBIAN_SUITE_DEFAULT"
    fi
    if [[ -z "$mirror" ]]; then
        mirror="$INSTALLUTILS_DEBIAN_MIRROR_DEFAULT"
    fi
    if [[ -z "$comps" ]]; then
        comps="main contrib non-free-firmware"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/apt"

    local file
    file="$(sanitize_path "$root/etc/apt/sources.list")"

    {
        printf 'deb %s %s %s\n' "$mirror" "$suite" "$comps"
        printf 'deb %s %s-updates %s\n' "$mirror" "$suite" "$comps"
        printf 'deb http://security.debian.org/debian-security %s-security %s\n' "$suite" "$comps"
    } >"$file"
}

installutils_debootstrap_base() {
    # Single responsibility: run debootstrap into target root
    # Args: target_root suite mirror include_csv
    local root; root="$(sanitize_path "${1-}")"
    local suite; suite="$(sanitize_ws "${2-}")"
    local mirror; mirror="$(sanitize_ws "${3-}")"
    local include; include="$(sanitize_ws "${4-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$suite" ]]; then
        suite="$INSTALLUTILS_DEBIAN_SUITE_DEFAULT"
    fi
    if [[ -z "$mirror" ]]; then
        mirror="$INSTALLUTILS_DEBIAN_MIRROR_DEFAULT"
    fi

    require_cmd debootstrap || return 1
    require_cmd mkdir || return 1
    mkdir -p "$root"

    local args=()
    if [[ -n "$include" ]]; then
        args+=(--include="$include")
    fi

    if ! debootstrap "${args[@]}" "$suite" "$root" "$mirror" >/dev/null 2>&1; then
        stderr "Erro: debootstrap falhou (suite=$suite mirror=$mirror root=$root)."
        return 1
    fi
}

installutils_bind_mounts() {
    # Single responsibility: bind mount essential fs into target root
    # Args: target_root mounts_space_separated
    local root; root="$(sanitize_path "${1-}")"
    local mounts; mounts="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$mounts" ]]; then
        mounts="$INSTALLUTILS_BIND_MOUNTS_DEFAULT"
    fi

    require_cmd mount || return 1
    require_cmd mkdir || return 1

    local m
    for m in $mounts; do
        m="$(sanitize_path "$m")"
        if [[ -z "$m" || ! -d "$m" ]]; then
            continue
        fi
        mkdir -p "$root$m"
        if mountpoint -q "$root$m" 2>/dev/null; then
            continue
        fi
        if ! mount --bind "$m" "$root$m" >/dev/null 2>&1; then
            stderr "Erro: bind mount falhou: $m -> $root$m"
            return 1
        fi
    done
}

installutils_bind_umounts() {
    # Single responsibility: umount bind mounts in reverse order
    # Args: target_root mounts_space_separated
    local root; root="$(sanitize_path "${1-}")"
    local mounts; mounts="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$mounts" ]]; then
        mounts="$INSTALLUTILS_BIND_MOUNTS_DEFAULT"
    fi

    require_cmd umount || return 1

    # Reverse order
    local list
    list="$(printf '%s' "$mounts" | tr ' ' '\n' | awk '{print length($0) "\t" $0}' | sort -rn | cut -f2-)"
    list="$(sanitize_ws "$list")"
    if [[ -z "$list" ]]; then
        return 0
    fi

    if ! printf '%s\n' "$list" | while IFS= read -r m; do
        m="$(sanitize_path "$m")"
        if [[ -z "$m" ]]; then
            continue
        fi
        if mountpoint -q "$root$m" 2>/dev/null; then
            umount "$root$m" >/dev/null 2>&1 || return 1
        fi
    done; then
        return 1
    fi
}

installutils_chroot_run() {
    # Single responsibility: run a command in chroot, with safe env (proxy aware)
    # Args: target_root command_string
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

    local proxy
    proxy="$(sanitize_ws "$(installutils_detect_proxy_env)")"

    # Avoid injection by restricting to a conservative command set here:
    # we run through /bin/bash -lc but require cmd to not contain newlines or NUL (already sanitized)
    if [[ "$cmd" == *";;"* || "$cmd" == *$'\0'* ]]; then
        stderr "Erro: comando chroot contém padrões inválidos."
        return 1
    fi

    if [[ -n "$proxy" ]]; then
        if ! chroot "$root" /usr/bin/env -i \
            "PATH=/usr/sbin:/usr/bin:/sbin:/bin" \
            "http_proxy=$proxy" "https_proxy=$proxy" \
            /bin/bash -lc "$cmd" >/dev/null 2>&1; then
            stderr "Erro: comando chroot falhou: $cmd"
            return 1
        fi
        return 0
    fi

    if ! chroot "$root" /usr/bin/env -i \
        "PATH=/usr/sbin:/usr/bin:/sbin:/bin" \
        /bin/bash -lc "$cmd" >/dev/null 2>&1; then
        stderr "Erro: comando chroot falhou: $cmd"
        return 1
    fi
}

installutils_apt_configure_retries() {
    # Single responsibility: configure apt retries and timeouts in target
    # Args: target_root retries timeout
    local root; root="$(sanitize_path "${1-}")"
    local retries; retries="$(sanitize_uint "${2-}")"
    local timeout; timeout="$(sanitize_uint "${3-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$retries" ]]; then
        retries="$INSTALLUTILS_APT_RETRIES_DEFAULT"
    fi
    if [[ -z "$timeout" ]]; then
        timeout="$INSTALLUTILS_APT_TIMEOUT_DEFAULT"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/apt/apt.conf.d"

    local file
    file="$(sanitize_path "$root/etc/apt/apt.conf.d/80retries")"
    {
        printf 'Acquire::Retries "%s";\n' "$retries"
        printf 'Acquire::http::Timeout "%s";\n' "$timeout"
        printf 'Acquire::https::Timeout "%s";\n' "$timeout"
    } >"$file"
}

installutils_apt_update() {
    # Single responsibility: apt-get update in chroot
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    installutils_chroot_run "$root" "apt-get update" || return 1
}

installutils_apt_install_packages() {
    # Single responsibility: apt-get install a list of packages in chroot
    # Args: target_root packages_space_separated
    local root; root="$(sanitize_path "${1-}")"
    local pkgs; pkgs="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$pkgs" ]]; then
        stderr "Erro: lista de pacotes vazia."
        return 1
    fi

    # Reject suspicious characters
    if printf '%s' "$pkgs" | grep -Eq '[^a-zA-Z0-9+_.:-[:space:]]'; then
        stderr "Erro: lista de pacotes contém caracteres inválidos."
        return 1
    fi

    installutils_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ${pkgs}" || return 1
}

installutils_install_kernel_and_zfs() {
    # Single responsibility: install kernel + ZFS tooling in chroot (package names may vary)
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi

    installutils_apt_update "$root" || return 1

    # Conservative baseline: zfsutils-linux + zfs-dkms (or zfs-initramfs on Debian)
    # You can refine per projeto.md later.
    local pkgs
    pkgs="linux-image-amd64 linux-headers-amd64 zfsutils-linux zfs-initramfs"
    installutils_apt_install_packages "$root" "$pkgs" || return 1
}

installutils_write_fstab_stub_for_efi() {
    # Single responsibility: ensure ESP mount in fstab (optional if systemd mount via GPT auto)
    # Args: target_root esp_part esp_mount
    local root; root="$(sanitize_path "${1-}")"
    local esp_part; esp_part="$(sanitize_path "${2-}")"
    local esp_mount; esp_mount="$(sanitize_path "${3-}")"

    if [[ -z "$root" ]]; then
        root="$INSTALLUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$esp_part" || ! -b "$esp_part" ]]; then
        stderr "Erro: esp_part inválida: $esp_part"
        return 1
    fi
    if [[ -z "$esp_mount" ]]; then
        esp_mount="/boot/efi"
    fi
    require_cmd blkid || return 1
    require_cmd mkdir || return 1

    mkdir -p "$root/etc"
    local fstab
    fstab="$(sanitize_path "$root/etc/fstab")"
    if [[ ! -f "$fstab" ]]; then
        : >"$fstab"
    fi

    local uuid
    if ! uuid="$(blkid -s UUID -o value "$esp_part" 2>/dev/null || true)"; then
        uuid=""
    fi
    uuid="$(sanitize_ws "$uuid")"
    if [[ -z "$uuid" ]]; then
        stderr "Erro: UUID vazio para ESP: $esp_part"
        return 1
    fi

    if grep -Eq "[[:space:]]${esp_mount}[[:space:]]" "$fstab" 2>/dev/null; then
        return 0
    fi

    printf 'UUID=%s %s vfat umask=0077 0 1\n' "$uuid" "$esp_mount" >>"$fstab"
}
