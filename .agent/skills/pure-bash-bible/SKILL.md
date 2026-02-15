---
name: pure-bash-bible
description: |
  Pure Bash scripting techniques using only built-in features without external tools.
  Use for: string manipulation, arrays, file handling, loops, parameter expansion.
  Replaces: sed, awk, grep, cut, wc, head, tail, cat, seq, dirname, basename.
  Triggers: "bash pure", "without external tools", "bash built-in", "parameter expansion",
           "replace sed", "replace awk", "pure bash", "bash alternative",
           "bash puro", "sem ferramentas externas", "expansão de parâmetro",
           "substituir sed", "substituir awk", "puro bash", "alternativa bash",
           "apenas bash", "somente bash", "built-in bash", "recursos nativos bash".
---

# Pure Bash Bible

A collection of pure Bash alternatives to external processes. This skill helps you write efficient, portable Bash scripts using only built-in features.

## Quick Reference

| External Tool | Pure Bash Alternative |
|--------------|----------------------|
| `sed` | Parameter expansion, regex matching |
| `awk` | Parameter expansion, read built-in |
| `grep` | `[[ string =~ pattern ]]` |
| `cut` | Parameter expansion, IFS |
| `wc -l` | `${#array[@]}` or while read loop |
| `head` | `mapfile -tn N` |
| `tail` | `mapfile -tn 0` + array slicing |
| `cat file` | `$(<file)` |
| `seq` | Brace expansion `{1..100}` |
| `dirname` | Parameter expansion `${1%/*}` |
| `basename` | Parameter expansion `${1##*/}` |
| `tr` | Parameter expansion `${var,,}` `${var^^}` |

## String Manipulation

### Trim leading and trailing whitespace

```bash
trim_string() {
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}
```

### Convert case (Bash 4+)

```bash
# To lowercase
lower() { printf '%s\n' "${1,,}"; }

# To uppercase
upper() { printf '%s\n' "${1^^}"; }

# Reverse case
reverse_case() { printf '%s\n' "${1~~}"; }
```

### Strip patterns

```bash
# Remove from start (shortest match)
${var#pattern}

# Remove from start (longest match)
${var##pattern}

# Remove from end (shortest match)
${var%pattern}

# Remove from end (longest match)
${var%%pattern}

# Replace first occurrence
${var/pattern/replacement}

# Replace all occurrences
${var//pattern/replacement}

# Remove first occurrence
${var/pattern}

# Remove all occurrences
${var//pattern}
```

### Regex matching

```bash
if [[ $string =~ ^[0-9]+$ ]]; then
    echo "Is a number"
    # Capture groups available in ${BASH_REMATCH[@]}
fi
```

### Check substring

```bash
# Contains substring
[[ $var == *substring* ]]

# Starts with
[[ $var == prefix* ]]

# Ends with
[[ $var == *suffix ]]
```

## Arrays

### Read file into array

```bash
# Bash 4+
mapfile -t array < "file"

# Bash 3 (preserve empty lines)
while IFS= read -r line; do
    array+=("$line")
done < "file"
```

### Remove duplicates (Bash 4+)

```bash
remove_dups() {
    declare -A tmp
    for i in "$@"; do
        [[ $i ]] && tmp["$i"]=1
    done
    printf '%s\n' "${!tmp[@]}"
}
```

### Random element

```bash
random_element() {
    local arr=("$@")
    printf '%s\n' "${arr[RANDOM % $#]}"
}
```

### Array operations

```bash
# Reverse array
shopt -s extdebug
f()(printf '%s\n' "${BASH_ARGV[@]}"); f "${array[@]}"
shopt -u extdebug

# Get length
${#array[@]}

# All elements
${array[@]}

# All indices
${!array[@]}

# Slice
${array[@]:start:count}

# Last N elements
${array[@]: -N}
```

## Loops

### Range loops

```bash
# Fixed range (no variables)
for i in {1..100}; do
    echo "$i"
done

# Variable range
for ((i=0; i<=MAX; i++)); do
    echo "$i"
done

# With step (Bash 4+)
for i in {0..100..2}; do
    echo "$i"
done
```

### Array loops

```bash
arr=(a b c)

# Elements only
for element in "${arr[@]}"; do
    echo "$element"
done

# With index
for i in "${!arr[@]}"; do
    echo "$i: ${arr[$i]}"
done
```

### File loops

```bash
# Read file line by line
while IFS= read -r line; do
    echo "$line"
done < "file"

# Iterate files (don't use ls)
for file in *.txt; do
    echo "$file"
done

# Recursive (Bash 4+)
shopt -s globstar
for file in **/*; do
    echo "$file"
done
shopt -u globstar
```

## File Operations

### Read files

```bash
# Read entire file to string
content="$(<file)"

# Read to array (Bash 4+)
mapfile -t lines < "file"

# Get first N lines
mapfile -tn 10 lines < "file"

# Get last N lines
mapfile -tn 0 lines < "file"
printf '%s\n' "${lines[@]: -10}"

# Count lines
mapfile -tn 0 lines < "file"
${#lines[@]}
```

### File path manipulation

```bash
# Directory name (dirname alternative)
dir=${1%/*}

# Base name (basename alternative)
base=${1##*/}

# Remove extension
name=${base%.*}
ext=${base##*.}

# Full path breakdown
path="/home/user/file.txt"
dir=${path%/*}       # /home/user
base=${path##*/}     # file.txt
name=${base%.*}      # file
ext=${base##*.}      # txt
```

## Parameter Expansion Reference

| Expansion | Result |
|-----------|--------|
| `${var:-default}` | Use default if var is empty/unset |
| `${var:=default}` | Set and use default if var is empty/unset |
| `${var:+alternate}` | Use alternate if var is not empty |
| `${var:?error}` | Display error if var is empty/unset |
| `${#var}` | Length of var |
| `${var:offset}` | Substring from offset |
| `${var:offset:length}` | Substring from offset with length |
| `${var::length}` | First N characters |
| `${var: -length}` | Last N characters |
| `${var#pattern}` | Remove shortest prefix match |
| `${var##pattern}` | Remove longest prefix match |
| `${var%pattern}` | Remove shortest suffix match |
| `${var%%pattern}` | Remove longest suffix match |
| `${var/pattern/repl}` | Replace first match |
| `${var//pattern/repl}` | Replace all matches |
| `${var/#pattern/repl}` | Replace if at start |
| `${var/%pattern/repl}` | Replace if at end |
| `${var^}` | Uppercase first char (Bash 4+) |
| `${var^^}` | Uppercase all (Bash 4+) |
| `${var,}` | Lowercase first char (Bash 4+) |
| `${var,,}` | Lowercase all (Bash 4+) |
| `${var~}` | Toggle case first char (Bash 4+) |
| `${var~~}` | Toggle case all (Bash 4+) |

## Conditional Expressions

### File tests

```bash
[[ -e file ]]    # Exists
[[ -f file ]]    # Is regular file
[[ -d file ]]    # Is directory
[[ -r file ]]    # Is readable
[[ -w file ]]    # Is writable
[[ -x file ]]    # Is executable
[[ -s file ]]    # Has size > 0
[[ -L file ]]    # Is symlink
[[ file1 -nt file2 ]]  # Newer than
[[ file1 -ot file2 ]]  # Older than
```

### String tests

```bash
[[ -z $var ]]    # Is empty
[[ -n $var ]]    # Is not empty
[[ $var == "string" ]]  # Equals
[[ $var != "string" ]]  # Not equals
[[ $var =~ regex ]]     # Matches regex
[[ $var < $var2 ]]      # Lexicographically less
[[ $var > $var2 ]]      # Lexicographically greater
```

### Numeric tests

```bash
[[ $n -eq 5 ]]   # Equal
[[ $n -ne 5 ]]   # Not equal
[[ $n -lt 5 ]]   # Less than
[[ $n -le 5 ]]   # Less or equal
[[ $n -gt 5 ]]   # Greater than
[[ $n -ge 5 ]]   # Greater or equal
```

## Arithmetic

```bash
# Simple arithmetic
((result = 1 + 2))
((result++))
((result--))
((result += 5))

# With variables
((result = var1 + var2))
((result = arr[0] * 10))

# Ternary operator
((result = condition ? if_true : if_false))
((max = a > b ? a : b))

# Bitwise operations
((result = val << 2))   # Left shift
((result = val >> 2))   # Right shift
((result = val & mask)) # AND
((result = val | mask)) # OR
((result = val ^ mask)) # XOR
```

## Internal Variables

```bash
$BASH          # Path to bash binary
$BASH_VERSION  # Bash version string
$BASH_VERSINFO # Version as array
$BASHPID       # Current process ID
$PWD           # Current directory
$OLDPWD        # Previous directory
$HOSTNAME      # Host name
$HOSTTYPE      # CPU architecture
$OSTYPE        # Operating system
$SECONDS       # Seconds since script start
$RANDOM        # Random number 0-32767
$LINENO        # Current line number
$FUNCNAME      # Current function name
$0             # Script name
$1, $2, ...    # Positional parameters
$#             # Number of arguments
$@             # All arguments (preserve quotes)
$*             # All arguments (as single word)
$?             # Exit status of last command
$$             # PID of current shell
$!             # PID of last background job
```

## Best Practices

1. **Use `#!/usr/bin/env bash`** instead of `#!/bin/bash` for portability
2. **Use `$()`** instead of backticks for command substitution
3. **Use `[[ ]]`** instead of `[ ]` for tests (more features, safer)
4. **Use `(( ))`** for arithmetic operations
5. **Quote variables** to prevent word splitting: `"$var"` not `$var`
6. **Use `local`** for variables inside functions
7. **Use `printf`** instead of `echo` for portability
8. **Check for Bash 4+ features** if targeting older systems
9. **Use `mapfile -t`** instead of loops when reading files (Bash 4+)
10. **Disable Unicode for performance** when not needed: `LC_ALL=C LANG=C`

## Common Patterns

### URL encoding/decoding

```bash
urlencode() {
    local LC_ALL=C
    for ((i = 0; i < ${#1}; i++)); do
        : "${1:i:1}"
        case "$_" in
            [a-zA-Z0-9.~_-]) printf '%s' "$_" ;;
            *) printf '%%%02X' "'$_" ;;
        esac
    done
    printf '\n'
}

urldecode() {
    : "${1//+/ }"
    printf '%b\n' "${_//%/\\x}"
}
```

### Check if command exists

```bash
# Any of these work
if type -p command &>/dev/null; then
    echo "command exists"
fi

if hash command &>/dev/null; then
    echo "command exists"
fi

if command -v command &>/dev/null; then
    echo "command exists"
fi
```

### Sleep without external command (Bash 4+)

```bash
read_sleep() {
    read -rt "$1" <> <(:) || :
}
```

### Extract lines between markers

```bash
extract() {
    while IFS=$'\n' read -r line; do
        [[ $extract && $line != "$3" ]] && printf '%s\n' "$$line"
        [[ $line == "$2" ]] && extract=1
        [[ $line == "$3" ]] && extract=
    done < "$1"
}
```

## Performance Tips

1. **Avoid subshells** - Use built-ins instead of `$()` when possible
2. **Avoid external commands** - Use parameter expansion instead of sed/awk
3. **Use `[[ ]]`** instead of `[ ]` - No forking for pattern matching
4. **Use `(( ))`** for math - No external `expr` needed
5. **Disable Unicode** - Set `LC_ALL=C LANG=C` for ~30% speedup
6. **Use `read` instead of `sleep`** - No external process (Bash 4+)
7. **Use built-in `printf`** - No external `echo` needed
8. **Use parameter expansion** - Instead of `dirname`, `basename`, `cut`, etc.

## References

| Topic | Description |
|-------|-------------|
| [references/parameter-expansion.md](references/parameter-expansion.md) | Complete parameter expansion guide |
| [references/arrays.md](references/arrays.md) | Array manipulation patterns |
| [references/strings.md](references/strings.md) | String manipulation patterns |
| [references/file-operations.md](references/file-operations.md) | File handling without external tools |
| [references/performance.md](references/performance.md) | Optimization techniques |
