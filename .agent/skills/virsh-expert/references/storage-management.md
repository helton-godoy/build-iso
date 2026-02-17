# Gerenciamento de Discos e Storage

Referência para criação, manipulação e gerenciamento de discos virtuais e pools de storage com `qemu-img`, `virsh` e `virt-install`.

## qemu-img — Operações com Imagens de Disco

### Criar Disco

```bash
# Criar disco qcow2 (formato padrão do projeto)
qemu-img create -f qcow2 disco.qcow2 10G

# Criar disco raw (performance máxima, sem snapshots)
qemu-img create -f raw disco.raw 10G

# Criar disco com preallocação (menos fragmentação)
qemu-img create -f qcow2 -o preallocation=metadata disco.qcow2 20G
```

### Inspecionar Disco

```bash
# Informações detalhadas
qemu-img info disco.qcow2

# Saída típica:
# image: disco.qcow2
# file format: qcow2
# virtual size: 10 GiB (10737418240 bytes)
# disk size: 196 KiB
# cluster_size: 65536

# Verificar integridade
qemu-img check disco.qcow2
```

### Redimensionar Disco

```bash
# Expandir disco (VM deve estar desligada)
qemu-img resize disco.qcow2 +5G

# Reduzir (PERIGOSO — pode danificar dados)
qemu-img resize --shrink disco.qcow2 5G
```

### Converter Formatos

```bash
# qcow2 → raw
qemu-img convert -f qcow2 -O raw disco.qcow2 disco.raw

# raw → qcow2 (com compressão)
qemu-img convert -f raw -O qcow2 -c disco.raw disco-comprimido.qcow2

# vmdk → qcow2
qemu-img convert -f vmdk -O qcow2 disco.vmdk disco.qcow2
```

## Padrão do Projeto: 4 Discos por VM

O projeto cria 4 discos de 10GB para simulação de pool ZFS:

```bash
DISK_DIR="scripts/vm/disks/uefi"
mkdir -p "$DISK_DIR"

# Criar 4 discos de 10GB
for i in {1..4}; do
  if [[ ! -f "$DISK_DIR/disk${i}.qcow2" ]]; then
    qemu-img create -f qcow2 "$DISK_DIR/disk${i}.qcow2" 10G
  fi
done
```

### Estrutura de Diretórios

```
scripts/vm/disks/
├── uefi/
│   ├── disk1.qcow2
│   ├── disk2.qcow2
│   ├── disk3.qcow2
│   └── disk4.qcow2
└── bios/
    ├── disk1.qcow2
    ├── disk2.qcow2
    ├── disk3.qcow2
    └── disk4.qcow2
```

## Attach/Detach de Discos em VMs Ativas

### Adicionar Disco a VM Rodando

```bash
# Attach disco virtio (hot-plug)
virsh attach-disk nas-test-uefi \
  scripts/vm/disks/uefi/extra.qcow2 \
  vdb \
  --driver qemu \
  --subdriver qcow2 \
  --targetbus virtio

# Attach disco SCSI
virsh attach-disk nas-test-uefi \
  scripts/vm/disks/uefi/extra.qcow2 \
  sda \
  --driver qemu \
  --subdriver qcow2 \
  --targetbus scsi
```

### Remover Disco

```bash
# Detach disco
virsh detach-disk nas-test-uefi vdb

# Detach com persistência (para VMs definidas)
virsh detach-disk nas-test-uefi vdb --config
```

## Listar Discos de uma VM

```bash
# Lista de block devices
virsh domblklist nas-test-uefi

# Saída típica:
#  Target   Source
# -------------------------------------------------
#  vda      /home/user/scripts/vm/disks/uefi/disk1.qcow2
#  vdb      /home/user/scripts/vm/disks/uefi/disk2.qcow2
#  sda      /home/user/output/debian-live.iso

# Informações detalhadas de um bloco
virsh domblkinfo nas-test-uefi vda

# Estatísticas de I/O
virsh domblkstat nas-test-uefi vda
```

## Storage Pools Libvirt

```bash
# Listar pools
virsh pool-list --all

# Criar pool baseado em diretório
virsh pool-define-as mypool dir - - - - /var/lib/libvirt/images/mypool
virsh pool-build mypool
virsh pool-start mypool
virsh pool-autostart mypool

# Listar volumes em um pool
virsh vol-list mypool

# Criar volume em um pool
virsh vol-create-as mypool meu-disco.qcow2 10G --format qcow2

# Informações de volume
virsh vol-info --pool mypool meu-disco.qcow2

# Deletar volume
virsh vol-delete --pool mypool meu-disco.qcow2

# Deletar pool
virsh pool-destroy mypool
virsh pool-undefine mypool
```

## Formatos Suportados

| Formato | Snapshots | Compressão | Performance | Uso Típico               |
| ------- | --------- | ---------- | ----------- | ------------------------ |
| qcow2   | ✅        | ✅         | Boa         | Desenvolvimento e testes |
| raw     | ❌        | ❌         | Máxima      | Produção, I/O intensivo  |
| vmdk    | ❌        | ❌         | Média       | Importação de VMware     |
| vdi     | ❌        | ❌         | Média       | Importação de VirtualBox |

## Boas Práticas

1. **Use qcow2** para desenvolvimento e testes (snapshots, sparse allocation)
2. **Verifique formato** antes de usar: `qemu-img info disco.qcow2`
3. **Valide tamanho mínimo** para evitar falhas de boot (≥ 1GB)
4. **Cleanup**: remova discos antigos ao recriar VMs (`--remove-all-storage`)
5. **Backup**: use `qemu-img convert` para criar cópias em formato diferente
