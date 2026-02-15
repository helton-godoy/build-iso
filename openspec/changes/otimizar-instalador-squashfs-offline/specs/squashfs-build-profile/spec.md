## ADDED Requirements

### Requirement: Perfil padrao de compressao SquashFS

O pipeline de build da ISO MUST definir perfil padrao de compressao SquashFS com algoritmo explicito,
nivel configuravel e fallback controlado, preservando compatibilidade de boot em UEFI e BIOS.

#### Scenario: Build com perfil padrao aplicado

- **WHEN** o processo de build da ISO executa configuracao do live-build
- **THEN** o perfil de compressao SquashFS padrao e aplicado de forma explicita
- **AND** o perfil pode ser identificado por configuracao/auditoria do build

### Requirement: Fallback parametrico de compressao

O sistema de build SHALL permitir fallback parametrico de algoritmo/nivel de compressao sem edicao manual
de multiplos arquivos de pipeline.

#### Scenario: Selecao de perfil alternativo

- **WHEN** um perfil alternativo de compressao e solicitado por configuracao valida
- **THEN** o build utiliza o perfil alternativo definido
- **AND** a selecao fica registrada nas evidencias de build

### Requirement: Validacao do artefato SquashFS gerado

A validacao do build MUST confirmar que o artefato SquashFS final corresponde ao perfil de compressao
selecionado para a execucao.

#### Scenario: Artefato inconsistente com perfil

- **WHEN** o artefato SquashFS gerado nao corresponde ao perfil selecionado
- **THEN** a validacao falha
- **AND** o relatorio informa divergencia entre perfil esperado e artefato produzido
