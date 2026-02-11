# RUNBOOK: Serviço SMB "fileserver" (A record) + Kerberos/SPN (empresa.com.br)

Este runbook cobre todos os passos operacionais para o serviço SMB do projeto, desde a configuração DNS e SPNs até a validação pós-join e pós-failover.

## Nomes e Identidades (Fixos)

| Item                       | Valor                                    |
| :------------------------- | :--------------------------------------- |
| Nó físico (ativo)          | EMPRESA-BM-NAS                           |
| Nó VM (standby)            | EMPRESA-VM-NAS                           |
| Alias/VIP (serviço)        | fileserver                               |
| FQDN do serviço            | fileserver.empresa.com.br                |
| DNS                        | Registro A → `<VIP_IPV4>`               |
| Computer Account dedicada  | EMPRESA\EMPRESA-FILESERVER$              |
| Conta de automação         | EMPRESA\svc-nas-automation               |

---

## 1) DNS (Registro A)

Criar (ou garantir) registro A:

- **Nome:** fileserver
- **Zona:** empresa.com.br
- **Tipo:** A
- **IP:** `<VIP_IPV4>`

**Observação:** Usar A record (não CNAME) reduz variáveis e evita nuances de CNAME+Kerberos.

### Validação DNS

```powershell
# No Windows (DC/RSAT)
nslookup fileserver.empresa.com.br
Test-NetConnection fileserver.empresa.com.br -Port 445
```

```bash
# No Linux (Debian)
host fileserver.empresa.com.br
dig fileserver.empresa.com.br A
```

---

## 2) SPN (Kerberos para alias)

Os SPNs CIFS devem existir para o nome usado pelo cliente (`fileserver` e o FQDN).

### 2.1 Descobrir em qual conta registrar

A conta-alvo é a **computer account dedicada** do serviço (não as contas dos nós físico/VM):

```bat
setspn -L EMPRESA\EMPRESA-FILESERVER$
```

### 2.2 Adicionar SPNs (usar -S para evitar duplicidade)

```bat
setspn -S cifs/fileserver EMPRESA\EMPRESA-FILESERVER$
setspn -S cifs/fileserver.empresa.com.br EMPRESA\EMPRESA-FILESERVER$
```

### 2.3 Verificar SPNs

```bat
setspn -Q cifs/fileserver
setspn -Q cifs/fileserver.empresa.com.br
```

### 2.4 Checar duplicidade (domínio/floresta)

```bat
setspn -X
```

**Critério de aceite:** NÃO deve existir duplicidade para `cifs/fileserver*` (duplicidade quebra Kerberos por ambiguidade).

---

## 3) Requisito de Tempo (NTP/Chrony)

Kerberos exige relógios sincronizados. O valor padrão de clock skew máximo é 300 segundos (5 minutos).

### Checklist Debian

```bash
# Verificar sincronismo
timedatectl status

# Garantir que chrony aponta para DCs/NTP corporativo
chronyc sources -v
```

**Critério de aceite:** `timedatectl status` indica sincronismo ativo e diferença de relógio em segundos (não minutos).

---

## 4) Validação no Linux (servidor Samba — nó ativo)

Execute na ordem:

```bash
# 1. Keytab Kerberos
kinit -k

# 2. Join no domínio
net ads testjoin

# 3. Trust Winbind
wbinfo -t

# 4. Configuração Samba
testparm -s

# 5. Smoke test de acesso
smbclient //fileserver/SHARE -U 'EMPRESA\admin' -c 'ls'

# 6. ACL (NT ACLs via smbcacls)
smbcacls //fileserver/SHARE / -U 'EMPRESA\admin' --maximum-access
```

**Script automatizado:** Use `/usr/local/sbin/validate_ad_smb.sh` do projeto para executar todas as validações de uma vez.

---

## 5) Validação no Windows (cliente)

1. Acessar `\\fileserver\SHARE` e verificar acesso.
2. Verificar que Kerberos está sendo usado (não NTLM):
   - Event Viewer → Security → procurar por Logon Type 3 com Authentication Package = Kerberos.
3. Verificar SMB Multichannel (se habilitado):

```powershell
Get-SmbMultichannelConnection
Get-SmbConnection
```

---

## 6) Checklist de validação pós-join (resumo)

| Etapa          | Comando                               | Resultado Esperado |
| :------------- | :------------------------------------ | :----------------- |
| Keytab         | `kinit -k`                            | Sem erro           |
| Join           | `net ads testjoin`                    | OK                 |
| Trust          | `wbinfo -t`                           | OK                 |
| Config         | `testparm -s`                         | Sem warnings críticos |
| Acesso         | `smbclient //fileserver/SHARE -c ls`  | Listagem OK        |
| ACL            | `smbcacls //fileserver/SHARE /`       | ACL exibida        |
| DNS            | `host fileserver.empresa.com.br`      | VIP resolve        |

---

## 7) Regras de Failover (A/P)

- Em failover, o VIP permanece o **mesmo IP**; apenas muda o nó que responde.
- SPNs **NÃO** devem ser movidos entre `EMPRESA-BM-NAS$` e `EMPRESA-VM-NAS$`.
- A identidade dedicada `EMPRESA-FILESERVER$` é a fonte de verdade do Kerberos para CIFS.
- Ordem de resources no cluster: **VIP → import/mount ZFS → Samba/Winbind**

### Validação pós-failover

1. DNS resolve `fileserver` para o VIP (mesmo IP, nó diferente respondendo).
2. Clientes Windows reconectam e autenticam normalmente.
3. Se Kerberos falhar pós-failover:
   - Revisar SPNs `cifs/fileserver*` em `EMPRESA-FILESERVER$`.
   - Verificar se o serviço responde com o IP esperado.
   - Verificar NTP/sincronismo no nó que assumiu.

---

## 8) Automação AD-side (Jump Box)

Para configuração automatizada de DNS/SPN via Jump Box Windows:

```bash
# No Debian (NAS) — dry-run (sem mudanças)
ad-precheck-fileserver --method ssh --host JUMPBOX.empresa.com.br \
  --user 'EMPRESA\svc-nas-automation' \
  --vip 10.10.10.50 --dns-server DC01

# Com aplicação real
ad-precheck-fileserver --method ssh --host JUMPBOX.empresa.com.br \
  --user 'EMPRESA\svc-nas-automation' \
  --vip 10.10.10.50 --dns-server DC01 --apply
```

O script `ad_setup_fileserver.ps1` é DRY-RUN por padrão e gera um relatório JSON.
