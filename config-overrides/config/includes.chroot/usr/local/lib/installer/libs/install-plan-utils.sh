#!/usr/bin/env bash

plan_get_selected_disks_csv() {
	local disks_csv
	disks_csv="$(sanitize_ws "$(state_kv_get install_disks)")"
	if [[ -z "$disks_csv" ]]; then
		local disk
		disk="$(sanitize_path "$(state_kv_get install_disk)")"
		[[ -n "$disk" ]] && disks_csv="$disk"
	fi
	printf '%s' "$disks_csv"
}

plan_ensure_version() {
	state_kv_set "install_plan_version" "1"
}

plan_make_vdev_entry() {
	local vtype
	vtype="$(sanitize_id "${1-}")"
	local disks_csv
	disks_csv="$(sanitize_ws "${2-}")"
	printf 'type=%s,disks=%s' "$vtype" "$disks_csv"
}

plan_set_data_vdevs() {
	local entries
	entries="$(sanitize_ws "${1-}")"
	state_kv_set "install_plan_data_vdevs" "$entries"
}

plan_get_data_vdevs() {
	printf '%s' "$(sanitize_ws "$(state_kv_get install_plan_data_vdevs)")"
}

plan_set_data_topology() {
	local topo
	topo="$(sanitize_id "${1-stripe}")"
	state_kv_set "install_plan_data_topology" "$topo"
}

plan_set_aux_vdev() {
	local klass
	klass="$(sanitize_id "${1-}")"
	local layout
	layout="$(sanitize_id "${2-single}")"
	local disks_csv
	disks_csv="$(sanitize_ws "${3-}")"

	case "$klass" in
	log | cache | special | dedup | spare) ;;
	*)
		stderr "Classe auxiliar inválida: $klass"
		return 1
		;;
	esac

	state_kv_set "install_plan_aux_${klass}_layout" "$layout" || return 1
	state_kv_set "install_plan_aux_${klass}_disks" "$disks_csv" || return 1
}

plan_get_aux_disks() {
	local klass
	klass="$(sanitize_id "${1-}")"
	printf '%s' "$(sanitize_ws "$(state_kv_get install_plan_aux_${klass}_disks)")"
}

plan_get_aux_layout() {
	local klass
	klass="$(sanitize_id "${1-}")"
	printf '%s' "$(sanitize_id "$(state_kv_get install_plan_aux_${klass}_layout)")"
}

plan_signature() {
	local payload
	payload="v=$(sanitize_ws "$(state_kv_get install_plan_version)")"
	payload+="|disks=$(plan_get_selected_disks_csv)"
	payload+="|data_topo=$(sanitize_id "$(state_kv_get install_plan_data_topology)")"
	payload+="|data_vdevs=$(plan_get_data_vdevs)"
	payload+="|aux_log=$(plan_get_aux_layout log):$(plan_get_aux_disks log)"
	payload+="|aux_cache=$(plan_get_aux_layout cache):$(plan_get_aux_disks cache)"
	payload+="|aux_special=$(plan_get_aux_layout special):$(plan_get_aux_disks special)"
	payload+="|aux_dedup=$(plan_get_aux_layout dedup):$(plan_get_aux_disks dedup)"
	payload+="|aux_spare=$(plan_get_aux_layout spare):$(plan_get_aux_disks spare)"
	payload+="|pool=$(sanitize_ws "$(state_kv_get zfs_pool_name)")"
	payload+="|comp=$(sanitize_id "$(state_kv_get zfs_compression)")"
	payload+="|dedup=$(sanitize_id "$(state_kv_get zfs_dedup)")"

	if command -v sha256sum >/dev/null 2>&1; then
		printf '%s' "$payload" | sha256sum | cut -d' ' -f1
	else
		printf '%s' "$payload"
	fi
}

plan_validate_aux_guardrails() {
	local data_entries
	data_entries="$(plan_get_data_vdevs)"
	local data_csv=""
	local entry
	while IFS= read -r entry || [[ -n "$entry" ]]; do
		[[ -z "$entry" ]] && continue
		local ecsv
		ecsv="$(printf '%s' "$entry" | sed -n 's/^type=[^,]*,disks=\(.*\)$/\1/p')"
		[[ -z "$ecsv" ]] && continue
		if [[ -n "$data_csv" ]]; then
			data_csv+=","
		fi
		data_csv+="$ecsv"
	done < <(printf '%s\n' "$data_entries" | tr '|' '\n')

	local -a data_disks=()
	IFS=',' read -r -a data_disks <<<"$data_csv"

	local log_layout
	log_layout="$(plan_get_aux_layout log)"
	local log_disks
	log_disks="$(plan_get_aux_disks log)"
	if [[ -n "$log_layout" ]]; then
		case "$log_layout" in
		single | mirror) ;;
		*)
			stderr "Layout de log inválido: $log_layout"
			return 1
			;;
		esac
	fi
	if [[ "$log_layout" == "mirror" ]]; then
		local -a larr=()
		IFS=',' read -r -a larr <<<"$log_disks"
		if [[ "${#larr[@]}" -lt 2 ]]; then
			stderr "Log mirror requer ao menos 2 discos."
			return 1
		fi
	fi

	# Guardrail: um disco não pode estar simultaneamente em vdev de dados e auxiliar
	local klass
	for klass in log cache special dedup spare; do
		local aux_csv
		aux_csv="$(plan_get_aux_disks "$klass")"
		[[ -z "$aux_csv" ]] && continue
		local -a aux_arr=()
		IFS=',' read -r -a aux_arr <<<"$aux_csv"
		local d a
		for d in "${data_disks[@]}"; do
			for a in "${aux_arr[@]}"; do
				if [[ "$d" == "$a" ]]; then
					stderr "Disco $d foi usado em dados e em $klass."
					return 1
				fi
			done
		done
	done
	return 0
}
