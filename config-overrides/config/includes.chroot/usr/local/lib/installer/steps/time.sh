#!/usr/bin/env bash

list_timezones() {
	local tz_file="/usr/share/zoneinfo/zone1970.tab"
	if [[ -f "$tz_file" ]]; then
		awk 'NF && $1 !~ /^#/ { print $3 }' "$tz_file" | sort -u
		return 0
	fi

	printf '%s\n' "America/Sao_Paulo" "UTC"
}

step_time() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "Data e Hora"
	ui_card "Fuso horário" \
		"  $UI_BULLET Lista completa baseada em /usr/share/zoneinfo/zone1970.tab" \
		"  $UI_BULLET Recomendado para Brasil: America/Sao_Paulo" \
		"  $UI_BULLET Digite para filtrar rapidamente na lista"

	local -a timezones
	mapfile -t timezones < <(list_timezones)
	if [[ "${#timezones[@]}" -eq 0 ]]; then
		timezones=("America/Sao_Paulo" "UTC")
	fi

	local tz
	tz="$(ui_filter_select "Selecione o fuso horário:" "${timezones[@]}")"
	tz="$(sanitize_ws "$tz")"
	if [[ -z "$tz" ]]; then
		tz="UTC"
	fi
	state_kv_set "install_tz" "$tz" || return 1

	local ntp
	if ui_confirm "Ativar NTP?" "Ativar" "Desativar"; then
		ntp="1"
	else
		ntp="0"
	fi
	state_kv_set "install_ntp" "$ntp" || return 1

	if [[ "$ntp" == "1" ]]; then
		local ntp_srv
		ntp_srv="$(ui_input "Servidor NTP (opcional):" "pool.ntp.org")"
		ntp_srv="$(sanitize_ws "$ntp_srv")"
		state_kv_set "install_ntp_server" "$ntp_srv" || return 1
	fi
}
