# Especificação Técnica: Nova Versão do Instalador com Gum e Suite de Testes

## 1. Contexto Técnico

### 1.1 Ambiente

- **Linguagem**: Bash 5.1+
- **Sistema**: Debian 13 (Trixie)
- **Dependências Principais**:
  - `gum` >= 0.14.0 (já incluído em `/usr/local/bin/gum`)
  - `expect` >= 5.45 (a adicionar em package-lists)
  - `qemu-kvm` (para execução de testes)
  - `bash` >= 5.1
  - `openssh-client` (para conexão SSH com VMs)

### 1.2 Arquitetura Atual do Instalador

```
/usr/local/bin/installer                    # Router principal (675 linhas)
/usr/local/lib/installer/
├── libs/                                   # 19 bibliotecas compartilhadas
│   ├── ui-utils.sh                         # 655 linhas - Design System v2.0
│   ├── ui-gum.sh                           # 164 linhas - Wrappers gum
│   ├── state-utils.sh                      # 123 linhas - Persistência de estado
│   ├── core-utils.sh                       # 91 linhas - Utilitários básicos
│   ├── disk-utils.sh                       # 580 linhas - Operações de disco
│   ├── zfs-utils.sh                        # 217 linhas - Operações ZFS
│   ├── boot-utils.sh                       # 343 linhas - Configuração de boot
│   ├── install-utils.sh                    # 193 linhas - Instalação do sistema
│   ├── system-config.sh                    # 220 linhas - Configuração do sistema
│   └── [outras 10 bibliotecas]
└── steps/                                  # 21 módulos de etapas
    ├── welcome.sh                          # 18 linhas
    ├── prefs_locale.sh                     # 42 linhas
    ├── prefs_keyboard.sh                   # 45 linhas
    ├── identity.sh                         # 23 linhas
    ├── network.sh                          # 49 linhas
    ├── time.sh                             # 53 linhas
    ├── user_account.sh                     # 38 linhas
    ├── admin_policy.sh                     # 56 linhas
    ├── disk_select.sh                      # 216 linhas
    ├── disk_wipe_confirm.sh                # 58 linhas
    ├── zfs_strategy.sh                     # 45 linhas
    ├── zfs_auto_topology.sh                # 181 linhas
    ├── zfs_auto_properties.sh              # 81 linhas
    ├── zfs_aux_setup.sh                    # 164 linhas
    ├── zfs_auto_datasets.sh                # 169 linhas
    ├── zfs_manual.sh                       # 24 linhas
    ├── boot.sh                             # 25 linhas
    ├── review.sh                           # 109 linhas
    ├── install.sh                          # 870 linhas
    ├── post_install.sh                     # 108 linhas
    └── finish.sh                           # 24 linhas
```

**Fluxo de Etapas**: 21 etapas sequenciais
```
welcome → prefs_locale → prefs_keyboard → identity → network → time → 
user_account → admin_policy → disk_select → disk_wipe_confirm → 
zfs_strategy → {zfs_auto_topology|zfs_manual} → zfs_auto_properties → 
zfs_aux_setup → zfs_auto_datasets → boot → review → install → 
post_install → finish
```

**Sistema de Estado**: Persistência em `/run/fileserver-installer/state.env`

**Carregamento**: Lazy loading de etapas via `register_step()` no router

### 1.3 Infraestrutura de Testes Existente

- **Scripts VM**: `scripts/vm/` contém scripts de gerenciamento de VMs
  - `vm-setup.sh`: Instalação de dependências KVM
  - `vm-start-test-boot-iso.sh`: Inicia VM com ISO
  - `vm-connect-ssh.sh`: Conexão SSH com VMs
  - `vm-start-test-all.sh`: Executa testes em BIOS e UEFI
- **Teste Expect Atual**: `scripts/vm/expect-install-bios.exp` (198 linhas)
  - Cobre apenas instalação automática em BIOS
  - Usa modo plain UI (`INSTALLER_PLAIN_UI=1`)
  - Timeouts conservadores (300s padrão)
- **Makefile**: Targets de teste (`test-vm-uefi`, `test-vm-bios`, `test-vm-all`)

## 2. Abordagem de Implementação

### 2.1 Estratégia Geral

**Abordagem**: Refatoração incremental preservando compatibilidade

**Princípios**:
1. **Manter arquitetura modular existente** (router + libs + steps)
2. **Centralizar interações UI** em `ui-utils.sh` e `ui-gum.sh`
3. **Preservar modo plain UI** como fallback funcional
4. **Não alterar lógica de negócio** das etapas (apenas camada UI)
5. **Criar suite de testes paralela** sem afetar script expect existente

### 2.2 Padrão de Código Existente

**Tags Semânticas**:
```bash
# @INST_FILE: nome-arquivo
# @INST_DESC: Descrição breve
# @INST_FUNC: nome_funcao
# @INST_ARGS: arg1, arg2
# @INST_RET: valor_retorno
# @INST_DEP: dependencia
```

**Design System v2.0** (Monocromático Slate):
- Paleta: variáveis `DS_*` (235-252 + acentos 66-68, 153)
- Componentes: `ui_hero()`, `ui_section()`, `ui_card()`, `ui_error()`, etc.
- Wrappers gum: `ui_confirm()`, `ui_select()`, `ui_input()`, `ui_password()`

**Convenções**:
- Indentação: tabs
- Variáveis globais: UPPERCASE
- Variáveis locais: lowercase
- Funções públicas: `funcao_publica()`
- Funções privadas: `_funcao_privada()`

## 3. Mudanças de Estrutura de Código

### 3.1 Biblioteca `ui-utils.sh` (Refatoração)

**Objetivo**: Centralizar e padronizar todas as interações UI usando gum

**Mudanças**:

1. **Mover wrappers de `ui-gum.sh` para `ui-utils.sh`**
   - Consolidar funções `ui_confirm()`, `ui_select()`, `ui_input()`, etc.
   - Manter `ui-gum.sh` apenas para funções auxiliares de baixo nível

2. **Adicionar wrappers faltantes**:
   ```bash
   # @INST_FUNC: ui_choose
   # @INST_DESC: Seleção única ou múltipla com gum choose
   # @INST_ARGS: title, multi (0|1), options...
   # @INST_RET: Seleção(ões) escolhida(s)
   ui_choose() { ... }
   
   # @INST_FUNC: ui_filter
   # @INST_DESC: Seleção com busca incremental usando gum filter
   # @INST_ARGS: title, options...
   # @INST_RET: Opção filtrada e selecionada
   ui_filter() { ... }
   
   # @INST_FUNC: ui_spin
   # @INST_DESC: Indicador de progresso para operações longas
   # @INST_ARGS: title, command
   # @INST_RET: Exit code do comando
   ui_spin() { ... }
   
   # @INST_FUNC: ui_table
   # @INST_DESC: Exibição de dados em formato tabular
   # @INST_ARGS: headers (csv), rows (array)
   # @INST_RET: 0
   ui_table() { ... }
   ```

3. **Melhorar fallbacks plain UI**:
   - Cada wrapper deve detectar `INSTALLER_PLAIN_UI=1`
   - Implementar alternativas texto puro funcionais
   - Manter UX degradada mas utilizável

4. **Adicionar validações inline**:
   - Integrar validações comuns (hostname, IP, etc.) nos wrappers
   - Permitir callbacks de validação customizada

### 3.2 Biblioteca `ui-validation.sh` (Nova)

**Objetivo**: Validações reutilizáveis para entrada de usuário

**Funções**:
```bash
# @INST_FUNC: validate_hostname
# @INST_ARGS: hostname
# @INST_RET: 0 se válido, 1 se inválido
validate_hostname() { ... }

# @INST_FUNC: validate_domain
# @INST_ARGS: domain
validate_domain() { ... }

# @INST_FUNC: validate_username
# @INST_ARGS: username
validate_username() { ... }

# @INST_FUNC: validate_ip
# @INST_ARGS: ip
validate_ip() { ... }

# @INST_FUNC: validate_timezone
# @INST_ARGS: timezone
validate_timezone() { ... }

# @INST_FUNC: validate_disk_path
# @INST_ARGS: disk_path
validate_disk_path() { ... }
```

**Integração**:
- Source em `installer` (router principal)
- Uso via wrappers em `ui-utils.sh`
- Mensagens de erro via `ui_error()`

### 3.3 Módulos de Etapas (Atualização)

**Objetivo**: Substituir todas as interações diretas por wrappers de `ui-utils.sh`

**Padrão de Mudança**:

**Antes**:
```bash
# Entrada direta
read -r -p "Hostname: " hostname

# Select manual
select opt in "${options[@]}"; do
  ...
done
```

**Depois**:
```bash
# Via wrapper com validação
hostname=$(ui_input "Hostname" "" "validate_hostname")

# Via wrapper padronizado
selected=$(ui_choose "Selecione" 0 "${options[@]}")
```

**Etapas Afetadas** (todas as 21):
- **Simples** (welcome, finish): Apenas ajustes de `ui_confirm()`
- **Médias** (prefs_locale, identity, network, time, user_account): Substituir inputs e selects
- **Complexas** (disk_select, zfs_auto_topology, review, install): Refatorar múltiplas interações

**Sem mudanças de lógica**: Apenas UI, mantendo fluxo e estado inalterados

## 4. Mudanças de Modelo de Dados / API

### 4.1 Estrutura de Estado (Sem Mudanças)

**Preservar**:
- `/run/fileserver-installer/state.env` (formato key=value)
- Funções de `state-utils.sh`: `state_kv_set()`, `state_kv_get()`, etc.
- Todas as chaves de estado existentes

**Adicionar (opcional para testes)**:
```bash
# Modo de execução (para testes automatizados)
export INSTALLER_MODE="${INSTALLER_MODE:-interactive}"  # interactive|automated

# Arquivo de respostas automáticas (para testes)
export INSTALLER_ANSWERS_FILE="${INSTALLER_ANSWERS_FILE:-}"
```

### 4.2 Interface de Wrappers UI

**API Consistente**:
```bash
# Todos os wrappers retornam via stdout e exit code 0/1
# Formato: ui_<tipo> <titulo> [default] [validacao]

ui_input "Prompt" "default_value" "validate_func"
ui_confirm "Question?" "y"  # y ou n como default
ui_select "Title" "Option1" "Option2" "Option3"  # primeira é default
ui_choose "Title" 0 "Opt1" "Opt2"  # 0=single, 1=multi
ui_filter "Title" "item1" "item2" "item3"
ui_spin "Loading..." "comando_a_executar"
ui_table "Col1,Col2" "val1a,val1b" "val2a,val2b"
```

**Modo Plain UI**:
- Mesma API, implementação diferente
- Fallback para `read`, `select`, `printf`
- Sem gráficos, apenas texto

## 5. Estrutura da Suite de Testes Expect

### 5.1 Hierarquia de Arquivos

```
scripts/vm/expect/
├── lib/                                    # Bibliotecas comuns
│   ├── expect-common.tcl                   # Funções reutilizáveis
│   ├── expect-config.tcl                   # Configurações e variáveis
│   └── expect-assertions.tcl               # Validações e asserções
├── steps/                                  # Testes de etapas individuais
│   ├── test-step-welcome.exp              # ~30 linhas cada
│   ├── test-step-prefs_locale.exp
│   ├── test-step-prefs_keyboard.exp
│   ├── test-step-identity.exp
│   ├── test-step-network.exp
│   ├── test-step-time.exp
│   ├── test-step-user_account.exp
│   ├── test-step-admin_policy.exp
│   ├── test-step-disk_select.exp
│   ├── test-step-disk_wipe_confirm.exp
│   ├── test-step-zfs_strategy.exp
│   ├── test-step-zfs_auto_topology.exp
│   ├── test-step-zfs_auto_properties.exp
│   ├── test-step-zfs_aux_setup.exp
│   ├── test-step-zfs_auto_datasets.exp
│   ├── test-step-zfs_manual.exp
│   ├── test-step-boot.exp
│   ├── test-step-review.exp
│   ├── test-step-install.exp
│   ├── test-step-post_install.exp
│   └── test-step-finish.exp
├── scenarios/                              # Testes de cenários completos
│   ├── test-install-auto-bios.exp          # ~150 linhas
│   ├── test-install-auto-uefi.exp          # ~150 linhas
│   ├── test-install-manual-mirror.exp      # ~200 linhas
│   ├── test-install-manual-raidz1.exp      # ~200 linhas
│   └── test-install-error-recovery.exp     # ~180 linhas
├── run-test-suite.sh                       # Executor principal (~200 linhas)
└── README.md                               # Documentação de uso
```

### 5.2 Biblioteca Comum (`expect-common.tcl`)

**Funções Principais**:
```tcl
# Procedimentos de interação
proc expect_step {pattern response timeout} { ... }
proc expect_select {prompt options selected_index} { ... }
proc expect_confirm {prompt expected_default} { ... }
proc expect_input {prompt value} { ... }
proc expect_multiline {prompts responses} { ... }

# Procedimentos de validação
proc assert_state_key {key expected_value} { ... }
proc assert_file_exists {path} { ... }
proc assert_zpool_exists {pool_name} { ... }
proc assert_boot_entries {} { ... }

# Utilitários
proc log_test_step {message} { ... }
proc log_error {message} { ... }
proc setup_test_state {step_id} { ... }
proc cleanup_test_state {} { ... }
```

### 5.3 Testes de Etapas Individuais

**Template Padrão** (exemplo: `test-step-identity.exp`):
```tcl
#!/usr/bin/env expect

source [file join [file dirname $argv0] "../lib/expect-common.tcl"]
source [file join [file dirname $argv0] "../lib/expect-config.tcl"]

set timeout 60

# Setup: criar estado mínimo necessário
setup_test_state "identity"

# Conectar via SSH e executar apenas a etapa
spawn ssh -tt -o StrictHostKeyChecking=no ${vm_user}@${vm_ip}
expect -re {[$#] $}

# Executar etapa individual
send "source /usr/local/lib/installer/libs/ui-utils.sh\r"
send "source /usr/local/lib/installer/libs/state-utils.sh\r"
send "source /usr/local/lib/installer/steps/identity.sh\r"
send "step_identity\r"

# Interagir conforme esperado
expect_input "Hostname:" "nas-test"
expect_input "Domínio (opcional):" ""

# Validar saída
assert_state_key "SYSTEM_HOSTNAME" "nas-test"

# Cleanup
cleanup_test_state
exit 0
```

**Vantagens**:
- Testes isolados e rápidos (< 2 min cada)
- Facilitam debug de etapas específicas
- Validam entrada/saída de forma granular

### 5.4 Testes de Cenários Completos

**Template Padrão** (exemplo: `test-install-auto-bios.exp`):
```tcl
#!/usr/bin/env expect

source [file join [file dirname $argv0] "../lib/expect-common.tcl"]
source [file join [file dirname $argv0] "../lib/expect-config.tcl"]

set timeout 1800  # 30 min para instalação completa

# Conectar via SSH e limpar estado
spawn ssh -tt -o StrictHostKeyChecking=no ${vm_user}@${vm_ip}
expect -re {[$#] $}
send "rm -rf /run/fileserver-installer\r"

# Iniciar instalador
send "INSTALLER_PLAIN_UI=1 /usr/local/bin/installer\r"

# Sequência completa de todas as 21 etapas
expect_confirm "Iniciar instalação?" "y"
expect_select "locale" {"pt_BR.UTF-8" "en_US.UTF-8"} 0
expect_select "keyboard" {"br-abnt2" "us"} 0
expect_input "Hostname:" $hostname
expect_input "Domínio (opcional):" ""
# ... (continua para todas as etapas)

# Validação final do sistema instalado
assert_zpool_exists "zroot"
assert_boot_entries
assert_file_exists "/target/etc/hostname"

exit 0
```

**Cenários Cobertos**:
1. **Auto BIOS**: Instalação automática em modo BIOS com defaults
2. **Auto UEFI**: Instalação automática em modo UEFI com defaults
3. **Manual Mirror**: Configuração manual ZFS mirror (2 discos)
4. **Manual RAIDZ1**: Configuração manual ZFS raidz1 (3+ discos)
5. **Error Recovery**: Validação de tratamento de erros (disco inválido, etc.)

### 5.5 Executor da Suite (`run-test-suite.sh`)

**Interface CLI**:
```bash
./scripts/vm/expect/run-test-suite.sh [opções]

Opções:
  --all                  Executa todos os testes (steps + scenarios)
  --steps                Executa apenas testes de etapas individuais
  --scenarios            Executa apenas testes de cenários completos
  --test <nome>          Executa teste específico (ex: test-step-identity)
  --vm-type <bios|uefi>  Tipo de VM para testes (padrão: ambos)
  --report <json|text>   Formato do relatório (padrão: text)
  --parallel             Executa testes em paralelo (quando possível)
  --vm-cleanup           Remove VMs após execução
  --verbose              Modo verboso (log detalhado)
  -h, --help             Exibe esta ajuda
```

**Funcionalidades**:
1. **Gerenciamento de VMs**: Criar/destruir VMs de teste automaticamente
2. **Execução sequencial ou paralela**: Testes independentes em paralelo
3. **Relatórios**: JSON (para CI/CD) ou texto (para leitura humana)
4. **Retry lógico**: Retry automático em falhas transitórias de rede
5. **Logs detalhados**: Captura de logs de cada teste para debug

**Estrutura Interna**:
```bash
# Função principal
main() {
  parse_args "$@"
  setup_vms
  run_tests
  generate_report
  cleanup_vms
}

# Execução de teste individual
run_single_test() {
  local test_file=$1
  local vm_ip=$2
  local start_time=$(date +%s)
  
  expect "$test_file" "$vm_ip" > "$LOG_DIR/$test_name.log" 2>&1
  local exit_code=$?
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  record_result "$test_name" "$exit_code" "$duration"
}

# Geração de relatório
generate_report() {
  if [[ "$REPORT_FORMAT" == "json" ]]; then
    generate_json_report
  else
    generate_text_report
  fi
}
```

**Relatório JSON** (exemplo):
```json
{
  "test_suite": "fileserver-installer-expect",
  "version": "1.0.0",
  "timestamp": "2026-02-17T03:00:00Z",
  "environment": {
    "os": "Debian 13 Trixie",
    "qemu_version": "8.2.0",
    "expect_version": "5.45.4"
  },
  "summary": {
    "total": 26,
    "passed": 25,
    "failed": 1,
    "skipped": 0,
    "duration_seconds": 3600
  },
  "tests": [
    {
      "name": "test-install-auto-bios",
      "category": "scenario",
      "status": "passed",
      "duration_seconds": 1200,
      "vm_type": "bios",
      "log_file": "/var/log/test-install-auto-bios.log"
    },
    {
      "name": "test-step-identity",
      "category": "step",
      "status": "passed",
      "duration_seconds": 45,
      "vm_type": "uefi"
    }
  ],
  "failures": [
    {
      "name": "test-install-manual-raidz1",
      "error": "Timeout aguardando finalização",
      "log_file": "/var/log/test-install-manual-raidz1.log",
      "exit_code": 124
    }
  ]
}
```

## 6. Fases de Entrega

### Fase 1: Refatoração de UI (Instalador)
**Duração Estimada**: 15h

**Artefatos**:
- `ui-utils.sh` refatorado (consolidar wrappers, adicionar validações)
- `ui-validation.sh` criado (funções de validação)
- 21 etapas atualizadas (substituir interações por wrappers)
- Testes manuais completos (verificar cada etapa)

**Verificação**:
- [ ] Todas as etapas funcionam com gum
- [ ] Modo plain UI (`INSTALLER_PLAIN_UI=1`) funcional
- [ ] Nenhuma regressão funcional detectada
- [ ] Design System v2.0 consistente em todas as etapas

### Fase 2: Suite de Testes Expect
**Duração Estimada**: 17h

**Artefatos**:
- Bibliotecas expect (`expect-common.tcl`, `expect-config.tcl`, `expect-assertions.tcl`)
- 21 testes de etapas individuais
- 5 testes de cenários completos
- Executor da suite (`run-test-suite.sh`)
- Documentação (`scripts/vm/expect/README.md`)

**Verificação**:
- [ ] Suite completa executável via `run-test-suite.sh --all`
- [ ] Taxa de sucesso > 95% em ambiente controlado
- [ ] Relatórios JSON e texto gerados corretamente
- [ ] Tempo total de execução < 2 horas

### Fase 3: Integração e Documentação
**Duração Estimada**: 4h

**Artefatos**:
- Atualização de `AGENTS.md` (diretrizes de instalador e testes)
- Criação de `docs/INSTALLER_GUM_MIGRATION.md` (guia de mudanças)
- Atualização de `Makefile` (novos targets de teste)
- Atualização de `justfile` (comandos da suite expect)
- Atualização de `.pre-commit-config.yaml` (shellcheck nas etapas)

**Verificação**:
- [ ] Documentação completa e clara
- [ ] Comandos integrados ao workflow de desenvolvimento
- [ ] Hooks de qualidade configurados

## 7. Abordagem de Verificação

### 7.1 Testes Manuais (Fase 1)

**Processo**:
1. Build da ISO com instalador refatorado
2. Iniciar VM BIOS e VM UEFI
3. Executar instalação manual completa em cada VM
4. Validar modo plain UI (`INSTALLER_PLAIN_UI=1`)
5. Verificar cada etapa individualmente

**Critérios de Sucesso**:
- Instalação completa funcional em BIOS e UEFI
- Modo plain UI funcional (UX degradada mas utilizável)
- Nenhum erro de UI ou validação

### 7.2 Testes Automatizados (Fase 2)

**Processo**:
1. Executar suite completa: `./scripts/vm/expect/run-test-suite.sh --all`
2. Analisar relatório JSON
3. Investigar falhas via logs individuais
4. Iterar até taxa de sucesso > 95%

**Critérios de Sucesso**:
- 25+ de 26 testes passando
- Nenhum falso positivo detectado
- Tempo de execução < 2 horas

### 7.3 Comandos de Lint e Typecheck

**Lint (Shellcheck)**:
```bash
just lint
# Ou: make lint
# Shellcheck em todos os scripts do instalador e testes
```

**Verificação de Contratos**:
```bash
just verify-comment-contract
# Valida tags semânticas @INST_* em todos os arquivos
```

**Validação de Configurações**:
```bash
just validate-configs
# Valida JSONs e YAMLs do projeto
```

**Check Completo** (pré-commit recomendado):
```bash
just check
# Executa: lint + validate-configs + docs-verify + verify-comment-contract
```

## 8. Riscos e Mitigações

### 8.1 Quebra de Funcionalidades Existentes

**Risco**: Refatoração pode introduzir bugs sutis em etapas complexas

**Mitigação**:
- Testes manuais completos antes de cada commit
- Preservar versão anterior como fallback
- Implementação incremental etapa por etapa
- Code review rigoroso (via AGENTS.md)

### 8.2 Testes Instáveis (Flaky Tests)

**Risco**: Testes expect podem falhar intermitentemente devido a timing

**Mitigação**:
- Timeouts generosos (300s padrão, 1800s para instalação)
- Esperas explícitas (`after 120`) após comandos críticos
- Validação de estado antes de prosseguir
- Retry automático em operações de rede

### 8.3 Performance de Testes

**Risco**: Suite completa pode levar > 2 horas

**Mitigação**:
- Paralelização de testes independentes
- Uso de snapshots ZFS para acelerar setup de VMs
- Discos qcow2 com preallocação
- Opção `--test <nome>` para executar testes individuais

### 8.4 Manutenibilidade da Suite

**Risco**: Testes expect podem ficar difíceis de manter

**Mitigação**:
- Biblioteca comum de funções (DRY principle)
- Documentação clara de padrões
- Código modular e reutilizável
- Comentários explicando expectativas

## 9. Dependências e Pré-requisitos

### 9.1 Adicionar `expect` ao Live ISO

**Arquivo**: `config-overrides/config/package-lists/tools.list.chroot`

**Adição**:
```
expect
tcl
```

### 9.2 Garantir `gum` >= 0.14.0

**Status Atual**: gum já incluído em `/usr/local/bin/gum` (binário estático)

**Verificação**: Confirmar versão durante testes

### 9.3 Infraestrutura de VM

**Dependências do Host**:
- qemu-kvm
- libvirt (opcional, para gerenciamento)
- openssh-client

**Instalação**: Via `just setup-vm` ou `make setup-vm`

## 10. Notas de Implementação

### 10.1 Ordem de Implementação Recomendada

1. **Refatorar `ui-utils.sh`**: Consolidar wrappers, adicionar validações
2. **Criar `ui-validation.sh`**: Funções de validação
3. **Atualizar etapas simples** (welcome, finish, identity): 3-4 etapas primeiro
4. **Testar manualmente**: Garantir que mudanças funcionam
5. **Atualizar etapas médias** (locale, keyboard, network, time, user): 5-7 etapas
6. **Atualizar etapas complexas** (disk_select, zfs_*, review, install): 9-11 etapas
7. **Testar instalação completa manualmente**: BIOS e UEFI
8. **Criar bibliotecas expect**: Common, config, assertions
9. **Criar testes de etapas individuais**: 21 testes
10. **Criar testes de cenários completos**: 5 cenários
11. **Criar executor da suite**: `run-test-suite.sh`
12. **Integrar com justfile/Makefile**: Comandos de teste
13. **Documentar**: README, guia de migração, AGENTS.md

### 10.2 Padrão de Commit

**Convenção**: Semantic commits via `just commit`

**Exemplos**:
- `feat(installer): adicionar wrapper ui_filter para seleção com busca`
- `refactor(ui-utils): consolidar wrappers gum em ui-utils.sh`
- `test(expect): adicionar teste de etapa identity`
- `docs(installer): documentar mudanças de UI no guia de migração`

### 10.3 Compatibilidade com Versão Anterior

**Estratégia**: Substituição direta (sem coexistência)

**Justificativa**: É refatoração de UI, não de lógica. Mantemos modo plain UI como fallback.

**Rollback**: Versão anterior preservada em git (tag antes da refatoração)

## 11. Checklist de Conclusão

### Instalador Refatorado

- [ ] `ui-utils.sh` refatorado com wrappers completos
- [ ] `ui-validation.sh` criado com validações reutilizáveis
- [ ] 21 etapas atualizadas (todas usando wrappers)
- [ ] Modo plain UI funcional e testado
- [ ] Design System v2.0 consistente
- [ ] Testes manuais completos (BIOS + UEFI)
- [ ] Nenhuma regressão detectada

### Suite de Testes Expect

- [ ] Bibliotecas expect criadas (common, config, assertions)
- [ ] 21 testes de etapas individuais implementados
- [ ] 5 testes de cenários completos implementados
- [ ] Executor da suite (`run-test-suite.sh`) funcional
- [ ] Taxa de sucesso > 95% em 3 execuções consecutivas
- [ ] Tempo de execução < 2 horas
- [ ] Relatórios JSON e texto gerados corretamente

### Integração e Documentação

- [ ] `Makefile` atualizado com targets de teste
- [ ] `justfile` atualizado com comandos da suite
- [ ] `.pre-commit-config.yaml` atualizado (shellcheck)
- [ ] `docs/INSTALLER_GUM_MIGRATION.md` criado
- [ ] `scripts/vm/expect/README.md` criado
- [ ] `AGENTS.md` atualizado (diretrizes de instalador e testes)

---

**Documento criado em**: 2026-02-17  
**Versão**: 1.0  
**Status**: Pronto para Implementação
