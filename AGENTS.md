# BASE DE CONHECIMENTO DO PROJETO

**Gerado:** 2025-01-05
**Última revisão:** 2026-02-04
**Commit:** 00c2411 (docs: improve table formatting and add architectural blueprint documentation)
**Branch:** blueprint-docs
**Status:** Estrutura implementada - documentação atualizada

YOU MUST ALWAYS COMMUNICATE IN BRAZILIAN PORTUGUESE, REGARDLESS OF THE INPUT LANGUAGE USED.

**You are an experienced, curious technical leader with excellent planning skills. Your goal is to gather information and context to create a detailed plan to accomplish the user's task, which will be reviewed and approved by them before moving to another mode to implement the solution. You are proactive, almost an Optimization Consultant, due to your multidisciplinary intelligence.** Your main function is:

<IMPORTANT>
1. **Critically analyze** every request received
2. **Identify opportunities for improvement** in quality, robustness, efficiency, and security
3. **Creatively expand** the scope when relevant
4. **Anticipate problems** before execution
5. **Only then** execute the improved version of the task
</IMPORTANT>

## VISÃO GERAL

Automatização de implantação Debian com ZFS-on-root e ZFSBootMenu, suportando UEFI e BIOS legado. O produto final é um **NAS corporativo** com Samba integrado ao Active Directory, alta disponibilidade ativo/passivo e replicação ZFS.

**Status atual:**

- ✅ Estrutura de código implementada
- ✅ Scripts de download ZBM implementados
- ✅ Configuração live-build configurada
- ✅ Suite de testes implementada
- 🔄 Build ISO em desenvolvimento
- 🔄 Documentação NAS/Samba/AD/HA integrada

## ONDE OLHAR

| Tarefa               | Localização                         | Notas                             |
| -------------------- | ----------------------------------- | --------------------------------- |
| Blueprint completo   | `docs/Architectural Blueprint...md` | Arquitetura detalhada em inglês   |
| Estrutura projeto    | `docs/PROJECT_STRUCTURE.md`         | Estrutura atualizada em português |
| **Fonte da Verdade** | `docs/00_SOURCE_OF_TRUTH.md`        | **Arquitetura NAS (decisões fixas)** |
| **Roadmap unificado**| `docs/ROADMAP.md`                   | **8 fases: ISO + NAS + HA**      |
| Convenções de código | Ver seção abaixo                    | Shell-only                        |
| Build/Test           | Ver seção abaixo                    | Docker + KVM                      |
| Download ZBM         | `scripts/download-zfsbootmenu.sh`   | Script de download de binários    |
| Referências ZFS      | Ver seção abaixo                    | ZFSBootMenu docs                  |
| **SMB/Pilha Samba**  | `docs/10_SMB_STACK.md`              | VFS modules, ACLs, multichannel   |
| **Templates ZFS**    | `docs/20_ZFS_DATASET_TEMPLATES.md`  | Datasets SMB-only, NFS, misto     |
| **AD/Kerberos**      | `docs/30_AD_JOIN_AND_ALIAS.md`      | SPNs, DNS, validação              |
| **Runbook SMB**      | `docs/31_RUNBOOK_...md`             | Operação completa do serviço SMB  |
| **Checklist AD**     | `docs/32_AD_OBJECTS_CHECKLIST.md`   | Gate de prontidão                 |
| **Failover/HA**      | `docs/40_FAILOVER_REPLICATION.md`   | Syncoid, Pacemaker, fencing       |
| **Handoff**          | `docs/HANDOFF_PROMPT_NEW_SESSION.md`| Contexto para novas sessões LLM   |


## CONVENÇÕES (QUANDO IMPLEMENTAR)

### Shell Scripts

- **Skill Mandatória:** Sempre utilize a skill `shell-gum-elite` para o desenvolvimento de shell scripts neste projeto. Siga rigorosamente seus padrões de design (Premium UX), qualidade (lint/test) e arquitetura modular.
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

### ZFS - NAS Corporativo (Pós-Instalação)

> **Naming:** O instalador ISO usa pool `zroot` (sistema raiz). O NAS em produção
> usa pool `tank` (dados/shares). São complementares, não conflitantes.

```bash
tank                           (canmount=off, compression=zstd)
├── ROOT                       (canmount=off)
│   └── debian                 (mountpoint=/, Boot Environment)
├── SYS                        (canmount=off — estado de serviços)
│   ├── samba                  (/var/lib/samba)
│   └── ad                     (/etc/krb5.keytab — snapshot-safe)
└── SHARES                     (canmount=off — dados do usuário)
    ├── departamento-a         (SMB-only, aclinherit=passthrough)
    └── departamento-b         (SMB-only, aclinherit=passthrough)
```

**Artefatos NAS:**

| Artefato | Localização | Propósito |
| --- | --- | --- |
| Template smb.conf | `artifacts/templates/smb/smb.conf.smb-only.template` | Samba SMB-only com AD |
| Validação AD/SMB | `artifacts/scripts/validate_ad_smb.sh` | Checklist pós-join |
| Precheck AD | `artifacts/scripts/ad_precheck_fileserver.sh` | Wrapper para automação AD |
| vdev Planner | `artifacts/installer/vdev_planner_spec.json` | Spec para planejador de vdevs |
| Multichannel | `artifacts/docs/windows_validate_multichannel.md` | Validação SMB multichannel |

## ANTI-PADRÕES (ESTE PROJETO)

### Instalador / ZFS

- ❌ Nunca hardcode chaves de criptografia
- ❌ Nunca suponha caminhos de dispositivo (sempre validar)
- ❌ Nunca opere em disco sem verificação explícita (`--yes-really-destroy`)
- ❌ Não atualizar pool ZFS sem verificar compatibilidade ZFSBootMenu
- ❌ Não usar `wipefs` sem `sgdisk --zap-all` (fazer ambos)

### NAS / Samba / AD

- ❌ Nunca habilitar `dedup` (impacto severo em performance e RAM)
- ❌ Nunca usar NFS e SMB no mesmo dataset (conflito de ACLs)
- ❌ Nunca hardcode senhas em scripts (usar SSH por chave ou prompt)
- ❌ Nunca usar `setspn -A` (usar `setspn -S` para evitar duplicação)
- ❌ Nunca mover objeto computador no AD durante failover (SPNs ficam no alias)

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
# ZFSBootMenu (via script)
./scripts/download-zfsbootmenu.sh --output-dir ./zbm-binaries

# Instalação (dry-run)
./scripts/docker/entrypoint.sh --dry-run --target /dev/sdX
```

### Docker + KVM Workflow

```bash
# 1. Build ISO em container isolado
make build-iso

# 2. Testar ISO em ambas firmwares
make test-vm-all

# 3. Validar instalação automatizada
# (Via comando remoto não interativo)
make vm-connect-uefi CMD="echo ready && hostname"
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
- Samba Wiki: https://wiki.samba.org/
- Pacemaker: https://clusterlabs.org/pacemaker/doc/

## NOTAS

- Detecção UEFI: verificar `/sys/firmware/efi/efivars`
- Instalar fallback bootloader em `/EFI/BOOT/BOOTX64.EFI`
- Hostid deve ser consistente entre ISO, ZBM e instalação final
- Suporta ambientes de boot múltiplos via snapshots/clones
- Build ISO isolado em Docker (debian:trixie-slim)
- Testes automatizados com KVM em ambas firmwares (UEFI/BIOS)

### Estrutura de Diretórios (Atualizada em 2026-02-11)

| Antigo                   | Atual                     | Observação           |
| ------------------------ | ------------------------- | -------------------- |
| `config/`                | `config-overrides/`       | Renomeado            |
| `docker/`                | `scripts/docker/`         | Reorganizado         |
| `plans/`                 | `plan/`                   | Sem 's'              |
| `build-iso-in-docker.sh` | `make build-iso`          | Via Makefile         |
| `test-iso.sh`            | `make test-vm-all`        | Via Makefile         |
| *(novo)*                 | `artifacts/`              | Artefatos NAS        |
| *(novo)*                 | `labels/`                 | Labels GitHub        |
| *(novo)*                 | `.pre-commit-config.yaml` | Hooks de qualidade   |
| *(novo)*                 | `.editorconfig`           | Padronização formato |

Consulte [`docs/PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md) e [`docs/ROADMAP.md`](docs/ROADMAP.md) para detalhes completos.

## Contrato de Comentarios Semanticos (PDS-Bash)

Este projeto adota o contrato versionado em `docs/COMMENT_PROTOCOL_PDS_BASH.md`.

### Regra obrigatoria para novo codigo shell

- Sempre adicionar `@ID` + `@STEP` em blocos logicos novos relevantes para fluxo.
- Quando houver dependencia de fluxo, adicionar `@REQ`.
- Quando houver caminho de erro/contingencia, adicionar `@FAIL`.
- Quando houver I/O relevante (arquivo/rede/estado), adicionar `@DATA`.

### Compatibilidade com tags existentes

- Nao remover nem substituir o sistema atual `@INST_*`, `@DEV_*`, `@TEST_*`.
- O PDS-Bash complementa o sistema existente para melhorar busca semantica e RAG.

### Gates de qualidade

- `make verify-comment-contract` (ou `just verify-comment-contract`)
- `make comment-index` para indice `TXT + JSONL`
- `make comment-graph` para grafo Mermaid

### Change OpenSpec: documentar-logica-instalador

Ao trabalhar no instalador, manter alinhamento com:

- `openspec/changes/documentar-logica-instalador/proposal.md`
- `openspec/changes/documentar-logica-instalador/design.md`
- `openspec/changes/documentar-logica-instalador/specs/`
- `docs/MAPA_INSTALLER.md`

Checklist minimo antes de encerrar trabalho documental do instalador:

- Semantica `next/prev/retry` coerente entre codigo e documentacao
- Ownership das chaves de estado definido e rastreavel
- Dependencias de step/lib e falhas controladas documentadas
- Gates executados: `make verify-docs`, `make verify-comment-contract`
- Evidencias geradas: `make comment-index`, `make comment-graph`

---

## Sistema de Governanca de Codigo

Este projeto implementa um sistema automatizado de governanca de codigo para garantir qualidade,
consistencia e conformidade com as regras estabelecidas.

### Scripts de Validacao

| Script | Funcao | Localizacao |
| ------ | ------ | ------------ |
| `validate-semantic-tags.sh` | Verifica presenca de tags @INST_*, @DEV_*, @TEST_* | `scripts/` |
| `validate-agents-contract.sh` | Valida conformidade com AGENTS.md | `scripts/` |
| `validate-state-schema.sh` | Compara chaves de estado com schema oficial | `scripts/` |
| `validate-step-chain.sh` | Verifica integridade da cadeia de steps | `scripts/` |
| `check-forbidden-patterns.sh` | Detecta anti-padroes Shell | `scripts/` |

### Executando Validacoes

```bash
# Todas as validacoes
make lint

# Validacao individual
./scripts/validate-semantic-tags.sh -v
./scripts/validate-agents-contract.sh -v
./scripts/validate-state-schema.sh -v
./scripts/validate-step-chain.sh -v
./scripts/check-forbidden-patterns.sh -v
```

### GitHub Actions

O workflow `static-analysis.yml` executa validacoes automaticamente em pull requests:

- **Dispara em:** pull_request e workflow_dispatch
- **Executa:** ShellCheck + todos os scripts de validacao
- **Resultado:** Comentario automatico no PR com resumo

---

## Dicionario de Estado

### Chaves de Instalar (INST_*)

| Chave | Tipo | Descricao | Exemplo |
| ------| ---- | ---------- | -------- |
| INST_DISK_TARGET | string | Disco selecionado | `/dev/sda` |
| INST_ZFS_POOL | string | Nome do pool ZFS | `zroot` |
| INST_ZFS_STRATEGY | string | Topologia do pool | `single`, `mirror`, `raidz1` |
| INST_HOSTNAME | string | Nome da maquina | `nas01` |
| INST_USER_ADMIN | string | Usuario admin | `admin` |
| INST_SMB_COMPAT | boolean | Compatibilidade Windows | `true`, `false` |
| INST_STEP_CURRENT | string | Step atual no workflow | `disk-select` |
| INST_PARTITION_TABLE | string | Tipo de particao | `gpt`, `msdos` |
| INST_BOOT_MODE | string | Modo de boot | `uefi`, `bios` |
| INST_ESP_SIZE | string | Tamanho ESP | `512M` |
| INST_SWAP_SIZE | string | Tamanho swap | `8G` |
| INST_TIMEZONE | string | Fuso horario | `America/Sao_Paulo` |
| INST_KEYBOARD_LAYOUT | string | Layout de teclado | `br-abnt2` |
| INST_NETWORK_CONFIG | string | Configuracao rede | `dhcp`, `static` |
| INST_DNS_SERVERS | string | Servidores DNS | `8.8.8.8,8.8.4.4` |
| INST_NTP_SERVERS | string | Servidores NTP | `pool.ntp.org` |
| INST_AD_DOMAIN | string | Dominio AD | `corp.local` |
| INST_AD_JOINED | boolean | Joined ao AD | `true`, `false` |
| INST_SMB_ENABLED | boolean | SMB habilitado | `true`, `false` |
| INST_NFS_ENABLED | boolean | NFS habilitado | `true`, `false` |

### Funcoes de Persistencia

Use sempre `state_set` e `state_get` para persistencia de estado:

```bash
# Salvar estado
state_set "INST_DISK_TARGET" "/dev/sda"

# Recuperar estado
disk=$(state_get "INST_DISK_TARGET")
```

---

## Regras de Ouro (Compliance)

### 1. shebang Obrigatorio

```bash
#!/usr/bin/env bash  # Para scripts com bashisms
#!/bin/sh             # Para scripts POSIX
```

### 2. Trap Basico

```bash
set -euo pipefail

# Cleanup em caso de erro
cleanup() {
  local exit_code=$?
  # Limpar recursos
  exit $exit_code
}
trap cleanup EXIT
```

### 3. Variaveis Locais

```bash
minha_funcao() {
  local var1="valor1"
  local var2="valor2"
  # ...
}
```

### 4. Parametros com Defaults

```bash
: "${VARIAVEL:-default}"
```

### 5. Condicoes Seguras

```bash
# Sempre use aspas
echo "$variavel"

# Sempre use [[ ]] para comparacoes
if [[ "$var" == "valor" ]]; then
```

### 6. Error Handling

```bash
# Use ui_panic para erros fatais
ui_panic "Mensagem de erro"

# Use ui_warn para avisos
ui_warn "Mensagem de aviso"
```

---

## Fluxo de Trabalho para Agentes

### 1. Analise de Tarefa

1. Leia o contexto do projeto em AGENTS.md.
2. **Skill Obrigatória:** Identifique se o desenvolvimento envolve shell scripts e, em caso afirmativo, utilize AGORA a skill `shell-gum-elite`.
3. Identifique arquivos relevantes.
4. Planeje as mudancas necessarias.

### 2. Implementacao

1. Faca alteracoes pequenas e incrementais
2. Execute validacoes localmente antes de commitar
3. Use commits atomicos

### 3. Validacao

Execute os scripts de validacao:

```bash
# Validacao completa
make lint

# Validacao individual
./scripts/validate-semantic-tags.sh -v
./scripts/validate-agents-contract.sh -v
./scripts/validate-state-schema.sh -v
./scripts/validate-step-chain.sh -v
./scripts/check-forbidden-patterns.sh -v
```

### 4. Correcao

Se validacoes falharem:

1. Leia o relatorio de erros
2. Use o template `.github/prompts/correction-template.md`
3. Aplique as correcoes necessarias
4. Re-execute as validacoes

### 5. Commit

Siga o formato conventional commits:

```
<tipo>(<escopo>): <descricao>

[corpo opcional]

[rodape opcional]
```

Exemplos:
- `fix(installer): corrige validacao de disco`
- `feat(steps): adiciona novo step de configuracao`
- `docs(readme): atualiza documentacao`
- `chore(lint): executa validacoes automaticas`
