## ADDED Requirements

### Requirement: Configuração de Hostname
O sistema MUST permitir que o usuário defina o hostname da máquina.

#### Scenario: Definir Hostname
- **WHEN** solicitado no wizard
- **THEN** validar o input (apenas alfanuméricos e hífens)
- **AND** gravar em `/etc/hostname` e `/etc/hosts` no sistema alvo

### Requirement: Usuário Inicial
O sistema MUST criar um usuário inicial comum com permissões de sudo.

#### Scenario: Criar Usuário
- **WHEN** solicitado usuário e senha
- **THEN** criar usuário no sistema alvo
- **AND** adicionar aos grupos `sudo`, `plugdev`, `audio`, `video`
- **AND** definir senha fornecida

### Requirement: Configurações Regionais
O sistema MUST configurar timezone e locales básicos.

#### Scenario: Configuração Padrão
- **WHEN** o sistema é instalado
- **THEN** configurar timezone para UTC (ou perguntar, default UTC)
- **AND** gerar locales `en_US.UTF-8` e `pt_BR.UTF-8`

### Requirement: Networking Básico
O sistema MUST configurar rede via DHCP para a interface principal.

#### Scenario: Configurar Rede
- **WHEN** finalizar instalação
- **THEN** configurar `/etc/network/interfaces` ou NetworkManager para DHCP automático
- **AND** garantir resolução de nomes funcional
