# Checklist AD: SMB "fileserver" + Kerberos/SPN (empresa.com.br)

Contexto fixo do projeto:

- Nós: EMPRESA-BM-NAS (bare metal) e EMPRESA-VM-NAS (standby)
- Serviço para clientes: \\fileserver\SHARE e \\fileserver.empresa.com.br\SHARE
- DNS: A record fileserver.empresa.com.br -> VIP (IP movido pelo cluster)
- Identidade dedicada do serviço (AD computer account): EMPRESA\EMPRESA-FILESERVER$

Objetivo: garantir que autenticação Kerberos e acesso SMB funcionem de forma previsível no modo ativo+passivo, sem mover SPN em failover.
---

## 1) Objetos obrigatórios no AD

### 1.1 Computer account dedicada do serviço

- Deve existir: EMPRESA-FILESERVER (computer object; referenciado como EMPRESA\EMPRESA-FILESERVER$ em setspn)
Validação (rodar em DC / host com RSAT):

- `setspn -L EMPRESA\EMPRESA-FILESERVER$`

### 1.2 Registros DNS A

- Deve existir: fileserver.empresa.com.br A VIP (ex.: 10.10.10.50)
Validação (rodar em DC / host com RSAT):

- `Get-DnsServerResourceRecord -ZoneName empresa.com.br -Name fileserver`
- Ou via nslookup: `nslookup fileserver.empresa.com.br`

### 1.3 SPNs do alias

- Deve existir: cifs/fileserver em EMPRESA\EMPRESA-FILESERVER$
- Deve existir: cifs/fileserver.empresa.com.br em EMPRESA\EMPRESA-FILESERVER$
Validação (rodar em DC / host com RSAT):

- `setspn -L EMPRESA\EMPRESA-FILESERVER$`
- `setspn -Q cifs/fileserver`
- `setspn -Q cifs/fileserver.empresa.com.br`
- `setspn -X` (verificar duplicidades no domínio)

## 2) Checklist de prontidão

Antes de marcar o cluster como pronto, valide estes itens (automação sugerida no futuro):

- [ ] Computer account EMPRESA-FILESERVER existe
- [ ] DNS A record fileserver.empresa.com.br aponta para VIP atual
- [ ] SPNs cifs/fileserver e cifs/fileserver.empresa.com.br estão em EMPRESA\EMPRESA-FILESERVER$
- [ ] Não há SPNs duplicados no domínio (setspn -X)
- [ ] Tempo sincronizado entre nós e DC (chrony/ntpd)
- [ ] Rede/DNS resolvendo domínio AD
- [ ] Teste de join AD bem-sucedido (net ads testjoin)
- [ ] Validação Kerberos (kinit -k funciona)
- [ ] Winbind funcional (wbinfo -t e wbinfo -u)
- [ ] Samba configurado e testparm passa
- [ ] Share SMB-only acessível via \\fileserver\SHARE (testar ACL round-trip)

## 3) Comandos para criação/correção (rodar em DC com RSAT)

### Criar computer account dedicada

```powershell
# Criar computer account
New-ADComputer -Name "EMPRESA-FILESERVER" -SAMAccountName "EMPRESA-FILESERVER$" -Path "OU=Computers,DC=empresa,DC=com,DC=br"
```

### Criar DNS A record

```powershell
# Importar módulo
Import-Module DnsServer

# Criar A record
Add-DnsServerResourceRecordA -Name "fileserver" -ZoneName "empresa.com.br" -IPv4Address "10.10.10.50"
```

### Criar SPNs

```powershell
# Verificar se já existem
setspn -Q cifs/fileserver
setspn -Q cifs/fileserver.empresa.com.br

# Adicionar evitando duplicidade
setspn -S cifs/fileserver EMPRESA\EMPRESA-FILESERVER$
setspn -S cifs/fileserver.empresa.com.br EMPRESA\EMPRESA-FILESERVER$
```

## 4) Observações

- Computer accounts aparecem como NOME$ no AD; use domínio\conta$ em comandos.
- VIP deve ser movido pelo cluster (Pacemaker/Corosync); DNS A record aponta para VIP atual.
- Em failover, SPNs ficam fixos na conta dedicada; não mova SPNs entre nós.
- Use setspn -X para detectar SPNs duplicados (problema comum).
