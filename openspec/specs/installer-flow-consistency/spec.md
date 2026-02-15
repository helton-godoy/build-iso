## ADDED Requirements

### Requirement: Estado canonico unico para execucao
O instalador SHALL consolidar todas as escolhas em um plano canonico de execucao e usar esse plano como unica fonte de verdade na etapa destrutiva.

#### Scenario: Execucao alinhada com revisao
- **WHEN** o usuario confirmar a revisao final
- **THEN** a etapa de instalacao deve executar exatamente os parametros exibidos no resumo

### Requirement: Deteccao de divergencia de estado
O instalador MUST detectar divergencia entre dados de revisao e dados de execucao antes de iniciar operacoes destrutivas.

#### Scenario: Divergencia detectada
- **WHEN** qualquer campo critico do plano estiver inconsistente entre estado persistido e estado em memoria
- **THEN** o instalador deve bloquear a execucao, exibir erro claro e orientar retorno ao step apropriado

### Requirement: Navegacao sem loop regressivo
O instalador SHALL impedir retorno ciclico entre revisao e instalacao causado por validacao tardia de pre-condicoes.

#### Scenario: Validacao de preflight antes de iniciar
- **WHEN** o usuario confirmar inicio da instalacao
- **THEN** o instalador deve executar todas as validacoes de preflight antes de qualquer alteracao em disco

### Requirement: Rastreabilidade normativa de transicoes de fluxo

O contrato de consistencia de fluxo MUST manter rastreabilidade entre transicoes reais executadas pelo
orquestrador e artefatos normativos (OpenSpec + mapa tecnico), incluindo correspondencia de identificador
de etapa e direcao de transicao.

#### Scenario: Evidencia de transicao alinhada ao contrato

- **WHEN** uma etapa registra transicao de fluxo no runtime
- **THEN** a transicao pode ser vinculada a requisito normativo correspondente
- **AND** inconsistencias de mapeamento sao detectaveis por validacao automatizada

### Requirement: Divergencia entre fluxo e documentacao bloqueia promocao

A consistencia de fluxo SHALL tratar divergencia entre comportamento executado e documentacao normativa
como risco operacional, com bloqueio de promocao ate reconciliacao.

#### Scenario: Fluxo executado diverge do contrato

- **WHEN** validadores detectam que `next/prev/retry` executado nao corresponde ao requisito normativo
- **THEN** a validacao retorna falha
- **AND** o relatorio identifica etapa, transicao e referencia documental afetada
