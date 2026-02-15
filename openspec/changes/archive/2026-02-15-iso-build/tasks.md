## 1. Fundação e Design System (UI)

- [x] 1.1 Criar estrutura de diretórios (`scripts/lib/installer/`, `scripts/lib/fileserver-ds.sh`)
- [x] 1.2 Implementar Design System v2.0 (`fileserver-ds.sh`) com wrappers para `gum`
- [x] 1.3 Criar script de validação visual (`tests/manual/validate_ui.sh`) para testar componentes do tema monocromático

## 2. Detecção e Particionamento

- [x] 2.1 Implementar módulo `boot-utils.sh` (Detecção UEFI/BIOS via sysfs)
- [x] 2.2 Implementar módulo `disk-utils.sh` (Listagem `lsblk`, filtro >20GB, seleção multi-disco)
- [x] 2.3 Implementar módulo `partitioning.sh` (Wipefs, efibootmgr clean, gdisk para GPT Híbrido: BIOS Boot + ESP + ZFS)
- [x] 2.4 Criar teste de integração VM (`tests/test_installer_partitioning.sh`) para validar layout de disco

## 3. Storage ZFS e Instalação Base

- [x] 3.1 Implementar módulo `zfs-utils.sh` (Criação de pool `zroot`, datasets ZBM compliant, mountpoints)
- [x] 3.2 Implementar função de instalação do sistema (Rsync do live filesystem para `/mnt` com exclusões corretas: `/proc`, `/sys`, `/dev`, etc)
- [x] 3.3 Implementar módulo `system-config.sh` (Geração de fstab, hostname, timezone, locale, criação de usuário inicial)
- [x] 3.4 Criar teste de validação de estrutura ZFS (`tests/test_installer_zfs.sh`)

## 4. Bootloader (ZFSBootMenu)

- [x] 4.1 Implementar módulo `zbm-install.sh` (Cópia de vmlinuz/initramfs ZBM para ESP)
- [x] 4.2 Configurar Bootloader UEFI (Entradas `efibootmgr` apontando para ZBM)
- [x] 4.3 Configurar propriedades de Boot ZFS (`org.zfsbootmenu:commandline`, hostid persistente)
- [x] 4.4 Validar injeção de argumentos de kernel ZFSBootMenu

## 5. Integração e Build

- [x] 5.1 Implementar script orquestrador principal (`/usr/local/bin/installer`) ligando módulos e steps no fluxo Wizard
- [x] 5.2 Configurar inclusão live-build (`config-overrides/config/includes.chroot`) para injetar scripts na ISO final
- [x] 5.3 Garantir permissões de execução nos scripts instalados (`chmod +x`) via hook ou source
- [x] 5.4 Realizar build completo da ISO (`make build-iso`) com novo instalador incluído

## 6. Validação Full-Stack

- [x] 6.1 Testar instalação completa em VM UEFI (`make test-vm-uefi`)
- [x] 6.2 Testar instalação completa em VM BIOS (`make test-vm-bios`)
- [x] 6.3 Verificar primeiro boot do sistema instalado (Login funcional, ZFS montado corretamente)
- [x] 6.4 Documentar guia de uso do instalador em `docs/INSTALLER_GUIDE.md`

---

## ✅ Status da Mudança

Todas as tarefas desta mudança estão marcadas como concluídas.

Observação: resultados de runtime (build e validações em VM) devem ser confirmados na pipeline/
ambiente de teste da branch atual, pois este arquivo é um artefato de planejamento e pode conter
registros históricos de execuções anteriores.

## 7. Refinamentos Pós-Implementação (Fixes)

- [x] 7.1 Corrigir limite mínimo de disco para 20GB em `disk-utils.sh`
- [x] 7.2 Implementar exibição dinâmica de modo de boot em `welcome.sh`
- [x] 7.3 Implementar suporte a boot BIOS Legacy (Syslinux) em `zbm-install.sh`
- [x] 7.4 Atualizar specs e design para suportar multi-disco e BIOS
- [x] 7.5 Corrigir caminhos de testes legados

## 8. Ajustes de Verificação Final

- [x] 8.1 Alinhar cmdline ZBM com `root=zfs:zroot/ROOT/debian`
- [x] 8.2 Remover tolerância silenciosa de erro no boot BIOS pós-instalação
- [x] 8.3 Adicionar teste estático para firmware dinâmico e filtro mínimo de disco
- [x] 8.4 Registrar decisão de cmdline explícita no `design.md`
