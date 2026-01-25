# 🧠 Agent-OS: Sistema Operacional Cognitivo para Engenharia Autônoma

## 🎯 Visão Geral

O **Agent-OS** não é apenas um conjunto de scripts, mas uma camada de abstração entre o Usuário, o Sistema Operacional e os Modelos de Linguagem (LLMs). O objetivo é minimizar a carga cognitiva do agente (tokens), garantindo que tarefas burocráticas sejam processadas de forma programática e determinística.

---

## 🏗️ Pilares da Arquitetura

### 1. Governança Determinística (Kernel)

As tarefas de infraestrutura (Git, Lint, Formatação) são tratadas por scripts Python/Bash em nível de sistema, removendo a necessidade de o agente "alucinar" comandos ou estados de repositório.

### 2. Otimização Híbrida (Fast-Path)

Se uma tarefa pode ser resolvida programaticamente (ex: `trunk fmt`), o sistema a executa sem invocar um LLM. Isso gera economia de custo e tempo.

### 3. Ciclo de Vida "Closed-Loop"

Toda ação do agente é encapsulada em um ciclo de:
**Roteamento (Router) -> Execução (Tarefa) -> Persistência (Smart Commit).**

---

## 🛠️ Componentes do Sistema

| Componente                      | Localização                      | Função                                                                                |
| :------------------------------ | :------------------------------- | :------------------------------------------------------------------------------------ |
| **Orquestrador (`agent-exec`)** | `.agent/bin/agent-exec`          | Wrapper universal que prepara o contexto e finaliza a tarefa.                         |
| **Sentinela (Daemon)**          | `.agent/scripts/sentinel.sh`     | Monitor passivo (inotify) que garante commits automáticos em caso de queda da sessão. |
| **Roteador Inteligente**        | `.agent/scripts/task_router.py`  | Classifica a intenção e define a Persona/Skill adequada.                              |
| **Smart Committer**             | `.agent/scripts/smart_commit.py` | Analisa o `git diff` e gera Semantic Commits automaticamente.                         |

---

## 🔄 Fluxo de Trabalho (Workflow)

1. **Trigger:** O usuário ou um agente superior invoca `./.agent/bin/agent-exec "instrução"`.
2. **Contextualização:** O `task_router.py` é disparado, gerando um arquivo `.agent/tmp/current_context.md`.
3. **Seleção de Caminho:**
   - **Fast-Path:** Se a tarefa for mecânica, é executada imediatamente.
   - **Cognitive-Path:** O ambiente é preparado para a intervenção do LLM (Gemini, Ollama, etc.).
4. **Execução:** O agente realiza as mudanças no código.
5. **Estabilização (Debounce):** O Sentinela observa as mudanças. Após 25 segundos de silêncio, o sistema verifica se há arquivos vazios ou bloqueios.
6. **Finalização:** O `smart_commit.py` é executado, persistindo as mudanças com uma mensagem semântica (ex: `feat: update...`).

---

## 🚀 Como Expandir

Para adicionar novos "Superpoderes" ao agente:

1. Crie um script granular em `.agent/scripts/` para a tarefa específica.
2. Adicione a lógica de detecção de intenção no `task_router.py`.
3. O `agent-exec` passará a usar essa nova ferramenta automaticamente sempre que a intenção for detectada.

---

## 🛡️ Regras de Segurança

- **Debounce de 25s:** Protege contra commits de arquivos ainda em processamento (0 bytes).
- **Lock Check:** Evita conflitos com operações manuais do Git.
- **Isolamento:** Logs e arquivos temporários são mantidos em `.agent/tmp/` para não poluir o código-fonte.

---

_Documentado em 25 de Janeiro de 2026._
