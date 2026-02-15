## ADDED Requirements

### Requirement: Prioridade de fonte local para instalacao offline

O instalador MUST priorizar artefatos locais da midia para instalacao offline antes de qualquer tentativa
de uso de fonte de rede.

#### Scenario: Midia local valida e disponivel

- **WHEN** o instalador inicia em modo offline e a midia local esta integra
- **THEN** a instalacao utiliza somente a fonte local como origem de pacotes/artefatos
- **AND** o fluxo nao depende de conectividade externa para concluir a instalacao base

### Requirement: Falha bloqueante para pre-condicao offline ausente

O instalador SHALL falhar de forma bloqueante e acionavel quando o modo offline for requerido e os
artefatos locais obrigatorios estiverem ausentes ou invalidos.

#### Scenario: Artefato offline ausente

- **WHEN** o preflight offline detecta ausencia de artefato local obrigatorio
- **THEN** a instalacao e interrompida antes de operacoes irreversiveis
- **AND** a mensagem de erro informa claramente a pre-condicao nao atendida

### Requirement: Comportamento auditavel de escolha de fonte

O processo de instalacao MUST registrar de forma auditavel qual fonte foi escolhida (local/offline ou
outro modo explicitamente permitido) para permitir rastreabilidade operacional.

#### Scenario: Registro de fonte efetiva no log

- **WHEN** a fase de instalacao seleciona a origem de artefatos
- **THEN** a origem efetiva fica registrada em evidencia de execucao
- **AND** o registro permite diagnosticar desvios de contrato offline
