# Performance Optimization

Techniques for writing high-performance Bash scripts using pure built-in features.

## Core Principles

1. **Avoid external commands** - Each fork/exec is expensive
2. **Use built-ins** - They're implemented in C, very fast
3. **Minimize subshells** - `$()` creates subshells
4. **Prefer parameter expansion** - No process creation
5. **Use `[[ ]]` over `[ ]`** - Built-in vs external
6. **Use `(( ))` for math** - No external `expr`

## External vs Built-in

| External | Built-in | Speedup |
|----------|----------|---------|
| `cat file` | `$(<file)` | ~100x |
| `grep pattern` | `[[ $v =~ pattern ]]` | ~50x |
| `sed 's/a/b/'` | `${var/a/b}` | ~500x |
| `tr 'A-Z' 'a-z'` | `${var,,}` | ~1000x |
| `awk '{print $1}'` | `${var%% *}` | ~200x |
| `cut -d: -f1` | `${var%%:*}` | ~200x |
| `expr $a + $b` | `((c=a+b))` | ~1000x |
| `seq 1 100` | `{1..100}` | ~500x |
| `wc -l` | `mapfile` + `${#arr[@]}` | ~50x |
| `basename` | `${var##*/}` | ~100x |
| `dirname` | `${var%/*}` | ~100x |
| `sleep 1` | `read -rt 1` (Bash 4+) | ~10x |

## String Operations

### Fast string replacement
```bash
# SLOW: External sed
result=$(echo "$var" | sed 's/foo/bar/g')

# FAST: Parameter expansion
result=${var//foo/bar}
```

### Fast case conversion
```bash
# SLOW: External tr
lower=$(echo "$var" | tr '[:upper:]' '[:lower:]')

# FAST: Parameter expansion (Bash 4+)
lower=${var,,}
upper=${var^^}
```

### Fast substring
```bash
# SLOW: External cut
first=$(echo "$line" | cut -d' ' -f1)

# FAST: Parameter expansion
first=${line%% *}
rest=${line#* }
```

### Fast trimming
```bash
# SLOW: External sed/awk
result=$(echo "$var" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# FAST: Parameter expansion
trim() {
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}
```

## File Operations

### Fast file reading
```bash
# SLOW: External cat
content=$(cat "file")

# FAST: Built-in redirection
content=$(<"file")

# FAST: mapfile for arrays (Bash 4+)
mapfile -t lines < "file"
```

### Fast line counting
```bash
# SLOW: External wc
lines=$(wc -l < "file")

# FAST: Built-in (Bash 4+)
mapfile -tn 0 arr < "file"
lines=${#arr[@]}

# FAST: Loop (Bash 3, memory efficient)
lines=0
while IFS= read -r _; do ((lines++)); done < "file"
```

### Fast iteration
```bash
# SLOW: External find + while
find . -name '*.txt' | while read -r file; do
    process "$file"
done

# FAST: Glob + for
for file in *.txt; do
    [[ -e $file ]] || continue
    process "$file"
done

# FAST: Recursive (Bash 4+)
shopt -s globstar
for file in **/*.txt; do
    [[ -e $file ]] || continue
    process "$file"
done
shopt -u globstar
```

## Arithmetic

### Fast math
```bash
# SLOW: External expr
result=$(expr $a + $b)

# FAST: Built-in arithmetic
((result = a + b))
result=$((a + b))

# FAST: Increment/decrement
((count++))
((total += value))
```

### Fast comparison
```bash
# SLOW: External test
if test "$a" -eq "$b"; then
    ...
fi

# FAST: Built-in
if ((a == b)); then
    ...
fi
```

### Fast loop ranges
```bash
# SLOW: External seq
for i in $(seq 1 100); do
    echo "$i"
done

# FAST: Brace expansion
for i in {1..100}; do
    echo "$i"
done

# FAST: C-style loop
for ((i=1; i<=100; i++)); do
    echo "$i"
done
```

## Array Operations

### Fast array initialization
```bash
# SLOW: Loop + append
arr=()
for i in {1..100}; do
    arr+=($i)
done

# FAST: Direct assignment
arr=({1..100})
```

### Fast unique elements
```bash
# SLOW: Sort + uniq
unique=$(printf '%s\n' "${arr[@]}" | sort -u)

# FAST: Associative array (Bash 4+)
declare -A seen
for item in "${arr[@]}"; do
    seen[$item]=1
done
unique=("${!seen[@]}")
```

## Conditional Testing

### Fast pattern matching
```bash
# SLOW: External grep
if echo "$var" | grep -q "pattern"; then
    ...
fi

# FAST: Built-in [[ ]]
if [[ $var == *pattern* ]]; then
    ...
fi

# FAST: Regex
if [[ $var =~ ^[0-9]+$ ]]; then
    ...
fi
```

### Fast file tests
```bash
# SLOW: External test
if test -f "$file"; then
    ...
fi

# FAST: Built-in [[ ]]
if [[ -f $file ]]; then
    ...
fi
```

## Unicode and Locale

### Disable Unicode for speed
```bash
# Can improve performance by ~30%
LC_ALL=C
LANG=C

# Example: Faster pattern matching
LC_ALL=C
[[ $var == *[a-z]* ]]  # Faster than Unicode
```

### Locale considerations
```bash
# Uppercase/lowercase is locale-dependent
# In some locales, uppercase conversion can be slow

# Fast: ASCII only (set LC_ALL=C first)
LC_ALL=C
upper=${var^^}
```

## Avoiding Subshells

### Problem: Subshell overhead
```bash
# SLOW: Subshell for each iteration
for i in {1..1000}; do
    result=$(echo $i | wc -c)
done

# FAST: No subshell
for i in {1..1000}; do
    result=${#i}
done
```

### Grouping without subshell
```bash
# Creates subshell
(
    cd /tmp
    do_something
)

# No subshell (current shell)
{
    cd /tmp
    do_something
}
```

### Process substitution vs here-string
```bash
# Slower: Process substitution
while read -r line; do
    ...
done < <(command)

# Faster: Here-string (if data fits)
while read -r line; do
    ...
done <<< "$data"

# Fastest: Pipe (sometimes)
command | while read -r line; do
    ...
done
```

## Memory Optimization

### Streaming vs loading
```bash
# MEMORY INTENSIVE: Load entire file
mapfile -t lines < "huge_file"
for line in "${lines[@]}"; do
    process "$line"
done

# MEMORY EFFICIENT: Stream
while IFS= read -r line; do
    process "$line"
done < "huge_file"
```

### Array slicing instead of copying
```bash
# WASTEFUL: Copy array
new_arr=("${old_arr[@]:10}")

# BETTER: Use slice directly
for item in "${old_arr[@]:10}"; do
    process "$item"
done
```

## Code Patterns

### Fast default values
```bash
# OK: External:-
value=${var:-default}

# Fast for frequent operations
: ${var:=default}  # Sets if empty
```

### Fast string building
```bash
# SLOW: Repeated cat
cmd="echo"
for arg in "$@"; do
    cmd="$cmd $arg"
done

# FAST: Array join
args=("$@")
cmd="echo ${args[*]}"
```

### Fast accumulation
```bash
# SLOW: String concatenation in loop
result=""
for item in "${arr[@]}"; do
    result="$result$item,"
done

# FAST: Use IFS
IFS=',' result="${arr[*]}"
```

## Benchmarking

### Simple timing
```bash
start=$SECONDS
# ... code ...
((elapsed = SECONDS - start))
echo "Took $elapsed seconds"
```

### Micro-benchmarking
```bash
# Compare two approaches
timeit() {
    local start=$SECONDS
    local i
    for ((i=0; i<1000; i++)); do
        "$@" &>/dev/null
    done
    echo "Took $((SECONDS - start)) seconds"
}

# Test
timeit external_command
timeit builtin_equivalent
```

## Performance Checklist

- [ ] Replace `cat` with `$(<file)`
- [ ] Replace `grep` with `[[ =~ ]]`
- [ ] Replace `sed` with parameter expansion
- [ ] Replace `awk` with parameter expansion
- [ ] Replace `tr` with `${var,,}` or `${var^^}`
- [ ] Replace `cut` with `${var#pattern}` or `${var%%pattern}`
- [ ] Replace `expr` with `(( ))`
- [ ] Replace `seq` with `{1..100}`
- [ ] Replace `wc -l` with `mapfile`
- [ ] Replace `basename` with `${var##*/}`
- [ ] Replace `dirname` with `${var%/*}`
- [ ] Use `[[ ]]` instead of `[ ]` or `test`
- [ ] Use `(( ))` for arithmetic
- [ ] Avoid subshells with `$()` when possible
- [ ] Use `LC_ALL=C` for ASCII operations
- [ ] Stream large files instead of loading
- [ ] Use arrays instead of strings for lists

## When to Use External Commands

Sometimes external commands are necessary or faster:

| Situation | Use |
|-----------|-----|
| Complex text processing | awk/sed |
| Sorting | sort |
| Cryptographic hashes | md5sum/sha256sum |
| File operations (cp/mv/rm) | External commands |
| Network operations | curl/wget |
| Binary data | External tools |
| Regular expressions | grep (for PCRE) |
| XML/JSON parsing | Specialized tools |

## Real-World Example

### Before (Slow)
```bash
#!/bin/bash
count=0
for file in *.txt; do
    lines=$(cat "$file" | wc -l)
    words=$(cat "$file" | wc -w)
    chars=$(cat "$file" | wc -c)
    echo "$file: $lines lines, $words words, $chars chars"
    ((count++))
done
echo "Total files: $count"
```

### After (Fast)
```bash
#!/bin/bash
LC_ALL=C
shopt -s nullglob
txt_files=(*.txt)
shopt -u nullglob

for file in "${txt_files[@]}"; do
    lines=0 words=0 chars=0
    while IFS= read -r line; do
        ((lines++))
        ((chars += ${#line} + 1))
        # Count words by converting spaces to newlines
        words+=($line)
    done < "$file"
    printf '%s: %d lines, %d words, %d chars\n' \
        "$file" "$lines" "${#words[@]}" "$chars"
done

printf 'Total files: %d\n' "${#txt_files[@]}"
```
