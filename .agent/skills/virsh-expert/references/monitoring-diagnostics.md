# Monitoramento e Diagnóstico

Referência para monitorar estado, performance e diagnosticar problemas em VMs com `virsh` e ferramentas do sistema.

## Informações Gerais da VM

```bash
# Informações completas
virsh dominfo nas-test-uefi

# Saída típica:
# Id:             3
# Name:           nas-test-uefi
# UUID:           abc123...
# OS Type:        hvm
# State:          running
# CPU(s):         2
# CPU time:       42.3s
# Max memory:     4194304 KiB
# Used memory:    4194304 KiB
# Persistent:     no (transient)
# Autostart:      disable
```

## Estado da VM

```bash
# Estado simples
virsh domstate nas-test-uefi
# running

# Estado com motivo
virsh domstate nas-test-uefi --reason
# running (booted)
```

### Tabela de Estados e Transições

```
shut off ──start──► running ──shutdown──► shut off
                       │
                       ├──destroy──► shut off
                       ├──suspend──► paused ──resume──► running
                       ├──save─────► saved  ──restore─► running
                       └──reboot───► running (reinicia)
```

## Métricas de CPU

```bash
# Informações de vCPUs
virsh vcpuinfo nas-test-uefi

# Saída:
# VCPU:           0
# CPU:            3
# State:          running
# CPU time:       21.8s
# CPU Affinity:   yyyyyyyy

# Contagem de vCPUs
virsh vcpucount nas-test-uefi
```

## Métricas de Memória

```bash
# Estatísticas de memória
virsh dommemstat nas-test-uefi

# Saída típica:
# actual 4194304
# swap_in 0
# swap_out 0
# major_fault 0
# minor_fault 12345
# unused 2500000
# available 4000000
# usable 3000000
# rss 3500000
```

## Métricas de Disco / Block I/O

```bash
# Listar block devices
virsh domblklist nas-test-uefi

# Informações de um disco
virsh domblkinfo nas-test-uefi vda

# Saída:
# Capacity:       10737418240
# Allocation:     209715200
# Physical:       209715200

# Estatísticas de I/O
virsh domblkstat nas-test-uefi vda

# Saída:
# vda rd_req 12345
# vda rd_bytes 50000000
# vda wr_req 5678
# vda wr_bytes 20000000
# vda flush_operations 100
# vda rd_total_times 1234567890
# vda wr_total_times 567890123
```

## Métricas de Rede

```bash
# Listar interfaces
virsh domiflist nas-test-uefi

# Estatísticas de interface
virsh domifstat nas-test-uefi vnet0

# Saída:
# vnet0 rx_bytes 1234567
# vnet0 rx_packets 5000
# vnet0 rx_errs 0
# vnet0 rx_drop 0
# vnet0 tx_bytes 234567
# vnet0 tx_packets 3000
# vnet0 tx_errs 0
# vnet0 tx_drop 0
```

## Estatísticas Consolidadas (domstats)

```bash
# Todas as estatísticas de uma VM
virsh domstats nas-test-uefi

# Filtrar por tipo
virsh domstats --cpu-total nas-test-uefi
virsh domstats --balloon nas-test-uefi
virsh domstats --block nas-test-uefi
virsh domstats --interface nas-test-uefi

# Estatísticas de todas as VMs rodando
virsh domstats --list-running
```

## Diagnóstico Rápido — Checklist do Agente

```bash
#!/usr/bin/env bash
# Diagnóstico rápido para agente LLM
VM_NAME="${1:-nas-test-uefi}"

echo "=== Estado ==="
virsh domstate "$VM_NAME" --reason 2>/dev/null || echo "VM não encontrada"

echo ""
echo "=== Recursos ==="
virsh dominfo "$VM_NAME" 2>/dev/null | grep -E "(CPU|memory|State)"

echo ""
echo "=== Rede ==="
virsh domifaddr "$VM_NAME" 2>/dev/null || echo "IP não disponível"

echo ""
echo "=== Discos ==="
virsh domblklist "$VM_NAME" 2>/dev/null

echo ""
echo "=== Memória ==="
virsh dommemstat "$VM_NAME" 2>/dev/null | grep -E "(actual|unused|available)"
```

## Logs do Sistema

```bash
# Logs do libvirtd
journalctl -u libvirtd --since "10 minutes ago" --no-pager

# Logs do QEMU para uma VM específica
cat /var/log/libvirt/qemu/nas-test-uefi.log

# Logs de erro apenas
journalctl -u libvirtd -p err --no-pager -n 20

# Logs da rede default
virsh net-info default
```

## Saúde do Hypervisor

```bash
# Informações do hypervisor
virsh version

# Capabilities do host
virsh capabilities | head -50

# Verificar conexão
virsh connect qemu:///system

# Node info (recursos do host)
virsh nodeinfo

# Saída:
# CPU model:           x86_64
# CPU(s):              8
# CPU frequency:       3600 MHz
# CPU socket(s):       1
# Memory size:         32768000 KiB
```

## Monitoramento Contínuo (Scripts)

### Polling de Estado

```bash
monitor_vm_state() {
  local vm_name="$1"
  local interval="${2:-5}"

  while true; do
    local state
    state=$(virsh domstate "$vm_name" 2>/dev/null)

    if [[ -z "$state" ]]; then
      printf "[%s] %s: VM NÃO ENCONTRADA\n" "$(date +%H:%M:%S)" "$vm_name"
    else
      local ip
      ip=$(virsh domifaddr "$vm_name" 2>/dev/null \
        | awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}')
      printf "[%s] %s: %s (IP: %s)\n" \
        "$(date +%H:%M:%S)" "$vm_name" "$state" "${ip:-n/a}"
    fi

    sleep "$interval"
  done
}

# Uso (Ctrl+C para parar)
monitor_vm_state "nas-test-uefi" 5
```

### Coletar Métricas em JSON

```bash
collect_vm_metrics() {
  local vm_name="$1"

  local state cpu_time mem_used
  state=$(virsh domstate "$vm_name" 2>/dev/null)
  cpu_time=$(virsh dominfo "$vm_name" 2>/dev/null | awk '/CPU time/ {print $3}')
  mem_used=$(virsh dommemstat "$vm_name" 2>/dev/null | awk '/rss/ {print $2}')

  printf '{"vm":"%s","state":"%s","cpu_time":"%s","mem_rss_kb":"%s","timestamp":"%s"}\n' \
    "$vm_name" "$state" "${cpu_time:-0}" "${mem_used:-0}" "$(date -Iseconds)"
}

# Uso
collect_vm_metrics "nas-test-uefi" >> metrics.jsonl
```
