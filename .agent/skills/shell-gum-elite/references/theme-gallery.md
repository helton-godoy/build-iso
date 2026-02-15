# Theme Gallery & Terminal Design Theory

## Objective

Named palettes ready for copy-paste, color theory rules adapted for TUI,
Nerd Font icon catalog, and kmscon integration for TTY-pure environments.

## Named Palettes

Each palette provides semantic variables that plug directly into the
`design-system.md` theme loader.

### Catppuccin Mocha (Suave, Pastel, Moderno)

Best for: dashboards, friendly CLIs, modern tooling.

```bash
# --- Theme: Catppuccin Mocha ---
COLOR_PRIMARY="#cba6f7"    # Mauve
COLOR_SECONDARY="#89b4fa"  # Blue
COLOR_ACCENT="#f5c2e7"     # Pink
COLOR_SUCCESS="#a6e3a1"    # Green
COLOR_WARNING="#f9e2af"    # Yellow
COLOR_ERROR="#f38ba8"      # Red
COLOR_MUTED="#6c7086"      # Overlay
COLOR_TEXT="#cdd6f4"       # Text
COLOR_SUBTEXT="#a6adc8"    # Subtext
```

### Nord (Frio, Profissional, Corporativo)

Best for: infrastructure tools, server scripts, sysadmin dashboards.

```bash
# --- Theme: Nord ---
COLOR_PRIMARY="#88c0d0"    # Frost Blue
COLOR_SECONDARY="#81a1c1"  # Frost Dark
COLOR_ACCENT="#5e81ac"     # Frost Darkest
COLOR_SUCCESS="#a3be8c"    # Aurora Green
COLOR_WARNING="#ebcb8b"    # Aurora Yellow
COLOR_ERROR="#bf616a"      # Aurora Red
COLOR_MUTED="#4c566a"      # Polar Night
COLOR_TEXT="#d8dee9"       # Snow Storm
COLOR_SUBTEXT="#e5e9f0"    # Snow Storm Light
```

### Gruvbox Dark (Retro, Alto Contraste, Quente)

Best for: hacker tools, log viewers, Vim-centric workflows.

```bash
# --- Theme: Gruvbox ---
COLOR_PRIMARY="#fe8019"    # Orange (signature)
COLOR_SECONDARY="#fabd2f"  # Yellow
COLOR_ACCENT="#83a598"     # Blue
COLOR_SUCCESS="#b8bb26"    # Green
COLOR_WARNING="#fabd2f"    # Yellow
COLOR_ERROR="#fb4934"      # Red
COLOR_MUTED="#928374"      # Gray
COLOR_TEXT="#ebdbb2"       # Light
COLOR_SUBTEXT="#d5c4a1"    # Light2
```

### Tokyo Night (Cyberpunk, Neon, Noturno)

Best for: futuristic scripts, interactive games, demo tools.

```bash
# --- Theme: Tokyo Night ---
COLOR_PRIMARY="#7aa2f7"    # Blue
COLOR_SECONDARY="#bb9af7"  # Purple
COLOR_ACCENT="#7dcfff"     # Cyan
COLOR_SUCCESS="#9ece6a"    # Green
COLOR_WARNING="#e0af68"    # Orange
COLOR_ERROR="#f7768e"      # Red
COLOR_MUTED="#565f89"      # Comment
COLOR_TEXT="#c0caf5"       # Foreground
COLOR_SUBTEXT="#9aa5ce"    # Dark Foreground
```

## Color Theory for TUI

### Regra 60-30-10 (Adaptada)

No terminal, o fundo é fixo (preto/transparente). A regra se adapta para
**intensidade da cor**:

| % | Papel | Tokens | Onde usar |
| --- | --- | --- | --- |
| 60% | Neutro | `COLOR_TEXT`, `COLOR_SUBTEXT`, `COLOR_MUTED` | Corpo do texto, bordas inativas, placeholders |
| 30% | Contexto | `COLOR_SECONDARY`, `COLOR_ACCENT` | Cabeçalhos de tabela, ícones, labels informativos |
| 10% | Destaque | `COLOR_PRIMARY` | Cursor, item selecionado, spinner, botão confirm |

```bash
# Exemplo prático da regra 60-30-10
gum choose \
  --cursor.foreground "${COLOR_PRIMARY}" \
  --header.foreground "${COLOR_SECONDARY}" \
  --item.foreground "${COLOR_TEXT}"
```

### Hierarquia Visual (H1 → Meta)

| Nível | Tratamento | Exemplo |
| --- | --- | --- |
| H1 (Título) | `gum style --border --bold --padding "1 2"` | Tela principal |
| H2 (Subtítulo) | `gum style --foreground PRIMARY --bold` | Seção interna |
| H3 (Corpo) | `gum style --foreground TEXT` | Conteúdo padrão |
| Meta | `gum style --foreground MUTED --faint` | Timestamps, versões |

### Feedback por Estado

| Estado | Token | Prefixo |
| --- | --- | --- |
| Neutro | `COLOR_MUTED` (borda) | — |
| Focado | `COLOR_PRIMARY` (borda) | — |
| Sucesso | `COLOR_SUCCESS` | `[OK]` ou `✓` |
| Alerta | `COLOR_WARNING` | `[WARN]` ou `⚠` |
| Erro | `COLOR_ERROR` | `[ERR]` ou `✗` |

## Nerd Font Icon Catalog

Tabela de ícones semânticos para uso em prompts, menus e mensagens.
Requer **Nerd Font** instalada (ex: JetBrainsMono NF, FiraCode NF).

| Contexto | Unicode | Emoji Fallback | Uso típico |
| --- | --- | --- | --- |
| Configuração | `` | ⚙️ | Menu de settings |
| Usuário | `` | 👤 | Input de nome/login |
| Senha | `` | 🔒 | `gum input --password` |
| Sucesso | `` | ✅ | Mensagens de OK |
| Erro | `` | ❌ | Mensagens de falha |
| Busca | `` | 🔍 | `gum filter` prompt |
| Arquivo | `` | 📄 | `gum file` cursor |
| Diretório | `` | 📂 | `gum file` items |
| Rede | `󰈀` | 🌐 | Operações remotas |
| Disco | `` | 💾 | Operações de storage |
| Deploy | `󰜟` | 🚀 | Confirmação de deploy |
| Informação | `` | ℹ️ | Dicas e notas |

```bash
# Exemplo: menu com ícones
gum choose \
  --cursor.foreground "${COLOR_ACCENT}" \
  " Configurações" \
  " Gerenciar Usuários" \
  " Explorar Arquivos" \
  " Sair"
```

> **Fallback:** Em terminais sem Nerd Font, use emoji Unicode como substituto.
> Detecte suporte com `fc-list 2>/dev/null | grep -qi "nerd"`.
>
> **Instalar:** Use `bash scripts/install-nerd-fonts.sh` para download
> interativo das fontes recomendadas (JetBrainsMono, FiraCode, etc.).

## Integração kmscon (TTY Puro)

O `kmscon` substitui o console Linux (VT) por um emulador KMS/DRM com suporte
a TrueType e cores estendidas. Isto permite Nerd Fonts e paletas completas
no TTY puro.

### Palette strings para `kmscon.conf`

Formato: 16 cores ANSI em ordem (black, red, green, yellow, blue, magenta,
cyan, white, bright variants).

```ini
# Catppuccin Mocha
palette = "1e1e2e, f38ba8, a6e3a1, f9e2af, 89b4fa, f5c2e7, 94e2d5, bac2de, 585b70, f38ba8, a6e3a1, f9e2af, 89b4fa, f5c2e7, 94e2d5, a6adc8"

# Nord
palette = "3b4252, bf616a, a3be8c, ebcb8b, 81a1c1, b48ead, 88c0d0, e5e9f0, 4c566a, bf616a, a3be8c, ebcb8b, 81a1c1, b48ead, 88c0d0, eceff4"

# Gruvbox Dark
palette = "282828, cc241d, 98971a, d79921, 458588, b16286, 689d6a, a89984, 928374, fb4934, b8bb26, fabd2f, 83a598, d3869b, 8ec07c, ebdbb2"

# Tokyo Night
palette = "1a1b26, f7768e, 9ece6a, e0af68, 7aa2f7, bb9af7, 7dcfff, a9b1d6, 414868, f7768e, 9ece6a, e0af68, 7aa2f7, bb9af7, 7dcfff, c0caf5"
```

### Fonte no kmscon

```bash
--font-name "JetBrainsMono Nerd Font" --font-size 14
```

### Cores ANSI indexadas para herança de tema

Quando o script roda em kmscon, use índices ANSI (0-15) no lugar de hex.
Isso faz o script herdar automaticamente a paleta configurada:

```bash
# Script que herda tema do kmscon automaticamente
gum style \
  --border double \
  --border-foreground 5 \
  --foreground 15 \
  --align center \
  "SISTEMA INICIADO"
```

> **Por que usar:** Se o usuário mudar de Catppuccin para Nord no
> `kmscon.conf`, o script se adapta sem edição. Use hex codes apenas
> dentro das definições de `theme.conf` do projeto.

## Choosing a Palette

| Contexto do projeto | Paleta recomendada |
| --- | --- |
| NAS/Server/Infra | **Nord** — profissional, discreto |
| DevOps tooling | **Catppuccin Mocha** — moderno, legível |
| Legacy/Retro | **Gruvbox** — alto contraste, quente |
| Demo/Interactive | **Tokyo Night** — vibrante, chamativo |
| TTY puro (kmscon) | Qualquer uma + string `palette` correspondente |
