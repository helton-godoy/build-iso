#!/usr/bin/env bash
set -euo pipefail

# 12 - artifacts/scripts/ad_precheck_fileserver.sh
#
# Wrapper Debian-side para executar o script PowerShell AD-side que:
# - cria/verifica DNS A record fileserver.empresa.com.br -> VIP
# - cria/verifica computer account EMPRESA-FILESERVER
# - configura SPNs cifs/fileserver e cifs/fileserver.empresa.com.br
# - gera relatório JSON
#
# Métodos de execução remota:
#   (A) SSH para Windows (recomendado) -> executa pwsh
#   (B) WinRM via pywinrm (opcional)

usage() {
  cat <<'EOF'
Usage:
  ad-precheck-fileserver --method ssh --host JUMPBOX.empresa.com.br \
    --user 'EMPRESA\admin' --vip 10.10.10.50 --dns-server DC01 \
    --report /var/log/my-nas/ad_report.json [--apply]

  ad-precheck-fileserver --method winrm --host JUMPBOX.empresa.com.br \
    --user 'EMPRESA\admin' --vip 10.10.10.50 --dns-server DC01 \
    --report /var/log/my-nas/ad_report.json [--apply]

Notes:
- Without --apply, it is DRY-RUN (safe).
- Requires ad_setup_fileserver.ps1 present at /usr/local/share/my-nas/scripts/
- NUNCA armazene senhas neste script; use SSH por chave ou prompt interativo.
EOF
}

METHOD=""
HOST=""
REMOTE_USER=""
VIP=""
DNSSERVER=""
REPORT="/var/log/my-nas/ad_setup_fileserver.report.json"
APPLY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method) METHOD="$2"; shift 2;;
    --host) HOST="$2"; shift 2;;
    --user) REMOTE_USER="$2"; shift 2;;
    --vip) VIP="$2"; shift 2;;
    --dns-server) DNSSERVER="$2"; shift 2;;
    --report) REPORT="$2"; shift 2;;
    --apply) APPLY="true"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Argumento desconhecido: $1" >&2; usage; exit 2;;
  esac
done

# Validar parâmetros obrigatórios
if [[ -z "$METHOD" || -z "$HOST" || -z "$REMOTE_USER" || -z "$VIP" || -z "$DNSSERVER" ]]; then
  usage
  exit 1
fi

SCRIPT_LOCAL="/usr/local/share/my-nas/scripts/ad_setup_fileserver.ps1"
[[ -f "$SCRIPT_LOCAL" ]] || { echo "ERRO: Faltando $SCRIPT_LOCAL"; exit 1; }

mkdir -p "$(dirname "$REPORT")"

# Execução via SSH (método preferido — usa chave, sem senha)
run_via_ssh() {
  command -v ssh >/dev/null 2>&1 || { echo "ssh não instalado"; exit 1; }
  command -v scp >/dev/null 2>&1 || { echo "scp não instalado"; exit 1; }

  local tmp_ps1="C:/Windows/Temp/ad_setup_fileserver.ps1"
  local tmp_json="C:/Windows/Temp/ad_setup_fileserver.report.json"

  echo "Enviando PS1 para a Jump Box via scp..."
  scp -q "$SCRIPT_LOCAL" "${REMOTE_USER}@${HOST}:${tmp_ps1}"

  local args="-VipIPv4 ${VIP} -DnsServer ${DNSSERVER} -ReportPath ${tmp_json}"
  if [[ "$APPLY" == "true" ]]; then args="${args} -Apply"; fi

  echo "Executando PowerShell remotamente via SSH..."
  ssh -o BatchMode=yes "${REMOTE_USER}@${HOST}" "pwsh -NoProfile -ExecutionPolicy Bypass -File ${tmp_ps1} ${args}"

  echo "Baixando relatório JSON..."
  scp -q "${REMOTE_USER}@${HOST}:${tmp_json}" "$REPORT"
}

# Execução via WinRM (alternativa se SSH não estiver disponível)
run_via_winrm() {
  command -v python3 >/dev/null 2>&1 || { echo "python3 não instalado"; exit 1; }

  echo "AVISO: Método WinRM requer pywinrm instalado (pip install pywinrm)"
  echo "A senha será solicitada interativamente."

  python3 - <<PY
import getpass, json, pathlib
try:
    import winrm
except ImportError:
    raise SystemExit("ERRO: pywinrm não instalado. Execute: pip install pywinrm")

host = "${HOST}"
user = "${REMOTE_USER}"
vip  = "${VIP}"
dns  = "${DNSSERVER}"
apply = "$APPLY" == "true"
script_path = "${SCRIPT_LOCAL}"
report_path = "${REPORT}"

pw = getpass.getpass("Senha WinRM para %s: " % user)

ps = pathlib.Path(script_path).read_text(encoding="utf-8")
args = "-VipIPv4 '%s' -DnsServer '%s'" % (vip, dns)
if apply:
    args += " -Apply"
cmd = ps + "\n" + args

s = winrm.Session(host, auth=(user, pw))
r = s.run_ps(cmd)
if r.status_code != 0:
    raise SystemExit("WinRM falhou: %s" % r.std_err.decode(errors="ignore"))
print(r.std_out.decode(errors="ignore"))
PY
}

case "$METHOD" in
  ssh) run_via_ssh;;
  winrm) run_via_winrm;;
  *) echo "Método inválido: $METHOD (use ssh|winrm)" >&2; exit 2;;
esac

echo "OK. Relatório salvo em: $REPORT"
