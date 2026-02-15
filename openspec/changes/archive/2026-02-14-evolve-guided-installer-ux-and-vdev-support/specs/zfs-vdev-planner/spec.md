## ADDED Requirements

### Requirement: Planejamento explicito de vdevs de dados
O instalador SHALL permitir que o usuario defina a topologia de vdev de dados com representacao explicita do layout selecionado (stripe, mirror, raidz1, raidz2, raidz3 e draid quando habilitado).

#### Scenario: Selecao de topologia com visualizacao
- **WHEN** o usuario escolher a topologia de dados
- **THEN** o instalador deve exibir a representacao final do vdev e os discos associados

### Requirement: Validacao de minimo de discos por topologia
O instalador MUST validar quantidade minima de discos antes da confirmacao final e bloquear topologias invalidas com mensagem objetiva.

#### Scenario: Bloqueio de topologia invalida
- **WHEN** o usuario selecionar `raidz2` com menos de 3 discos
- **THEN** o instalador deve impedir o avanco e informar o minimo exigido

### Requirement: Composicao de multiplos top-level vdevs
O instalador SHALL suportar configuracao de mais de um top-level vdev de dados no mesmo pool quando o usuario optar por layout composto.

#### Scenario: Criacao de pool com vdevs compostos
- **WHEN** o usuario configurar dois vdevs de dados validos no plano
- **THEN** o instalador deve persistir ambos no plano canonico e apresentar o comando de provisionamento correspondente na revisao
