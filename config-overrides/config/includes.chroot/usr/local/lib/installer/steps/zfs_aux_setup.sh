#!/usr/bin/env bash
# @INST_STEP_ID: zfs_aux_setup
# @INST_STEP_FLOW: prev=zfs_auto_properties, next=zfs_auto_datasets
# @INST_STATE: install_plan_aux_log_disks, install_plan_aux_cache_disks, install_plan_aux_special_disks, install_plan_aux_dedup_disks, install_plan_aux_spare_disks

step_zfs_aux_setup() {
  ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
  ui_section "Discos Auxiliares"
  ui_guidance \
    "Configurar dispositivos adicionais para performance e segurança" \
    "Log (SLOG): Acelera escritas síncronas | Special: Metadados e blocos pequenos" \
    "Cache (L2ARC): Estende RAM para leitura | Spare: Disco reserva automático" \
    "Dedup: NÃO RECOMENDADO — impacto severo em RAM (consulte docs/00_SOURCE_OF_TRUTH.md)"

  local data_disks
  data_disks="$(state_kv_get "install_disks")"

  # Current usage map to exclude already selected disks
  local current_exclude="$data_disks"

  # Helper to check availability
  _has_available() {
    local av
    av="$(disk_list_available_excluding "$current_exclude")"
    [[ -n "$av" ]]
  }

  if ! _has_available; then
    ui_card "Nenhum disco disponível" \
      "  Todos os discos foram alocados para DADOS." \
      "  Não é possível adicionar Cache/Log/Spare."
    sleep 2
    return 0
  fi

  if ! ui_confirm "Deseja configurar dispositivos auxiliares?" "Sim" "Não, pular"; then
    return 0
  fi

  # 1. LOG (SLOG)
  if _has_available; then
    if ui_confirm "Adicionar dispositivo de LOG (SLOG)?" "Sim" "Não"; then
      local log_devs
      log_devs="$(disk_select_multi_interactive_excluding "Selecione disco(s) para LOG:" "$current_exclude")"
      if [[ -n "$log_devs" ]]; then
        # Format to CSV
        local log_csv
        log_csv="$(printf '%s' "$log_devs" | tr '\n' ',' | sed 's/,$//')"
        state_kv_set "install_plan_aux_log_disks" "$log_csv" || return 1
        current_exclude="${current_exclude},${log_csv}"
      fi
    fi
  fi

  # 2. CACHE (L2ARC)
  if _has_available; then
    if ui_confirm "Adicionar dispositivo de CACHE (L2ARC)?" "Sim" "Não"; then
      local cache_devs
      cache_devs="$(disk_select_multi_interactive_excluding "Selecione disco(s) para CACHE:" "$current_exclude")"
      if [[ -n "$cache_devs" ]]; then
        local cache_csv
        cache_csv="$(printf '%s' "$cache_devs" | tr '\n' ',' | sed 's/,$//')"
        state_kv_set "install_plan_aux_cache_disks" "$cache_csv" || return 1
        current_exclude="${current_exclude},${cache_csv}"
      fi
    fi
  fi

  # 3. SPARE
  if _has_available; then
    if ui_confirm "Adicionar disco de SPARE (Reserva)?" "Sim" "Não"; then
      local spare_devs
      spare_devs="$(disk_select_multi_interactive_excluding "Selecione disco(s) para SPARE:" "$current_exclude")"
      if [[ -n "$spare_devs" ]]; then
        local spare_csv
        spare_csv="$(printf '%s' "$spare_devs" | tr '\n' ',' | sed 's/,$//')"
        state_kv_set "install_plan_aux_spare_disks" "$spare_csv" || return 1
        current_exclude="${current_exclude},${spare_csv}"
      fi
    fi
  fi

  # 4. SPECIAL (metadados e blocos pequenos)
  if _has_available; then
    if ui_confirm "Adicionar dispositivo SPECIAL (metadados/blocos pequenos)?" "Sim" "Não"; then
      local special_devs
      special_devs="$(disk_select_multi_interactive_excluding "Selecione disco(s) para SPECIAL:" "$current_exclude")"
      if [[ -n "$special_devs" ]]; then
        local special_csv
        special_csv="$(printf '%s' "$special_devs" | tr '\n' ',' | sed 's/,$//')"
        state_kv_set "install_plan_aux_special_disks" "$special_csv" || return 1
        current_exclude="${current_exclude},${special_csv}"
      fi
    fi
  fi

  # 5. DEDUP (AVANÇADO - com aviso explícito)
  if _has_available; then
    ui_card "⚠️  DEDUP - Recurso Avançado" \
      "  A deduplicação consome MUITA memória RAM." \
      "  Regra prática: cada TB de dados dedup = ~5GB RAM adicional." \
      "  Recomendamos usar apenas com planejamento cuidadoso."
    if ui_confirm "Tem certeza que deseja adicionar dispositivo DEDUP?" "Sim, entendo os riscos" "Não, pular"; then
      local dedup_devs
      dedup_devs="$(disk_select_multi_interactive_excluding "Selecione disco(s) para DEDUP:" "$current_exclude")"
      if [[ -n "$dedup_devs" ]]; then
        local dedup_csv
        dedup_csv="$(printf '%s' "$dedup_devs" | tr '\n' ',' | sed 's/,$//')"
        state_kv_set "install_plan_aux_dedup_disks" "$dedup_csv" || return 1
        current_exclude="${current_exclude},${dedup_csv}"
      fi
    fi
  fi
}

# Helper local wrapper for exclusion interactive select
disk_select_multi_interactive_excluding() {
  local prompt="$1"
  local exclude="$2"

  local disks
  disks=$(disk_list_available_excluding "$exclude")

  if [[ -z "$disks" ]]; then
    return 1
  fi

  # Use standard gum choose via same style as disk-utils but using the filtered list
  # Since disk_select_multi_interactive in disk-utils calls disk_list_available internally,
  # we need to replicate the gum call here or modify disk-utils to accept a list.
  # Accessing internal logic of disk-utils/gum here to allow passing the list.

  gum style --foreground "${DS_CLOUD:-250}" "$prompt" >&2
  gum style --foreground "${DS_FOG:-245}" --italic "  ${UI_ARROW:-▶} Espaço marca • Enter confirma" >&2
  echo "" >&2

  local selected
  selected=$(echo "$disks" | gum choose \
    --height 8 \
    --show-help \
    --no-limit \
    --cursor "${UI_ARROW:-▶} " \
    --selected-prefix "[${UI_BULLET:-●}] " \
    --unselected-prefix "[ ] " \
    --cursor-prefix "[ ] " \
    --cursor.foreground "${DS_FILESERVER_PEAK:-153}" \
    --item.foreground "${DS_CLOUD:-250}" \
    --selected.foreground "${DS_SILVER:-252}" \
    --selected.background "${DS_ELEVATION:-239}")

  if [[ -z "$(sanitize_ws "$selected")" ]]; then
    return 1
  fi

  local -a sel_array
  mapfile -t sel_array < <(
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      _disk_extract_device "$line"
    done <<<"$selected"
  )

  printf '%s\n' "${sel_array[@]}"
}
