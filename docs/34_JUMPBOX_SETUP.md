# Jump Box WS2019: setup base para automacao AD-side

Objetivo: preparar a Jump Box Windows Server 2019 para executar automacoes de DNS/SPN do fileserver SMB via SSH, com seguranca e rastreabilidade.

## 1) Requisitos minimos

- Windows Server 2019 atualizado (patching em dia).
- Acesso de administracao local para bootstrap inicial.
- Conectividade da Jump Box para Domain Controllers (LDAP/Kerberos/DNS/RPC).
- OpenSSH Server instalado e em execucao.
- PowerShell 5.1 (nativo) ou PowerShell 7 (`pwsh`) instalado.

## 2) Hardening inicial da maquina

1. Renomear host conforme padrao corporativo e ingressar no dominio.
2. Configurar NTP consistente com AD (evita falhas Kerberos por drift).
3. Aplicar baseline de firewall e desabilitar servicos nao usados.
4. Restringir acesso RDP (somente grupos autorizados e jump-subnet).

## 3) OpenSSH Server (obrigatorio)

Executar como administrador:

```powershell
# Verificar recursos OpenSSH disponiveis
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'

# Instalar OpenSSH Client (opcional, recomendado para troubleshooting local)
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Instalar OpenSSH Server (se necessario)
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Habilitar servico
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

# Regra de firewall (porta 22)
if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}
```

Opcional (recomendado): definir shell padrao para sessoes SSH.

```powershell
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShell' \
  -Value 'C:\Program Files\PowerShell\7\pwsh.exe' -PropertyType String -Force

Restart-Service sshd
```

## 4) Conta de automacao AD

Conta recomendada: `EMPRESA\svc-nas-automation`.

Politicas recomendadas:

- Conta dedicada (nao reutilizar conta pessoal).
- Sem perfil de Domain Admin por padrao (principio do menor privilegio).
- Permissoes delegadas apenas para:
  - atualizar registro A do alias (`fileserver`),
  - validar/criar SPNs `cifs/fileserver*` no objeto correto,
  - leitura de objetos AD necessarios para precheck.

## 5) Estrutura local para execucao de scripts

Criar diretorio dedicado para staging temporario da automacao:

```powershell
New-Item -ItemType Directory -Force -Path 'C:\ProgramData\nas-automation' | Out-Null
```

Boas praticas:

- Nao armazenar secrets em arquivo texto.
- Limpeza de artefatos temporarios apos execucao.
- Logs de execucao centralizados no Event Log ou pipeline de observabilidade.

## 6) Validacao funcional minima

Da maquina Debian/NAS:

```bash
# Teste de conectividade SSH
ssh -o BatchMode=yes 'svc-nas-automation@empresa.com.br@JUMPBOX.empresa.com.br' 'hostname'

# Teste de PowerShell remoto sem alterar AD
ssh 'svc-nas-automation@empresa.com.br@JUMPBOX.empresa.com.br' \
  'pwsh -NoLogo -NoProfile -Command "$PSVersionTable.PSVersion"'
```

## 7) Integracao com scripts do projeto

- Wrapper Debian-side: `artifacts/scripts/ad_precheck_fileserver.sh`
- Script AD-side esperado: `artifacts/scripts/ad_setup_fileserver.ps1`

Fluxo esperado:

1. Debian faz precheck local e remoto.
2. Debian transfere script para Jump Box.
3. Jump Box executa PowerShell em dry-run por padrao.
4. Saida JSON retorna ao Debian para auditoria.

## 8) Troubleshooting rapido

- `Permission denied (publickey)`: revisar `docs/35_JUMPBOX_SSH_KEYS.md`.
- `Permission denied (publickey)` com conta admin: revisar `administrators_authorized_keys` + ACLs em `docs/37_JUMPBOX_WS2019_AD_KEYAUTH.md`.
- `KRB_AP_ERR_SKEW` ou falhas Kerberos: revisar NTP (clock drift).
- `pwsh: command not found`: ajustar caminho/instalacao do PowerShell 7.
- Falha de DNS/SPN com credencial valida: revisar delegacoes da conta `svc-nas-automation`.

## 9) Referencias oficiais (Microsoft)

- Instalar e iniciar OpenSSH no Windows Server: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
- Configuracao do servidor OpenSSH no Windows (inclui DefaultShell): https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh-server-configuration
- Gerenciamento de chaves no OpenSSH para Windows: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement
