```bash
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: post-utils.sh
# Purpose: post-install configuration helpers (locale, timezone, users, networking, initramfs, services)
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

POSTUTILS_TARGET_ROOT_DEFAULT="/mnt"
POSTUTILS_LOCALE_DEFAULT="pt_BR.UTF-8"
POSTUTILS_LANG_DEFAULT="pt_BR.UTF-8"
POSTUTILS_KEYMAP_DEFAULT="br"
POSTUTILS_HOSTNAME_DEFAULT="fileserver"
POSTUTILS_TZ_DEFAULT="UTC"

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

postutils_loaded() { :; }

postutils_chroot_run() {
    # Single responsibility: run a command in chroot with sanitized env
    # Args: target_root command_string
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

    if ! chroot "$root" /usr/bin/env -i "PATH=/usr/sbin:/usr/bin:/sbin:/bin" /bin/bash -lc "$cmd" >/dev/null 2>&1; then
        stderr "Erro: comando chroot falhou: $cmd"
        return 1
    fi
}

postutils_set_hostname() {
    # Single responsibility: set /etc/hostname and /etc/hosts minimal entries
    # Args: target_root hostname domain(optional)
    local root; root="$(sanitize_path "${1-}")"
    local hn; hn="$(sanitize_ws "${2-}")"
    local dom; dom="$(sanitize_ws "${3-}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    hn="$(sanitize_ws "$hn")"
    if [[ -z "$hn" ]]; then
        hn="$POSTUTILS_HOSTNAME_DEFAULT"
    fi

    local fqdn
    fqdn="$hn"
    if [[ -n "$dom" ]]; then
        fqdn="${hn}.${dom}"
    fi

    printf '%s\n' "$hn" >"$root/etc/hostname"

    local hosts
    hosts="$(sanitize_path "$root/etc/hosts")"
    if [[ ! -f "$hosts" ]]; then
        : >"$hosts"
    fi

    if ! grep -Eq '^[[:space:]]*127\.0\.1\.1[[:space:]]+' "$hosts" 2>/dev/null; then
        printf '127.0.1.1\t%s %s\n' "$fqdn" "$hn" >>"$hosts"
    else
        # Replace existing 127.0.1.1 line
        require_cmd sed || return 1
        sed -i -E "s|^[[:space:]]*127\.0\.1\.1[[:space:]]+.*$|127.0.1.1\t${fqdn} ${hn}|g" "$hosts" || return 1
    fi

    if ! grep -Eq '^[[:space:]]*127\.0\.0\.1[[:space:]]+localhost' "$hosts" 2>/dev/null; then
        printf '127.0.0.1\tlocalhost\n' >>"$hosts"
    fi
    if ! grep -Eq '^[[:space:]]*::1[[:space:]]+localhost' "$hosts" 2>/dev/null; then
        printf '::1\tlocalhost ip6-localhost ip6-loopback\n' >>"$hosts"
    fi
}

postutils_configure_locale() {
    # Single responsibility: configure locale generation and default locale
    # Args: target_root locale lang
    local root; root="$(sanitize_path "${1-}")"
    local locale; locale="$(sanitize_ws "${2-}")"
    local lang; lang="$(sanitize_ws "${3-}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$locale" ]]; then
        locale="$POSTUTILS_LOCALE_DEFAULT"
    fi
    if [[ -z "$lang" ]]; then
        lang="$POSTUTILS_LANG_DEFAULT"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/default"

    local gen
    gen="$(sanitize_path "$root/etc/locale.gen")"
    if [[ ! -f "$gen" ]]; then
        : >"$gen"
    fi

    # Ensure locale in locale.gen
    if ! grep -Eq "^[[:space:]]*${locale}[[:space:]]+UTF-8" "$gen" 2>/dev/null; then
        printf '%s UTF-8\n' "$locale" >>"$gen"
    fi

    local def
    def="$(sanitize_path "$root/etc/default/locale")"
    {
        printf 'LANG=%s\n' "$lang"
        printf 'LC_ALL=%s\n' "$locale"
    } >"$def"

    postutils_chroot_run "$root" "locale-gen" || return 1
    postutils_chroot_run "$root" "update-locale LANG=${lang} LC_ALL=${locale}" || return 1
}

postutils_configure_keymap() {
    # Single responsibility: set console keymap
    # Args: target_root keymap
    local root; root="$(sanitize_path "${1-}")"
    local km; km="$(sanitize_id "${2-}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$km" ]]; then
        km="$POSTUTILS_KEYMAP_DEFAULT"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/default"

    local kbd
    kbd="$(sanitize_path "$root/etc/default/keyboard")"
    {
        printf 'XKBLAYOUT="%s"\n' "$km"
        printf 'XKBVARIANT=""\n'
        printf 'XKBOPTIONS=""\n'
    } >"$kbd"
}

postutils_set_timezone() {
    # Single responsibility: configure timezone and /etc/localtime symlink
    # Args: target_root timezone
    local root; root="$(sanitize_path "${1-}")"
    local tz; tz="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$tz" ]]; then
        tz="$POSTUTILS_TZ_DEFAULT"
    fi

    printf '%s\n' "$tz" >"$root/etc/timezone"
    postutils_chroot_run "$root" "ln -sf /usr/share/zoneinfo/${tz} /etc/localtime" || return 1
    postutils_chroot_run "$root" "dpkg-reconfigure -f noninteractive tzdata" || return 1
}

postutils_create_user() {
    # Single responsibility: create user with sudo
    # Args: target_root username fullname password_plain
    local root; root="$(sanitize_path "${1-}")"
    local user; user="$(sanitize_id "${2-}")"
    local full; full="$(sanitize_ws "${3-}")"
    local pass; pass="${4-}"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$user" ]]; then
        stderr "Erro: username vazio."
        return 1
    fi
    if [[ -z "$full" ]]; then
        full="$user"
    fi
    if [[ -z "$(sanitize_ws "$pass")" ]]; then
        stderr "Erro: senha vazia."
        return 1
    fi

    # Create user if missing
    postutils_chroot_run "$root" "id -u ${user} >/dev/null 2>&1 || useradd -m -s /bin/bash -c \"${full}\" ${user}" || return 1

    # Set password via chpasswd (stdin)
    require_cmd chroot || return 1
    if ! printf '%s:%s\n' "$user" "$pass" | chroot "$root" /usr/sbin/chpasswd >/dev/null 2>&1; then
        stderr "Erro: falha ao definir senha do usuário $user."
        return 1
    fi

    # Ensure sudo installed and add to sudo group
    postutils_chroot_run "$root" "apt-get update" || return 1
    postutils_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install sudo" || return 1
    postutils_chroot_run "$root" "usermod -aG sudo ${user}" || return 1
}

postutils_enable_root_account_optional() {
    # Single responsibility: enable or disable root password
    # Args: target_root enable(1|0) root_password_plain(optional)
    local root; root="$(sanitize_path "${1-}")"
    local enable; enable="$(sanitize_ws "${2-0}")"
    local pass; pass="${3-}"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    enable="$(sanitize_ws "$enable")"
    if [[ "$enable" != "1" && "$enable" != "0" ]]; then
        enable="0"
    fi

    require_cmd chroot || return 1

    if [[ "$enable" == "0" ]]; then
        postutils_chroot_run "$root" "passwd -l root" || return 1
        return 0
    fi

    if [[ -z "$(sanitize_ws "$pass")" ]]; then
        stderr "Erro: root_password vazia com enable=1."
        return 1
    fi

    if ! printf 'root:%s\n' "$pass" | chroot "$root" /usr/sbin/chpasswd >/dev/null 2>&1; then
        stderr "Erro: falha ao definir senha do root."
        return 1
    fi
    postutils_chroot_run "$root" "passwd -u root" || return 1
}

postutils_enable_service() {
    # Single responsibility: enable a systemd service in target
    # Args: target_root service_name
    local root; root="$(sanitize_path "${1-}")"
    local svc; svc="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$svc" ]]; then
        stderr "Erro: service vazio."
        return 1
    fi

    postutils_chroot_run "$root" "systemctl enable ${svc}" || return 1
}

postutils_configure_ssh_optional() {
    # Single responsibility: install+enable OpenSSH if requested
    # Args: target_root enable(1|0)
    local root; root="$(sanitize_path "${1-}")"
    local enable; enable="$(sanitize_ws "${2-0}")"

    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ "$enable" != "1" ]]; then
        return 0
    fi

    postutils_chroot_run "$root" "apt-get update" || return 1
    postutils_chroot_run "$root" "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install openssh-server" || return 1
    postutils_enable_service "$root" "ssh" || return 1
}

postutils_write_resolv_conf_static_optional() {
    # Single responsibility: write resolv.conf for manual networking (best-effort)
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

    # Avoid breaking systemd-resolved; only write if not a symlink
    if [[ -L "$file" ]]; then
        return 0
    fi

    : >"$file"
    local ip
    while IFS= read -r ip; do
        ip="$(sanitize_ws "$ip")"
        if [[ -z "$ip" ]]; then
            continue
        fi
        printf 'nameserver %s\n' "$ip" >>"$file"
    done < <(printf '%s' "$dns" | tr ' ' '\n' | sed -E '/^[[:space:]]*$/d')
}

postutils_update_initramfs_all() {
    # Single responsibility: update initramfs inside chroot
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    postutils_chroot_run "$root" "update-initramfs -u -k all" || return 1
}

postutils_set_zfs_cachefile_path() {
    # Single responsibility: set zpool cachefile to /etc/zfs/zpool.cache (inside chroot)
    # Args: target_root pool_name
    local root; root="$(sanitize_path "${1-}")"
    local pool; pool="$(sanitize_ws "${2-}")"
    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$pool" ]]; then
        stderr "Erro: pool vazio para cachefile."
        return 1
    fi
    postutils_chroot_run "$root" "mkdir -p /etc/zfs && zpool set cachefile=/etc/zfs/zpool.cache ${pool}" || return 1
}

postutils_write_machine_id() {
    # Single responsibility: ensure machine-id exists (systemd)
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$POSTUTILS_TARGET_ROOT_DEFAULT"
    fi
    postutils_chroot_run "$root" "systemd-machine-id-setup" || return 1
}
```
