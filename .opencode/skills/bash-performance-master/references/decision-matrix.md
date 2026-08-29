# Decision matrix

## Strictness

| Profile | Settings | Select when |
|---|---|---|
| `portable` | none | Explicit status handling or legacy behavior is required |
| `balanced` | `set -u -o pipefail` | Default for new Bash scripts |
| `aggressive` | `set -euo pipefail` | Control flow is designed and tested for `errexit` |

Do not add `set -e` mechanically to existing scripts.

## Builtin versus external

| Situation | Default |
|---|---|
| Short scalar in a variable | Parameter expansion |
| Large or unbounded input | Streaming tool |
| Fixed delimiter fields | `IFS= read -r` |
| Quoted CSV | Real CSV parser |
| Recursive metadata predicates | `find` |
| Small known directory | Glob with explicit empty-match policy |
| Validated integers | Bash arithmetic |
| Complex record aggregation | `awk` or domain tool |

## Non-equivalences

- `: > file` truncates; `touch file` preserves content.
- Parameter trimming is not a complete `basename` or `dirname` replacement.
- `globstar` is not a complete `find` replacement.
- Closing fd 2 differs from redirecting it to `/dev/null`.
- Here-strings and brace expansions materialize their input.
- Bash substitutions use glob patterns, not regular expressions.
