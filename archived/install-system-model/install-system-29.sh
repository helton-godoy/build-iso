#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: post-utils.sh
# Purpose: configure target system identity/locale/keymap/timezone/users/root policy/resolv.conf/ZFS cache/initramfs/machine-id
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

POSTUTILS_TARGET_ROOT_DEFAULT="/mnt"

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

postutils_loaded() { :; }

postutils_chroot_run() {
    # Single responsibility: run a command in chroot with sanitized env
    # Args: target_root cmd
    local root; root="$(sanitize_path "${1-}")"
    local cmd; cmd="$(sanitize_ws "${2-}")"
    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
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

postutils_set_hostname() {
    # Single responsibility: set /etc/hostname and /etc/hosts in target
    # Args: target_root hostname domain(optional)
    local root; root="$(sanitize_path "${1-}")"
    local hn; hn="$(sanitize_ws "${2-}")"
    local dom; dom="$(sanitize_ws "${3-}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$hn" ]]; then
        stderr "Erro: hostname vazio."
        return 1
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc"

    local fqdn="$hn"
    if [[ -n "$dom" ]]; then
        fqdn="${hn}.${dom}"
    fi

    printf '%s\n' "$hn" >"$root/etc/hostname"

    local hosts
    hosts="$(sanitize_path "$root/etc/hosts")"
    if [[ ! -f "$hosts" ]]; then
        : >"$hosts"
    fi

    if ! grep -Eq '^[[:space:]]*127\.0\.0\.1[[:space:]]+localhost' "$hosts" 2>/dev/null; then
        printf '127.0.0.1\tlocalhost\n' >>"$hosts"
    fi
    if ! grep -Eq '^[[:space:]]*::1[[:space:]]+localhost' "$hosts" 2>/dev/null; then
        printf '::1\tlocalhost ip6-localhost ip6-loopback\n' >>"$hosts"
    fi

    if grep -Eq '^[[:space:]]*127\.0\.1\.1[[:space:]]+' "$hosts" 2>/dev/null; then
        require_cmd sed || return 1
        sed -i -E "s|^[[:space:]]*127\.0\.1\.1[[:space:]]+.*$|127.0.1.1\t${fqdn} ${hn}|g" "$hosts" || return 1
    else
        printf '127.0.1.1\t%s %s\n' "$fqdn" "$hn" >>"$hosts"
    fi
}

postutils_configure_locale() {
    # Single responsibility: configure locale generation and default LANG in target
    # Args: target_root locale lang(optional)
    local root; root="$(sanitize_path "${1-}")"
    local locale; locale="$(sanitize_ws "${2-}")"
    local lang; lang="$(sanitize_ws "${3-}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$locale" ]]; then
        locale="pt_BR.UTF-8"
    fi
    if [[ -z "$lang" ]]; then
        lang="$locale"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc"

    local gen
    gen="$(sanitize_path "$root/etc/locale.gen")"
    if [[ ! -f "$gen" ]]; then
        : >"$gen"
    fi

    # Ensure the locale is enabled in locale.gen (uncomment or append)
    if grep -Eq "^[[:space:]]*#?[[:space:]]*${locale}[[:space:]]+UTF-8" "$gen" 2>/dev/null; then
        require_cmd sed || return 1
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*(${locale}[[:space:]]+UTF-8)|\1|g" "$gen" || return 1
    else
        printf '%s UTF-8\n' "$locale" >>"$gen"
    fi

    printf 'LANG=%s\n' "$lang" >"$root/etc/default/locale"

    # Generate locales inside chroot (best-effort if locales not installed yet)
    postutils_chroot_run "$root" "locale-gen" || true
    postutils_chroot_run "$root" "update-locale LANG='${lang}'" || true
}

postutils_configure_keymap() {
    # Single responsibility: configure keyboard layout in target (console-setup)
    # Args: target_root keymap
    local root; root="$(sanitize_path "${1-}")"
    local km; km="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$km" ]]; then
        km="br"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/default"

    local file
    file="$(sanitize_path "$root/etc/default/keyboard")"
    {
        printf 'XKBMODEL="pc105"\n'
        printf 'XKBLAYOUT="%s"\n' "$km"
        printf 'XKBVARIANT=""\n'
        printf 'XKBOPTIONS=""\n'
        printf 'BACKSPACE="guess"\n'
    } >"$file"

    postutils_chroot_run "$root" "dpkg-reconfigure -f noninteractive keyboard-configuration" || true
}

postutils_set_timezone() {
    # Single responsibility: set timezone in target
    # Args: target_root timezone
    local root; root="$(sanitize_path "${1-}")"
    local tz; tz="$(sanitize_ws "${2-UTC}")"
    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$tz" ]]; then
        tz="UTC"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc"

    printf '%s\n' "$tz" >"$root/etc/timezone"
    if [[ -f "$root/usr/share/zoneinfo/$tz" ]]; then
        ln -sf "/usr/share/zoneinfo/$tz" "$root/etc/localtime" >/dev/null 2>&1 || true
    fi

    postutils_chroot_run "$root" "dpkg-reconfigure -f noninteractive tzdata" || true
}

postutils_create_user() {
    # Single responsibility: create user with sudo, set password
    # Args: target_root username fullname password
    local root; root="$(sanitize_path "${1-}")"
    local user; user="$(sanitize_ws "${2-}")"
    local full; full="$(sanitize_ws "${3-}")"
    local pw; pw="${4-}"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$user" || -z "$full" || -z "$(sanitize_ws "$pw")" ]]; then
        stderr "Erro: parâmetros inválidos para criar usuário."
        return 1
    fi

    # Ensure sudo exists
    postutils_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install sudo" || true

    # Create user if missing
    postutils_chroot_run "$root" "id -u '${user}' >/dev/null 2>&1 || useradd -m -s /bin/bash -c '${full}' '${user}'" || return 1

    # Set password
    local esc
    esc="$(printf '%s' "$pw" | sed -E 's/\\/\\\\/g; s/"/\\"/g')"
    postutils_chroot_run "$root" "printf '%s:%s\n' '${user}' \"${esc}\" | chpasswd" || return 1

    # Add to sudo group (Debian uses sudo)
    postutils_chroot_run "$root" "usermod -aG sudo '${user}'" || return 1
}

postutils_enable_root_account_optional() {
    # Single responsibility: enable root password or lock root
    # Args: target_root enable(1|0) root_password(optional)
    local root; root="$(sanitize_path "${1-}")"
    local enable; enable="$(sanitize_ws "${2-0}")"
    local pw; pw="${3-}"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ "$enable" != "1" && "$enable" != "0" ]]; then
        enable="0"
    fi

    if [[ "$enable" == "0" ]]; then
        postutils_chroot_run "$root" "passwd -l root" || true
        return 0
    fi

    if [[ -z "$(sanitize_ws "$pw")" ]]; then
        stderr "Erro: senha root vazia com enable=1."
        return 1
    fi

    local esc
    esc="$(printf '%s' "$pw" | sed -E 's/\\/\\\\/g; s/"/\\"/g')"
    postutils_chroot_run "$root" "printf '%s:%s\n' 'root' \"${esc}\" | chpasswd" || return 1
    postutils_chroot_run "$root" "passwd -u root" || true
}

postutils_write_resolv_conf_static_optional() {
    # Single responsibility: write resolv.conf in target if not symlink (best-effort)
    # Args: target_root dns_list_space_separated
    local root; root="$(sanitize_path "${1-}")"
    local dns; dns="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$dns" ]]; then
        return 0
    fi

    local file
    file="$(sanitize_path "$root/etc/resolv.conf")"
    if [[ -L "$file" ]]; then
        return 0
    fi

    : >"$file"
    local ip
    while IFS= read -r ip; do
        ip="$(sanitize_ws "$ip")"
        [[ -z "$ip" ]] && continue
        printf 'nameserver %s\n' "$ip" >>"$file"
    done < <(printf '%s' "$dns" | tr ' ' '\n' | sed -E '/^[[:space:]]*$/d')
}

postutils_set_zfs_cachefile_path() {
    # Single responsibility: set zpool cachefile path inside target
    # Args: target_root pool_name
    local root; root="$(sanitize_path "${1-}")"
    local pool; pool="$(sanitize_ws "${2-}")"
    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$pool" ]]; then
        stderr "Erro: pool vazio."
        return 1
    fi
    postutils_chroot_run "$root" "mkdir -p /etc/zfs && zpool set cachefile=/etc/zfs/zpool.cache '${pool}'" || return 1
}

postutils_update_initramfs_all() {
    # Single responsibility: update initramfs inside target
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    postutils_chroot_run "$root" "update-initramfs -u -k all" || return 1
}

postutils_write_machine_id() {
    # Single responsibility: ensure machine-id exists inside target
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    postutils_chroot_run "$root" "systemd-machine-id-setup" || return 1
}
