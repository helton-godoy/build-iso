# PRD: Nova Versão do Instalador com Gum e Suite de Testes Automatizados

## 1. Contexto e Problema

### 1.1 Contexto Atual

O projeto build-iso possui um instalador modular (`/usr/local/bin/installer`) que:

- **Arquitetura**: Sistema baseado em roteador (router) com carregamento preguiçoso de módulos de etapas
- **UI atual**: Utiliza `gum` para interface, mas de forma inconsistente em algumas partes
- **Estrutura modular**:
  - Router principal: `/usr/local/bin/installer`
  - Bibliotecas compartilhadas: `/usr/local/lib/installer/libs/` (19 arquivos)
  - Módulos de etapas: `/usr/local/lib/installer/steps/` (21 etapas)
- **Fluxo**: 21 etapas sequenciais desde welcome até finish
- **Estado**: Sistema de persistência em `/run/fileserver-installer/state.env`
- **Testes**: Script expect existente (`scripts/vm/expect-install-bios.exp`) para testes de boot BIOS, mas limitado

### 1.2 Problema

Apesar do instalador já utilizar `gum` em muitas partes, existem inconsistências e oportunidades de melhoria:

1. **Inconsistência de UI**: Algumas interações ainda utilizam mecanismos nativos do bash em vez de gum
2. **Cobertura de testes limitada**: Apenas um script expect para BIOS; falta cobertura UEFI e testes modulares
3. **Testabilidade**: Dificultar testar etapas individuais ou cenários específicos
4. **Modo plain UI**: Existe fallback `INSTALLER_PLAIN_UI=1` que precisa ser mantido e testado

## 2. Objetivos

### 2.1 Objetivo Principal

Criar uma nova versão do instalador que:

1. **Utilize gum de forma consistente e completa** em todos os pontos de interação
2. **Forneça suite completa de testes automatizados** usando expect para validação end-to-end e por etapa

### 2.2 Objetivos Específicos

#### 2.2.1 Instalador com Gum

- [ ] Padronizar todas as interações de usuário através de gum (input, select, confirm, choose, style)
- [ ] Manter compatibilidade com modo plain UI (`INSTALLER_PLAIN_UI=1`)
- [ ] Preservar a arquitetura modular existente (router + steps + libs)
- [ ] Garantir Design System v2.0 (monocromático slate) em todas as etapas
- [ ] Adicionar validações de entrada robustas usando gum filter onde apropriado

#### 2.2.2 Suite de Testes com Expect

- [ ] Script expect principal para instalação completa (BIOS e UEFI)
- [ ] Scripts expect modulares para testar etapas individuais
- [ ] Cobertura de cenários:
  - Instalação padrão (automática)
  - Instalação avançada (manual ZFS)
  - Diferentes topologias ZFS (stripe, mirror, raidz1)
  - Validação de erros e recuperação
- [ ] Framework de testes que permita:
  - Execução de suite completa
  - Execução de testes individuais
  - Relatórios de resultados
  - Integração com CI/CD

## 3. Requisitos Funcionais

### 3.1 RF01: Gum como Interface Única

**Descrição**: Todas as interações com o usuário devem utilizar componentes gum apropriados.

**Componentes Gum Requeridos**:

| Componente | Uso | Exemplo |
|------------|-----|---------|
| `gum input` | Entrada de texto livre | hostname, domain, username |
| `gum style` | Formatação e apresentação | títulos, cards, mensagens |
| `gum confirm` | Confirmações sim/não | confirmação de wipe, iniciar instalação |
| `gum choose` | Seleção única/múltipla | discos, idioma, timezone |
| `gum filter` | Seleção com busca incremental | timezone, keyboard layout |
| `gum spin` | Indicadores de progresso | operações demoradas |
| `gum table` | Apresentação tabular | revisão de configurações |

**Critérios de Aceitação**:
- ✅ Nenhuma chamada a `read` nativa do bash para entrada de usuário
- ✅ Todas as mensagens formatadas via `gum style`
- ✅ Validações de entrada implementadas antes de aceitar valores
- ✅ Modo plain UI continua funcional com fallback apropriado

### 3.2 RF02: Preservação da Arquitetura Modular

**Descrição**: A estrutura modular existente deve ser mantida e melhorada.

**Estrutura Preservada**:
```
/usr/local/bin/installer              # Router principal
/usr/local/lib/installer/
├── libs/                             # Bibliotecas compartilhadas
│   ├── ui-utils.sh                   # Componentes UI gum
│   ├── state-utils.sh                # Gerenciamento de estado
│   ├── core-utils.sh                 # Utilitários core
│   └── [outros]
└── steps/                            # Módulos de etapas
    ├── welcome.sh
    ├── prefs_locale.sh
    ├── [outras 19 etapas]
```

**Melhorias na Modularidade**:
- Refatorar `ui-utils.sh` para centralizar todos os wrappers gum
- Adicionar módulo `ui-validation.sh` para validações reutilizáveis
- Documentar contratos de entrada/saída de cada etapa

**Critérios de Aceitação**:
- ✅ Todas as 21 etapas existentes continuam funcionais
- ✅ Sistema de registro de etapas (`register_step`) mantido
- ✅ Carregamento preguiçoso (lazy loading) preservado
- ✅ Sistema de estado (`state-utils.sh`) mantido

### 3.3 RF03: Suite de Testes Automatizados com Expect

**Descrição**: Criar suite completa de testes automatizados usando expect para validar o instalador.

#### 3.3.1 Estrutura de Testes

```
scripts/vm/expect/
├── lib/
│   ├── expect-common.exp             # Funções comuns (expect_step, expect_select, etc)
│   ├── expect-config.exp             # Configurações e variáveis de ambiente
│   └── expect-assertions.exp         # Funções de validação
├── steps/                            # Testes de etapas individuais
│   ├── test-step-welcome.exp
│   ├── test-step-locale.exp
│   ├── test-step-keyboard.exp
│   └── [testes para todas as 21 etapas]
├── scenarios/                        # Testes de cenários completos
│   ├── test-install-auto-bios.exp
│   ├── test-install-auto-uefi.exp
│   ├── test-install-manual-mirror.exp
│   ├── test-install-manual-raidz1.exp
│   └── test-install-error-recovery.exp
└── run-test-suite.sh                 # Executor da suite

```

#### 3.3.2 Funcionalidades da Suite

**F1: Biblioteca Comum de Expect**

Funções reutilizáveis:
```tcl
# expect-common.exp
proc expect_step {pattern response} { ... }
proc expect_select {options selected_index} { ... }
proc expect_confirm {expected_default} { ... }
proc expect_input {prompt value} { ... }
proc expect_multiline_prompt {prompts responses} { ... }
```

**F2: Testes de Etapas Individuais**

Cada etapa possui teste dedicado que:
- Inicializa estado mínimo necessário
- Executa a etapa
- Valida saída esperada
- Verifica estado final

**F3: Testes de Cenários Completos**

Cenários cobertos:
1. **Instalação Automática BIOS**: Fluxo completo com defaults
2. **Instalação Automática UEFI**: Fluxo completo com defaults
3. **Instalação Manual Mirror**: ZFS mirror com 2 discos
4. **Instalação Manual RAIDZ1**: ZFS raidz1 com 3+ discos
5. **Recuperação de Erros**: Validação de tratamento de erros

**F4: Executor da Suite**

```bash
# run-test-suite.sh - Executor da suite de testes

# Uso:
./scripts/vm/expect/run-test-suite.sh [opções]

# Opções:
#   --all              Executa todos os testes
#   --steps            Executa testes de etapas individuais
#   --scenarios        Executa testes de cenários completos
#   --test <nome>      Executa teste específico
#   --report [json|text] Formato do relatório (default: text)
#   --vm-cleanup       Limpa VMs após execução
```

**Critérios de Aceitação**:
- ✅ Suite executa todos os testes automaticamente
- ✅ Testes podem ser executados individualmente
- ✅ Relatório de resultados em formato texto e JSON
- ✅ Testes falham apropriadamente quando instalador tem erro
- ✅ Testes validam estado final do sistema instalado
- ✅ Tempo total de execução < 2 horas para suite completa

### 3.4 RF04: Modo Plain UI Compatível

**Descrição**: Manter suporte ao modo texto puro sem gum para ambientes limitados.

**Comportamento**:
- Variável `INSTALLER_PLAIN_UI=1` ativa modo plain
- Todas as funções em `ui-utils.sh` possuem fallback
- Testes expect validam ambos os modos (gum e plain)

**Critérios de Aceitação**:
- ✅ Instalação funcional com `INSTALLER_PLAIN_UI=1`
- ✅ Testes expect cobrem modo plain
- ✅ Experiência degradada mas funcional sem gum

## 4. Requisitos Não-Funcionais

### 4.1 RNF01: Performance

- Suite de testes completa deve executar em < 2 horas
- Cada teste individual de etapa < 2 minutos
- Instalação completa (tempo real) < 30 minutos

### 4.2 RNF02: Confiabilidade

- Taxa de sucesso de testes > 95% em ambiente estável
- Timeouts apropriados para operações longas (zpool create, debootstrap)
- Retry automático em falhas transitórias de rede

### 4.3 RNF03: Manutenibilidade

- Código com tags semânticas `@INST_*` mantidas
- Funções documentadas com descrição, args e retorno
- Testes com comentários explicando expectativas

### 4.4 RNF04: Compatibilidade

- Suporta Debian 13 (Trixie)
- Funciona em BIOS e UEFI
- Compatível com gum >= 0.14.0
- Compatível com expect >= 5.45

## 5. Escopo

### 5.1 Em Escopo

#### 5.1.1 Instalador
- ✅ Refatoração de `ui-utils.sh` para gum consistente
- ✅ Atualização de todas as 21 etapas para usar gum via ui-utils
- ✅ Validações de entrada robustas
- ✅ Testes manuais de cada etapa
- ✅ Manter modo plain UI funcional

#### 5.1.2 Suite de Testes
- ✅ Biblioteca comum de funções expect
- ✅ Testes de etapas individuais (21 etapas)
- ✅ Testes de cenários completos (5 cenários)
- ✅ Executor da suite (run-test-suite.sh)
- ✅ Relatórios de resultados

### 5.2 Fora de Escopo

#### 5.2.1 Instalador
- ❌ Mudanças na lógica de negócio das etapas (apenas UI)
- ❌ Novas funcionalidades ou etapas
- ❌ Mudanças no sistema de boot (ZFSBootMenu)
- ❌ Alterações em hooks do live-build

#### 5.2.2 Testes
- ❌ Testes unitários de funções bash (foco em testes end-to-end)
- ❌ Testes de performance detalhados
- ❌ Integração com GitHub Actions (pode ser fase posterior)
- ❌ Testes de stress ou carga

## 6. Critérios de Sucesso

### 6.1 Instalador

1. **Consistência de UI**: 100% das interações usando gum ou fallback documentado
2. **Sem Regressões**: Todas as funcionalidades existentes continuam funcionais
3. **Validações**: Todas as entradas possuem validação apropriada
4. **Modo Plain**: Funciona corretamente sem gum

### 6.2 Suite de Testes

1. **Cobertura**: 21 testes de etapas + 5 testes de cenários implementados
2. **Taxa de Sucesso**: > 95% em ambiente de teste controlado
3. **Documentação**: README explicando como executar e interpretar resultados
4. **Automatização**: Suite executável com um único comando

## 7. Riscos e Mitigações

### 7.1 Risco: Quebrar Funcionalidades Existentes

**Probabilidade**: Média  
**Impacto**: Alto

**Mitigação**:
- Testes manuais completos antes de substituir versão
- Manter versão anterior como backup
- Implementação incremental etapa por etapa

### 7.2 Risco: Testes Instáveis (Flaky Tests)

**Probabilidade**: Alta  
**Impacto**: Médio

**Mitigação**:
- Timeouts generosos para operações I/O
- Esperas explícitas após comandos destrutivos
- Validação de estado antes de prosseguir
- Retry em operações de rede

### 7.3 Risco: Performance de Testes

**Probabilidade**: Média  
**Impacto**: Médio

**Mitigação**:
- Paralelização de testes onde possível
- Uso de snapshots ZFS para acelerar setup
- Discos qcow2 com preallocação para VMs

### 7.4 Risco: Complexidade de Manutenção

**Probabilidade**: Baixa  
**Impacto**: Alto

**Mitigação**:
- Biblioteca comum de funções expect
- Documentação clara de padrões
- Código modular e reutilizável

## 8. Entregas

### 8.1 Entrega 1: Instalador Refatorado

**Artefatos**:
- `/usr/local/bin/installer` (atualizado)
- `/usr/local/lib/installer/libs/ui-utils.sh` (refatorado)
- `/usr/local/lib/installer/libs/ui-validation.sh` (novo)
- `/usr/local/lib/installer/steps/*.sh` (21 etapas atualizadas)
- `docs/INSTALLER_GUM_MIGRATION.md` (guia de mudanças)

**Critério de Conclusão**:
- Todos os testes manuais passando
- Documentação atualizada

### 8.2 Entrega 2: Suite de Testes Expect

**Artefatos**:
- `scripts/vm/expect/lib/*.exp` (3 arquivos de biblioteca)
- `scripts/vm/expect/steps/*.exp` (21 testes de etapas)
- `scripts/vm/expect/scenarios/*.exp` (5 testes de cenários)
- `scripts/vm/expect/run-test-suite.sh` (executor)
- `scripts/vm/expect/README.md` (documentação)

**Critério de Conclusão**:
- Suite completa executável
- Documentação de uso criada
- Taxa de sucesso > 95% em 3 execuções consecutivas

## 9. Cronograma Estimado

**Nota**: Estimativas baseadas em trabalho focado por agente LLM.

| Fase | Atividade | Estimativa |
|------|-----------|-----------|
| 1 | Análise e planejamento detalhado | ✅ (atual) |
| 2 | Refatoração ui-utils.sh | 2h |
| 3 | Criação ui-validation.sh | 1h |
| 4 | Atualização etapas 1-7 (preferências, identidade, rede, tempo, usuário) | 3h |
| 5 | Atualização etapas 8-14 (discos, ZFS) | 4h |
| 6 | Atualização etapas 15-21 (boot, review, install, finish) | 3h |
| 7 | Testes manuais e ajustes | 2h |
| 8 | Biblioteca expect comum | 2h |
| 9 | Testes de etapas individuais (21 testes) | 8h |
| 10 | Testes de cenários completos (5 cenários) | 5h |
| 11 | Executor da suite e relatórios | 2h |
| 12 | Documentação completa | 2h |
| 13 | Validação final e ajustes | 2h |
| **Total** | | **36h** |

## 10. Dependências

### 10.1 Dependências de Sistema

- **gum** >= 0.14.0 (já incluído em `/usr/local/bin/gum`)
- **expect** >= 5.45 (precisa verificar se está no package-lists)
- **bash** >= 5.1
- **qemu-kvm** para VMs de teste

### 10.2 Dependências de Projeto

- Arquitetura modular existente do instalador
- Sistema de estado em `/run/fileserver-installer`
- Scripts de VM existentes em `scripts/vm/`
- Live-build configurado em `config-overrides/`

## 11. Perguntas para Esclarecimento

### 11.1 Prioridades

**P1**: Qual deve ser a prioridade entre instalador refatorado e suite de testes?

**Opções**:
- A) Instalador primeiro, testes depois (sequencial)
- B) Em paralelo (incrementos simultâneos)
- C) Testes primeiro (TDD approach)

**Sugestão**: Opção A (sequencial) para validar mudanças antes de testar.

### 11.2 Cobertura de Testes

**P2**: Qual nível de cobertura de testes é suficiente?

**Opções**:
- A) Apenas cenários principais (auto BIOS/UEFI) - ~2 testes
- B) Cenários principais + etapas críticas (discos, ZFS) - ~10 testes
- C) Cobertura completa conforme especificado (21 + 5) - ~26 testes

**Sugestão**: Opção B para balancear cobertura e esforço, com possibilidade de expandir para C posteriormente.

### 11.3 Modo Plain UI

**P3**: Qual nível de suporte ao modo plain UI é requerido?

**Opções**:
- A) Suporte completo com paridade de funcionalidades
- B) Suporte básico (funcional mas UX degradada)
- C) Deprecar e focar apenas em gum

**Sugestão**: Opção B (suporte básico) para manter compatibilidade sem duplicar esforço.

### 11.4 Compatibilidade com Versão Anterior

**P4**: Como lidar com a transição da versão atual?

**Opções**:
- A) Substituir diretamente (sem backward compatibility)
- B) Coexistir temporariamente (`installer` e `installer-legacy`)
- C) Feature flag para ativar nova versão (`INSTALLER_USE_NEW=1`)

**Sugestão**: Opção A (substituir diretamente) dado que é refatoração de UI, não de lógica.

## 12. Glossário

| Termo | Definição |
|-------|-----------|
| **Gum** | Ferramenta CLI para criar interfaces de terminal interativas |
| **Expect** | Ferramenta para automação de aplicações interativas |
| **Plain UI** | Modo de interface texto puro sem componentes gum |
| **Step** | Etapa individual do fluxo de instalação (21 no total) |
| **Router** | Script principal (`installer`) que gerencia fluxo de etapas |
| **State** | Sistema de persistência de configurações em `/run/fileserver-installer` |
| **Lazy Loading** | Carregamento sob demanda de módulos de etapas |
| **ZFS Strategy** | Escolha entre modo automático ou manual para configuração ZFS |

## 13. Anexos

### A. Mapeamento de Componentes Gum por Etapa

| Etapa | Componentes Gum Usados |
|-------|------------------------|
| welcome | style, confirm |
| prefs_locale | filter, choose, style |
| prefs_keyboard | filter, choose, input (teste) |
| identity | input (hostname, domain) |
| network | choose, input, confirm |
| time | filter, choose, input (NTP), confirm |
| user_account | input (3x), password (2x) |
| admin_policy | confirm (2x), password (condicional) |
| disk_select | choose (multi), table |
| disk_wipe_confirm | input (palavra-chave "APAGAR") |
| zfs_strategy | choose |
| zfs_auto_topology | choose (múltiplas escolhas) |
| zfs_auto_properties | choose, confirm |
| zfs_aux_setup | confirm (5x), choose (condicional) |
| zfs_auto_datasets | choose, confirm |
| zfs_manual | input (múltiplos), choose |
| boot | choose, input (params) |
| review | table, confirm (2x) |
| install | spin, style (progresso) |
| post_install | spin, style |
| finish | style, confirm (reboot) |

### B. Estrutura de Relatório de Testes

```json
{
  "test_suite": "fileserver-installer-expect",
  "version": "1.0.0",
  "timestamp": "2026-02-17T02:46:00Z",
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
    "duration_seconds": 5400
  },
  "tests": [
    {
      "name": "test-install-auto-bios",
      "category": "scenario",
      "status": "passed",
      "duration_seconds": 1200,
      "vm_type": "bios"
    },
    {
      "name": "test-step-locale",
      "category": "step",
      "status": "passed",
      "duration_seconds": 45
    }
  ],
  "failures": [
    {
      "name": "test-install-manual-raidz1",
      "error": "Timeout aguardando finalização",
      "log_file": "/var/log/test-install-manual-raidz1.log"
    }
  ]
}
```

---

**Documento criado em**: 2026-02-17  
**Versão**: 1.0  
**Status**: Em Revisão
