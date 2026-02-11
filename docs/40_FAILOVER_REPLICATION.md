# Replicação + Failover Ativo/Passivo — Projeto NAS Debian

## Visão Geral

O projeto utiliza um modelo **ativo/passivo** com replicação ZFS do servidor físico (EMPRESA-BM-NAS) para uma VM standby (EMPRESA-VM-NAS), permitindo failover com RPO definido e RTO baixo.

```
┌──────────────────┐    zfs send/receive    ┌──────────────────┐
│  EMPRESA-BM-NAS  │ ────────────────────▶  │  EMPRESA-VM-NAS  │
│  (ativo normal)  │       (periódico)      │  (standby)       │
│                  │                        │                  │
│  VIP: fileserver │                        │  (assume VIP     │
│  Samba + Winbind │                        │   no failover)   │
└──────────────────┘                        └──────────────────┘
```

## Método de Replicação: ZFS Snapshots + Send/Receive

### Ferramenta Recomendada: Syncoid (Sanoid)

Syncoid automatiza `zfs send | zfs receive` com suporte a:
- Snapshots incrementais (apenas deltas são transmitidos)
- Compressão durante transmissão
- Suporte a datasets recursivos
- Verificação de integridade

### Datasets Replicados

| Dataset               | Conteúdo                              | Prioridade |
| :-------------------- | :------------------------------------ | :--------- |
| `tank/SHARES/*`       | Dados dos shares SMB (recursivo)      | Crítica    |
| `tank/SYS/samba-state`| Estado Samba/AD (keytab, TDB, secrets)| Crítica    |
| `tank/ROOT/debian`    | Sistema operacional (boot environment)| Média      |

### Configuração Syncoid (exemplo)

```bash
# Replicação periódica (cron/systemd timer)
syncoid --recursive --compress=zstd-fast \
  tank/SHARES user@EMPRESA-VM-NAS:tank/SHARES

syncoid --compress=zstd-fast \
  tank/SYS/samba-state user@EMPRESA-VM-NAS:tank/SYS/samba-state
```

### RPO (Recovery Point Objective)

O RPO depende da frequência de replicação:

| Frequência  | RPO           | Impacto no link              |
| :---------- | :------------ | :--------------------------- |
| 15 minutos  | ≤ 15 min      | Mais tráfego, menor perda    |
| 1 hora      | ≤ 1 hora      | Balanço razoável             |
| Diário      | ≤ 24 horas    | Menor tráfego, maior perda   |

---

## Cluster: Pacemaker + Corosync

### Modo: Ativo/Passivo

- **Apenas o nó ativo** sobe os serviços (Samba, Winbind) e responde no VIP.
- O standby mantém réplica atualizada mas **não** roda serviços.

### Fencing (STONITH): Obrigatório

> **CRÍTICO:** Cluster sem fencing é um risco de split-brain. STONITH é obrigatório.

Opções de fencing para este projeto:
- **IPMI/iDRAC** (para o Dell PowerEdge 2950)
- **Fence agent para VM** (libvirt/fence_virsh para a VM standby)

### Ordem dos Resources

O cluster deve iniciar resources na seguinte ordem estrita:

```
1. VIP (IP virtual float)
2. Import/mount do pool ZFS tank
3. Samba (smbd)
4. Winbind (winbindd)
```

E desligar na ordem inversa durante failover.

### Configuração Pacemaker (exemplo conceitual)

```bash
# Resource: VIP
pcs resource create vip-fileserver ocf:heartbeat:IPaddr2 \
  ip=<VIP_IPV4> cidr_netmask=24 \
  op monitor interval=10s

# Resource: ZFS pool import
pcs resource create zfs-tank ocf:heartbeat:ZFS \
  pool=tank \
  op start timeout=120s

# Resource: Samba
pcs resource create samba systemd:smbd \
  op monitor interval=30s

# Resource: Winbind
pcs resource create winbind systemd:winbindd \
  op monitor interval=30s

# Ordering constraints
pcs constraint order vip-fileserver then zfs-tank
pcs constraint order zfs-tank then samba
pcs constraint order samba then winbind

# Colocation (tudo roda no mesmo nó)
pcs constraint colocation add samba with vip-fileserver INFINITY
pcs constraint colocation add winbind with samba INFINITY
pcs constraint colocation add zfs-tank with vip-fileserver INFINITY
```

---

## Abordagem NÃO Recomendada: DRBD sob ZFS

> **AVISO:** DRBD + Pacemaker/Corosync **sob** ZFS em hardware RAID adiciona muita complexidade e pontos de falha. O projeto deliberadamente **evita** essa abordagem no baseline.

### Motivos

- ZFS já fornece checksums, snapshots e send/receive nativos.
- DRBD adiciona uma camada de replicação redundante com overhead de I/O.
- Depurar problemas em DRBD+ZFS+PERC é significativamente mais difícil.

---

## Kerberos e SPNs no Failover

- SPNs `cifs/fileserver` e `cifs/fileserver.empresa.com.br` ficam **fixos** em `EMPRESA\EMPRESA-FILESERVER$`.
- **Não** mover SPNs entre `EMPRESA-BM-NAS$` e `EMPRESA-VM-NAS$` a cada failover.
- O VIP permanece o mesmo IP; apenas muda o nó que responde.

Consulte `docs/30_AD_JOIN_AND_ALIAS.md` e `docs/32_AD_OBJECTS_CHECKLIST.md` para detalhes.

---

## Validação Pós-Failover

1. **DNS:** `fileserver.empresa.com.br` resolve para o VIP (mesmo IP).
2. **Serviços:** Samba e Winbind rodando no nó que assumiu.
3. **Kerberos:** `kinit -k` e `net ads testjoin` passam.
4. **Acesso Windows:** Clientes reconectam a `\\fileserver\SHARE`.
5. **Multichannel:** `Get-SmbMultichannelConnection` (se habilitado).

---

## Snapshots e Rollback (Operação de Rotina)

Além da replicação, use snapshots locais para proteção:

```bash
# Snapshot manual antes de manutenção
zfs snapshot tank/SHARES/dados@pre-manutencao

# Rollback se necessário
zfs rollback tank/SHARES/dados@pre-manutencao

# Listar snapshots
zfs list -t snapshot -r tank/SHARES
```

Para automação de snapshots locais, configure o **Sanoid** com política de retenção.
