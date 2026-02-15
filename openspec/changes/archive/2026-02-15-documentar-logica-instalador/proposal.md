## Why

O instalador ja possui fluxo robusto em shell, com estado persistido, roteamento entre etapas e contrato
de metadados semanticos, mas esse conhecimento esta disperso entre scripts e documentos operacionais.
Precisamos formalizar a logica do instalador em OpenSpec para reduzir regressoes, acelerar onboarding
tecnico e tornar auditoria/manutencao mais previsiveis.

## What Changes

- Definir um contrato de documentacao do orquestrador do instalador (roteamento de steps, politica de
  avancar/voltar, tratamento de falha e comportamento de retry).
- Definir um contrato de estado do instalador (chaves persistidas, origem das mudancas e invariantes do
  fluxo entre etapas).
- Definir um contrato de interfaces entre `steps` e bibliotecas compartilhadas (`core-utils`,
  `state-utils`, `ui-utils`, `disk-utils`, `install-plan-utils`), com pre-condicoes e pos-condicoes.
- Definir criterios de cobertura documental e validacoes automatizadas para garantir consistencia entre
  implementacao shell, mapa tecnico e protocolos de comentarios semanticos.

## Capabilities

### New Capabilities

- `installer-orchestrator-documentation`: Documenta os requisitos normativos do roteador principal do
  instalador e a semantica de transicao entre etapas.
- `installer-state-contract`: Define requisitos para estado persistido em runtime, incluindo chaves,
  invariantes e regras de compatibilidade entre etapas.
- `installer-step-library-interfaces`: Define contrato entre `steps/*.sh` e libs compartilhadas,
  incluindo dependencias, entradas, saidas e erros esperados.
- `installer-documentation-gates`: Define criterios verificaveis de qualidade documental e consistencia
  com os protocolos semanticos ja adotados no projeto.

### Modified Capabilities

- `installer-flow-consistency`: explicitar requisitos de rastreabilidade entre fluxo real do orquestrador
  e artefatos documentais normativos.

## Impact

- Documentacao e governanca: `docs/MAPA_INSTALLER.md`, `docs/COMMENT_PROTOCOL_PDS_BASH.md`,
  `AGENTS.md` e possiveis referencias em `docs/ROADMAP.md`.
- Fluxo OpenSpec: novos arquivos em `openspec/changes/documentar-logica-instalador/specs/` e delta na
  capability existente `openspec/specs/installer-flow-consistency/spec.md`.
- Qualidade: alinhamento entre validadores existentes (`tests/test-docs.sh`, `tests/test-comment-contract.sh`)
  e os novos requisitos normativos de documentacao.
- Operacao/manutencao: diagnostico mais rapido de regressao de fluxo, menor dependencia de conhecimento
  tacito e base mais forte para RAG tecnico do instalador.
