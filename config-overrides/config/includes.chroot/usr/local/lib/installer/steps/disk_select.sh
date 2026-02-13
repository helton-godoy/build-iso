#!/usr/bin/env bash
# @INST_STEP_ID: disk_select
# @INST_STEP_FLOW: prev=admin_policy, next=disk_wipe_confirm
# @INST_STATE: install_disk, install_disks, install_plan_selected_disks
# @INST_TODO: Melhorar validação de discos já em uso por outros pools.
step_disk_select() {
  ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
  ui_section "Disco de Destino"
  ui_guidance \
    "Selecione TODOS os discos que farão parte do pool de DADOS (rpool)." \
    "Discos auxiliares (Cache/Log/Spare) devem ser selecionados NA PRÓXIMA ETAPA." \
    "Todos os discos selecionados serão APAGADOS." \
    "Recomendamos discos de mesmo tamanho e tipo para o pool de dados."
  ui_card "Aviso" \
    "  $UI_WARN Múltiplos discos: O instalador oferecerá Mirror/RAIDZ." \
    "  $UI_BULLET Espaço marca disco • Enter confirma" \
    "  $UI_BULLET Se houver apenas 1 disco, será configurado como Stripe."

  if [[ -f "${LIBS_DIR}/disk-utils.sh" ]]; then
    source "${LIBS_DIR}/disk-utils.sh"
  fi
  if [[ -f "${LIBS_DIR}/install-plan-utils.sh" ]]; then
    source "${LIBS_DIR}/install-plan-utils.sh"
  fi

  local raw_disks
  local ret
  local -a selected_disks
  local primary_disk

  while true; do
    selected_disks=()
    if declare -F disk_select_multi_interactive >/dev/null; then
      raw_disks=""
      ret=0
      raw_disks="$(disk_select_multi_interactive "Selecione o(s) disco(s) de DADOS:")" || ret=$?

      if [[ "$ret" -eq 1 ]]; then
        ui_error "Seleção cancelada" "A seleção de discos foi cancelada." "Selecione ao menos um disco para continuar."
        log_line "WARN" "disk_select: seleção cancelada pelo usuário; repetindo step"
        continue
      elif [[ "$ret" -eq 2 ]]; then
        ui_error "Seleção Obrigatória" "Nenhum disco selecionado." "Use a tecla TAB para marcar os discos antes de confirmar."
        log_line "WARN" "disk_select: seleção vazia; repetindo step"
        continue
      fi
    else
      ui_error "Erro Interno" "Função 'disk_select_multi_interactive' não encontrada. Usando modo manual."
      raw_disks="$(ui_input "Disco alvo (ex: /dev/nvme0n1):" "/dev/nvme0n1")"
    fi

    mapfile -t selected_disks < <(printf '%s\n' "$raw_disks" | sed '/^$/d')
    if [[ "${#selected_disks[@]}" -eq 0 ]]; then
      ui_error "Pelo menos um disco é obrigatório."
      log_line "WARN" "disk_select: lista de discos vazia após parse; repetindo step"
      continue
    fi

    local count="${#selected_disks[@]}"
    if [[ "$count" -gt 1 ]]; then
      local first_size=""
      local first_dev="${selected_disks[0]}"
      first_size=$(lsblk -d -n -b -o SIZE "$first_dev" 2>/dev/null || echo "0")

      local mismatch_found="0"
      local d
      for d in "${selected_disks[@]:1}"; do
        local s
        s=$(lsblk -d -n -b -o SIZE "$d" 2>/dev/null || echo "0")
        local diff=$((first_size - s))
        if [[ "${diff#-}" -gt $((first_size / 10)) ]]; then
          mismatch_found="1"
          break
        fi
      done

      if [[ "$mismatch_found" == "1" ]]; then
        ui_card "Atenção: Discos Heterogêneos" \
          "  $UI_WARN Detectamos discos com diferença significativa de tamanho." \
          "  Isso limitará o pool ao tamanho do menor disco."
        if ! ui_confirm "Deseja continuar mesmo assim?" "Sim, continuar" "Não, reescolher"; then
          log_line "INFO" "disk_select: usuário escolheu re-selecionar após alerta de discos heterogêneos"
          continue
        fi
      fi
    fi

    primary_disk="$(sanitize_ws "${selected_disks[0]}")"
    if [[ -z "$primary_disk" ]]; then
      ui_error "Disco primário inválido."
      log_line "WARN" "disk_select: disco primário inválido após sanitização"
      continue
    fi

    break
  done

  local disks_csv
  disks_csv="$(printf '%s,' "${selected_disks[@]}")"
  disks_csv="${disks_csv%,}"
  disks_csv="$(sanitize_ws "$disks_csv")"

  state_kv_set "install_disk" "$primary_disk" || return 1
  state_kv_set "install_disks" "$disks_csv" || return 1
  plan_ensure_version || return 1
  state_kv_set "install_plan_selected_disks" "$disks_csv" || return 1

  # Reset da topologia para evitar estado inconsistente
  state_kv_set "install_plan_data_vdevs" "" || return 1
  state_kv_set "install_plan_aux_log_disks" "" || return 1
  state_kv_set "install_plan_aux_cache_disks" "" || return 1
  state_kv_set "install_plan_aux_special_disks" "" || return 1
  state_kv_set "install_plan_aux_dedup_disks" "" || return 1
  state_kv_set "install_plan_aux_spare_disks" "" || return 1
  log_line "INFO" "disk_select: primary=$primary_disk selected=$disks_csv"
}
