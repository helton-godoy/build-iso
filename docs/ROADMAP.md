# Roadmap — Projeto NAS Debian (ZFS + Samba/AD + ZFSBootMenu + HA)

Este roadmap unifica as duas trilhas do projeto: **ISO/Instalador** e **NAS Corporativo**.

## Fase 0 — Guardrails (obrigatório antes de avançar)

Critérios de aceite:

- pre-commit habilitado (shfmt, shellcheck, gitleaks, PSScriptAnalyzer)
- CI "lint" passando em PR
- docs/00_SOURCE_OF_TRUTH.md atualizado como gate

Entregas:

- `.pre-commit-config.yaml`
- `.github/workflows/lint.yml`
- `PSScriptAnalyzerSettings.psd1`
- `.editorconfig`
- `labels/labels.json`

Status: 🔄 Artefatos criados, CI configurado — pendente ativação e teste

---

## Fase 1 — ISO MVP (live-build + ZFS + ZFSBootMenu)

Critérios de aceite:

- ISO live-build gera e boota em VM (UEFI + BIOS)
- Módulos ZFS DKMS compilados durante build
- Binários ZFSBootMenu injetados na ISO
- ISO híbrida UEFI+BIOS gerada

Entregas:

- Pipeline Docker de build (Makefile: `make build-iso`)
- Scripts de download ZBM (`scripts/download-zfsbootmenu.sh`)
- Testes VM automatizados (`make test-vm-all`)

Status: 🔄 Build funcional, testes em desenvolvimento

---

## Fase 2 — Instalador Automatizado (ZFS-on-root)

Critérios de aceite:

- Script `install-zfs-debian` implementado
- Detecção automática de firmware (UEFI/BIOS)
- Particionamento híbrido implementado
- Criação de pool ZFS e datasets
- ZFSBootMenu funcional com menu de boot environments

Entregas:

- Instalador interativo (`gum`-based)
- Suite de testes do instalador (`tests/test_installer_*.sh`)

Status: 🔄 Refatorado com gum, em desenvolvimento

---

## Fase 3 — NAS SMB-only + AD Join

Critérios de aceite:

- SMB-only com AD join e ACL editável via Windows (Security tab)
- `validate_ad_smb.sh` passa no nó ativo (Linux-side)
- Template smb.conf funcional
- First-boot wizard idempotente
- Documentação de operação mínima

Entregas:

- `artifacts/templates/smb/smb.conf.smb-only.template`
- `artifacts/scripts/validate_ad_smb.sh`
- First-boot wizard (AD join, datasets, Samba config)
- Docs: `10_SMB_STACK.md`, `30_AD_JOIN_AND_ALIAS.md`, `32_AD_OBJECTS_CHECKLIST.md`

Status: ⏳ Documentação criada, implementação pendente

---

## Fase 4 — Jump Box + Automação AD-side

Critérios de aceite:

- Scripts PowerShell para setup DNS/SPN via Jump Box
- Wrapper Debian-side funcional (SSH ou WinRM)
- Relatório JSON gerado com status de cada operação

Entregas:

- `artifacts/scripts/ad_precheck_fileserver.sh` (wrapper)
- `artifacts/scripts/ad_setup_fileserver.ps1` (PowerShell AD-side)
- Docs: `35_JUMPBOX_SSH_KEYS.md`, `36_POWERSHELL_OVER_SSH_SUBSYSTEM.md`

Status: ⏳ Wrapper criado, script PowerShell pendente

---

## Fase 5 — Hardening + Observabilidade

Critérios de aceite:

- Logs padronizados (`/var/log/my-nas`)
- Métricas básicas (samba/zfs/disk/network)
- Threat model mínimo (segredos, chaves, AD automation)
- Auto-tuning ZFS baseado em hardware (ARC, prefetch)

Entregas:

- Hardening docs
- Alertas básicos e runbooks
- Script de auto-tuning ZFS (`/etc/modprobe.d/zfs.conf`)

Status: ⏳ Pendente

---

## Fase 6 — HA Ativo/Passivo + Replicação

Critérios de aceite:

- Replicação física → VM (RPO definido via syncoid)
- Failover automático (VIP + ZFS mount + Samba) com fencing (STONITH)
- SPNs fixos na identidade `EMPRESA-FILESERVER$` (não mover em failover)

Entregas:

- Pacemaker/Corosync configs
- Runbook de failover (`docs/40_FAILOVER_REPLICATION.md`)
- Testes de caos (poweroff, link down)

Status: ⏳ Documentação criada, implementação pendente

---

## Fase 7 — Validação Final + Hardware Real

Critérios de aceite:

- Testes em hardware real (Dell PowerEdge 2950)
- Boot UEFI/BIOS validado
- SMB multichannel funcional com 10Gb NICs
- Documentação completa para operação

Entregas:

- Relatórios de validação
- Docs de operação e recovery
- Guia para usuário final

Status: ⏳ Pendente
