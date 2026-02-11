# Fonte da Verdade (SoT) — Projeto NAS Debian (ZFS + Samba/AD + ZFSBootMenu)

Este documento é a referência principal do projeto. Qualquer mudança de arquitetura deve ser registrada aqui antes de alterar scripts/ISO.

## 1) Objetivo do produto

Entregar uma ISO Debian Trixie remasterizada via live-build que instala um NAS corporativo com:

- ZFS + ZFSBootMenu (boot environments e rollback do sistema)
- Samba (SMB-only como padrão) integrado ao Active Directory
- Máxima compatibilidade com Windows (ACLs gerenciáveis via aba Security)
- Alta performance e estabilidade operacional
- Replicação do físico para VM standby e failover automático ativo+passivo

NFS existe apenas como exceção e NUNCA deve compartilhar o mesmo dataset com SMB no modo padrão.

## 2) Hardware alvo inicial (baseline)

Servidor físico:

- Dell PowerEdge 2950
- 32 GiB RAM
- 2× CPU octa-core
- Controladora RAID Dell PERC (sem JBOD)
- 6× SAS 600 GiB 15k
- NICs: 2×1Gb onboard + 2×10Gb (placa dual)

## 3) Storage/RAID: decisão fixa

Como não há JBOD, a redundância real fica na controladora.

Decisão:

- Criar 1 Virtual Disk usando todos os 6 discos em RAID10.
- Habilitar write-back (somente com proteção/estado saudável), pois write-back melhora latência percebida e throughput de escrita; write-through é mais conservador e tende a ser mais lento.
- NÃO dividir discos em VDs distintos para SO/dados no baseline.

## 4) ZFS: layout e regras

Pool:

- Nome padrão: tank (pode ser configurável)

Datasets (exemplo):

- tank/ROOT/debian → Boot Environment (sistema)
- tank/SYS/samba-state → estado Samba/AD (segredos/keytab/tdb etc.) separado do ROOT
- tank/SHARES/<share_name> → 1 dataset por share SMB

Regras:

- Cada Boot Environment deve ser exatamente 1 filesystem/dataset (coerência de snapshot/rollback).
- Dados de shares nunca devem ficar dentro do dataset de ROOT (para rollback do sistema não afetar dados).
- Propriedades recomendadas para SMB-only em cada dataset de share:
  - acltype=posixacl
  - xattr=sa (fortemente recomendado com posixacl para performance de xattr/ACL)
  - atime=off
- NÃO habilitar dedup no baseline; dedup tem custo alto e pode degradar severamente.
- NÃO alterar recordsize sem benchmark; mudar recordsize em FS de uso geral é desencorajado e pode piorar performance.

ZFSBootMenu:

- Configurar para preferir o pool explicitamente com `zbm.prefer=<pool>!`.
- Syslinux só existe como "ponte" para BIOS legacy quando necessário.

## 5) Samba: SMB-only (padrão)

Perfil padrão do produto: SMB-only com Windows-first ACL.

VFS modules:

- `vfs objects = acl_xattr streams_xattr`
- `acl_xattr:ignore system acls = yes` (SMB-only)

Justificativa:

- `acl_xattr` armazena ACL NT em xattr `security.NTACL` e recomenda `ignore system acls=yes` quando dados são acessados somente via Samba.
- `streams_xattr` implementa NTFS Alternate Data Streams via xattrs (compatibilidade Windows).

Protocolos:

- Desabilitar SMB1; usar SMB2/SMB3.

SMB Multichannel:

- Habilitar multichannel e validar no Windows.

Templates:

- artifacts/templates/smb/smb.conf.smb-only.template
- (Exceção) SMB+NFS: ignore system acls = no (somente se for inevitável)
- (Exceção) NFS-only: dataset separado

Validação Linux:

- Usar /usr/local/sbin/validate_ad_smb.sh (script do projeto)
- `smbcacls` pode ler/alterar ACLs NT em shares SMB e tem opções como `--maximum-access`.

## 6) AD + Kerberos + Alias/VIP (fixo)

Serviço para clientes:

- alias/VIP: fileserver
- FQDN: fileserver.empresa.com.br
- DNS: registro A fileserver.empresa.com.br → VIP

Nós:

- EMPRESA-BM-NAS (bare metal)
- EMPRESA-VM-NAS (standby VM)

Identidade dedicada do serviço (AD computer account):

- EMPRESA\EMPRESA-FILESERVER$

SPNs:

- cifs/fileserver
- cifs/fileserver.empresa.com.br
- Gerenciar via setspn; usar -S e checar duplicidades com -X.

Runbooks:

- docs/30_AD_JOIN_AND_ALIAS.md
- docs/31_RUNBOOK_FILESERVICE_FILESERVERSMB_AD.md
- docs/32_AD_OBJECTS_CHECKLIST.md

## 7) Jump Box (AD-side automation)

Jump Box:

- Windows Server 2019
- Acesso preferido: SSH por chave (conta AD)

Conta AD para automação:

- EMPRESA\svc-nas-automation (preferido; não-admin local)

Automação AD-side:

- artifacts/scripts/ad_setup_fileserver.ps1 (dry-run default; -Apply para mudanças; gera JSON)
- Execução a partir do Debian:
  - artifacts/scripts/ad_precheck_fileserver.sh (wrapper: hostkey pinning, upload/run/download, SHA256, rotação)

Docs:

- docs/34_JUMPBOX_SETUP.md
- docs/35_JUMPBOX_SSH_KEYS.md
- docs/37_JUMPBOX_WS2019_AD_KEYAUTH.md

## 8) Replicação + Failover (ativo/passivo)

Objetivo:

- Replicar tank/SHARES (recursivo) + tank/SYS/samba-state do físico para a VM standby
- RPO: definido pelo cron do syncoid
- Failover: ativo+passivo via Pacemaker/Corosync + VIP

Método:

- syncoid (zfs send/receive automatizado)
- Pacemaker/Corosync para VIP + fencing (STONITH obrigatório)
- Ordem de resources: VIP → import/mount ZFS → Samba → Winbind

## 9) Qualidade de código e CI/CD (fixo)

Qualidade local (antes do commit):

- pre-commit com shfmt + shellcheck + gitleaks
- PSScriptAnalyzer para PowerShell (settings em PSScriptAnalyzerSettings.psd1)
- Testes bash (bats ou shellspec)

CI:

- GitHub Actions com shell lint (sh-checker)
- PSScriptAnalyzer job
- Build ISO (job pesado, apenas em merge/release)

IA/Agentes:

- VS Code + Continue (regras locais em .continue/rules)

## 10) Proibição e limites

- Nunca armazenar credenciais AD na ISO.
- Nunca depender de CNAME para o alias padrão (usar A record).
- Nunca exportar NFS sobre o mesmo dataset usado por SMB no modo padrão.
- Nunca habilitar dedup sem benchmark em produção.
- SMB1 (NT1) proibido em produção.
