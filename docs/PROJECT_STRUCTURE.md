# Estrutura do Projeto `build-iso`

**Última revisão:** 2026-02-04  
**Status:** Documentação atualizada para refletir estrutura real do projeto

---

## Visão Geral

Este documento descreve a organização de diretórios do projeto e serve como guia para novos colaboradores e para a automação do pipeline de build ISO Debian com ZFS-on-root e ZFSBootMenu.

> **Nota:** A estrutura do projeto passou por refatorações. Verifique sempre este documento em vez de depender de documentação desatualizada.

---

## Diretórios Raiz

### 📁 `config-overrides/` ⭐ (Configuração Live-Build)

Contém a configuração do `live-build` com overrides para personalização:

```
config-overrides/
├── auto/
│   ├── build              # Script executado durante build
│   ├── clean              # Script de limpeza
│   └── config             # Configuração automática
├── config/
│   ├── binary             # Configuração imagem binária
│   ├── bootstrap          # Configuração bootstrap
│   ├── chroot             # Configuração chroot
│   ├── source             # Configuração source
│   └── hooks/
│       └── live/
│           ├── 0050-fix-syslinux.hook.binary
│           ├── 0100-compile-zfs-dkms.hook.chroot
│           └── 0100-install-zfs.hook.chroot
├── includes.binary/
│   ├── EFI/BOOT/BOOTX64.EFI
│   └── zbm/
│       └── vmlinuz
└── includes.chroot/
    ├── etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
    └── usr/local/bin/
        ├── gum
        └── install-zfs-debian
```

### 📁 `scripts/` ⭐ (Automação)

Scripts de automação para build, download de binários e testes:

```
scripts/
├── download-gum.sh                   # Download binário Gum (CLI)
├── download-zfsbootmenu.sh           # Download binários ZFSBootMenu
├── docker/
│   ├── README_DOCKER.md          # Guia de configuração Docker
│   ├── Dockerfile                # Imagem do builder
│   └── entrypoint.sh             # Ponto de entrada do container
└── vm/
    ├── vm-start-test-all.sh          # Testa BIOS + UEFI simultaneamente
    ├── vm-start-test-boot-disk.sh    # Testa boot com disco
    ├── vm-start-test-boot-iso.sh     # Testa boot via ISO
    ├── vm-connect-agent-llm.sh        # Gateway serial para agentes LLM
    ├── vm-setup.sh                   # Setup de dependências KVM
    └── disks/
```

### 📁 `conductor/` (Metadados e Planejamento)

Metadados e especificações do projeto (framework Conductor):

```
conductor/
├── code_styleguides/
│   └── general.md
├── product.md                        # Descrição do produto
├── product-guidelines.md             # Diretrizes do produto
├── setup_state.json                  # Estado do setup
├── tech-stack.md                     # Stack tecnológico
├── tracks/                           # Trilhas de desenvolvimento
│   ├── advanced_installer_gum_20260106/
│   ├── iso_pipeline_20260105/
│   ├── trixie_iso_pipeline_20260106/
│   └── vm_test_automation_20260106/
└── workflow.md                       # Workflow do projeto
```

### 📁 `docs/` ⭐ (Documentação)

Documentação técnica e arquitetural:

```
docs/
├── PROJECT_STRUCTURE.md              # Este documento
├── ARCHITECTURE.md                   # Arquitetura do projeto
├── "Architectural Blueprint..."       # Blueprint detalhado (inglês)
├── PRD.md                            # Product Requirements Document
├── PROPOSTA-DEBIAN-ZFS.md            # Proposta técnica original
├── INSTALLER_GUIDE.md                # Guia do instalador
├── INSTALLER_ARCHITECTURE.md         # Arquitetura modular do instalador
├── INSTALLER_JUNIOR_PLAYBOOK.md      # Playbook para equipe junior
├── MAPA_INSTALLER.md                 # Mapa técnico do instalador
├── DESIGN_SYSTEM_v2.0.md             # Design System monocromático
├── SCRIPTS_TESTS_INVENTORY.md        # Inventário de scripts/testes
├── AI_SPEC_DRIVEN_WORKFLOW.md         # Workflow AI/Spec-driven
├── BUGFIX_REPORT.md                  # Relatório de correções
├── IMPLEMENTATION_REPORT.md           # Relatório de implementação
├── 00_SOURCE_OF_TRUTH.md             # Fonte da verdade (NAS/Samba/AD)
├── 10_SMB_STACK.md                   # Pilha SMB (VFS, ACLs, multichannel)
├── 20_ZFS_DATASET_TEMPLATES.md       # Templates ZFS (5 cenários)
├── 30_AD_JOIN_AND_ALIAS.md           # AD join, SPNs, DNS
├── 31_RUNBOOK_FILESERVICE_...md      # Runbook completo SMB+AD
├── 32_AD_OBJECTS_CHECKLIST.md        # Checklist de objetos AD
├── 35_JUMPBOX_SSH_KEYS.md            # SSH keys para jump box
├── 36_POWERSHELL_OVER_SSH_...md      # PowerShell over SSH
├── 40_FAILOVER_REPLICATION.md        # HA: Syncoid + Pacemaker
├── ROADMAP.md                        # Roadmap unificado (8 fases)
└── HANDOFF_PROMPT_NEW_SESSION.md     # Contexto para novas sessões LLM
```

### 📁 `tests/` (Suite de Testes)

Scripts de teste automatizados (Bash):

| Script                        | Propósito                       |
| ----------------------------- | ------------------------------- |
| `test_docker_cmd.sh`          | Testa comandos Docker           |
| `test_docker_env.sh`          | Valida ambiente Docker          |
| `test_installer_presence.sh`  | Verifica presença do instalador |
| `test_iso_build.sh`           | Valida build da ISO             |
| `test_iso_pool_structure.sh`  | Testa estrutura de pool ZFS     |
| `test_iso_structure.sh`       | Valida estrutura da ISO         |
| `test_lb_config.sh`           | Testa configuração live-build   |
| `test_package_lists.sh`       | Verifica listas de pacotes      |
| `test_project_structure.sh`   | Valida estrutura do projeto     |
| `test_vm_boot_validation.sh`  | Valida boot em VM               |
| `test_vm_dependencies.sh`     | Verifica dependências de VM     |
| `test_vm_disk_size.sh`        | Testa tamanho de disco          |
| `test_vm_disk.sh`             | Testa configuração de disco     |
| `test_vm_kvm.sh`              | Valida suporte KVM              |
| `test_vm_uefi.sh`             | Testa boot UEFI                 |
| `test_wrapper_permissions.sh` | Verifica permissões             |
| `test_zbm_hook.sh`            | Testa hooks do ZBM              |

### 📁 `plan/` (Blueprints e Propostas)

Blueprints arquiteturais e propostas iniciais:

| Arquivo                                                         | Descrição                   |
| --------------------------------------------------------------- | --------------------------- |
| `001 - Plan: ZFSBootMenu Integration (Refactoring).md`          | Integração ZFSBootMenu      |
| `002 - PROPOSTA-DEBIAN-ZFS.md`                                  | Proposta inicial Debian ZFS |
| `003 - Plan: ANALISE-CRITICA-PROPOSTA.md`                       | Análise crítica             |
| `004 - Plan: Automatizar download para BINARIES ZFSBOOTMENU.md` | Automação de download       |

### 📁 `archived/` (Arquivo Histórico)

Documentos e tarefas arquivados:

```
archived/
└── 000 - Tasks: TODO_FIXES_20260106.md
```

---

## Artefatos e Processamento (Gerados Automaticamente)

### 📁 `live-build-workspace/`

Área de trabalho do live-build (criada durante build):

```
live-build-workspace/
├── config/           # Configuração gerada
├── chroot/           # Ambiente chroot
├── binary/           # Imagem binária
└── .build/           # Metadados de build
```

### 📁 `logs/`

Logs de execução (criados automaticamente):

```
logs/
└── test-YYYYMMDD-HHMMSS/  # Logs de teste
```

### 📁 `output/`

Artefatos de build finalizados:

```
output/
└── *.iso                    # Imagens ISO geradas
```

---

## 📋 Comparativo: Documentação Antiga vs. Estrutura Atual

| Documentação Antiga         | Estrutura Real           | Status                                     |
| --------------------------- | ------------------------ | ------------------------------------------ |
| `config/`                   | `config-overrides/`      | ✅ Corrigido                               |
| `docker/`                   | `scripts/docker/`        | ✅ Corrigido                               |
| `plans/`                    | `plan/` (sem 's')        | ✅ Corrigido                               |
| `auto/`                     | `config-overrides/auto/` | ✅ Corrigido                               |
| `docker/artifacts/`         | `live-build-workspace/`  | ✅ Corrigido                               |
| `work/`                     | Não existe como descrito | ℹ️ Substituído por `live-build-workspace/` |
| `zbm-binaries/`             | Baixado via script       | ℹ️ Gerenciado dinamicamente                |
| `scripts/scripts_exemplos/` | Removido                 | ❌                                         |
| ❌                          | `conductor/`             | 🆕 Adicionado                              |
| ❌                          | `archived/`              | 🆕 Adicionado                              |
| ❌                          | `artifacts/`             | 🆕 Artefatos NAS                           |
| ❌                          | `labels/`                | 🆕 Labels GitHub                            |
| ❌                          | `.pre-commit-config.yaml`| 🆕 Hooks de qualidade                       |
| ❌                          | `.editorconfig`          | 🆕 Padronização formato                     |

---

## Interface de Comandos (Makefile)

O projeto oferece uma interface unificada via [`Makefile`](Makefile):

| Categoria         | Comandos Make                                                |
| :---------------- | :----------------------------------------------------------- |
| **Build**         | `make download-zbm`, `make setup-docker`, `make build-iso`   |
| **VM Setup**      | `make setup-vm`                                              |
| **VM Testes**     | `make test-vm-uefi`, `make test-vm-bios`, `make test-vm-all` |
| **VM Conexão**    | `make vm-connect-uefi`, `make vm-connect-bios`               |
| **Gerenciamento** | `make vm-list`, `make vm-destroy`, `make clean`              |
| **NAS / AD**      | `make validate-ad`, `make ad-precheck`, `make validate-configs`, `make lint` |
| **Documentação** | `make docs`, `make verify-docs`, `make docs-markdown`         |

Execute `make help` para ver todos os comandos disponíveis.

---

## Guia para Colaboradores

| Necessidade                     | Onde Encontrar                                                    |
| :------------------------------ | :---------------------------------------------------------------- |
| Adicionar pacotes na ISO        | `config-overrides/config/package-lists/`                          |
| Adicionar arquivos customizados | `config-overrides/config/includes.chroot/`                        |
| Scripts de automação            | `scripts/`                                                        |
| Documentação de VMs             | `scripts/vm/README_VM.md`                                         |
| Documentação de Docker          | `scripts/docker/README_DOCKER.md`                                 |
| Arquitetura detalhada           | `docs/ARCHITECTURE.md`                                            |
| Blueprint completo              | `docs/Architectural Blueprint...md`                               |
| **Arquitetura NAS**             | `docs/00_SOURCE_OF_TRUTH.md`                                      |
| **Roadmap do projeto**          | `docs/ROADMAP.md`                                                 |
| **Artefatos NAS**               | `artifacts/` (templates, scripts, specs)                          |

---

## ⚠️ Observações

- `docs/CONNECT_VM_TEST.md` foi movido para [`scripts/vm/README_VM.md`](scripts/vm/README_VM.md)
- `scripts/scripts_exemplos/` foi removido do projeto

---

## 📌 Referências

- [`Makefile`](Makefile) - Interface de comandos
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) - Arquitetura técnica
- [`docs/ROADMAP.md`](docs/ROADMAP.md) - Roadmap unificado
- [`docs/00_SOURCE_OF_TRUTH.md`](docs/00_SOURCE_OF_TRUTH.md) - Fonte da verdade NAS
- [`scripts/vm/README_VM.md`](scripts/vm/README_VM.md) - Guia de testes em VM
- [`scripts/docker/README_DOCKER.md`](scripts/docker/README_DOCKER.md) - Guia Docker
- [`AGENTS.md`](AGENTS.md) - Base de conhecimento para agentes LLM

---

_Última atualização: 2026-02-11_
