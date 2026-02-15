## ADDED Requirements

### Requirement: Roteamento canonico de etapas

O orquestrador do instalador MUST definir e aplicar uma semantica canonica de transicao entre etapas,
incluindo caminhos de `next`, `prev` e `retry`, com comportamento deterministico para sucesso, cancelamento
e falha recuperavel.

#### Scenario: Transicao de etapa bem-sucedida

- **WHEN** uma etapa retorna sucesso com proxima etapa valida
- **THEN** o orquestrador avanca para a etapa declarada como `next`
- **AND** registra no log a etapa atual e a etapa de destino

### Requirement: Tratamento normativo de falha e retorno

O orquestrador SHALL mapear classes de retorno de etapa para acoes explicitas de navegacao, impedindo
loops silenciosos e garantindo que o operador receba orientacao objetiva de recuperacao.

#### Scenario: Falha em etapa com retorno para etapa anterior

- **WHEN** uma etapa retorna falha com politica de retorno para `prev`
- **THEN** o orquestrador retorna para a etapa anterior configurada
- **AND** registra motivo da falha e contexto minimo para diagnostico

### Requirement: Protecao contra regressao de navegacao

O orquestrador MUST impedir ciclos regressivos nao intencionais entre etapas criticas por meio de
validacoes de precondicao antes de executar operacoes destrutivas.

#### Scenario: Preflight antes de etapa destrutiva

- **WHEN** a navegacao chega a uma etapa com risco de alteracao irreversivel
- **THEN** o orquestrador executa validacoes de preflight obrigatorias
- **AND** bloqueia a continuidade se as precondicoes nao forem satisfeitas
