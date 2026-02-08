# Inventário de Scripts e Testes

**Data da Análise:** 2026-02-08  
**Última Atualização:** 2026-02-08  
**Commit Base:** 00c2411  
**Branch:** blueprint-docs  
**Analista:** Sisyphus AI

---

## Sumário Executivo

### Visão Geral (ATUALIZADA)

| Categoria                | Total | Funcionais | Obsoletos | Refatorados |
| ------------------------ | ----- | ---------- | --------- | ----------- |
| **Scripts**              | 9     | 9 (100%)   | 0         | 3 ✅        |
| **Testes Automatizados** | 22    | 14 (64%)   | 8 (36%)   | 8 ✅        |
| **Testes Manuais**       | 1     | 1 (100%)   | 0         | 0           |

### Status Pós-Refatoração

✅ **CONCLUÍDO** - Scripts `vm-connent-*.sh` renomeados para `vm-connect-*.sh`
✅ **CONCLUÍDO** - 8 testes refatorados com caminhos atualizados
✅ **CONCLUÍDO** - `test_iso_qemu.sh` convertido para modo não-interativo (CI-compatível)
✅ **CONCLUÍDO** - 4 testes obsoletos irrecuperáveis removidos
⚠️ **PENDENTE** - 8 testes ainda requerem reescrita para novos scripts VM

### Changelog (2026-02-08)

#### Scripts Renomeados
- `vm-connect-socket.sh` → `vm-connect-socket.sh`
- `vm-connect-ssh.sh` → `vm-connect-ssh.sh`
- `vm-connect-agent-llm.sh` → `vm-connect-agent-llm.sh`

#### Testes Refatorados
- `test_docker_env.sh` - Caminho: scripts/docker/Dockerfile, Pacotes: zfsutils-linux
- `test_package_lists.sh` - Caminho: config-overrides/config/package-lists/
- `test_zbm_hook.sh` - Caminho: config-overrides/config/hooks/
- `test_installer_presence.sh` - Caminho: config-overrides/..., Verificação: gum
- `test_iso_build.sh` - Caminho: output/*.iso
- `test_project_structure.sh` - REESCRITO para nova estrutura
- `validate_iso_installer.sh` - Caminhos atualizados para installer/libs/
- `test_iso_qemu.sh` - Interatividade removida, aceita argumento [uefi|bios|all]

#### Testes Removidos (Obsoletos Irrecuperáveis)
- `test_docker_cmd.sh` - Dependia de scripts/build-iso-in-docker.sh
- `test_wrapper_permissions.sh` - Dependia de scripts/build-iso-in-docker.sh
- `test_vm_disk_size.sh` - Coberto por vm-start-test-boot-iso.sh
- `manual/validate_ui.sh` - Dependia de scripts/lib/fileserver-ds.sh

---

## Parte 1: Inventário de Scripts

### 1.1 Scripts de Download

#### download-gum.sh

| Atributo                  | Valor                                                                    |
| ------------------------- | ------------------------------------------------------------------------ |
| **Localização**           | `scripts/download-gum.sh`                                                |
| **Linhas**                | 54                                                                       |
| **Propósito**             | Download binário estático Gum (charmbracelet) para UI CLI interativa     |
| **Destino**               | `config-overrides/config/includes.chroot/usr/local/bin/gum`              |
| **Fluxo**                 | API GitHub → detecta versão → baixa tar.gz Linux x86_64 → extrai → copia |
| **Dependências**          | curl, tar, GitHub API (api.github.com)                                   |
| **Complexidade**          | Baixa                                                                    |
| **Estado**                | ✅ FUNCIONAL                                                             |
| **Problema Identificado** | Padrão de extração `gum_*/gum` pode falhar se estrutura tar mudar        |
| **Recomendação**          | **MANTER** - Adicionar fallback para variações de estrutura              |

#### download-zfsbootmenu.sh

| Atributo         | Valor                                                                                 |
| ---------------- | ------------------------------------------------------------------------------------- |
| **Localização**  | `scripts/download-zfsbootmenu.sh`                                                     |
| **Linhas**       | 120                                                                                   |
| **Propósito**    | Download binários ZFSBootMenu (EFI + BIOS) para live-build                            |
| **Destinos**     | `includes.binary/EFI/BOOT/BOOTX64.EFI`, `includes.binary/zbm/{vmlinuz,initramfs.img}` |
| **Fluxo**        | Detecta versão via redirect/API → baixa EFI release → baixa tarball → extrai          |
| **Dependências** | curl (--retry 3), tar, GitHub API                                                     |
| **Logging**      | `logs/download-zfsbootmenu.log`                                                       |
| **Complexidade** | Média                                                                                 |
| **Estado**       | ✅ FUNCIONAL - CRÍTICO PARA O PROJETO                                                 |
| **Recomendação** | **MANTER** - Componente central, bem implementado                                     |

#### extract-docs.sh

| Atributo         | Valor                                                                  |
| ---------------- | ---------------------------------------------------------------------- |
| **Localização**  | `scripts/extract-docs.sh`                                              |
| **Linhas**       | 51                                                                     |
| **Propósito**    | Extrai metadados @INST\_\* dos scripts do instalador para visualização |
| **Fonte**        | `includes.chroot/usr/local/lib/installer/{libs,steps}/*.sh`            |
| **Dependências** | Scripts do instalador com tags @INST\_\*                               |
| **Complexidade** | Baixa                                                                  |
| **Estado**       | ⚠️ FUNCIONAL (dependência parcial - steps/ vazio)                      |
| **Recomendação** | **MANTER** - Útil quando steps/\*.sh forem implementados               |

---

### 1.2 Scripts Docker

#### Dockerfile

| Atributo         | Valor                                                                                                                                                                                                                       |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Localização**  | `scripts/docker/Dockerfile`                                                                                                                                                                                                 |
| **Linhas**       | 28                                                                                                                                                                                                                          |
| **Base**         | `debian:trixie-slim`                                                                                                                                                                                                        |
| **Pacotes**      | live-build, debootstrap, squashfs-tools, xorriso, isolinux, syslinux-common, grub-efi-amd64-bin, grub-pc-bin, mtools, dosfstools, zstd, build-essential, dkms, linux-headers-amd64, locales, zfsutils-linux, gum (charm.sh) |
| **Locale**       | pt_BR.UTF-8                                                                                                                                                                                                                 |
| **Complexidade** | Baixa                                                                                                                                                                                                                       |
| **Estado**       | ✅ FUNCIONAL                                                                                                                                                                                                                |
| **Otimização**   | Single RUN layer (eficiente)                                                                                                                                                                                                |
| **Recomendação** | **MANTER**                                                                                                                                                                                                                  |

#### entrypoint.sh

| Atributo           | Valor                                                                     |
| ------------------ | ------------------------------------------------------------------------- |
| **Localização**    | `scripts/docker/entrypoint.sh`                                            |
| **Linhas**         | 40                                                                        |
| **Propósito**      | Orquestra build ISO dentro do container Docker                            |
| **Fluxo**          | Sync config-overrides → workspace → lb config → lb build → move ISO       |
| **Logging**        | `/build/logs/live-build-YYYYMMDD-HHMM.log`                                |
| **Complexidade**   | Média                                                                     |
| **Estado**         | ✅ FUNCIONAL                                                              |
| **Problema Menor** | Move _.contents/_.zsync para `/build/build/` (diretório pode não existir) |
| **Recomendação**   | **MANTER** - Corrigir criação de diretório destino                        |

---

### 1.3 Scripts de VM

#### vm-setup.sh

| Atributo         | Valor                                                                                        |
| ---------------- | -------------------------------------------------------------------------------------------- |
| **Localização**  | `scripts/vm/vm-setup.sh`                                                                     |
| **Linhas**       | 23                                                                                           |
| **Propósito**    | Instala dependências de virtualização no host                                                |
| **Pacotes**      | qemu-kvm, qemu-utils, qemu-system-x86, libvirt-\*, bridge-utils, virtinst, virt-viewer, ovmf |
| **Grupos**       | Adiciona usuário a libvirt, kvm                                                              |
| **Logging**      | `logs/vm-setup.log`                                                                          |
| **Complexidade** | Baixa                                                                                        |
| **Estado**       | ✅ FUNCIONAL                                                                                 |
| **Recomendação** | **MANTER**                                                                                   |

#### vm-start-test-all.sh

| Atributo         | Valor                                                                          |
| ---------------- | ------------------------------------------------------------------------------ |
| **Localização**  | `scripts/vm/vm-start-test-all.sh`                                              |
| **Linhas**       | 42                                                                             |
| **Propósito**    | Inicia testes BIOS + UEFI simultaneamente (paralelo)                           |
| **Fluxo**        | Dispara vm-start-test-boot-iso.sh {uefi,bios} em background → captura 30s boot |
| **Dependências** | vm-start-test-boot-iso.sh, vm-connect-agent-llm.sh                             |
| **Logging**      | `logs/test-YYYYMMDD/`                                                          |
| **Complexidade** | Média                                                                          |
| **Estado**       | ✅ FUNCIONAL                                                                   |
| **Recomendação** | **MANTER**                                                                     |

#### vm-start-test-boot-disk.sh

| Atributo          | Valor                                                                                |
| ----------------- | ------------------------------------------------------------------------------------ |
| **Localização**   | `scripts/vm/vm-start-test-boot-disk.sh`                                              |
| **Linhas**        | 150                                                                                  |
| **Propósito**     | Iniciar VM a partir de disco instalado (não ISO)                                     |
| **Argumentos**    | `-f/--firmware` (uefi\|bios), `-m/--memory`, `-c/--cpus`, `-n/--name`, `<disk-path>` |
| **Fluxo**         | Valida disco (qemu-img info) → limpa VM anterior → virt-install                      |
| **Socket Serial** | `/tmp/${vm_name}.sock`                                                               |
| **Complexidade**  | Alta                                                                                 |
| **Estado**        | ✅ FUNCIONAL                                                                         |
| **Uso**           | Testar sistema após instalação ZFS                                                   |
| **Recomendação**  | **MANTER**                                                                           |

#### vm-start-test-boot-iso.sh

| Atributo         | Valor                                                                           |
| ---------------- | ------------------------------------------------------------------------------- |
| **Localização**  | `scripts/vm/vm-start-test-boot-iso.sh`                                          |
| **Linhas**       | 75                                                                              |
| **Propósito**    | Iniciar VM de teste com ISO + 4 discos virtuais (simulação NAS)                 |
| **Argumentos**   | mode (uefi\|bios)                                                               |
| **Fluxo**        | Encontra ISO em output/ → cria 4 discos 10GB → limpa VM anterior → virt-install |
| **Discos**       | `scripts/vm/disks/{mode}/disk{1-4}.qcow2` (10GB cada)                           |
| **VM Name**      | `nas-test-{mode}`                                                               |
| **Socket**       | `/tmp/nas-test-{mode}.sock`                                                     |
| **Complexidade** | Alta                                                                            |
| **Estado**       | ✅ FUNCIONAL                                                                    |
| **Uso**          | Essencial para testes de instalação                                             |
| **Recomendação** | **MANTER**                                                                      |

#### vm-connect-socket.sh ⚠️

| Atributo         | Valor                                                  |
| ---------------- | ------------------------------------------------------ |
| **Localização**  | `scripts/vm/vm-connect-socket.sh`                      |
| **Linhas**       | 38                                                     |
| **Propósito**    | Conexão serial pura via socket Unix (nc)               |
| **Modos**        | Enviar comando (timeout 5s) ou escutar interativamente |
| **Socket**       | `/tmp/nas-test-{mode}.sock`                            |
| **Complexidade** | Baixa                                                  |
| **Estado**       | ✅ FUNCIONAL                                           |
| **Problema**     | ✅ CORRIGIDO - Typo 'connent' → 'connect'     |
| **Recomendação** | **MANTER** - Renomeado com sucesso                       |

#### vm-connect-ssh.sh ⚠️

| Atributo         | Valor                                                                                              |
| ---------------- | -------------------------------------------------------------------------------------------------- |
| **Localização**  | `scripts/vm/vm-connect-ssh.sh`                                                                     |
| **Linhas**       | 300                                                                                                |
| **Propósito**    | Conexão SSH automatizada com fallback para serial                                                  |
| **Features**     | Detecta rede (virsh domiflist) → obtém IP (net-dhcp-leases) → verifica SSH → copia chave → conecta |
| **Variáveis**    | USE_SSH, FORCE_SSH_KEY, SSH_USER, VM_IP                                                            |
| **Timeout DHCP** | 30s                                                                                                |
| **Complexidade** | Alta                                                                                               |
| **Estado**       | ✅ FUNCIONAL                                                                                       |
| **Problema**     | ✅ CORRIGIDO - Typo 'connent' → 'connect'                                                 |
| **Recomendação** | **MANTER** - Renomeado com sucesso                                                                   |

#### vm-connect-agent-llm.sh ⚠️

| Atributo         | Valor                                                                                   |
| ---------------- | --------------------------------------------------------------------------------------- |
| **Localização**  | `scripts/vm/vm-connect-agent-llm.sh`                                                    |
| **Linhas**       | 80                                                                                      |
| **Propósito**    | Gateway para agentes LLM interagirem com VM                                             |
| **Features**     | Auto-bootstrap SSH via serial (copia chave, configura sshd, habilita root login)        |
| **Variáveis**    | AUTO_BOOTSTRAP_SSH, VM_CMD, VM_IP, VM_SSH_PASSWORD                                      |
| **Fluxo**        | Garante chave local → detecta IP → bootstrap via serial → delega para vm-connect-ssh.sh |
| **Complexidade** | Média                                                                                   |
| **Estado**       | ✅ FUNCIONAL                                                                            |
| **Problema**     | ✅ CORRIGIDO - Typo 'connent' → 'connect'                                      |
| **Recomendação** | **MANTER** - Renomeado com sucesso                                                        |

---

## Parte 2: Inventário de Testes

### 2.1 Testes Docker

#### test_docker_cmd.sh

| Atributo                   | Valor                                                                 |
| -------------------------- | --------------------------------------------------------------------- |
| **Localização**            | `tests/test_docker_cmd.sh`                                            |
| **Propósito**              | Testa comando lb dentro do container                                  |
| **Dependências**           | scripts/build-iso-in-docker.sh (❌ NÃO EXISTE)                        |
| **Caminhos Referenciados** | docker/artifacts/logs/lb-build.log (❌ OBSOLETO)                      |
| **Estado**                 | ❌ OBSOLETO                                                           |
| **Recomendação**           | **DESCARTAR ou REESCREVER** - Adaptar para novo workflow via Makefile |

#### test_docker_env.sh

| Atributo                   | Valor                                                    |
| -------------------------- | -------------------------------------------------------- |
| **Localização**            | `tests/test_docker_env.sh`                               |
| **Propósito**              | Valida Dockerfile (base, pacotes)                        |
| **Caminhos Referenciados** | docker/Dockerfile (❌ agora é scripts/docker/Dockerfile) |
| **Pacotes Verificados**    | live-build, git (❌ git removido), curl                  |
| **Estado**                 | ❌ OBSOLETO                                              |
| **Recomendação**           | **REFATORAR** - Atualizar caminho e lista de pacotes     |

---

### 2.2 Testes do Instalador

#### test_install_plan_guardrails.sh

| Atributo           | Valor                                                             |
| ------------------ | ----------------------------------------------------------------- |
| **Localização**    | `tests/test_install_plan_guardrails.sh`                           |
| **Propósito**      | Testa funções de validação do install-plan-utils.sh               |
| **Casos de Teste** | Bloqueio sobreposição discos, exigência mirror log, config válida |
| **Dependências**   | core-utils.sh, state-utils.sh, install-plan-utils.sh              |
| **Estado**         | ✅ FUNCIONAL                                                      |
| **Recomendação**   | **MANTER**                                                        |

#### test_install_plan_state.sh

| Atributo           | Valor                                                                          |
| ------------------ | ------------------------------------------------------------------------------ |
| **Localização**    | `tests/test_install_plan_state.sh`                                             |
| **Propósito**      | Testa state-utils.sh e install-plan-utils.sh                                   |
| **Casos de Teste** | state_kv_set/get com espaços, estado legado, assinatura de plano, idempotência |
| **Estado**         | ✅ FUNCIONAL                                                                   |
| **Recomendação**   | **MANTER**                                                                     |

#### test_installer_flow_consistency.sh

| Atributo           | Valor                                                                           |
| ------------------ | ------------------------------------------------------------------------------- |
| **Localização**    | `tests/test_installer_flow_consistency.sh`                                      |
| **Propósito**      | Testa install_plan_preflight do steps/install.sh                                |
| **Casos de Teste** | Preflight passa/falha com assinatura consistente/divergente, topologia inválida |
| **Estado**         | ✅ FUNCIONAL                                                                    |
| **Recomendação**   | **MANTER**                                                                      |

#### test_installer_partitioning.sh

| Atributo                   | Valor                                                                                   |
| -------------------------- | --------------------------------------------------------------------------------------- |
| **Localização**            | `tests/test_installer_partitioning.sh`                                                  |
| **Propósito**              | Testa partitioning.sh e disk-detection.sh                                               |
| **Requisito**              | Disco real (/dev/vda) - TESTE DESTRUTIVO                                                |
| **Caminhos Referenciados** | scripts/lib/installer/ (❌ NÃO EXISTE - agora includes.chroot/usr/local/lib/installer/) |
| **Estado**                 | ❌ OBSOLETO                                                                             |
| **Recomendação**           | **REFATORAR** - Atualizar caminho base                                                  |

#### test_installer_presence.sh

| Atributo                   | Valor                                                       |
| -------------------------- | ----------------------------------------------------------- |
| **Localização**            | `tests/test_installer_presence.sh`                          |
| **Propósito**              | Verifica existência do script install-zfs-debian            |
| **Caminhos Referenciados** | config/includes.chroot/ (❌ agora config-overrides/config/) |
| **Estado**                 | ❌ OBSOLETO                                                 |
| **Recomendação**           | **REFATORAR** - Atualizar caminho base                      |

#### test_installer_zfs.sh

| Atributo                   | Valor                                                   |
| -------------------------- | ------------------------------------------------------- |
| **Localização**            | `tests/test_installer_zfs.sh`                           |
| **Propósito**              | Testa zfs-setup.sh                                      |
| **Requisito**              | Dispositivo real (/dev/vda3) - TESTE DESTRUTIVO com ZFS |
| **Caminhos Referenciados** | scripts/lib/installer/ (❌ NÃO EXISTE)                  |
| **Estado**                 | ❌ OBSOLETO                                             |
| **Recomendação**           | **REFATORAR** - Atualizar caminho base                  |

---

### 2.3 Testes de ISO

#### test_iso_build.sh

| Atributo                   | Valor                                           |
| -------------------------- | ----------------------------------------------- |
| **Localização**            | `tests/test_iso_build.sh`                       |
| **Propósito**              | Verifica se ISO foi gerada e tem >100MB         |
| **Caminhos Referenciados** | docker/artifacts/dist/\*.iso (❌ agora output/) |
| **Estado**                 | ❌ OBSOLETO                                     |
| **Recomendação**           | **REFATORAR** - Atualizar para output/\*.iso    |

#### test_iso_pool_structure.sh

| Atributo               | Valor                                                        |
| ---------------------- | ------------------------------------------------------------ |
| **Localização**        | `tests/test_iso_pool_structure.sh`                           |
| **Propósito**          | Valida estrutura ISO via xorriso                             |
| **Estrutura Esperada** | /pool, /dists, /live/vmlinuz, /live/initrd.img               |
| **Problema**           | /pool e /dists não são estruturas típicas de live ISO Debian |
| **Estado**             | ⚠️ PARCIALMENTE OBSOLETO                                     |
| **Recomendação**       | **REFATORAR** - Ajustar estrutura esperada para live ISO     |

#### test_iso_qemu.sh

| Atributo         | Valor                                                           |
| ---------------- | --------------------------------------------------------------- |
| **Localização**  | `tests/test_iso_qemu.sh`                                        |
| **Linhas**       | 180                                                             |
| **Propósito**    | Teste de boot ISO com QEMU puro (sem libvirt)                   |
| **Features**     | Cria disco teste, testa UEFI (OVMF), testa BIOS, valida tamanho |
| **ISO Esperada** | output/live-image-amd64.hybrid.iso                              |
| **Problema**     | ⚠️ Usa `read -p` (interativo) - incompatível com CI             |
| **Estado**       | ⚠️ FUNCIONAL MAS INTERATIVO                                     |
| **Recomendação** | **REFATORAR** - Remover prompts interativos para CI             |

#### test_iso_structure.sh

| Atributo                 | Valor                                                                      |
| ------------------------ | -------------------------------------------------------------------------- |
| **Localização**          | `tests/test_iso_structure.sh`                                              |
| **Propósito**            | Valida estrutura ISO via xorriso                                           |
| **Estrutura Verificada** | /live/vmlinuz, initrd.img, filesystem.squashfs, /EFI/BOOT, ZFS em packages |
| **Estado**               | ✅ FUNCIONAL                                                               |
| **Recomendação**         | **MANTER**                                                                 |

---

### 2.4 Testes de Configuração Live-Build

#### test_lb_config.sh

| Atributo                   | Valor                                                                       |
| -------------------------- | --------------------------------------------------------------------------- |
| **Localização**            | `tests/test_lb_config.sh`                                                   |
| **Propósito**              | Valida config/binary, config/chroot, config/bootstrap                       |
| **Caminhos Referenciados** | config/ (❌ gerado em live-build-workspace/)                                |
| **Estado**                 | ❌ OBSOLETO                                                                 |
| **Recomendação**           | **REFATORAR** - Testar live-build-workspace/ pós-build ou config-overrides/ |

#### test_package_lists.sh

| Atributo                   | Valor                                                                   |
| -------------------------- | ----------------------------------------------------------------------- |
| **Localização**            | `tests/test_package_lists.sh`                                           |
| **Propósito**              | Valida listas de pacotes (zfs.list.chroot, tools.list.chroot)           |
| **Caminhos Referenciados** | config/package-lists/ (❌ agora config-overrides/config/package-lists/) |
| **Estado**                 | ❌ OBSOLETO                                                             |
| **Recomendação**           | **REFATORAR** - Atualizar caminho base                                  |

---

### 2.5 Testes de Estrutura do Projeto

#### test_project_structure.sh

| Atributo         | Valor                                                                           |
| ---------------- | ------------------------------------------------------------------------------- |
| **Localização**  | `tests/test_project_structure.sh`                                               |
| **Propósito**    | Valida estrutura docker/artifacts/{logs,dist,build,cache}                       |
| **Estado**       | ❌ OBSOLETO                                                                     |
| **Motivo**       | Estrutura docker/artifacts/ não existe mais                                     |
| **Recomendação** | **REESCREVER** - Validar nova estrutura (logs/, output/, live-build-workspace/) |

---

### 2.6 Testes de VM

#### test_vm_boot_validation.sh

| Atributo         | Valor                                                           |
| ---------------- | --------------------------------------------------------------- |
| **Localização**  | `tests/test_vm_boot_validation.sh`                              |
| **Propósito**    | Testa scripts/test-iso.sh                                       |
| **Dependências** | scripts/test-iso.sh (❌ NÃO EXISTE)                             |
| **Estado**       | ❌ OBSOLETO                                                     |
| **Recomendação** | **REESCREVER** - Adaptar para novos scripts vm-start-test-\*.sh |

#### test_vm_dependencies.sh

| Atributo         | Valor                                     |
| ---------------- | ----------------------------------------- |
| **Localização**  | `tests/test_vm_dependencies.sh`           |
| **Propósito**    | Testa scripts/test-iso.sh --check-deps    |
| **Estado**       | ❌ OBSOLETO                               |
| **Recomendação** | **REESCREVER** - Adaptar para vm-setup.sh |

#### test_vm_disk.sh

| Atributo         | Valor                                                   |
| ---------------- | ------------------------------------------------------- |
| **Localização**  | `tests/test_vm_disk.sh`                                 |
| **Propósito**    | Testa criação de disco via test-iso.sh                  |
| **Estado**       | ❌ OBSOLETO                                             |
| **Recomendação** | **REESCREVER** - Adaptar para vm-start-test-boot-iso.sh |

#### test_vm_disk_size.sh

| Atributo         | Valor                                                                |
| ---------------- | -------------------------------------------------------------------- |
| **Localização**  | `tests/test_vm_disk_size.sh`                                         |
| **Propósito**    | Testa tamanho de disco via test-iso.sh                               |
| **Estado**       | ❌ OBSOLETO                                                          |
| **Recomendação** | **DESCARTAR** - Funcionalidade coberta por vm-start-test-boot-iso.sh |

#### test_vm_kvm.sh

| Atributo         | Valor                                                          |
| ---------------- | -------------------------------------------------------------- |
| **Localização**  | `tests/test_vm_kvm.sh`                                         |
| **Propósito**    | Testa flags KVM via test-iso.sh dry-run                        |
| **Estado**       | ❌ OBSOLETO                                                    |
| **Recomendação** | **REESCREVER** - Validar vm-start-test-boot-iso.sh com libvirt |

#### test_vm_uefi.sh

| Atributo         | Valor                                                        |
| ---------------- | ------------------------------------------------------------ |
| **Localização**  | `tests/test_vm_uefi.sh`                                      |
| **Propósito**    | Testa UEFI/OVMF via test-iso.sh dry-run                      |
| **Estado**       | ❌ OBSOLETO                                                  |
| **Recomendação** | **REESCREVER** - Adaptar para vm-start-test-boot-iso.sh uefi |

---

### 2.7 Testes de Hooks e Wrappers

#### test_wrapper_permissions.sh

| Atributo         | Valor                                                  |
| ---------------- | ------------------------------------------------------ |
| **Localização**  | `tests/test_wrapper_permissions.sh`                    |
| **Propósito**    | Testa ownership de arquivos via build-iso-in-docker.sh |
| **Dependências** | scripts/build-iso-in-docker.sh (❌ NÃO EXISTE)         |
| **Estado**       | ❌ OBSOLETO                                            |
| **Recomendação** | **REESCREVER** - Testar via Makefile + scripts/docker/ |

#### test_zbm_hook.sh

| Atributo                   | Valor                                                        |
| -------------------------- | ------------------------------------------------------------ |
| **Localização**            | `tests/test_zbm_hook.sh`                                     |
| **Propósito**              | Valida hook de compilação ZFS DKMS                           |
| **Caminhos Referenciados** | config/hooks/live/ (❌ agora config-overrides/config/hooks/) |
| **Estado**                 | ❌ OBSOLETO                                                  |
| **Recomendação**           | **REFATORAR** - Atualizar caminho base                       |

---

### 2.8 Testes de Validação

#### validate_iso_installer.sh

| Atributo         | Valor                                                                                  |
| ---------------- | -------------------------------------------------------------------------------------- |
| **Localização**  | `tests/validate_iso_installer.sh`                                                      |
| **Linhas**       | 130                                                                                    |
| **Propósito**    | Validação completa ISO + instalador                                                    |
| **Verificações** | ISO existe >500MB, estrutura (EFI/ISOLINUX/LIVE/ZBM), binários ZBM, scripts, hooks     |
| **Problema**     | Referencia scripts/lib/installer/\*.sh e scripts/lib/fileserver-ds.sh (❌ NÃO EXISTEM) |
| **Estado**       | ⚠️ PARCIALMENTE OBSOLETO                                                               |
| **Recomendação** | **REFATORAR** - Lógica boa, atualizar caminhos                                         |

#### test-docs.sh

| Atributo         | Valor                                                                |
| ---------------- | -------------------------------------------------------------------- |
| **Localização**  | `tests/test-docs.sh`                                                 |
| **Linhas**       | 55                                                                   |
| **Propósito**    | Valida tags @INST_STEP_ID e @INST_STEP_FLOW em installer/steps/\*.sh |
| **Verificações** | Todos steps têm ID/FLOW, referências a IDs existentes                |
| **Estado**       | ✅ FUNCIONAL                                                         |
| **Caminho**      | Usa config-overrides/...installer/ (CORRETO)                         |
| **Recomendação** | **MANTER**                                                           |

---

### 2.9 Testes Manuais

#### manual/validate_ui.sh

| Atributo         | Valor                                                |
| ---------------- | ---------------------------------------------------- |
| **Localização**  | `tests/manual/validate_ui.sh`                        |
| **Propósito**    | Validação visual do Design System v2.0               |
| **Dependências** | scripts/lib/fileserver-ds.sh (❌ NÃO EXISTE)         |
| **Estado**       | ❌ OBSOLETO                                          |
| **Recomendação** | **DESCARTAR ou REFATORAR** - Dependência inexistente |

#### manual/validate_kmscon_ui_filters.sh

| Atributo         | Valor                                          |
| ---------------- | ---------------------------------------------- |
| **Localização**  | `tests/manual/validate_kmscon_ui_filters.sh`   |
| **Propósito**    | Checklist manual para validar UI em TTY/KMSCON |
| **Dependências** | Nenhuma (apenas imprime checklist)             |
| **Estado**       | ✅ FUNCIONAL                                   |
| **Recomendação** | **MANTER**                                     |

---

## Parte 3: Matriz de Ações

### 3.1 Ações por Prioridade

#### 🔴 URGENTE (Bloqueia CI/CD)

| Arquivo                      | Ação      | Esforço | Descrição                                                     |
| ---------------------------- | --------- | ------- | ------------------------------------------------------------- |
| `test_docker_env.sh`         | REFATORAR | Baixo   | Atualizar caminho para scripts/docker/Dockerfile, remover git |
| `test_package_lists.sh`      | REFATORAR | Baixo   | Atualizar para config-overrides/config/package-lists/         |
| `test_zbm_hook.sh`           | REFATORAR | Baixo   | Atualizar para config-overrides/config/hooks/                 |
| `test_installer_presence.sh` | REFATORAR | Baixo   | Atualizar para config-overrides/config/includes.chroot/       |
| `test_iso_build.sh`          | REFATORAR | Baixo   | Atualizar para output/\*.iso                                  |

#### 🟠 ALTA (Cobertura de Testes Crítica)

| Arquivo                     | Ação       | Esforço | Descrição                                                      |
| --------------------------- | ---------- | ------- | -------------------------------------------------------------- |
| `test_project_structure.sh` | REESCREVER | Médio   | Validar nova estrutura (logs/, output/, live-build-workspace/) |
| `test_vm_*.sh` (6 arquivos) | REESCREVER | Alto    | Adaptar para novos scripts vm-start-test-\*.sh                 |
| `validate_iso_installer.sh` | REFATORAR  | Médio   | Atualizar caminhos para instalador                             |

#### 🟡 MÉDIA (Qualidade de Código)

| Arquivo                        | Ação      | Esforço | Descrição                              |
| ------------------------------ | --------- | ------- | -------------------------------------- |
| `test_iso_qemu.sh`             | REFATORAR | Médio   | Remover prompts interativos para CI    |
| `vm-connent-*.sh` (3 arquivos) | RENOMEAR  | Baixo   | Corrigir typo 'connent' → 'connect'    |
| `test_lb_config.sh`            | REFATORAR | Médio   | Testar live-build-workspace/ pós-build |

#### 🟢 BAIXA (Limpeza)

| Arquivo                       | Ação      | Esforço | Descrição                 |
| ----------------------------- | --------- | ------- | ------------------------- |
| `test_docker_cmd.sh`          | DESCARTAR | -       | Funcionalidade obsoleta   |
| `test_wrapper_permissions.sh` | DESCARTAR | -       | Funcionalidade obsoleta   |
| `test_vm_disk_size.sh`        | DESCARTAR | -       | Coberto por outros testes |
| `manual/validate_ui.sh`       | DESCARTAR | -       | Dependência inexistente   |

---

### 3.2 Sumário de Ações

| Ação           | Scripts | Testes | Total |
| -------------- | ------- | ------ | ----- |
| **MANTER**     | 6       | 6      | 12    |
| **REFATORAR**  | 3       | 10     | 13    |
| **REESCREVER** | 0       | 7      | 7     |
| **DESCARTAR**  | 0       | 4      | 4     |
| **TOTAL**      | 9       | 27     | 36    |

---

## Parte 4: Mapa de Dependências

### 4.1 Cadeia de Dependências - Scripts

```
Makefile
├── download-zbm → download-zfsbootmenu.sh
│   └── curl, tar, GitHub API
├── setup-docker → scripts/docker/Dockerfile
│   └── scripts/docker/entrypoint.sh
│       └── lb config, lb build
├── setup-vm → scripts/vm/vm-setup.sh
│   └── apt-get (qemu-kvm, libvirt, ovmf)
├── create-disks → scripts/vm/vm-start-test-boot-iso.sh
│   └── qemu-img
├── test-vm-all → scripts/vm/vm-start-test-all.sh
│   ├── vm-start-test-boot-iso.sh
│   └── vm-connect-agent-llm.sh
│       └── vm-connect-ssh.sh
│           └── vm-connect-socket.sh
└── vm-connect-* → scripts/vm/vm-connent-*.sh
```

### 4.2 Dependências Críticas - Testes

| Teste                              | Dependências Críticas                   | Status            |
| ---------------------------------- | --------------------------------------- | ----------------- |
| test*install_plan*\*.sh            | libs/{core,state,install-plan}-utils.sh | ✅ OK             |
| test_installer_flow_consistency.sh | steps/install.sh                        | ✅ OK             |
| test_iso_structure.sh              | output/\*.iso, xorriso                  | ✅ OK             |
| test-docs.sh                       | installer/steps/\*.sh                   | ✅ OK             |
| test_docker_env.sh                 | scripts/docker/Dockerfile               | ❌ Caminho errado |
| test*\*\_vm*\*.sh                  | scripts/test-iso.sh                     | ❌ NÃO EXISTE     |

---

## Parte 5: Plano de Execução Recomendado

### Fase 1: Correções Rápidas (Esforço: 2-4h)

1. Atualizar caminhos em 5 testes URGENTES
2. Renomear arquivos vm-connent-_.sh → vm-connect-_.sh
3. Atualizar referências no Makefile

### Fase 2: Refatoração de Testes (Esforço: 1-2 dias)

1. Reescrever test_project_structure.sh
2. Refatorar validate_iso_installer.sh
3. Remover interatividade de test_iso_qemu.sh

### Fase 3: Cobertura de Novos Scripts (Esforço: 2-3 dias)

1. Criar testes para scripts/vm/\*.sh
2. Criar teste de integração Docker → ISO → VM

### Fase 4: Limpeza (Esforço: 1h)

1. Remover 4 testes obsoletos irrecuperáveis
2. Arquivar ou documentar decisão

---

## Apêndice: Variáveis de Caminho

### Migração de Caminhos (Referência Rápida)

| Antigo                           | Novo                                                               |
| -------------------------------- | ------------------------------------------------------------------ |
| `config/`                        | `config-overrides/config/`                                         |
| `config/includes.chroot/`        | `config-overrides/config/includes.chroot/`                         |
| `config/hooks/`                  | `config-overrides/config/hooks/`                                   |
| `config/package-lists/`          | `config-overrides/config/package-lists/`                           |
| `docker/`                        | `scripts/docker/`                                                  |
| `docker/Dockerfile`              | `scripts/docker/Dockerfile`                                        |
| `docker/artifacts/`              | (removido - usar logs/, output/)                                   |
| `docker/artifacts/dist/`         | `output/`                                                          |
| `docker/artifacts/logs/`         | `logs/`                                                            |
| `scripts/build-iso-in-docker.sh` | (removido - usar make build-iso)                                   |
| `scripts/test-iso.sh`            | (removido - usar scripts/vm/vm-start-test-\*.sh)                   |
| `scripts/lib/installer/`         | `config-overrides/config/includes.chroot/usr/local/lib/installer/` |

---

_Documento gerado automaticamente por análise de código-fonte._
