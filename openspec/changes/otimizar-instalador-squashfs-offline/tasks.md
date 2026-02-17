## 1. Baseline e escopo de medicao

- [ ] 1.1 Consolidar baseline versionado para tamanho da ISO, tempo de build, tempo de boot e tempo de instalacao em ambiente de referencia
- [x] 1.2 Definir formato de evidencia auditavel para resultados de benchmark e regressao
- [x] 1.3 Validar que a coleta de baseline distingue UEFI e BIOS como dimensoes de resultado

## 2. Perfil SquashFS no pipeline de build

- [x] 2.1 Parametrizar perfil padrao de compressao SquashFS no fluxo de `lb config` com algoritmo e nivel explicitos
- [x] 2.2 Implementar fallback parametrico de algoritmo/nivel sem exigir edicao manual de multiplos pontos do pipeline
- [x] 2.3 Adicionar validacao que confirme coerencia entre perfil selecionado e artefato `filesystem.squashfs` gerado

## 3. Contrato de instalacao offline

- [x] 3.1 Implementar preflight de instalacao offline com verificacao de artefatos locais obrigatorios antes de operacoes irreversiveis
- [x] 3.2 Garantir prioridade de fonte local no modo offline e bloquear fallback silencioso para rede
- [x] 3.3 Padronizar mensagens e logs para falhas de pre-condicao offline com contexto acionavel

## 4. Gates de regressao e compatibilidade

- [x] 4.1 Definir limites de regressao por metrica com comparacao automatizada contra baseline versionado
- [x] 4.2 Integrar gate de performance ao pipeline para bloquear promocao quando limites forem excedidos
- [x] 4.3 Incluir validacao obrigatoria de boot em UEFI e BIOS como criterio de aceite dos perfis de build

## 5. Validacao final e prontidao de entrega

- [x] 5.1 Executar testes de estrutura da ISO e fluxo de instalacao para confirmar aderencia aos requisitos das specs
- [x] 5.2 Registrar evidencias finais (metricas, resultados de firmware e decisao de gate) para auditoria
- [x] 5.3 Preparar resumo de handoff com riscos residuais e criterios de aceite atendidos para fase de apply
