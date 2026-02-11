# Auditoria Técnica: Instalador GPT com Lazy Loading

**Data:** 2026-02-07
**Status:** ~~Em Execução~~ → **Superseded**
**Autor:** Antigravity AI

> [!WARNING]
> **Plano superseded.** O instalador foi refatorado com `gum` e a arquitetura de `libs/` e `steps/` está implementada em
> `config-overrides/config/includes.chroot/usr/local/lib/installer/`. Consulte
> [`docs/INSTALLER_ARCHITECTURE.md`](../docs/INSTALLER_ARCHITECTURE.md) para a arquitetura atual.

## Descrição do Problema

A implementação anterior do instalador, embora tenha buscado uma abordagem modular com **Lazy Loading em Shell Script**, apresenta desvios significativos da arquitetura definida em [projeto.md](file:///home/helton/git/build-iso/projeto.md):

> [!IMPORTANT]
> **45 artefatos** com prefixo `install-system-gpt-*.sh` foram gerados, mas a estrutura de diretórios esperada (`./libs/` e [./steps/](file:///home/helton/git/build-iso/install-system-gpt.sh#543-568)) **não existe**.

---

## Topologia de Diretórios

### Arquitetura Definida em [projeto.md](file:///home/helton/git/build-iso/projeto.md)

```mermaid
flowchart TB
    subgraph ESPERADO["🎯 Estrutura Esperada (projeto.md)"]
        direction TB
        root_e["/install-zfs/"]
        maestro_e["install-system.sh<br/>(Maestro)"]
        disks_e["disks-identify.sh"]
        libs_e["libs/"]
        
        root_e --> maestro_e
        root_e --> disks_e
        root_e --> libs_e
        
        libs_e --> common["common-utils.sh"]
        libs_e --> single["prepare-disks-single.sh"]
        libs_e --> mirror["prepare-disks-mirror.sh"]
        libs_e --> raidz1["prepare-disks-raidz1.sh"]
        libs_e --> raidz2["prepare-disks-raidz2.sh"]
        libs_e --> draid["prepare-disks-draid.sh"]
        libs_e --> raid10["prepare-disks-raid10.sh"]
        libs_e --> datasets["setup-datasets.sh"]
        libs_e --> bootloader["setup-bootloader.sh"]
        libs_e --> zbmconfig["setup-zbm-config.sh"]
        libs_e --> finalize["finalize-chroot.sh"]
    end
```

### Estrutura Real do Projeto

```mermaid
flowchart TB
    subgraph ATUAL["📦 Estrutura Atual"]
        direction TB
        root["/home/helton/git/build-iso/"]
        
        gpt_main["install-system-gpt.sh<br/>43KB, 1165 linhas"]
        gpt_1["install-system-gpt-1.sh<br/>Auditor"]
        gpt_20["install-system-gpt-20.sh<br/>Router v2.0"]
        gpt_36["install-system-gpt-36.sh<br/>Router v2.1"]
        gpt_44["install-system-gpt-44.sh<br/>Step: install.sh"]
        gpt_other["... 40 outros arquivos"]
        
        scripts["scripts/"]
        lib["lib/"]
        installer["installer/"]
        
        root --> gpt_main
        root --> gpt_1
        root --> gpt_20
        root --> gpt_36
        root --> gpt_44
        root --> gpt_other
        
        root --> scripts
        scripts --> lib
        lib --> installer
        
        installer --> disk_det["disk-detection.sh"]
        installer --> fw_det["firmware-detection.sh"]
        installer --> part["partitioning.sh"]
        installer --> sys_cfg["system-config.sh"]
        installer --> zbm_inst["zbm-install.sh"]
        installer --> zfs_setup["zfs-setup.sh"]
    end
    
    style gpt_main fill:#10B981,stroke:#059669,color:#fff
    style installer fill:#3B82F6,stroke:#2563EB,color:#fff
```

---

## Fluxo de Execução (Lazy Loading)

O padrão implementado em [install-system-gpt.sh](file:///home/helton/git/build-iso/install-system-gpt.sh) segue uma arquitetura robusta:

```mermaid
sequenceDiagram
    participant Main as Maestro (main)
    participant Reg as register_all_steps()
    participant Router as Router Logic
    participant Lazy as lazy_source_step()
    participant Deps as lazy_source_deps()
    participant Handler as Step Handler
    
    Main->>Reg: Registra 20 steps com metadados
    Note over Reg: STEP_TITLE, STEP_MODULE,<br/>STEP_HANDLER, STEP_DEPS
    
    Main->>Router: goto_step("welcome")
    Router->>Router: step_invoke("welcome")
    
    Router->>Deps: lazy_source_deps("net-utils.sh,...")
    Note over Deps: source $LIBS_DIR/$dep<br/>⚠️ ./libs/ NÃO EXISTE
    Deps-->>Router: Deps carregadas (ou fallback)
    
    Router->>Lazy: lazy_source_step("welcome")
    Note over Lazy: source $STEPS_DIR/welcome.sh<br/>⚠️ ./steps/ NÃO EXISTE
    Lazy-->>Router: Módulo carregado (ou fallback)
    
    Router->>Handler: step_welcome()
    Note over Handler: UI renderizada via Gum
    Handler-->>Router: return 0/1
    
    Router->>Main: goto_next()
```

---

## Mapa de Dependências

### Step Registry ([install-system-gpt.sh](file:///home/helton/git/build-iso/install-system-gpt.sh))

```mermaid
graph LR
    subgraph Steps["📋 Steps Registrados (20)"]
        welcome["welcome"]
        locale["installer_prefs_locale"]
        keyboard["installer_prefs_keyboard"]
        identity["identity"]
        network["network"]
        time["time"]
        user["user_account"]
        admin["admin_policy"]
        disk_sel["disk_select"]
        disk_wipe["disk_wipe_confirm"]
        zfs_strat["zfs_strategy"]
        zfs_topo["zfs_auto_topology"]
        zfs_props["zfs_auto_properties"]
        zfs_ds["zfs_auto_datasets"]
        zfs_man["zfs_manual"]
        boot["boot"]
        review["review"]
        install["install"]
        post["post_install"]
        finish["finish"]
    end
    
    welcome --> locale --> keyboard --> identity
    identity --> network --> time
    time --> user --> admin --> disk_sel
    disk_sel --> disk_wipe --> zfs_strat
    zfs_strat --> zfs_topo --> zfs_props --> zfs_ds --> boot
    zfs_strat -.-> zfs_man -.-> boot
    boot --> review --> install --> post --> finish
    
    style zfs_strat fill:#F59E0B,stroke:#D97706
    style zfs_man fill:#EF4444,stroke:#DC2626
```

### Dependências por Step

| Step | Módulo Esperado | Libs Requeridas | Status |
|------|-----------------|-----------------|--------|
| [welcome](file:///home/helton/git/build-iso/install-system-gpt.sh#575-587) | `welcome.sh` | - | ⚠️ Fallback interno |
| [network](file:///home/helton/git/build-iso/install-system-gpt.sh#635-677) | `network.sh` | `net-utils.sh` | ❌ Ausente |
| [time](file:///home/helton/git/build-iso/install-system-gpt.sh#678-706) | `time.sh` | `time-utils.sh` | ❌ Ausente |
| [user_account](file:///home/helton/git/build-iso/install-system-gpt.sh#707-740) | `user_account.sh` | `auth-utils.sh` | ❌ Ausente |
| [disk_select](file:///home/helton/git/build-iso/install-system-gpt.sh#781-797) | `disk_select.sh` | `disk-utils.sh` | ⚠️ Existe em `scripts/lib/installer/` |
| `zfs_strategy` | `zfs_strategy.sh` | `zfs-utils.sh` | ⚠️ Existe em `scripts/lib/installer/` |
| `zfs_auto_topology` | `zfs_auto_topology.sh` | `zfs-utils.sh`, `disks-identify-suporte-types.sh` | ❌ Ausente |
| `boot` | `boot.sh` | `boot-utils.sh` | ❌ Ausente |
| `install` | `install.sh` | 6 libs | ⚠️ Exemplo em `gpt-44.sh` |
| `post_install` | `post_install.sh` | 7 libs | ❌ Ausente |

---

## Classificação dos Artefatos

### ✅ Componentes Robustos (Reaproveitáveis)

| Arquivo | Descrição | Linhas | Valor |
|---------|-----------|--------|-------|
| `install-system-gpt.sh` | Router principal com lazy loading completo | 1165 | ⭐⭐⭐ |
| `install-system-gpt-44.sh` | Step module `install.sh` bem estruturado | 287 | ⭐⭐⭐ |
| `install-system-gpt-1.sh` | Auditor de dependências | 423 | ⭐⭐ |
| `scripts/lib/installer/*.sh` | 6 libs funcionais | ~25KB | ⭐⭐⭐ |

### ⚠️ Componentes com Desvios (Requerem Refatoração)

| Arquivo | Problema Principal |
|---------|-------------------|
| `install-system-gpt-20.sh` | Router duplicado, steps reduzidos (4 steps) |
| `install-system-gpt-36.sh` | Router duplicado v2.1, steps reduzidos (5 steps) |
| `install-system-gpt-2.sh` a `install-system-gpt-43.sh` | Iterações anteriores, possivelmente obsoletas |

### ❌ Anomalias Críticas

| Problema | Impacto | Localização |
|----------|---------|-------------|
| Diretório `./libs/` não existe | Lazy loading falha silenciosamente | Raiz do projeto |
| Diretório `./steps/` não existe | Steps usam handlers internos como fallback | Raiz do projeto |
| Caminho `/mnt/data/projeto.md` hardcoded | Referência absoluta incorreta | `gpt-1.sh:13` |
| `disks-identify-suporte-types.sh` não existe | Topologia automática não funciona | Referenciado em `register_all_steps()` |
| 15+ libs referenciadas mas não implementadas | Steps falham em carregamento | Step registry |

---

## Plano de Correção

### Fase 1: Consolidação de Estrutura (Prioridade Alta)

```mermaid
gantt
    title Roadmap de Correção
    dateFormat  YYYY-MM-DD
    section Fase 1
    Criar ./libs/ e migrar           :a1, 2026-02-07, 1d
    Criar ./steps/ com módulos       :a2, after a1, 2d
    section Fase 2
    Implementar libs faltantes       :b1, after a2, 3d
    Testar lazy loading              :b2, after b1, 1d
    section Fase 3
    Integrar com install-system.sh   :c1, after b2, 2d
    Arquivar artefatos obsoletos     :c2, after c1, 1d
```

#### Tarefas Fase 1

1. **Criar estrutura de diretórios**
   ```bash
   mkdir -p libs steps
   ```

2. **Migrar libs existentes**
   ```bash
   cp scripts/lib/installer/*.sh libs/
   mv libs/disk-detection.sh libs/disk-utils.sh
   mv libs/firmware-detection.sh libs/boot-utils.sh
   mv libs/zfs-setup.sh libs/zfs-utils.sh
   ```

3. **Criar libs faltantes baseadas em `projeto.md`**
   - `libs/common-utils.sh` - Função `prepare_common()`
   - `libs/net-utils.sh` - Configuração de rede
   - `libs/time-utils.sh` - Fuso horário e NTP
   - `libs/auth-utils.sh` - Usuários e senhas
   - `libs/validate-utils.sh` - Validações de checkpoint
   - `libs/install-utils.sh` - Debootstrap e APT
   - `libs/post-utils.sh` - Pós-instalação

### Fase 2: Implementação de Steps

1. **Extrair handlers internos de `install-system-gpt.sh`** para arquivos individuais em `./steps/`
2. **Usar `install-system-gpt-44.sh` como template** para estrutura de step module
3. **Implementar steps restantes** seguindo o padrão Single Responsibility

### Fase 3: Integração Final

1. **Escolher Router principal**: `install-system-gpt.sh` (mais completo)
2. **Arquivar artefatos obsoletos** em `archived/installer-iterations/`
3. **Renomear Router final** para integração com ISO

---

## Verificação

### Testes Automatizados Existentes

```bash
# Verificar estrutura do projeto
./tests/test_project_structure.sh

# Verificar presença do instalador
./tests/test_installer_presence.sh
```

### Verificação Manual

1. **Testar lazy loading**:
   ```bash
   ./install-system-gpt.sh --help
   # Deve listar steps sem erros de source
   ```

2. **Validar dependências**:
   ```bash
   ./install-system-gpt-1.sh --router ./install-system-gpt.sh \
       --steps-dir ./steps --libs-dir ./libs
   ```

3. **Testar em VM** (após estrutura completa):
   ```bash
   make test-vm-all
   ```

---

## Referências

- [projeto.md](file:///home/helton/git/build-iso/projeto.md) - Arquitetura de referência
- [install-system-gpt.sh](file:///home/helton/git/build-iso/install-system-gpt.sh) - Router principal
- [scripts/lib/installer/](file:///home/helton/git/build-iso/scripts/lib/installer/) - Libs existentes
- [docs/PROJECT_STRUCTURE.md](file:///home/helton/git/build-iso/docs/PROJECT_STRUCTURE.md) - Estrutura do projeto
