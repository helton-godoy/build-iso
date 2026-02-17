#!/usr/bin/env bash
# @INST_LIB_NAME: auth-utils
# @INST_DESC: Gerenciamento de contas de usuário, grupos e credenciais no chroot.

set -euo pipefail

authutils_create_user() {
	local target="$1"
	local username="$2"
	local password="$3"
	local groups="${4:-sudo,plugdev,audio,video,users}"

	chroot "$target" useradd -m -s /bin/bash -G "$groups" "$username"
	echo "${username}:${password}" | chroot "$target" chpasswd
}

authutils_set_root_pw() {
	local target="$1"
	local password="$2"

	echo "root:${password}" | chroot "$target" chpasswd
}
