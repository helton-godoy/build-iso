## ADDED Requirements

### Requirement: Contrato de chamadas entre step e biblioteca

Cada interface entre `steps/*.sh` e `libs/*.sh` MUST declarar precondicoes, parametros esperados,
efeitos de estado e saidas/erros possiveis, evitando acoplamento por comportamento implicito.

#### Scenario: Step consome biblioteca com contrato definido

- **WHEN** um step invoca uma funcao de biblioteca compartilhada
- **THEN** a invocacao segue assinatura e precondicoes documentadas
- **AND** o resultado permite decisao de fluxo sem ambiguidade

### Requirement: Dependencias explicitas e validaveis

As dependencias de bibliotecas por etapa SHALL ser declaradas de forma explicita e validavel, com
tratamento de erro normativo quando uma dependencia obrigatoria estiver indisponivel.

#### Scenario: Biblioteca obrigatoria ausente

- **WHEN** uma etapa nao consegue carregar biblioteca obrigatoria
- **THEN** a etapa retorna falha controlada
- **AND** o log informa dependencia ausente e impacto no fluxo

### Requirement: Semantica de retorno padronizada

As interfaces entre step e biblioteca MUST usar semantica de retorno padronizada para sucesso, erro
recuperavel e erro bloqueante, de modo consistente com o roteador principal.

#### Scenario: Biblioteca retorna erro recuperavel

- **WHEN** uma biblioteca sinaliza erro recuperavel
- **THEN** o step traduz o retorno conforme contrato de navegacao
- **AND** o orquestrador aplica a transicao esperada (`retry` ou `prev`)
