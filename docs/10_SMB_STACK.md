# Pilha SMB-only — Módulos VFS, ACLs e Configuração Samba

Este documento detalha a configuração da pilha SMB para o cenário padrão do projeto: **SMB-only** com ACLs gerenciáveis via aba Security do Windows.

## Cenário Padrão: SMB-only

Quando o dataset é acessado **exclusivamente via SMB** (sem NFS sobre o mesmo dataset), a configuração é mais simples e performática.

### Módulos VFS Obrigatórios

```ini
vfs objects = acl_xattr streams_xattr
```

| Módulo          | Função                                                                                          |
| :-------------- | :---------------------------------------------------------------------------------------------- |
| `acl_xattr`     | Armazena ACL NT no xattr `security.NTACL`. Permite manipulação via aba Security do Windows.     |
| `streams_xattr` | Implementa NTFS Alternate Data Streams via xattrs do filesystem (compatibilidade com Windows).  |

### Diretivas Críticas

```ini
# Para SMB-only: ignora ACLs POSIX do sistema, usando apenas as ACLs NT armazenadas em xattr
acl_xattr:ignore system acls = yes
```

**Por que `ignore system acls = yes`?**
- Quando dados são acessados **somente** via Samba, não há necessidade de traduzir ACLs NT para POSIX.
- Isso elimina inconsistências entre ACLs POSIX e NT, garantindo que a aba Security do Windows reflita exatamente o que está configurado.
- Se você tiver acesso misto (SMB + algum serviço local lendo arquivos diretamente), essa opção deve ser `no`.

### Protocolo SMB

```ini
# Desabilitar SMB1 (NT1) - obrigatório
server min protocol = SMB2

# Habilitar SMB Multichannel para performance com múltiplas NICs
server multi channel support = yes
aio read size = 1
aio write size = 1
```

## Cenário Excepcional: SMB + NFS (mesmo dataset)

> **AVISO:** O projeto NÃO recomenda compartilhar o mesmo dataset entre SMB e NFS. Se for inevitável:

```ini
vfs objects = acl_xattr streams_xattr
acl_xattr:ignore system acls = no
```

Nesse caso, as ACLs POSIX do sistema **devem** ser consideradas, pois NFS opera com permissões POSIX. Isso adiciona complexidade e possíveis inconsistências.

## Cenário Excepcional: NFS-only

- Não requer módulos VFS do Samba.
- Dataset separado dos datasets SMB.
- Propriedades ZFS: `acltype=posixacl`, `xattr=sa`, sem necessidade de `streams_xattr`.

## Módulos VFS NÃO Recomendados

| Módulo     | Motivo                                                                                     |
| :--------- | :----------------------------------------------------------------------------------------- |
| `zfsacl`   | Projetado para NFSv4 ACLs nativas do ZFS (Solaris/FreeBSD). No Linux com Samba, `acl_xattr` cobre o cenário SMB-only de forma mais limpa. |
| `nfs4acl_xattr` | Similar ao zfsacl, mas via xattr. Menos testado no ecossistema Debian + ZFS Linux.     |

## Administração de ACLs via Linux

Para manipular ACLs NT via linha de comando no Linux:

```bash
# Listar ACL do diretório raiz de um share
smbcacls //fileserver/SHARE / -U 'EMPRESA\admin' --maximum-access

# Exportar ACL em formato SDDL
smbcacls //fileserver/SHARE / -U 'EMPRESA\admin' --sddl
```

O `smbcacls` manipula NT ACLs em shares SMB e pode operar em SMB2/SMB3.

## Referências Rápidas

- `acl_xattr`: armazena ACL NT em `security.NTACL`, recomenda `ignore system acls=yes` para dados SMB-only.
- `streams_xattr`: implementa NTFS ADS via xattrs.
- `smbcacls`: ferramenta para ler/alterar ACLs NT em shares SMB.
- Protocolo mínimo: SMB2 (desabilitar SMB1/NT1).
- Multichannel: habilitado por padrão para throughput agregado e tolerância a falha.
