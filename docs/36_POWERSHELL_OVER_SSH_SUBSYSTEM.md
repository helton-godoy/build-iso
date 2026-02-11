# PowerShell Remoting over SSH (subsystem) — opção futura

A Microsoft descreve que é possível adicionar um Subsystem "powershell" no `sshd_config` para hospedar um processo PowerShell via SSH.

**Benefício:** sessões PowerShell mais "nativas" via SSH.

**Risco/custo:** mexe em `sshd_config`, exige restart do serviço e padronização do caminho do `pwsh`.

## Configuração (sshd_config)

```
Subsystem powershell c:/progra~1/powershell/7/pwsh.exe -sshs -NoLogo -NoProfile
```

## Quando usar

- Quando quiser sessões PowerShell interativas entre Debian e Windows via SSH.
- Para o cenário deste projeto (execução de script pontual), `pwsh -File` direto via SSH é suficiente.
