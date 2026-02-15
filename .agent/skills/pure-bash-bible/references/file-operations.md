# File Operations

Pure Bash alternatives to external file utilities like cat, head, tail, wc, and more.

## Reading Files

### Read entire file
```bash
# Read to variable
content="$(<file)"

# Alternative
content=$(cat <"file")
```

### Read to array by lines (Bash 4+)
```bash
mapfile -t lines < "file"
```

### Read to array by lines (Bash 3)
```bash
lines=()
while IFS= read -r line || [[ $line ]]; do
    lines+=("$line")
done < "file"
```

### Read specific lines

#### First N lines (head)
```bash
# Bash 4+
head() {
    mapfile -tn "$1" line < "$2"
    printf '%s\n' "${line[@]}"
}

# Bash 3
head_compat() {
    local count=0
    while IFS= read -r line && ((count < $1)); do
        printf '%s\n' "$line"
        ((count++))
    done < "$2"
}
```

#### Last N lines (tail)
```bash
# Bash 4+
tail() {
    mapfile -tn 0 line < "$2"
    printf '%s\n' "${line[@]: -$1}"
}

# Bash 3
tail_compat() {
    local lines=()
    while IFS= read -r line; do
        lines+=("$line")
        ((${#lines[@]} > $1)) && lines=("${lines[@]:1}")
    done < "$2"
    printf '%s\n' "${lines[@]}"
}
```

### Read line by line
```bash
while IFS= read -r line; do
    # Process line
    echo "$line"
done < "file"
```

### Read with line numbers
```bash
line_num=0
while IFS= read -r line; do
    ((line_num++))
    printf '%5d: %s\n' "$line_num" "$line"
done < "file"
```

### Skip N lines
```bash
# Bash 4+
mapfile -t -s 10 lines < "file"  # Skip first 10

# Bash 3
skip=10
while ((skip-- > 0)) && IFS= read -r _; do :; done < "file"
while IFS= read -r line; do
    echo "$line"
done < "file"
```

### Read between markers
```bash
extract() {
    local file=$1
    local start=$2
    local end=$3
    local extract=0
    local line
    
    while IFS= read -r line; do
        [[ $extract == 1 && $line != "$end" ]] &&
            printf '%s\n' "$line"
        [[ $line == "$start" ]] && extract=1
        [[ $line == "$end" ]] && extract=0
    done < "$file"
}

# Usage
extract file.txt "### START" "### END"
```

## Line Counting

### Count lines
```bash
# Bash 4+
lines() {
    mapfile -tn 0 lines < "$1"
    printf '%s\n' "${#lines[@]}"
}

# Bash 3 - memory efficient
lines_loop() {
    local count=0
    while IFS= read -r _; do
        ((count++))
    done < "$1"
    printf '%s\n' "$count"
}

# Bash 3 - using wc (not pure)
lines_wc() {
    command wc -l < "$1"
}
```

### Count non-empty lines
```bash
non_empty_lines() {
    local count=0
    while IFS= read -r line; do
        [[ $line ]] && ((count++))
    done < "$1"
    printf '%s\n' "$count"
}
```

## File Path Operations

### Get directory (dirname)
```bash
dirname() {
    local tmp=${1:-.}
    
    [[ $tmp != *[!/]* ]] && { printf '/\n'; return; }
    
    tmp=${tmp%%"${tmp##*[!/]}"}
    [[ $tmp != */* ]] && { printf '.\n'; return; }
    
    tmp=${tmp%/*}
    tmp=${tmp%%"${tmp##*[!/]}"}
    
    printf '%s\n' "${tmp:-/}"
}
```

### Get filename (basename)
```bash
basename() {
    local tmp
    tmp=${1%"${1##*[!/]}"}
    tmp=${tmp##*/}
    tmp=${tmp%"${2/"$tmp"}"}
    printf '%s\n' "${tmp:-/}"
}

# Usage
basename "/path/to/file.txt"       # file.txt
basename "/path/to/file.txt" .txt  # file
```

### Split path
```bash
split_path() {
    local path=$1
    local dir=${path%/*}
    local base=${path##*/}
    local name=${base%.*}
    local ext=${base##*.}
    
    [[ $base == *.* ]] || ext=""
    [[ $dir == "$path" ]] && dir="."
    
    printf '%s\n' "$dir" "$base" "$name" "$ext"
}

# Usage
read -r dir base name ext < <(split_path "/path/to/file.txt")
```

### Check file type
```bash
# These use test command (built-in)
[[ -f file ]]    # Regular file
[[ -d file ]]    # Directory
[[ -L file ]]    # Symlink
[[ -b file ]]    # Block device
[[ -c file ]]    # Character device
[[ -p file ]]    # Named pipe
[[ -S file ]]    # Socket
[[ -e file ]]    # Exists
```

### File permissions
```bash
[[ -r file ]]    # Readable
[[ -w file ]]    # Writable
[[ -x file ]]    # Executable
[[ -s file ]]    # Size > 0
[[ -O file ]]    # Owned by effective user
[[ -G file ]]    # Owned by effective group
[[ -N file ]]    # Modified since last read
```

## File Creation

### Create empty file (touch)
```bash
>file
:>file
echo -n >file
printf '' >file
```

### Create with content
```bash
cat > file << 'EOF'
Line 1
Line 2
EOF

# Or
cat << 'EOF' > file
Line 1
Line 2
EOF
```

### Create directories (mkdir -p)
```bash
# Pure Bash can't create directories
# Use external mkdir or loop with test
mkdir_p() {
    local dir=$1
    local parent=${dir%/*}
    
    [[ -d $dir ]] && return 0
    [[ $parent != "$dir" ]] && mkdir_p "$parent"
    command mkdir "$dir"
}
```

## File Iteration

### Iterate files (no ls)
```bash
# Current directory
for file in *; do
    [[ -e $file ]] || continue  # Handle empty directory
    echo "$file"
done

# Specific directory
for file in /path/to/dir/*; do
    [[ -e $file ]] || continue
    echo "$file"
done

# Specific extension
for file in *.txt; do
    [[ -e $file ]] || continue
    echo "$file"
done
```

### Iterate directories only
```bash
for dir in /path/*/; do
    [[ -e $dir ]] || continue
    echo "$dir"
done
```

### Recursive iteration (Bash 4+)
```bash
shopt -s globstar
for file in /path/**/*; do
    [[ -e $file ]] || continue
    echo "$file"
done
shopt -u globstar
```

### With sorting
```bash
# Bash 4+
shopt -s globstar
readarray -d '' files < <(printf '%s\0' /path/**/* 2>/dev/null | sort -z)
for file in "${files[@]}"; do
    [[ -e $file ]] || continue
    echo "$file"
done
shopt -u globstar
```

## File Counting

### Count files
```bash
# All files in directory
count_files() {
    set -- "$1"/*
    echo "$#"
}

# Specific pattern
count_txt() {
    set -- "$1"/*.txt
    echo "$#"
}

# Directories only
count_dirs() {
    set -- "$1"/*/
    echo "$#"
}
```

## File Comparisons

### Compare modification times
```bash
# file1 newer than file2
[[ file1 -nt file2 ]]

# file1 older than file2
[[ file1 -ot file2 ]]

# Same inode (hard links)
[[ file1 -ef file2 ]]
```

## File Size

### Get file size (requires stat)
```bash
# Pure Bash can't get file size
# Must use external command
file_size() {
    command stat -f%z "$1" 2>/dev/null ||  # macOS
    command stat -c%s "$1"                 # Linux
}
```

### Check if empty
```bash
[[ -s file ]] || echo "File is empty"

# Or
if [[ ! -s file ]]; then
    echo "File is empty or doesn't exist"
fi
```

## Temporary Files

### Create temp file (mktemp)
```bash
# Pure Bash approximation
temp_file() {
    local tmp="/tmp/tmp.${RANDOM}.${RANDOM}"
    while [[ -e $tmp ]]; do
        tmp="/tmp/tmp.${RANDOM}.${RANDOM}"
    done
    touch "$tmp"
    echo "$tmp"
}

# With cleanup trap
cleanup() {
    [[ $tmp_file ]] && rm -f "$tmp_file"
}
trap cleanup EXIT
tmp_file=$(temp_file)
```

## File Searching

### Find files by name pattern
```bash
# Requires globstar (Bash 4+)
shopt -s globstar
for file in **/*.txt; do
    [[ -e $file ]] || continue
    echo "$file"
done
shopt -u globstar
```

### Find files by content (grep alternative)
```bash
# Search in files
search_files() {
    local pattern=$1
    shift
    for file in "$@"; do
        [[ -f $file ]] || continue
        while IFS= read -r line; do
            [[ $line == *$pattern* ]] && printf '%s: %s\n' "$file" "$line"
        done < "$file"
    done
}
```

## File Operations Summary

| Operation | Pure Bash | Limitation |
|-----------|-----------|------------|
| Read file | `$(<file)` | Whole file in memory |
| Read lines | `mapfile -t` | Bash 4+ |
| Line count | Loop or mapfile | Memory intensive |
| First N | `mapfile -tn N` | Bash 4+ |
| Last N | Array slicing | Bash 4+ |
| Directory | `${path%/*}` | Works for simple cases |
| Basename | `${path##*/}` | Works for simple cases |
| Touch | `>file` | Creates empty file |
| Iterate | `for f in *` | No sorting |
| Recursive | `**/*` | Bash 4+ with globstar |
| Size | Not possible | Requires stat |
| Mkdir | Not possible | Requires mkdir |
| Chmod | Not possible | Requires chmod |
| Copy | Not possible | Requires cp |
| Move | Not possible | Requires mv |
| Remove | Not possible | Requires rm |

## Performance Tips

1. **Avoid cat** - Use `$(<file)` instead of `$(cat file)`
2. **Use mapfile** - Faster than read loops (Bash 4+)
3. **Avoid ls** - Use globs directly
4. **Batch operations** - Process files in batches to reduce fork overhead
5. **Use built-in test** - `[[ -f file ]]` not `[ -f file ]`
6. **Minimize loops** - Use parameter expansion when possible

## Common Patterns

### Process files safely
```bash
# Handle spaces in filenames
for file in *.txt; do
    [[ -e $file ]] || continue
    process_file "$file"
done

# Or with find (not pure)
while IFS= read -r -d '' file; do
    process_file "$file"
done < <(find . -name '*.txt' -print0)
```

### Read config file
```bash
while IFS='=' read -r key value; do
    [[ $key =~ ^[[:space:]]*# ]] && continue  # Skip comments
    [[ -z $key ]] && continue                  # Skip empty lines
    # Remove leading/trailing whitespace
    key=$(trim "$key")
    value=$(trim "$value")
    config[$key]=$value
done < "config.txt"
```

### Safe file write
```bash
# Write to temp then move
write_file() {
    local file=$1
    local content=$2
    local tmp="${file}.tmp.$$"
    
    printf '%s' "$content" > "$tmp" || return 1
    command mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
}
```
