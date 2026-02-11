# Templates de Dataset ZFS por Cenário de Uso

Este documento define os templates de propriedades ZFS para cada cenário de acesso a dados do projeto NAS.

## Regras Gerais

- **1 dataset = 1 share SMB** (ou 1 propósito). Nunca misturar shares no mesmo dataset.
- Dados de shares **nunca** ficam dentro de `tank/ROOT` (rollback do sistema não afeta dados).
- **Dedup desabilitado** no baseline (custo de memória alto, pode degradar severamente).
- **Recordsize padrão** (128K): não alterar sem benchmark específico.

## Hierarquia de Datasets

```
tank/ROOT/debian          → Boot Environment (sistema operacional)
tank/SYS/samba-state      → Estado Samba/AD (segredos, keytab, tdb)
tank/SHARES/<share_name>  → 1 dataset por share SMB
```

---

## Template 1: SMB-only (Padrão do Projeto)

Cenário: dataset acessado **exclusivamente** via Samba, com ACLs gerenciáveis via aba Security do Windows.

```bash
zfs create -o acltype=posixacl \
           -o xattr=sa \
           -o atime=off \
           -o compression=zstd \
           -o dnodesize=auto \
           -o relatime=off \
           -o normalization=formD \
           tank/SHARES/<NOME_DO_SHARE>
```

| Propriedade      | Valor       | Justificativa                                                                                 |
| :--------------- | :---------- | :-------------------------------------------------------------------------------------------- |
| `acltype`        | `posixacl`  | Obrigatório para Samba armazenar ACLs NT via `acl_xattr`.                                     |
| `xattr`          | `sa`        | Fortemente recomendado com `posixacl` para performance (xattrs no sistema de arquivos).        |
| `atime`          | `off`       | Desliga atualização de access time; reduz escritas desnecessárias.                              |
| `compression`    | `zstd`      | Compressão leve com boa razão performance/economia. Usar `lz4` se CPU for limitada.            |
| `dnodesize`      | `auto`      | Permite dnodes maiores para metadados extensos (xattrs, ACLs).                                 |
| `normalization`  | `formD`     | Normalização Unicode para consistência de nomes de arquivos.                                   |

### Pré-requisitos Samba

```ini
vfs objects = acl_xattr streams_xattr
acl_xattr:ignore system acls = yes
```

---

## Template 2: NFS-only (Exceção)

Cenário: dataset acessado **exclusivamente** via NFS, sem compartilhamento SMB.

```bash
zfs create -o acltype=posixacl \
           -o xattr=sa \
           -o atime=off \
           -o compression=zstd \
           tank/SHARES/<NOME_DO_EXPORT_NFS>
```

| Propriedade      | Valor       | Justificativa                                                                |
| :--------------- | :---------- | :--------------------------------------------------------------------------- |
| `acltype`        | `posixacl`  | Permissões padrão POSIX.                                                     |
| `xattr`          | `sa`        | Performance de xattrs.                                                       |
| `atime`          | `off`       | Reduz I/O desnecessário.                                                     |
| `compression`    | `zstd`      | Compressão padrão.                                                           |

### Notas

- **Não** requer módulos VFS do Samba.
- Deve ficar em **dataset separado** dos datasets SMB.
- Export via `/etc/exports` com opções adequadas de segurança.

---

## Template 3: SMB + NFS (Misto — Evitar)

> **AVISO:** O projeto NÃO recomenda compartilhar o mesmo dataset entre SMB e NFS. Use apenas se for absolutamente inevitável.

Cenário: dataset acessado via SMB **e** NFS simultaneamente.

```bash
zfs create -o acltype=posixacl \
           -o xattr=sa \
           -o atime=off \
           -o compression=zstd \
           -o dnodesize=auto \
           tank/SHARES/<NOME_DO_SHARE_MISTO>
```

### Diferenças Críticas no Samba

```ini
vfs objects = acl_xattr streams_xattr
# ATENÇÃO: no modo misto, NÃO ignorar ACLs do sistema
acl_xattr:ignore system acls = no
```

### Riscos

- ACLs POSIX e NT podem ficar inconsistentes.
- Administração mais complexa (duas visões de permissões).
- Operações NFS podem sobrescrever ACLs definidas via Windows.

---

## Template 4: Boot Environment (Sistema)

```bash
zfs create -o canmount=noauto \
           -o mountpoint=/ \
           -o compression=zstd \
           -o atime=off \
           -o xattr=sa \
           -o acltype=posixacl \
           tank/ROOT/debian
```

### Notas

- `canmount=noauto` porque o ZFSBootMenu monta o BE selecionado.
- Mountpoint `/` é a raiz do sistema.
- Snapshot/clone deste dataset permite rollback completo do OS.

---

## Template 5: Estado Samba/AD

```bash
zfs create -o canmount=on \
           -o mountpoint=/var/lib/samba \
           -o compression=zstd \
           -o atime=off \
           -o xattr=sa \
           tank/SYS/samba-state
```

### Notas

- Contém: TDB files, keytab, secrets, Group Policy cache.
- Separado do ROOT para que rollback do sistema não perca estado AD.
- **Replicável** para o nó standby junto com os shares.

---

## Propriedades do Pool

```bash
zpool create -o ashift=12 \
             -o compatibility=openzfs-2.2-linux \
             tank <dispositivo>
```

| Propriedade      | Valor                   | Justificativa                                     |
| :--------------- | :---------------------- | :------------------------------------------------ |
| `ashift`         | `12`                    | Alinhamento correto para discos 4K (e maiores).    |
| `compatibility`  | `openzfs-2.2-linux`     | Garantir compatibilidade com features estáveis.    |
