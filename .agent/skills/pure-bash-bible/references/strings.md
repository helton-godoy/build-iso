# String Manipulation

Pure Bash alternatives to external tools like sed, awk, grep, cut, and tr.

## Trimming Whitespace

### Trim leading and trailing
```bash
trim_string() {
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}

# Usage
trim_string "  hello world  "  # "hello world"
```

### Trim all whitespace (normalize)
```bash
# shellcheck disable=SC2086,SC2048
trim_all() {
    set -f
    set -- $*
    printf '%s\n' "$*"
    set +f
}

# Usage
trim_all "  hello    world  "  # "hello world"
```

### Trim leading only
```bash
ltrim() {
    printf '%s\n' "${1#"${1%%[![:space:]]*}"}"
}

# Or simpler
ltrim() {
    printf '%s\n' "${1#"${1%%[![:space:]]*}"}"
}
```

### Trim trailing only
```bash
rtrim() {
    printf '%s\n' "${1%"${1##*[![:space:]]}"}"
}
```

## Case Conversion

### To lowercase (Bash 4+)
```bash
lower() {
    printf '%s\n' "${1,,}"
}

# First character only
lower_first() {
    printf '%s\n' "${1,}"
}
```

### To uppercase (Bash 4+)
```bash
upper() {
    printf '%s\n' "${1^^}"
}

# First character only
upper_first() {
    printf '%s\n' "${1^}"
}
```

### Toggle case (Bash 4+)
```bash
reverse_case() {
    printf '%s\n' "${1~~}"
}

# First character only
toggle_first() {
    printf '%s\n' "${1~}"
}
```

### Case conversion (Bash 3 compatible)
```bash
# Using tr (not pure, but portable)
# For pure Bash 3, loop through characters

lower_compat() {
    local str=$1
    local result=""
    local i char
    for ((i=0; i<${#str}; i++)); do
        char=${str:$i:1}
        case $char in
            [A-Z]) char=$(printf '%d' "'$char")
                    char=$((char + 32))
                    char=$(printf "\\$(printf '%03o' $char)") ;;
        esac
        result+=$char
    done
    printf '%s\n' "$result"
}
```

## Substring Operations

### Contains substring
```bash
# Using [[ ]]
if [[ $str == *substring* ]]; then
    echo "contains"
fi

# Using case
case $str in
    *substring*) echo "contains" ;;
esac

# Using parameter expansion
if [[ ${str/substring/} != "$str" ]]; then
    echo "contains"
fi
```

### Starts with
```bash
if [[ $str == prefix* ]]; then
    echo "starts with prefix"
fi
```

### Ends with
```bash
if [[ $str == *suffix ]]; then
    echo "ends with suffix"
fi
```

### Position of substring
```bash
# Find position of substring
strpos() {
    local str=$1
    local substr=$2
    local prefix=${str%%$substr*}
    [[ $prefix == "$str" ]] && return 1
    printf '%s\n' "${#prefix}"
}

# Usage
strpos "hello world" "world"  # 6
```

### Count occurrences
```bash
count_substr() {
    local str=$1
    local substr=$2
    local count=0
    while [[ $str == *$substr* ]]; do
        str=${str#*$substr}
        ((count++))
    done
    printf '%s\n' "$count"
}
```

## Pattern Stripping

### Remove from start
```bash
str="/path/to/file"

# Remove shortest prefix
${str#*/}        # path/to/file

# Remove longest prefix
${str##*/}       # file
```

### Remove from end
```bash
str="file.txt.bak"

# Remove shortest suffix
${str%.*}        # file.txt

# Remove longest suffix
${str%%.*}       # file
```

### Remove all occurrences
```bash
str="foo bar foo baz"

# Remove all 'foo'
${str//foo/}     # bar  baz

# Remove all spaces
${str// /}       # foobarfoobaz
```

### Remove first occurrence
```bash
str="foo bar foo baz"
${str/foo/}      # bar foo baz
```

## Search and Replace

### Replace first
```bash
${var/pattern/replacement}
```

### Replace all
```bash
${var//pattern/replacement}
```

### Replace at start only
```bash
${var/#pattern/replacement}
```

### Replace at end only
```bash
${var/%pattern/replacement}
```

## Splitting Strings

### Split by delimiter (Bash 4+)
```bash
split() {
    IFS=$'\n' read -d "" -ra arr <<< "${1//$2/$'\n'}"
    printf '%s\n' "${arr[@]}"
}

# Usage
split "a,b,c" ","    # a\nb\nc
```

### Split by delimiter (Bash 3)
```bash
split_compat() {
    local IFS=$2
    set -f
    set -- $1
    printf '%s\n' "$@"
}
```

### Read into array
```bash
str="apples,oranges,bananas"
IFS=',' read -ra fruits <<< "$str"
echo "${fruits[1]}"  # oranges
```

## Padding

### Pad left
```bash
pad_left() {
    printf '%*s' "$2" "$1"
}

# Usage
pad_left "42" 5     # "   42"
```

### Pad left with zeros
```bash
zero_pad() {
    printf '%0*d' "$2" "$1"
}

# Usage
zero_pad 42 5       # "00042"
```

### Pad right
```bash
pad_right() {
    printf '%-*s' "$2" "$1"
}

# Usage
pad_right "42" 5    # "42   "
```

## URL Encoding/Decoding

### URL encode
```bash
urlencode() {
    local LC_ALL=C
    local i c
    for ((i=0; i<${#1}; i++)); do
        c=${1:$i:1}
        case $c in
            [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    printf '\n'
}

# Usage
urlencode "hello world"    # hello%20world
```

### URL decode
```bash
urldecode() {
    : "${1//+/ }"
    printf '%b\n' "${_//%/\\x}"
}

# Usage
urldecode "hello%20world"  # hello world
```

## Base64 (Bash 4+)

### Encode (requires external base64)
```bash
# Pure Bash not practical for base64
# Use built-in if available
base64_encode() {
    printf '%s' "$1" | command base64
}
```

### Decode
```bash
base64_decode() {
    command base64 -d <<< "$1"
}
```

## String Reversal

### Reverse string
```bash
reverse() {
    local str=$1
    local rev=""
    local i
    for ((i=${#str}-1; i>=0; i--)); do
        rev+=${str:$i:1}
    done
    printf '%s\n' "$rev"
}

# Or using parameter expansion (slower)
reverse_alt() {
    local str=$1
    local rev=""
    while [[ $str ]]; do
        rev=${str:0:1}$rev
        str=${str:1}
    done
    printf '%s\n' "$rev"
}
```

## Repeat String

```bash
repeat() {
    local str=$1
    local count=$2
    local result=""
    local i
    for ((i=0; i<count; i++)); do
        result+=$str
    done
    printf '%s\n' "$result"
}

# Or using printf
repeat_printf() {
    printf '%*s' "$2" | tr ' ' "$1"
}
```

## Quote Handling

### Strip quotes
```bash
trim_quotes() {
    : "${1//\'/'"
    printf '%s\n' "${_//\"/'"
}

# Usage
trim_quotes '"hello"'     # hello
trim_quotes "'hello'"     # hello
```

### Add quotes if needed
```bash
quote() {
    local str=$1
    if [[ $str == *' '* || $str == *$'\t'* ]]; then
        printf '"%s"\n' "$str"
    else
        printf '%s\n' "$str"
    fi
}
```

## Regex Operations

### Match regex
```bash
if [[ $str =~ ^[0-9]+$ ]]; then
    echo "is a number"
fi
```

### Extract with regex
```bash
regex_extract() {
    [[ $1 =~ $2 ]] && printf '%s\n' "${BASH_REMATCH[1]}"
}

# Usage
regex_extract "file.txt" "^([^.]+)"   # file
```

### Validate patterns
```bash
is_integer() {
    [[ $1 =~ ^-?[0-9]+$ ]]
}

is_float() {
    [[ $1 =~ ^-?[0-9]*\.?[0-9]+$ ]]
}

is_hex() {
    [[ $1 =~ ^(0x)?[0-9a-fA-F]+$ ]]
}

is_email() {
    [[ $1 =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}
```

## Template Substitution

### Simple templating
```bash
template() {
    local tmpl=$1
    local key val
    shift
    while [[ $1 ]]; do
        key=$1
        val=$2
        tmpl=${tmpl//\{$key\}/$val}
        shift 2
    done
    printf '%s\n' "$tmpl"
}

# Usage
template "Hello, {name}!" "name" "World"   # Hello, World!
```

## Length Operations

### String length
```bash
${#str}
```

### Length without spaces
```bash
len_no_spaces() {
    local str=${1// /}
    printf '%s\n' "${#str}"
}
```

## Quick Reference Table

| Operation | Pure Bash | External Tool |
|-----------|-----------|---------------|
| Trim | `${var#...}` | `sed 's/^ *//;s/ *$//'` |
| Case change | `${var,,}` | `tr '[:upper:]' '[:lower:]'` |
| Substring | `${var:3:5}` | `cut -c4-8` |
| Replace | `${var//a/b}` | `sed 's/a/b/g'` |
| Remove | `${var//pattern/}` | `sed '/pattern/d'` |
| Contains | `[[ $v == *sub* ]]` | `grep -q` |
| Starts with | `[[ $v == pre* ]]` | `grep '^pre'` |
| Ends with | `[[ $v == *suf ]]` | `grep 'suf$'` |
| Length | `${#var}` | `wc -c` |
| Split | `IFS=',' read -ra` | `cut -d','` |
| Reverse | Loop | `rev` |
