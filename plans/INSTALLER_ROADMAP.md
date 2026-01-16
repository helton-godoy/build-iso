## Status Atual do Projeto

- **Fases 1 a 8**: ✅ Concluídas e validadas (ver `docs/INSTALLER_IMPLEMENTATION_COMPLETE.md`)
- **Fase Atual**: 🚀 Ingressando na **Fase 10: Funcionalidades Enterprise Premium Gold**

---

## Objetivo Atual

Implementar as funcionalidades de elite que diferenciam o DEBIAN_ZFS:

- **Criptografia Nativa ZFS**: Proteção total de dados com performance.
- **Perfis Inteligentes**: Instalação customizada para Server ou Workstation.
- **Ambientes de Boot (BE)**: Suporte completo a rollbacks via snapshots.
- ZFS-on-Root com todas as opções do Proxmox
- ZFSBootMenu como bootloader
- Suporte a RAID-Z com múltiplos discos
- Interface TUI premium com Gum
- Instalação 100% offline

---

## Estrutura de Arquivos

```
config/includes.chroot/usr/local/bin/
├── install-DEBIAN_ZFS.sh          # Instalador principal (novo)
└── install-zfs-debian         # Legado (remover após migração)
```

---

## Fases de Implementação

### Fase 1: Infraestrutura Base

**Status:** ⬜ Não iniciado | **Prioridade:** P0 (Crítica)

| ID  | Tarefa                       | Descrição                        | Critérios de Aceite                                           |
| --- | ---------------------------- | -------------------------------- | ------------------------------------------------------------- |
| 1.1 | Criar `install-DEBIAN_ZFS.sh`    | Arquivo principal do instalador  | Arquivo criado, shebang correto, `set -euo pipefail`          |
| 1.2 | Implementar logging          | Funções `log()` e `error_exit()` | Logs em `/var/log/DEBIAN_ZFS-installer.log`, mensagens formatadas |
| 1.3 | Implementar cleanup          | Função `cleanup()` com trap      | Desmonta filesystems, exporta pool em caso de erro            |
| 1.4 | Implementar preflight_checks | Verificações de pré-requisitos   | Verifica root, módulo ZFS, memória, comandos                  |

---

### Fase 2: Interface TUI (Gum)

**Status:** ⬜ Não iniciado | **Prioridade:** P0 (Crítica)

| ID  | Tarefa                | Descrição                                       | Critérios de Aceite                                    |
| --- | --------------------- | ----------------------------------------------- | ------------------------------------------------------ |
| 2.1 | welcome_screen        | Tela de boas-vindas                             | Logo, descrição, confirmação para continuar            |
| 2.2 | select_disks          | Seleção de discos                               | Lista discos, permite seleção múltipla, valida seleção |
| 2.3 | select_topology       | Seleção de topologia RAID                       | Mostra opções válidas para qtd de discos               |
| 2.4 | configure_zfs_options | Opções avançadas ZFS                            | ashift, compression, checksum, copies, hdsize          |
| 2.5 | collect_info          | Coleta informações (hostname, username, senhas) | Senhas validadas com gum                               |
| 2.6 | select_profile        | Selecionar Perfil: SERVER vs WORKSTATION        | Define pacotes e configs gráficas                      |
| 2.7 | configure_encryption  | Configurar Criptografia Nativa ZFS              | Escolher ON/OFF, coletar passphrase                    |
| 2.8 | confirm_installation  | Resumo e confirmação final                      | Proteção contra destruição acidental                   |

---

### Fase 3: Preparação do Disco

**Status:** ⬜ Não iniciado | **Prioridade:** P0 (Crítica)

| ID  | Tarefa             | Descrição                      | Critérios de Aceite                          |
| --- | ------------------ | ------------------------------ | -------------------------------------------- |
| 3.1 | prepare_disks      | Limpar e particionar discos    | wipefs, sgdisk, partprobe em TODOS os discos |
| 3.2 | Partição BIOS Boot | Criar partição EF02 (1M)       | Para boot legacy                             |
| 3.3 | Partição EFI       | Criar partição EF00 (512M)     | Para UEFI boot                               |
| 3.4 | Partição ZFS       | Criar partição BF00 (restante) | Para pool ZFS                                |
| 3.5 | Suporte a hdsize   | Limitar tamanho usado          | Respeitar limite se definido                 |

---

### Fase 4: Configuração ZFS

**Status:** ⬜ Não iniciado | **Prioridade:** P0 (Crítica)

| ID  | Tarefa                   | Descrição                                 | Critérios de Aceite                                 |
| --- | ------------------------ | ----------------------------------------- | --------------------------------------------------- |
| 4.1 | load_zfs_module          | Carregar módulo ZFS                       | modprobe zfs, verificar sucesso                     |
| 4.2 | create_pool              | Criar pool ZFS                            | Usar opções selecionadas (ashift, compression, etc) |
| 4.3 | Suporte a topologias     | mirror, raidz1, raidz2, raidz3            | Criar pool com topologia selecionada                |
| 4.4 | create_datasets          | Criar hierarquia (ROOT/debian, home, etc) | Suporte a Boot Environments (BE)                    |
| 4.5 | setup_encryption         | Aplicar criptografia nativa               | AES-256-GCM se selecionado                          |
| 4.6 | Propriedades de datasets | Aplicar propriedades ZFS                  | mountpoint, canmount, com.sun:auto-snapshot         |

**Hierarquia de Datasets:**

```
zroot/
├── ROOT/
│   └── debian (mountpoint=/)
├── home (mountpoint=/home)
│   └── root (mountpoint=/root)
└── var (canmount=off)
    ├── log
    ├── cache (auto-snapshot=false)
    └── tmp (auto-snapshot=false)
```

---

### Fase 5: Extração do Sistema

**Status:** ⬜ Não iniciado | **Prioridade:** P0 (Crítica)

| ID  | Tarefa                      | Descrição                        | Critérios de Aceite                           |
| --- | --------------------------- | -------------------------------- | --------------------------------------------- |
| 5.1 | extract_system              | Extrair sistema do squashfs      | unsquashfs obrigatório, erro se não encontrar |
| 5.2 | Validar squashfs            | Verificar existência do arquivo  | Mensagem de erro clara se ausente             |
| 5.3 | Criar diretórios essenciais | /dev, /proc, /sys, /run, /tmp    | Permissões corretas (1777 em /tmp)            |
| 5.4 | Barra de progresso          | Feedback visual durante extração | gum spin                                      |

**Caminhos do squashfs:**

```bash
squashfs_paths=(
    "/run/live/medium/live/filesystem.squashfs"
    "/lib/live/mount/medium/live/filesystem.squashfs"
    "/cdrom/live/filesystem.squashfs"
)
```

---

### Fase 6: Configuração Chroot

**Status:** ⬜ Não iniciado | **Prioridade:** P0 (Crítica)

| ID  | Tarefa                   | Descrição                        | Critérios de Aceite        |
| --- | ------------------------ | -------------------------------- | -------------------------- |
| 6.1 | mount_chroot_filesystems | Montar /dev, /proc, /sys, /run   | --make-private --rbind     |
| 6.2 | configure_hostname       | Configurar hostname e /etc/hosts | Arquivo válido             |
| 6.3 | configure_users          | Criar usuário e definir senhas   | chpasswd, sudo group       |
| 6.4 | configure_locales        | Configurar locale e timezone     | pt_BR.UTF-8 como padrão    |
| 6.5 | configure_fstab          | Gerar /etc/fstab                 | Entrada para dataset root  |
| 6.6 | generate_hostid          | Gerar /etc/hostid                | zgenhostid                 |
| 6.7 | update_initramfs         | Regenerar initramfs              | update-initramfs -u -k all |

---

### Fase 7: Instalação ZFSBootMenu

**Status:** ⬜ Não iniciado | **Prioridade:** P0 (Crítica)

| ID  | Tarefa                | Descrição                   | Critérios de Aceite         |
| --- | --------------------- | --------------------------- | --------------------------- |
| 7.1 | format_esp            | Formatar partição EFI       | mkfs.vfat -F 32             |
| 7.2 | mount_esp             | Montar ESP em /boot/efi     | mkdir -p, mount             |
| 7.3 | copy_zbm_binaries     | Copiar binários ZFSBootMenu | De /usr/share/zfsbootmenu   |
| 7.4 | configure_efi         | Criar entrada EFI           | efibootmgr -c               |
| 7.5 | configure_commandline | Definir propriedade ZFS     | org.zfsbootmenu:commandline |

---

### Fase 8: Finalização

**Status:** ⬜ Não iniciado | **Prioridade:** P0 (Crítica)

| ID  | Tarefa          | Descrição                      | Critérios de Aceite       |
| --- | --------------- | ------------------------------ | ------------------------- |
| 8.1 | create_snapshot | Criar snapshot inicial         | zroot/ROOT/debian@install |
| 8.2 | unmount_all     | Desmontar todos os filesystems | Ordem inversa, sem erros  |
| 8.3 | export_pool     | Exportar pool ZFS              | zpool export zroot        |
| 8.4 | success_message | Exibir mensagem de sucesso     | Instruções para reboot    |

---

### Fase 9: Qualidade e Testes

**Status:** ⬜ Não iniciado | **Prioridade:** P1 (Alta)

| ID  | Tarefa                 | Descrição                           | Critérios de Aceite   |
| --- | ---------------------- | ----------------------------------- | --------------------- |
| 9.1 | Validação de sintaxe   | bash -n, shellcheck                 | Zero erros            |
| 9.2 | Teste UEFI single disk | VM QEMU UEFI, 1 disco               | Boot completo         |
| 9.3 | Teste UEFI mirror      | VM QEMU UEFI, 2 discos              | Mirror funcional      |
| 9.4 | Teste UEFI raidz1      | VM QEMU UEFI, 3 discos              | RAIDZ1 funcional      |
| 9.5 | Teste BIOS             | VM QEMU BIOS                        | Boot legacy funcional |
| 9.6 | Teste offline          | Sem rede na VM                      | Instalação completa   |
| 9.7 | Teste de rollback      | Criar snapshot, modificar, rollback | Sistema restaurado    |

---

### Fase 10: Funcionalidades Futuras

**Status:** ⬜ Backlog | **Prioridade:** P2 (Média)

| ID   | Tarefa                  | Descrição                                |
| ---- | ----------------------- | ---------------------------------------- |
| 10.1 | Integração LDAP/AD      | Join automático ao domínio (Workstation) |
| 10.2 | SSH no Bootloader       | Remote unlock via SSH                    |
| 10.3 | Suporte a Secure Boot   | Assinatura de módulos e binários         |
| 10.4 | Instalação automatizada | Arquivo de resposta (preseed-like)       |
| 10.5 | GUI com Calamares       | Alternativa gráfica completa             |

---

## Métricas de Qualidade

### Critérios Enterprise Premium Gold

| Categoria            | Requisito           | Métrica                            |
| -------------------- | ------------------- | ---------------------------------- |
| **Confiabilidade**   | Zero crashes        | 100% das instalações bem-sucedidas |
| **Performance**      | Instalação rápida   | < 5 min em SSD NVMe                |
| **Usabilidade**      | Interface intuitiva | Usuário completa sem documentação  |
| **Manutenibilidade** | Código limpo        | Shellcheck sem warnings            |
| **Documentação**     | Auto-documentado    | Comentários em todas as funções    |
| **Testabilidade**    | Cobertura de testes | Todos os cenários testados         |
| **Offline**          | Sem internet        | 100% funcional offline             |

---

## Dependências

### No Live System

| Pacote           | Propósito                |
| ---------------- | ------------------------ |
| `gum`            | Interface TUI            |
| `zfsutils-linux` | Comandos ZFS             |
| `squashfs-tools` | unsquashfs (obrigatório) |
| `gdisk`          | Particionamento GPT      |
| `dosfstools`     | Formatação FAT32         |
| `efibootmgr`     | Configuração EFI         |
| `rsync`          | Fallback para cópia      |

### Na ISO

| Componente         | Localização                    |
| ------------------ | ------------------------------ |
| ZFSBootMenu EFI    | `/usr/share/zfsbootmenu/*.EFI` |
| Sistema comprimido | `/live/filesystem.squashfs`    |
| Módulos ZFS        | Pré-compilados via DKMS        |

---

## Comandos de Desenvolvimento

```bash
# Rebuild da ISO
./scripts/build-iso-in-docker.sh

# Testar em VM UEFI
./scripts/test-iso.sh uefi --create-disk test.qcow2 --disk-size 20G

# Validar sintaxe do instalador
bash -n config/includes.chroot/usr/local/bin/install-DEBIAN_ZFS.sh

# Shellcheck
shellcheck config/includes.chroot/usr/local/bin/install-DEBIAN_ZFS.sh
```

---

## Changelog

| Data       | Versão | Mudança                             |
| ---------- | ------ | ----------------------------------- |
| 2026-01-07 | 1.0    | Documento criado com todas as fases |

---

## Notas para Continuidade

> **IMPORTANTE:** Este documento contém todas as informações necessárias para continuar o desenvolvimento do instalador DEBIAN_ZFS. Qualquer desenvolvedor (humano ou IA) pode usar este roadmap para implementar as funcionalidades pendentes.

### Contexto Essencial

1. **Problema Original:** O instalador anterior (`install-zfs-debian`) crashava durante a criação do pool ZFS
2. **Decisão:** Reescrever do zero baseado no pve-zol
3. **Método de instalação:** unsquashfs (não debootstrap)
4. **Bootloader:** ZFSBootMenu (não GRUB)
5. **Interface:** Gum TUI

### Arquivos de Referência

- `/home/helton/git/build-iso/docs/INSTALLER_ARCHITECTURE.md` - Arquitetura e decisões
- `/home/helton/git/build-iso/plans/Architectural Blueprint...md` - Blueprint original
- `/home/helton/git/build-iso/AGENTS.md` - Convenções de código
