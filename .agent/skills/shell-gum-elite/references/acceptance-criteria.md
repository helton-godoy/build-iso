# Acceptance Criteria: shell-gum-elite

**SDK/Tooling Focus**: Bash + Gum CLI + ShellCheck + Bats
**Purpose**: Validate that generated scripts prioritize pure Bash logic and premium Gum UX.

---

## 1. Foundation Safety

### 1.1 Strict mode present

#### CORRECT
```bash
#!/usr/bin/env bash
set -euo pipefail
```

#### INCORRECT
```bash
#!/bin/bash
set +e
```

### 1.2 Safe quoting

#### CORRECT
```bash
printf '%s\n' "${value}"
```

#### INCORRECT
```bash
echo $value
```

---

## 2. Pure Bash Preference

### 2.1 String length uses parameter expansion

#### CORRECT
```bash
len="${#value}"
```

#### INCORRECT
```bash
len="$(echo "$value" | wc -c)"
```

### 2.2 Arithmetic uses native expansion

#### CORRECT
```bash
((retries+=1))
```

#### INCORRECT
```bash
retries="$(expr "$retries" + 1)"
```

---

## 3. Gum Interaction Quality

### 3.1 User decisions are explicit

#### CORRECT
```bash
target="$(gum choose dev stage prod)"
gum confirm "Deploy to ${target}?" || exit 0
```

#### INCORRECT
```bash
target="prod"
deploy_now
```

### 3.2 Long operations show feedback

#### CORRECT
```bash
gum spin --title "Deploying..." -- ./deploy.sh
```

#### INCORRECT
```bash
./deploy.sh
```

---

## 4. Architecture and Diagnostics

### 4.1 Structured logging present

#### CORRECT
```bash
gum log --level info "Backup completed"
```

#### INCORRECT
```bash
echo "done"
```

### 4.2 Cleanup trap configured

#### CORRECT
```bash
cleanup() { local code=$?; exit "$code"; }
trap cleanup EXIT INT TERM
```

#### INCORRECT
```bash
# no trap configured
```

---

## 5. Forbidden Patterns

- Hardcoded credentials/tokens.
- `eval` for avoidable control flow.
- Unchecked destructive command execution.
- Overuse of external tools for native Bash-capable operations.
