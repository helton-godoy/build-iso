# Plano de Correções Pós-Review - 2026-01-06

## Problemas Identificados
- Erro de sintaxe no `rsync` do instalador (impede instalação).
- `hostid` não sincronizado (pode impedir boot do ZFS).
- `chown` agressivo no script de build (risco a arquivos locais).
- Detecção de ISO ambígua no script de teste.
- Versão de kernel hardcoded no script de download.

## Tarefas

- [x] **Task 1: Corrigir `install-zfs-debian`**
  - [x] Adicionar `\` nas linhas do rsync.
  - [x] Adicionar `zgenhostid` para sincronizar hostid.
  - [x] Adicionar configuração de `/etc/hostname` e `/etc/hosts`.
  
- [x] **Task 2: Refinar `0100-compile-zfs-dkms.hook.chroot`**
  - [x] Melhorar detecção da variável `KERNEL_VERSION`.

- [x] **Task 3: Ajustar `build-iso-in-docker.sh`**
  - [x] Mudar `chown` para atuar apenas em `docker/artifacts`.

- [x] **Task 4: Dinamizar `download-zfsbootmenu.sh`**
  - [x] Extrair nome do tarball via `Content-Disposition`.

- [x] **Task 5: Melhorar `test-iso.sh`**
  - [x] Ordenar ISOs por data para pegar a mais recente.

- [ ] **Task 6: Verificação Final**
  - Executar `./scripts/build-iso-in-docker.sh`.
  - Executar `./scripts/test-iso.sh --dry-run`.
