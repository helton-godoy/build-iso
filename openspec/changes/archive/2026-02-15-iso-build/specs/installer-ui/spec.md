## ADDED Requirements

### Requirement: Design System Monocromático
O sistema MUST implementar uma interface visual monocromática baseada no tom "Slate Blue" para todas as interações com o usuário.

#### Scenario: Interface Consistente
- **WHEN** o instalador exibe qualquer tela
- **THEN** deve usar apenas tons da paleta Slate Blue (exceto mensagens de erro/sucesso)
- **AND** deve exibir o header "FILESERVER INSTALLER" estilizado

### Requirement: Componentes de UI
O sistema MUST fornecer funções reutilizáveis para componentes de interface padrão.

#### Scenario: Uso de Componentes
- **WHEN** um script precisa solicitar input ou exibir informação
- **THEN** deve usar funções do Design System (`fileserver_input`, `fileserver_section`, etc)
- **AND** não deve usar comandos `echo` crus para interação

### Requirement: Feedback de Progresso
O sistema MUST exibir progresso visual para operações demoradas.

#### Scenario: Operação Longa
- **WHEN** uma operação leva mais de 2 segundos (ex: criar pool)
- **THEN** deve exibir um spinner ou barra de progresso
- **AND** bloquear interação do usuário durante o processo
