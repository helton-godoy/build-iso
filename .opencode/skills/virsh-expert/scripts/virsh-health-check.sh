#!/usr/bin/env bash
# =============================================================================
# virsh-health-check.sh — Diagnóstico rápido das VMs do projeto build-iso
# =============================================================================
# Verifica estado, IP, recursos e conectividade de todas as VMs do projeto.
# Segue padrões shell-gum-elite (set -euo pipefail, gum para UX).
# =============================================================================
set -euo pipefail

# shellcheck disable=SC2034
SCRIPT_NAME="${0##*/}"

# --- Constantes do projeto ---
VM_PREFIX="nas-test-"
PROJECT_VMS=("nas-test-uefi" "nas-test-bios" "disk-boot-uefi" "disk-boot-bios")
SOCKET_DIR="/tmp"

# --- Cores (fallback sem gum) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# --- Detecção de ferramentas ---
HAS_GUM=false
command -v gum >/dev/null 2>&1 && HAS_GUM=true

HAS_VIRSH=false
command -v virsh >/dev/null 2>&1 && HAS_VIRSH=true

# --- Funções de logging ---
log_info() {
  if [[ "$HAS_GUM" == "true" ]]; then
    gum log --level info -- "$1"
  else
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
  fi
}

log_warn() {
  if [[ "$HAS_GUM" == "true" ]]; then
    gum log --level warn -- "$1"
  else
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
  fi
}

log_error() {
  if [[ "$HAS_GUM" == "true" ]]; then
    gum log --level error -- "$1"
  else
    printf "${RED}[ERR]${NC} %s\n" "$1"
  fi
}

# --- Funções de diagnóstico ---

check_prerequisites() {
  log_info "Verificando pré-requisitos..."

  local missing=0

  for cmd in virsh virt-install qemu-img; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "  ✅ %s encontrado\n" "$cmd"
    else
      printf "  ❌ %s NÃO encontrado\n" "$cmd"
      missing=$((missing + 1))
    fi
  done

  # Verificar grupo libvirt
  if groups 2>/dev/null | grep -qw libvirt; then
    printf "  ✅ Usuário no grupo libvirt\n"
  else
    printf "  ⚠️  Usuário NÃO está no grupo libvirt\n"
    missing=$((missing + 1))
  fi

  # Verificar serviço libvirtd
  if systemctl is-active --quiet libvirtd 2>/dev/null; then
    printf "  ✅ libvirtd ativo\n"
  else
    printf "  ❌ libvirtd NÃO está ativo\n"
    missing=$((missing + 1))
  fi

  return "$missing"
}

check_vm_state() {
  local vm_name="$1"
  local state=""

  state=$(virsh domstate "$vm_name" 2>/dev/null) || state="não definida"

  case "$state" in
  running)
    printf "  ${GREEN}●${NC} %-25s ${GREEN}%s${NC}" "$vm_name" "$state"
    ;;
  "shut off")
    printf "  ${YELLOW}○${NC} %-25s ${YELLOW}%s${NC}" "$vm_name" "$state"
    ;;
  paused)
    printf "  ${BLUE}◐${NC} %-25s ${BLUE}%s${NC}" "$vm_name" "$state"
    ;;
  "não definida")
    printf "  ${RED}✕${NC} %-25s ${RED}%s${NC}" "$vm_name" "$state"
    ;;
  *)
    printf "  ? %-25s %s" "$vm_name" "$state"
    ;;
  esac
}

check_vm_ip() {
  local vm_name="$1"
  local ip=""

  ip=$(virsh domifaddr "$vm_name" 2>/dev/null |
    awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}')

  if [[ -n "$ip" ]]; then
    printf "  IP: %s" "$ip"
  else
    printf "  IP: n/a"
  fi
}

check_vm_resources() {
  local vm_name="$1"
  local info=""

  info=$(virsh dominfo "$vm_name" 2>/dev/null) || return 0

  local cpus mem_used
  cpus=$(printf '%s\n' "$info" | awk -F: '/^CPU\(s\)/ {gsub(/^ +/, "", $2); print $2}')
  mem_used=$(printf '%s\n' "$info" | awk -F: '/^Used memory/ {gsub(/^ +| KiB/, "", $2); print $2}')

  if [[ -n "$mem_used" ]]; then
    local mem_mb=$((mem_used / 1024))
    printf "  CPU: %s  RAM: %sMB" "${cpus:-?}" "$mem_mb"
  fi
}

check_socket() {
  local vm_name="$1"
  local socket_path="${SOCKET_DIR}/${vm_name}.sock"

  if [[ -S "$socket_path" ]]; then
    printf "  Socket: ✅"
  else
    printf "  Socket: ❌"
  fi
}

check_ssh_connectivity() {
  local vm_name="$1"
  local ip=""

  ip=$(virsh domifaddr "$vm_name" 2>/dev/null |
    awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}')

  if [[ -z "$ip" ]]; then
    printf "  SSH: n/a"
    return
  fi

  if timeout 3 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
    "root@${ip}" "exit" >/dev/null 2>&1; then
    printf "  SSH: ✅"
  else
    printf "  SSH: ❌"
  fi
}

# --- Exibição ---

print_header() {
  if [[ "$HAS_GUM" == "true" ]]; then
    gum style \
      --border double \
      --border-foreground "#8ECAE6" \
      --padding "0 2" \
      --margin "1 0" \
      "🏥 Virsh Health Check — Projeto build-iso"
  else
    echo ""
    printf '%b════════════════════════════════════════════════════%b\n' "$BOLD" "$NC"
    printf '%b  🏥 Virsh Health Check — Projeto build-iso%b\n' "$BOLD" "$NC"
    printf '%b════════════════════════════════════════════════════%b\n' "$BOLD" "$NC"
    echo ""
  fi
}

print_section() {
  local title="$1"
  echo ""
  printf "${BOLD}── %s ──${NC}\n" "$title"
}

# --- Main ---

main() {
  if [[ "$HAS_VIRSH" != "true" ]]; then
    log_error "virsh não encontrado. Instale: sudo apt install libvirt-daemon-system"
    exit 127
  fi

  print_header

  # Pré-requisitos
  print_section "Pré-requisitos"
  check_prerequisites || true

  # Rede libvirt
  print_section "Rede Libvirt"
  local net_status
  net_status=$(virsh net-list --all 2>/dev/null | grep -w default | awk '{print $2}') || net_status="?"
  printf "  Rede default: %s\n" "${net_status:-não encontrada}"

  # VMs do projeto
  print_section "VMs do Projeto"

  for vm_name in "${PROJECT_VMS[@]}"; do
    local state
    state=$(virsh domstate "$vm_name" 2>/dev/null) || state="não definida"

    check_vm_state "$vm_name"

    if [[ "$state" == "running" ]]; then
      check_vm_ip "$vm_name"
      check_vm_resources "$vm_name"
      check_socket "$vm_name"
      check_ssh_connectivity "$vm_name"
    fi

    echo ""
  done

  # Outras VMs (fora do projeto)
  local other_vms
  other_vms=$(virsh list --all --name 2>/dev/null | grep -v "^$" | grep -v "^${VM_PREFIX}" || true)

  if [[ -n "$other_vms" ]]; then
    print_section "Outras VMs (fora do escopo)"
    while IFS= read -r vm; do
      printf "  ⚠️  %s (estado: %s)\n" "$vm" "$(virsh domstate "$vm" 2>/dev/null || echo '?')"
    done <<<"$other_vms"
  fi

  # Cache de IPs
  local cache_file="scripts/vm/.cache/vm-ips.env"
  if [[ -f "$cache_file" ]]; then
    print_section "Cache de IPs"
    while IFS= read -r line; do
      [[ -n "$line" ]] && printf "  %s\n" "$line"
    done <"$cache_file"
  fi

  echo ""
  log_info "Diagnóstico concluído."
}

main "$@"
