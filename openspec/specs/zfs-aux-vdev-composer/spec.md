## ADDED Requirements

### Requirement: Composicao de vdevs auxiliares
O instalador SHALL permitir adicionar vdevs auxiliares por classe (`log`, `cache`, `special`, `dedup`, `spare`) de forma opcional e independente dos vdevs de dados.

#### Scenario: Adicao de vdev auxiliar
- **WHEN** o usuario escolher adicionar uma classe auxiliar
- **THEN** o instalador deve coletar os discos dessa classe e registrar no plano de instalacao

### Requirement: Guardrails de compatibilidade por classe
O instalador MUST bloquear combinacoes invalidas por classe auxiliar e exibir motivo tecnico em linguagem simples.

#### Scenario: Restricao para log vdev
- **WHEN** o usuario tentar configurar `log` com layout nao permitido
- **THEN** o instalador deve impedir o avanco e informar a restricao aplicavel

### Requirement: Resumo de impacto por classe auxiliar
O instalador SHALL mostrar, para cada classe auxiliar configurada, o impacto esperado em resiliencia, desempenho e operacao.

#### Scenario: Revisao com classes auxiliares
- **WHEN** houver ao menos uma classe auxiliar no plano
- **THEN** a tela de revisao deve exibir lista por classe com discos associados e observacao de impacto
