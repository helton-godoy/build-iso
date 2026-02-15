## Why

Os testes recentes mostram que o instalador ainda falha em cenarios reais: o usuario seleciona multiplos discos, mas o fluxo de execucao usa informacoes inconsistentes e pode entrar em loop ao voltar para etapas anteriores. Ao mesmo tempo, a interface atual exige conhecimento previo de Linux/ZFS e aumenta a ansiedade de equipes tecnicas juniores em ambiente corporativo.

## What Changes

- Padronizar o fluxo para usar, validar e executar sempre com o mesmo conjunto de discos selecionados, evitando regressao para modo single-disk e eliminando loops de navegacao.
- Introduzir um planejador guiado de topologia ZFS com validacoes por regra de negocio (mirror/RAIDZ/dRAID), incluindo mensagens explicativas de impacto, tolerancia a falhas e pre-requisitos.
- Adicionar suporte de modelagem para combinacao de vdevs de dados no mesmo pool e configuracao opcional de vdevs auxiliares (`log`, `cache`, `special`, `dedup`, `spare`) com guardrails.
- Evoluir a UX TUI para um modo orientativo: linguagem didatica, dicas contextuais por etapa, exemplos praticos e feedback claro de proximo passo.
- Melhorar seletores longos (locale/teclado/timezone/discos) com filtro pesquisavel e apresentacao consistente com o design system.

## Capabilities

### New Capabilities
- `guided-installer-education`: Camada de orientacao passo a passo para publico junior, com explicacoes de objetivo, impacto e recomendacoes em cada etapa.
- `zfs-vdev-planner`: Planejamento e validacao de topologias de vdev de dados (single/multiplos vdevs), incluindo regras minimas e compatibilidade operacional.
- `zfs-aux-vdev-composer`: Selecao e validacao de vdevs auxiliares (`log`, `cache`, `special`, `dedup`, `spare`) com restricoes tecnicas e mensagens de risco.
- `installer-flow-consistency`: Estado transacional do fluxo de instalacao para impedir loops, divergencia entre revisao e execucao, e preparacao parcial de discos.
- `searchable-selection-ui`: Componentes de selecao com busca/filtro para listas extensas em TTY/KMSCON.

### Modified Capabilities
- Nenhuma (nao ha specs existentes em `openspec/specs` neste repositorio).

## Impact

- Scripts do instalador em `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/` (principalmente `disk_select.sh`, `review.sh`, `install.sh`, `zfs_*`).
- Bibliotecas em `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/` (estado, UI, disco, ZFS, validacao).
- Contratos de estado persistente (`state.env`) e compatibilidade entre etapas de revisao/execucao.
- Experiencia operacional em KMSCON/TTY, com menor erro humano e onboarding mais rapido para equipes sem familiaridade profunda com Linux/ZFS.
