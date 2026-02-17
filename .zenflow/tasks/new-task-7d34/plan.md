# Full SDD workflow

## Configuration
- **Artifacts Path**: {@artifacts_path} → `.zenflow/tasks/{task_id}`

---

## Workflow Steps

### [x] Step: Requirements
<!-- chat-id: 461f584f-de10-469d-96e4-17625649553f -->

Create a Product Requirements Document (PRD) based on the feature description.

1. Review existing codebase to understand current architecture and patterns
2. Analyze the feature definition and identify unclear aspects
3. Ask the user for clarifications on aspects that significantly impact scope or user experience
4. Make reasonable decisions for minor details based on context and conventions
5. If user can't clarify, make a decision, state the assumption, and continue

Save the PRD to `{@artifacts_path}/requirements.md`.

### [x] Step: Technical Specification
<!-- chat-id: 666c8da7-7fed-4700-ac58-1436b4733e7b -->

Create a technical specification based on the PRD in `{@artifacts_path}/requirements.md`.

1. Review existing codebase architecture and identify reusable components
2. Define the implementation approach

Save to `{@artifacts_path}/spec.md` with:
- Technical context (language, dependencies)
- Implementation approach referencing existing code patterns
- Source code structure changes
- Data model / API / interface changes
- Delivery phases (incremental, testable milestones)
- Verification approach using project lint/test commands

### [x] Step: Planning
<!-- chat-id: fc607566-6c3a-46ab-98bd-aa05f83fc8ca -->

Plano de implementação criado baseado nas especificações técnicas e requisitos.

---

## FASE 1: Preparação e Bibliotecas UI (8-10h)

### [x] Step: Adicionar Dependência Expect ao Live ISO
<!-- chat-id: ad5989a0-f567-445b-bc27-e45ee937c52e -->
**Arquivo**: `config-overrides/config/package-lists/tools.list.chroot`
**Atividades**:
- Adicionar `expect` e `tcl` ao package-lists
- Verificar se gum >= 0.14.0 está presente

**Verificação**:
```bash
just validate-configs
grep -q "expect" config-overrides/config/package-lists/tools.list.chroot
```

### [x] Step: Criar Biblioteca ui-validation.sh
<!-- chat-id: cb1feead-8761-49de-9933-df67e66beab2 -->
**Arquivo**: `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-validation.sh`
**Funções a implementar**:
- `validate_hostname()` - RFC 1123
- `validate_domain()` - FQDN válido
- `validate_username()` - Sistema UNIX
- `validate_ip()` - IPv4/IPv6
- `validate_timezone()` - Timezone válida
- `validate_disk_path()` - /dev/* existente

**Padrão de código**:
- Tags semânticas `@INST_*`
- Indentação: tabs
- Retorno: 0=válido, 1=inválido
- Mensagens de erro via stderr

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-validation.sh
grep -q "@INST_FILE" config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-validation.sh
```

### [x] Step: Refatorar ui-utils.sh - Consolidar Wrappers Existentes
<!-- chat-id: 9d56a06b-945f-4e8b-b02e-0dfa6c114707 -->
**Arquivo**: `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-utils.sh`
**Atividades**:
1. Mover wrappers de `ui-gum.sh` para `ui-utils.sh`:
   - `ui_confirm()`
   - `ui_select()`
   - `ui_input()`
   - `ui_password()`
2. Melhorar fallbacks plain UI em cada wrapper
3. Integrar validações via callback opcional

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-utils.sh
grep -c "ui_confirm\|ui_select\|ui_input\|ui_password" config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-utils.sh
```

### [ ] Step: Adicionar Novos Wrappers Gum em ui-utils.sh
**Arquivo**: `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-utils.sh`
**Funções a adicionar**:
- `ui_choose()` - Seleção única/múltipla com gum choose
- `ui_filter()` - Seleção com busca incremental usando gum filter
- `ui_spin()` - Indicador de progresso para operações longas
- `ui_table()` - Exibição de dados em formato tabular

**API consistente**: `ui_<tipo> <titulo> [default] [validacao]`
**Fallback**: Implementar alternativas plain UI para cada função

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-utils.sh
grep -q "ui_choose\|ui_filter\|ui_spin\|ui_table" config-overrides/config/includes.chroot/usr/local/lib/installer/libs/ui-utils.sh
```

---

## FASE 2: Atualização de Etapas Simples (3-4h)

### [ ] Step: Atualizar Etapas Simples (welcome, finish)
**Arquivos**: 
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/welcome.sh`
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/finish.sh`

**Mudanças**:
- Substituir confirmações diretas por `ui_confirm()`
- Garantir Design System v2.0 consistente
- Testar fallback plain UI

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/welcome.sh
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/finish.sh
grep -v "read -r" config-overrides/config/includes.chroot/usr/local/lib/installer/steps/welcome.sh
```

### [ ] Step: Atualizar Etapa identity.sh
**Arquivo**: `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/identity.sh`
**Mudanças**:
- Substituir `read` por `ui_input()` com validação
- Hostname: `ui_input "Hostname" "" "validate_hostname"`
- Domínio: `ui_input "Domínio (opcional)" ""`

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/identity.sh
grep -q "ui_input.*validate_hostname" config-overrides/config/includes.chroot/usr/local/lib/installer/steps/identity.sh
```

---

## FASE 3: Atualização de Etapas Médias (4-5h)

### [ ] Step: Atualizar Etapas de Preferências (prefs_locale, prefs_keyboard)
**Arquivos**:
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_locale.sh`
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_keyboard.sh`

**Mudanças**:
- Substituir selects por `ui_filter()` para busca incremental
- Locale: `ui_filter "Selecione o idioma" "${locales[@]}"`
- Keyboard: `ui_filter "Layout do teclado" "${layouts[@]}"`

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_locale.sh
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/prefs_keyboard.sh
```

### [ ] Step: Atualizar Etapas network.sh e time.sh
**Arquivos**:
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/network.sh`
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/time.sh`

**Mudanças network.sh**:
- IP: `ui_input "Endereço IP" "" "validate_ip"`
- Gateway: `ui_input "Gateway" "" "validate_ip"`

**Mudanças time.sh**:
- Timezone: `ui_filter "Fuso horário" "${timezones[@]}"`

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/network.sh
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/time.sh
```

### [ ] Step: Atualizar Etapas user_account.sh e admin_policy.sh
**Arquivos**:
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/user_account.sh`
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/admin_policy.sh`

**Mudanças user_account.sh**:
- Username: `ui_input "Nome de usuário" "" "validate_username"`
- Password: `ui_password "Senha"`

**Mudanças admin_policy.sh**:
- Confirmações: `ui_confirm "Permitir sudo sem senha?" "n"`

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/user_account.sh
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/admin_policy.sh
```

---

## FASE 4: Atualização de Etapas Complexas - Discos (5-6h)

### [ ] Step: Atualizar disk_select.sh
**Arquivo**: `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_select.sh`
**Mudanças**:
- Lista de discos: `ui_choose "Selecione os discos" 1 "${disks[@]}"` (multi-select)
- Apresentação tabular: `ui_table "Disco,Tamanho,Tipo" "${disk_info[@]}"`

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_select.sh
grep -q "ui_choose.*1" config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_select.sh
```

### [ ] Step: Atualizar disk_wipe_confirm.sh
**Arquivo**: `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_wipe_confirm.sh`
**Mudanças**:
- Confirmação destrutiva: `ui_confirm "⚠️  ATENÇÃO: Todos os dados serão apagados! Confirma?" "n"`
- Design System v2.0 com alertas visuais

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/disk_wipe_confirm.sh
```

---

## FASE 5: Atualização de Etapas Complexas - ZFS (6-7h)

### [ ] Step: Atualizar zfs_strategy.sh
**Arquivo**: `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_strategy.sh`
**Mudanças**:
- Escolha: `ui_select "Estratégia ZFS" "Automática (recomendado)" "Manual (avançado)"`

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_strategy.sh
```

### [ ] Step: Atualizar zfs_auto_topology.sh
**Arquivo**: `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_topology.sh`
**Mudanças**:
- Topologia: `ui_select "Topologia ZFS" "Stripe" "Mirror" "RAIDZ1" "RAIDZ2"`
- Validações de quantidade de discos por topologia

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_topology.sh
```

### [ ] Step: Atualizar zfs_auto_properties.sh, zfs_aux_setup.sh, zfs_auto_datasets.sh
**Arquivos**:
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_properties.sh`
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_aux_setup.sh`
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_datasets.sh`

**Mudanças**:
- Properties: `ui_select` para opções de compressão, atime, etc.
- Aux pools: `ui_choose` para seleção de discos auxiliares
- Datasets: `ui_confirm` para criação de datasets opcionais

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_properties.sh
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_aux_setup.sh
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_auto_datasets.sh
```

### [ ] Step: Atualizar zfs_manual.sh
**Arquivo**: `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_manual.sh`
**Mudanças**:
- Input de comandos ZFS: `ui_input "Comando zpool create" "" "validate_zfs_command"`
- Validação básica de sintaxe

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/zfs_manual.sh
```

---

## FASE 6: Atualização de Etapas Finais (4-5h)

### [ ] Step: Atualizar boot.sh e review.sh
**Arquivos**:
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/boot.sh`
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/review.sh`

**Mudanças boot.sh**:
- Confirmação: `ui_confirm "Instalar ZFSBootMenu?" "y"`

**Mudanças review.sh**:
- Apresentação: `ui_table "Configuração,Valor" "${review_items[@]}"`
- Confirmação: `ui_confirm "Iniciar instalação?" "n"`

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/boot.sh
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/review.sh
```

### [ ] Step: Atualizar install.sh e post_install.sh
**Arquivos**:
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/install.sh`
- `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/post_install.sh`

**Mudanças install.sh**:
- Progresso de operações longas: `ui_spin "Instalando sistema base..." "debootstrap_command"`
- Feedback visual de cada etapa

**Mudanças post_install.sh**:
- Confirmações de configurações: `ui_confirm`
- Progresso: `ui_spin`

**Verificação**:
```bash
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/install.sh
shellcheck config-overrides/config/includes.chroot/usr/local/lib/installer/steps/post_install.sh
```

---

## FASE 7: Testes Manuais do Instalador (2-3h)

### [ ] Step: Testar Instalação Completa - BIOS
**Atividades**:
1. Build da ISO com instalador refatorado
2. Iniciar VM BIOS: `make test-vm-bios`
3. Executar instalação manual completa
4. Validar cada etapa individualmente
5. Verificar estado final do sistema

**Verificação**:
- Sistema bootável após instalação
- ZFS pool criado corretamente
- Todas as etapas funcionam sem erros
- Design System v2.0 consistente

### [ ] Step: Testar Instalação Completa - UEFI
**Atividades**:
1. Iniciar VM UEFI: `make test-vm-uefi`
2. Executar instalação manual completa
3. Validar cada etapa
4. Verificar boot UEFI funcional

**Verificação**:
- Sistema bootável em modo UEFI
- EFI System Partition criada
- ZFSBootMenu configurado

### [ ] Step: Testar Modo Plain UI
**Atividades**:
1. Iniciar VM com `INSTALLER_PLAIN_UI=1`
2. Executar instalação completa
3. Validar fallbacks funcionais
4. Verificar UX degradada mas utilizável

**Verificação**:
```bash
INSTALLER_PLAIN_UI=1 /usr/local/bin/installer
# Todas as etapas devem funcionar sem gum
```

---

## FASE 8: Suite de Testes Expect - Bibliotecas (3-4h)

### [ ] Step: Criar Estrutura de Diretórios da Suite Expect
**Diretórios a criar**:
```
scripts/vm/expect/
├── lib/
├── steps/
└── scenarios/
```

**Verificação**:
```bash
test -d scripts/vm/expect/lib
test -d scripts/vm/expect/steps
test -d scripts/vm/expect/scenarios
```

### [ ] Step: Criar expect-config.tcl
**Arquivo**: `scripts/vm/expect/lib/expect-config.tcl`
**Conteúdo**:
- Variáveis de ambiente (VM_IP, VM_USER, VM_PASSWORD)
- Timeouts padrão (60s, 300s, 1800s)
- Configurações de SSH
- Paths do instalador

**Verificação**:
```bash
expect -c "source scripts/vm/expect/lib/expect-config.tcl; puts \$default_timeout"
```

### [ ] Step: Criar expect-common.tcl
**Arquivo**: `scripts/vm/expect/lib/expect-common.tcl`
**Procedimentos**:
- `expect_step {pattern response timeout}` - Interação básica
- `expect_select {prompt options selected_index}` - Seleção em lista
- `expect_confirm {prompt expected_default}` - Confirmação sim/não
- `expect_input {prompt value}` - Entrada de texto
- `expect_multiline {prompts responses}` - Múltiplas entradas
- `log_test_step {message}` - Log estruturado
- `setup_test_state {step_id}` - Setup de estado
- `cleanup_test_state {}` - Limpeza

**Verificação**:
```bash
expect -c "source scripts/vm/expect/lib/expect-common.tcl; puts [info procs]"
shellcheck scripts/vm/expect/lib/expect-common.tcl
```

### [ ] Step: Criar expect-assertions.tcl
**Arquivo**: `scripts/vm/expect/lib/expect-assertions.tcl`
**Procedimentos**:
- `assert_state_key {key expected_value}` - Validar estado
- `assert_file_exists {path}` - Verificar arquivo
- `assert_zpool_exists {pool_name}` - Verificar ZFS pool
- `assert_boot_entries {}` - Verificar entradas de boot
- `assert_network_config {}` - Verificar configuração de rede

**Verificação**:
```bash
expect -c "source scripts/vm/expect/lib/expect-assertions.tcl; puts [info procs]"
```

---

## FASE 9: Suite de Testes Expect - Etapas Individuais (8-10h)

### [ ] Step: Criar Testes de Etapas 1-7 (Simples e Médias)
**Arquivos a criar**:
- `scripts/vm/expect/steps/test-step-welcome.exp`
- `scripts/vm/expect/steps/test-step-prefs_locale.exp`
- `scripts/vm/expect/steps/test-step-prefs_keyboard.exp`
- `scripts/vm/expect/steps/test-step-identity.exp`
- `scripts/vm/expect/steps/test-step-network.exp`
- `scripts/vm/expect/steps/test-step-time.exp`
- `scripts/vm/expect/steps/test-step-user_account.exp`

**Template**:
```tcl
#!/usr/bin/env expect
source [file join [file dirname $argv0] "../lib/expect-common.tcl"]
source [file join [file dirname $argv0] "../lib/expect-config.tcl"]

set timeout 60
setup_test_state "nome_etapa"

# Conectar SSH
spawn ssh -tt -o StrictHostKeyChecking=no ${vm_user}@${vm_ip}
expect -re {[$#] $}

# Executar etapa
send "source /usr/local/lib/installer/libs/ui-utils.sh\r"
send "source /usr/local/lib/installer/steps/nome_etapa.sh\r"
send "step_nome_etapa\r"

# Interações esperadas
expect_input "Prompt:" "valor"

# Validações
assert_state_key "CHAVE" "valor"

cleanup_test_state
exit 0
```

**Verificação**:
```bash
shellcheck scripts/vm/expect/steps/test-step-*.exp
ls -1 scripts/vm/expect/steps/ | wc -l  # Deve ser >= 7
```

### [ ] Step: Criar Testes de Etapas 8-14 (Discos e ZFS)
**Arquivos a criar**:
- `scripts/vm/expect/steps/test-step-admin_policy.exp`
- `scripts/vm/expect/steps/test-step-disk_select.exp`
- `scripts/vm/expect/steps/test-step-disk_wipe_confirm.exp`
- `scripts/vm/expect/steps/test-step-zfs_strategy.exp`
- `scripts/vm/expect/steps/test-step-zfs_auto_topology.exp`
- `scripts/vm/expect/steps/test-step-zfs_auto_properties.exp`
- `scripts/vm/expect/steps/test-step-zfs_aux_setup.exp`

**Particularidades**:
- Testes de disco: Setup com discos virtuais
- Testes ZFS: Validações de pool e datasets
- Timeouts maiores (120s-300s)

**Verificação**:
```bash
ls -1 scripts/vm/expect/steps/ | wc -l  # Deve ser >= 14
```

### [ ] Step: Criar Testes de Etapas 15-21 (Instalação e Finalização)
**Arquivos a criar**:
- `scripts/vm/expect/steps/test-step-zfs_auto_datasets.exp`
- `scripts/vm/expect/steps/test-step-zfs_manual.exp`
- `scripts/vm/expect/steps/test-step-boot.exp`
- `scripts/vm/expect/steps/test-step-review.exp`
- `scripts/vm/expect/steps/test-step-install.exp` (timeout 1800s)
- `scripts/vm/expect/steps/test-step-post_install.exp`
- `scripts/vm/expect/steps/test-step-finish.exp`

**Particularidades**:
- `test-step-install.exp`: Timeout muito longo (30 min)
- Validações de sistema instalado

**Verificação**:
```bash
ls -1 scripts/vm/expect/steps/ | wc -l  # Deve ser 21
```

---

## FASE 10: Suite de Testes Expect - Cenários Completos (6-8h)

### [ ] Step: Criar test-install-auto-bios.exp
**Arquivo**: `scripts/vm/expect/scenarios/test-install-auto-bios.exp`
**Cenário**: Instalação automática completa em BIOS
**Duração**: ~25 min
**Validações**:
- ZFS pool criado
- Boot entries corretos
- Sistema bootável

**Verificação**:
```bash
expect scripts/vm/expect/scenarios/test-install-auto-bios.exp
```

### [ ] Step: Criar test-install-auto-uefi.exp
**Arquivo**: `scripts/vm/expect/scenarios/test-install-auto-uefi.exp`
**Cenário**: Instalação automática completa em UEFI
**Validações adicionais**:
- EFI System Partition
- Boot UEFI funcional

**Verificação**:
```bash
expect scripts/vm/expect/scenarios/test-install-auto-uefi.exp
```

### [ ] Step: Criar test-install-manual-mirror.exp
**Arquivo**: `scripts/vm/expect/scenarios/test-install-manual-mirror.exp`
**Cenário**: Instalação manual com ZFS mirror (2 discos)
**Particularidades**:
- Seleção manual de topologia
- Validação de mirror funcionando

**Verificação**:
```bash
expect scripts/vm/expect/scenarios/test-install-manual-mirror.exp
```

### [ ] Step: Criar test-install-manual-raidz1.exp
**Arquivo**: `scripts/vm/expect/scenarios/test-install-manual-raidz1.exp`
**Cenário**: Instalação manual com ZFS raidz1 (3+ discos)
**Validações**:
- RAIDZ1 criado corretamente
- Redundância funcional

**Verificação**:
```bash
expect scripts/vm/expect/scenarios/test-install-manual-raidz1.exp
```

### [ ] Step: Criar test-install-error-recovery.exp
**Arquivo**: `scripts/vm/expect/scenarios/test-install-error-recovery.exp`
**Cenário**: Validação de tratamento de erros
**Testes**:
- Disco inválido
- Validação de hostname inválido
- Confirmação de wipe recusada
- Recuperação graceful

**Verificação**:
```bash
expect scripts/vm/expect/scenarios/test-install-error-recovery.exp
```

---

## FASE 11: Executor da Suite e Relatórios (3-4h)

### [ ] Step: Criar run-test-suite.sh
**Arquivo**: `scripts/vm/expect/run-test-suite.sh`
**Funcionalidades**:
- Parse de argumentos (`--all`, `--steps`, `--scenarios`, `--test <nome>`)
- Gerenciamento de VMs (criar/destruir)
- Execução sequencial ou paralela
- Captura de logs individuais
- Geração de relatórios (JSON e texto)
- Retry em falhas transitórias

**Interface CLI**:
```bash
./scripts/vm/expect/run-test-suite.sh --all --report json
./scripts/vm/expect/run-test-suite.sh --test test-step-identity
./scripts/vm/expect/run-test-suite.sh --scenarios --vm-type bios
```

**Verificação**:
```bash
shellcheck scripts/vm/expect/run-test-suite.sh
./scripts/vm/expect/run-test-suite.sh --help
```

### [ ] Step: Implementar Geração de Relatórios
**Funções a adicionar em run-test-suite.sh**:
- `generate_json_report()` - Relatório JSON estruturado
- `generate_text_report()` - Relatório texto humanizado
- `record_result()` - Registro de resultado de teste
- `calculate_statistics()` - Cálculo de taxa de sucesso

**Formato JSON**:
```json
{
  "test_suite": "fileserver-installer-expect",
  "summary": {
    "total": 26,
    "passed": 25,
    "failed": 1
  },
  "tests": [...]
}
```

**Verificação**:
```bash
./scripts/vm/expect/run-test-suite.sh --all --report json | jq .summary
```

---

## FASE 12: Integração e Documentação (3-4h)

### [ ] Step: Criar scripts/vm/expect/README.md
**Arquivo**: `scripts/vm/expect/README.md`
**Seções**:
1. Visão Geral da Suite
2. Estrutura de Diretórios
3. Como Executar Testes
4. Interpretar Resultados
5. Adicionar Novos Testes
6. Troubleshooting

**Verificação**:
```bash
test -f scripts/vm/expect/README.md
wc -l scripts/vm/expect/README.md  # >= 100 linhas
```

### [ ] Step: Atualizar Makefile com Targets da Suite Expect
**Arquivo**: `Makefile`
**Targets a adicionar**:
```makefile
test-expect-all:
	./scripts/vm/expect/run-test-suite.sh --all

test-expect-steps:
	./scripts/vm/expect/run-test-suite.sh --steps

test-expect-scenarios:
	./scripts/vm/expect/run-test-suite.sh --scenarios

test-expect-single:
	./scripts/vm/expect/run-test-suite.sh --test $(TEST)
```

**Verificação**:
```bash
make -n test-expect-all
```

### [ ] Step: Atualizar justfile com Comandos da Suite Expect
**Arquivo**: `justfile`
**Receitas a adicionar**:
```just
# Executar suite completa de testes expect
test-expect-all:
	./scripts/vm/expect/run-test-suite.sh --all --report text

# Executar testes de etapas individuais
test-expect-steps:
	./scripts/vm/expect/run-test-suite.sh --steps

# Executar testes de cenários completos
test-expect-scenarios:
	./scripts/vm/expect/run-test-suite.sh --scenarios

# Executar teste específico
test-expect TEST:
	./scripts/vm/expect/run-test-suite.sh --test {{TEST}}
```

**Verificação**:
```bash
just --list | grep test-expect
```

### [ ] Step: Criar docs/INSTALLER_GUM_MIGRATION.md
**Arquivo**: `docs/INSTALLER_GUM_MIGRATION.md`
**Seções**:
1. Motivação da Refatoração
2. Mudanças na Arquitetura UI
3. Guia de Migração de Código
4. Novos Wrappers Disponíveis
5. Modo Plain UI e Fallbacks
6. Padrões de Código
7. Exemplos Antes/Depois

**Verificação**:
```bash
test -f docs/INSTALLER_GUM_MIGRATION.md
```

### [ ] Step: Atualizar AGENTS.md com Diretrizes de Instalador
**Arquivo**: `AGENTS.md`
**Seções a adicionar**:
1. Diretrizes de UI com Gum
2. Convenções de Validação
3. Padrão de Testes Expect
4. Como Adicionar Novas Etapas

**Verificação**:
```bash
grep -q "Instalador" AGENTS.md
grep -q "gum" AGENTS.md
```

### [ ] Step: Atualizar .pre-commit-config.yaml
**Arquivo**: `.pre-commit-config.yaml`
**Hooks a adicionar**:
```yaml
- id: shellcheck
  name: Shellcheck Installer Steps
  entry: shellcheck
  language: system
  types: [shell]
  files: ^config-overrides/config/includes.chroot/usr/local/lib/installer/
```

**Verificação**:
```bash
pre-commit run --all-files shellcheck
```

---

## FASE 13: Validação Final e Ajustes (2-3h)

### [ ] Step: Executar Suite Completa de Testes - 1ª Rodada
**Comando**:
```bash
./scripts/vm/expect/run-test-suite.sh --all --report json > test-results-1.json
```

**Análise**:
- Verificar taxa de sucesso (meta: > 95%)
- Identificar testes instáveis (flaky tests)
- Revisar timeouts
- Analisar logs de falhas

**Ações**:
- Ajustar timeouts se necessário
- Corrigir bugs encontrados
- Adicionar esperas explícitas onde necessário

### [ ] Step: Executar Suite Completa de Testes - 2ª Rodada
**Objetivo**: Validar correções da 1ª rodada

**Verificação**:
```bash
./scripts/vm/expect/run-test-suite.sh --all --report json > test-results-2.json
jq '.summary.passed / .summary.total * 100' test-results-2.json  # >= 95%
```

### [ ] Step: Executar Suite Completa de Testes - 3ª Rodada
**Objetivo**: Confirmar estabilidade e reprodutibilidade

**Verificação**:
```bash
./scripts/vm/expect/run-test-suite.sh --all --report json > test-results-3.json
# Comparar resultados das 3 rodadas
```

**Critério de Sucesso**: 3 execuções consecutivas com taxa de sucesso > 95%

### [ ] Step: Executar Comandos de Lint e Qualidade
**Comandos**:
```bash
just lint                        # Shellcheck em todos os scripts
just validate-configs            # Validar JSONs e YAMLs
just verify-comment-contract     # Validar tags @INST_*
just check                       # Check completo
```

**Verificação**:
- Todos os comandos devem passar sem erros
- Corrigir problemas identificados

### [ ] Step: Verificar Tempo de Execução da Suite
**Objetivo**: Garantir que suite completa execute em < 2 horas

**Medição**:
```bash
time ./scripts/vm/expect/run-test-suite.sh --all
```

**Otimizações se necessário**:
- Paralelização de testes independentes
- Redução de timeouts excessivos
- Snapshots ZFS para acelerar setup

---

## Critérios de Conclusão Global

### Instalador Refatorado
- [ ] 18 bibliotecas atualizadas/criadas
- [ ] 21 etapas atualizadas usando wrappers gum
- [ ] Modo plain UI funcional
- [ ] Design System v2.0 consistente
- [ ] Testes manuais completos (BIOS + UEFI)
- [ ] Nenhuma regressão detectada

### Suite de Testes Expect
- [ ] 3 bibliotecas expect criadas
- [ ] 21 testes de etapas individuais
- [ ] 5 testes de cenários completos
- [ ] Executor da suite funcional
- [ ] Taxa de sucesso > 95% (3 rodadas consecutivas)
- [ ] Tempo de execução < 2 horas
- [ ] Relatórios JSON e texto corretos

### Integração e Documentação
- [ ] Makefile atualizado
- [ ] justfile atualizado
- [ ] .pre-commit-config.yaml atualizado
- [ ] docs/INSTALLER_GUM_MIGRATION.md criado
- [ ] scripts/vm/expect/README.md criado
- [ ] AGENTS.md atualizado

---

## Estimativa Total de Tempo

| Fase | Horas |
|------|-------|
| Fase 1: Preparação e Bibliotecas UI | 8-10h |
| Fase 2: Etapas Simples | 3-4h |
| Fase 3: Etapas Médias | 4-5h |
| Fase 4: Etapas Complexas - Discos | 5-6h |
| Fase 5: Etapas Complexas - ZFS | 6-7h |
| Fase 6: Etapas Finais | 4-5h |
| Fase 7: Testes Manuais | 2-3h |
| Fase 8: Suite Expect - Bibliotecas | 3-4h |
| Fase 9: Suite Expect - Etapas | 8-10h |
| Fase 10: Suite Expect - Cenários | 6-8h |
| Fase 11: Executor e Relatórios | 3-4h |
| Fase 12: Integração e Docs | 3-4h |
| Fase 13: Validação Final | 2-3h |
| **TOTAL** | **57-73h** |

**Nota**: Estimativa considera trabalho focado por agente LLM, incluindo iterações e ajustes.
