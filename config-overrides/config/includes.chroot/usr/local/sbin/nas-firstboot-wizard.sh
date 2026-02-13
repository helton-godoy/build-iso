#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/var/lib/my-nas-firstboot"
MARKER_FILE="${STATE_DIR}/completed"
LOG_DIR="/var/log/my-nas"
LOG_FILE="${LOG_DIR}/firstboot-wizard.log"
DEFAULTS_FILE="/etc/default/my-nas-firstboot"

SMB_TEMPLATE="/usr/local/share/my-nas/templates/smb.conf.smb-only.template"
SMB_CONFIG="/etc/samba/smb.conf"

VALIDATE_SCRIPT="/usr/local/sbin/validate_ad_smb.sh"
AD_PRECHECK_SCRIPT="/usr/local/sbin/ad_precheck_fileserver.sh"

log() {
  mkdir -p "${LOG_DIR}"
  printf '%s [INFO] %s\n' "$(date -Is)" "$*" | tee -a "${LOG_FILE}" >/dev/null
}

warn() {
  mkdir -p "${LOG_DIR}"
  printf '%s [WARN] %s\n' "$(date -Is)" "$*" | tee -a "${LOG_FILE}" >/dev/null
}

load_defaults() {
  if [[ -f "${DEFAULTS_FILE}" ]]; then
    while IFS='=' read -r raw_key raw_value; do
      raw_key="${raw_key%%[[:space:]]*}"
      [[ -z "${raw_key}" || "${raw_key}" =~ ^# ]] && continue

      raw_value="${raw_value#\"}"
      raw_value="${raw_value%\"}"

      case "${raw_key}" in
      NAS_REALM | NAS_DOMAIN | NAS_VIP_FQDN | NAS_SHARE | NAS_USER | AD_METHOD | AD_JUMPBOX_HOST | AD_JUMPBOX_USER | AD_VIP_IPV4 | AD_DNS_SERVER)
        printf -v "${raw_key}" '%s' "${raw_value}"
        ;;
      esac
    done <"${DEFAULTS_FILE}"
  fi

  : "${NAS_REALM:=}"
  : "${NAS_DOMAIN:=}"
  : "${NAS_VIP_FQDN:=}"
  : "${NAS_SHARE:=}"
  : "${NAS_USER:=}"

  : "${AD_METHOD:=ssh}"
  : "${AD_JUMPBOX_HOST:=}"
  : "${AD_JUMPBOX_USER:=}"
  : "${AD_VIP_IPV4:=}"
  : "${AD_DNS_SERVER:=}"
}

ensure_state() {
  mkdir -p "${STATE_DIR}" "${LOG_DIR}"
}

apply_smb_template_if_missing() {
  if [[ -f "${SMB_CONFIG}" ]]; then
    log "smb.conf ja existe; mantendo configuracao atual."
    return 0
  fi

  if [[ ! -f "${SMB_TEMPLATE}" ]]; then
    warn "Template SMB ausente em ${SMB_TEMPLATE}; pulando provisionamento de smb.conf."
    return 0
  fi

  mkdir -p /etc/samba
  cp "${SMB_TEMPLATE}" "${SMB_CONFIG}"
  chmod 0644 "${SMB_CONFIG}"
  log "Template SMB aplicado em ${SMB_CONFIG}."
}

run_validate_if_configured() {
  if [[ ! -x "${VALIDATE_SCRIPT}" ]]; then
    warn "Script ${VALIDATE_SCRIPT} nao encontrado; pulando validacao AD/SMB."
    return 0
  fi

  if [[ -z "${NAS_REALM}" || -z "${NAS_DOMAIN}" || -z "${NAS_VIP_FQDN}" ]]; then
    warn "Parametros NAS_REALM/NAS_DOMAIN/NAS_VIP_FQDN ausentes; pulando validate_ad_smb."
    return 0
  fi

  local args
  args=(--realm "${NAS_REALM}" --domain "${NAS_DOMAIN}" --vip-fqdn "${NAS_VIP_FQDN}")
  if [[ -n "${NAS_SHARE}" ]]; then
    args+=(--share "${NAS_SHARE}")
  fi
  if [[ -n "${NAS_USER}" ]]; then
    args+=(--user "${NAS_USER}")
  fi

  if ! "${VALIDATE_SCRIPT}" "${args[@]}"; then
    warn "validate_ad_smb retornou erro; revisar ${LOG_FILE}."
  else
    log "validate_ad_smb executado com sucesso."
  fi
}

run_ad_precheck_if_configured() {
  if [[ ! -x "${AD_PRECHECK_SCRIPT}" ]]; then
    warn "Script ${AD_PRECHECK_SCRIPT} nao encontrado; pulando precheck AD-side."
    return 0
  fi

  if [[ -z "${AD_JUMPBOX_HOST}" || -z "${AD_JUMPBOX_USER}" || -z "${AD_VIP_IPV4}" || -z "${AD_DNS_SERVER}" ]]; then
    warn "Parametros AD_* insuficientes; pulando ad_precheck_fileserver."
    return 0
  fi

  local report
  report="${LOG_DIR}/ad_setup_fileserver.report.json"
  if ! "${AD_PRECHECK_SCRIPT}" \
    --method "${AD_METHOD}" \
    --host "${AD_JUMPBOX_HOST}" \
    --user "${AD_JUMPBOX_USER}" \
    --vip "${AD_VIP_IPV4}" \
    --dns-server "${AD_DNS_SERVER}" \
    --report "${report}"; then
    warn "ad_precheck_fileserver retornou erro; revisar ${LOG_FILE}."
  else
    log "ad_precheck_fileserver executado em dry-run com sucesso."
  fi
}

show_status() {
  if [[ -f "${MARKER_FILE}" ]]; then
    printf 'completed\n'
  else
    printf 'pending\n'
  fi
}

run_auto() {
  ensure_state
  if [[ -f "${MARKER_FILE}" ]]; then
    log "First boot NAS wizard ja concluido; nenhuma acao necessaria."
    return 0
  fi

  load_defaults
  log "Iniciando first boot wizard NAS (modo auto)."

  apply_smb_template_if_missing
  run_validate_if_configured
  run_ad_precheck_if_configured

  touch "${MARKER_FILE}"
  log "First boot wizard NAS concluido."
  log "Para reexecutar: remova ${MARKER_FILE} e rode nas-firstboot-wizard.sh --auto"
}

usage() {
  cat <<'EOF'
Uso:
  nas-firstboot-wizard.sh --auto
  nas-firstboot-wizard.sh --status

Descricao:
  Orquestra bootstrap inicial NAS/SMB/AD com seguranca (dry-run por padrao no precheck AD).
EOF
}

main() {
  case "${1---auto}" in
  --auto)
    run_auto
    ;;
  --status)
    show_status
    ;;
  --help | -h)
    usage
    ;;
  *)
    usage
    return 1
    ;;
  esac
}

main "$@"
