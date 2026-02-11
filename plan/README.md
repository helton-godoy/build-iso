# Diretório `plan/`

Documentos de planejamento técnico do projeto **build-iso**.

---

## Convenções

### Naming

```
NNN - Plan: Título Descritivo.md
```

- `NNN`: número sequencial global (nunca reutilizado)
- Próximo número disponível: **005** (baseado em histórico de `archived/plan/`)

### Template

Todo novo plano deve seguir esta estrutura:

```markdown
# NNN - Plan: Título Descritivo

**Data:** YYYY-MM-DD
**Status:** Draft | Em Revisão | Aprovado | Em Execução | Concluído | Superseded
**Autor:** [nome ou agent ID]
**Relacionado:** [links para issues, docs, changes OpenSpec]

---

## Problema / Contexto

[Descrever o que motivou este plano]

## Proposta

[Descrever a solução proposta]

## Tarefas

- [ ] Task 1
- [ ] Task 2

## Critérios de Aceitação

- [ ] Critério 1
- [ ] Critério 2

## Referências

- [Link 1](url)
```

### Lifecycle

```
Draft → Em Revisão → Aprovado → Em Execução → Concluído → Arquivado
                                                            ↓
                                                    archived/plan/
```

- Planos **concluídos** devem ser movidos para `archived/plan/` via `make plan-archive`
- Planos **superseded** permanecem com o status atualizado no cabeçalho

### Regras

1. **Apenas planos de ação** neste diretório — guias e referências vão em `docs/`
2. **Sem rascunhos de conversa** — curar o conteúdo antes de criar um plano
3. **Referências relativas** — nunca usar paths absolutos nos links
4. **Integração OpenSpec** — para mudanças estruturais, usar `/opsx-new` e linkar a change no campo `Relacionado`

---

## Comandos Úteis

```bash
make plan-list       # Lista planos ativos com status
make plan-archive FILE=plan/NNN-*.md  # Arquiva plano concluído
```

---

## Conteúdo Atual

| Arquivo | Status |
|:--|:--|
| `001 - Plan: Auditoria Técnica do Instalador.md` | Superseded |

## Histórico (archived/plan/)

| Arquivo | Tipo |
|:--|:--|
| `000 - Reference: Arquitetura Maestro Original.md` | Referência histórica |
| `001 - Plan: Otimização do tempo de login.md` | Plano concluído |
| `001 - Plan: Para garantir que o qualquer agente LLM.md` | Plano concluído |
| `001 - Plan: ZFSBootMenu Integration (Refactoring).md` | Plano concluído |
| `003 - Plan: ANALISE-CRITICA-PROPOSTA.md` | Plano concluído |
| `004 - Plan: Automatizar download para BINARIES ZFSBOOTMENU.md` | Plano concluído |
