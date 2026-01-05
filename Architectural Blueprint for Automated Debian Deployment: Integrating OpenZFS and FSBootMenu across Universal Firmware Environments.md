# Architectural Blueprint for Automated Debian Deployment: Integrating OpenZFS and FSBootMenu across Universal Firmware Environments

The landscape of Linux systems administration has undergone a fundamental transition as storage requirements increasingly demand the advanced data integrity and management features of OpenZFS. While traditional filesystems like EXT4 or XFS have served as the standard for decades, the advent of OpenZFS on Linux has introduced capabilities such as copy-on-write (COW) semantics, transparent compression, and native encryption that traditional volume managers struggle to emulate. However, the primary bottleneck in adopting ZFS as a root filesystem has remained the bootloader. Traditional solutions, most notably GRUB, have historically relied on a subset of ZFS features implemented within the bootloader itself, often leading to situations where upgrading a ZFS pool with modern feature flags renders a system unbootable.[1, 2]

The emergence of ZFSBootMenu (ZBM) provides a robust alternative by leveraging a minimal Linux environment to act as the bootloader, thereby utilizing the full power of the OpenZFS driver to manage the boot process.[2] To address the complexities of deploying such a system, an automated framework for creating a Debian ISO and managing the subsequent installation is necessary. This framework must account for the divergent requirements of legacy BIOS and modern UEFI firmware, ensuring that a single deployment strategy can span the entirety of the x86_64 hardware spectrum.[3, 4]

## The Evolution of the ZFS Bootloader Paradigm

The architectural philosophy of ZFSBootMenu is inspired by the FreeBSD bootloader, which has long offered native integration with ZFS.[2, 5] Unlike GRUB, which must include its own limited ZFS implementation to read the kernel and initramfs from a pool, ZFSBootMenu is a self-contained Linux system.[2, 5] It identifies other Linux kernels and initramfs images within ZFS filesystems by mounting the datasets directly, using the same ZFS drivers that the final operating system will use.[2, 5] This eliminates the "feature lag" inherent in GRUB and allows administrators to enable new ZFS features as soon as they are available in the kernel.[1, 5]

### The Role of Kexec in System Transitions

The mechanism by which ZFSBootMenu transitions control to the target operating system is the `kexec` system call. In essence, `kexec` allows a running Linux kernel to load another kernel and initramfs into memory and jump to it without performing a hardware reset.[2, 5] This approach is particularly advantageous for ZFS-on-root systems because it ensures that the bootloader has already successfully imported the pool and verified the presence of the necessary boot artifacts before the final handoff occurs.[2, 5]

The ZFSBootMenu environment handles the complexity of discovering boot environments (BEs). It scans all importable pools for datasets with a `mountpoint` property of `/` or datasets where `mountpoint=legacy` and the custom ZFS property `org.zfsbootmenu:active` is set to `on`.[6] This discovery logic allows for the coexistence of multiple distributions or versions of the same operating system within a single pool, which ZFSBootMenu presents to the user via an interactive menu.[5, 6]

### Comparison of Bootloader Architectures for ZFS

| Feature                   | GRUB                            | ZFSBootMenu                   |
| ------------------------- | ------------------------------- | ----------------------------- |
| **ZFS Driver Source**     | Custom/Subset                   | Full Linux ZFS Module [5]     |
| **Feature Flag Support**  | Limited (often lags behind) [1] | Complete and Immediate [2, 5] |
| **Boot Environments**     | Manual/Clunky                   | Native and Automated [5, 7]   |
| **Native Encryption**     | Restricted/Partial              | Fully Supported [2, 8]        |
| **Transition Method**     | Firmware Handoff                | Kexec [5]                     |
| **Configuration Storage** | `/boot/grub/grub.cfg`           | ZFS Dataset Properties [5]    |

## Automated ISO Engineering with Debian Live-Build

The creation of an automated Debian ISO requires a sophisticated build pipeline capable of injecting the necessary ZFS drivers and ZFSBootMenu binaries into a live environment. The `live-build` framework is the standard for this process, allowing for the definition of custom repositories, package lists, and pre-configuration scripts.[9] Projects such as `debian-zfs-live` have refined this process specifically for the ZFS ecosystem.[10]

### The Live-Build Stages and ZFS Integration

Building a Debian ISO involves several distinct stages, each of which must be modified to support ZFS. During the `bootstrap` stage, the basic Debian system is pulled from a mirror.[9] The `chroot` stage is where the critical modifications occur: the `contrib` and `non-free` repositories are added to enable the installation of `zfs-dkms` and `zfsutils-linux`.[11] Because ZFS is an out-of-tree kernel module, the ISO build must account for the compilation of these modules using Dynamic Kernel Module Support (DKMS).[1, 11]

The automated build process must also include the `zfsbootmenu` package or its pre-built binaries to facilitate the installation on the target hardware.[5] For the ISO to be useful as an installer, it should include automation scripts—such as those found in the `soupdiver/zbm-easy-install` or `NLaundry/zfsbootmenu-autoinstaller` repositories—pre-staged in the filesystem.[12, 13] These scripts act as the bridge between the live environment and the persistent installation on the target disk.[12, 13]

### Architecture of the Installer Script

The installer script is the core of the automation project. It must be capable of hardware detection, disk partitioning, pool creation, and operating system bootstrapping.[11, 13] The `zbm-easy-install` project, for example, utilizes a Python-based CLI to allow users to define boot and pool disks, hostnames, and passwords.[12]

The logic of such a script follows a predictable yet complex path. It begins by wiping existing partition tables using `wipefs` and `sgdisk --zap-all` to ensure a clean state.[14] It then proceeds to partition the disk using a layout that supports both legacy BIOS and UEFI.[14, 15]

## Universal Boot Support: Hybrid Partitioning and Firmware Logic

To satisfy the requirement of supporting both UEFI and legacy BIOS systems, the automation must implement a hybrid boot strategy. This is primarily achieved through the use of the GUID Partition Table (GPT) in conjunction with specific partition types that satisfy the differing requirements of the two firmware standards.[15, 16]

### The GPT Layout for Hybrid Boot

While UEFI requires an EFI System Partition (ESP) with a FAT32 filesystem, legacy BIOS requires a location to store the second stage of its bootloader if the disk is GPT-formatted.[15] This is resolved by creating a BIOS Boot Partition (Type Code `EF02`).[16]

| Partition     | Size      | Type Code | Filesystem | Purpose                                           |
| ------------- | --------- | --------- | ---------- | ------------------------------------------------- |
| **BIOS Boot** | 1 MiB     | `EF02`    | None (Raw) | GRUB/Syslinux stage 2 for legacy BIOS [16]        |
| **ESP**       | 512 MiB   | `EF00`    | VFAT/FAT32 | UEFI executables and ZFSBootMenu bundles [11, 14] |
| **ZFS Pool**  | Remaining | `BF00`    | ZFS        | Operating system and data storage [11, 14]        |

Automation scripts must detect the current boot mode of the live ISO to determine which bootloader pathway to initialize.[17] This detection is typically done by checking for the existence of `/sys/class/efivars`.[17] However, a truly universal installer will configure *both* methods regardless of the current boot mode, allowing the resulting disk to be portable across different hardware.[5, 7]

### Legacy BIOS Implementation with Syslinux and Extlinux

For legacy BIOS support, the automation tool must install a bootloader that can bridge the gap between the BIOS MBR and the ZFSBootMenu kernel.[16] Syslinux is a common choice for this role. The automation process creates an EXT4 partition—often separate or nested—to hold the Syslinux binaries and the ZBM kernel/initramfs pair.[16] The `extlinux` command is used to install the bootloader to this partition, and `dd` is used to write the Syslinux MBR code to the disk's first 440 bytes.[16]

This legacy pathway ensures that even hardware from the pre-UEFI era can leverage the benefits of ZFSBootMenu.[5, 16] The ZFSBootMenu project provides specific guides for this configuration, often involving the `vmlinuz-bootmenu` and `initramfs-bootmenu.img` artifacts.[5, 16]

## ZFS Pool Engineering and Dataset Strategy

The creation of the ZFS pool is the most critical step in ensuring long-term system stability and compatibility with ZFSBootMenu.[11, 14] The automation must handle pool creation with a focus on feature flag compatibility and a logical dataset hierarchy.[6, 11]

### Feature Flag Management and Compatibility

To ensure that ZFSBootMenu can always import the root pool, automation scripts use compatibility sets during pool creation.[11, 14] The `-o compatibility=openzfs-2.2-linux` flag is a conservative and highly recommended choice.[11, 14] This prevents the pool from automatically enabling new features that might not yet be supported by the specific version of ZFSBootMenu being deployed.[3, 14]

The automation must also configure the `ashift` property, typically set to `12` for modern 4K sector drives, to ensure optimal performance.[14] The `canmount=off` property is set on the root dataset of the pool to ensure that it serves only as a container for other datasets, preventing accidental file creation at the top level.[11]

### Hierarchical Dataset Design for Boot Environments

ZFSBootMenu relies on a specific dataset hierarchy to manage different operating system versions or snapshots.[5, 6] The standard practice, followed by tools like `zfsbootmenu-autoinstaller`, is to create a `ROOT` dataset under which individual boot environments are placed.[18]

| Dataset Path        | Mountpoint   | Properties                                                 |
| ------------------- | ------------ | ---------------------------------------------------------- |
| `zroot`             | `none`       | `canmount=off`, `compression=zstd` [5, 11]                 |
| `zroot/ROOT`        | `none`       | `canmount=off`, `org.zfsbootmenu:commandline="quiet"` [18] |
| `zroot/ROOT/debian` | `/`          | `relatime=on`, `xattr=sa` [11, 19]                         |
| `zroot/home`        | `/home`      | `com.sun:auto-snapshot=true` [14]                          |
| `zroot/home/user`   | `/home/user` | User-specific data and encryption [20]                     |

This structure allows the property `org.zfsbootmenu:commandline` to be set at the `ROOT` level and inherited by all child boot environments, ensuring a consistent set of kernel parameters across different versions of the OS.[5, 18]

## Security and Native Encryption Automation

A primary advantage of ZFS on root is the ability to use native encryption.[2, 5] The automation framework must streamline the creation of encrypted datasets and the subsequent key management.[8, 14]

### Native Encryption Workflow

During the automated installation, the script prompts the user for an encryption passphrase. This passphrase is used to create the `ROOT` dataset with encryption enabled: `zfs create -o encryption=on -o keyformat=passphrase -o keylocation=prompt zroot/ROOT`.[14, 18] By setting `keylocation=prompt`, the administrator ensures that ZFSBootMenu will intercept the boot sequence and provide a secure console prompt to unlock the pool.[14, 18]

For remote or headless servers, the automation can be extended to include `dropbear` in the ZFSBootMenu initramfs.[8, 21] This allows the administrator to SSH into the bootloader environment and provide the passphrase remotely, a feature that is essential for data center deployments.[8, 21]

### Handling Multiple Encrypted Datasets

Automation also solves the problem of multiple passphrase prompts. By configuring child datasets to inherit encryption from a parent that has already been unlocked by ZFSBootMenu, or by using a key file that is stored within the now-unlocked root dataset, the system can boot to a full graphical or multi-user environment with only a single manual intervention.[14, 20]

## Boot Environment Management and Atomic Updates

One of the most powerful features enabled by ZFSBootMenu is the ability to perform atomic system updates through the use of Boot Environments (BEs).[5, 7]

### The Lifecycle of a Boot Environment

The automation project should include utilities for managing the BE lifecycle. When an update is performed, the script creates a snapshot of the current root: `zfs snapshot zroot/ROOT/debian@2025-01-01`.[2, 7] It then clones this snapshot to a new dataset: `zfs clone zroot/ROOT/debian@2025-01-01 zroot/ROOT/debian-new`.[7] The update is then applied within the `debian-new` environment via `chroot`.[11]

If the update is successful, the `bootfs` property of the pool is updated to point to the new BE: `zpool set bootfs=zroot/ROOT/debian-new zroot`.[5, 18] If it fails, the system can be rolled back simply by selecting the original `debian` BE in the ZFSBootMenu interface at the next boot.[2, 7]

### Snapshot Pruning and Data Retention

To prevent the ZFS pool from becoming cluttered, automation must include a policy for snapshot retention.[7, 8] Tools like `sanoid` can be automated to prune snapshots based on age and type, ensuring that only a relevant window of bootable system states is maintained.[7]

## Advanced Automation: Custom Hooks and Remote Access

The extensibility of ZFSBootMenu allows for the integration of custom hooks that can perform actions before or after the pool is imported.[3, 22] An automation project can leverage these hooks to add significant value to the deployment.

### Implementing Early-Setup Hooks

Hooks are scripts placed in the `early-setup.d` directory of the ZFSBootMenu initramfs.[3, 23] These can be used for various purposes, such as:

1. **LUKS Unlocking:** If ZFS is stored within LUKS containers, a hook can prompt for the LUKS   passphrase before ZBM attempts to import the ZFS pool.[23]

2. **Hardware Initialization:** Hooks can ensure that specific drivers (e.g., for niche storage controllers) are loaded before the pool scan occurs.[3]

3. **Remote VPN Access:** Integration with Tailscale or other VPNs can be achieved through hooks,   allowing the ZBM environment to join a secure network for remote    management.[24]

The automation script must handle the inclusion of these hooks during the ZFSBootMenu image generation process, typically by placing them in the `hooks` subdirectory and running `zbm-builder.sh`.[22, 23]

## ZBM-Builder and Containerized Workflows

For the creation of the ZFSBootMenu images themselves, the use of OCI containers (Docker or Podman) is highly recommended for automation.[22] The `zbm-builder.sh` script acts as a wrapper for these containers, ensuring that the bootloader is built in a clean, reproducible environment that is independent of the host's operating system.[22] This is a critical component of a "DevOps" approach to OS deployment, as it allows the bootloader to be treated as a versioned artifact.[4, 22]

## Troubleshooting the Automated Deployment

Despite the power of automation, hardware quirks—particularly in the UEFI space—can introduce challenges.[4, 17] A comprehensive report must address these potential failure points and the mechanisms provided by ZFSBootMenu to resolve them.

### Firmware Incompatibility and UEFI Variables

Some UEFI implementations, particularly those from vendors like Dell, are known to have buggy EFI variable support, often failing to respect the boot order set by `efibootmgr`.[4] The automation framework should mitigate this by installing a secondary boot manager like `rEFInd` or by creating a "Unified Kernel Image" (UKI) that is placed in the fallback boot path: `/EFI/BOOT/BOOTX64.EFI`.[4, 22]

### Hostid Mismatches and Pool Protection

ZFS uses the `hostid` to track which system "owns" a pool.[11, 14] If a pool is moved to new hardware or the `hostid` changes, ZFS will refuse to import the pool without a "force" flag.[14] ZFSBootMenu 2.3+ includes enhancements to handle these mismatches more gracefully, but the automation script must ensure that the `/etc/hostid` is consistent between the live ISO, the ZBM image, and the final Debian installation.[3, 14]

## Optimization and Performance Tuning for Debian on ZFS

An automated project should not merely install the OS but also optimize it for the target hardware.[14] This involves setting specific ZFS properties and kernel parameters during the installation phase.[5, 19]

### Kernel Parameter Optimization

The `org.zfsbootmenu:commandline` property should be populated with parameters that improve the boot experience and system performance.[5, 18] For example:

• `elevator=noop` or `elevator=none`: Recommended for ZFS, which performs its own I/O scheduling.[18]

• `zfs.zfs_arc_max`: Can be used to limit the memory usage of the ZFS Adaptive Replacement Cache (ARC), which is particularly important on systems with limited RAM.[1]

• `zbm.waitfor`: A ZFSBootMenu-specific parameter that tells the bootloader to wait for certain device nodes to appear before scanning for pools, useful for slow USB or network-attached storage.[3]

### Dataset Tuning for Specific Workloads

Automation can apply specific ZFS properties based on the intended use of a dataset.[14] For instance, a dataset intended for a database might have a smaller `recordsize` to match the database's page size, while a dataset for media storage might use a larger `recordsize` to improve compression ratios and sequential read speeds.[5, 14]

| Workload Type        | Recordsize | Compression | Special Property        |
| -------------------- | ---------- | ----------- | ----------------------- |
| **General OS**       | 128k       | zstd        | `xattr=sa` [19]         |
| **Database**         | 8k - 16k   | lz4         | `primarycache=metadata` |
| **Media/Archive**    | 1M         | zstd-19     | `atime=off` [14]        |
| **Virtual Machines** | 64k        | lz4         | `volblocksize=64k`      |

## The Future of ZFS-on-Root Deployment

As the OpenZFS project continues to mature, new features like Redaction, Device Removal, and Improved Sequential Resilver are becoming standard.[1, 3] The decoupling of the bootloader from the OS via ZFSBootMenu ensures that Debian systems can take advantage of these features as soon as the kernel supports them, without waiting for bootloader updates.[1, 5]

The move toward Unified Kernel Images (UKIs) and Secure Boot is the next frontier for ZFSBootMenu automation.[4, 5] By signing the ZFSBootMenu EFI bundle and enrolling the public key in the system's UEFI firmware, administrators can achieve a fully verified boot path from the firmware to the ZFS root.[5] This level of security, combined with the power of ZFS, represents the pinnacle of modern Linux system design.

## Conclusion

The project to automate the creation of a Debian ISO for ZFS-on-root installations with ZFSBootMenu support is an ambitious but highly rewarding endeavor. It requires a deep understanding of the Linux boot process, the nuances of ZFS pool management, and the complexities of modern and legacy hardware firmware.[5, 11, 16] By leveraging existing tools like `live-build`, `debootstrap`, and the `zbm-builder` container, administrators can create a deployment pipeline that is both reproducible and resilient.[9, 13, 22]

Whether deploying on a legacy workstation or a state-of-the-art UEFI server, the combination of Debian and ZFSBootMenu provides a level of flexibility and data protection that is unmatched by traditional installation methods.[2, 5, 7] The ability to manage snapshots, roll back updates, and maintain multiple boot environments directly from the bootloader transforms the operating system from a static installation into a dynamic, manageable resource.[5, 7] As automation scripts continue to evolve, this advanced configuration will become increasingly accessible to the broader Linux community, setting a new standard for professional-grade deployments.

--------------------------------------------------------------------------------

1. boot on ZFS no longer works with Debian's GRUB after "zpool upgrade"?, [https://unix.stackexchange.com/questions/799134/boot-on-zfs-no-longer-works-with-debians-grub-after-zpool-upgrade](https://www.google.com/url?sa=E&q=https%3A%2F%2Funix.stackexchange.com%2Fquestions%2F799134%2Fboot-on-zfs-no-longer-works-with-debians-grub-after-zpool-upgrade)

2. zbm-dev/zfsbootmenu:   ZFS bootloader for root-on-ZFS systems with support for snapshots and    native full disk encryption - GitHub, [https://github.com/zbm-dev/zfsbootmenu](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgithub.com%2Fzbm-dev%2Fzfsbootmenu)

3. Releases · zbm-dev/zfsbootmenu - GitHub, [https://github.com/zbm-dev/zfsbootmenu/releases](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgithub.com%2Fzbm-dev%2Fzfsbootmenu%2Freleases)

4. UEFI Booting — ZFSBootMenu 3.0.1 documentation, [https://docs.zfsbootmenu.org/en/v3.0.x/general/uefi-booting.html](https://www.google.com/url?sa=E&q=https%3A%2F%2Fdocs.zfsbootmenu.org%2Fen%2Fv3.0.x%2Fgeneral%2Fuefi-booting.html)

5. Overview — ZFSBootMenu 3.1.0 documentation, [https://zfsbootmenu.org/](https://www.google.com/url?sa=E&q=https%3A%2F%2Fzfsbootmenu.org%2F)

6. Boot Environments and You: A Primer — ZFSBootMenu 3.0.1 documentation, [https://docs.zfsbootmenu.org/en/v3.0.x/general/bootenvs-and-you.html](https://www.google.com/url?sa=E&q=https%3A%2F%2Fdocs.zfsbootmenu.org%2Fen%2Fv3.0.x%2Fgeneral%2Fbootenvs-and-you.html)

7. ZBM 101: Introduction to ZFSBootMenu - Klara Systems, [https://klarasystems.com/articles/zbm-101-introduction-to-zfsbootmenu/](https://www.google.com/url?sa=E&q=https%3A%2F%2Fklarasystems.com%2Farticles%2Fzbm-101-introduction-to-zfsbootmenu%2F)

8. Prebuilt ZFSBootMenu + Debian + legacy boot + encrypted root tutorial? And other ZBM Questions... : r/zfs - Reddit, [https://www.reddit.com/r/zfs/comments/1orrwve/prebuilt_zfsbootmenu_debian_legacy_boot_encrypted/](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwww.reddit.com%2Fr%2Fzfs%2Fcomments%2F1orrwve%2Fprebuilt_zfsbootmenu_debian_legacy_boot_encrypted%2F)

9. Proxmox VE Live System build - free-pmx, [https://free-pmx.org/guides/live-build/](https://www.google.com/url?sa=E&q=https%3A%2F%2Ffree-pmx.org%2Fguides%2Flive-build%2F)

10. B0F1B0 - GitHub, [https://github.com/B0F1B0](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgithub.com%2FB0F1B0)

11. Debian (UEFI) — ZFSBootMenu 3.0.1 documentation, [https://docs.zfsbootmenu.org/en/v3.0.x/guides/debian/uefi.html](https://www.google.com/url?sa=E&q=https%3A%2F%2Fdocs.zfsbootmenu.org%2Fen%2Fv3.0.x%2Fguides%2Fdebian%2Fuefi.html)

12. soupdiver/zbm-easy-install: The goal is to provide an easy ... - GitHub, [https://github.com/soupdiver/zbm-easy-install](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgithub.com%2Fsoupdiver%2Fzbm-easy-install)

13. NLaundry/zfsbootmenu-autoinstaller - GitHub, [https://github.com/NLaundry/zfsbootmenu-autoinstaller](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgithub.com%2FNLaundry%2Fzfsbootmenu-autoinstaller)

14. Alpine Linux (UEFI) — ZFSBootMenu 3.0.1 documentation, [https://docs.zfsbootmenu.org/en/v3.0.x/guides/alpine/uefi.html](https://www.google.com/url?sa=E&q=https%3A%2F%2Fdocs.zfsbootmenu.org%2Fen%2Fv3.0.x%2Fguides%2Falpine%2Fuefi.html)

15. Switch Debian from legacy to UEFI boot mode - Jens Getreu's blog, [https://blog.getreu.net/projects/legacy-to-uefi-boot/](https://www.google.com/url?sa=E&q=https%3A%2F%2Fblog.getreu.net%2Fprojects%2Flegacy-to-uefi-boot%2F)

16. Void Linux (SYSLINUX MBR) — ZFSBootMenu 3.0.1 documentation, [https://docs.zfsbootmenu.org/en/v3.0.x/guides/void-linux/syslinux-mbr.html](https://www.google.com/url?sa=E&q=https%3A%2F%2Fdocs.zfsbootmenu.org%2Fen%2Fv3.0.x%2Fguides%2Fvoid-linux%2Fsyslinux-mbr.html)

17. UEFI installation always fail · zbm-dev zfsbootmenu · Discussion #297 - GitHub, [https://github.com/zbm-dev/zfsbootmenu/discussions/297](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgithub.com%2Fzbm-dev%2Fzfsbootmenu%2Fdiscussions%2F297)

18. Chimera Linux (UEFI) — ZFSBootMenu 3.0.1 documentation, [https://docs.zfsbootmenu.org/en/v3.0.x/guides/chimera/uefi.html](https://www.google.com/url?sa=E&q=https%3A%2F%2Fdocs.zfsbootmenu.org%2Fen%2Fv3.0.x%2Fguides%2Fchimera%2Fuefi.html)

19. Void Linux (UEFI) — ZFSBootMenu 3.1.0 documentation, [https://docs.zfsbootmenu.org/en/latest/guides/void-linux/uefi.html](https://www.google.com/url?sa=E&q=https%3A%2F%2Fdocs.zfsbootmenu.org%2Fen%2Flatest%2Fguides%2Fvoid-linux%2Fuefi.html)

20. 3CX - DistroWatch.com: Put the fun back into computing. Use Linux, BSD., [https://distrowatch.com/?distribution=&month=January&year=all](https://www.google.com/url?sa=E&q=https%3A%2F%2Fdistrowatch.com%2F%3Fdistribution%3D%26month%3DJanuary%26year%3Dall)

21. ZFSBootMenu -- encrypted root on remote Debian server? - Practical ZFS, [https://discourse.practicalzfs.com/t/zfsbootmenu-encrypted-root-on-remote-debian-server/2193/5](https://www.google.com/url?sa=E&q=https%3A%2F%2Fdiscourse.practicalzfs.com%2Ft%2Fzfsbootmenu-encrypted-root-on-remote-debian-server%2F2193%2F5)

22. Can't boot my Alienware M18 · zbm-dev zfsbootmenu · Discussion ..., [https://github.com/zbm-dev/zfsbootmenu/discussions/689](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgithub.com%2Fzbm-dev%2Fzfsbootmenu%2Fdiscussions%2F689)

23. agorgl/zbm-luks-unlock: A custom build of ZFSBootMenu to allow unlocking and using zfs pools residing in luks volumes - GitHub, [https://github.com/agorgl/zbm-luks-unlock](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgithub.com%2Fagorgl%2Fzbm-luks-unlock)

24. rescue · GitHub Topics, [https://github.com/topics/rescue?l=shell&o=desc&s=forks](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgithub.com%2Ftopics%2Frescue%3Fl%3Dshell%26o%3Ddesc%26s%3Dforks)
