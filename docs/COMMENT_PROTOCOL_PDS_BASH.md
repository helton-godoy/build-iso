# Protocolo de Comentarios Semanticos (PDS-Bash)

Versao: `v1.1`

Objetivo: padronizar comentarios estrategicos para reconstruir fluxo logico por
grep/indexacao, com foco em troubleshooting e consumo por agentes LLM (RAG).

## 1) Tags obrigatorias (novo contrato)

Para blocos logicos novos (funcao, etapa critica, orquestracao):

- `@ID`: identificador estavel e unico do bloco (ex.: `INSTALL_PREPARE_DISKS`)
- `@STEP`: descricao semantica curta do objetivo do bloco

Tags opcionais recomendadas:

- `@REQ`: IDs pre-requisito separados por virgula
- `@FAIL`: ID de destino em caminho de falha
- `@DATA`: contexto de dados (ex.: `IN /etc/hosts`, `OUT /tmp/report.json`)

Exemplo:

```bash
# @ID: INSTALL_PREPARE_DISKS
# @STEP: Limpa e particiona discos selecionados para ZFS
# @REQ: REVIEW_CONFIRM
# @FAIL: INSTALL_ABORT
# @DATA: IN install_disks
# @DATA: OUT gpt_layout
```

## 2) Compatibilidade com padrao atual do projeto

O projeto ja usa tags estruturadas em shell:

- `@INST_STEP_ID`, `@INST_STEP_FLOW`, `@INST_STATE`
- `@INST_FUNC`, `@INST_DESC`, `@INST_DEP`
- `@DEV_*`, `@TEST_*`

Regra: o PDS-Bash **complementa** (nao substitui) o padrao existente.

## 3) Regras de qualidade

- IDs devem ser unicos no escopo do repositorio
- `@REQ` e `@FAIL` devem referenciar IDs existentes
- `@STEP` deve descrever intencao (nao apenas comando tecnico)
- Comentarios devem ficar imediatamente acima do bloco descrito

## 4) Ferramentas locais

- Gerar indice grepavel + JSONL:
  - `make comment-index`
  - `just comment-index`
- Gerar grafo Mermaid de fluxo:
  - `make comment-graph`
  - `just comment-graph`
- Validar contrato semantico:
  - `make verify-comment-contract`
  - `just verify-comment-contract`

Saidas padrao:

- `output/comment-index/comment-index.txt`
- `output/comment-index/comment-index.jsonl`
- `output/comment-index/comment-flow.mmd`

## 5) Integracao com RAG

Estrutura recomendada para retrieval inicial:

1. Buscar por ID/tag no `comment-index.txt` (latencia minima)
2. Carregar contexto relacionado via `comment-flow.mmd` (dependencias)
3. Expandir para chunks de codigo alvo conforme `file:line`

Isso reduz varredura ampla de contexto e acelera troubleshooting dirigido.
