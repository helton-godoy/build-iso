# Snapshots, Clones e Backup

Referência para gerenciamento de snapshots, clonagem de VMs e backup de configuração com `virsh`.

## Snapshots

Snapshots permitem salvar o estado completo de uma VM (memória + disco) para restauração posterior.

### Criar Snapshot

```bash
# Snapshot com nome e descrição
virsh snapshot-create-as nas-test-uefi \
  --name "pre-install" \
  --description "Estado antes da instalação ZFS"

# Snapshot com memória (VM pode estar rodando)
virsh snapshot-create-as nas-test-uefi \
  --name "running-state" \
  --description "Estado com sistema rodando" \
  --memspec snapshot=internal

# Snapshot apenas de disco (sem memória)
virsh snapshot-create-as nas-test-uefi \
  --name "disk-only" \
  --description "Apenas estado dos discos" \
  --disk-only
```

### Listar Snapshots

```bash
# Lista simples
virsh snapshot-list nas-test-uefi

# Com árvore de dependências
virsh snapshot-list nas-test-uefi --tree

# Com informações de pai
virsh snapshot-list nas-test-uefi --parent
```

### Informações do Snapshot

```bash
# Detalhes de um snapshot
virsh snapshot-info nas-test-uefi --snapshotname "pre-install"

# Configuração XML do snapshot
virsh snapshot-dumpxml nas-test-uefi "pre-install"

# Snapshot atual (mais recente)
virsh snapshot-current nas-test-uefi
```

### Restaurar Snapshot

```bash
# Reverter para snapshot (VM deve estar desligada ou pausada)
virsh snapshot-revert nas-test-uefi --snapshotname "pre-install"

# Reverter forçando desligamento
virsh snapshot-revert nas-test-uefi --snapshotname "pre-install" --force

# Reverter e iniciar
virsh snapshot-revert nas-test-uefi --snapshotname "pre-install" --running
```

### Deletar Snapshot

```bash
# Deletar snapshot específico
virsh snapshot-delete nas-test-uefi --snapshotname "pre-install"

# Deletar snapshot e seus filhos
virsh snapshot-delete nas-test-uefi --snapshotname "pre-install" --children

# Deletar metadados apenas (preservar dados de disco)
virsh snapshot-delete nas-test-uefi --snapshotname "pre-install" --metadata
```

## Cenários de Uso para Agentes LLM

### Save-State Antes de Teste Destrutivo

```bash
# 1. Criar snapshot antes de teste
virsh snapshot-create-as nas-test-uefi \
  --name "pre-test-$(date +%Y%m%d-%H%M%S)" \
  --description "Antes de teste destrutivo"

# 2. Executar teste arriscado
make vm-connect-uefi CMD="zpool destroy zroot"

# 3. Se falhar, reverter
virsh snapshot-revert nas-test-uefi --snapshotname "pre-test-20260216-183000" --force
```

### Ciclo de Teste Iterativo

```bash
# Criar baseline após instalação limpa
virsh snapshot-create-as nas-test-uefi --name "clean-install"

# Para cada iteração de teste:
#   1. Executar teste
#   2. Verificar resultado
#   3. Reverter para baseline
virsh snapshot-revert nas-test-uefi --snapshotname "clean-install" --force
```

## Clonagem de VMs

```bash
# Clonar VM (deve estar desligada)
virt-clone \
  --original nas-test-uefi \
  --name nas-test-uefi-clone \
  --auto-clone

# Clonar com novo nome de disco
virt-clone \
  --original nas-test-uefi \
  --name nas-test-uefi-v2 \
  --file scripts/vm/disks/uefi/clone-disk1.qcow2 \
  --file scripts/vm/disks/uefi/clone-disk2.qcow2

# Verificar clone
virsh dominfo nas-test-uefi-clone
```

## Backup de Configuração XML

```bash
# Exportar configuração completa
virsh dumpxml nas-test-uefi > backup/nas-test-uefi.xml

# Restaurar configuração
virsh define backup/nas-test-uefi.xml

# Exportar todas as VMs do projeto
for vm in nas-test-uefi nas-test-bios; do
  virsh dumpxml "$vm" > "backup/${vm}.xml" 2>/dev/null || true
done
```

## Save e Restore de Estado (Managedave)

```bash
# Salvar estado completo (memória + disco) para arquivo
virsh save nas-test-uefi /tmp/nas-test-uefi.save

# Restaurar estado (VM reinicia do ponto salvo)
virsh restore /tmp/nas-test-uefi.save

# Managedsave (salva ao desligar, restaura ao ligar)
virsh managedsave nas-test-uefi
virsh start nas-test-uefi  # Restaura automaticamente
```

## Limitações com VMs Transientes

> **ATENÇÃO**: O projeto usa `--transient` no `virt-install`. VMs transientes:
>
> - **Não suportam snapshots** de disco interno (qcow2-based snapshots requerem VM definida)
> - **Desaparecem** após `virsh destroy`
> - Para usar snapshots, remova `--transient` ou use `virsh define` com o XML

### Alternativa para VMs Transientes

```bash
# Em vez de snapshot, copiar o disco diretamente
cp scripts/vm/disks/uefi/disk1.qcow2 scripts/vm/disks/uefi/disk1-backup.qcow2

# Para restaurar
cp scripts/vm/disks/uefi/disk1-backup.qcow2 scripts/vm/disks/uefi/disk1.qcow2
```
