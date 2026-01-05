# ZFSBootMenu Binaries - Download Information

**Updated:** 2025-01-05
**Version:** v3.1.0 (latest)

## Download Endpoints

### Base URL
```
https://get.zfsbootmenu.org/
```

### Available Assets

| Asset | Build | URL | Output Filename |
|-------|-------|-----|-----------------|
| EFI | release | `https://get.zfsbootmenu.org/efi` | `zfsbootmenu-release-x86_64-v3.1.0-linux6.12.EFI` |
| EFI | recovery | `https://get.zfsbootmenu.org/efi/recovery` | `zfsbootmenu-recovery-x86_64-v3.1.0-linux6.12.EFI` |
| Components | release | `https://get.zfsbootmenu.org/components` | `zfsbootmenu-release-x86_64-v3.1.0-linux6.12.tar.gz` |
| Components | recovery | `https://get.zfsbootmenu.org/components/recovery` | `zfsbootmenu-recovery-x86_64-v3.1.0-linux6.12.tar.gz` |

### Other Assets

| Asset | URL | Description |
|-------|-----|-------------|
| SHA256 signatures | `https://get.zfsbootmenu.org/sha256.sig` | GPG signatures |
| SHA256 checksums | `https://get.zfsbootmenu.org/sha256.txt` | Checksum file |
| Source | `https://get.zfsbootmenu.org/source` | Source tarball |
| Builder script | `https://get.zfsbootmenu.org/zbm-builder.sh` | Build script |
| Kernel command line | `https://get.zfsbootmenu.org/zbm-kcl` | CLI tool |

## File Structure

### Components Tarball (release)
```
zfsbootmenu-release-x86_64-v3.1.0-linux6.12.tar.gz
├── vmlinuz-bootmenu              # Linux kernel
├── initramfs-bootmenu.img        # Initramfs
└── EFI/
    ├── BOOT/
    │   └── BOOTX64.EFI          # Fallback bootloader (UEFI)
    └── ZFSBootMenu/
        └── GRUBX64.EFI          # Main bootloader (UEFI)
```

### Components Tarball (recovery)
```
zfsbootmenu-recovery-x86_64-v3.1.0-linux6.12.tar.gz
├── vmlinuz-bootmenu
├── initramfs-bootmenu.img
└── EFI/
    ├── BOOT/
    │   └── BOOTX64.EFI          # Recovery bootloader
    └── ZFSBootMenu/
        └── GRUBX64.EFI
```

## Download Examples

### Using curl
```bash
# Download with project-defined filename
curl -LJO https://get.zfsbootmenu.org/efi
curl -LJO https://get.zfsbootmenu.org/efi/recovery
curl -LJO https://get.zfsbootmenu.org/components

# Download with custom filename
curl -o zfsbootmenu.EFI https://get.zfsbootmenu.org/efi
curl -o zfsbootmenu-recovery.EFI https://get.zfsbootmenu.org/efi/recovery
curl -o zfsbootmenu.tar.gz https://get.zfsbootmenu.org/components
```

### Using wget
```bash
# Download with project-defined filename
wget --content-disposition https://get.zfsbootmenu.org/efi
wget --content-disposition https://get.zfsbootmenu.org/efi/recovery
wget --content-disposition https://get.zfsbootmenu.org/components

# Download with custom filename
wget -O zfsbootmenu.EFI https://get.zfsbootmenu.org/efi
wget -O zfsbootmenu-recovery.EFI https://get.zfsbootmenu.org/efi/recovery
wget -O zfsbootmenu.tar.gz https://get.zfsbootmenu.org/components
```

## Usage in ISO Build

### Extract components
```bash
# Download and extract
curl -LJO https://get.zfsbootmenu.org/components
tar -xzf zfsbootmenu-release-x86_64-v3.1.0-linux6.12.tar.gz

# Copy to ISO build directory
cp vmlinuz-bootmenu /path/to/iso/isolinux/vmlinuz-bootmenu
cp initramfs-bootmenu.img /path/to/iso/isolinux/initramfs-bootmenu.img
mkdir -p /path/to/iso/EFI/BOOT
mkdir -p /path/to/iso/EFI/ZFSBootMenu
cp EFI/BOOT/BOOTX64.EFI /path/to/iso/EFI/BOOT/
cp EFI/ZFSBootMenu/GRUBX64.EFI /path/to/iso/EFI/ZFSBootMenu/
```

### Direct EFI download (simpler)
```bash
# Download and place EFI directly
curl -LJO https://get.zfsbootmenu.org/efi/recovery
cp zfsbootmenu-recovery-x86_64-v3.1.0-linux6.12.EFI /path/to/iso/EFI/BOOT/BOOTX64.EFI
```

## Version Detection

To programmatically detect the latest version:
```bash
# Get version from redirect headers
VERSION=$(curl -sI https://get.zfsbootmenu.org/efi | grep -i location | grep -oP 'v\d+\.\d+\.\d+' | head -1)
echo "Latest ZFSBootMenu version: $VERSION"
```

## Signature Verification

```bash
# Download assets and signatures
curl -LJO https://get.zfsbootmenu.org/components
curl -o sha256.sig https://get.zfsbootmenu.org/sha256.sig
curl -o sha256.txt https://get.zfsbootmenu.org/sha256.txt

# Verify GPG signature (requires ZFSBootMenu GPG key)
gpg --verify sha256.sig sha256.txt

# Verify checksums
sha256sum -c sha256.txt
```

## References

- ZFSBootMenu Download: https://get.zfsbootmenu.org/
- Signature Verification: https://docs.zfsbootmenu.org/en/latest/general/verification.html
- GitHub Releases: https://github.com/zbm-dev/zfsbootmenu/releases
