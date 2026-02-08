#!/usr/bin/env bash
# @INST_STEP_ID: install
# @INST_STEP_FLOW: prev=review, next=post_install
# @INST_DESC: Orquestra a execução real da instalação: particionamento, ZFS, debootstrap e configuração base.
# @INST_TODO: Refatorar install_prepare_disks para delegar totalmente à libs/partitioning.

set -o errexit
set -o nounset
set -o pipefail

# steps/install.sh
# Exports: step_install
# Depends on (lazy-loaded by router):
#   libs/disk-utils.sh libs/zfs-utils.sh libs/boot-utils.sh libs/install-utils.sh libs/validate-utils.sh libs/disks-identify-suporte-types.sh
# Uses router-provided: ui_*, state_*, sanitize_*, log_line

INSTALL_TARGET_ROOT_DEFAULT="/mnt"
INSTALL_ESP_MOUNT_DEFAULT="/boot/efi"
INSTALL_EFI_MIB_DEFAULT="512"
INSTALLER_PLAN_MODE_DEFAULT="canonical"

step_install() {
	ui_hero "${PROJECT_NAME:-FILESERVER INSTALLER}" "${PROJECT_TAGLINE:-Debian 13 + ZFS on Root}"
	ui_section "Instalação do Sistema Base"

	state_load || true

	if declare -F validate_all_checkpoint >/dev/null 2>&1; then
		if ! validate_all_checkpoint; then
			ui_warn "Configuração inválida/ incompleta. Rode 'Assistente de Configuração' e revise no 'Resumo'."
			if ! ui_confirm "Continuar mesmo assim?" "Continuar" "Cancelar"; then
				return 1
			fi
		fi
	fi

	local disk disks_csv pool topo comp dedup strategy ashift arc_mode arc_max suite mirror retries timeout swap_mib bootloader plan_mode
	disk="$(sanitize_path "$(state_kv_get install_disk)")"
	disks_csv="$(sanitize_ws "$(state_kv_get install_disks)")"
	pool="$(sanitize_ws "$(state_kv_get zfs_pool_name)")"
	topo="$(sanitize_id "$(state_kv_get zfs_topology)")"
	comp="$(sanitize_id "$(state_kv_get zfs_compression)")"
	dedup="$(sanitize_id "$(state_kv_get zfs_dedup)")"
	strategy="$(sanitize_id "$(state_kv_get install_zfs_strategy)")"
	ashift="$(sanitize_ws "$(state_kv_get zfs_ashift)")"
	arc_mode="$(sanitize_id "$(state_kv_get zfs_arc_mode)")"
	arc_max="$(sanitize_ws "$(state_kv_get zfs_arc_max)")"
	suite="$(sanitize_ws "$(state_kv_get install_suite)")"
	mirror="$(sanitize_ws "$(state_kv_get install_mirror)")"
	retries="$(sanitize_ws "$(state_kv_get install_apt_retries)")"
	timeout="$(sanitize_ws "$(state_kv_get install_apt_timeout)")"
	swap_mib="$(sanitize_ws "$(state_kv_get install_swap_mib)")"
	bootloader="$(sanitize_id "$(state_kv_get bootloader)")"
	plan_mode="$(sanitize_id "${INSTALLER_PLAN_MODE:-$INSTALLER_PLAN_MODE_DEFAULT}")"
	[[ -z "$plan_mode" ]] && plan_mode="$INSTALLER_PLAN_MODE_DEFAULT"

	[[ -z "$suite" ]] && suite="stable"
	[[ -z "$mirror" ]] && mirror="http://deb.debian.org/debian"
	[[ -z "$retries" ]] && retries="5"
	[[ -z "$timeout" ]] && timeout="30"
	[[ -z "$swap_mib" ]] && swap_mib="0"
	[[ -z "$bootloader" ]] && bootloader="grub"

	local -a selected_disks=()
	if [[ -n "$disks_csv" ]]; then
		IFS=',' read -r -a selected_disks <<<"$disks_csv"
	fi
	if [[ "${#selected_disks[@]}" -eq 0 && -n "$disk" ]]; then
		selected_disks=("$disk")
	fi

	if [[ "${#selected_disks[@]}" -eq 0 || -z "$pool" ]]; then
		ui_error "Disco(s)/pool não definidos. Rode o Assistente."
		return 1
	fi

	disk="$(sanitize_path "${selected_disks[0]}")"
	local disk_count="${#selected_disks[@]}"

	if ! install_validate_topology_disk_count "$topo" "$disk_count"; then
		return 1
	fi

	local d
	for d in "${selected_disks[@]}"; do
		d="$(sanitize_path "$d")"
		if declare -F diskid_policy_refuse_usb_install >/dev/null 2>&1; then
			diskid_policy_refuse_usb_install "$d" || return 1
		fi
		diskutils_validate_target_disk "$d" || return 1
		diskutils_refuse_install_on_media_disk "$d" || return 1
	done

	local disks_label
	disks_label="$(
		IFS=,
		printf '%s' "${selected_disks[*]}"
	)"

	ui_card "Plano de instalação" \
		"  ${UI_BULLET:-•} Disco(s):    $disks_label" \
		"  ${UI_BULLET:-•} Pool:        $pool" \
		"  ${UI_BULLET:-•} Topologia:   $topo" \
		"  ${UI_BULLET:-•} Compressão:  $comp" \
		"  ${UI_BULLET:-•} Dedup:       $dedup" \
		"  ${UI_BULLET:-•} ARC:         ${arc_mode}${arc_max:+ ($arc_max)}" \
		"  ${UI_BULLET:-•} SWAP MiB:    $swap_mib" \
		"  ${UI_BULLET:-•} Suite:       $suite" \
		"  ${UI_BULLET:-•} Mirror:      $mirror" \
		"  ${UI_BULLET:-•} Bootloader:  $bootloader" \
		"" \
		"  ${UI_BULLET:-•} Será alterado: partições, pool ZFS e sistema base nos discos selecionados." \
		"  ${UI_BULLET:-•} Não será alterado: discos não selecionados e configurações fora do alvo." \
		"  ${UI_BULLET:-•} Modo do plano: $plan_mode"

	state_kv_set "install_plan_mode" "$plan_mode" || true
	if [[ "$plan_mode" != "legacy" ]]; then
		if ! install_plan_preflight "$topo" "$disk_count"; then
			return 1
		fi
	fi

	if ! ui_confirm "CONFIRMAR e iniciar (destrutivo)?" "Instalar" "Cancelar"; then
		return 1
	fi

	ui_process_step "Preparando disco(s) (${disk_count})..." \
		install_prepare_disks "$disks_label" "$swap_mib" "$bootloader" || return 1

	ui_process_step "Criando ZFS ($pool/$topo)..." \
		install_create_zfs "$disks_label" "$pool" "$topo" "$comp" "$dedup" "$ashift" "$strategy" "$swap_mib" || return 1

	ui_process_step "Montando volumes..." \
		install_mount_esp_and_write_fstab "$disk" "$swap_mib" || return 1

	ui_process_step "Instalando sistema base (Debian $suite)..." \
		install_debootstrap_and_apt "$suite" "$mirror" "$retries" "$timeout" || return 1

	ui_process_step "Configurando Kernel e ZFS..." \
		install_kernel_zfs_and_base_tools || return 1

	ui_process_step "Otimizando performance (ARC)..." \
		install_apply_arc_tuning "$arc_mode" "$arc_max" || return 1

	ui_success "Sistema base instalado."
}

install_plan_preflight() {
	local topo="$1"
	local count="$2"

	if ! install_validate_topology_disk_count "$topo" "$count"; then
		return 1
	fi

	if ! plan_validate_aux_guardrails; then
		ui_error "Configuração de vdev auxiliar inválida."
		return 1
	fi

	local review_sig current_sig
	review_sig="$(sanitize_ws "$(state_kv_get install_plan_review_sig)")"
	current_sig="$(plan_signature)"
	if [[ -n "$review_sig" && "$review_sig" != "$current_sig" ]]; then
		ui_error "Plano alterado após revisão. Revise novamente antes de instalar."
		return 1
	fi

	return 0
}

install_validate_topology_disk_count() {
	local topo
	topo="$(sanitize_id "${1-}")"
	local count
	count="$(sanitize_ws "${2-0}")"
	if ! printf '%s' "$count" | grep -Eq '^[0-9]+$'; then
		ui_error "Quantidade de discos inválida: $count"
		return 1
	fi

	case "$topo" in
	"" | stripe)
		if ((count < 1)); then
			ui_error "Topologia stripe requer ao menos 1 disco."
			return 1
		fi
		;;
	mirror)
		if ((count < 2)); then
			ui_error "Topologia mirror requer ao menos 2 discos."
			return 1
		fi
		;;
	raidz | raidz1)
		if ((count < 2)); then
			ui_error "Topologia raidz1 requer ao menos 2 discos."
			return 1
		fi
		;;
	raidz2)
		if ((count < 3)); then
			ui_error "Topologia raidz2 requer ao menos 3 discos."
			return 1
		fi
		;;
	raidz3)
		if ((count < 4)); then
			ui_error "Topologia raidz3 requer ao menos 4 discos."
			return 1
		fi
		;;
	draid1)
		if ((count < 2)); then
			ui_error "Topologia draid1 requer ao menos 2 discos."
			return 1
		fi
		;;
	draid2)
		if ((count < 3)); then
			ui_error "Topologia draid2 requer ao menos 3 discos."
			return 1
		fi
		;;
	draid3)
		if ((count < 4)); then
			ui_error "Topologia draid3 requer ao menos 4 discos."
			return 1
		fi
		;;
	*)
		ui_error "Topologia não suportada neste fluxo: $topo"
		return 1
		;;
	esac
}

install_build_data_vdev_spec() {
	local fallback_topo="$1"
	local parts_csv="$2"
	local -a zfs_parts=()
	IFS=',' read -r -a zfs_parts <<<"$parts_csv"

	local plan_entries
	plan_entries="$(sanitize_ws "$(state_kv_get install_plan_data_vdevs)")"
	if [[ -z "$plan_entries" ]]; then
		printf '%s\n' "$(plan_make_vdev_entry "$fallback_topo" "$parts_csv")"
		return 0
	fi
	printf '%s' "$plan_entries"
}

install_build_aux_vdev_spec() {
	local class="$1"
	local layout
	layout="$(plan_get_aux_layout "$class")"
	local csv
	csv="$(plan_get_aux_disks "$class")"
	[[ -z "$csv" ]] && return 0

	local -a disks=()
	IFS=',' read -r -a disks <<<"$csv"
	if [[ "${#disks[@]}" -eq 0 ]]; then
		return 0
	fi

	case "$class" in
	log)
		if [[ "$layout" == "mirror" ]]; then
			printf 'log mirror %s\n' "$(
				IFS=' '
				printf '%s' "${disks[*]}"
			)"
		else
			printf 'log %s\n' "$(
				IFS=' '
				printf '%s' "${disks[*]}"
			)"
		fi
		;;
	cache)
		printf 'cache %s\n' "$(
			IFS=' '
			printf '%s' "${disks[*]}"
		)"
		;;
	special)
		if [[ "$layout" == "mirror" ]]; then
			printf 'special mirror %s\n' "$(
				IFS=' '
				printf '%s' "${disks[*]}"
			)"
		else
			printf 'special %s\n' "$(
				IFS=' '
				printf '%s' "${disks[*]}"
			)"
		fi
		;;
	dedup)
		if [[ "$layout" == "mirror" ]]; then
			printf 'dedup mirror %s\n' "$(
				IFS=' '
				printf '%s' "${disks[*]}"
			)"
		else
			printf 'dedup %s\n' "$(
				IFS=' '
				printf '%s' "${disks[*]}"
			)"
		fi
		;;
	spare)
		printf 'spare %s\n' "$(
			IFS=' '
			printf '%s' "${disks[*]}"
		)"
		;;
	esac
}

install_prepare_disks() {
	# Single responsibility: wipe + GPT partitioning + format ESP + init swap optional
	# Args: disks_csv swap_mib bootloader
	local disks_csv
	disks_csv="$(sanitize_ws "${1-}")"
	local swap_mib
	swap_mib="$(sanitize_ws "${2-0}")"
	local bootloader
	bootloader="$(sanitize_id "${3-grub}")"

	local -a disks=()
	IFS=',' read -r -a disks <<<"$disks_csv"
	if [[ "${#disks[@]}" -eq 0 ]]; then
		ui_error "Nenhum disco selecionado para preparar."
		return 1
	fi

	local bios_grub="0"
	if ! bootutils_is_uefi && [[ "$bootloader" == "grub" ]]; then
		bios_grub="1"
	fi

	local d
	for d in "${disks[@]}"; do
		d="$(sanitize_path "$d")"
		diskutils_umount_all_children "$d" || true
	done

	# Auxiliares: limpar assinaturas para garantir inclusão segura no pool
	local klass aux_csv
	for klass in log cache special dedup spare; do
		aux_csv="$(plan_get_aux_disks "$klass")"
		[[ -z "$aux_csv" ]] && continue
		local -a aux_arr=()
		IFS=',' read -r -a aux_arr <<<"$aux_csv"
		for d in "${aux_arr[@]}"; do
			d="$(sanitize_path "$d")"
			[[ -z "$d" ]] && continue
			diskutils_umount_all_children "$d" || true
			diskutils_wipe_signatures "$d" || return 1
			diskutils_zap_gpt "$d" || true
		done
	done

	if declare -F zfsutils_pool_exists >/dev/null 2>&1; then
		local pool
		pool="$(sanitize_ws "$(state_kv_get zfs_pool_name)")"
		if [[ -n "$pool" ]] && zfsutils_pool_exists "$pool"; then
			zfsutils_umount_all_under_altroot "$pool" || true
			zfsutils_export_pool "$pool" || true
		fi
	fi

	local -a zfs_parts=()
	local efi="" swap=""
	local idx=0

	for d in "${disks[@]}"; do
		d="$(sanitize_path "$d")"
		diskutils_wipe_signatures "$d" || return 1
		diskutils_zap_gpt "$d" || true

		local this_swap="0"
		local this_bios_grub="0"
		local has_swap="0"
		if ((idx == 0)); then
			this_swap="$swap_mib"
			this_bios_grub="$bios_grub"
			if [[ -n "$swap_mib" ]] && printf '%s' "$swap_mib" | grep -Eq '^[0-9]+$' && [[ "$swap_mib" != "0" ]]; then
				has_swap="1"
			fi
		fi

		diskutils_create_gpt_efi_swap_optional "$d" "$INSTALL_EFI_MIB_DEFAULT" "$this_swap" "$this_bios_grub" || return 1

		local parts zfsp
		if ! parts="$(diskutils_partition_paths_for_zfs_layout "$d" "$has_swap" "$this_bios_grub")"; then
			ui_error "Falha ao detectar partições criadas em $d."
			return 1
		fi

		zfsp="$(printf '%s\n' "$parts" | awk -F= '$1=="ZFS"{print $2}' | head -n1 || true)"
		zfsp="$(sanitize_path "$zfsp")"
		if [[ -z "$zfsp" ]]; then
			ui_error "Partição ZFS não encontrada em $d."
			return 1
		fi
		zfs_parts+=("$zfsp")

		if ((idx == 0)); then
			efi="$(printf '%s\n' "$parts" | awk -F= '$1=="EFI"{print $2}' | head -n1 || true)"
			swap="$(printf '%s\n' "$parts" | awk -F= '$1=="SWAP"{print $2}' | head -n1 || true)"
			efi="$(sanitize_path "$efi")"
			swap="$(sanitize_path "$swap")"
			if [[ -z "$efi" ]]; then
				ui_error "Partição EFI não encontrada em $d."
				return 1
			fi
		fi

		idx=$((idx + 1))
	done

	if [[ "${#zfs_parts[@]}" -eq 0 ]]; then
		ui_error "Nenhuma partição ZFS válida foi encontrada."
		return 1
	fi

	state_kv_set "install_part_efi" "$efi" || return 1
	state_kv_set "install_part_zfs" "${zfs_parts[0]}" || return 1
	state_kv_set "install_part_swap" "$swap" || true
	state_kv_set "install_parts_zfs" "$(
		IFS=,
		printf '%s' "${zfs_parts[*]}"
	)" || return 1

	diskutils_mkfs_vfat_efi "$efi" || return 1
	if [[ -n "$swap" ]]; then
		diskutils_mkswap_partition "$swap" || return 1
	fi
}

install_create_zfs() {
	# Single responsibility: create pool + datasets and mount root dataset to target
	# Args: disks_csv pool topo comp dedup ashift strategy swap_mib
	local disks_csv
	disks_csv="$(sanitize_ws "${1-}")"
	local pool
	pool="$(sanitize_ws "${2-}")"
	local topo
	topo="$(sanitize_id "${3-}")"
	local comp
	comp="$(sanitize_id "${4-}")"
	local dedup
	dedup="$(sanitize_id "${5-0}")"
	local ashift
	ashift="$(sanitize_ws "${6-12}")"
	local strategy
	strategy="$(sanitize_id "${7-auto}")"
	local swap_mib
	swap_mib="$(sanitize_ws "${8-0}")"

	local parts_csv
	parts_csv="$(sanitize_ws "$(state_kv_get install_parts_zfs)")"
	[[ -z "$parts_csv" ]] && parts_csv="$(sanitize_ws "$(state_kv_get install_part_zfs)")"

	local -a zfs_parts=()
	IFS=',' read -r -a zfs_parts <<<"$parts_csv"
	if [[ "${#zfs_parts[@]}" -eq 0 ]]; then
		ui_error "Nenhuma partição ZFS definida para criação do pool."
		return 1
	fi

	local p
	for p in "${zfs_parts[@]}"; do
		p="$(sanitize_path "$p")"
		if [[ -z "$p" || ! -b "$p" ]]; then
			ui_error "Partição ZFS inválida: $p"
			return 1
		fi
	done

	if ! install_validate_topology_disk_count "$topo" "${#zfs_parts[@]}"; then
		return 1
	fi

	local root_ds="${pool}/ROOT/${PROJECT_BOOT_ID:-debian}"
	state_kv_set "zfs_root_dataset" "$root_ds" || return 1

	if [[ "$strategy" == "manual" ]]; then
		ui_warn "Modo manual ainda usa fluxo assistido para criação do pool neste instalador."
	fi

	if zfsutils_pool_exists "$pool"; then
		ui_warn "Pool já existe; tentando exportar e recriar."
		zfsutils_umount_all_under_altroot "$pool" || true
		zfsutils_export_pool "$pool" || true
	fi

	local -a vdev_spec=()
	local data_entries
	data_entries="$(install_build_data_vdev_spec "$topo" "$parts_csv")"

	# mapear disco selecionado -> partição ZFS correspondente
	local selected_csv
	selected_csv="$(plan_get_selected_disks_csv)"
	local -a selected_arr=()
	IFS=',' read -r -a selected_arr <<<"$selected_csv"
	declare -A disk_part_map=()
	local i
	for ((i = 0; i < ${#selected_arr[@]} && i < ${#zfs_parts[@]}; i++)); do
		disk_part_map["${selected_arr[$i]}"]="${zfs_parts[$i]}"
	done

	local entry
	while IFS= read -r entry; do
		[[ -z "$entry" ]] && continue
		local vtype
		vtype="$(printf '%s' "$entry" | sed -n 's/^type=\([^,]*\),.*$/\1/p')"
		local vcsv
		vcsv="$(printf '%s' "$entry" | sed -n 's/^type=[^,]*,disks=\(.*\)$/\1/p')"
		local -a vdisks=()
		IFS=',' read -r -a vdisks <<<"$vcsv"
		local -a mapped=()
		local vd
		for vd in "${vdisks[@]}"; do
			vd="$(sanitize_path "$vd")"
			if [[ -n "${disk_part_map[$vd]-}" ]]; then
				mapped+=("${disk_part_map[$vd]}")
			else
				mapped+=("$vd")
			fi
		done

		if ! install_validate_topology_disk_count "$vtype" "${#mapped[@]}"; then
			return 1
		fi

		case "$vtype" in
		"" | stripe)
			vdev_spec+=("${mapped[@]}")
			;;
		mirror | raidz1 | raidz2 | raidz3 | draid1 | draid2 | draid3)
			vdev_spec+=("$vtype" "${mapped[@]}")
			;;
		raidz)
			vdev_spec+=(raidz1 "${mapped[@]}")
			;;
		*)
			ui_error "Tipo de vdev não suportado: $vtype"
			return 1
			;;
		esac
	done <<<"$data_entries"

	local -a aux_spec=()
	local aux_line
	for aux_class in log cache special dedup spare; do
		aux_line="$(install_build_aux_vdev_spec "$aux_class")"
		[[ -z "$aux_line" ]] && continue
		read -r -a parts <<<"$aux_line"
		aux_spec+=("${parts[@]}")
	done

	if zpool list "$pool" &>/dev/null; then
		zpool destroy -f "$pool" || true
	fi

	zpool create -f \
		-o ashift="$ashift" \
		-o autotrim=on \
		-O acltype=posixacl \
		-O canmount=off \
		-O compression="$comp" \
		-O dedup="$dedup" \
		-O dnodesize=auto \
		-O normalization=formD \
		-O relatime=on \
		-O xattr=sa \
		-O mountpoint=none \
		"$pool" "${vdev_spec[@]}" "${aux_spec[@]}" || return 1

	# Root dataset tree
	zfsutils_create_root_datasets "$pool" "$root_ds" "$INSTALL_TARGET_ROOT_DEFAULT" || return 1

	# Presets
	local preset
	preset="$(sanitize_id "$(state_kv_get zfs_dataset_preset)")"
	[[ -z "$preset" ]] && preset="default"

	if [[ "$preset" == "server" ]]; then
		zfsutils_create_dataset_preset_server "$pool" "$root_ds" || return 1
	else
		zfsutils_create_dataset_preset_default "$pool" "$root_ds" || return 1
	fi

	zfsutils_set_mountpoints_final "$root_ds" || true

	# Ensure target root exists
	mkdir -p "$INSTALL_TARGET_ROOT_DEFAULT"
}

install_mount_esp_and_write_fstab() {
	# Single responsibility: mount ESP into target and write fstab entry
	# Args: disk swap_mib
	local disk
	disk="$(sanitize_path "${1-}")"
	local swap_mib
	swap_mib="$(sanitize_ws "${2-0}")"
	local efi swap
	efi="$(sanitize_path "$(state_kv_get install_part_efi)")"
	swap="$(sanitize_path "$(state_kv_get install_part_swap)")"

	if [[ -z "$efi" || ! -b "$efi" ]]; then
		ui_error "Partição EFI inválida: $efi"
		return 1
	fi

	bootutils_ensure_boot_dirs "$INSTALL_TARGET_ROOT_DEFAULT" || return 1
	bootutils_mount_esp "$efi" "$INSTALL_TARGET_ROOT_DEFAULT$INSTALL_ESP_MOUNT_DEFAULT" || return 1

	installutils_write_fstab_stub_for_efi "$INSTALL_TARGET_ROOT_DEFAULT" "$efi" "$INSTALL_ESP_MOUNT_DEFAULT" || return 1

	if [[ -n "$swap" && -b "$swap" && "$swap_mib" != "0" ]]; then
		# Optional: add swap to fstab if desired (simple)
		mkdir -p "$INSTALL_TARGET_ROOT_DEFAULT/etc"
		local fstab="$INSTALL_TARGET_ROOT_DEFAULT/etc/fstab"
		[[ -f "$fstab" ]] || : >"$fstab"
		if ! grep -Fq "$swap" "$fstab" 2>/dev/null; then
			printf '%s\tnone\tswap\tsw\t0\t0\n' "$swap" >>"$fstab"
		fi
	fi
}

install_debootstrap_and_apt() {
	# Single responsibility: debootstrap + apt configuration
	# Args: suite mirror retries timeout
	local suite
	suite="$(sanitize_ws "${1-stable}")"
	local mirror
	mirror="$(sanitize_ws "${2-http://deb.debian.org/debian}")"
	local retries
	retries="$(sanitize_ws "${3-5}")"
	local timeout
	timeout="$(sanitize_ws "${4-30}")"

	local proxy
	proxy="$(sanitize_ws "$(state_kv_get install_proxy)")"

	installutils_write_sources_list "$INSTALL_TARGET_ROOT_DEFAULT" "$suite" "$mirror" "main contrib non-free non-free-firmware" || return 1
	installutils_apt_configure_retries "$INSTALL_TARGET_ROOT_DEFAULT" "$retries" "$timeout" || return 1
	installutils_write_apt_proxy_conf "$INSTALL_TARGET_ROOT_DEFAULT" "$proxy" || return 1

	# Base include set ensures enough tooling
	local include="ca-certificates,gnupg,apt-transport-https,systemd-sysv"
	installutils_debootstrap_base "$INSTALL_TARGET_ROOT_DEFAULT" "$suite" "$mirror" "$include" || return 1

	installutils_bind_mounts "$INSTALL_TARGET_ROOT_DEFAULT" || return 1
}

install_kernel_zfs_and_base_tools() {
	# Single responsibility: install kernel + zfs + essentials inside target, then unmount binds kept for post_install
	installutils_install_kernel_and_zfs "$INSTALL_TARGET_ROOT_DEFAULT" || return 1

	# Basic tooling for boot/install/post steps
	installutils_apt_install_packages "$INSTALL_TARGET_ROOT_DEFAULT" "vim-tiny less curl wget openssh-server" || true
	installutils_apt_install_packages "$INSTALL_TARGET_ROOT_DEFAULT" "grub-efi-amd64 grub-pc efibootmgr" || true
	installutils_apt_install_packages "$INSTALL_TARGET_ROOT_DEFAULT" "refind" || true
}

install_apply_arc_tuning() {
	# Single responsibility: apply ARC tuning file into target
	# Args: arc_mode arc_max
	local mode
	mode="$(sanitize_id "${1-auto}")"
	local max
	max="$(sanitize_ws "${2-}")"
	zfsutils_apply_arc_tuning_target_file "$INSTALL_TARGET_ROOT_DEFAULT" "$mode" "$max" || return 1
}

# Export internals for spinner subshell
export -f install_prepare_disks
export -f install_create_zfs
export -f install_mount_esp_and_write_fstab
export -f install_debootstrap_and_apt
export -f install_kernel_zfs_and_base_tools
export -f install_apply_arc_tuning
export -f install_validate_topology_disk_count
export -f install_plan_preflight
export -f install_build_data_vdev_spec
export -f install_build_aux_vdev_spec
