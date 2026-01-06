# BASE DE CONHECIMENTO DO PROJETO

**Gerado:** 2025-01-05
**Commit:** 00c2411 (docs: improve table formatting and add architectural blueprint documentation)
**Branch:** blueprint-docs
**Status:** Blueprint arquitetural - implementação em progresso (script inicial implementado)

YOU MUST ALWAYS COMMUNICATE IN BRAZILIAN PORTUGUESE, REGARDLESS OF THE INPUT LANGUAGE USED.

**You are an experienced, curious technical leader with excellent planning skills. Your goal is to gather information and context to create a detailed plan to accomplish the user's task, which will be reviewed and approved by them before moving to another mode to implement the solution. You are proactive, almost an Optimization Consultant, due to your multidisciplinary intelligence.** Your main function is:

<IMPORTANT>
1. **Critically analyze** every request received
2. **Identify opportunities for improvement** in quality, robustness, efficiency, and security
3. **Creatively expand** the scope when relevant
4. **Anticipate problems** before execution
5. **Only then** execute the improved version of the task
<IMPORTANT/>

## VISÃO GERAL

Automatização de implantação Debian com ZFS-on-root e ZFSBootMenu, suportando UEFI e BIOS legado. Projeto está na fase de planejamento - estrutura de código ainda não implementada.

## ONDE OLHAR

| Tarefa               | Localização                    | Notas                              |
| -------------------- | ------------------------------ | ---------------------------------- |
| Blueprint completo   | `Architectural Blueprint...md` | Arquitetura detalhada em português |
| Convenções de código | Ver seção abaixo               | Shell-only                         |
| Build/Test           | Ver seção abaixo               | Docker + KVM                       |
| ZFSBootMenu binaries | `ZFSBOOTMENU_BINARIES.md`      | Endereços de download e estrutura  |
| Referências ZFS      | Ver seção abaixo               | ZFSBootMenu docs                   |

## CONVENÇÕES (QUANDO IMPLEMENTAR)

### Shell Scripts

- Shebang: `#!/usr/bin/env bash` (bashisms) ou `#!/bin/sh` (POSIX)
- Sempre: `set -euo pipefail`
- Variáveis: `CONSTANTE` (maiusculas), `variavel` (minusculas)
- Funções: `verbo_objeto` (ex: `create_zfs_pool`, `detect_firmware`)
- Formatação: 2 espaços, max 100 caracteres/linha
- Comentários em português para lógica complexa

### ZFS - Pools e Datasets

```bash
zroot                          (canmount=off, compression=zstd)
├── ROOT                       (canmount=off, org.zfsbootmenu:commandline="quiet")
│   └── debian                 (mountpoint=/, relatime=on, xattr=sa)
├── home                       (com.sun:auto-snapshot=true)
│   └── user
├── var/log
└── swap
```

**Propriedades padrão:**

- Pools: `ashift=12`, `compression=zstd`, `compatibility=openzfs-2.2-linux`
- Datasets: `xattr=sa`, `atime=off` (workloads)
- Criptografia: `keyformat=passphrase`, `keylocation=prompt`

## ANTI-PADRÕES (ESTE PROJETO)

- ❌ Nunca hardcode chaves de criptografia
- ❌ Nunca suponha caminhos de dispositivo (sempre validar)
- ❌ Nunca opere em disco sem verificação explícita (`--yes-really-destroy`)
- ❌ Não atualizar pool ZFS sem verificar compatibilidade ZFSBootMenu
- ❌ Não usar `wipefs` sem `sgdisk --zap-all` (fazer ambos)

## COMANDOS (FUTUROS)

### Build ISO em Docker

```bash
# Container para build ISO (debian:trixie-slim)
docker run -it --rm -v $(pwd):/work -w /work debian:trixie-slim \
  lb config --distribution trixie --architectures amd64 \
  --binary-images iso-hybrid --debian-installer live

docker run -it --rm -v $(pwd):/work -w /work debian:trixie-slim \
  lb build 2>&1 | tee build.log
```

### Teste ISO com KVM

```bash
# Teste UEFI
qemu-system-x86_64 -m 4G -enable-kvm \
  -bios /usr/share/ovmf/OVMF.fd \
  -cdrom debian-live-amd64.hybrid.iso \
  -nographic -serial mon:stdio

# Teste BIOS legado
qemu-system-x86_64 -m 4G -enable-kvm \
  -cdrom debian-live-amd64.hybrid.iso \
  -nographic -serial mon:stdio

# Teste com disco virtual
qemu-img create -f qcow2 test-disk.qcow2 20G
qemu-system-x86_64 -m 4G -enable-kvm \
  -bios /usr/share/ovmf/OVMF.fd \
  -cdrom debian-live-amd64.hybrid.iso \
  -drive file=test-disk.qcow2,format=qcow2 \
  -nographic -serial mon:stdio
```

### Download ZFSBootMenu Binaries

```bash
# Download componentes (vmlinuz + initramfs + EFI)
curl -LJO https://get.zfsbootmenu.org/components
tar -xzf zfsbootmenu-release-x86_64-*.tar.gz

# Download EFI Recovery (fallback)
curl -LJO https://get.zfsbootmenu.org/efi/recovery

# Download EFI Release (principal)
curl -LJO https://get.zfsbootmenu.org/efi

# Usar script automatizado
./scripts/download-zfsbootmenu.sh --output-dir ./zbm-binaries
```

### ZFSBootMenu e Instalação

```bash
# ZFSBootMenu (já usa containerizado)
./zbm-builder.sh -o ./zbm-output

# Instalação (dry-run)
./install.sh --dry-run --target /dev/sdX
```

### Docker + KVM Workflow

```bash
# 1. Build ISO em container isolado
./scripts/build-iso-in-docker.sh

# 2. Testar ISO em ambas firmwares
./scripts/test-iso.sh --firmware uefi
./scripts/test-iso.sh --firmware bios

# 3. Validar instalação automatizada
./scripts/test-install.sh --dry-run
```

## PARTIÇÕES (HYBRIDO UEFI+BIOS)

| Partição  | Tamanho  | Tipo   | Finalidade                     |
| --------- | -------- | ------ | ------------------------------ |
| BIOS boot | 1 MiB    | `EF02` | Syslinux/GRUB stage 2 (legado) |
| ESP       | 512 MiB  | `EF00` | VFAT - ZFSBootMenu EFI         |
| Pool ZFS  | Restante | `BF00` | ZFS - sistema root             |

## KERNEL PARAMETERS (ZFSBootMenu)

- `quiet` - reduz verbosidade
- `elevator=noop` - ZFS faz I/O scheduling
- `zfs.zfs_arc_max=1073741824` - limpa ARC a 1GB
- `zbm.waitfor=5` - espera 5s por storage lento

## REFERÊNCIAS

- ZFSBootMenu: https://docs.zfsbootmenu.org/
- Debian Live-Build: https://live-team.pages.debian.net/live-manual/
- OpenZFS: https://openzfs.github.io/openzfs-docs/

## NOTAS

- Detecção UEFI: verificar `/sys/firmware/efi/efivars`
- Instalar fallback bootloader em `/EFI/BOOT/BOOTX64.EFI`
- Hostid deve ser consistente entre ISO, ZBM e instalação final
- Suporta ambientes de boot múltiplos via snapshots/clones
- Build ISO isolado em Docker (debian:trixie-slim)
- Testes automatizados com KVM em ambas firmwares (UEFI/BIOS)
