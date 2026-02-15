# Gum UX Patterns

## Command-to-Use-Case Mapping

| UX Need | Gum Command | Pattern |
|---|---|---|
| Single selection menu | `gum choose` | `choice="$(gum choose a b c)"` |
| Multi selection | `gum choose --no-limit` | `selected="$(gum choose --no-limit ... )"` |
| Fuzzy filtering | `gum filter` | `pick="$(printf '%s\n' ... | gum filter)"` |
| Single-line input | `gum input` | `name="$(gum input --placeholder 'Name')"` |
| Password prompt | `gum input --password` | `pass="$(gum input --password)"` |
| Multi-line entry | `gum write` | `body="$(gum write --placeholder 'Details')"` |
| Confirmation | `gum confirm` | `gum confirm 'Continue?' || exit 0` |
| Spinner feedback | `gum spin` | `gum spin --title 'Working...' -- command` |
| Styled messaging | `gum style`, `gum log` | Reusable status wrappers |
| Data display | `gum table`, `gum pager`, `gum format` | Rich output and browsing |

## Premium Interaction Flows

### Validated input loop

```bash
while :; do
  version="$(gum input --placeholder "1.2.3")"
  [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
  gum log --level error "Invalid version: ${version}"
done
```

### Safe destructive action

```bash
target="$(gum file --all)"
gum confirm "Delete ${target}?" --default=false || exit 0
gum spin --title "Deleting..." -- rm -rf -- "${target}"
gum log --level info "Deleted ${target}"
```

### Progressive disclosure flow

```bash
env="$(gum choose --header "Environment" dev stage prod)"
details="$(gum write --placeholder "Describe deployment")"
gum style --border rounded --padding "1 2" "${env}\n${details}"
gum confirm "Proceed?" || exit 0
```

## Styling Baseline

- Header cards: `rounded` or `double` borders.
- Important actions: accent foreground + bold.
- Errors: explicit text prefix plus color (`[ERR]`).
- Keep max 2-3 strong colors on a screen to reduce visual noise.

## Contextual Spinners

Choose the spinner type based on what the operation does:

| Operation | Spinner | Why |
| --- | --- | --- |
| Build/compile | `line` or `meter` | Implies sequential progress |
| Network/download | `globe` or `pulse` | Conveys remote activity |
| General processing | `dot` (default) | Universal, unobtrusive |
| Long background task | `moon` | Slow cadence matches long waits |
| File operations | `minidot` | Subtle, quick feedback |
| Fun/demo scripts | `monkey` or `hamburger` | Light-hearted tone |

## Timeout Best Practice

All interactive Gum subcommands accept `--timeout`. Use it in automation
and CI-adjacent scripts to prevent indefinite hangs:

```bash
# Abort if no input within 30 seconds
gum input --placeholder "Name" --timeout 30s

# Auto-confirm after 10 seconds (useful for unattended scripts)
gum confirm "Continue?" --timeout 10s --default yes
```

## Operational Caveats

1. Always capture command output from Gum subcommands when used as data.
2. Provide fallbacks for non-interactive sessions when needed.
3. Use `--timeout` or explicit cancellation paths for unattended scripts.
4. Check installed Gum version if using recently added flags.
