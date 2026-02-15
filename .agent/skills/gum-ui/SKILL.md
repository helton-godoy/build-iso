---
name: gum-ui
description: UI patterns using Charmbracelet's Gum tool.
---

# Gum UI Patterns - Referência Avançada

Este SKILL define os padrões para interfaces de usuário (TUI) usando o `gum`, com foco em **todos** os parâmetros disponíveis para customização granular.

## Verificação de Existência

Sempre verifique se o `gum` está disponível.

```bash
if ! command -v gum &> /dev/null; then
    echo "Erro: 'gum' é necessário para este script."
    exit 1
fi
```

## Estilização Global (Style Flags)

Quase todos os subcomandos suportam flags de estilo que se aplicam a elementos específicos (ex: `--cursor.foreground`, `--header.border`).

| Flag Base | Descrição |
| --- | --- |
| `--foreground`, `--background` | Cores (nomes como "red", ou hex "#ff0000") |
| `--border` | Borda: `none`, `hidden`, `normal`, `rounded`, `thick`, `double` |
| `--border-foreground`, `--border-background` | Cores da borda |
| `--align` | Alinhamento: `left`, `center`, `right`, `bottom`, `middle`, `top` |
| `--width`, `--height` | Dimensões em caracteres/linhas |
| `--margin`, `--padding` | Espaçamento (formato CSS: "top right bottom left") |
| `--bold`, `--faint`, `--italic`, `--strikethrough`, `--underline` | Atributos de texto |

> **Nota:** Para aplicar a um sub-elemento, prefixe com o nome do elemento. Ex: em `gum choose`, use `--cursor.foreground` para a cor do cursor.

---

## 1. Escolha (`gum choose`)

Selecione uma ou mais opções de uma lista.

**Elementos Estilizáveis:** `cursor`, `item`, `selected`.

| Flag | Descrição |
| --- | --- |
| `--limit <n>` | Máximo de escolhas (0 = sem limite, mas prefira `--no-limit`) |
| `--no-limit` | Permite seleção ilimitada |
| `--height <n>` | Altura da lista |
| `--cursor <str>` | Prefixo do cursor (padrão: `> `) |
| `--selected <str>` | Itens pré-selecionados (pode repetir) |

**Exemplo Avançado:**
```bash
gum choose --no-limit --limit 3 \
  --cursor.foreground "#FF0000" --header "Selecione até 3 itens" \
  --selected.foreground "#00FF00" --selected.bold \
  "Opção A" "Opção B" "Opção C" "Opção D"
```

---

## 2. Confirmação (`gum confirm`)

Pergunta Sim/Não. Retorna status code `0` (Sim) ou `1` (Não).

**Elementos Estilizáveis:** `prompt`, `selected`, `unselected`.

| Flag | Descrição |
| --- | --- |
| `--affirmative <str>` | Texto para "Sim" (ex: "Confirmar") |
| `--negative <str>` | Texto para "Não" (ex: "Cancelar") |
| `--default` | Seleção padrão (Yes/No) |
| `--timeout <duration>` | Timeout (ex: `10s`). Sai com 1 se expirar. |

**Exemplo:**
```bash
if gum confirm "Deletar banco de dados?" --affirmative "Sim, DESTRUIR" --negative "Não, salve-me" --prompt.foreground "#ff0000"; then
    rm -rf /db
fi
```

---

## 3. Filtro (`gum filter`)

Filtro fuzzy interativo (estilo fzf).

**Elementos Estilizáveis:** `indicator`, `selected-indicator`, `unselected-prefix`, `text`, `match`, `prompt`.

| Flag | Descrição |
| --- | --- |
| `--placeholder <str>` | Texto placeholder |
| `--prompt <str>` | Prompt (padrão `> `) |
| `--value <str>` | Valor inicial do filtro |
| `--reverse` | Exibe de baixo para cima |
| `--indicator <str>` | Símbolo do item selecionado |

**Exemplo:**
```bash
cat arquivos.txt | gum filter --placeholder "Busque um arquivo..." --indicator "->" --match.foreground "#00FFFF"
```

---

## 4. Input (`gum input`)

Entrada de texto de linha única.

**Elementos Estilizáveis:** `prompt`, `cursor`.

| Flag | Descrição |
| --- | --- |
| `--placeholder <str>` | Placeholder text |
| `--password` | Mascara caracteres (`*`) |
| `--char-limit <n>` | Limite de caracteres (0 = sem limite) |
| `--width <n>` | Largura do campo |
| `--value <str>` | Valor inicial |

**Exemplo:**
```bash
USER=$(gum input --prompt "Username: " --placeholder "admin")
PASS=$(gum input --password --prompt "Senha: ")
```

---

## 5. Texto Longo (`gum write`)

Editor de texto multi-linha (textarea).

**Elementos Estilizáveis:** `base`, `cursor-line`, `cursor-line-number`, `cursor`, `line-number`, `header`, `placeholder`, `prompt`, `end-of-buffer`.

| Flag | Descrição |
| --- | --- |
| `--width <n>`, `--height <n>` | Dimensões da área de texto |
| `--header <str>` | Título/Cabeçalho |
| `--show-line-numbers` | Exibe números de linha |
| `--show-cursor-line` | Destaca linha atual |

**Exemplo:**
```bash
DESC=$(gum write --header "Descrição do Commit" --width 80 --show-line-numbers)
```

---

## 6. Formatação (`gum format`)

Renderiza Markdown, Código ou Templates.

| Flag | Descrição |
| --- | --- |
| `--type <t>` | `markdown` (padrão), `code`, `emoji`, `template` |

---

## 7. Spinner (`gum spin`)

Executa comando enquanto exibe animação.

**Elementos Estilizáveis:** `spinner`, `title`.

| Flag | Descrição |
| --- | --- |
| `--spinner <type>` | `dot`, `line`, `minidot`, `jump`, `pulse`, `points`, `globe`, `moon`, `monkey`, `meter`, `hamburger` |
| `--show-output` | Exibe output do comando (stdout/stderr) enquanto roda |
| `--title <str>` | Texto ao lado do spinner |
| `--align <str>` | Alinhamento do spinner |

**Exemplo:**
```bash
gum spin --spinner globe --title "Baixando internet..." -- sleep 5
```

---

## 8. Arquivo (`gum file`)

Seletor de arquivos (file picker).

**Elementos Estilizáveis:** `cursor`, `symlink`, `directory`, `file`, `permissions`, `selected`, `file-size`.

| Flag | Descrição |
| --- | --- |
| `--all` | Mostra ocultos (dotfiles) |
| `--cursor <str>` | Caractere do cursor |
| `--height <n>` | Altura da lista |

---

## 9. Tabela (`gum table`)

Renderiza CSV/TSV em tabela interativa.

**Elementos Estilizáveis:** `cell`, `header`, `selected`.

| Flag | Descrição |
| --- | --- |
| `--file <path>` | Arquivo CSV para ler |
| `--separator <str>` | Separador (default `,`) |
| `--columns <list>` | Nomes das colunas (sobrescreve header) |
| `--widths <list>` | Larguras das colunas |

---

## 10. Paginação (`gum pager`)

Visualizador de texto com scroll (estilo `less`).

**Elementos Estilizáveis:** `help`, `line-number`.

| Flag | Descrição |
| --- | --- |
| `--show-line-numbers` | Exibe números de linha |

---

## 11. Estilo / Join (`gum style` / `gum join`)

Ferramentas para layout e composição visual.

**Exemplo Layout:**
```bash
# Cria duas caixas
BOX1=$(gum style --border double --padding "1 2" "Esquerda")
BOX2=$(gum style --border rounded --padding "1 2" "Direita")

# Junta horizontalmente
gum join --horizontal "$BOX1" "$BOX2"
```

---

## Tratamento de Erros e Cancelamento

O `gum` geralmente retorna status `130` quando o usuário cancela (Ctrl+C).

```bash
if ! NOME=$(gum input); then
    echo "Cancelado pelo usuário."
    exit 0
fi
```
