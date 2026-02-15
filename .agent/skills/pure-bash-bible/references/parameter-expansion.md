# Parameter Expansion Reference

Complete guide to Bash parameter expansion operators.

## Default Values

### Use default value
```bash
${var:-default}
```
If `var` is empty or unset, use `default`. Does not change `var`.

**Examples:**
```bash
name=${1:-"Anonymous"}
echo "Hello, $name"
```

### Assign default value
```bash
${var:=default}
```
If `var` is empty or unset, set it to `default`.

**Examples:**
```bash
${count:=0}
echo $count  # Now count is 0
```

### Use alternate value
```bash
${var:+alternate}
```
If `var` is not empty, use `alternate`, otherwise empty.

**Examples:**
```bash
debug=${DEBUG:+"--verbose"}
./script $debug  # Only adds --verbose if DEBUG is set
```

### Display error if unset
```bash
${var:?error_message}
```
If `var` is empty or unset, print error and exit.

**Examples:**
```bash
${CONFIG_FILE:?"Error: CONFIG_FILE not set"}
```

## Substring Operations

### Get string length
```bash
${#var}
```

**Examples:**
```bash
str="hello"
echo ${#str}  # 5

arr=(a b c d)
echo ${#arr[@]}  # 4 (array length)
```

### Remove from beginning

#### Shortest match
```bash
${var#pattern}
```

**Examples:**
```bash
path="/home/user/file.txt"
echo ${path#*/}    # home/user/file.txt
echo ${path#/}     # home/user/file.txt
```

#### Longest match
```bash
${var##pattern}
```

**Examples:**
```bash
path="/home/user/file.txt"
echo ${path##*/}   # file.txt (basename)
echo ${path##*.}   # txt (extension)
```

### Remove from end

#### Shortest match
```bash
${var%pattern}
```

**Examples:**
```bash
path="/home/user/file.txt"
echo ${path%/*}    # /home/user (dirname)
echo ${path%.*}    # /home/user/file
```

#### Longest match
```bash
${var%%pattern}
```

**Examples:**
```bash
path="/home/user/file.tar.gz"
echo ${path%%.*}   # /home/user/file
echo ${path%.*}    # /home/user/file.tar
```

## Search and Replace

### Replace first occurrence
```bash
${var/pattern/replacement}
```

**Examples:**
```bash
str="The quick brown fox"
echo ${str/brown/red}      # The quick red fox
echo ${str/ /-}            # The-quick brown fox
```

### Replace all occurrences
```bash
${var//pattern/replacement}
```

**Examples:**
```bash
str="foo bar foo baz"
echo ${str//foo/FOO}       # FOO bar FOO baz
echo ${str// /,}           # foo,bar,foo,baz
```

### Replace at start only
```bash
${var/#pattern/replacement}
```

**Examples:**
```bash
str="/path/to/file"
echo ${str/#\/path\//\/new\/}   # /new/to/file
```

### Replace at end only
```bash
${var/%pattern/replacement}
```

**Examples:**
```bash
str="file.txt"
echo ${str/%.txt/.md}      # file.md
```

### Delete patterns
```bash
${var/pattern}      # Delete first match
${var//pattern}     # Delete all matches
```

**Examples:**
```bash
str="foo bar foo baz"
echo ${str/foo}           # bar foo baz
echo ${str//foo}          # bar  baz
```

## Substring Extraction

### Offset only
```bash
${var:offset}
```
Remove first N characters.

**Examples:**
```bash
str="hello world"
echo ${str:6}             # world
echo ${str: -5}           # world (note space before -)
```

### Offset and length
```bash
${var:offset:length}
```
Extract substring starting at offset with given length.

**Examples:**
```bash
str="hello world"
echo ${str:0:5}           # hello
echo ${str:6:5}           # world
echo ${str: -5:3}         # wor
```

### Negative offset
```bash
${var: -N}         # Last N characters
${var:: -N}        # Remove last N characters
```

**Examples:**
```bash
str="hello world"
echo ${str: -5}           # world
echo ${str:: -6}          # hello
```

### Combined
```bash
${var:offset:-length}
```
Remove first N and last N characters.

**Examples:**
```bash
str="hello beautiful world"
echo ${str:6: -6}         # beautiful
```

## Case Modification (Bash 4+)

### Uppercase
```bash
${var^}             # First character uppercase
${var^^}            # All characters uppercase
```

**Examples:**
```bash
str="hello world"
echo ${var^}              # Hello world
echo ${var^^}             # HELLO WORLD
```

### Lowercase
```bash
${var,}             # First character lowercase
${var,,}            # All characters lowercase
```

**Examples:**
```bash
str="HELLO WORLD"
echo ${var,}              # hELLO WORLD
echo ${var,,}             # hello world
```

### Toggle case
```bash
${var~}             # Toggle first character case
${var~~}            # Toggle all characters case
```

**Examples:**
```bash
str="Hello World"
echo ${var~}              # hello World
echo ${var~~}             # hELLO wORLD
```

### With patterns
```bash
${var^^pattern}     # Uppercase matching characters
${var,,pattern}     # Lowercase matching characters
```

**Examples:**
```bash
str="hello world"
echo ${str^^[aeiou]}      # hEllO wOrld
echo ${str,,[AEIOU]}      # hEllo world
```

## Variable Indirection

### Access variable by name
```bash
${!var}
```

**Examples:**
```bash
greeting="hello"
ref="greeting"
echo ${!ref}              # hello
```

### List variable names
```bash
${!prefix*}         # IFS-separated list
${!prefix@}         # Array of names
```

**Examples:**
```bash
var1=1 var2=2 var3=3
array1=(a b c)
echo ${!var*}             # var1 var2 var3
echo ${!array*}           # array1
```

## Command Names

```bash
${0}                # Script name
${!#}               # Last positional parameter
```

## Quick Reference Table

| Operator | Description |
|----------|-------------|
| `${var:-val}` | Use default value |
| `${var:=val}` | Assign default value |
| `${var:+val}` | Use alternate value |
| `${var:?msg}` | Error if unset |
| `${#var}` | String length |
| `${var:offset}` | Substring from offset |
| `${var:offset:len}` | Substring with length |
| `${var:: -N}` | Remove last N chars |
| `${var: -N}` | Last N chars |
| `${var#pat}` | Remove shortest prefix |
| `${var##pat}` | Remove longest prefix |
| `${var%pat}` | Remove shortest suffix |
| `${var%%pat}` | Remove longest suffix |
| `${var/pat/repl}` | Replace first |
| `${var//pat/repl}` | Replace all |
| `${var/#pat/repl}` | Replace at start |
| `${var/%pat/repl}` | Replace at end |
| `${var^}` | Uppercase first |
| `${var^^}` | Uppercase all |
| `${var,}` | Lowercase first |
| `${var,,}` | Lowercase all |
| `${var~}` | Toggle first |
| `${var~~}` | Toggle all |
| `${!var}` | Variable indirection |
| `${!prefix*}` | List variable names |
