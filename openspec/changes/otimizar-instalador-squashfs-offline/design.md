## Context

A change `otimizar-instalador-squashfs-offline` formaliza requisitos para reduzir dependencia de internet
no fluxo de instalacao e melhorar previsibilidade de performance da ISO. Hoje o build ja usa live-build
com suporte a SquashFS, mas ainda ha risco de divergencia entre perfil de compressao, comportamento do
instalador em modo offline e criterios de aceite de performance.

Estado atual relevante:

- `config-overrides/auto/config` define opcoes de build e compressao do live image.
- `scripts/docker/entrypoint.sh` executa `lb config` e `lb build` no pipeline Docker.
- `steps/install.sh` + `libs/install-utils.sh` ainda seguem caminho principal com `debootstrap`/`apt`.
- `tests/test_iso_structure.sh` valida artefatos basicos da ISO, mas nao cobre gates de performance.

Stakeholders principais: engenharia de instalador/ISO, operacao de NAS e QA de regressao em VM UEFI/BIOS.

## Goals / Non-Goals

**Goals:**

- Definir perfil tecnico de compressao SquashFS focado em equilibrio entre tamanho e tempo de boot/instalacao.
- Definir contrato de instalacao offline com semantica explicita para sucesso, fallback e erro bloqueante.
- Definir criterios de medicao para gates de desempenho e regressao (build, boot, instalacao, tamanho ISO).
- Garantir compatibilidade operacional em UEFI e BIOS no fluxo de validacao.

**Non-Goals:**

- Nao substituir toda a estrategia de instalacao para um novo instalador.
- Nao introduzir nova stack de build fora de live-build nesta change.
- Nao tratar tuning de runtime Samba/AD/HA; escopo restrito ao pipeline de ISO e fonte offline.
- Nao definir meta de benchmark absoluta sem baseline reproduzivel no ambiente do projeto.

## Decisions

### D1) Perfil padrao SquashFS orientado a tempo total

**Decisao:** adotar perfil padrao com `zstd` como baseline de compressao para a imagem live, mantendo
parametrizacao explicita no build para fallback controlado (`xz` para densidade, `gzip` para compatibilidade
legada) quando requerido por gate de produto.

**Rationale:** `zstd` tende a melhor equilibrio pratico para tempo total (build + boot + instalacao)
com compressao competitiva, reduzindo risco de instalacao lenta em hardware comum.

**Alternativas consideradas:**

- `xz` como padrao: melhor ratio, porem penaliza descompressao e pode ampliar tempo de instalacao.
- `gzip` como padrao: simples e amplamente compativel, porem perde eficiencia de tamanho.
- `lz4` como padrao: muito rapido, mas custo alto em tamanho final da ISO.

### D2) Contrato explicito de fonte offline no instalador

**Decisao:** exigir descoberta e validacao de artefato local da midia antes de qualquer caminho de rede,
com falha bloqueante e mensagem acionavel quando pre-condicoes offline nao forem atendidas.

**Rationale:** evita comportamento ambiguo (metade offline, metade online), melhora previsibilidade e
reduz risco em cenarios air-gapped.

**Alternativas consideradas:**

- Fallback silencioso para rede: rejeitado por mascarar erro de midia e gerar instalacoes nao reproduziveis.
- Modo hibrido sem prioridade: rejeitado por dificultar auditoria de causa em falha.

### D3) Gates de performance baseados em baseline versionado

**Decisao:** estabelecer baseline versionado no pipeline e comparar variacoes por gate (tempo de build,
tempo de boot, tempo de instalacao, tamanho da ISO), com tolerancias explicitas por metrica.

**Rationale:** sem baseline versionado, otimizar compressao vira decisao subjetiva e suscetivel a regressao.

**Alternativas consideradas:**

- Gate binario unico (pass/fail sem baseline): rejeitado por baixa sensibilidade.
- Metricas apenas em release manual: rejeitado por detectar regressao tarde demais.

### D4) Compatibilidade de boot tratada como requisito de design

**Decisao:** preservar validacao em UEFI e BIOS como parte obrigatoria do design de compressao/offline,
nao como verificador opcional pos-implementacao.

**Rationale:** mudancas de imagem podem impactar boot path; validar cedo reduz custo de rollback.

**Alternativas consideradas:**

- Testar apenas UEFI: rejeitado por risco de regressao em legado.
- Postergar teste de firmware para fim do ciclo: rejeitado por feedback tardio.

## Risks / Trade-offs

- **[Perfil de compressao inadequado para hardware alvo]** -> Mitigacao: baseline por ambiente e fallback
  controlado por parametro de build.
- **[Instalador entrar em caminho de rede sem intencao]** -> Mitigacao: regra de prioridade offline +
  erro bloqueante quando artefato local faltar.
- **[Variacao de benchmark por ruido de ambiente]** -> Mitigacao: executar medicao em VM padrao e repetir
  amostras minimas antes de concluir regressao.
- **[Aumento de tamanho da ISO para ganhar velocidade]** -> Mitigacao: definir limite maximo de tamanho
  e faixa aceitavel por perfil.
- **[Divergencia entre docs e implementacao]** -> Mitigacao: gates de consistencia documental e
  rastreabilidade com evidencias versionadas.

## Migration Plan

1. Congelar baseline atual de build/boot/instalacao/tamanho da ISO com evidencia versionada.
2. Introduzir perfil SquashFS parametrico no fluxo de build (padrao + fallback).
3. Formalizar e validar contrato offline no instalador (ordem de descoberta, preflight, erros).
4. Adicionar/ajustar gates e testes de regressao para as metricas definidas.
5. Validar em UEFI e BIOS; promover somente se limites de gate forem atendidos.

Rollback:

- Reverter para perfil de compressao anterior e desabilitar gate novo em caso de regressao critica,
  mantendo evidencias da regressao para iteracao seguinte.

## Open Questions

- Qual nivel inicial de compressao `zstd` deve ser baseline no projeto (e qual limite de ajuste por release)?
- Qual tolerancia maxima aceitavel para tempo de instalacao em troca de reducao de tamanho da ISO?
- O contrato offline deve bloquear totalmente qualquer acesso de rede, ou permitir modo explicito opt-in?
- Quais ambientes VM/hardware serao referencia oficial para benchmark do gate?
