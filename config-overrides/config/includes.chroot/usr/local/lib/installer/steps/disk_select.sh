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

	local raw_disks
	if declare -F disk_select_multi_interactive >/dev/null; then
		raw_disks="$(disk_select_multi_interactive "Selecione o(s) disco(s) de DADOS:")"
	else
		# Fallback crítico se a lib não tiver suporte (improvável)
		raw_disks="$(ui_input "Disco alvo (ex: /dev/nvme0n1):" "/dev/nvme0n1")"
	fi

	local -a selected_disks
	mapfile -t selected_disks < <(printf '%s\n' "$raw_disks" | sed '/^$/d')

	if [[ "${#selected_disks[@]}" -eq 0 ]]; then
		ui_error "Pelo menos um disco é obrigatório."
		return 1
	fi

	local count="${#selected_disks[@]}"
	if [[ "$count" -gt 1 ]]; then
		# Validação simples de tamanho/tipo (aviso apenas)
		local first_size=""
		local first_dev="${selected_disks[0]}"
		first_size=$(lsblk -d -n -b -o SIZE "$first_dev" 2>/dev/null || echo "0")
		
		local mismatch_found="0"
		local d
		for d in "${selected_disks[@]:1}"; do
			local s
			s=$(lsblk -d -n -b -o SIZE "$d" 2>/dev/null || echo "0")
			# Diferença > 10%
			local diff=$(( first_size - s ))
			if [[ "${diff#-}" -gt $(( first_size / 10 )) ]]; then
				mismatch_found="1"
				break
			fi
		done

		if [[ "$mismatch_found" == "1" ]]; then
			ui_card "Atenção: Discos Heterogêneos" \
				"  $UI_WARN Detectamos discos com diferença significativa de tamanho." \
				"  Isso limitará o pool ao tamanho do menor disco."
			if ! ui_confirm "Deseja continuar mesmo assim?" "Sim, continuar" "Não, reescolher"; then
				return 0 # Retorna ao início do loop do passo (router re-executa se retornar 0/false? não, router avança se true. Se retornar 0, router avança? Não, o router verifica retorno de step_invoke. Se 0, avança.)
				# O router espera retorno 0 para sucesso. Retorno 1 para erro.
				# Se eu retornar 0, ele avança. Se eu quiser ficar no step, preciso falhar ou controlar o loop?
				# O router main_loop: if step_invoke returns 0 (true), goto_next.
				# Então para FICAR no step, eu teria que... na verdade o router do bash não tem "ficar no step". Ele avança ou recua.
				# O ideal é chamar recursivamente ou retornar 1 (erro) e o router lida?
				# Na implementação original: main_loop chama step_invoke. Se falhar (!), ele tenta goto_prev. Se goto_prev falhar, morre.
				# Então retornar 1 faz voltar. Isso é bom.
				return 1
			fi
		fi
	fi

	local primary_disk
	primary_disk="$(sanitize_ws "${selected_disks[0]}")"
	if [[ -z "$primary_disk" ]]; then
		ui_error "Disco primário inválido."
		return 1
	fi

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
}
