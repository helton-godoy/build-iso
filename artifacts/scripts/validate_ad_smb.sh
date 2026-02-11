#!/usr/bin/env bash
set -euo pipefail

# 10 - artifacts/scripts/validate_ad_smb.sh
#
# Uso:
#   sudo ./validate_ad_smb.sh --realm EXEMPLO.COM --domain EXEMPLO \
#     --vip-fqdn filesvc.exemplo.com \
#     --share //filesvc/SHARE_EXEMPLO --user 'EXEMPLO\Administrador'
#
# Observação: este script valida o lado Linux.
# A validação de multichannel é do lado Windows (ver artifacts/docs/windows_validate_multichannel.md).

REALM=""
DOMAIN=""
VIP_FQDN=""
SHARE=""
USER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --realm) REALM="$2"; shift 2;;
    --domain) DOMAIN="$2"; shift 2;;
    --vip-fqdn) VIP_FQDN="$2"; shift 2;;
    --share) SHARE="$2"; shift 2;;
    --user) USER="$2"; shift 2;;
    *) echo "Argumento desconhecido: $1"; exit 2;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Faltando comando: $1"; exit 1; }; }

echo "[1/9] Checando comandos necessários"
need testparm
need smbclient
need smbcacls
need wbinfo
need net
need kinit
need host
need timedatectl

echo "[2/9] Checando sincronismo de tempo (Kerberos é sensível a clock skew)"
timedatectl status | sed -n '1,12p' || true
echo "Dica: Kerberos costuma falhar se o desvio de relógio excede ~300s; use NTP/chrony corretamente."

echo "[3/9] Validando resolução DNS (VIP/FQDN)"
if [[ -n "${VIP_FQDN}" ]]; then
  host "${VIP_FQDN}" || { echo "ERRO: DNS não resolve ${VIP_FQDN}"; exit 1; }
fi

echo "[4/9] Validando Kerberos (keytab)"
if [[ -n "${REALM}" ]]; then
  echo "Tentando kinit -k (keytab). Se falhar: DNS/tempo/realm/keytab."
  kinit -k || { echo "ERRO: kinit -k falhou"; exit 1; }
fi

echo "[5/9] Validando join no domínio (net ads testjoin)"
net ads testjoin || { echo "ERRO: net ads testjoin falhou"; exit 1; }

echo "[6/9] Validando Winbind (trust e enum básico)"
wbinfo -t || { echo "ERRO: wbinfo -t falhou"; exit 1; }
wbinfo --online-status || true
wbinfo -u | head -n 5 || true
wbinfo -g | head -n 5 || true

echo "[7/9] Validando configuração do Samba (testparm)"
testparm -s >/dev/null || { echo "ERRO: testparm encontrou problemas"; exit 1; }

echo "[8/9] Smoke test de acesso ao share via smbclient"
if [[ -n "${SHARE}" && -n "${USER}" ]]; then
  echo "Tentando listar share. Informe senha quando solicitado."
  smbclient "${SHARE}" -U "${USER}" -c 'ls' || { echo "ERRO: smbclient ls falhou"; exit 1; }
else
  echo "Pulando smbclient (faltou --share e/ou --user)"
fi

echo "[9/9] Smoke test de ACL via smbcacls"
# smbcacls manipula NT ACL em shares SMB e pode operar em SMB2/SMB3 (max-protocol).
if [[ -n "${SHARE}" && -n "${USER}" ]]; then
  echo "Consultando ACL do diretório raiz do share. Informe senha quando solicitado."
  smbcacls "${SHARE}" / -U "${USER}" --maximum-access || true
  echo "Dica: use --sddl para export/import ACL em formato SDDL se necessário."
else
  echo "Pulando smbcacls (faltou --share e/ou --user)"
fi

echo "OK: validações básicas concluídas."
echo "Para validar SMB Multichannel, rode os comandos no Windows conforme artifacts/docs/windows_validate_multichannel.md."
