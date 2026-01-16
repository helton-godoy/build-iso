# AGENTS.md - Debian ZFS ISO Builder

**Project:** Debian ISO Builder with ZFS-on-Root and ZFSBootMenu  
**Language:** Shell scripts (Bash)  
**Last Updated:** 2026-01-16

---

## OVERVIEW

Builds bootable Debian ISO with ZFS-on-Root and ZFSBootMenu bootloader. Uses live-build to create ISO, custom installer components for ZFS setup.

## STRUCTURE
```
./
├── docker/                    # Live-build configuration
│   └── config/package-lists/  # Package lists for ISO
├── include/usr/local/bin/installer/
│   ├── components/            # Installer phases (01-08)
│   ├── lib/                   # Shared libraries
│   ├── install-system         # Main installer
│   └── install-manager.sh     # Orchestrator
├── tests/                     # Test suite
└── tools/                     # Utility scripts
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| ISO build | `docker/` + `lb build` |
| Installer phases | `components/01-*.sh` through `08-*.sh` |
| Shared utilities | `lib/*.sh` (logging, validation, chroot) |
| Testing | `tests/` + `tests/AGENTS.md` |
| ZFSBootMenu | `tools/download-zfsbootmenu.sh` |

## CODE MAP
| Component | Lines | Role |
|-----------|-------|------|
| install-system | ~1200 | Main installer entry |
| install-manager.sh | ~500 | Orchestrates components |
| components/07-bootloader.sh | 331 | ZFSBootMenu setup |
| components/03-pool.sh | 274 | ZFS pool creation |
| lib/validation.sh | ~250 | Pre-flight checks |

## CONVENTIONS

### Shell Style
```bash
#!/usr/bin/env bash
set -euo pipefail          # ALWAYS

# CONSTANTS
readonly POOL_NAME="zroot"

# Functions (Portuguese naming)
create_zfs_pool() { ... }

# Variables
local disk="${SELECTED_DISKS[0]}"
```

### Indentation: 2 spaces (no tabs)  
### Max line: 100 chars

## ANTI-PATTERNS (NEVER)
- ❌ Hardcode encryption keys
- ❌ Assume device paths (use `/dev/disk/by-id/*`)
- ❌ Operate on disks without confirmation
- ❌ Use `wipefs` without `sgdisk --zap-all`

## ZFS POOL CONFIG
```bash
zpool create -f \
    -o ashift=12 \
    -o compression=zstd \
    -O xattr=sa \
    zroot /dev/disk/by-id/...
```

## KERNEL PARAMS (ZFSBootMenu)
```
quiet
elevator=noop
zfs.zfs_arc_max=1073741824
zbm.waitfor=5
```

## COMMANDS
```bash
# Validate syntax
bash -n include/usr/local/bin/installer/install-system

# Run tests
bash tests/test_installer.sh
CI=true bash tests/test_vm_*.sh

# Build ISO
cd docker && lb config --distribution trixie --architectures amd64 --binary-images iso-hybrid && lb build

# ShellCheck
shellcheck include/usr/local/bin/installer/install-system
```

## SUB-DIRECTORY GUIDES
- `tests/AGENTS.md` - Test patterns and execution
- `components/AGENTS.md` - Installer phase details

---

**See also:** `tests/AGENTS.md`, `components/AGENTS.md`
