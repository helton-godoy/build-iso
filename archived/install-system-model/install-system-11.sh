#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Library: time-utils.sh
# Purpose: timezone selection helpers, NTP enablement, clock sync (installer + target)
# Notes:
# - Designed to be lazy-loaded by installer-router.sh
# - Single-responsibility functions
# - No exits inside functions (return codes only)
# - All stderr messages via printf >&2

TIMEUTILS_ALLOWED_TZ_RE_DEFAULT='^[A-Za-z]+(/[A-Za-z0-9._+-]+)+$'
TIMEUTILS_TARGET_ROOT_DEFAULT="/mnt"
TIMEUTILS_DEFAULT_NTP_SERVER="pool.ntp.org"

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

timeutils_loaded() { :; }

timeutils_is_timezone() {
    local tz; tz="$(sanitize_ws "${1-}")"
    [[ -n "$tz" && "$tz" =~ $TIMEUTILS_ALLOWED_TZ_RE_DEFAULT ]]
}

timeutils_list_timezones() {
    # Single responsibility: list available timezones (best-effort)
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl list-timezones 2>/dev/null || true
        return 0
    fi
    if [[ -f /usr/share/zoneinfo/zone.tab ]]; then
        awk '!/^#/ && NF>=3 {print $3}' /usr/share/zoneinfo/zone.tab 2>/dev/null || true
        return 0
    fi
    find /usr/share/zoneinfo -type f 2>/dev/null \
        | sed -E 's|^/usr/share/zoneinfo/||' \
        | grep -Ev '^(posix|right|Etc)/|^leapseconds$|^localtime$' || true
}

timeutils_set_timezone_installer() {
    # Single responsibility: set timezone in installer/live environment
    # Args: tz
    local tz; tz="$(sanitize_ws "${1-}")"
    if ! timeutils_is_timezone "$tz"; then
        stderr "Erro: timezone inválido: $tz"
        return 1
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-timezone "$tz" >/dev/null 2>&1 || return 1
        return 0
    fi

    if [[ -d /usr/share/zoneinfo && -f "/usr/share/zoneinfo/${tz}" ]]; then
        ln -sf "/usr/share/zoneinfo/${tz}" /etc/localtime >/dev/null 2>&1 || return 1
        printf '%s\n' "$tz" >/etc/timezone
        return 0
    fi

    stderr "Erro: não foi possível aplicar timezone (timedatectl indisponível e zoneinfo ausente)."
    return 1
}

timeutils_enable_ntp_installer() {
    # Single responsibility: enable NTP in installer environment
    # Args: enable(1|0)
    local enable; enable="$(sanitize_ws "${1-1}")"
    if [[ "$enable" != "1" && "$enable" != "0" ]]; then
        enable="1"
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        if [[ "$enable" == "1" ]]; then
            timedatectl set-ntp true >/dev/null 2>&1 || return 1
            return 0
        fi
        timedatectl set-ntp false >/dev/null 2>&1 || return 1
        return 0
    fi

    # If systemd tools not available, best-effort with ntpdate or chrony.
    if [[ "$enable" == "0" ]]; then
        return 0
    fi

    if command -v chronyc >/dev/null 2>&1; then
        chronyc -a makestep >/dev/null 2>&1 || true
        return 0
    fi
    if command -v ntpdate >/dev/null 2>&1; then
        ntpdate -u "$TIMEUTILS_DEFAULT_NTP_SERVER" >/dev/null 2>&1 || true
        return 0
    fi
}

timeutils_sync_clock_installer() {
    # Single responsibility: attempt a clock sync (best-effort)
    # Args: server(optional)
    local server; server="$(sanitize_ws "${1-}")"
    if [[ -z "$server" ]]; then
        server="$TIMEUTILS_DEFAULT_NTP_SERVER"
    fi

    if command -v chronyc >/dev/null 2>&1; then
        chronyc -a "server ${server} iburst" >/dev/null 2>&1 || true
        chronyc -a makestep >/dev/null 2>&1 || true
        return 0
    fi
    if command -v ntpdate >/dev/null 2>&1; then
        ntpdate -u "$server" >/dev/null 2>&1 || true
        return 0
    fi
    if command -v sntp >/dev/null 2>&1; then
        sntp -s "$server" >/dev/null 2>&1 || true
        return 0
    fi
}

timeutils_write_timezone_target() {
    # Single responsibility: write timezone settings into target root (without requiring chroot)
    # Args: target_root tz
    local root; root="$(sanitize_path "${1-}")"
    local tz; tz="$(sanitize_ws "${2-}")"

    if [[ -z "$root" ]]; then
        root="$TIMEUTILS_TARGET_ROOT_DEFAULT"
    fi
    if ! timeutils_is_timezone "$tz"; then
        stderr "Erro: timezone inválido: $tz"
        return 1
    fi
    if [[ ! -d "$root/usr/share/zoneinfo" || ! -f "$root/usr/share/zoneinfo/$tz" ]]; then
        stderr "Erro: zoneinfo não disponível no target para $tz"
        return 1
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc"

    printf '%s\n' "$tz" >"$root/etc/timezone"
    ln -sf "/usr/share/zoneinfo/${tz}" "$root/etc/localtime" >/dev/null 2>&1 || return 1
}

timeutils_configure_timesyncd_target() {
    # Single responsibility: configure systemd-timesyncd in target root
    # Args: target_root enable(1|0) server(optional)
    local root; root="$(sanitize_path "${1-}")"
    local enable; enable="$(sanitize_ws "${2-1}")"
    local server; server="$(sanitize_ws "${3-}")"

    if [[ -z "$root" ]]; then
        root="$TIMEUTILS_TARGET_ROOT_DEFAULT"
    fi
    if [[ "$enable" != "1" && "$enable" != "0" ]]; then
        enable="1"
    fi
    if [[ -z "$server" ]]; then
        server="$TIMEUTILS_DEFAULT_NTP_SERVER"
    fi

    require_cmd mkdir || return 1
    mkdir -p "$root/etc/systemd"

    local conf
    conf="$(sanitize_path "$root/etc/systemd/timesyncd.conf")"

    if [[ "$enable" == "0" ]]; then
        # Disable by masking service (no chroot required)
        mkdir -p "$root/etc/systemd/system"
        ln -sf /dev/null "$root/etc/systemd/system/systemd-timesyncd.service" >/dev/null 2>&1 || true
        return 0
    fi

    {
        printf '[Time]\n'
        printf 'NTP=%s\n' "$server"
        printf 'FallbackNTP=%s\n' "$TIMEUTILS_DEFAULT_NTP_SERVER"
    } >"$conf"

    # Ensure service not masked
    rm -f "$root/etc/systemd/system/systemd-timesyncd.service" >/dev/null 2>&1 || true
}
