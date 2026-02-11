# Jump Box: SSH por chave (Windows OpenSSH) para automação do NAS

Objetivo: permitir que o Debian (instalador/first-boot) rode scripts PowerShell na Jump Box via SSH sem senha.

## 1) Key-based auth no OpenSSH do Windows

A Microsoft documenta que, para contas administrativas, as chaves públicas devem ir em:

```
%ProgramData%\ssh\administrators_authorized_keys
```

É recomendado ajustar permissões com `icacls` para Administrators e SYSTEM.

### Exemplo (rodar na Jump Box em PowerShell como admin)

```powershell
# Criar/editar arquivo
$path = "$env:ProgramData\ssh\administrators_authorized_keys"
New-Item -Force -Path $path | Out-Null
Add-Content -Force -Path $path -Value '<COLE_AQUI_A_PUBLIC_KEY_DO_DEBIAN>'

# Fixar ACLs (somente Administrators e SYSTEM)
icacls.exe "$path" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
```

## 2) Observação importante

- Para contas **não-admin**, o `authorized_keys` pode ficar no perfil do usuário (`%USERPROFILE%\.ssh\authorized_keys`).
- Para contas **admin**, o comportamento padrão usa `administrators_authorized_keys`.
- Permissões incorretas são causa comum de "publickey denied" em OpenSSH no Windows.
