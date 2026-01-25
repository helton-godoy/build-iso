# Debian ZFS Installer - Technical Documentation

An advanced, modular, and resilient installer for Debian Trixie (testing) with Root-on-ZFS and ZFSBootMenu. This project replaces legacy `whiptail`/`dialog` interfaces with modern `gum` components.

## 🌟 Key Features

- **Root-on-ZFS**: Native ZFS boot support (no ext4 /boot required for ZFSBootMenu).
- **ZFSBootMenu**: Boot Environments (snapshots), rollbacks, and recovery pre-boot.
- **Modern UI**: Built with [Charm's Gum](https://github.com/charmbracelet/gum) for a beautiful terminal experience.
- **Modular Design**: Separated concerns (UI, Logic, Logging, error handling).
- **Atomic Rollback**: Automatic cleanup on failure to ensure system consistency.
- **Automated Testing**: `bats-core` integrated for reliability.

## 📂 Architecture

The installer is located at `/usr/local/bin/installer` in the live system.

```
installer/
├── components/          # Installation phases
│   ├── 01-validate.sh   # Pre-flight checks
│   ├── 02-partition.sh  # Disk preparation
│   ├── 03-pool.sh       # ZFS Pool creation
│   ├── ...
│   └── 08-cleanup.sh    # Finalization
├── lib/
│   ├── logging.sh       # Structured logging
│   ├── validation.sh    # Input validation
│   └── error.sh         # Trap & Rollback mechanism
└── README.md            # This file
```

## 🚀 Usage

The installer is pre-baked into the ISO. To run it:

```bash
sudo install-system
```

### Installation Workflow

1. **Disk Selection**: Dynamic lists of drives (nvme/sata).
2. **Profile**: Server (minimal) or Workstation (GUI).
3. **ZFS Config**: RAIDZ/Mirror selection, encryption setup (if available).
4. **Execution**: Review summary and execute components sequentially.

## 🛡️ Robustness & Recovery

### Error Handling

The system uses `set -euo pipefail` standard. A global `trap` catches any non-zero exit code during the installation phases.

### Atomic Rollback

Based on the `INSTALL_STATE`, the system decides how to revert:

- **PREP**: No action.
- **POOL_CREATED**: Exports and destroys the partial pool.
- **DATASETS_CREATED**: Unmounts targets and destroys pool.

## 🛠️ Development

### Prerequisites

- Docker (for building the ISO)
- `bats-core` (for testing)

### Running Tests

Tests are located in `tests/`.

```bash
bats tests/test_installer.bats
```

### Building the ISO

Refactored build script:

```bash
./build-debian-trixie-zbm.sh
```

## 📝 Logs

Installation logs are persisted to:

- `/var/log/install-system.log`

Use `tail -f` on this file to debug issues during installation.
