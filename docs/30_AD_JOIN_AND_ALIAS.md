# AD + Kerberos + Alias (VIP) para Samba: fileserver (empresa.com.br)

## Nomes Fixos

- Nó físico: EMPRESA-BM-NAS
- Nó VM standby: EMPRESA-VM-NAS
- Serviço (VIP/alias): fileserver
- Domínio DNS: empresa.com.br
- FQDN do serviço: fileserver.empresa.com.br

## DNS

- Criar registro A: fileserver.empresa.com.br → `<VIP_IPV4>` (VIP é movido pelo cluster).
- Usar A record (não CNAME) para reduzir variáveis com Kerberos.

## SPN (Kerberos) — conta dedicada do serviço (recomendado)

Conta dedicada do serviço (computer account):

- EMPRESA\EMPRESA-FILESERVER$

O utilitário `setspn` lê/modifica SPNs em contas de serviço/computadores no AD; use `-S` para adicionar evitando SPNs duplicados.

Comandos:

```bat
setspn -L EMPRESA\EMPRESA-FILESERVER$
setspn -S cifs/fileserver EMPRESA\EMPRESA-FILESERVER$
setspn -S cifs/fileserver.empresa.com.br EMPRESA\EMPRESA-FILESERVER$
setspn -Q cifs/fileserver
setspn -Q cifs/fileserver.empresa.com.br
setspn -X
```

## Time Sync

Kerberos depende de relógios sincronizados; tolerância típica de 300s (5 min). Usar NTP/chrony.

## Checklist de validação pós-join (Linux)

- `kinit -k` (keytab) deve funcionar.
- `net ads testjoin` deve retornar OK.
- `wbinfo -t` deve retornar OK.
- Acesso SMB via `\\fileserver\share` deve usar Kerberos.

## Checklist de validação pós-failover (A/P)

- DNS deve resolver `fileserver` para o VIP (mesmo IP, nó diferente).
- Clientes Windows devem reconectar e autenticar.
- Se Kerberos falhar, revisar SPNs `cifs/fileserver*` e se o serviço responde com o mesmo nome/IP.
