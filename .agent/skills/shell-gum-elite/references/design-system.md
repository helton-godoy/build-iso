# Premium Terminal Design System

## Intent

Provide a consistent, high-end visual language for shell interfaces built with Gum.

## Palette

| Token | Color | Usage |
|---|---|---|
| `--color-primary` | `#8ECAE6` | Headers, labels, neutral emphasis |
| `--color-accent` | `#FFB703` | Focus states, active selections |
| `--color-success` | `#2A9D8F` | Success confirmations |
| `--color-warning` | `#FB8500` | Warnings and confirmations |
| `--color-error` | `#D62828` | Error states |
| `--color-muted` | `#6C757D` | Secondary metadata |

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
- Chain visual states: select -> confirm -> execute -> report.
- Avoid stacked spinners; serialize long operations for clarity.

## Accessibility

1. Never encode meaning with color alone.
2. Keep contrast high for prompt text and cursor focus.
3. Use explicit placeholder text to reduce ambiguity.
4. Keep actionable labels short and verb-first.

## Reusable Style Presets

```bash
ui_header() {
  gum style \
    --foreground "#8ECAE6" \
    --border double \
    --border-foreground "#FFB703" \
    --padding "1 2" \
    --bold \
    "$1"
}

ui_error() {
  gum style --foreground "#D62828" --bold "[ERR] $1"
}
```
