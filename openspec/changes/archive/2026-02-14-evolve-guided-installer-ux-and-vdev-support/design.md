## Context

O instalador TTY atual ja possui fluxo por etapas, persistencia de estado e componentes visuais baseados em `gum`, mas ainda apresenta tres problemas estruturais: (1) divergencia entre o que o usuario revisa e o que a etapa de instalacao executa, (2) lacunas de modelagem para topologias ZFS avancadas e vdevs auxiliares, e (3) pouca orientacao para publico junior em ambiente corporativo.

Do ponto de vista tecnico, o estado e carregado de `state.env`, e as etapas combinam regras de negocio com renderizacao de UI no mesmo arquivo. Isso dificulta validacao consistente entre etapas (selecao -> revisao -> execucao), especialmente para cenarios multi-disco. O resultado observado em testes foi loop de navegacao e mensagens pouco precisas sobre quais discos/topologias seriam aplicados.

## Goals / Non-Goals

**Goals:**
- Garantir consistencia transacional do fluxo de instalacao (mesmos dados entre selecao, revisao e execucao).
- Introduzir planejamento explicito de vdevs com validacao por regras (dados e auxiliares) antes da etapa destrutiva.
- Tornar a UX didatica para perfil junior, com explicacoes de impacto e recomendacoes praticas por opcao.
- Manter compatibilidade com TTY/KMSCON e design system existente.
- Reduzir risco operacional com guardrails de minimo de discos, combinacoes invalidas e preflight checks.

**Non-Goals:**
- Reescrever todo o instalador em outra linguagem/framework.
- Cobrir tuning avancado de performance por workload (alem de defaults seguros).
- Implementar orquestracao multi-host ou provisionamento remoto.
- Substituir documentacao oficial de OpenZFS por texto extensivo dentro da UI.

## Decisions

1) **Separar estado de intencao do estado de execucao**
- Decisao: persistir um modelo canonico de plano de instalacao (ex.: `install_plan_*`) e gerar dele o comando final de provisionamento.
- Racional: evita divergencia entre revisao e execucao e elimina loops por estado parcial.
- Alternativas consideradas:
  - Reaproveitar chaves soltas existentes (`install_disk`, `zfs_topology`, etc.) sem normalizacao. Rejeitada por fragilidade.
  - Gerar comando direto em cada step sem consolidacao. Rejeitada por baixa auditabilidade.

2) **Introduzir `vdev planner` em duas camadas**
- Decisao: modelar separadamente:
  - vdevs de dados top-level (stripe/mirror/raidz1/raidz2/raidz3/draid)
  - vdevs auxiliares (`log`, `cache`, `special`, `dedup`, `spare`)
- Racional: reflete o modelo OpenZFS e simplifica validacoes especificas por classe.
- Alternativas consideradas:
  - Um unico formulario gigante com todas as opcoes. Rejeitada por sobrecarga cognitiva.

3) **Validacao centralizada antes da execucao (preflight gate)**
- Decisao: criar validadores reutilizaveis por regra:
  - minimo de discos por topologia;
  - restricoes de combinacao (ex.: `log` nao aceita raidz/draid);
  - coerencia entre quantidade de discos e layout declarado.
- Racional: impedir que o usuario chegue na etapa destrutiva com plano invalido.
- Alternativas consideradas:
  - Validar apenas no `zpool create`. Rejeitada por UX ruim e retorno tardio.

4) **UX orientativa progressiva para publico junior**
- Decisao: cada step passa a ter bloco fixo de orientacao:
  - "O que voce esta escolhendo"
  - "Impacto no resultado"
  - "Recomendacao segura"
  - "Quando NAO usar"
- Racional: reduz ansiedade e melhora tomada de decisao sem exigir conhecimento previo.
- Alternativas consideradas:
  - Ajuda global unica no inicio. Rejeitada por baixa retencao contextual.

5) **Listas longas com busca usando `gum filter`**
- Decisao: adotar `ui_filter_select` para locale/teclado/timezone e listas extensas de disco/perfis.
- Racional: melhora navegacao em TTY com grande volume de opcoes.
- Alternativas consideradas:
  - `gum choose` puro com paginacao. Rejeitada por busca limitada.

6) **Compatibilidade incremental sem quebrar fluxo atual**
- Decisao: manter chaves legadas (`install_disk`) como fallback enquanto novas chaves (`install_disks`, `install_plan_*`) sao adotadas.
- Racional: reduz risco de regressao durante migracao.
- Alternativas consideradas:
  - corte imediato para novo formato. Rejeitada por alto risco em ambiente ja em teste.

## Risks / Trade-offs

- [Complexidade de estado] -> Mitigacao: contrato de estado versionado (`install_plan_version`) e testes de serializacao.
- [Regressao em steps existentes] -> Mitigacao: adaptadores de compatibilidade e flags de fallback.
- [Sobrecarga de UI por excesso de texto] -> Mitigacao: orientacao em blocos curtos, linguagem objetiva e exemplos minimos.
- [Divergencia entre regras implementadas e docs ZFS] -> Mitigacao: tabela de regras derivada de fonte oficial e revisao tecnica periodica.
- [Ambiguidade em combinacoes avancadas de vdev] -> Mitigacao: wizard por etapas com validacao imediata e resumo final auditavel.

## Migration Plan

1. Introduzir contrato de estado canonico do plano (`install_plan_*`) mantendo chaves legadas.
2. Implementar `planner` de vdev de dados com validacao minima por topologia.
3. Adicionar composicao de vdevs auxiliares com restricoes tecnicas.
4. Atualizar tela de revisao para exibir plano completo (dados + auxiliares + riscos).
5. Conectar etapa de instalacao ao plano canonico (fonte unica de verdade).
6. Adicionar testes de fluxo (selecao -> revisao -> execucao) para evitar loop.
7. Descontinuar gradualmente chaves legadas apos estabilizacao.

Rollback:
- flag de execucao para modo legado (`INSTALLER_PLAN_MODE=legacy`) ate a estabilizacao.
- manter parser de estado retrocompativel para sessoes antigas.

## Open Questions

- Como representar de forma simples (na UI) composicoes multi-vdev complexas sem sobrecarregar usuario junior?
- Quais perfis predefinidos devemos oferecer por padrao (NAS, virtualizacao, backup, banco)?
- dRAID entra na primeira versao do planner ou em fase 2 com assistente dedicado?
- Quais limites de guardrail serao "hard fail" versus "warning com override"?
