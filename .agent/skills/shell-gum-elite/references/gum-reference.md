# Gum Quick Reference

## Objective

Complete cheat sheet for all Gum subcommands: key flags, environment variable
equivalents, and enum catalogs. Use `gum <cmd> --help` to check your installed
version.

## Subcommand Reference

### `gum input` — Single-line text entry

| Flag | Env Var | Description |
| --- | --- | --- |
| `--placeholder "text"` | `GUM_INPUT_PLACEHOLDER` | Greyed-out hint |
| `--value "text"` | `GUM_INPUT_VALUE` | Pre-filled value |
| `--prompt "> "` | `GUM_INPUT_PROMPT` | Prompt symbol |
| `--password` | `GUM_INPUT_PASSWORD` | Hide typed characters |
| `--width 80` | `GUM_INPUT_WIDTH` | Field width |
| `--timeout 5s` | `GUM_INPUT_TIMEOUT` | Auto-cancel timer |
| `--cursor.foreground` | `GUM_INPUT_CURSOR_FOREGROUND` | Cursor color |
| `--prompt.foreground` | `GUM_INPUT_PROMPT_FOREGROUND` | Prompt color |

### `gum write` — Multi-line text editor

| Flag | Env Var | Description |
| --- | --- | --- |
| `--placeholder "text"` | `GUM_WRITE_PLACEHOLDER` | Hint text |
| `--width` / `--height` | `GUM_WRITE_WIDTH` / `GUM_WRITE_HEIGHT` | Editor dimensions |
| `--cursor.foreground` | `GUM_WRITE_CURSOR_FOREGROUND` | Cursor color |

### `gum choose` — Selection menu

| Flag | Env Var | Description |
| --- | --- | --- |
| `--height 15` | `GUM_CHOOSE_HEIGHT` | Visible list height |
| `--cursor ">"` | `GUM_CHOOSE_CURSOR` | Cursor symbol |
| `--selected-prefix "✓ "` | `GUM_CHOOSE_SELECTED_PREFIX` | Selected icon |
| `--unselected-prefix "  "` | `GUM_CHOOSE_UNSELECTED_PREFIX` | Unselected icon |
| `--limit 3` | `GUM_CHOOSE_LIMIT` | Max selections |
| `--no-limit` | `GUM_CHOOSE_NO_LIMIT` | Unlimited selection |
| `--selected "item"` | `GUM_CHOOSE_SELECTED` | Pre-selected item |
| `--cursor.foreground` | `GUM_CHOOSE_CURSOR_FOREGROUND` | Cursor color |
| `--selected.foreground` | `GUM_CHOOSE_SELECTED_FOREGROUND` | Selected item color |

### `gum confirm` — Yes/No dialog

| Flag | Env Var | Description |
| --- | --- | --- |
| `--default yes` | `GUM_CONFIRM_DEFAULT` | Default answer |
| `--timeout 10s` | `GUM_CONFIRM_TIMEOUT` | Auto-cancel timer |
| `--selected.foreground` | `GUM_CONFIRM_SELECTED_FOREGROUND` | Active option color |

Exit codes: `0` = confirmed, `1` = denied.

### `gum filter` — Fuzzy search

| Flag | Env Var | Description |
| --- | --- | --- |
| `--limit 2` | `GUM_FILTER_LIMIT` | Max selections |
| `--no-limit` | `GUM_FILTER_NO_LIMIT` | Unlimited selection |
| `--height 15` | `GUM_FILTER_HEIGHT` | List height |
| `--placeholder "search"` | `GUM_FILTER_PLACEHOLDER` | Search prompt hint |
| `--cursor.foreground` | `GUM_FILTER_CURSOR_FOREGROUND` | Cursor color |

### `gum file` — File picker

| Flag | Env Var | Description |
| --- | --- | --- |
| `--path "$HOME"` | `GUM_FILE_PATH` | Starting directory |
| `--show-hidden` | `GUM_FILE_SHOW_HIDDEN` | Show dotfiles |
| `--height 20` | `GUM_FILE_HEIGHT` | Panel height |

### `gum spin` — Spinner during command

| Flag | Env Var | Description |
| --- | --- | --- |
| `--spinner dot` | `GUM_SPIN_SPINNER` | Spinner type (see enums) |
| `--title "msg"` | `GUM_SPIN_TITLE` | Status message |
| `--show-output` | `GUM_SPIN_SHOW_OUTPUT` | Pass through stdout |
| `--align left` | `GUM_SPIN_ALIGN` | Spinner position |
| `--spinner.foreground` | `GUM_SPIN_SPINNER_FOREGROUND` | Spinner color |
| `--title.foreground` | `GUM_SPIN_TITLE_FOREGROUND` | Title color |

### `gum style` — Text styling

| Flag | Env Var | Description |
| --- | --- | --- |
| `--foreground 212` | `GUM_STYLE_FOREGROUND` | Text color |
| `--background 16` | `GUM_STYLE_BACKGROUND` | Background color |
| `--border rounded` | `GUM_STYLE_BORDER` | Border type (see enums) |
| `--border-foreground 212` | `GUM_STYLE_BORDER_FOREGROUND` | Border color |
| `--align center` | `GUM_STYLE_ALIGN` | Text alignment (see enums) |
| `--width 50` | `GUM_STYLE_WIDTH` | Block width |
| `--margin "1 2"` | `GUM_STYLE_MARGIN` | Outer spacing |
| `--padding "2 4"` | `GUM_STYLE_PADDING` | Inner spacing |
| `--bold` | `GUM_STYLE_BOLD` | Bold text |

### `gum join` — Combine text blocks

| Flag | Env Var | Description |
| --- | --- | --- |
| `--horizontal` | `GUM_JOIN_HORIZONTAL` | Side-by-side (default) |
| `--vertical` | `GUM_JOIN_VERTICAL` | Stacked |
| `--align center` | `GUM_JOIN_ALIGN` | Alignment |

### `gum table` — Tabular data

| Flag | Env Var | Description |
| --- | --- | --- |
| `--separator ","` | `GUM_TABLE_SEPARATOR` | Column delimiter |
| `--height 15` | `GUM_TABLE_HEIGHT` | Visible height |
| `--cell.align left` | `GUM_TABLE_CELL_ALIGN` | Cell alignment |
| `--header.align center` | `GUM_TABLE_HEADER_ALIGN` | Header alignment |

### `gum pager` — Scroll long content

| Flag | Env Var | Description |
| --- | --- | --- |
| `--height 20` | `GUM_PAGER_HEIGHT` | Panel height |
| `--line-numbers` | `GUM_PAGER_LINE_NUMBERS` | Show line numbers |

### `gum log` — Styled log output

| Flag | Env Var | Description |
| --- | --- | --- |
| `--level error` | `GUM_LOG_LEVEL` | Log level |
| `--time rfc3339` | `GUM_LOG_TIME` | Timestamp format |
| `--structured` | `GUM_LOG_STRUCTURED` | JSON-like output |

### `gum format` — Render markdown/code/emoji

| Flag | Env Var | Description |
| --- | --- | --- |
| `--type markdown` | `GUM_FORMAT_TYPE` | Processing mode (see enums) |
| `--theme pink` | `GUM_FORMAT_THEME` | Syntax theme (see enums) |
| `--language go` | `GUM_FORMAT_LANGUAGE` | Code language |

## Enum Catalog

### Spinner types (`gum spin --spinner`)

| Value | Visual | Best for |
| --- | --- | --- |
| `dot` | ⠋⠙⠹⠸ | Default, general use |
| `minidot` | ⠋⠙ | Minimal feedback |
| `line` | `-\|/` | Build/compile operations |
| `jump` | ⢄⢂⡁ | Light waiting |
| `pulse` | ░▒▓█ | Network/download |
| `points` | ∙∙∙ | Subtle processing |
| `globe` | 🌍🌎🌏 | Network/remote operations |
| `moon` | 🌑🌒🌓 | Long-running background tasks |
| `monkey` | 🙈🙉🙊 | Fun/casual scripts |
| `meter` | ▱▰ | Progress-like feedback |
| `hamburger` | ☰ | Menu loading |

### Border types (`--border`)

| Value | Description |
| --- | --- |
| `none` | No border |
| `hidden` | Space reserved but invisible |
| `normal` | Single-line ASCII |
| `rounded` | Rounded corners (modern look) |
| `thick` | Heavy borders |
| `double` | Double-line frame |

### Alignment (`--align`)

| Value | Usage |
| --- | --- |
| `left` | Default, body text |
| `center` | Headers, titles |
| `right` | Counters, metadata |

### Format types (`gum format --type`)

| Value | Description |
| --- | --- |
| `markdown` | Render markdown with glamour |
| `code` | Syntax-highlighted code |
| `template` | Go template processing |
| `emoji` | Convert `:emoji:` shortcodes |

### Format themes (`gum format --theme`)

| Value | Style |
| --- | --- |
| `pink` | Default glamour theme |
| `dark` | Dark background optimized |
| `light` | Light background optimized |
| `notty` | Plain text, no styles |

## Color Formats

Gum accepts colors in multiple formats:

```bash
# ANSI 256 color index
gum style --foreground 212

# Hex color
gum style --foreground "#8ECAE6"

# ANSI index (0-15) — inherits terminal palette
gum style --foreground 5
```

> **Dica:** Use ANSI indexes (0-15) when you want scripts to inherit the
> user's terminal palette automatically. Use hex codes only inside theme
> variable definitions.

## Version Check

```bash
# Guard against missing features
require_gum_version() {
  local required="${1:?}"
  local current
  current="$(gum --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')" || {
    die "gum not installed"
  }
  # Simple semver comparison (major.minor only)
  printf '%s\n%s' "${required}" "${current}" \
    | sort -V | head -n1 | grep -qF "${required}" || {
    die "gum ${required}+ required (found ${current})"
  }
}
```
