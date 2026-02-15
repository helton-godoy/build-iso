# Array Manipulation

Complete guide to Bash arrays using pure built-in features.

## Array Declaration

### Indexed arrays
```bash
# Declare empty
arr=()

# With elements
arr=(a b c)
arr=("first item" "second item")

# With indices
arr[0]=first
arr[5]=fifth  # Sparse array

# From command output
arr=($(command))
arr=("$(command)")  # Better for preserving spaces

# From string
str="a:b:c"
IFS=':' read -ra arr <<< "$str"
```

### Associative arrays (Bash 4+)
```bash
declare -A assoc
assoc[key]=value
assoc=([key1]=val1 [key2]=val2)
```

## Array Operations

### Get elements
```bash
arr=(a b c d e)

# All elements
${arr[@]}         # a b c d e
${arr[*]}         # a b c d e (as single word)

# Specific element
${arr[0]}         # a
${arr[2]}         # c

# With quotes (preserves spaces)
"${arr[@]}"       # "a" "b" "c" "d" "e"
```

### Get indices
```bash
# All indices
${!arr[@]}        # 0 1 2 3 4
${!arr[*]}

# Count elements
${#arr[@]}        # 5
${#arr[*]}

# Length of element
${#arr[0]}        # 1 (length of "a")
```

### Slicing
```bash
arr=(a b c d e f g)

# From index
${arr[@]:3}       # d e f g

# With count
${arr[@]:2:3}     # c d e

# Negative index (from end)
${arr[@]: -3}     # e f g

# From end with count
${arr[@]: -4:2}   # d e
```

### Adding elements
```bash
arr=()

# Append
arr+=("new item")
arr+=(a b c)      # Add multiple

# Prepend
arr=("new" "${arr[@]}")

# At specific index
arr[10]=tenth
arr[$(( ${#arr[@]} + 1 ))]=next
```

### Removing elements
```bash
arr=(a b c d e)

# Remove specific index
unset 'arr[2]'    # Removes 'c'

# Remove first
arr=("${arr[@]:1}")

# Remove last
arr=("${arr[@]::${#arr[@]}-1}")

# Remove by value (keep others)
arr=("${arr[@]/b/}")

# Filter (keep only matching)
new_arr=()
for item in "${arr[@]}"; do
    [[ $item == pattern ]] && new_arr+=("$item")
done
```

## Array Functions

### Print array
```bash
print_array() {
    printf '%s\n' "$@"
}

# Usage
print_array "${arr[@]}"
```

### Join array
```bash
join() {
    local IFS="$1"
    shift
    printf '%s\n' "$*"
}

# Usage
join ',' "${arr[@]}"    # a,b,c
```

### Reverse array
```bash
reverse_array() {
    # Method 1: Using extdebug
    shopt -s extdebug
    f()(printf '%s\n' "${BASH_ARGV[@]}"); f "$@"
    shopt -u extdebug
}

# Method 2: Using loop
reverse_loop() {
    local arr=("$@")
    local i
    for ((i=${#arr[@]}-1; i>=0; i--)); do
        printf '%s\n' "${arr[$i]}"
    done
}
```

### Remove duplicates (Bash 4+)
```bash
unique() {
    declare -A seen
    local item
    for item in "$@"; do
        [[ $item ]] && seen["$item"]=1
    done
    printf '%s\n' "${!seen[@]}"
}
```

### Random element
```bash
random_element() {
    local arr=("$@")
    printf '%s\n' "${arr[RANDOM % $#]}"
}
```

### Contains check
```bash
contains() {
    local arr=("${@:2}")
    local item=$1
    local i
    for i in "${arr[@]}"; do
        [[ $i == "$item" ]] && return 0
    done
    return 1
}

# Usage
if contains "b" "${arr[@]}"; then
    echo "Found"
fi
```

### Sort array (Bash 4+)
```bash
sort_array() {
    local IFS=$'\n'
    local sorted=($(sort <<< "${*//$/}"
    printf '%s\n' "${sorted[@]}"
}

# Alternative (no external sort)
sort_builtin() {
    local arr=("$@")
    local i j tmp
    for ((i=0; i<${#arr[@]}; i++)); do
        for ((j=i+1; j<${#arr[@]}; j++)); do
            if [[ ${arr[$i]} > ${arr[$j]} ]]; then
                tmp=${arr[$i]}
                arr[$i]=${arr[$j]}
                arr[$j]=$tmp
            fi
        done
    done
    printf '%s\n' "${arr[@]}"
}
```

### Min/Max (numeric)
```bash
array_min() {
    local min=$1
    local n
    for n in "$@"; do
        ((n < min)) && min=$n
    done
    printf '%s\n' "$min"
}

array_max() {
    local max=$1
    local n
    for n in "$@"; do
        ((n > max)) && max=$n
    done
    printf '%s\n' "$max"
}
```

## Reading Files into Arrays

### Read lines (Bash 4+)
```bash
mapfile -t arr < "file.txt"
mapfile -t -n 10 arr < "file.txt"  # First 10 lines
mapfile -t -s 5 arr < "file.txt"   # Skip first 5 lines
mapfile -t -O 5 arr < "file.txt"   # Start at index 5
```

### Read lines (Bash 3)
```bash
arr=()
while IFS= read -r line || [[ $line ]]; do
    arr+=("$line")
done < "file.txt"
```

### Read words
```bash
read -ra words <<< "word1 word2 word3"
```

### Read with delimiter
```bash
IFS=':' read -ra parts <<< "a:b:c"
```

## Array Iteration

### Elements only
```bash
for item in "${arr[@]}"; do
    echo "$item"
done
```

### With index
```bash
for i in "${!arr[@]}"; do
    echo "$i: ${arr[$i]}"
done
```

### C-style loop
```bash
for ((i=0; i<${#arr[@]}; i++)); do
    echo "$i: ${arr[$i]}"
done
```

### While loop (destructive)
```bash
arr_copy=("${arr[@]}")
while ((${#arr_copy[@]})); do
    echo "${arr_copy[0]}"
    arr_copy=("${arr_copy[@]:1}")
done
```

## Associative Arrays

### Operations
```bash
declare -A assoc

# Set
assoc[key]=value
assoc+=([key2]=val2 [key3]=val3)

# Get
${assoc[key]}

# Check if key exists
[[ ${assoc[key]+isset} ]]

# Get all keys
${!assoc[@]}

# Get all values
${assoc[@]}

# Count
${#assoc[@]}

# Iterate
for key in "${!assoc[@]}"; do
    echo "$key: ${assoc[$key]}"
done

# Remove
unset 'assoc[key]'
```

## Advanced Patterns

### Cycle through array
```bash
arr=(a b c d)
cycle() {
    printf '%s ' "${arr[${i:=0}]}"
    ((i=i>=${#arr[@]}-1?0:++i))
}

# Usage
for _ in {1..10}; do cycle; done  # a b c d a b c d a b
```

### Toggle between values
```bash
toggle() {
    local arr=("$@")
    printf '%s\n' "${arr[${i:=0}]}"
    ((i=i>=${#arr[@]}-1?0:++i))
}

# Usage
toggle true false  # Returns alternating true/false
```

### Cartesian product
```bash
cartesian() {
    local arr1=("${@:1:$#/2}")
    local arr2=("${@:$(( $#/2 + 1 ))}")
    local a b
    for a in "${arr1[@]}"; do
        for b in "${arr2[@]}"; do
            echo "$a-$b"
        done
    done
}
```

### Array difference
```bash
array_diff() {
    local arr1=("${@:1:$#/2}")
    local arr2=("${@:$(( $#/2 + 1 ))}")
    local item found
    for item in "${arr1[@]}"; do
        found=0
        for check in "${arr2[@]}"; do
            [[ $item == "$check" ]] && { found=1; break; }
        done
        ((found)) || echo "$item"
    done
}
```

## Quick Reference

| Operation | Syntax |
|-----------|--------|
| Declare | `arr=(a b c)` |
| Access | `${arr[0]}` |
| All elements | `${arr[@]}` |
| All quoted | `"${arr[@]}"` |
| All indices | `${!arr[@]}` |
| Count | `${#arr[@]}` |
| Slice | `${arr[@]:2:3}` |
| Last N | `${arr[@]: -3}` |
| Append | `arr+=(item)` |
| Delete index | `unset 'arr[2]'` |
| Delete all | `unset arr` |
| Iterate | `for item in "${arr[@]}"; do` |
| With index | `for i in "${!arr[@]}"; do` |
