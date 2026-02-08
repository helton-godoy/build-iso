#!/usr/bin/env bash

_split_disks_into_groups() {
	local disks_csv="$1"
	local groups="$2"
	local -a all=()
	IFS=',' read -r -a all <<<"$disks_csv"
	local total="${#all[@]}"
	if ((groups < 1 || total < groups)); then
		return 1
	fi

	local base=$((total / groups))
	local rest=$((total % groups))
	local idx=0
	local g size
	for ((g = 0; g < groups; g++)); do
		size="$base"
		if ((g < rest)); then
			size=$((size + 1))
		fi
		local -a chunk=()
		local j
		for ((j = 0; j < size; j++)); do
			chunk+=("${all[$idx]}")
			idx=$((idx + 1))
		done
		printf '%s\n' "$(
			IFS=,
			printf '%s' "${chunk[*]}"
		)"
	done
}

step_zfs_auto_topology() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "ZFS: Topologia do Pool"
	ui_guidance \
		"Escolher como os discos serão organizados em vdevs" \
		"Define capacidade útil, desempenho e tolerância a falhas" \
		"Para produção, prefira mirror/raidz2 conforme quantidade de discos" \
		"Não houver clareza sobre risco de perda de dados"

	local topo pool
	topo="$(ui_select "Topologia de dados:" "stripe" "mirror" "raidz1" "raidz2" "raidz3" "draid1" "draid2" "draid3")"
	topo="$(sanitize_id "$topo")"
	[[ -z "$topo" ]] && topo="stripe"

	pool="$(ui_input "Nome do pool:" "rpool")"
	pool="$(sanitize_id "$pool")"
	[[ -z "$pool" ]] && pool="rpool"

	local disks_csv
	disks_csv="$(plan_get_selected_disks_csv)"
	if [[ -z "$disks_csv" ]]; then
		ui_error "Selecione os discos antes da topologia."
		return 1
	fi

	local -a disks=()
	IFS=',' read -r -a disks <<<"$disks_csv"
	local count="${#disks[@]}"

	# Definição de layout de top-level vdevs
	local data_vdevs=""
	local groups="1"

	if [[ "$topo" == "mirror" && "$count" -ge 4 ]]; then
		if ui_confirm "Usar RAID10 (múltiplos mirrors em stripe)?" "RAID10" "Mirror único"; then
			if ((count % 2 != 0)); then
				ui_error "RAID10 requer número par de discos."
				return 1
			fi
			local i
			for ((i = 0; i < count; i += 2)); do
				local pair_csv="${disks[$i]},${disks[$((i + 1))]}"
				local entry
				entry="$(plan_make_vdev_entry "mirror" "$pair_csv")"
				if [[ -n "$data_vdevs" ]]; then
					data_vdevs+="|"
				fi
				data_vdevs+="$entry"
			done
		else
			data_vdevs="$(plan_make_vdev_entry "$topo" "$disks_csv")"
		fi
	elif [[ "$topo" =~ ^raidz[123]$ && "$count" -ge 6 ]]; then
		if ui_confirm "Dividir em 2 grupos de vdev para mais paralelismo?" "Dividir" "Grupo único"; then
			groups="2"
		fi
		if [[ "$groups" == "2" ]]; then
			local gcsv
			while IFS= read -r gcsv; do
				[[ -z "$gcsv" ]] && continue
				local entry
				entry="$(plan_make_vdev_entry "$topo" "$gcsv")"
				if [[ -n "$data_vdevs" ]]; then
					data_vdevs+="|"
				fi
				data_vdevs+="$entry"
			done < <(_split_disks_into_groups "$disks_csv" 2)
		else
			data_vdevs="$(plan_make_vdev_entry "$topo" "$disks_csv")"
		fi
	else
		data_vdevs="$(plan_make_vdev_entry "$topo" "$disks_csv")"
	fi

	state_kv_set "zfs_topology" "$topo" || return 1
	state_kv_set "zfs_pool_name" "$pool" || return 1
	plan_ensure_version || return 1
	plan_set_data_topology "$topo" || return 1
	plan_set_data_vdevs "$data_vdevs" || return 1
}
