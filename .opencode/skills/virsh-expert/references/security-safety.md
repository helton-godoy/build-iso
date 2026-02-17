# Segurança e Proteção para Agentes LLM

Referência de regras de segurança, mitigações e boas práticas para operações virsh executadas por agentes LLM autônomos.

## Modelo de Ameaça

Um agente LLM que executa comandos virsh pode:

1. **Destruir VMs** fora do escopo do projeto
2. **Executar código malicioso** dentro das VMs via guest-exec
3. **Acessar credenciais** do host (chaves SSH, tokens, .env)
4. **Escalar privilégios** usando permissões do grupo libvirt
5. **Causar DoS** criando VMs ou discos excessivos

## Regras Obrigatórias

### 1. Escopo de VMs — Prefixo Obrigatório

O agente **só pode operar** em VMs com prefixo `nas-test-`:

```bash
validate_vm_name() {
  local vm_name="$1"

  if [[ ! "$vm_name" =~ ^nas-test- ]]; then
    echo "❌ BLOQUEADO: VM '$vm_name' está fora do escopo permitido (prefixo: nas-test-)" >&2
    return 1
  fi
  return 0
}

# Uso obrigatório antes de qualquer operação
validate_vm_name "$VM_NAME" || exit 1
```

### 2. Blocklist de Comandos Perigosos

Comandos que **nunca devem ser executados**, nem dentro das VMs:

| Comando                                          | Risco                          |
| ------------------------------------------------ | ------------------------------ |
| `rm -rf /`                                       | Destruição total do filesystem |
| `dd if=/dev/zero of=/dev/sd*`                    | Sobrescrever discos do host    |
| `shutdown -h now` (no host)                      | Desligar o servidor físico     |
| `virsh destroy` (VMs externas)                   | Destruir VMs de produção       |
| `virsh undefine --remove-all-storage` (externas) | Apagar dados persistentes      |
| `mkfs.*` (em discos do host)                     | Formatar partições do host     |
| `:(){:\|:&};:`                                   | Fork bomb                      |

```bash
# Blocklist de padrões perigosos para guest-exec
BLOCKED_PATTERNS=(
  "rm -rf /"
  "dd if=/dev/zero"
  "mkfs"
  "shutdown"
  "reboot"  # do host — dentro da VM é OK
  "fork bomb"
)

check_command_safety() {
  local cmd="$1"

  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if [[ "$cmd" == *"$pattern"* ]]; then
      echo "❌ BLOQUEADO: Comando contém padrão perigoso: '$pattern'" >&2
      return 1
    fi
  done
  return 0
}
```

### 3. Sanitização de Entrada

```bash
sanitize_vm_name() {
  local name="$1"

  # Permitir apenas alfanuméricos, hifens e underscores
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ Nome de VM inválido: '$name' (apenas [a-zA-Z0-9_-])" >&2
    return 1
  fi

  # Tamanho máximo
  if (( ${#name} > 64 )); then
    echo "❌ Nome de VM muito longo (máx 64 chars)" >&2
    return 1
  fi

  return 0
}

sanitize_file_path() {
  local path="$1"

  # Bloquear traversal de diretório
  if [[ "$path" == *".."* ]]; then
    echo "❌ Path traversal detectado: '$path'" >&2
    return 1
  fi

  # Bloquear paths absolutos fora do projeto
  if [[ "$path" == /* && "$path" != */scripts/vm/* ]]; then
    echo "❌ Path fora do diretório do projeto: '$path'" >&2
    return 1
  fi

  return 0
}
```

### 4. Princípio do Menor Privilégio

```bash
# ✅ CORRETO: Usar grupo libvirt (não root)
virsh --connect qemu:///system list --all

# ❌ ERRADO: Usar sudo desnecessariamente
sudo virsh list --all

# Verificar permissões do usuário
groups | grep -qw libvirt || {
  echo "⚠️ Usuário não está no grupo libvirt"
  echo "Execute: sudo usermod -aG libvirt $USER && newgrp libvirt"
  exit 1
}
```

### 5. Timeouts em Operações

```bash
# Sempre usar timeout para operações que podem travar
timeout 30 virsh domifaddr nas-test-uefi

# Timeout para guest-exec (agente pode não responder)
timeout 10 virsh qemu-agent-command nas-test-uefi '{"execute": "guest-ping"}'

# Timeout para SSH
ssh -o ConnectTimeout=5 -o BatchMode=yes root@192.168.122.45 "echo ok"
```

### 6. Kill Switch — Fusível de Segurança

```bash
emergency_stop() {
  echo "🚨 EMERGENCY STOP: Destruindo todas as VMs do projeto..."
  for vm in $(virsh list --state-running --name | grep "^nas-test-"); do
    virsh destroy "$vm" 2>/dev/null || true
    echo "  Destruída: $vm"
  done
}

# Registrar como trap para falhas catastróficas
# trap emergency_stop ERR  # Use com cautela
```

### 7. Logging e Auditoria

```bash
LOG_FILE="/tmp/virsh-agent-audit-$(date +%Y%m%d).log"

audit_log() {
  local action="$1"
  local vm_name="$2"
  local details="${3:-}"

  printf '[%s] ACTION=%s VM=%s USER=%s DETAILS="%s"\n' \
    "$(date -Iseconds)" "$action" "$vm_name" "$(whoami)" "$details" \
    >> "$LOG_FILE"
}

# Uso
audit_log "START" "nas-test-uefi" "virt-install com ISO"
audit_log "EXEC" "nas-test-uefi" "CMD: zpool status"
audit_log "DESTROY" "nas-test-uefi" "Cleanup pós-teste"
```

## Whitelist de Executáveis (guest-exec)

Para `qemu-agent-command guest-exec`, restringir paths executáveis:

```bash
ALLOWED_EXEC_PATHS=(
  "/usr/bin/hostname"
  "/usr/bin/uname"
  "/usr/bin/lsblk"
  "/usr/bin/free"
  "/usr/bin/df"
  "/usr/bin/cat"
  "/usr/bin/ls"
  "/usr/bin/id"
  "/usr/sbin/zpool"
  "/usr/sbin/zfs"
  "/usr/bin/systemctl"
  "/usr/bin/journalctl"
  "/usr/sbin/lspci"
  "/usr/sbin/ip"
)

validate_exec_path() {
  local exec_path="$1"

  for allowed in "${ALLOWED_EXEC_PATHS[@]}"; do
    if [[ "$exec_path" == "$allowed" ]]; then
      return 0
    fi
  done

  echo "❌ BLOQUEADO: Executável '$exec_path' não está na whitelist" >&2
  return 1
}
```

## Limites de Recursos

```bash
# Limite de VMs simultâneas do projeto
MAX_PROJECT_VMS=4

check_vm_limit() {
  local running
  running=$(virsh list --state-running --name | grep -c "^nas-test-" || true)

  if (( running >= MAX_PROJECT_VMS )); then
    echo "❌ Limite de VMs atingido: $running/$MAX_PROJECT_VMS" >&2
    return 1
  fi
  return 0
}

# Limite de discos criados
MAX_DISK_SIZE_GB=50
MAX_TOTAL_DISKS=20

check_disk_limit() {
  local disk_count
  disk_count=$(find scripts/vm/disks -name "*.qcow2" 2>/dev/null | wc -l)

  if (( disk_count >= MAX_TOTAL_DISKS )); then
    echo "❌ Limite de discos atingido: $disk_count/$MAX_TOTAL_DISKS" >&2
    return 1
  fi
  return 0
}
```

## Checklist de Segurança para Novas Operações

Antes de adicionar qualquer nova operação virsh ao agente:

- [ ] O comando opera apenas em VMs `nas-test-*`?
- [ ] Entradas são sanitizadas (nomes, paths, parâmetros)?
- [ ] Há timeout configurado?
- [ ] O comando está logado no audit trail?
- [ ] O comando está na blocklist de padrões perigosos?
- [ ] O princípio do menor privilégio é respeitado?
- [ ] Há fallback/recovery em caso de falha?
