# Acceptance Criteria: pure-bash-bible

**Purpose**: Skill testing acceptance criteria for pure-bash-bible skill

---

## 1. Correct Import Patterns

### 1.1 Using Built-ins

#### ✅ CORRECT: No imports needed
```bash
#!/usr/bin/env bash
# Pure Bash uses only built-in features
# No external imports required

# Example: String manipulation
str="Hello World"
lower=${str,,}
```

#### ✅ CORRECT: Using parameter expansion
```bash
# Pure Bash alternative to sed/awk/grep
result=${var//pattern/replacement}
```

#### ❌ INCORRECT: Using external tools when built-ins available
```bash
# Wrong - external process
result=$(echo "$var" | sed 's/foo/bar/g')

# Wrong - external process
result=$(echo "$var" | tr '[:upper:]' '[:lower:]')

# Wrong - external process
if echo "$var" | grep -q "pattern"; then
    ...
fi
```

---

## 2. Parameter Expansion Patterns

### 2.1 Substring Removal

#### ✅ CORRECT: Remove from start
```bash
${var#pattern}      # Shortest match
${var##pattern}     # Longest match
```

#### ✅ CORRECT: Remove from end
```bash
${var%pattern}      # Shortest match
${var%%pattern}     # Longest match
```

#### ✅ CORRECT: Practical examples
```bash
# Get directory (dirname alternative)
dir=${path%/*}

# Get filename (basename alternative)
base=${path##*/}

# Remove extension
name=${base%.*}
```

#### ❌ INCORRECT: Using external commands
```bash
# Wrong
dir=$(dirname "$path")

# Wrong  
base=$(basename "$path")

# Wrong
name=$(echo "$base" | sed 's/\.[^.]*$//')
```

### 2.2 Search and Replace

#### ✅ CORRECT: Parameter expansion
```bash
${var/pattern/repl}     # Replace first
${var//pattern/repl}    # Replace all
```

#### ❌ INCORRECT: External sed
```bash
# Wrong
result=$(echo "$var" | sed 's/foo/bar/')

# Wrong
result=$(echo "$var" | sed 's/foo/bar/g')
```

### 2.3 Case Modification (Bash 4+)

#### ✅ CORRECT: Parameter expansion
```bash
${var,,}        # Lowercase all
${var^^}        # Uppercase all
${var~~}        # Toggle case
${var,}         # Lowercase first
${var^}         # Uppercase first
```

#### ❌ INCORRECT: External tr
```bash
# Wrong
lower=$(echo "$var" | tr '[:upper:]' '[:lower:]')

# Wrong
upper=$(echo "$var" | tr '[:lower:]' '[:upper:]')
```

---

## 3. String Testing Patterns

### 3.1 Substring Testing

#### ✅ CORRECT: Using [[ ]]
```bash
[[ $var == *substring* ]]    # Contains
[[ $var == prefix* ]]        # Starts with
[[ $var == *suffix ]]        # Ends with
```

#### ✅ CORRECT: Using case
```bash
case $var in
    *substring*) ... ;;
esac
```

#### ❌ INCORRECT: Using grep
```bash
# Wrong
if echo "$var" | grep -q "substring"; then
    ...
fi
```

### 3.2 Regex Matching

#### ✅ CORRECT: Using [[ =~ ]]
```bash
if [[ $var =~ ^[0-9]+$ ]]; then
    ...
fi
```

#### ❌ INCORRECT: External grep
```bash
# Wrong
if echo "$var" | grep -qE '^[0-9]+$'; then
    ...
fi
```

---

## 4. Array Patterns

### 4.1 Array Declaration

#### ✅ CORRECT: Indexed arrays
```bash
arr=(a b c)
arr+=(new_item)
```

#### ✅ CORRECT: Read into array (Bash 4+)
```bash
mapfile -t arr < "file"
```

#### ✅ CORRECT: Read into array (Bash 3)
```bash
while IFS= read -r line; do
    arr+=("$line")
done < "file"
```

### 4.2 Array Access

#### ✅ CORRECT: Proper quoting
```bash
"${arr[@]}"     # All elements (quoted)
${#arr[@]}      # Array length
${!arr[@]}      # All indices
```

#### ❌ INCORRECT: Unquoted expansion
```bash
# Wrong - word splitting issues
for item in ${arr[@]}; do
    ...
end

# Wrong
len=${#arr}  # Length of first element, not array
```

---

## 5. File Operation Patterns

### 5.1 Reading Files

#### ✅ CORRECT: Read to variable
```bash
content="$(<file)"
```

#### ✅ CORRECT: Read to array (Bash 4+)
```bash
mapfile -t lines < "file"
```

#### ❌ INCORRECT: External cat
```bash
# Wrong
content=$(cat "file")
```

### 5.2 File Iteration

#### ✅ CORRECT: Using globs
```bash
for file in *.txt; do
    [[ -e $file ]] || continue
    ...
done
```

#### ❌ INCORRECT: Using ls
```bash
# Wrong
for file in $(ls *.txt); do
    ...
done
```

---

## 6. Arithmetic Patterns

### 6.1 Arithmetic Operations

#### ✅ CORRECT: Using (( ))
```bash
((result = a + b))
((count++))
((total += value))
```

#### ✅ CORRECT: Using $(( ))
```bash
result=$((a + b))
```

#### ❌ INCORRECT: External expr
```bash
# Wrong
result=$(expr $a + $b)

# Wrong
result=$(expr $a \* $b)
```

---

## 7. Conditional Patterns

### 7.1 Test Command

#### ✅ CORRECT: Using [[ ]]
```bash
[[ -f $file ]]      # File exists and is regular
[[ -d $dir ]]       # Is directory
[[ -z $var ]]       # Is empty
[[ -n $var ]]       # Is not empty
[[ $a == $b ]]      # String equality
[[ $a =~ regex ]]   # Regex match
```

#### ❌ INCORRECT: Using [ ] or test
```bash
# Less preferred
[ -f "$file" ]
test -f "$file"
```

---

## 8. Loop Patterns

### 8.1 Range Loops

#### ✅ CORRECT: Brace expansion
```bash
for i in {1..100}; do
    ...
done
```

#### ✅ CORRECT: C-style for
```bash
for ((i=0; i<100; i++)); do
    ...
done
```

#### ❌ INCORRECT: External seq
```bash
# Wrong
for i in $(seq 1 100); do
    ...
done
```

---

## 9. Best Practices

### 9.1 Shebang

#### ✅ CORRECT
```bash
#!/usr/bin/env bash
```

#### ❌ INCORRECT
```bash
#!/bin/bash  # Less portable
```

### 9.2 Command Substitution

#### ✅ CORRECT
```bash
var=$(command)
```

#### ❌ INCORRECT
```bash
var=`command`  # Backticks are legacy
```

### 9.3 Function Declaration

#### ✅ CORRECT
```bash
my_function() {
    ...
}
```

#### ❌ INCORRECT
```bash
function my_function() {  # Unnecessary keyword
    ...
}
```

---

## 10. Performance Patterns

### 10.1 String Building

#### ✅ CORRECT: Using arrays
```bash
args=("$@")
result="${args[*]}"
```

#### ❌ INCORRECT: String concatenation in loop
```bash
# Slow
result=""
for item in "$@"; do
    result="$result $item"
done
```

### 10.2 Locale for ASCII

#### ✅ CORRECT: Set for performance
```bash
LC_ALL=C
LANG=C
```

---

## 11. Common Anti-Patterns

### 11.1 UUOC (Useless Use of Cat)

#### ❌ ANTI-PATTERN
```bash
cat file | grep pattern
cat file | head -10
cat file | while read line; do ... done
```

#### ✅ CORRECT
```bash
grep pattern file
head -10 file
while read line; do ... done < file
```

### 11.2 Parsing ls

#### ❌ ANTI-PATTERN
```bash
for file in $(ls); do
    ...
done
```

#### ✅ CORRECT
```bash
for file in *; do
    [[ -e $file ]] || continue
    ...
done
```

### 11.3 Unquoted Variables

#### ❌ ANTI-PATTERN
```bash
if [ $var = "test" ]; then
    ...
fi
```

#### ✅ CORRECT
```bash
if [[ $var == "test" ]]; then
    ...
fi
```

---

## 12. Version Compatibility

### 12.1 Bash 4+ Features

The following require Bash 4+:
- `${var,,}` - Case modification
- `${var^^}` - Case modification
- `${var~~}` - Case toggle
- `mapfile` - Read array
- `readarray` - Read array
- `globstar` - Recursive globs
- `{start..end..step}` - Brace expansion with step
- Associative arrays (`declare -A`)
- `|&` - Pipe stderr

#### ✅ CORRECT: Version check
```bash
if ((BASH_VERSINFO[0] >= 4)); then
    # Use Bash 4+ features
    lower=${var,,}
else
    # Fallback for Bash 3
    lower=$(printf '%s' "$var" | tr '[:upper:]' '[:lower:]')
fi
```
