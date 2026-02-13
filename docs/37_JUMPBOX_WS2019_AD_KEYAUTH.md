# WS2019 + AD + SSH key auth: perfil recomendado para `svc-nas-automation`

Objetivo: padronizar autenticacao por chave SSH para a conta AD usada na automacao do NAS, reduzindo risco operacional e evitando dependencias de senha.

## 1) Escopo

Este documento cobre:

- autenticao SSH por chave no Windows Server 2019,
- particularidades para conta AD administrativa vs nao administrativa,
- controles minimos de seguranca e auditoria.

Nao cobre WinRM (fora de escopo deste baseline).

## 2) Conta recomendada

- Conta: `EMPRESA\svc-nas-automation`
- Tipo: conta de servico dedicada
- Privilégios: delegados para DNS/SPN, sem Domain Admin por padrao

## 3) Posicionamento da chave publica

Referencias Microsoft/OpenSSH no Windows:

- Conta nao-admin: `%USERPROFILE%\.ssh\authorized_keys`
- Conta admin local: `%ProgramData%\ssh\administrators_authorized_keys`

Observacao importante para Windows OpenSSH: `StrictModes` nao e suportado no Windows; o hardening depende de ACL correta via `icacls`.

Para este projeto, prefira manter `svc-nas-automation` como **nao-admin local**, evitando dependencias de `administrators_authorized_keys`.

## 4) Exemplo de bootstrap (PowerShell, admin local)

```powershell
$user = 'EMPRESA\svc-nas-automation'
$pubKey = '<COLE_AQUI_A_CHAVE_PUBLICA_DO_DEBIAN>'

# Descobre profile local da conta (apos primeiro logon)
$profileRoot = "C:\Users\svc-nas-automation"
$sshDir = Join-Path $profileRoot '.ssh'
$authKeys = Join-Path $sshDir 'authorized_keys'

New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
Set-Content -Path $authKeys -Value $pubKey -Encoding ascii

# Permissoes minimas
icacls.exe $sshDir /inheritance:r /grant "svc-nas-automation:F"
icacls.exe $authKeys /inheritance:r /grant "svc-nas-automation:F" /grant "SYSTEM:F"
```

Se a politica corporativa exigir conta admin local, use o fluxo de `administrators_authorized_keys` descrito em `docs/35_JUMPBOX_SSH_KEYS.md`.

Exemplo minimo para conta administrativa local/dominio:

```powershell
$adminKeysFile = "$env:ProgramData\ssh\administrators_authorized_keys"
$pubKey = '<COLE_AQUI_A_CHAVE_PUBLICA_DO_DEBIAN>'

Add-Content -Force -Path $adminKeysFile -Value $pubKey

# ACL restrita: apenas SYSTEM e Administrators
icacls.exe $adminKeysFile /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

# Variante segura para ambientes com locale diferente
# *S-1-5-32-544 = Administrators, *S-1-5-18 = SYSTEM
# icacls.exe $adminKeysFile /inheritance:r /grant "*S-1-5-32-544:F" /grant "*S-1-5-18:F"
```

## 5) Hardening recomendado

- Desabilitar autenticacao por senha no `sshd_config` quando viavel.
- Restringir logon SSH por grupo (`AllowGroups`) para contas de automacao.
- Definir origem de rede permitida (jump subnet) no firewall.
- Rotacionar chaves periodicamente e revogar chaves antigas.

## 6) Validacao rapida

No Debian/NAS:

```bash
ssh -o BatchMode=yes 'svc-nas-automation@empresa.com.br@JUMPBOX.empresa.com.br' 'whoami'
ssh -o BatchMode=yes 'svc-nas-automation@empresa.com.br@JUMPBOX.empresa.com.br' \
  'pwsh -NoLogo -NoProfile -Command "Get-Date -Format o"'
```

Esperado:

- sem prompt de senha,
- `whoami` retornando `empresa\svc-nas-automation`,
- comando PowerShell executado com sucesso.

## 7) Auditoria e operacao

- Registrar fingerprint da chave publica aprovada (inventario de chaves).
- Manter trilha de execucao dos scripts AD-side (stdout/stderr + JSON final).
- Revisar periodicamente eventos de logon SSH (`sshd`) e falhas de autenticacao.

## 8) Erros comuns

- `Permission denied (publickey)`: arquivo em local incorreto ou ACL frouxa.
- Login funciona, mas `pwsh` falha: PowerShell 7 ausente no PATH do contexto SSH.
- Funciona manualmente, falha no wrapper: host key nao pinada ou usuario incorreto.

## 9) Notas de compatibilidade WS2019

- `GSSAPIAuthentication` nao esta disponivel no baseline WS2019 do OpenSSH (aparece em versoes mais novas do Windows).
- Formato de usuario de dominio para login remoto costuma funcionar como `usuario@dominio@host`.
- Para regras no `sshd_config` (`AllowUsers`/`AllowGroups`), seguir a sintaxe documentada pela Microsoft para principals de dominio.

## 10) Referencias oficiais

- OpenSSH server configuration (Windows): https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh-server-configuration
- OpenSSH key management (Windows): https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement
- Win32-OpenSSH wiki (DefaultShell): https://github.com/PowerShell/Win32-OpenSSH/wiki/DefaultShell
- Win32-OpenSSH wiki (public-key auth): https://github.com/PowerShell/Win32-OpenSSH/wiki/Setup-public-key-based-authentication-for-windows
