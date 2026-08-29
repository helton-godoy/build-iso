# Bash compatibility

Declare and test the minimum supported Bash version.

| Feature | Minimum Bash |
|---|---|
| `=~` | 3.0 |
| `printf -v` | 3.1 |
| `globstar`, associative arrays, case conversion | 4.0 |
| `declare -n`, `wait -n` | 4.3 |
| `${value@Q}` | 4.4 |

Bash supports `declare -l` and `declare -u`; it does not support `declare -c`. Do not claim POSIX `sh` compatibility for arrays, `[[`, process substitution, `shopt`, or advanced parameter transformations. Account for Bash 3.2 when the macOS system Bash is a target.
