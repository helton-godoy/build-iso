## ADDED Requirements

### Requirement: Baseline versionado de metricas do pipeline ISO

O processo de build e validacao da ISO MUST manter baseline versionado para metricas de tamanho da ISO,
tempo de build, tempo de boot e tempo de instalacao.

#### Scenario: Comparacao com baseline disponivel

- **WHEN** uma nova execucao de build/validacao e realizada
- **THEN** as metricas coletadas sao comparadas com baseline versionado
- **AND** o resultado da comparacao fica registrado como evidencia auditavel

### Requirement: Gate de regressao de performance

O pipeline SHALL aplicar gates de regressao com limites explicitos para variacoes aceitaveis das metricas
definidas, bloqueando promocao quando limites forem excedidos.

#### Scenario: Regressao acima do limite aceito

- **WHEN** uma metrica excede o limite de regressao definido pelo contrato
- **THEN** o gate retorna falha
- **AND** o relatorio identifica metrica, baseline e variacao observada

### Requirement: Validacao de firmware como criterio de aceite

Os criterios de aceite MUST incluir validacao de boot em UEFI e BIOS para os perfis de build suportados,
assegurando que otimizacao de imagem nao degrade compatibilidade de inicializacao.

#### Scenario: Perfil aprovado em um firmware e reprovado em outro

- **WHEN** a validacao de firmware detecta incompatibilidade de boot em um dos modos suportados
- **THEN** o perfil nao e promovido
- **AND** a evidencia de teste registra modo de firmware afetado e causa da falha
