# Documentação Técnica e Indexação do Instalador

Este plano visa documentar o funcionamento interno do instalador, mapeando o fluxo entre scripts, funções principais e o gerenciamento de estado, utilizando uma estratégia de tags para indexação inteligente.

## Estratégia de Tags (@INST)

Utilizaremos tags padronizadas no início de cada arquivo e antes de funções críticas:

- `@INST_STEP_ID`: ID único da etapa.
- `@INST_STEP_FLOW`: Direção do fluxo (Próximo/Anterior).
- `@INST_LIB_NAME`: Identificação de bibliotecas.
- `@INST_FUNC`: Documentação de funções (Parâmetros, Retorno, Lógica).
- `@INST_DEP`: Dependências de sistema ou de outros scripts.
- `@INST_STATE`: Variáveis de estado (`state.env`) manipuladas.
- `@INST_TODO`: Pontos de melhoria identificados.

## Mudanças Propostas

### [Componente] Core Router e Bibliotecas Base

Documentar o ponto de entrada e as libs fundamentais para entender o sistema de design e estado.

#### [MODIFY] [installer](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/bin/installer)

- Inserir tags de fluxo global e IDs das etapas.
- Explicar o mecanismo de `lazy_source`.

#### [MODIFY] [core-utils.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/core-utils.sh)

- Documentar funções de log e utilitários de string.

#### [MODIFY] [ui-utils.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-utils.sh)

- Mapear os componentes de interface baseados no `gum`.

### [Componente] Lógica de ZFS e Particionamento

Documentar o "coração" do instalador.

#### [MODIFY] [zfs-utils.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/zfs-utils.sh)

- Documentar criação de pools, datasets e snapshots.

#### [MODIFY] [partitioning.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/partitioning.sh)

- Explicar a estratégia de particionamento híbrido (BIOS/UEFI).

### [Componente] Etapas do Fluxo (Steps)

Documentar os arquivos em `steps/` seguindo a ordem de execução do Router.

## Análise Crítica e Recomendações

Após o mapeamento completo via `@INST`, identifiquei as seguintes oportunidades de melhoria:

### 1. Centralização do Particionamento

> [!IMPORTANT]
> Existe código de particionamento duplicado em [libs/partitioning.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/partitioning.sh) e [libs/disk-utils.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/disk-utils.sh).

- **Ação:** Mover toda a lógica de escrita em disco para [partitioning.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/partitioning.sh).
- **Benefício:** Garantia de que o layout GPT híbrido seja idêntico em qualquer fluxo.

### 2. Validação Estrita (Pre-flight)

> [!WARNING]
> Etapas como `Network` e `Identity` possuem validação fraca (apenas contra strings vazias).

- **Ação:** Implementar `validate_ip`, `validate_hostname` e `validate_zfs_name` usando regex em uma nova biblioteca `validate-utils.sh`.
- **Benefício:** Evita falhas no meio do [debootstrap](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/install.sh#636-661) ou criação de pool por caracteres inválidos.

### 3. Padronização do Estado (`state_kv`)

- **Ação:** Migrar as raras variáveis locais/globais que vazam entre scripts para o sistema `state_kv`.
- **Benefício:** Persistência robusta e capacidade de retomar a instalação em caso de queda de energia/erro.

### 4. Gestão de Memória (ZFS ARC)

- **Ação:** Melhorar a detecção automática no passo [zfs_auto_properties](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_properties.sh#9-52) para sugerir um ARC Max baseado na RAM real do host (ex: 50% ou 75% da RAM livre).

## Verificação Concluída

A documentação foi aplicada em:

- [x] [/usr/local/bin/installer](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/bin/installer) (Router)
- [x] `/usr/local/lib/installer/libs/` (9 arquivos)
- [x] `/usr/local/lib/installer/steps/` (15 arquivos)

## Plano de Verificação

### Testes Automatizados

- Executar `grep -r "@INST" /usr/local/lib/installer` para validar a cobertura.
- Validar se o instalador continua funcional após a inserção dos comentários (teste de integridade Bash).

### Verificação Manual

- O usuário poderá rodar `installer --print-map` e verificar se a documentação reflete o mapa impresso.
- Gerar um resumo automático dos passos usando as novas tags.

---

# Mapa de Documentação do Instalador

Este documento apresenta o resultado do mapeamento técnico realizado no código fonte do instalador Aurora.

## 🏗️ Arquitetura do Sistema de Tags `@INST`

Implementamos um sistema de indexação semântica para facilitar a manutenção e a extração automática de documentação:

- `@INST_LIB_NAME`: Identifica a biblioteca.
- `@INST_STEP_ID`: ID único da etapa no roteador.
- `@INST_STEP_FLOW`: Mapeia as transições (`prev`, `next`).
- `@INST_STATE`: Variáveis de estado gerenciadas.
- `@INST_FUNC`: Descrição de funções internas.
- `@INST_TODO`: Pontos de melhoria identificados.

## 🗺️ Fluxo de Trabalho (Steps)

Abaixo, a sequência lógica do instalador conforme documentado:

| ID                                                                                                                                                          | Arquivo                                                                                                                                                  | Próximo Passo                                                                                                                                               | Descrição                  |
| :---------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------- |
| [welcome](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/welcome.sh#5-17)                          | [welcome.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/welcome.sh)                         | [installer_prefs_locale](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_locale.sh#13-35)     | Tela inicial e requisitos  |
| [installer_prefs_locale](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_locale.sh#13-35)     | [prefs_locale.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_locale.sh)               | [installer_prefs_keyboard](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_keyboard.sh#20-43) | Idioma do sistema          |
| [installer_prefs_keyboard](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_keyboard.sh#20-43) | [prefs_keyboard.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_keyboard.sh)           | [identity](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/identity.sh#2-18)                        | Layout de teclas           |
| [identity](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/identity.sh#2-18)                        | [identity.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/identity.sh)                       | [network](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/network.sh#5-39)                          | Hostname e Domínio         |
| [network](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/network.sh#5-39)                          | [network.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/network.sh)                         | [time](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/time.sh#16-53)                               | DHCP ou IP Estático        |
| [time](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/time.sh#16-53)                               | [time.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/time.sh)                               | [user_account](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/user_account.sh#5-30)                | Timezone e NTP             |
| [user_account](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/user_account.sh#5-30)                | [user_account.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/user_account.sh)               | [admin_policy](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/admin_policy.sh#2-39)                | Criação de usuário e senha |
| [admin_policy](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/admin_policy.sh#2-39)                | [admin_policy.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/admin_policy.sh)               | [disk_select](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_select.sh#6-60)                  | Sudo vs Root               |
| [disk_select](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_select.sh#6-60)                  | [disk_select.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_select.sh)                 | [disk_wipe_confirm](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_wipe_confirm.sh#7-59)      | Seleção do alvo ZFS        |
| [disk_wipe_confirm](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_wipe_confirm.sh#7-59)      | [disk_wipe_confirm.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_wipe_confirm.sh)     | [zfs_strategy](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_strategy.sh#9-36)                | Confirmação de destruição  |
| [zfs_strategy](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_strategy.sh#9-36)                | [zfs_strategy.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_strategy.sh)               | [zfs_auto_topology](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_topology.sh#35-115)    | Auto vs Manual             |
| [zfs_auto_topology](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_topology.sh#35-115)    | [zfs_auto_topology.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_topology.sh)     | [zfs_auto_properties](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_properties.sh#9-52)  | Mirror, RAIDZ, etc         |
| [zfs_auto_properties](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_properties.sh#9-52)  | [zfs_auto_properties.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_properties.sh) | [zfs_auto_datasets](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_properties.sh#5-53)    | Compressão, ARC, Dedup     |
| [zfs_auto_datasets](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_properties.sh#5-53)    | [zfs_auto_datasets.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_datasets.sh)     | [boot](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/boot.sh#5-22)                                | VDEVs auxiliares           |
| [boot](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/boot.sh#5-22)                                | [boot.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/boot.sh)                               | [review](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/review.sh#2-65)                            | Bootloader e Kernel params |
| [review](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/review.sh#2-65)                            | [review.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/review.sh)                           | [install](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/boot-utils.sh#147-196)                     | Resumo e Confirmação final |
| [install](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/boot-utils.sh#147-196)                     | [install.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/install.sh)                         | [post_install](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/post_install.sh#2-83)                | Execução da instalação     |
| [post_install](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/post_install.sh#2-83)                | [post_install.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/post_install.sh)               | [finish](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/finish.sh#5-18)                            | Chroot config              |
| [finish](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/finish.sh#5-18)                            | [finish.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/steps/finish.sh)                           | -                                                                                                                                                           | Reinicialização            |

## 🛠️ Bibliotecas Nucleares

As bibliotecas foram documentadas com foco em suas APIs internas:

- **[core-utils.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/core-utils.sh)**: Sistema de logs e limpeza de strings.
- **[ui-utils.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-utils.sh)**: Design System "Monochrome Slate" (Gum).
- **[zfs-utils.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/zfs-utils.sh)**: Abstração de criação de pools e datasets.
- **[disk-utils.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/disk-utils.sh)**: Detecção e adapters de disco.
- **[zbm-install.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/zbm-install.sh)**: Implementação do ZFSBootMenu.
- **[install-plan-utils.sh](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/usr/local/lib/installer/libs/install-plan-utils.sh)**: Gestão do estado complexo da instalação.

## 🔍 Conclusões da Análise Crítica

Identificamos a necessidade de:

1. Consolidação da lógica de particionamento (atualmente dispersa).
2. Fortalecimento das validações de rede e hostname.
3. Padronização total do acesso ao estado via `state_kv`.

---

# Extensão: Scripts de Desenvolvimento e Testes

Este documento foi expandido para incluir a indexação dos scripts de desenvolvimento (`scripts/`) e testes (`tests/`), utilizando convenções de tags compatíveis com o sistema `@INST`.

## 🏷️ Sistema de Tags Expandido

### Tags para Scripts de Desenvolvimento (`@DEV`)

Scripts em `scripts/` utilizam o prefixo `@DEV`:

| Tag | Descrição | Exemplo |
|:----|:----------|:--------|
| `@DEV_SCRIPT` | Identifica o script e sua finalidade | `@DEV_SCRIPT: download-zfsbootmenu - Baixa binários ZBM` |
| `@DEV_CATEGORY` | Categoria do script | `build`, `vm`, `docker`, `util` |
| `@DEV_FUNC` | Documentação de função | `@DEV_FUNC: detect_latest_version - Detecta versão via API` |
| `@DEV_DEP` | Dependências externas | `@DEV_DEP: curl, jq, tar` |
| `@DEV_INPUT` | Entradas esperadas (args, env) | `@DEV_INPUT: $1=mode (uefi\|bios)` |
| `@DEV_OUTPUT` | Saídas produzidas | `@DEV_OUTPUT: EFI/BOOT/BOOTX64.EFI` |
| `@DEV_MAKEFILE` | Target do Makefile associado | `@DEV_MAKEFILE: download-zbm` |
| `@DEV_TODO` | Pontos de melhoria | `@DEV_TODO: Adicionar cache local` |

### Tags para Testes (`@TEST`)

Scripts em `tests/` utilizam o prefixo `@TEST`:

| Tag | Descrição | Exemplo |
|:----|:----------|:--------|
| `@TEST_SUITE` | Identifica a suite de testes | `@TEST_SUITE: test_installer_zfs` |
| `@TEST_CATEGORY` | Categoria do teste | `unit`, `integration`, `e2e`, `validation` |
| `@TEST_CASE` | Caso de teste individual | `@TEST_CASE: zfs_pool_exists retorna 0 se pool existe` |
| `@TEST_DEP` | Dependências do teste | `@TEST_DEP: zfsutils-linux, qemu-kvm` |
| `@TEST_FIXTURE` | Setup/teardown necessário | `@TEST_FIXTURE: Requer VM ativa` |
| `@TEST_ASSERTS` | Asserções realizadas | `@TEST_ASSERTS: exit_code=0, output contains "zroot"` |
| `@TEST_COVERS` | Componentes cobertos | `@TEST_COVERS: libs/zfs-utils.sh, steps/install.sh` |
| `@TEST_TODO` | Melhorias pendentes | `@TEST_TODO: Adicionar teste de falha de disco` |

## 📂 Mapa de Scripts de Desenvolvimento

### Categoria: Build (`scripts/`)

| Script | Target Makefile | Descrição |
|:-------|:----------------|:----------|
| `download-zfsbootmenu.sh` | `download-zbm` | Baixa EFI + vmlinuz + initramfs do ZFSBootMenu |
| `download-gum.sh` | - | Baixa binário estático do gum (UI) |
| `extract-docs.sh` | `docs` | Extrai e exibe tags @INST/@DEV/@TEST |

### Categoria: Docker (`scripts/docker/`)

| Script | Target Makefile | Descrição |
|:-------|:----------------|:----------|
| `entrypoint.sh` | `build-iso` | Orquestra lb config + lb build dentro do container |
| `Dockerfile` | `setup-docker` | Define imagem debian:trixie-slim com live-build |

### Categoria: VM (`scripts/vm/`)

| Script | Target Makefile | Descrição |
|:-------|:----------------|:----------|
| `vm-setup.sh` | `setup-vm` | Instala qemu-kvm, libvirt, ovmf |
| `vm-start-test-boot-iso.sh` | `test-vm-{uefi,bios}` | Inicia VM com ISO + 4 discos virtuais |
| `vm-start-test-boot-disk.sh` | `vm-boot-disk-{uefi,bios}` | Boot a partir de disco instalado |
| `vm-start-test-all.sh` | `test-vm-all` | Executa UEFI + BIOS em paralelo |
| `vm-connect-agent-llm.sh` | `vm-connect-{uefi,bios}` | Bootstrap SSH + conexão para agentes |
| `vm-connect-ssh.sh` | - | Conexão SSH com detecção automática de IP |
| `vm-connect-socket.sh` | - | Conexão serial via Unix socket |

## 🧪 Mapa de Testes

### Testes de Estrutura

| Arquivo | Categoria | Cobertura |
|:--------|:----------|:----------|
| `test_project_structure.sh` | validation | Estrutura de diretórios |
| `test_lb_config.sh` | validation | Configuração live-build |
| `test_package_lists.sh` | validation | Listas de pacotes |
| `test_iso_structure.sh` | validation | Estrutura da ISO gerada |
| `test_iso_pool_structure.sh` | validation | Pool ZFS na ISO |

### Testes do Instalador

| Arquivo | Categoria | Cobertura |
|:--------|:----------|:----------|
| `test_installer_presence.sh` | unit | Verifica binário do instalador |
| `test_installer_flow_consistency.sh` | integration | Fluxo de steps |
| `test_installer_partitioning.sh` | integration | Particionamento GPT híbrido |
| `test_installer_zfs.sh` | integration | Criação de pool e datasets |
| `test_install_plan_state.sh` | unit | Estado state_kv |
| `test_install_plan_guardrails.sh` | unit | Validações de segurança |

### Testes de Infraestrutura

| Arquivo | Categoria | Cobertura |
|:--------|:----------|:----------|
| `test_docker_env.sh` | validation | Dockerfile e entrypoint |
| `test_vm_dependencies.sh` | validation | Dependências de VM |
| `test_vm_kvm.sh` | validation | Suporte KVM |
| `test_vm_uefi.sh` | validation | OVMF para UEFI |
| `test_vm_disk.sh` | validation | Discos virtuais |
| `test_vm_boot_validation.sh` | e2e | Boot completo |
| `test_zbm_hook.sh` | validation | Hook ZFSBootMenu |
| `test_iso_build.sh` | e2e | Build completo |
| `test_iso_qemu.sh` | e2e | Boot ISO em QEMU |

### Testes de Documentação

| Arquivo | Categoria | Cobertura |
|:--------|:----------|:----------|
| `test-docs.sh` | validation | Integridade das tags @INST |
| `validate_iso_installer.sh` | e2e | Validação completa ISO + instalador |

## 🔧 Comandos Makefile para Documentação

```bash
# Extrair documentação de todos os componentes
make docs

# Extrair apenas scripts de desenvolvimento
make docs-dev

# Extrair apenas testes
make docs-tests

# Validar integridade das tags
make verify-docs
```

## 📊 Comandos grep para Filtrar Tags

```bash
# Listar todos os scripts de desenvolvimento
grep -r "@DEV_SCRIPT" scripts/

# Listar todas as funções documentadas
grep -rh "@DEV_FUNC\|@INST_FUNC" scripts/ config-overrides/

# Listar todos os TODOs
grep -rh "@DEV_TODO\|@INST_TODO\|@TEST_TODO" . --include="*.sh"

# Listar cobertura de testes
grep -r "@TEST_COVERS" tests/

# Listar dependências externas
grep -rh "@DEV_DEP\|@INST_DEP\|@TEST_DEP" . --include="*.sh"
```

---

_Gerado por Antigravity - Optimization Consultant_
