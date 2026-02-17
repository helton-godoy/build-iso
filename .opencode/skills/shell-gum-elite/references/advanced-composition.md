# Advanced Gum Composition

## Objective

Patterns for rich, multi-component terminal interfaces using Gum composition
primitives (`gum join`, `gum style`, `gum progress`, `gum table`).

## Progress Bars

### Known-count iteration

```bash
process_items() {
  local items=("$@")
  local total="${#items[@]}"

  for i in "${!items[@]}"; do
    process_one "${items[$i]}"
    echo "$(( (i + 1) * 100 / total ))"
  done | gum progress --title "Processing items..."
}
```

### Streaming progress from a command

```bash
# Pipe percentage values (0-100) to gum progress
download_with_progress() {
  local url="$1"
  curl -# -o output.tar.gz "${url}" 2>&1 \
    | stdbuf -oL tr '\r' '\n' \
    | grep -oP '[0-9]+(?=\.[0-9])' \
    | gum progress --title "Downloading..."
}
```

### Multi-step progress (manual)

```bash
run_pipeline() {
  local steps=("Validating" "Building" "Testing" "Deploying")
  local total="${#steps[@]}"

  for i in "${!steps[@]}"; do
    gum spin --title "[$(( i + 1 ))/${total}] ${steps[$i]}..." -- "step_${steps[$i],,}"
    log_info "[$(( i + 1 ))/${total}] ${steps[$i]} ✓"
  done
}
```

## Wizard / Multi-Step Flow

### With header progress indicator

```bash
wizard_header() {
  local current="$1"
  local total="$2"
  local title="$3"

  local bar=""
  for ((i = 1; i <= total; i++)); do
    if (( i < current )); then
      bar+="●"
    elif (( i == current )); then
      bar+="◉"
    else
      bar+="○"
    fi
    (( i < total )) && bar+="─"
  done

  gum style \
    --foreground "#8ECAE6" \
    --border rounded \
    --border-foreground "#FFB703" \
    --padding "0 2" \
    --bold \
    "${bar}  ${title}"
}

run_wizard() {
  local total=3

  # Step 1
  wizard_header 1 "${total}" "Environment"
  local env
  env="$(gum choose --header "Select target" dev stage prod)"

  # Step 2
  wizard_header 2 "${total}" "Version"
  local version
  version="$(gum input --placeholder "1.0.0")"

  # Step 3
  wizard_header 3 "${total}" "Confirmation"
  local summary
  summary="$(gum style --padding "1 2" \
    "Environment: ${env}" \
    "Version:     ${version}")"
  printf '%s\n' "${summary}"
  gum confirm "Deploy?" || exit 0
}
```

## Dashboard with gum join

### Horizontal layout

```bash
dashboard_status() {
  local box_services
  box_services="$(gum style \
    --border rounded \
    --border-foreground "#2A9D8F" \
    --padding "1 2" \
    --width 30 \
    "SERVICES" "" \
    "[OK] API Server" \
    "[OK] Database" \
    "[!!] Queue Worker")"

  local box_metrics
  box_metrics="$(gum style \
    --border rounded \
    --border-foreground "#8ECAE6" \
    --padding "1 2" \
    --width 30 \
    "METRICS" "" \
    "CPU:    42%" \
    "Memory: 67%" \
    "Disk:   23%")"

  gum join --horizontal "${box_services}" "${box_metrics}"
}
```

### Vertical stacking

```bash
dashboard_full() {
  local header
  header="$(gum style \
    --foreground "#FFB703" \
    --bold \
    --align center \
    --width 62 \
    "═══ System Dashboard ═══")"

  local body
  body="$(dashboard_status)"

  gum join --vertical "${header}" "${body}"
}
```

## Dynamic Tables

### From command output

```bash
show_disk_usage() {
  {
    printf 'Mount,Size,Used,Avail,Use%%\n'
    df -h --output=target,size,used,avail,pcent 2>/dev/null \
      | tail -n +2 \
      | awk '{printf "%s,%s,%s,%s,%s\n", $1, $2, $3, $4, $5}'
  } | gum table --separator ","
}
```

### From arrays

```bash
show_task_status() {
  local csv="Task,Status,Duration\n"
  csv+="Build,Done,12s\n"
  csv+="Test,Running,--\n"
  csv+="Deploy,Pending,--\n"
  printf '%b' "${csv}" | gum table --separator ","
}
```

## File Picker with Validation

```bash
pick_config_file() {
  local start_dir="${1:-.}"
  local file

  while :; do
    file="$(gum file --all "${start_dir}")"

    # Validate extension
    case "${file}" in
      *.yaml|*.yml|*.json|*.toml|*.conf)
        break
        ;;
      *)
        log_warn "Invalid file type: ${file##*.} (expected: yaml, json, toml, conf)"
        gum confirm "Try again?" || exit 0
        ;;
    esac
  done

  printf '%s\n' "${file}"
}
```

## Pipe / Stdin Integration

### Detect and adapt

```bash
read_input() {
  local prompt="${1:-Enter data}"

  if [[ ! -t 0 ]]; then
    # Reading from pipe
    cat
  elif is_interactive; then
    gum write --header "${prompt}" --placeholder "Type or paste content..."
  else
    die "No input available (not a pipe and not interactive)"
  fi
}

# Usage:
# echo "data" | ./script.sh            # Pipe mode
# ./script.sh                           # Interactive mode (gum write)
# ENV_VAR=x ./script.sh < input.txt     # File redirect mode
```

### Process piped list with gum filter

```bash
interactive_select() {
  if [[ ! -t 0 ]]; then
    # Pipe input to gum filter for interactive selection
    gum filter --placeholder "Search..."
  else
    die "Pipe a list to this command"
  fi
}

# Usage: find . -name "*.sh" | ./script.sh interactive_select
```

## Composition Best Practices

1. Use `--width` consistently to ensure alignment in `gum join`.
2. Keep box content under 40 characters wide for side-by-side layout.
3. Use `gum join --vertical` for stacking header + body + footer.
4. Cache rendered boxes in variables before joining.
5. Test layouts in narrower terminals (80 columns minimum).
6. Provide plain-text fallbacks for non-interactive contexts.
