## ADDED Requirements

### Requirement: Particionamento Híbrido
O sistema MUST criar uma tabela de partição GPT contendo partições necessárias para ambos os modos de boot (Hybrid Boot).

#### Scenario: Layout de Partição Universal
- **WHEN** o disco é particionado
- **THEN** criar partição 1: BIOS Boot (tipo `ef02`, 1MB)
- **AND** criar partição 2: EFI System Partition (tipo `ef00`, 512MB, FAT32)
- **AND** criar partição 3: Solaris Root (tipo `bf00`, restante do disco)

### Requirement: Limpeza de Disco
O sistema MUST limpar assinaturas de sistemas de arquivos e particionamentos anteriores antes de criar novas partições.

#### Scenario: Disco Reutilizado
- **WHEN** o disco alvo contém dados anteriores (ex: ZFS pools antigos, partições Windows)
- **THEN** executar `wipefs` em todo o disco
- **AND** destruir tabela de partição antiga (gdisk `o`)

### Requirement: Formatação ESP
O sistema MUST formatar a partição EFI como FAT32.

#### Scenario: Preparar ESP
- **WHEN** a partição 2 é criada
- **THEN** formatar com `mkfs.vfat -F32`
- **AND** definir label como "EFI"
