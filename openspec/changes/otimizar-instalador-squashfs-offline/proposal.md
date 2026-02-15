## Why

O fluxo atual mistura objetivos de ISO compacta e instalação rápida/offline sem um contrato explícito
de requisitos, o que gera divergência entre documentação e comportamento real. Precisamos formalizar
uma mudança que priorize instalação previsível sem dependência de internet, com compressão SquashFS
otimizada para desempenho e compatibilidade.

## What Changes

- Definir um perfil normativo de SquashFS para a imagem live (algoritmo e parâmetros de compressão)
  orientado a tempo de boot/instalação, sem quebrar compatibilidade BIOS/UEFI.
- Definir requisitos de instalação offline para o instalador, incluindo comportamento esperado quando
  a mídia local está íntegra e quando artefatos offline estão ausentes.
- Definir requisitos de cache/reprodutibilidade do build para permitir reconstrução consistente e
  auditoria de resultados.
- Definir métricas e gates de aceitação (tempo de build, tempo de boot, tempo de instalação e tamanho
  da ISO) para comparação com baseline.

## Capabilities

### New Capabilities

- `squashfs-build-profile`: Perfil de compressão SquashFS para live-build com critérios de desempenho,
  compatibilidade e fallback.
- `offline-installer-source`: Contrato de instalação offline usando artefatos locais da mídia, com
  semântica de erro clara quando pré-condições não forem atendidas.
- `iso-build-metrics-gates`: Métricas e critérios de aceitação para validar ganhos de performance e
  controlar regressões no pipeline de ISO.

### Modified Capabilities

- Nenhuma. Esta change introduz capacidades novas sem alterar requisitos normativos das specs
  existentes em `openspec/specs/`.

## Impact

- Build ISO: `config-overrides/auto/config`, `scripts/docker/entrypoint.sh` e possíveis ajustes em
  cache/configuração do live-build.
- Runtime do instalador: `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/install.sh`
  e `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/install-utils.sh` para alinhar
  comportamento offline ao contrato.
- Testes/validação: `tests/test_iso_structure.sh`, testes de boot em VM e gates de benchmark para
  baseline vs. perfil novo.
- Operação: redução de dependência de rede durante instalação, com maior previsibilidade em cenários
  air-gapped.
