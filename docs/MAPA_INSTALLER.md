# Mapa Tecnico do Instalador

Este documento consolida a logica de orquestracao do instalador shell, os contratos
de estado e as interfaces entre `steps` e `libs`.

Escopo: rastreabilidade normativa para reduzir regressao de fluxo e acelerar diagnostico.

## Fontes de verdade

- Requisitos normativos: `openspec/specs/installer-flow-consistency/spec.md`
- Delta normativo da change: `openspec/changes/documentar-logica-instalador/specs/`
- Protocolo semantico: `docs/COMMENT_PROTOCOL_PDS_BASH.md`

## 1) Orquestrador: semantica canonica de navegacao

Orquestrador principal: `config-overrides/config/includes.chroot/usr/local/bin/installer`

### Regras de transicao

- `next`: calculado por `compute_next_step` e aplicado por `goto_next`
- `prev`: calculado por `compute_prev_step` e aplicado por `goto_prev`
- `retry`: modelado como loop interno do step (ex.: `steps/disk_select.sh`), nao como
  transicao explicita do roteador

### Classes de resultado de step

- Sucesso (`0`): avanca para `next` (ou fim quando `next` vazio)
- Falha (`!= 0`) com `prev` definido: retorna para `prev`
- Falha sem `prev`: aborta com erro operacional seguro

### Guardrails

- Loop safety: limite de 200 iteracoes no `main_loop`
- Validacao de step existente antes da execucao
- Logging de entrada, sucesso e falha por etapa

## 2) Contrato de estado (`state_kv`)

Biblioteca: `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/state-utils.sh`

### Ownership de estado (writer/reader)

| Chave | Writer principal | Reader principal | Invariante |
| --- | --- | --- | --- |
| `current_step` | `installer` (`goto_step`) | `installer` (`state_load`) | Sempre aponta para step registrado |
| `install_disk` | `steps/disk_select.sh` | `steps/install.sh` | Nao vazio antes de `install` |
| `install_disks` | `steps/disk_select.sh` | `steps/install.sh`, `zfs_*` | CSV consistente com selecao atual |
| `install_plan_selected_disks` | `steps/disk_select.sh` | `install-plan-utils`, `steps/install.sh` | Alinhado a `install_disks` |
| `install_plan_data_vdevs` | `steps/zfs_auto_topology.sh` | `steps/install.sh` | Vazio apenas antes da definicao de topologia |
| `install_zfs_strategy` | `steps/zfs_strategy.sh` | `compute_next_step/prev_step` | `auto` ou `manual` |

### Invariantes criticos

- Antes de `install`: `install_disk` e `install_disks` devem estar preenchidos
- Se `install_zfs_strategy=manual`: fluxo deve passar por `zfs_manual`
- Mudanca de disco deve invalidar campos derivados de topologia (reset em `disk_select`)

## 3) Interfaces `steps` x `libs`

### API de UI

Arquivo: `libs/ui-utils.sh`

- Entrada em step: `ui_hero`, `ui_section`, `ui_card`, `ui_guidance`
- Entrada de usuario: `ui_input`, `ui_select`, `ui_filter_multiselect`, `ui_confirm`
- Erro/sucesso: `ui_error`, `ui_success`

Contrato: step nao deve depender de implementacao interna do `gum`, apenas da API
abstrata em `ui-utils.sh`.

### API de estado

Arquivo: `libs/state-utils.sh`

- Escrita: `state_kv_set`
- Leitura pontual: `state_kv_get`
- Carga de sessao: `state_load`

Contrato: toda troca de dados entre etapas deve usar `state_kv_*`.

### Dependencias por etapa (exemplo critico)

`disk_select` declara:

- `disk-utils.sh`
- `install-plan-utils.sh`

Semantica de falha controlada:

- Dependencia ausente gera `WARN` no roteador
- Se funcao requerida nao existir, step deve falhar de forma controlada com contexto de
  erro para retorno ao `prev`

## 4) Metadados semanticos e rastreabilidade

### Tags de fluxo ja estabelecidas

- `@INST_STEP_ID`
- `@INST_STEP_FLOW`
- `@INST_STATE`

### Tags PDS-Bash para blocos novos/criticos

- `@ID` e `@STEP` obrigatorias
- `@REQ`, `@FAIL`, `@DATA` quando aplicavel

Blocos criticos com IDs devem priorizar:

- orquestracao (`main_loop`, `step_invoke`, carregamento de dependencias)
- persistencia de estado (`state_kv_set`, `state_load`)
- etapas de risco (`disk_select`, `review`, `install`)

## 5) Gates e evidencias

### Validacoes obrigatorias

- `make verify-docs`
- `make verify-comment-contract`

### Evidencias de auditoria

- `make comment-index` -> `output/comment-index/comment-index.txt`
- `make comment-index` -> `output/comment-index/comment-index.jsonl`
- `make comment-graph` -> `output/comment-index/comment-flow.mmd`

## 6) Checklist operacional da change

- Contrato de transicoes `next/prev/retry` documentado e coerente com roteador
- Ownership de chaves de estado definido com invariantes
- Interfaces `steps/libs` catalogadas com dependencias e erros controlados
- Metadados semanticos aplicados em blocos criticos
- Gates executados e evidencias geradas

## 7) Pendencias residuais monitoradas

- Tratar `retry` como semantica explicita no contrato sem quebrar comportamento atual
- Fortalecer validacao automatica de divergencia entre `@INST_STEP_FLOW` e fluxo real
- Expandir matriz de ownership para todos os grupos `zfs_*` em mudanca dedicada
