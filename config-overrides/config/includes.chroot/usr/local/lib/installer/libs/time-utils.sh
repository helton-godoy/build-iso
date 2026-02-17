#!/usr/bin/env bash
# @INST_LIB_NAME: time-utils
# @INST_DESC: Utilitários para configuração de fuso horário e geração de locales.

set -euo pipefail

timeutils_set_timezone() {
	local target="$1"
	local timezone="${2:-UTC}"

	chroot "$target" ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
	# Reconfigure tzdata if possible (might fail in chroot without proper env)
	chroot "$target" dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true
}

timeutils_set_locales() {
	local target="$1"
	local locales="${2:-en_US.UTF-8 UTF-8,pt_BR.UTF-8 UTF-8}"

	# We assume locale.gen exists
	for loc in $(echo $locales | tr ',' ' '); do
		local regex="s/# ${loc}/${loc}/"
		sed -i "$regex" "$target/etc/locale.gen" 2>/dev/null || true
	done

	chroot "$target" locale-gen 2>/dev/null || true
	echo 'LANG=en_US.UTF-8' >"${target}/etc/default/locale"
}
