# AGENTS.md - Aurora OS Build System

**IDIOMA:** Comunicar-se sempre em **Português (pt_BR)**.

## OVERVIEW

Debian-based ISO builder via Docker + live-build: modular SquashFS layers, ZFSBootMenu bootloader, Gum TUI installer.

## STRUCTURE

```
./
├── Makefile                    # Orchestration (build/test/vm)
├── docker/
│   ├── config/                 # live-build configs + hooks + layers
│   └── tools/                  # Dockerfile, build-iso-in-docker.sh
├── include/usr/local/bin/      # Installer scripts overlay
├── tools/                      # download-zfsbootmenu.sh, download-gum.sh
├── qemu/tools/vm.sh            # QEMU/KVM VM manager (UEFI + BIOS)
├── tests/test_*.sh             # 18 test scripts
└── docs/                       # Architecture docs
```

## WHERE TO LOOK

| Task                 | Location                                      |
| -------------------- | --------------------------------------------- |
| Adicionar pacotes    | `docker/config/layers/*.list.chroot`          |
| Configurar ISO       | `docker/config/binary` (boot params)          |
| Customizar chroot    | `docker/config/hooks/live/*.hook.chroot`      |
| Configurar ZFS       | `docker/config/hooks/live/0100-*.hook.chroot` |
| Modificar instalador | `include/usr/local/bin/install-aurora.sh`     |
| Testar build         | `tests/test_*.sh` (execute `make test`)       |
| Testar VM            | `qemu/tools/vm.sh --start-uefi`               |
| Ajustar Docker       | `docker/tools/Dockerfile`                     |

## CODE MAP

- **Entry point:** `Makefile` → `make build`
- **Build orchestrator:** `docker/tools/build-iso-in-docker.sh` (Docker wrapper)
- **Installer:** `include/usr/local/bin/install-aurora.sh` (1918 lines - Gum TUI)
- **VM manager:** `qemu/tools/vm.sh` (266 lines - QEMU/KVM)
- **Layers:** `docker/config/layers/00-core.list.chroot` → 01 → 10 → 20
- **SquashFS:** `docker/config/hooks/normal/0990-modular-squashfs.hook.binary`
- **ZFS:** `docker/config/hooks/live/0100-compile-zfs-dkms.hook.chroot`

## CONVENTIONS

### Shell Scripts

```bash
#!/usr/bin/env bash
set -euo pipefail  # Strict mode obrigatório
```

- **Cores:** `C_RESET`, `C_CYAN`, `C_GREEN`, `C_YELLOW`, `C_RED` (readonly)
- **Logging:** `log_info()`, `log_ok()`, `log_warn()`, `log_error()`
- **Nomenclatura:** `readonly NOME="valor"` (constantes), `local var_name` (locais)
- **Cleanup:** `trap '[[ -d ${TEMP_DIR} ]] && rm -rf "${TEMP_DIR}"' EXIT`

### live-build

- **Arquivos list:** `NN-descrição.list.chroot` (NN = ordem)
- **Hooks live:** `NNNN-descrição.hook.chroot` (shebang `#!/bin/sh`)
- **Hooks binary:** `NNNN-descrição.hook.binary` (squashfs = 0990)
- **Variáveis LB_:** `LB_BOOTAPPEND_LIVE`, `LB_COMPRESSION="none"`

### Localização

- Textos usuário: **Português (pt_BR.UTF-8)**
- Comentários código: Inglês (preferido)
- Fuso: `America/Cuiaba`, Teclado: `br`

## ANTI-PATTERNS

- **NUNCA** usar `set -e` fora de hooks (quebra live-build)
- **NUNCA** modificar `LB_BUILD_WITH_CHROOT="false"` (segurança)
- **NUNCA** instalar plymouth (quebra boot params sem splash)
- **NUNCA** pacotes com versão fixa (`pacote=1.2.3`)
- **NUNCA** pacotes de teste em `00-core` (layer base imutável)
- **NUNCA** misturar layers sem ordem (00 → 01 → 10 → 20)
- **NUNCA** usar hooks > 5000 sem revisar (conflito upstream)
- **NUNCA** deixar blocos catch vazios

## COMMANDS

### Build

```bash
make build              # Constrói ISO (Docker, inclui deps)
make prepare            # Baixa ZFSBootMenu + Gum
make clean              # Limpa build e VM
make fix-permissions    # Corrige permissões docker/include
```

### Teste

```bash
make test               # Executa TODOS os testes
./tests/test_*.sh       # Teste individual
```

### VM Testing

```bash
make vm-uefi/bios       # Boot ISO (UEFI/BIOS)
make vm-test-uefi       # Boot do disco (pós-install)
make vm-raidz[1-3]      # Boot ISO com 3/4/5 discos
./qemu/tools/vm.sh --check  # Verifica dependências VM
```

## NOTES

- `docker/config/hooks/normal/` contém symlinks upstream (não modificar)
- Squashfs modular: `/live/filesystem.squashfs.*` (separado por layers)
- `LB_COMPRESSION="none"` em config/binary (comprimido no hook 0990)
- `config/bootstrap`, `config/chroot` são autogerados (não editar)
- `package-lists/` ≠ `layers/` (não duplicar conteúdo)
- DKMS ZFS compilado em `hooks/live/0100-compile-zfs-dkms.hook.chroot`
- Docker roda como `--privileged` (requerido para live-build)

## VERIFICATION PRÉ-COMMIT

1. `make test` - Todos os testes passam
2. `make build` - ISO constrói com sucesso
3. `make vm-uefi` - Se mudou comportamento de VM

## SEM CONFIGURAÇÕES EXTERNAS

Este projeto NÃO possui:

- `.cursor/rules/`, `.cursorrules`
- `.github/copilot-instructions.md`
- ESLint/Prettier/TypeScript configs

Seguir os padrões documentados acima.
