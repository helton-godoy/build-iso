#!/usr/bin/env bash
# @INST_STEP_ID: zfs_manual
# @INST_STEP_FLOW: prev=zfs_strategy, next=boot
# @INST_STATE: zfs_manual_ack
step_zfs_manual() {
	ui_hero "$PROJECT_NAME" "$PROJECT_TAGLINE"
	ui_section "ZFS: Manual (Avançado)"
	ui_card "Modo Avançado" \
		"  $UI_BULLET Gerenciar VDEVs, pools e datasets." \
		"  $UI_BULLET Propriedades e mountpoints personalizados." \
		"" \
		"  (Implementação real via módulos em $STEPS_DIR/zfs_manual.sh)"
	if ui_confirm "Continuar no modo manual?" "Continuar" "Voltar"; then
		state_kv_set "zfs_manual_ack" "1" || return 1
		return 0
	fi
	goto_prev || true
	return 0
}
