#!/usr/bin/env bash
set -euo pipefail

METHOD=""
HOST=""
REMOTE_USER=""
VIP=""
DNSSERVER=""
REPORT="/var/log/my-nas/ad_setup_fileserver.report.json"
APPLY="false"

usage() {
  cat <<'EOF'
Uso:
  ad_precheck_fileserver.sh --method ssh --host JUMPBOX.empresa.com.br \
    --user 'EMPRESA\svc-nas-automation' --vip 10.10.10.50 --dns-server DC01 \
    --report /var/log/my-nas/ad_report.json [--apply]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --method)
    METHOD="$2"
    shift 2
    ;;
  --host)
    HOST="$2"
    shift 2
    ;;
  --user)
    REMOTE_USER="$2"
    shift 2
    ;;
  --vip)
    VIP="$2"
    shift 2
    ;;
  --dns-server)
    DNSSERVER="$2"
    shift 2
    ;;
  --report)
    REPORT="$2"
    shift 2
    ;;
  --apply)
    APPLY="true"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf 'Argumento desconhecido: %s\n' "$1" >&2
    usage
    exit 2
    ;;
  esac
done

if [[ -z "${METHOD}" || -z "${HOST}" || -z "${REMOTE_USER}" || -z "${VIP}" || -z "${DNSSERVER}" ]]; then
  usage
  exit 1
fi

SCRIPT_LOCAL="/usr/local/share/my-nas/scripts/ad_setup_fileserver.ps1"
if [[ ! -f "${SCRIPT_LOCAL}" ]]; then
  printf 'ERRO: Faltando %s\n' "${SCRIPT_LOCAL}" >&2
  exit 1
fi

mkdir -p "$(dirname "${REPORT}")"

run_via_ssh() {
  command -v ssh >/dev/null 2>&1 || {
    printf 'ssh nao instalado\n' >&2
    exit 1
  }
  command -v scp >/dev/null 2>&1 || {
    printf 'scp nao instalado\n' >&2
    exit 1
  }

  local tmp_ps1 tmp_json args
  tmp_ps1="C:/Windows/Temp/ad_setup_fileserver.ps1"
  tmp_json="C:/Windows/Temp/ad_setup_fileserver.report.json"

  scp -q "${SCRIPT_LOCAL}" "${REMOTE_USER}@${HOST}:${tmp_ps1}"
  args="-VipIPv4 ${VIP} -DnsServer ${DNSSERVER} -ReportPath ${tmp_json}"
  if [[ "${APPLY}" == "true" ]]; then
    args="${args} -Apply"
  fi

  ssh -o BatchMode=yes "${REMOTE_USER}@${HOST}" \
    "pwsh -NoProfile -ExecutionPolicy Bypass -File ${tmp_ps1} ${args}"

  scp -q "${REMOTE_USER}@${HOST}:${tmp_json}" "${REPORT}"
}

run_via_winrm() {
  printf 'Metodo winrm nao habilitado neste baseline. Use --method ssh.\n' >&2
  exit 2
}

case "${METHOD}" in
ssh) run_via_ssh ;;
winrm) run_via_winrm ;;
*)
  printf 'Metodo invalido: %s\n' "${METHOD}" >&2
  exit 2
  ;;
esac

printf 'OK. Relatorio salvo em: %s\n' "${REPORT}"
