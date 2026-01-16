# components/ - Installer Phases

**Purpose:** Modular installation phases (01-validate through 08-cleanup)  
**Pattern:** Sequential numbered scripts sourced by install-manager.sh

## STRUCTURE
```
components/
├── 01-validate.sh      # Pre-flight checks
├── 02-partition.sh     # Disk partitioning
├── 03-pool.sh          # ZFS pool creation
├── 04-datasets.sh      # ZFS dataset hierarchy
├── 05-extract.sh       # Base system extraction
├── 06-chroot-configure.sh  # Chroot configuration
├── 07-bootloader.sh    # ZFSBootMenu setup
└── 08-cleanup.sh       # Final cleanup
```

## SCRIPT PATTERN
```bash
#!/usr/bin/env bash
# components/XX-name.sh - Description
# Uses: lib/logging.sh, lib/validation.sh

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib"
export LIB_DIR
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/validation.sh"

# Sections delimited by:
# =============================================================================

function main_phase() {
    log_init_component "Phase Name"
    # ... implementation
}
```

## EXECUTION ORDER
install-manager.sh sources components in numeric order:
1. **01-validate** - Environment validation (root, memory, ZFS)
2. **02-partition** - GPT partition tables
3. **03-pool** - `zpool create` with ashift=12
4. **04-datasets** - `zfs create` for datasets
5. **05-extract** - Debootstrap extraction
6. **06-chroot-configure** - /etc configuration in chroot
7. **07-bootloader** - ZFSBootMenu + EFI System Partition
8. **08-cleanup** - Unmount, pool export, temp cleanup

## VARIABLES EXPORTED BY install-manager.sh
- `SELECTED_DISKS` - Array of disk paths
- `POOL_NAME` - ZFS pool name (default: zroot)
- `MOUNT_POINT` - Target mount path
- `FIRMWARE` - uefi or bios

## PHASE-SPECIFIC CONVENTIONS
| Phase | Key Functions | Notes |
|-------|---------------|-------|
| 01 | `run_installer_validations()` | Returns 1 on failure |
| 02 | `partition_disk()` | Uses sgdisk, wipefs |
| 03 | `create_zpool()` | ashift=12, compression=zstd |
| 04 | `create_datasets()` | Follows dataset hierarchy |
| 07 | `install_zfsbootmenu()` | Handles UEFI/BIOS differences |

## ANTI-PATTERNS
- ❌ Never hardcode disk paths (use `${SELECTED_DISKS[0]}`)
- ❌ Never skip validation phase
- ❌ Never use `/dev/sdX` directly (use `/dev/disk/by-id/*`)
