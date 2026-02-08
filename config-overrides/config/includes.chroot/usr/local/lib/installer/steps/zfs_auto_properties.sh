#!/usr/bin/env bash
step_zfs_auto_properties() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "ZFS: Propriedades"
	ui_guidance \
		"Ajustar comportamento de compressão e memória (ARC)" \
		"Configurações agressivas podem afetar desempenho e uso de RAM" \
		"Use zstd e dedup desativado, salvo necessidade comprovada" \
		"Não houver benchmark/monitoramento para validar impacto"

	local comp dedup arc_mode arc_max
	comp="$(ui_select "Compressão:" "zstd" "lz4")"
	comp="$(sanitize_id "$comp")"
	if [[ -z "$comp" ]]; then
		comp="zstd"
	fi

	if ui_confirm "Ativar deduplicação?" "Ativar" "Desativar"; then
		dedup="1"
	else
		dedup="0"
	fi

	if ui_confirm "Definir ARC máximo?" "Definir" "Automático"; then
		arc_mode="custom"
		arc_max="$(ui_input "ARC máximo (ex: 4G):" "4G")"
		arc_max="$(sanitize_ws "$arc_max")"
		if [[ -z "$arc_max" ]]; then
			arc_max="4G"
		fi
	else
		arc_mode="auto"
		arc_max=""
	fi

	state_kv_set "zfs_compression" "$comp" || return 1
	state_kv_set "zfs_dedup" "$dedup" || return 1
	state_kv_set "zfs_arc_mode" "$arc_mode" || return 1
	state_kv_set "zfs_arc_max" "$arc_max" || return 1
	state_kv_set "install_plan_compression" "$comp" || return 1
	state_kv_set "install_plan_dedup" "$dedup" || return 1
	state_kv_set "install_plan_arc_mode" "$arc_mode" || return 1
	state_kv_set "install_plan_arc_max" "$arc_max" || return 1
}
