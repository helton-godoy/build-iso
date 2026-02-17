# Melhores Práticas para Instaladores Shell Linux

**Baseado em pesquisa de projetos estabelecidos (2026)**
*Fontes: ZFSBootMenu, bash-installer-framework, Debian d-i, Arch install scripts, openQA*

---

## 1. CHECKLIST PRÁTICO - STATE MACHINE

### 1.1 Estrutura de Estados

```bash
# Estados do instalador (persistidos em /var/tmp/installer-state/)
readonly STATE_NOT_RUN="NOT_RUN"
readonly STATE_RUNNING="RUNNING"
readonly STATE_DONE="DONE"
readonly STATE_FAILED="FAILED"
readonly STATE_ROLLBACK="ROLLBACK"

# Arquivo de estado persistente
STATE_FILE="${STATE_DIR}/installer.state"
CURRENT_STEP_FILE="${STATE_DIR}/current_step"
```

**Requisitos obrigatórios:**

- [ ] **Persistência de estado**: Estado salvo em disco (não apenas memória)
  - Permite retomar após falha/crash
  - Localização: `/var/tmp/installer-state/` ou `/run/installer/`

- [ ] **Tracking granular por step**:
  ```bash
  # Cada step tem: nome, status, timestamp, retry_count
  step_set_status "partition_disk" "RUNNING"
  step_set_status "partition_disk" "DONE"
  ```

- [ ] **Resumability**: Script pode ser re-executado e continua de onde parou
  ```bash
  # Pattern: case com fall-through para Bash 4+
  case "$(get_last_completed_step)" in
    "")
      ;&  # Fall through
    "disk_select")
      step_disk_select || handle_failure
      ;&
    "partition")
      step_partition || handle_failure
      ;&
    "zfs_create")
      step_zfs_create || handle_failure
      ;;
  esac
  ```

- [ ] **Max retry por step**: Limite de tentativas para steps falhos
  ```bash
  MAX_RETRY=3
  retry_count=$(step_get_retry "$step_name")
  if [[ $retry_count -ge $MAX_RETRY ]]; then
    log_fatal "Step $step_name falhou após $MAX_RETRY tentativas"
    exit 1
  fi
  ```

### 1.2 Transições Seguras

| De | Para | Condição |
|----|------|----------|
| NOT_RUN | RUNNING | Step iniciado |
| RUNNING | DONE | Step completou com sucesso (exit 0) |
| RUNNING | FAILED | Step falhou (exit != 0) |
| FAILED | RUNNING | Retry iniciado (incrementa contador) |
| FAILED | ROLLBACK | Max retries atingido |

**Guarda de transição obrigatória:**
```bash
transition_step() {
  local from="$1" to="$2" step="$3"
  local current=$(get_step_status "$step")
  
  if [[ "$current" != "$from" ]]; then
    log_error "Transição inválida: $step está $current, não $from"
    return 1
  fi
  
  set_step_status "$step" "$to"
}
```

---

## 2. CHECKLIST PRÁTICO - PREFLIGHT CHECKS

### 2.1 Validações de Hardware/Recursos

```bash
preflight_checks() {
  local failed=0
  
  # 1. Memória mínima (ZFS precisa de RAM)
  local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local mem_gb=$((mem_kb / 1024 / 1024))
  if [[ $mem_gb -lt 4 ]]; then
    log_error "Memória insuficiente: ${mem_gb}GB (mínimo 4GB)"
    failed=1
  fi
  
  # 2. Espaço em disco mínimo (antes de particionar)
  local disk="$TARGET_DISK"
  local size_bytes=$(blockdev --getsize64 "$disk" 2>/dev/null || echo 0)
  local size_gb=$((size_bytes / 1024 / 1024 / 1024))
  if [[ $size_gb -lt 20 ]]; then
    log_error "Disco muito pequeno: ${size_gb}GB (mínimo 20GB)"
    failed=1
  fi
  
  # 3. Arquitetura de CPU suportada
  local arch=$(uname -m)
  if [[ "$arch" != "x86_64" ]]; then
    log_error "Arquitetura não suportada: $arch (requer x86_64)"
    failed=1
  fi
  
  # 4. Virtualização detectada (warning, não erro)
  if [[ -d /sys/class/dmi/id ]]; then
    local product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")
    if [[ "$product" == *"Virtual"* ]] || [[ "$product" == *"VMware"* ]]; then
      log_warn "Ambiente virtualizado detectado: $product"
    fi
  fi
  
  # 5. Conectividade de rede (para downloads)
  if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    log_error "Sem conectividade de rede"
    failed=1
  fi
  
  # 6. Kernel com suporte a ZFS
  if ! modprobe zfs 2>/dev/null; then
    log_error "Módulo ZFS não disponível no kernel"
    failed=1
  fi
  
  # 7. Ferramentas necessárias presentes
  local required_tools=("sgdisk" "zfs" "mkfs.vfat" "debootstrap")
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      log_error "Ferramenta necessária não encontrada: $tool"
      failed=1
    fi
  done
  
  return $failed
}
```

### 2.2 Validações de Segurança

- [ ] **Verificar se está rodando como root** (ou sudo)
  ```bash
  if [[ $EUID -ne 0 ]]; then
    log_fatal "Este script deve ser executado como root"
  fi
  ```

- [ ] **Verificar se não está no sistema alvo** (evitar auto-destruição)
  ```bash
  if [[ -e /etc/zfs/zpool.cache ]] || mountpoint -q /boot/efi 2>/dev/null; then
    log_warn "Possível sistema ZFS existente detectado"
    confirm_or_abort "Continuar mesmo assim?"
  fi
  ```

- [ ] **Validar parâmetros críticos**
  ```bash
  validate_disk_exists() {
    local disk="$1"
    if [[ ! -b "$disk" ]]; then
      log_fatal "Dispositivo não existe: $disk"
    fi
    if [[ "$disk" == *"loop"* ]]; then
      log_fatal "Dispositivo loop não permitido: $disk"
    fi
  }
  ```

---

## 3. CHECKLIST PRÁTICO - ROLLBACK SAFETY

### 3.1 Estratégia de Backup Pré-Instalação

```bash
# Antes de tocar em qualquer disco, criar checkpoint
backup_partition_table() {
  local disk="$1"
  local backup_dir="${STATE_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup_dir"
  
  # Backup GPT
  if sgdisk -b "${backup_dir}/gpt_backup.bin" "$disk" 2>/dev/null; then
    log_info "Backup da tabela de partições criado"
  fi
  
  # Lista de partições existentes
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$disk" > "${backup_dir}/lsblk.txt"
  
  # ZFS pool info (se existir)
  if command -v zpool >/dev/null 2>&1; then
    zpool list 2>/dev/null > "${backup_dir}/zpool_list.txt" || true
    zpool status 2>/dev/null > "${backup_dir}/zpool_status.txt" || true
  fi
}
```

### 3.2 Cleanup Automático (Trap Pattern)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Variáveis de estado para cleanup
declare -a CLEANUP_MOUNTS=()
declare -a CLEANUP_DEVICES=()
declare -a CLEANUP_FILES=()
INSTALL_FAILED=0

cleanup() {
  local exit_code=$?
  
  log_info "Iniciando cleanup (exit code: $exit_code)..."
  
  # 1. Desmontar em ordem reversa
  for ((i=${#CLEANUP_MOUNTS[@]}-1; i>=0; i--)); do
    local mount="${CLEANUP_MOUNTS[$i]}"
    if mountpoint -q "$mount" 2>/dev/null; then
      log_info "Desmontando: $mount"
      umount -R "$mount" 2>/dev/null || true
    fi
  done
  
  # 2. Exportar pool ZFS (se importado por nós)
  if [[ "${ZFS_POOL_IMPORTED:-0}" -eq 1 ]]; then
    log_info "Exportando pool ZFS: $ZFS_POOL_NAME"
    zpool export "$ZFS_POOL_NAME" 2>/dev/null || true
  fi
  
  # 3. Fechar dispositivos loop
  for dev in "${CLEANUP_DEVICES[@]}"; do
    losetup -d "$dev" 2>/dev/null || true
  done
  
  # 4. Remover arquivos temporários
  for file in "${CLEANUP_FILES[@]}"; do
    rm -rf "$file" 2>/dev/null || true
  done
  
  # 5. Se falhou, manter logs para debug
  if [[ $exit_code -ne 0 ]] || [[ "$INSTALL_FAILED" -eq 1 ]]; then
    log_error "Instalação falhou. Logs preservados em: ${STATE_DIR}"
    # Compactar logs para análise posterior
    tar czf "${STATE_DIR}/failure-logs-$(date +%Y%m%d_%H%M%S).tar.gz" \
      -C "$STATE_DIR" . 2>/dev/null || true
  fi
  
  exit $exit_code
}

trap cleanup EXIT INT TERM

# Helper para registrar recursos
register_mount() { CLEANUP_MOUNTS+=("$1"); }
register_device() { CLEANUP_DEVICES+=("$1"); }
register_temp_file() { CLEANUP_FILES+=("$1"); }
```

### 3.3 Rollback de Steps Específicos

```bash
rollback_step() {
  local step="$1"
  log_warn "Executando rollback para step: $step"
  
  case "$step" in
    "zfs_create")
      # Destruir pool se foi criado
      if zpool list "$ZFS_POOL_NAME" >/dev/null 2>&1; then
        log_info "Destruindo pool ZFS criado: $ZFS_POOL_NAME"
        zpool destroy "$ZFS_POOL_NAME" 2>/dev/null || true
      fi
      ;;
      
    "partition")
      # Restaurar tabela de partições do backup
      local backup="${STATE_DIR}/backups/latest/gpt_backup.bin"
      if [[ -f "$backup" ]]; then
        log_info "Restaurando tabela de partições do backup"
        sgdisk -l "$backup" "$TARGET_DISK" 2>/dev/null || true
      fi
      ;;
      
    "mount")
      # Desmontar tudo
      for mount in /target/boot/efi /target/proc /target/sys /target/dev /target; do
        umount -R "$mount" 2>/dev/null || true
      done
      ;;
  esac
}
```

---

## 4. CHECKLIST PRÁTICO - LOGGING E DIAGNÓSTICOS

### 4.1 Sistema de Logging Estruturado (baseado em ZFSBootMenu)

```bash
#!/usr/bin/env bash

# Níveis de log (syslog-style)
readonly LOG_EMERG=0
readonly LOG_ALERT=1
readonly LOG_CRIT=2
readonly LOG_ERR=3
readonly LOG_WARNING=4
readonly LOG_NOTICE=5
readonly LOG_INFO=6
readonly LOG_DEBUG=7

# Nível atual (pode ser sobrescrito)
: "${INSTALL_LOG_LEVEL:=6}"

# Arquivos de log
INSTALL_LOG_FILE="${STATE_DIR}/install.log"
INSTALL_DEBUG_LOG="${STATE_DIR}/debug.log"

# Criar diretório de log
mkdir -p "$(dirname "$INSTALL_LOG_FILE")"

# Função de log principal
log_msg() {
  local level="$1"
  local msg="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local caller="${FUNCNAME[1]:-main}"
  local line="${BASH_LINENO[0]:-0}"
  
  # Formato estruturado
  local logline="[${timestamp}] [${caller}:${line}] [LEVEL:${level}] ${msg}"
  
  # Sempre salvar em arquivo
  echo "$logline" >> "$INSTALL_LOG_FILE"
  
  # Também logar em debug.log se nível >= DEBUG
  if [[ "$level" -le $LOG_DEBUG ]]; then
    echo "$logline" >> "$INSTALL_DEBUG_LOG"
  fi
  
  # Output para console baseado em nível
  if [[ "$level" -le $INSTALL_LOG_LEVEL ]]; then
    case "$level" in
      $LOG_EMERG|$LOG_ALERT|$LOG_CRIT|$LOG_ERR)
        echo -e "\033[31m[ERRO]\033[0m $msg" >&2
        ;;
      $LOG_WARNING)
        echo -e "\033[33m[AVISO]\033[0m $msg" >&2
        ;;
      $LOG_NOTICE)
        echo -e "\033[34m[NOTA]\033[0m $msg"
        ;;
      $LOG_INFO)
        echo -e "\033[32m[INFO]\033[0m $msg"
        ;;
      $LOG_DEBUG)
        echo -e "\033[90m[DEBUG]\033[0m $msg"
        ;;
    esac
  fi
  
  # Logar no kernel (para debug de boot)
  if [[ "$level" -le $LOG_ERR ]]; then
    echo "<${level}>Installer: $msg" > /dev/kmsg 2>/dev/null || true
  fi
}

# Helpers de conveniência
log_fatal() { log_msg $LOG_EMERG "$1"; exit 1; }
log_error() { log_msg $LOG_ERR "$1"; }
log_warn() { log_msg $LOG_WARNING "$1"; }
log_notice() { log_msg $LOG_NOTICE "$1"; }
log_info() { log_msg $LOG_INFO "$1"; }
log_debug() { log_msg $LOG_DEBUG "$1"; }

# Log de comandos executados (set -x style)
log_command() {
  local cmd="$*"
  log_debug "Executando: $cmd"
  
  local output
  local exit_code
  
  # Executar e capturar output
  output=$("$@" 2>&1)
  exit_code=$?
  
  # Logar output em debug
  if [[ -n "$output" ]]; then
    log_debug "Output: $output"
  fi
  
  if [[ $exit_code -ne 0 ]]; then
    log_error "Comando falhou (exit $exit_code): $cmd"
    log_error "Output: $output"
  fi
  
  return $exit_code
}
```

### 4.2 Captura de Diagnósticos em Falha

```bash
capture_diagnostics() {
  local diag_dir="${STATE_DIR}/diagnostics"
  mkdir -p "$diag_dir"
  
  log_info "Capturando diagnósticos em: $diag_dir"
  
  # Informações do sistema
  uname -a > "${diag_dir}/uname.txt" 2>/dev/null || true
  cat /proc/cmdline > "${diag_dir}/cmdline.txt" 2>/dev/null || true
  cat /proc/meminfo > "${diag_dir}/meminfo.txt" 2>/dev/null || true
  lscpu > "${diag_dir}/lscpu.txt" 2>/dev/null || true
  
  # Informações de disco
  lsblk -f > "${diag_dir}/lsblk.txt" 2>/dev/null || true
  fdisk -l > "${diag_dir}/fdisk.txt" 2>/dev/null || true
  
  # Informações ZFS
  if command -v zpool >/dev/null 2>&1; then
    zpool list > "${diag_dir}/zpool_list.txt" 2>/dev/null || true
    zpool status -v > "${diag_dir}/zpool_status.txt" 2>/dev/null || true
    zpool history > "${diag_dir}/zpool_history.txt" 2>/dev/null || true
    zfs list -t all > "${diag_dir}/zfs_list.txt" 2>/dev/null || true
    zfs get all > "${diag_dir}/zfs_get.txt" 2>/dev/null || true
  fi
  
  # Logs do kernel (últimas 1000 linhas)
  dmesg | tail -n 1000 > "${diag_dir}/dmesg.txt" 2>/dev/null || true
  
  # Estado do sistema de arquivos
  mount > "${diag_dir}/mount.txt" 2>/dev/null || true
  cat /proc/mounts > "${diag_dir}/proc_mounts.txt" 2>/dev/null || true
  
  # Estado da instalação
  if [[ -f "$STATE_FILE" ]]; then
    cp "$STATE_FILE" "${diag_dir}/installer.state"
  fi
  
  # Compactar tudo
  local archive="${STATE_DIR}/diagnostics-$(date +%Y%m%d_%H%M%S).tar.gz"
  tar czf "$archive" -C "$diag_dir" . 2>/dev/null || true
  
  log_info "Diagnósticos salvos em: $archive"
}

# Chamar em caso de falha
handle_failure() {
  local exit_code=$?
  INSTALL_FAILED=1
  
  log_error "Instalação falhou com código: $exit_code"
  capture_diagnostics
  
  # Oferecer shell de debug
  if [[ "${INSTALL_DEBUG_ON_FAILURE:-0}" -eq 1 ]]; then
    log_warn "Abrindo shell de debug..."
    /bin/bash
  fi
  
  exit $exit_code
}

trap handle_failure ERR
```

---

## 5. ANTI-PADRÕES QUE CAUSAM FALHAS REPETIDAS

### ❌ ANTI-PADRÃO 1: Não validar pré-condições

```bash
# RUIM: Assumir que o comando vai funcionar
mkfs.vfat /dev/sda1

# BOM: Verificar primeiro
if [[ ! -b /dev/sda1 ]]; then
  log_fatal "Partição /dev/sda1 não existe"
fi
mkfs.vfat /dev/sda1 || log_fatal "Falha ao criar filesystem"
```

### ❌ ANTI-PADRÃO 2: Não usar `set -euo pipefail`

```bash
# RUIM: Script continua mesmo com erro
#!/bin/bash
rm -rf /important/data
mkdir /new/dir
# Se rm falhar, mkdir ainda executa (perigoso!)

# BOM: Falha rápido
#!/usr/bin/env bash
set -euo pipefail
rm -rf /important/data
mkdir /new/dir
# Se rm falhar, script para imediatamente
```

### ❌ ANTI-PADRÃO 3: Cleanup inadequado

```bash
# RUIM: Sem trap de cleanup
mount /dev/sda1 /mnt
chroot /mnt /install.sh
umount /mnt  # Se chroot falhar, isso não executa

# BOM: Trap garante cleanup
cleanup() {
  umount -R /mnt 2>/dev/null || true
}
trap cleanup EXIT
mount /dev/sda1 /mnt
chroot /mnt /install.sh
```

### ❌ ANTI-PADRÃO 4: Logs insuficientes

```bash
# RUIM: Sem contexto
apt-get install zfsutils-linux
# "Falhou, mas por quê?"

# BOM: Log detalhado
log_info "Instalando pacotes ZFS..."
if ! apt-get install -y zfsutils-linux 2>&1 | tee -a "$INSTALL_LOG_FILE"; then
  log_error "Falha ao instalar zfsutils-linux"
  log_error "APT sources: $(cat /etc/apt/sources.list)"
  apt-cache policy zfsutils-linux >> "$INSTALL_LOG_FILE" 2>&1 || true
  exit 1
fi
```

### ❌ ANTI-PADRÃO 5: Assumir paths de dispositivo

```bash
# RUIM: Hardcode de device
DISK="/dev/sda"

# BOM: Detecção dinâmica com validação
select_disk() {
  local disks=($(lsblk -dn -o NAME | grep -E '^[sh]d|^nvme'))
  if [[ ${#disks[@]} -eq 0 ]]; then
    log_fatal "Nenhum disco detectado"
  fi
  # ... lógica de seleção ...
}
```

### ❌ ANTI-PADRÃO 6: Não verificar espaço livre

```bash
# RUIM: Assumir que tem espaço suficiente
dd if=/dev/zero of=/mnt/swapfile bs=1G count=8

# BOM: Verificar primeiro
REQUIRED_SPACE=$((8 * 1024 * 1024 * 1024))  # 8GB
AVAILABLE=$(df -B1 /mnt | awk 'NR==2 {print $4}')
if [[ $AVAILABLE -lt $REQUIRED_SPACE ]]; then
  log_fatal "Espaço insuficiente: $(($AVAILABLE/1024/1024/1024))GB disponível, 8GB necessário"
fi
```

### ❌ ANTI-PADRÃO 7: Instalação não-idempotente

```bash
# RUIM: Falha se já existe
zpool create zroot /dev/sda2

# BOM: Verificar antes ou usar -f quando apropriado
if ! zpool list zroot >/dev/null 2>&1; then
  zpool create zroot /dev/sda2
else
  log_warn "Pool zroot já existe, pulando criação"
fi
```

### ❌ ANTI-PADRÃO 8: Não validar assinaturas/checksums

```bash
# RUIM: Download sem verificação
curl -L -o zbm.efi "https://get.zfsbootmenu.org/efi"
cp zbm.efi /boot/efi/EFI/zbm.efi

# BOM: Verificar checksum
ZBM_CHECKSUM="abc123..."
curl -L -o zbm.efi "https://get.zfsbootmenu.org/efi"
if ! echo "$ZBM_CHECKSUM  zbm.efi" | sha256sum -c -; then
  log_fatal "Checksum inválido para ZFSBootMenu"
fi
```

---

## 6. ESTRATÉGIA DE TESTE COM VM (KVM/QEMU)

### 6.1 Script de Teste Automatizado

```bash
#!/usr/bin/env bash
# test-installer.sh - Testa o instalador em VMs

set -euo pipefail

readonly ISO_PATH="${1:-./build/debian-live-amd64.hybrid.iso}"
readonly TEST_RESULTS="./test-results"
readonly TEST_TIMEOUT=1800  # 30 minutos

# Criar diretório de resultados
mkdir -p "$TEST_RESULTS"

# Função para rodar teste em VM
run_vm_test() {
  local firmware="$1"  # uefi ou bios
  local test_name="$2"
  local disk_file="${TEST_RESULTS}/${test_name}.qcow2"
  local log_file="${TEST_RESULTS}/${test_name}.log"
  
  log_info "Iniciando teste: $test_name"
  
  # Criar disco virtual
  qemu-img create -f qcow2 "$disk_file" 32G
  
  # Preparar args do QEMU
  local qemu_args=(
    -m 4096
    -smp 2
    -enable-kvm
    -cdrom "$ISO_PATH"
    -drive "file=${disk_file},format=qcow2,if=virtio"
    -serial "file:${log_file}"
    -nographic
    -boot d
    -no-reboot
  )
  
  # Adicionar firmware específico
  if [[ "$firmware" == "uefi" ]]; then
    qemu_args+=(-bios /usr/share/ovmf/OVMF.fd)
  fi
  
  # Executar VM com timeout
  if timeout "$TEST_TIMEOUT" qemu-system-x86_64 "${qemu_args[@]}"; then
    log_info "✓ Teste $test_name: SUCESSO"
    echo "PASS" > "${TEST_RESULTS}/${test_name}.result"
  else
    log_error "✗ Teste $test_name: FALHA (exit code: $?)"
    echo "FAIL" > "${TEST_RESULTS}/${test_name}.result"
    return 1
  fi
}

# Testes
log_info "=== Iniciando Suite de Testes ==="

run_vm_test "bios" "install-bios" || true
run_vm_test "uefi" "install-uefi" || true

# Sumário
echo ""
echo "=== Resultados ==="
for result in "$TEST_RESULTS"/*.result; do
  if [[ -f "$result" ]]; then
    cat "$result"
  fi
done
```

### 6.2 Validações Pós-Instalação

```bash
#!/usr/bin/env bash
# validate-install.sh - Roda dentro da VM para validar instalação

validate_installation() {
  local failed=0
  
  echo "=== Validação Pós-Instalação ==="
  
  # 1. Verificar se bootou do disco (não ISO)
  if mountpoint -q /run/live/medium 2>/dev/null; then
    echo "❌ ERRO: Ainda em modo live"
    failed=1
  else
    echo "✓ Não está em modo live"
  fi
  
  # 2. Verificar ZFS pool
  if zpool list zroot >/dev/null 2>&1; then
    echo "✓ Pool ZFS 'zroot' existe"
  else
    echo "❌ ERRO: Pool 'zroot' não encontrado"
    failed=1
  fi
  
  # 3. Verificar datasets
  local required_datasets=("ROOT" "home" "var")
  for ds in "${required_datasets[@]}"; do
    if zfs list "zroot/${ds}" >/dev/null 2>&1; then
      echo "✓ Dataset zroot/${ds} existe"
    else
      echo "❌ ERRO: Dataset zroot/${ds} não encontrado"
      failed=1
    fi
  done
  
  # 4. Verificar EFI bootloader
  if [[ -f /boot/efi/EFI/zbm/zfsbootmenu.efi ]]; then
    echo "✓ ZFSBootMenu EFI presente"
  else
    echo "❌ ERRO: ZFSBootMenu EFI não encontrado"
    failed=1
  fi
  
  # 5. Verificar kernel
  if [[ -f /boot/vmlinuz-* ]]; then
    echo "✓ Kernel instalado"
  else
    echo "❌ ERRO: Kernel não encontrado"
    failed=1
  fi
  
  # 6. Verificar initramfs com ZFS
  if lsinitramfs /boot/initrd.img-* 2>/dev/null | grep -q zfs; then
    echo "✓ ZFS no initramfs"
  else
    echo "❌ ERRO: ZFS não encontrado no initramfs"
    failed=1
  fi
  
  # 7. Verificar fstab
  if grep -q "zfs" /etc/fstab 2>/dev/null || zfs get mountpoint zroot/ROOT/debian >/dev/null 2>&1; then
    echo "✓ Configuração de mountpoint ZFS presente"
  else
    echo "❌ ERRO: Configuração de mountpoint não encontrada"
    failed=1
  fi
  
  return $failed
}

# Executar validação
if validate_installation; then
  echo ""
  echo "✅ TODAS AS VALIDAÇÕES PASSARAM"
  exit 0
else
  echo ""
  echo "❌ ALGUMAS VALIDAÇÕES FALHARAM"
  exit 1
fi
```

### 6.3 Integração com CI

```yaml
# .github/workflows/test-installer.yml
name: Test Installer

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test-installer:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y qemu-system-x86 qemu-utils ovmf
      
      - name: Build ISO
        run: |
          make build-iso
      
      - name: Run VM tests
        run: |
          ./test-installer.sh ./build/*.iso
      
      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: test-results/
          retention-days: 7
```

---

## 7. REFERÊNCIAS

### Documentação Oficial

1. **Debian Installer Internals**: https://d-i.debian.org/doc/internals/
2. **ZFSBootMenu Documentation**: https://docs.zfsbootmenu.org/
3. **Arch Linux Install Guide**: https://wiki.archlinux.org/title/Installation_guide
4. **OpenZFS Best Practices**: https://openzfs.github.io/openzfs-docs/

### Projetos de Referência

1. **bash-installer-framework** (projectivetech): Framework de state machine
   - https://github.com/projectivetech/bash-installer-framework

2. **ZFSBootMenu** (zbm-dev): Logging e tratamento de erros
   - https://github.com/zbm-dev/zfsbootmenu

3. **zfsbootmenu-autoinstaller** (NLaundry): Automação de instalação ZFS
   - https://github.com/NLaundry/zfsbootmenu-autoinstaller

4. **openQA** (os-autoinst): Test automation para OS
   - https://open.qa/docs

---

## 8. CHECKLIST MÍNIMO PARA PRODUÇÃO

Antes de marcar o instalador como pronto para produção, verifique:

- [ ] `set -euo pipefail` presente no início
- [ ] Trap de cleanup registrado
- [ ] Preflight checks implementados
- [ ] State machine com persistência em disco
- [ ] Logging estruturado em arquivo
- [ ] Captura de diagnósticos em falha
- [ ] Rollback implementado para steps críticos
- [ ] Validação de parâmetros de entrada
- [ ] Verificação de pré-condições (memória, disco, ferramentas)
- [ ] Testes em VM BIOS passando
- [ ] Testes em VM UEFI passando
- [ ] Teste de retry/resumability funcionando
- [ ] Documentação de troubleshooting

---

*Documento gerado em 2026-02-15 - Aplicável ao projeto build-iso*
