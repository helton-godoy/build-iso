# Detecção de Rede e IP

Referência para descobrir endereços IP e configurações de rede de VMs gerenciadas por libvirt.

## Estratégia de Detecção do Projeto

O projeto usa uma estratégia em cascata (fast-path → fallback):

```
1. virsh domifaddr (rápido, requer guest-agent ou DHCP lease recente)
   ↓ falha
2. virsh domiflist + virsh net-dhcp-leases (match por MAC)
   ↓ falha
3. Cache local em scripts/vm/.cache/vm-ips.env
```

## Fast Path: virsh domifaddr

```bash
# Obter IP da VM (método mais rápido)
virsh domifaddr nas-test-uefi

# Parse para extrair apenas o IP (sem máscara)
virsh domifaddr nas-test-uefi | awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}'
```

### Variantes

```bash
# Via guest-agent (mais preciso, requer agente instalado)
virsh domifaddr --source agent nas-test-uefi

# Via DHCP lease (não requer agente)
virsh domifaddr --source lease nas-test-uefi
```

## Fallback: MAC Matching via DHCP Leases

Quando `domifaddr` não retorna resultado:

```bash
# 1. Obter rede da VM
NETWORK=$(virsh domiflist nas-test-uefi | awk '$2=="network" && $3!="--" {print $3; exit}')

# 2. Obter MAC da VM
VM_MAC=$(virsh domiflist nas-test-uefi | awk '$2=="network" && $5!="" {print tolower($5); exit}')

# 3. Buscar IP nos leases DHCP
virsh net-dhcp-leases "$NETWORK" | awk -v mac="$VM_MAC" 'tolower($2)==mac {sub(/\/.*/, "", $5); print $5; exit}'
```

## Função Completa de Detecção (Padrão do Projeto)

```bash
detect_vm_ip() {
  local vm_name="$1"
  local max_attempts="${2:-6}"
  local sleep_seconds="${3:-1}"
  local attempt=1
  local ip=""

  while (( attempt <= max_attempts )); do
    # Tentativa 1: domifaddr direto
    ip=$(virsh domifaddr "$vm_name" 2>/dev/null \
      | awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}')

    if [[ -n "$ip" ]]; then
      printf '%s\n' "$ip"
      return 0
    fi

    # Tentativa 2: DHCP lease matching
    local network
    network=$(virsh domiflist "$vm_name" 2>/dev/null \
      | awk '$2=="network" && $3!="--" {print $3; exit}')

    if [[ -n "$network" ]]; then
      local vm_mac
      vm_mac=$(virsh domiflist "$vm_name" 2>/dev/null \
        | awk '$2=="network" && $5!="" {print tolower($5); exit}')

      if [[ -n "$vm_mac" ]]; then
        local leases
        leases=$(virsh net-dhcp-leases "$network" 2>/dev/null || true)
        ip=$(printf '%s\n' "$leases" \
          | awk -v mac="$vm_mac" 'tolower($2)==mac {sub(/\/.*/, "", $5); print $5; exit}')

        if [[ -n "$ip" ]]; then
          printf '%s\n' "$ip"
          return 0
        fi
      fi
    fi

    attempt=$((attempt + 1))
    sleep "$sleep_seconds"
  done

  return 1
}

# Uso
VM_IP=$(detect_vm_ip "nas-test-uefi" 6 1)
```

## Listar Interfaces de Rede da VM

```bash
# Tabela completa de interfaces
virsh domiflist nas-test-uefi

# Saída típica:
#  Interface   Type      Source    Model    MAC
# ---------------------------------------------------
#  vnet0       network   default  virtio   52:54:00:xx:xx:xx
```

## Gerenciamento de Redes Libvirt

```bash
# Listar redes
virsh net-list --all

# Informações da rede default
virsh net-info default

# Listar todos os leases DHCP
virsh net-dhcp-leases default

# Iniciar rede
virsh net-start default

# Rede autostart (após reboot do host)
virsh net-autostart default
```

## Cache de IPs (Padrão do Projeto)

O projeto persiste IPs detectados em `scripts/vm/.cache/vm-ips.env`:

```bash
# Formato do arquivo
VM_IP_UEFI=192.168.122.45
VM_IP_BIOS=192.168.122.67
```

### Carregar IP do Cache

```bash
VM_STATE_FILE="scripts/vm/.cache/vm-ips.env"

load_cached_vm_ip() {
  local mode="$1"  # uefi ou bios
  local key="VM_IP_${mode^^}"

  if [[ -f "$VM_STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$VM_STATE_FILE"
    printf '%s\n' "${!key:-}"
  fi
}

# Uso
CACHED_IP=$(load_cached_vm_ip "uefi")
```

### Persistir IP Detectado

```bash
persist_vm_ip() {
  local mode="$1"
  local ip="$2"
  local key="VM_IP_${mode^^}"

  mkdir -p "$(dirname "$VM_STATE_FILE")"

  if grep -q "^${key}=" "$VM_STATE_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${ip}|" "$VM_STATE_FILE"
  else
    printf '%s=%s\n' "$key" "$ip" >> "$VM_STATE_FILE"
  fi
}

# Uso
persist_vm_ip "uefi" "192.168.122.45"
```

## Verificar Conectividade SSH

```bash
# Teste rápido de conectividade SSH
check_ssh_ready() {
  local ip="$1"
  local user="${2:-root}"

  ssh -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=3 \
      "${user}@${ip}" "exit" >/dev/null 2>&1
}

# Uso
if check_ssh_ready "$VM_IP"; then
  echo "SSH disponível"
fi
```

## Variáveis de Configuração

| Variável                | Padrão  | Descrição                                       |
| ----------------------- | ------- | ----------------------------------------------- |
| `VM_IP_DETECT_ATTEMPTS` | 6       | Número de tentativas de detecção de IP          |
| `VM_IP_DETECT_INTERVAL` | 1       | Segundos entre tentativas                       |
| `VM_DHCP_TIMEOUT`       | 12      | Timeout total para DHCP lease (conector legado) |
| `VM_IP`                 | (vazio) | IP explícito, pula detecção automática          |
