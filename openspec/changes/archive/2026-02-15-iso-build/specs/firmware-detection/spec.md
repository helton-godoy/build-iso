## ADDED Requirements

### Requirement: Detecção de Modo de Boot
O sistema MUST detectar automaticamente se o ambiente atual foi iniciado em modo UEFI ou Legacy BIOS.

#### Scenario: Ambiente UEFI
- **WHEN** o diretório `/sys/firmware/efi` existe
- **THEN** identificar o modo como "UEFI"
- **AND** configurar variáveis de instalação para suporte UEFI

#### Scenario: Ambiente BIOS
- **WHEN** o diretório `/sys/firmware/efi` NÃO existe
- **THEN** identificar o modo como "BIOS"
- **AND** configurar variáveis de instalação para suporte Legacy

### Requirement: Exibição de Modo de Boot
O sistema MUST informar ao usuário qual modo de boot foi detectado na tela de boas-vindas.

#### Scenario: Informar Usuário
- **WHEN** a tela inicial é carregada
- **THEN** exibir um card ou indicador com "Modo: UEFI" ou "Modo: BIOS"
