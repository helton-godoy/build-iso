## Purpose

Definir requisitos normativos para estado persistido do instalador, ownership e invariantes de fluxo.

## ADDED Requirements

### Requirement: Chaves de estado com ownership explicito

O contrato de estado do instalador MUST definir ownership explicito para chaves persistidas, incluindo
origem da escrita (etapa/lib), finalidade e momento de leitura, evitando sobrescrita implicita entre
dominios funcionais.

#### Scenario: Persistencia de chave com ownership rastreavel

- **WHEN** uma etapa grava chave de estado durante a execucao
- **THEN** a chave possui ownership associado ao componente que a produziu
- **AND** a leitura posterior consegue identificar origem e intencao da chave

### Requirement: Invariantes entre etapas criticas

O estado compartilhado SHALL declarar invariantes obrigatorios entre etapas criticas (ex.: disco,
topologia e instalacao), bloqueando avancos quando houver estado incompleto, conflitante ou invalido.

#### Scenario: Invariante violado antes da instalacao

- **WHEN** a etapa de instalacao identifica ausencia de chaves obrigatorias do plano
- **THEN** a transicao e bloqueada
- **AND** o operador recebe mensagem clara sobre quais precondicoes faltam

### Requirement: Compatibilidade de estado entre retries e retorno

O contrato de estado MUST preservar consistencia quando houver retry, retorno para etapa anterior ou
retomada de sessao, sem deixar residuos de estado que alterem o comportamento esperado do fluxo.

#### Scenario: Retry de etapa sem corrupcao de estado

- **WHEN** uma etapa e repetida apos falha recuperavel
- **THEN** o estado usado no retry reflete apenas dados validos e atuais
- **AND** dados stale sao descartados ou recalculados conforme contrato
