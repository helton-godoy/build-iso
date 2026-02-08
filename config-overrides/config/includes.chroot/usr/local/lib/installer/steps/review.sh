#!/usr/bin/env bash
step_review() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Revisão"
	ui_guidance \
		"Revisar tudo que será aplicado no servidor" \
		"Esta confirmação inicia ações destrutivas nos discos selecionados" \
		"Confirme somente após validar discos, topologia e nome do pool" \
		"Houver qualquer dúvida sobre impacto em produção"

	local hn user disk strat topo pool comp
	local disks_csv
	hn="$(sanitize_ws "${install_hostname-}")"
	user="$(sanitize_ws "${install_username-}")"
	disk="$(sanitize_ws "${install_disk-}")"
	disks_csv="$(sanitize_ws "${install_disks-}")"
	strat="$(sanitize_ws "${install_zfs_strategy-}")"
	topo="$(sanitize_ws "${zfs_topology-}")"
	pool="$(sanitize_ws "${zfs_pool_name-}")"
	comp="$(sanitize_ws "${zfs_compression-}")"
	local data_vdevs
	data_vdevs="$(sanitize_ws "$(state_kv_get install_plan_data_vdevs)")"
	local aux_log aux_cache aux_special aux_dedup aux_spare
	aux_log="$(sanitize_ws "$(plan_get_aux_disks log)")"
	aux_cache="$(sanitize_ws "$(plan_get_aux_disks cache)")"
	aux_special="$(sanitize_ws "$(plan_get_aux_disks special)")"
	aux_dedup="$(sanitize_ws "$(plan_get_aux_disks dedup)")"
	aux_spare="$(sanitize_ws "$(plan_get_aux_disks spare)")"
	local impact_aux=""
	[[ -n "$aux_log" ]] && impact_aux+="log=latência de escrita síncrona; "
	[[ -n "$aux_cache" ]] && impact_aux+="cache=acelera leitura; "
	[[ -n "$aux_special" ]] && impact_aux+="special=metadados/blocos pequenos; "
	[[ -n "$aux_dedup" ]] && impact_aux+="dedup=DDT dedicada; "
	[[ -n "$aux_spare" ]] && impact_aux+="spare=reserva para falha; "
	impact_aux="${impact_aux%; }"

	local disks_label
	disks_label="${disk:-"(não definido)"}"
	if [[ -n "$disks_csv" ]]; then
		disks_label="$disks_csv"
	fi

	ui_card "Resumo" \
		"  Sistema:       Debian 13 (trixie)" \
		"  Hostname:      ${hn:-"(não definido)"}" \
		"  Usuário:       ${user:-"(não definido)"}" \
		"  Disco(s):      ${disks_label}" \
		"  ZFS:           strategy=${strat:-"(não definido)"} topo=${topo:-"-"} pool=${pool:-"-"} comp=${comp:-"-"}" \
		"  VDEVs dados:   ${data_vdevs:-"(auto por topologia)"}" \
		"  AUX log:       ${aux_log:-"(não configurado)"}" \
		"  AUX cache:     ${aux_cache:-"(não configurado)"}" \
		"  AUX special:   ${aux_special:-"(não configurado)"}" \
		"  AUX dedup:     ${aux_dedup:-"(não configurado)"}" \
		"  AUX spare:     ${aux_spare:-"(não configurado)"}" \
		"  Impacto AUX:   ${impact_aux:-"(sem vdevs auxiliares configurados)"}"

	state_kv_set "install_plan_review_sig" "$(plan_signature)" || return 1
	state_kv_set "install_plan_review_step" "review" || return 1

	if ui_confirm "Iniciar instalação agora?" "Instalar" "Voltar"; then
		return 0
	fi
	goto_prev || true
}
