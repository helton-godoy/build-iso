## ADDED Requirements

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
