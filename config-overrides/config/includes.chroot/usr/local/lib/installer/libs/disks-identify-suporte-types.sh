#!/usr/bin/env bash
# @INST_LIB_NAME: disks-identify
# @INST_DESC: Lógica de identificação de tipos de disco para topologias ZFS.

set -euo pipefail

disks_identify_topology_candidates() {
	# Retorna lista de discos aptos para ZFS
	# Pode filtrar por tamanho, tipo, etc.
	disk_list_available
}
