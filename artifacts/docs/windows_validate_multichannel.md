# Validar SMB Multichannel (lado Windows)

O Windows implementa SMB Multichannel como mecanismo que cria múltiplas conexões TCP por sessão para throughput agregado e tolerância a falha.

Fonte: https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/manage-smb-multichannel

## Checar se está ativo (PowerShell)

```powershell
# Ver conexões multichannel
Get-SmbMultichannelConnection

# Ver conexões SMB
Get-SmbConnection
```

## Habilitar/Desabilitar (se necessário)

```powershell
# No servidor Windows (se aplicável)
Set-SmbServerConfiguration -EnableMultiChannel $true
Set-SmbServerConfiguration -EnableMultiChannel $false
```

## Diagnóstico

```powershell
# Ver status detalhado
Get-SmbMultichannelConnection | Format-List

# Verificar se NICs suportam RSS
Get-NetAdapterRss
```
