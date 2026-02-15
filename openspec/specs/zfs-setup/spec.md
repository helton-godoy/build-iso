# zfs-setup Specification

## Purpose
TBD - created by archiving change iso-build. Update Purpose after archive.
## Requirements
### Requirement: Criação de Pool Otimizado
O sistema MUST criar o pool ZFS `zroot` com propriedades otimizadas para performance e compatibilidade Linux.

#### Scenario: Criar zroot
- **WHEN** o pool é criado na partição 3
- **THEN** definir `ashift=12` (assumindo Advanced Format)
- **AND** definir `acltype=posixacl`, `xattr=sa`, `compression=zstd`
- **AND** definir `normalization=formD`

### Requirement: Hierarquia de Datasets ZBM
O sistema MUST criar datasets seguindo a estrutura exigida pelo ZFSBootMenu para Boot Environments.

#### Scenario: Estrutura Base
- **WHEN** o pool e criado
- **THEN** criar `zroot/ROOT` com `canmount=off` e `mountpoint=none`
- **AND** definir `org.zfsbootmenu:commandline="quiet"` em `zroot/ROOT`

#### Scenario: Boot Environment Inicial
- **WHEN** o sistema base é instalado
- **THEN** criar `zroot/ROOT/debian`
- **AND** definir `mountpoint=/` e `canmount=noauto` para este dataset

### Requirement: Datasets de Dados
O sistema MUST separar dados de usuário e sistema do dataset raiz.

#### Scenario: Datasets Separados
- **WHEN** a hierarquia é montada
- **THEN** criar `zroot/home` (mountpoint=/home)
- **AND** criar `zroot/var`, `zroot/var/log`, `zroot/var/tmp` com configurações específicas

