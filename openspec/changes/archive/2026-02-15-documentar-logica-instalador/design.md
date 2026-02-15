## Context

O instalador do projeto e composto por um orquestrador principal (`usr/local/bin/installer`) que executa
um fluxo de etapas shell (`steps/*.sh`) com estado persistido e bibliotecas compartilhadas (`libs/*.sh`).
O projeto ja possui base de rastreabilidade por metadados de etapa (`@INST_STEP_ID`, `@INST_STEP_FLOW`)
e protocolos semanticos adicionais para comentarios (`@ID`, `@STEP`, `@REQ`, `@FAIL`, `@DATA`).

Hoje, a logica operacional esta distribuida entre codigo e documentos, com bom conteudo tecnico, mas sem
um contrato normativo unico em OpenSpec para governar:

- comportamento do roteador de etapas (next/prev, retry, falha);
- contrato de estado em runtime (chaves, invariantes, origem de escrita);
- interfaces entre `steps` e bibliotecas;
- gates de consistencia documental para evitar divergencia entre implementacao e mapa tecnico.

Essa change formaliza esse contrato para reduzir regressao de fluxo, melhorar onboarding e fortalecer
auditoria/manutencao do instalador.

## Goals / Non-Goals

**Goals:**
- Definir arquitetura documental do orquestrador com regras claras de transicao e tratamento de erro.
- Definir contrato de estado do instalador com chaves, escopo e invariantes verificaveis.
- Definir contrato de interfaces entre steps e libs (entradas, saidas, pre-condicoes, pos-condicoes).
- Definir estrategia de validacao que conecte testes existentes (`test-docs`, `test-comment-contract`) ao
  contrato OpenSpec, com rastreabilidade entre docs e codigo.

**Non-Goals:**
- Nao reescrever o instalador ou alterar o comportamento funcional de instalacao nesta change.
- Nao introduzir nova stack, linguagem ou framework para o runtime do instalador.
- Nao substituir imediatamente todo documento existente; a mudanca foca contrato normativo e alinhamento.
- Nao tratar otimização de imagem/compactacao ISO (escopo da change de squashfs offline).

## Decisions

### 1) Fonte de verdade em camadas (OpenSpec normativo + docs operacionais)

**Decisao:** usar OpenSpec como fonte normativa de requisitos (capabilities/specs) e manter `docs/`
como material operacional e de consulta.

**Rationale:** reduz ambiguidade sobre o que e obrigatorio versus explicativo, mantendo a riqueza de
conteudo ja existente.

**Alternativas consideradas:**
- Concentrar tudo em `docs/` sem OpenSpec: rejeitada por baixa verificabilidade e rastreabilidade formal.
- Migrar todo `docs/` para OpenSpec de uma vez: rejeitada por custo alto e risco de perda de contexto.

### 2) Contrato explicito de orquestracao por transicoes e codigos de retorno

**Decisao:** modelar o roteador do instalador por transicoes de etapa (`next/prev/retry`) e semantica de
falha com comportamentos esperados por classe de erro.

**Rationale:** regressao recente de loop entre etapas mostrou que o risco maior esta na semantica de
transicao e nao apenas no conteudo de cada step.

**Alternativas consideradas:**
- Documentar somente lista de etapas: rejeitada por nao capturar dinamica de erro e retorno.
- Tratar apenas casos felizes: rejeitada por nao cobrir cenarios reais de operacao.

### 3) Contrato de estado orientado a invariantes

**Decisao:** documentar chaves de estado por dominio (identidade, rede, disco, topologia, install-plan,
confirmacao) e invariantes obrigatorios entre etapas criticas.

**Rationale:** integridade de estado e requisito de seguranca operacional; estados incompletos causam
falhas tardias de dificil diagnostico.

**Alternativas consideradas:**
- Documentar estado apenas por exemplos: rejeitada por permitir interpretacoes divergentes.
- Forcar schema rigido em runtime agora: rejeitada por ampliar escopo para implementacao.

### 4) Interfaces step/lib com pre e pos-condicoes

**Decisao:** cada capability de interface deve explicitar chamadas permitidas entre step e libs, entradas
minimas, efeitos de estado e saidas/erros esperados.

**Rationale:** evita acoplamento implicito e facilita manutencao de libs compartilhadas sem quebrar fluxo.

**Alternativas consideradas:**
- Contrato apenas por convencao textual: rejeitada por baixa auditabilidade.
- Criar wrappers obrigatorios para tudo agora: rejeitada por ser mudanca de implementacao, fora de escopo.

### 5) Gates de consistencia documental incremental

**Decisao:** reaproveitar validadores existentes e ampliar regras gradualmente, priorizando cobertura de
metadados e rastreabilidade antes de exigir perfeicao completa de todo legado.

**Rationale:** abordagem incremental reduz atrito e evita bloqueios por backlog historico.

**Alternativas consideradas:**
- Gate estrito imediato para todo repositório: rejeitada por alto risco de bloquear evolucao corrente.
- Sem gates automatizados: rejeitada por regressao silenciosa de qualidade documental.

## Risks / Trade-offs

- **[Sobrespecificacao documental]** -> Mitigacao: manter specs no nivel normativo (requisito), deixando
  detalhes de implementacao para design/task/code.
- **[Deriva entre docs e codigo]** -> Mitigacao: reforcar rastreabilidade por IDs e validar periodicamente
  com testes automatizados ja existentes.
- **[Aumento de custo de manutencao]** -> Mitigacao: padronizar templates e evoluir gates por fases.
- **[Conflito com changes paralelas de instalador]** -> Mitigacao: definir ownership e criterio de merge
  por capability, com revisao cruzada antes de sincronizar specs.

## Migration Plan

1. Criar specs novas para as capabilities de documentacao propostas e delta da capability modificada.
2. Mapear cada requisito a evidencias de codigo/docs (paths e marcadores semanticos).
3. Ajustar gates/documentacao para refletir o contrato aprovado sem alterar comportamento funcional.
4. Revisar consistencia com stakeholders tecnicos e aplicar refinamentos finais.
5. So apos validacao da change, iniciar implementacao de ajustes (se necessarios) em change separada ou
   fase de aplicacao (`/opsx-apply`).

**Rollback:** se houver divergencia relevante, manter apenas `proposal` e descartar `design/specs` desta
change ate consenso de escopo; nenhuma alteracao funcional do runtime depende desta etapa.

## Open Questions

- Qual granularidade minima desejada para as specs de interface (por biblioteca ou por grupo de steps)?
- O nivel de exigencia dos gates deve ser uniforme para todo legado ou faseado por areas de risco?
- Quais stakeholders devem aprovar o contrato final (engenharia de instalador, operacao NAS, QA)?
