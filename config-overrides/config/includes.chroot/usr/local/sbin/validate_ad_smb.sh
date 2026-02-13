#!/usr/bin/env bash
set -euo pipefail

REALM=""
DOMAIN=""
VIP_FQDN=""
SHARE=""
USER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --realm)
    REALM="$2"
    shift 2
    ;;
  --domain)
    DOMAIN="$2"
    shift 2
    ;;
  --vip-fqdn)
    VIP_FQDN="$2"
    shift 2
    ;;
  --share)
    SHARE="$2"
    shift 2
    ;;
  --user)
    USER="$2"
    shift 2
    ;;
  *)
    printf 'Argumento desconhecido: %s\n' "$1" >&2
    exit 2
    ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || {
  printf 'Faltando comando: %s\n' "$1" >&2
  exit 1
}; }

need testparm
need smbclient
need smbcacls
need wbinfo
need net
need kinit
need host
need timedatectl

if [[ -n "${VIP_FQDN}" ]]; then
  host "${VIP_FQDN}" >/dev/null
fi

if [[ -n "${REALM}" ]]; then
  kinit -k
fi

if [[ -n "${DOMAIN}" ]]; then
  wbinfo --online-status >/dev/null 2>&1 || true
fi

net ads testjoin
wbinfo -t
testparm -s >/dev/null

if [[ -n "${SHARE}" && -n "${USER}" ]]; then
  smbclient "${SHARE}" -U "${USER}" -c 'ls'
  smbcacls "${SHARE}" / -U "${USER}" --maximum-access || true
fi

printf 'OK: validacoes AD/SMB concluidas.\n'
