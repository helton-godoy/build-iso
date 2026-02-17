---
name: virsh-expert
description: Expert in virsh/libvirt for KVM/QEMU VM management. Enables LLM agent to interact with VMs: lifecycle, command execution, diagnostics, storage, snapshots, network, boot/GRUB and serial console.
argument-hint: virsh|vm|kvm|qemu|libvirt|virt-install|guest-agent|send-key|virtual machine|snapshot|serial console|boot vm|grub vm
---

# Virsh Expert

## Ecosystem Synergy

| Skill             | Sinergia                                                                                                                                     |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `shell-gum-elite` | Scripts de VM seguem os padrões de arquitetura, logging e UX desta skill. Combine para criar automações interativas de gerenciamento de VMs. |
| `pure-bash-bible` | Parse de saída virsh, manipulação de strings e arrays. Evita dependências externas no processamento de resultados.                           |

## Pré-requisitos

```bash
# Core (geralmente já instalado no host)
sudo apt install libvirt-daemon-system virtinst qemu-utils qemu-system-x86

# Dentro da VM (para guest-exec)
sudo apt install qemu-guest-agent

# Permissões do usuário
sudo usermod -aG libvirt,kvm "$USER"
```

## Contexto do Projeto build-iso

Este projeto utiliza VMs KVM para testar imagens ISO Debian Live com ZFS-on-root:

| Recurso            | Valor                                        |
| ------------------ | -------------------------------------------- |
| VMs de teste       | `nas-test-uefi`, `nas-test-bios`             |
| Socket serial UEFI | `/tmp/nas-test-uefi.sock`                    |
| Socket serial BIOS | `/tmp/nas-test-bios.sock`                    |
| Discos por VM      | 4 × 10GB qcow2 em `scripts/vm/disks/{mode}/` |
| Cache de IPs       | `scripts/vm/.cache/vm-ips.env`               |
| Hostname live      | `debian-trixie-zbm-<tipo>-<firmware>`        |

### Makefile Targets

```bash
make setup-vm              # Instala dependências KVM
make test-vm-uefi          # Inicia VM UEFI com ISO + 4 discos
make test-vm-bios          # Inicia VM BIOS com ISO + 4 discos
make test-vm-all           # Ambas em paralelo
make vm-connect-uefi CMD="..." # Executa comando remoto na VM UEFI
make vm-connect-bios CMD="..." # Executa comando remoto na VM BIOS
make vm-list               # Lista VMs em execução
make vm-destroy            # Destrói VMs ativas
```

## Core Workflow — Fluxo Típico do Agente

```bash
# 1. Verificar estado das VMs
virsh list --all

# 2. Iniciar VM (via Makefile — preferencial)
make test-vm-uefi

# 3. Aguardar boot e detectar IP
virsh domifaddr nas-test-uefi

# 4. Executar comando dentro da VM (via SSH)
make vm-connect-uefi CMD="lsblk -f && zpool status"

# 5. Interação com boot (se necessário)
virsh send-key nas-test-uefi KEY_ENTER

# 6. Diagnóstico
virsh dominfo nas-test-uefi
virsh domstats nas-test-uefi

# 7. Desligamento
virsh shutdown nas-test-uefi
```

## Feature Map

| Área           | Padrão Preferido                        | Motivo                                       |
| -------------- | --------------------------------------- | -------------------------------------------- |
| Listar VMs     | `virsh list --all`                      | Visão completa: ativas + inativas            |
| Iniciar VM     | `make test-vm-*` ou `virt-install`      | Idempotente, com cleanup prévio              |
| Desligar VM    | `virsh shutdown` (graceful)             | Preserva filesystem; `destroy` em emergência |
| IP da VM       | `virsh domifaddr` → `net-dhcp-leases`   | Fast path + fallback robusto                 |
| Comando remoto | SSH via `make vm-connect-*`             | Não-interativo, com bootstrap automático     |
| Comando guest  | `virsh qemu-agent-command` (guest-exec) | Sem rede, mas sem stdin interativo           |
| Teclas no boot | `virsh send-key KEY_*`                  | Funciona antes do SO carregar                |
| Console serial | `nc -U /tmp/nas-test-*.sock`            | Acesso direto ao TTY                         |
| Discos         | `qemu-img create -f qcow2`              | Formato padrão do projeto                    |
| Snapshots      | `virsh snapshot-create-as`              | Save-state antes de testes destrutivos       |
| Monitoramento  | `virsh dominfo` + `domstats`            | Métricas de CPU, memória, I/O                |
| Clonagem       | `virt-clone`                            | Replicação rápida de ambientes               |
| Segurança      | Prefixo `nas-test-*` + blocklist        | Escopo restrito para agentes LLM             |

## Regras de Segurança para Agentes LLM

> **CRÍTICO**: O agente opera sob restrições de segurança:

1. **Escopo de VMs**: Apenas VMs com prefixo `nas-test-` são permitidas
2. **Blocklist de comandos**: Nunca executar `rm -rf /`, `dd if=/dev/zero`, `shutdown` do host
3. **Validação de entrada**: Sanitizar nomes de VM e parâmetros antes de `subprocess`
4. **Menor privilégio**: Usar grupo `libvirt`, nunca root desnecessariamente
5. **Timeout**: Operações com limite de tempo; `virsh destroy` como fusível de segurança
6. **Auditoria**: Logar toda operação virsh executada pelo agente

## Embedded Tools

| Script                                                         | Uso                                  | Propósito                                     |
| -------------------------------------------------------------- | ------------------------------------ | --------------------------------------------- |
| [scripts/virsh-health-check.sh](scripts/virsh-health-check.sh) | `bash scripts/virsh-health-check.sh` | Diagnóstico rápido de todas as VMs do projeto |

## Reference Files

| Arquivo                                                                      | Conteúdo                                                            |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| [references/vm-lifecycle.md](references/vm-lifecycle.md)                     | Ciclo de vida: listar, criar, iniciar, parar, destruir, definir VMs |
| [references/guest-execution.md](references/guest-execution.md)               | Execução dentro da VM: guest-agent, SSH, console serial             |
| [references/network-detection.md](references/network-detection.md)           | Detecção de rede/IP: domifaddr, DHCP leases, cache                  |
| [references/boot-interaction.md](references/boot-interaction.md)             | Interação com GRUB/boot: send-key, console serial                   |
| [references/storage-management.md](references/storage-management.md)         | Discos, pools, volumes, qemu-img                                    |
| [references/snapshot-backup.md](references/snapshot-backup.md)               | Snapshots, clones, backup de configuração                           |
| [references/monitoring-diagnostics.md](references/monitoring-diagnostics.md) | Monitoramento, métricas, diagnóstico, logs                          |
| [references/security-safety.md](references/security-safety.md)               | Segurança, sandbox, blocklist para agentes LLM                      |
| [references/project-integration.md](references/project-integration.md)       | Integração com scripts/Makefile do projeto build-iso                |
