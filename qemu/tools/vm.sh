#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# vm.sh - Gerenciador de VM para Testes da ISO
#
# Suporta boot UEFI e BIOS (Legacy).
# Requer: qemu-system-x86_64, ovmf (para UEFI)
# ==============================================================================

# Cores e Estilos (ANSI)
readonly C_RESET=$'\033[0m'
readonly C_BOLD=$'\033[1m'
readonly C_PURPLE=$'\033[38;5;105m'
readonly C_CYAN=$'\033[38;5;39m'
readonly C_GREEN=$'\033[32m'
readonly C_YELLOW=$'\033[33m'
readonly C_RED=$'\033[31m'

# Diretórios
readonly ISO_DIR="docker/dist"
readonly VM_WORK_DIR="qemu/work"
readonly VM_DISK_DIR="$VM_WORK_DIR/vm-disk"
readonly VM_UEFI_DIR="$VM_WORK_DIR/vm-uefi"
readonly VM_VIRTIOFS_DIR="$VM_WORK_DIR/vm-virtiofs"
readonly HOST_SHARE_DIR=$(pwd)

# Funções de logging estilizado
log_info() { printf "${C_CYAN}ℹ %s${C_RESET}\n" "$*"; }
log_ok() { printf "${C_GREEN}✔ %s${C_RESET}\n" "$*"; }
log_warn() { printf "${C_YELLOW}⚠ %s${C_RESET}\n" "$*"; }
log_error() { printf "${C_RED}${C_BOLD}✖ %s${C_RESET}\n" "$*"; }
log_no() { printf "${C_RED} [X] %s${C_RESET}\n" "$*"; }

# Função para detectar OVMF
find_ovmf() {
  local type=$1 # CODE ou VARS
  local paths
  [[ "$type" == "CODE" ]] && paths=(
    "/usr/share/OVMF/OVMF_CODE_4M.fd" "/usr/share/OVMF/OVMF_CODE.fd"
    "/usr/share/ovmf/OVMF.fd" "/usr/share/qemu/OVMF.fd"
  ) || paths=(
    "/usr/share/OVMF/OVMF_VARS_4M.fd" "/usr/share/OVMF/OVMF_VARS.fd"
    "/usr/share/ovmf/OVMF_VARS.fd"
  )

  for p in "${paths[@]}"; do
    [[ -f "$p" ]] && {
      echo "$p"
      return 0
    }
  done
  return 1
}

# Tenta localizar os arquivos agora
OVMF_CODE=$(find_ovmf CODE || echo "")
OVMF_VARS=$(find_ovmf VARS || echo "")

# Configurações da VM (Padrões)
readonly TEMPLATE_FILE="qemu/template-vm.json"
VM_MEMORY="4G"
VM_CPUS="2"
DISK_SIZE="20G"
VM_VGA="virtio"

function read_config() {
  if [[ -f "$TEMPLATE_FILE" ]] && command -v jq &>/dev/null; then
    log_info "Lendo configurações de $TEMPLATE_FILE..."
    local config
    config=$(cat "$TEMPLATE_FILE")
    VM_MEMORY=$(echo "$config" | jq -r '.memory // "4G"')
    VM_CPUS=$(echo "$config" | jq -r '.cpus // 2')
    DISK_SIZE=$(echo "$config" | jq -r '.disk_size // "20G"')
    VM_VGA=$(echo "$config" | jq -r '.vga_device // "virtio"')
  else
    log_warn "Usando configurações padrão (Template não encontrado ou jq ausente)."
  fi
}

function check_deps() {
  log_info "Verificando dependências..."
  local missing_pkgs=()

  command -v qemu-system-x86_64 &>/dev/null && log_ok "qemu-system-x86_64" || {
    log_no "qemu-system-x86_64"
    missing_pkgs+=("qemu-system-x86" "qemu-utils")
  }
  command -v jq &>/dev/null && log_ok "jq" || {
    log_no "jq"
    missing_pkgs+=("jq")
  }

  local vfs_bin
  vfs_bin=$(command -v virtiofsd || find /usr/lib/qemu /usr/libexec -name virtiofsd 2>/dev/null | head -n 1 || true)
  [[ -n "$vfs_bin" ]] && log_ok "virtiofsd" || {
    log_no "virtiofsd"
    missing_pkgs+=("virtiofsd")
  }

  [[ -n "$OVMF_CODE" ]] && log_ok "OVMF (UEFI)" || {
    log_no "OVMF"
    missing_pkgs+=("ovmf")
  }

  if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    log_info "Tentando instalar dependências faltantes: ${missing_pkgs[*]}"
    command -v sudo &>/dev/null || {
      log_error "sudo não encontrado. Instale manualmente: ${missing_pkgs[*]}"
      exit 1
    }
    sudo apt-get update && sudo apt-get install -y "${missing_pkgs[@]}" && log_ok "Instalação concluída!" || {
      log_error "Falha na instalação."
      exit 1
    }
  else
    log_ok "Todas as dependências satisfeitas."
  fi
}

function get_latest_iso() {
  local iso
  iso=$(ls -t "$ISO_DIR"/*.iso 2>/dev/null | head -n 1)
  [[ -z "$iso" ]] && {
    log_error "Nenhuma ISO encontrada em $ISO_DIR."
    exit 1
  }
  echo "$iso"
}

function start_vm() {
  local mode=$1
  read_config
  local iso=$(get_latest_iso)
  local disk_img="$VM_DISK_DIR/disk-1.qcow2"

  mkdir -p "$VM_DISK_DIR" "$VM_UEFI_DIR" "$VM_VIRTIOFS_DIR"
  [[ ! -f "$disk_img" ]] && {
    log_info "Criando disco virtual..."
    qemu-img create -f qcow2 "$disk_img" "$DISK_SIZE"
  }

  log_info "Iniciando VM ($mode)..."
  local qemu_args=(-enable-kvm -m "$VM_MEMORY" -smp "$VM_CPUS" -drive "file=$disk_img,format=qcow2" -cdrom "$iso" -net nic -net user -vga "$VM_VGA" -display gtk)

  # Localização do virtiofsd
  local vfs_bin
  vfs_bin=$(command -v virtiofsd || true)
  [[ -z "$vfs_bin" ]] && vfs_bin=$(find /usr/lib/qemu /usr/libexec -name virtiofsd 2>/dev/null | head -n 1 || true)

  if [[ -n "$vfs_bin" ]]; then
    local socket="$VM_VIRTIOFS_DIR/virtiofs.sock"
    rm -f "$socket" "${socket}.pid" 2>/dev/null || true
    pkill -f "virtiofsd.*$socket" 2>/dev/null || true

    log_info "Iniciando virtiofsd..."
    "$vfs_bin" --socket-path="$socket" --shared-dir="$HOST_SHARE_DIR" --sandbox none &
    VIRTIOFSD_PID=$!

    local timeout=5
    while [[ ! -S "$socket" ]] && [[ $timeout -gt 0 ]]; do
      sleep 1
      ((timeout--))
    done
    [[ -S "$socket" ]] && qemu_args+=(-chardev "socket,id=char0,path=$socket" -device "vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=hostshare" -object "memory-backend-file,id=mem,size=$VM_MEMORY,mem-path=/dev/shm,share=on" -numa "node,memdev=mem") || log_warn "virtiofsd falhou ao criar socket."
  fi

  if [[ "$mode" == "UEFI" ]]; then
    if [[ -z "$OVMF_VARS" ]]; then
      log_error "OVMF_VARS não encontrado. Certifique-se que o pacote 'ovmf' está instalado."
      exit 1
    fi
    [[ ! -f "$VM_UEFI_DIR/OVMF_VARS.fd" ]] && cp "$OVMF_VARS" "$VM_UEFI_DIR/OVMF_VARS.fd"
    qemu_args+=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" -drive "if=pflash,format=raw,file=$VM_UEFI_DIR/OVMF_VARS.fd")
  fi

  if ! qemu-system-x86_64 "${qemu_args[@]}"; then
    log_error "QEMU falhou ao iniciar. Verifique se o seu ambiente suporta aceleração KVM e interface gráfica."
    exit 1
  fi

  if [[ -n "${VIRTIOFSD_PID:-}" ]]; then
    log_info "Encerrando virtiofsd..."
    kill "$VIRTIOFSD_PID" 2>/dev/null || true
    rm -f "$socket" "${socket}.pid" 2>/dev/null || true
  fi
}

function show_help() {
  cat <<EOF
${C_BOLD}${C_PURPLE}🌌 AURORA OS - VM MANAGER${C_RESET}
${C_CYAN}Gerenciador de VM otimizado para testes de ISO${C_RESET}

${C_BOLD}Uso:${C_RESET} \$0 ${C_GREEN}[OPÇÃO]${C_RESET}

${C_BOLD}Opções:${C_RESET}
  ${C_GREEN}--check${C_RESET}        Verifica e instala dependências necessárias
  ${C_GREEN}--start-uefi${C_RESET}   Inicia a VM em modo ${C_CYAN}UEFI${C_RESET} (Recomendado)
  ${C_GREEN}--start-bios${C_RESET}   Inicia a VM em modo ${C_YELLOW}BIOS${C_RESET} (Legacy)
  ${C_GREEN}--clean${C_RESET}        Limpa discos e arquivos temporários da VM
  ${C_GREEN}--help${C_RESET}         Exibe esta ajuda

${C_PURPLE}Dica:${C_RESET} O diretório atual será montado via ${C_CYAN}virtiofs${C_RESET} com a tag ${C_BOLD}hostshare${C_RESET}.
EOF
  exit 0
}

case "${1:-}" in
  --check) check_deps ;;
  --start-uefi) start_vm "UEFI" ;;
  --start-bios) start_vm "BIOS" ;;
  --clean)
    log_info "Limpando..."
    rm -rf "$VM_WORK_DIR"
    log_ok "Concluído."
    ;;
  --help | *) show_help ;;
esac
