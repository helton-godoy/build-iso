## 1. Baseline e alinhamento de escopo

- [x] 1.1 Revisar `proposal.md`, `design.md` e os 5 `spec.md` da change para validar fronteiras e dependencias entre capacidades
- [x] 1.2 Mapear evidencias atuais no repositorio (orquestrador, steps, libs e docs) e registrar lacunas de contrato por capacidade

## 2. Contrato de orquestracao e estado

- [x] 2.1 Documentar no mapa tecnico a semantica canonica de transicao (`next/prev/retry`) e classes de falha do orquestrador
- [x] 2.2 Definir e registrar ownership das chaves de estado (writer/reader) e invariantes obrigatorios entre etapas criticas
- [x] 2.3 Revisar pontos de retry/retorno para garantir que o contrato de estado cubra retomada sem residuos

## 3. Contrato de interfaces step/lib

- [x] 3.1 Catalogar interfaces entre `steps/*.sh` e `libs/*.sh` com pre-condicoes, entradas, saidas e erros esperados
- [x] 3.2 Registrar dependencias obrigatorias por etapa e padrao de falha controlada para dependencia ausente
- [x] 3.3 Validar consistencia entre contrato de interfaces e comportamento de navegacao do orquestrador

## 4. Gates de documentacao e rastreabilidade

- [x] 4.1 Aplicar/ajustar metadados semanticos necessarios para rastreabilidade normativa (`@INST_*` e PDS-Bash) nos pontos criticos
- [x] 4.2 Executar `make verify-docs` e corrigir nao conformidades relacionadas a cobertura e contrato documental
- [x] 4.3 Executar `make verify-comment-contract` e corrigir referencias quebradas de IDs/dependencias
- [x] 4.4 Gerar artefatos de evidencia com `make comment-index` e `make comment-graph` para auditoria do fluxo documentado

## 5. Fechamento da change e prontidao para aplicacao

- [x] 5.1 Atualizar documentos de governanca impactados (`docs/MAPA_INSTALLER.md`, `docs/COMMENT_PROTOCOL_PDS_BASH.md`, `AGENTS.md`) de forma coerente com as specs
- [x] 5.2 Executar checklist final de consistencia da change e registrar pendencias residuais em formato acionavel
- [x] 5.3 Preparar handoff para implementacao (`/opsx-apply`) com resumo de riscos, validacoes e criterios de aceite atendidos
