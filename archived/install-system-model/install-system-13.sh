#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: finalize-chroot.sh
# Purpose: finalize target system in chroot (fstab/hostname/locale/users/zfs cache/initramfs/boot)
# Notes:
# - Designed to be lazy-loaded by installer-router.sh (as a dep)
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

FINALIZE_TARGET_ROOT_DEFAULT="/mnt"

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

finalize_loaded() { :; }

finalize_chroot_run() {
    # Single responsibility: run command in chroot with sanitized env
    # Args: target_root cmd
    local root; root="$(sanitize_path "${1-}")"
    local cmd; cmd="$(sanitize_ws "${2-}")"
    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
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

finalize_ensure_core_files() {
    # Single responsibility: ensure minimal core files exist
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
    fi
    require_cmd mkdir || return 1
    mkdir -p "$root/etc"
    mkdir -p "$root/etc/default"
    mkdir -p "$root/etc/apt/apt.conf.d"
    mkdir -p "$root/etc/zfs"
}

finalize_write_hostname_hosts() {
    # Single responsibility: write hostname and hosts mapping
    # Args: target_root hostname domain
    local root; root="$(sanitize_path "${1-}")"
    local hn; hn="$(sanitize_ws "${2-}")"
    local dom; dom="$(sanitize_ws "${3-}")"

    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$hn" ]]; then
        stderr "Erro: hostname vazio."
        return 1
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

finalize_write_networking_static_optional() {
    # Single responsibility: write resolv.conf if manual dns specified (best-effort)
    # Args: target_root dns_list
    local root; root="$(sanitize_path "${1-}")"
    local dns; dns="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
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
        if [[ -z "$ip" ]]; then
            continue
        fi
        printf 'nameserver %s\n' "$ip" >>"$file"
    done < <(printf '%s' "$dns" | tr ' ' '\n' | sed -E '/^[[:space:]]*$/d')
}

finalize_set_zpool_cachefile_in_chroot() {
    # Single responsibility: set zpool cachefile to /etc/zfs/zpool.cache in chroot
    # Args: target_root pool_name
    local root; root="$(sanitize_path "${1-}")"
    local pool; pool="$(sanitize_ws "${2-}")"
    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$pool" ]]; then
        stderr "Erro: pool vazio."
        return 1
    fi
    finalize_chroot_run "$root" "mkdir -p /etc/zfs && zpool set cachefile=/etc/zfs/zpool.cache ${pool}" || return 1
}

finalize_update_initramfs_all() {
    # Single responsibility: update initramfs
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
    fi
    finalize_chroot_run "$root" "update-initramfs -u -k all" || return 1
}

finalize_write_grub_cmdline_optional() {
    # Single responsibility: set GRUB_CMDLINE_LINUX in /etc/default/grub if cmdline passed
    # Args: target_root cmdline
    local root; root="$(sanitize_path "${1-}")"
    local cmdline; cmdline="$(sanitize_ws "${2-}")"
    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
    fi
    if [[ -z "$cmdline" ]]; then
        return 0
    fi

    local file
    file="$(sanitize_path "$root/etc/default/grub")"
    if [[ ! -f "$file" ]]; then
        stderr "Erro: arquivo não encontrado: $file"
        return 1
    fi

    require_cmd sed || return 1
    local esc
    esc="$(printf '%s' "$cmdline" | sed -E 's/\\/\\\\/g; s/"/\\"/g')"

    if grep -Eq '^[[:space:]]*GRUB_CMDLINE_LINUX=' "$file" 2>/dev/null; then
        sed -i -E "s|^[[:space:]]*GRUB_CMDLINE_LINUX=.*$|GRUB_CMDLINE_LINUX=\"${esc}\"|g" "$file" || return 1
    else
        printf '\nGRUB_CMDLINE_LINUX="%s"\n' "$esc" >>"$file"
    fi
}

finalize_generate_grub_cfg() {
    # Single responsibility: generate grub configuration
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
    fi
    if ! finalize_chroot_run "$root" "update-grub"; then
        finalize_chroot_run "$root" "grub-mkconfig -o /boot/grub/grub.cfg" || return 1
    fi
}

finalize_machine_id() {
    # Single responsibility: ensure machine-id exists
    # Args: target_root
    local root; root="$(sanitize_path "${1-}")"
    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
    fi
    finalize_chroot_run "$root" "systemd-machine-id-setup" || return 1
}

finalize_all() {
    # Single responsibility: orchestrate finalization for target root
    # Args: target_root pool_name hostname domain dns_list grub_cmdline
    local root; root="$(sanitize_path "${1-}")"
    local pool; pool="$(sanitize_ws "${2-}")"
    local hn; hn="$(sanitize_ws "${3-}")"
    local dom; dom="$(sanitize_ws "${4-}")"
    local dns; dns="$(sanitize_ws "${5-}")"
    local cmdline; cmdline="$(sanitize_ws "${6-}")"

    if [[ -z "$root" ]]; then
        root="$FINALIZE_TARGET_ROOT_DEFAULT"
    fi

    finalize_ensure_core_files "$root" || return 1
    if [[ -n "$hn" ]]; then
        finalize_write_hostname_hosts "$root" "$hn" "$dom" || return 1
    fi
    finalize_write_networking_static_optional "$root" "$dns" || return 1
    if [[ -n "$pool" ]]; then
        finalize_set_zpool_cachefile_in_chroot "$root" "$pool" || return 1
    fi
    finalize_write_grub_cmdline_optional "$root" "$cmdline" || return 1
    finalize_update_initramfs_all "$root" || return 1
    finalize_generate_grub_cfg "$root" || return 1
    finalize_machine_id "$root" || return 1
}
