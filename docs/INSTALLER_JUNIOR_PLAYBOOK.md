# Playbook do Instalador para Equipe Junior

## Objetivo

Este guia ajuda a equipe tecnica a operar o instalador com seguranca em ambiente corporativo, mesmo sem experiencia previa profunda em Linux/ZFS.

## Fluxo Recomendado

1. Selecione somente discos dedicados ao servidor.
2. Escolha a topologia de dados conforme risco aceitavel.
3. Revise o plano completo antes de confirmar.
4. Somente confirme quando o impacto estiver claro.

## Regras Rapidas de Topologia

- `stripe`: sem redundancia (evitar para producao).
- `mirror`: resiliencia alta com menor capacidade util.
- `raidz1`: tolera 1 falha (uso com cautela em producao).
- `raidz2`: tolera 2 falhas (recomendado para NAS corporativo com varios discos).
- `raidz3`: tolera 3 falhas (ambientes grandes e criticos).

## VDEVs Auxiliares (quando usar)

- `log (SLOG)`: escritas sincronas; prefira disco(s) dedicado(s), idealmente mirror.
- `cache (L2ARC)`: melhora leitura quando RAM nao cobre o working set.
- `special`: metadados/blocos pequenos; use com redundancia adequada.
- `dedup`: **NÃO RECOMENDADO** — impacto severo em performance e RAM. Consulte `docs/00_SOURCE_OF_TRUTH.md`.
- `spare`: disco de reserva para substituicao automatica.

## Alertas Operacionais

- Nunca use o mesmo disco em vdev de dados e vdev auxiliar.
- Sempre valide se a topologia escolhida respeita o minimo de discos.
- Em caso de erro de preflight, volte para revisao e ajuste o plano.

## Glossario Minimo

- `pool`: agrupamento ZFS principal.
- `vdev`: bloco logico de discos dentro do pool.
- `top-level vdev`: vdev de dados principal do pool.
- `aux vdev`: vdev auxiliar (log/cache/special/dedup/spare).
- `preflight`: validacao antes da fase destrutiva.

## Recuperacao Rapida

1. Se houve cancelamento, reinicie o instalador e refaca a revisao.
2. Se houver divergencia de plano, volte para o step de topologia/datasets.
3. Se o erro persistir, colete logs e abra chamado interno de engenharia.
