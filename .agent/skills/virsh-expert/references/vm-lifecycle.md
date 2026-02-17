# Ciclo de Vida de VMs

Referência completa para gerenciamento do ciclo de vida de máquinas virtuais com `virsh` e `virt-install`.

## Listar VMs

```bash
# Todas as VMs (ativas + inativas)
virsh list --all

# Apenas VMs rodando
virsh list --state-running

# Apenas nomes (para scripting)
virsh list --state-running --name

# Verificar se VM específica está rodando
virsh list --state-running --name | grep -Fxq "nas-test-uefi"
```

## Iniciar VMs

```bash
# Iniciar VM existente por nome
virsh start nas-test-uefi

# Iniciar VM persistente definida por XML
virsh define /path/to/vm.xml
virsh start nome-da-vm
```

### Criar e Iniciar com virt-install (Padrão do Projeto)

```bash
# VM UEFI com ISO + 4 discos (padrão build-iso)
virt-install \
  --connect qemu:///system \
  --name "nas-test-uefi" \
  --ram 4096 \
  --vcpus 2 \
  --disk path=scripts/vm/disks/uefi/disk1.qcow2,bus=virtio \
  --disk path=scripts/vm/disks/uefi/disk2.qcow2,bus=virtio \
  --disk path=scripts/vm/disks/uefi/disk3.qcow2,bus=virtio \
  --disk path=scripts/vm/disks/uefi/disk4.qcow2,bus=virtio \
  --cdrom "output/debian-live.iso" \
  --boot uefi \
  --network network=default,model=virtio \
  --graphics spice \
  --os-variant debian12 \
  --noautoconsole \
  --transient \
  --serial unix,path=/tmp/nas-test-uefi.sock,mode=bind \
  --console pty,target_type=serial

# VM BIOS (Legacy)
virt-install \
  --connect qemu:///system \
  --name "nas-test-bios" \
  --ram 4096 \
  --vcpus 2 \
  --disk path=scripts/vm/disks/bios/disk1.qcow2,bus=virtio \
  --cdrom "output/debian-live.iso" \
  --boot hd,cdrom,menu=on \
  --network network=default,model=virtio \
  --graphics spice \
  --os-variant debian12 \
  --noautoconsole \
  --transient \
  --serial unix,path=/tmp/nas-test-bios.sock,mode=bind \
  --console pty,target_type=serial
```

### Flags Importantes do virt-install

| Flag                               | Propósito                                             |
| ---------------------------------- | ----------------------------------------------------- |
| `--transient`                      | VM não persiste após desligamento (ideal para testes) |
| `--noautoconsole`                  | Não abre console automaticamente (headless)           |
| `--serial unix,path=...,mode=bind` | Cria socket serial para agentes                       |
| `--console pty,target_type=serial` | Redireciona console para serial                       |
| `--boot uefi`                      | Usa firmware OVMF para UEFI                           |
| `--boot hd,cdrom,menu=on`          | Boot order para BIOS com menu                         |

## Desligar VMs

```bash
# Desligamento graceful (envia ACPI power button)
virsh shutdown nas-test-uefi

# Desligamento forçado (equivalente a puxar o cabo de energia)
virsh destroy nas-test-uefi

# Reboot
virsh reboot nas-test-uefi
```

### Regra de Ouro

> Prefira `virsh shutdown` para preservar filesystems (especialmente ZFS).
> Use `virsh destroy` apenas quando a VM não responde ou em cleanup de testes.

## Suspender e Resumir

```bash
# Pausar VM (congela execução, mantém memória)
virsh suspend nas-test-uefi

# Retomar execução
virsh resume nas-test-uefi
```

## Remover VMs

```bash
# Remover definição (VM deve estar desligada)
virsh undefine nas-test-uefi

# Remover com variáveis UEFI NVRAM
virsh undefine nas-test-uefi --nvram

# Remover com todos os discos vinculados
virsh undefine nas-test-uefi --nvram --remove-all-storage
```

## Padrão de Idempotência (Projeto build-iso)

Antes de criar/recriar uma VM, sempre limpar estado anterior:

```bash
cleanup_vm() {
  local vm_name="$1"

  if virsh --connect qemu:///system list --all --name | grep -q "^${vm_name}$"; then
    virsh --connect qemu:///system destroy "$vm_name" >/dev/null 2>&1 || true
    virsh --connect qemu:///system undefine "$vm_name" --nvram >/dev/null 2>&1 || true
  fi
}

# Uso
cleanup_vm "nas-test-uefi"
# ... virt-install ...
```

## Consultar Estado

```bash
# Estado atual
virsh domstate nas-test-uefi

# Estado com motivo
virsh domstate nas-test-uefi --reason
```

### Estados Possíveis

| Estado        | Significado                   |
| ------------- | ----------------------------- |
| `running`     | VM em execução                |
| `idle`        | VM ociosa                     |
| `paused`      | VM suspensa                   |
| `in shutdown` | Desligamento em andamento     |
| `shut off`    | VM desligada                  |
| `crashed`     | VM com erro fatal             |
| `pmsuspended` | Suspensa por power management |

## Exportar/Importar Configuração XML

```bash
# Exportar configuração atual
virsh dumpxml nas-test-uefi > vm-config-backup.xml

# Importar/definir VM a partir de XML
virsh define vm-config-backup.xml

# Editar XML inline (abre $EDITOR)
virsh edit nas-test-uefi
```
