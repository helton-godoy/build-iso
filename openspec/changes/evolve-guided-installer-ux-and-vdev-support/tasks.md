## 1. Estado canonico e consistencia de fluxo

- [x] 1.1 Definir contrato `install_plan_*` (versao, discos de dados, topologia, vdevs auxiliares, metadados de revisao) e adaptadores de leitura para chaves legadas.
- [x] 1.2 Implementar serializacao/desserializacao robusta do plano em `state-utils` com validacao de schema e fallback seguro para sessoes antigas.
- [x] 1.3 Implementar preflight unico antes da etapa destrutiva para validar coerencia entre revisao e execucao e bloquear divergencias.
- [x] 1.4 Ajustar navegacao entre `review` e `install` para eliminar loop regressivo quando houver erro de pre-condicao.

## 2. Planner de vdevs de dados

- [x] 2.1 Criar modelo de vdev de dados (top-level) com suporte a `stripe`, `mirror`, `raidz1`, `raidz2`, `raidz3` e ponto de extensao para `draid`.
- [x] 2.2 Implementar validadores de minimo de discos por topologia e mensagens de erro didaticas por regra violada.
- [x] 2.3 Implementar configuracao de multiplos top-level vdevs no mesmo pool e persistencia do layout no plano canonico.
- [x] 2.4 Atualizar renderizacao da tela de revisao para mostrar layout final dos vdevs de dados de forma auditavel.

## 3. Compositor de vdevs auxiliares

- [x] 3.1 Implementar fluxo de adicao opcional das classes `log`, `cache`, `special`, `dedup` e `spare` com selecao de discos por classe.
- [x] 3.2 Implementar guardrails de compatibilidade por classe (ex.: restricoes de layout para `log`) com bloqueio de avancar e explicacao tecnica simples.
- [x] 3.3 Incluir no resumo final a lista de classes auxiliares configuradas, discos associados e impacto esperado.
- [x] 3.4 Integrar geracao do comando/plano de provisionamento para incluir vdevs auxiliares sem quebrar cenarios legados.

## 4. UX orientativa para perfil junior

- [x] 4.1 Padronizar componente de orientacao por etapa com os blocos: objetivo, impacto, recomendacao e quando nao usar.
- [x] 4.2 Revisar textos de todos os steps criticos (disco, topologia, vdevs auxiliares, confirmacao final) para linguagem clara e exemplos praticos.
- [x] 4.3 Implementar resumo pedagogico pre-destrutivo destacando o que sera alterado e o que nao sera alterado.
- [x] 4.4 Definir tom e consistencia editorial (glossario minimo de termos ZFS) para reduzir jargao nao explicado.

## 5. Selecao pesquisavel e design system

- [x] 5.1 Consolidar `ui_filter_select` como padrao para listas extensas (locale, teclado, timezone, discos, perfis) com fallback automatico.
- [x] 5.2 Garantir consistencia visual dos estados de filtro/selecionado/cursor conforme design system do instalador.
- [x] 5.3 Adicionar mensagens de ajuda de teclado (filtrar, navegar, confirmar, cancelar) em todos os seletores pesquisaveis.
- [ ] 5.4 Validar comportamento em KMSCON/TTY com listas longas e terminais de diferentes dimensoes.

## 6. Integracao, testes e rollout seguro

- [x] 6.1 Criar testes de fluxo fim a fim (selecao -> revisao -> instalacao) cobrindo single-disk, multi-disco e topologias invalidas.
- [x] 6.2 Criar testes de regressao para persistencia de estado com valores complexos (espacos, listas CSV, retomada de sessao).
- [x] 6.3 Implementar flag de rollout (`INSTALLER_PLAN_MODE=legacy|canonical`) para ativacao progressiva e rollback rapido.
- [x] 6.4 Documentar playbook operacional para equipe junior (passos, alertas, interpretacao de erros e recuperacao).
