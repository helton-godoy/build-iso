## ADDED Requirements

### Requirement: Listagem de Discos
O sistema DEVE listar todos os dispositivos de bloco do tipo disco disponíveis no sistema, excluindo loop devices e a própria mídia de instalação.

#### Scenario: Listar Discos Disponíveis
- **WHEN** o usuário acessa a tela de seleção de disco
- **THEN** deve mostrar lista de discos físicos (ex: /dev/sda, /dev/nvme0n1)
- **AND** exibir modelo e capacidade legível (ex: "500GB Samsung SSD")

### Requirement: Filtro de Discos
O sistema DEVE ignorar dispositivos menores que o tamanho mínimo viável (20GB).

#### Scenario: Disco Muito Pequeno
- **WHEN** um pendrive de 4GB está conectado
- **THEN** ele não deve aparecer na lista de seleção principal
- **AND** garantir que o usuário não instale num dispositivo insuficiente

### Requirement: Seleção Única
O sistema DEVE permitir a seleção de apenas um disco de destino nesta versão.

#### Scenario: Selecionar Destino
- **WHEN** o usuário seleciona um disco da lista
- **THEN** armazenar o caminho do dispositivo (ex: `/dev/sda`) em variável global para uso nas próximas etapas
