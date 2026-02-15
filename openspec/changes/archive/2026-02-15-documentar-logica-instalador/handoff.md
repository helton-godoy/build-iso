# Handoff de Implementacao - documentar-logica-instalador

## Escopo concluido nesta sessao

- Contrato normativo da change criado e completo (`proposal`, `design`, `specs`, `tasks`).
- Mapa tecnico do instalador consolidado em `docs/MAPA_INSTALLER.md` com:
  - semantica canonica `next/prev/retry`
  - ownership de estado (`state_kv`) e invariantes criticos
  - interfaces `steps` x `libs` e padrao de falha controlada
  - gates/evidencias e checklist operacional
- Protocolo PDS-Bash atualizado para perfil do instalador em
  `docs/COMMENT_PROTOCOL_PDS_BASH.md`.
- Guia operacional atualizado em `AGENTS.md` para manter alinhamento com a change.

## Ajustes de rastreabilidade aplicados no codigo

- `usr/local/bin/installer`: IDs semanticos em blocos criticos de orquestracao
  (`INSTALLER_LAZY_SOURCE_DEPS`, `INSTALLER_STEP_INVOKE`, `INSTALLER_MAIN_LOOP`,
  `INSTALLER_DEP_NOT_FOUND`, `INSTALLER_STEP_FAILED`, `INSTALLER_ABORT`).
- `libs/state-utils.sh`: IDs semanticos para preparo, escrita, leitura e carga de estado
  (`STATE_PREPARE`, `STATE_KV_SET`, `STATE_WRITE_FAILED`, `STATE_KV_GET`, `STATE_LOAD_EXPORT`).
- `steps/disk_select.sh`: IDs semanticos para fluxo da etapa e cancelamento controlado
  (`STEP_DISK_SELECT_FLOW`, `STEP_DISK_SELECT_CANCELLED`).

## Validacoes executadas

- `make verify-docs` -> PASS (com warnings legados fora do escopo da change)
- `make verify-comment-contract` -> PASS
- `make comment-index` -> PASS
- `make comment-graph` -> PASS

## Pendencias residuais (acionaveis)

1. Cobertura `@DEV_*` em scripts de VM/docker ainda tem warnings em `make verify-docs`.
2. Cobertura `@TEST_*` em diversas suites de testes ainda tem warnings em `make verify-docs`.
3. Nao foi introduzido parser automatico para comparar `@INST_STEP_FLOW` vs fluxo real do roteador;
   a regra esta documentada, mas o gate ainda e parcial.

## Proxima acao recomendada

- Se a intencao for executar implementacao operacional adicional, seguir com
  `openspec instructions apply --change documentar-logica-instalador` e focar nas
  pendencias residuais acima em uma change dedicada de hardening documental.
