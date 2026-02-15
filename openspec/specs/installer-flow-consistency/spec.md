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
