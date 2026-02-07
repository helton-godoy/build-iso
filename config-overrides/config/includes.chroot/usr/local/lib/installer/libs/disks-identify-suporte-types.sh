#!/usr/bin/env bash
#
# disks-identify-suporte-types.sh - Identificação de tipos de disco para topologia ZFS
#

set -euo pipefail

disks_identify_topology_candidates() {
    # Retorna lista de discos aptos para ZFS
    # Pode filtrar por tamanho, tipo, etc.
    disk_list_available
}
