# Premium Terminal Design System

## Intent

Provide a consistent, high-end visual language for shell interfaces built with Gum.
Support customizable theming while maintaining accessibility.

## Palette

| Token | Color | Usage |
|---|---|---|
| `COLOR_PRIMARY` | `#8ECAE6` | Headers, labels, neutral emphasis |
| `COLOR_ACCENT` | `#FFB703` | Focus states, active selections |
| `COLOR_SUCCESS` | `#2A9D8F` | Success confirmations |
| `COLOR_WARNING` | `#FB8500` | Warnings and confirmations |
| `COLOR_ERROR` | `#D62828` | Error states |
| `COLOR_MUTED` | `#6C757D` | Secondary metadata |

## Visual Hierarchy

1. Section headers: bordered card + bold title.
2. Primary actions: accent foreground and focused cursor style.
3. Risky actions: warning color + explicit confirm copy.
4. Status lines: fixed prefixes (`[OK]`, `[WARN]`, `[ERR]`).

## Spacing and Rhythm

- One blank line between major blocks.
- Padding presets:
  - compact: `"0 1"`
  - standard: `"1 2"`
  - hero: `"1 4"`
- Keep content width under 100 columns when possible.

## Interaction Motion

- Commands above 300ms should use `gum spin`.
- Operations with known step count should use `gum progress`.
- Chain visual states: select -> confirm -> execute -> report.
- Avoid stacked spinners; serialize long operations for clarity.

## Accessibility

1. Never encode meaning with color alone.
2. Keep contrast high for prompt text and cursor focus.
3. Use explicit placeholder text to reduce ambiguity.
4. Keep actionable labels short and verb-first.
5. Support `NO_COLOR=1` for color-stripped output.
6. Support `TERM=dumb` with plain-text fallbacks.

## Customizable Themes

### Theme file (`theme.conf`)

```bash
# Project or user-level theme override
COLOR_PRIMARY="#8ECAE6"
COLOR_ACCENT="#FFB703"
COLOR_SUCCESS="#2A9D8F"
COLOR_WARNING="#FB8500"
COLOR_ERROR="#D62828"
COLOR_MUTED="#6C757D"
BORDER_STYLE="rounded"
PADDING_STANDARD="1 2"
SPINNER_STYLE="dot"
```

### Theme loader

```bash
load_theme() {
  local theme_file="${1:-}"
  local candidates=(
    "${theme_file}"
    "${SCRIPT_DIR}/theme.conf"
    "${HOME}/.config/shell-gum/theme.conf"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -n "${candidate}" && -f "${candidate}" ]]; then
      load_env_file "${candidate}"
      return 0
    fi
  done
}

# Apply defaults for any unset tokens
COLOR_PRIMARY="${COLOR_PRIMARY:-#8ECAE6}"
COLOR_ACCENT="${COLOR_ACCENT:-#FFB703}"
COLOR_SUCCESS="${COLOR_SUCCESS:-#2A9D8F}"
COLOR_WARNING="${COLOR_WARNING:-#FB8500}"
COLOR_ERROR="${COLOR_ERROR:-#D62828}"
COLOR_MUTED="${COLOR_MUTED:-#6C757D}"
BORDER_STYLE="${BORDER_STYLE:-rounded}"
PADDING_STANDARD="${PADDING_STANDARD:-1 2}"
SPINNER_STYLE="${SPINNER_STYLE:-dot}"
```

## Reusable Style Presets

```bash
ui_header() {
  gum style \
    --foreground "${COLOR_PRIMARY}" \
    --border "${BORDER_STYLE}" \
    --border-foreground "${COLOR_ACCENT}" \
    --padding "${PADDING_STANDARD}" \
    --bold \
    "$1"
}

ui_success() {
  gum style --foreground "${COLOR_SUCCESS}" --bold "[OK] $1"
}

ui_warn() {
  gum style --foreground "${COLOR_WARNING}" --bold "[WARN] $1"
}

ui_error() {
  gum style --foreground "${COLOR_ERROR}" --bold "[ERR] $1"
}

ui_muted() {
  gum style --foreground "${COLOR_MUTED}" --faint "$1"
}

ui_progress_header() {
  local current="$1" total="$2" title="$3"
  local bar=""
  for ((i = 1; i <= total; i++)); do
    if (( i < current )); then bar+="●"
    elif (( i == current )); then bar+="◉"
    else bar+="○"
    fi
    (( i < total )) && bar+="─"
  done
  gum style \
    --foreground "${COLOR_PRIMARY}" \
    --border "${BORDER_STYLE}" \
    --border-foreground "${COLOR_ACCENT}" \
    --padding "0 2" \
    --bold \
    "${bar}  ${title}"
}
```

## Composition with `gum join`

### Side-by-side boxes

```bash
dashboard() {
  local left right
  left="$(gum style --border rounded --border-foreground "${COLOR_SUCCESS}" \
    --padding "1 2" --width 30 "LEFT PANEL" "" "Content here")"
  right="$(gum style --border rounded --border-foreground "${COLOR_PRIMARY}" \
    --padding "1 2" --width 30 "RIGHT PANEL" "" "More content")"
  gum join --horizontal "${left}" "${right}"
}
```

### Stacked header + body

```bash
full_layout() {
  local header body
  header="$(gum style --foreground "${COLOR_ACCENT}" --bold --align center --width 62 \
    "═══ Dashboard ═══")"
  body="$(dashboard)"
  gum join --vertical "${header}" "${body}"
}
```

## Layout Best Practices

1. Use `--width` consistently for aligned `gum join` output.
2. Keep box content under 40 characters for side-by-side layouts.
3. Cache rendered elements in variables before joining.
4. Test layouts at 80-column minimum width.
5. Provide plain-text fallbacks for non-interactive contexts.

## See Also

- [theme-gallery.md](theme-gallery.md) — Named palettes (Catppuccin, Nord, Gruvbox, Tokyo Night), color theory rules (60-30-10), Nerd Font icon catalog, and kmscon TTY integration.
- [gum-reference.md](gum-reference.md) — Complete flags/env vars for every Gum subcommand plus enum catalogs.
- **Nerd Fonts:** Required for icon glyphs. Recommended: JetBrainsMono NF. Install from [nerd-fonts releases](https://github.com/ryanoasis/nerd-fonts/releases).
