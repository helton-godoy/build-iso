#!/usr/bin/env bash
# @INST_STEP_ID: zfs_auto_datasets
# @INST_STEP_FLOW: prev=zfs_aux_setup, next=boot
# @INST_STATE: zfs_dataset_preset, install_plan_aux_*

_select_aux_disks() {
  local title="$1"
  shift
  local -a options=("$@")
  if [[ "${#options[@]}" -eq 0 ]]; then
    printf '%s' ""
    return 0
  fi
  ui_multiselect "$title" "${options[@]}"
}

step_zfs_auto_datasets() {
  ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
  ui_section "ZFS: Datasets e VDEVs Auxiliares"
  ui_guidance \
    "Escolher preset de datasets e vdevs auxiliares opcionais" \
    "VDEVs auxiliares influenciam desempenho e resiliencia, nao a capacidade principal" \
    "Comece com preset default/server e adicione auxiliares apenas quando necessario" \
    "Nao houver clareza sobre funcao de log/cache/special/dedup/spare"

  local preset
  preset="$(ui_select "Preset de datasets:" "default" "server" "custom")"
  preset="$(sanitize_id "$preset")"
  [[ -z "$preset" ]] && preset="default"
  state_kv_set "zfs_dataset_preset" "$preset" || return 1

  local selected_csv
  selected_csv="$(plan_get_selected_disks_csv)"
  local -a selected=()
  IFS=',' read -r -a selected <<<"$selected_csv"
  local -a aux_candidates=()
  if declare -F disk_list_available >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      aux_candidates+=("$(printf '%s' "$line" | awk '{print $1}')")
    done < <(disk_list_available)
  fi
  if [[ "${#aux_candidates[@]}" -eq 0 ]]; then
    aux_candidates=("${selected[@]}")
  fi
  # Remover discos de dados da lista de candidatos auxiliares
  local -a filtered_aux=()
  local c d skip
  for c in "${aux_candidates[@]}"; do
    skip="0"
    for d in "${selected[@]}"; do
      if [[ "$c" == "$d" ]]; then
        skip="1"
        break
      fi
    done
    if [[ "$skip" == "0" ]]; then
      filtered_aux+=("$c")
    fi
  done

  if [[ "${#selected[@]}" -eq 0 ]]; then
    ui_error "Selecione discos antes de configurar vdevs auxiliares."
    return 1
  fi

  if ! ui_confirm "Deseja configurar vdevs auxiliares?" "Configurar" "Pular"; then
    plan_set_aux_vdev "log" "" "" || return 1
    plan_set_aux_vdev "cache" "" "" || return 1
    plan_set_aux_vdev "special" "" "" || return 1
    plan_set_aux_vdev "dedup" "" "" || return 1
    plan_set_aux_vdev "spare" "" "" || return 1
    return 0
  fi

  local log_layout="" log_csv=""
  if ui_confirm "Adicionar vdev de log (SLOG)?" "Sim" "Não"; then
    log_layout="$(ui_select "Layout do log:" "single" "mirror")"
    log_layout="$(sanitize_id "$log_layout")"
    [[ -z "$log_layout" ]] && log_layout="single"
    log_csv="$(_select_aux_disks "Selecione disco(s) para log:" "${filtered_aux[@]}")"
    log_csv="$(printf '%s' "$log_csv" | tr '\n' ',' | sed 's/,$//')"
  fi
  plan_set_aux_vdev "log" "$log_layout" "$log_csv" || return 1

  local cache_csv=""
  if ui_confirm "Adicionar cache L2ARC?" "Sim" "Não"; then
    cache_csv="$(_select_aux_disks "Selecione disco(s) para cache:" "${filtered_aux[@]}")"
    cache_csv="$(printf '%s' "$cache_csv" | tr '\n' ',' | sed 's/,$//')"
  fi
  plan_set_aux_vdev "cache" "single" "$cache_csv" || return 1

  local special_layout="" special_csv=""
  if ui_confirm "Adicionar vdev special (metadados/blocos pequenos)?" "Sim" "Não"; then
    special_layout="$(ui_select "Layout special:" "single" "mirror")"
    special_layout="$(sanitize_id "$special_layout")"
    [[ -z "$special_layout" ]] && special_layout="single"
    special_csv="$(_select_aux_disks "Selecione disco(s) para special:" "${filtered_aux[@]}")"
    special_csv="$(printf '%s' "$special_csv" | tr '\n' ',' | sed 's/,$//')"
  fi
  plan_set_aux_vdev "special" "$special_layout" "$special_csv" || return 1

  local dedup_layout="" dedup_csv=""
  if ui_confirm "Adicionar vdev dedup (DDT)?" "Sim" "Não"; then
    dedup_layout="$(ui_select "Layout dedup:" "single" "mirror")"
    dedup_layout="$(sanitize_id "$dedup_layout")"
    [[ -z "$dedup_layout" ]] && dedup_layout="single"
    dedup_csv="$(_select_aux_disks "Selecione disco(s) para dedup:" "${filtered_aux[@]}")"
    dedup_csv="$(printf '%s' "$dedup_csv" | tr '\n' ',' | sed 's/,$//')"
  fi
  plan_set_aux_vdev "dedup" "$dedup_layout" "$dedup_csv" || return 1

  local spare_csv=""
  if ui_confirm "Adicionar hot spare(s)?" "Sim" "Não"; then
    spare_csv="$(_select_aux_disks "Selecione disco(s) spare:" "${filtered_aux[@]}")"
    spare_csv="$(printf '%s' "$spare_csv" | tr '\n' ',' | sed 's/,$//')"
  fi
  plan_set_aux_vdev "spare" "single" "$spare_csv" || return 1
}
