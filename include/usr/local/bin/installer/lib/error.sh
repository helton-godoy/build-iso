#!/usr/bin/env bash
#
# lib/error.sh - Error handling and Atomic Rollback mechanism
#
# This library provides:
# 1. Global error trap
# 2. State tracking for atomic rollback
# 3. Cleanup functions
#

# Global state tracker
# Possible states: PREP, PARTITIONED, POOL_CREATED, DATASETS_CREATED, EXTRACTED, CONFIGURED, BOOTLOADER, FINISHED
declare INSTALL_STATE="PREP"

# Set global trap
set_error_trap() {
	trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR INT TERM
}

# Clear trap (success)
clear_error_trap() {
	trap - ERR INT TERM
}

# Update state
set_state() {
	INSTALL_STATE="$1"
	log_debug "State changed to: ${INSTALL_STATE}"
}

# Error Handler
error_handler() {
	local exit_code=$1
	local line_no=$2
	local command=$3

	# Ignore 0 and manual exits
	[[ ${exit_code} -eq 0 ]] && return

	echo ""
	log_error "CRITICAL FAILURE DETECTED"
	log_error "Error code: ${exit_code}"
	log_error "File: ${BASH_SOURCE[1]}"
	log_error "Line: ${line_no}"
	log_error "Command: ${command}"

	# User Notification via Gum locally if possible
	if command -v gum &>/dev/null; then
		gum style --foreground 196 --bold --border double --padding "1 2" \
			"CRITICAL ERROR DETECTED" \
			"The installation has failed." \
			"Starting emergency rollback procedure..."
	fi

	start_rollback "${INSTALL_STATE}"

	log_section "!!! INSTALLATION FAILED !!!"
	log_info "Please check the log file: ${LOG_FILE}"

	exit "${exit_code}"
}

# Atomic Rollback Logic
start_rollback() {
	local state="$1"
	log_section "=== STARTING ROLLBACK (State: ${state}) ==="

	# Ensure sync before doing anything destructive
	sync

	case "${state}" in
	FINISHED)
		log_warn "Failure occurred after success? No rollback needed."
		;;

	BOOTLOADER | CONFIGURED | EXTRACTED | DATASETS_CREATED)
		log_info "Unmounting ZFS datasets..."
		# Lazy unmount everything under target
		if mountpoint -q "${MOUNT_POINT}"; then
			umount -Rl "${MOUNT_POINT}" || log_warn "Failed to lazy unmount ${MOUNT_POINT}"
		fi

		# Export ZFS pool
		if [[ -n ${POOL_NAME-} ]]; then
			log_info "Exporting ZFS pool: ${POOL_NAME}"
			zpool export -f "${POOL_NAME}" || log_warn "Failed to export pool ${POOL_NAME}"
		fi

		# If we just created the pool/datasets, we might want to destroy it to leave disk clean?
		# Decision: "Atomic Cleanup" means reverting to pre-install state if possible.
		# However, `zpool destroy` is dangerous if we are not 100% sure.
		# Safer strategy: Export it. The user can overwrite it next time.
		# But specific requirement was "restore state".

		if [[ -n ${POOL_NAME-} ]]; then
			if zpool list "${POOL_NAME}" &>/dev/null; then
				log_warn "Destroying partially created pool ${POOL_NAME}..."
				zpool destroy -f "${POOL_NAME}" || log_warn "Failed to destroy pool"
			fi
		fi
		;;

	POOL_CREATED)
		# Only pool exists, no datasets mounted yet (theoretically)
		if [[ -n ${POOL_NAME-} ]]; then
			log_info "Destroying partial pool: ${POOL_NAME}"
			zpool destroy -f "${POOL_NAME}" || log_warn "Failed to destroy pool"
		fi
		;;

	PARTITIONED)
		# Disks are partitioned but no pool.
		# We could wipefs, but that might be excessive.
		log_info "Reverting partitions is not safe automated action. Leaving disks as-is."
		;;

	PREP)
		log_info "Failed during preparation. No persistent changes made."
		;;

	*)
		log_error "Unknown state: ${state}"
		;;
	esac

	log_success "Rollback procedure completed."
}
