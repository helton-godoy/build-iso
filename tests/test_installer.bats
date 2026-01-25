#!/usr/bin/env bats

# test_installer.bats
# Testes de integração para os componentes do instalador

load "test_helper.bash"

setup() {
    setup_test_env
    
    # Mocks globais para evitar falhas de sistema
    validate_root() { return 0; }
    validate_memory() { return 0; }
    validate_zfs_module() { return 0; }
    validate_zfs_commands() { return 0; }
    validate_commands() { return 0; }
    validate_firmware() { echo "uefi"; return 0; }
    ui_spin() { shift; "$@"; }
    ui_alert() { return 0; }
    ui_confirm() { return 0; }
    
    export -f validate_root validate_memory validate_zfs_module validate_zfs_commands 
    export -f validate_commands validate_firmware ui_spin ui_alert ui_confirm
}

teardown() {
    :
}

@test "T01_Validation_Environment" {
    source "${COMPONENTS_DIR}/01-validate.sh"
    validate_root() { return 0; }
    validate_memory() { return 0; }
    validate_zfs_module() { return 0; }
    validate_zfs_commands() { return 0; }
    validate_commands() { return 0; }
    validate_firmware() { echo "uefi"; return 0; }
    export -f validate_root validate_memory validate_zfs_module validate_zfs_commands validate_commands validate_firmware
    export SYSLINUX_MBR="/tmp/mock_gptmbr.bin"
    touch "${SYSLINUX_MBR}"
    run run_installer_validations
    [ "$status" -eq 0 ]
}

@test "T02_ZFS_Pool_Mirror" {
    source "${COMPONENTS_DIR}/03-pool.sh"
    SELECTED_DISKS=("/dev/sda" "/dev/sdb")
    RAID_TOPOLOGY="Mirror"
    POOL_NAME="zroot"
    MOUNT_POINT="/mnt"
    run create_pool
    [ "$status" -eq 0 ]
    assert_called "zpool create -f -o ashift=12.*zroot mirror /dev/sda2 /dev/sdb2"
}

@test "T03_ZFS_Pool_RAIDZ1" {
    source "${COMPONENTS_DIR}/03-pool.sh"
    SELECTED_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc")
    RAID_TOPOLOGY="RAIDZ1"
    POOL_NAME="tank"
    MOUNT_POINT="/mnt"
    run create_pool
    [ "$status" -eq 0 ]
    assert_called "zpool create -f.*tank raidz1 /dev/sda2 /dev/sdb2 /dev/sdc2"
}

@test "T04_ZFS_Pool_Encryption" {
    source "${COMPONENTS_DIR}/03-pool.sh"
    SELECTED_DISKS=("/dev/sda")
    RAID_TOPOLOGY="Single"
    POOL_NAME="secure"
    MOUNT_POINT="/mnt"
    ENCRYPTION="on"
    ENCRYPTION_PASSPHRASE="mysecretpassword"
    run create_pool
    [ "$status" -eq 0 ]
    assert_called "-O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt"
}

@test "T05_Partition_Server" {
    source "${COMPONENTS_DIR}/02-partition.sh"
    SELECTED_DISKS=("/dev/sda")
    PROFILE="Server"
    run partition_disk "/dev/sda"
    [ "$status" -eq 0 ]
    assert_called "sgdisk -n 1:2048:+256M"
}

@test "T06_Partition_Workstation" {
    source "${COMPONENTS_DIR}/02-partition.sh"
    SELECTED_DISKS=("/dev/sda")
    PROFILE="Workstation"
    run partition_disk "/dev/sda"
    [ "$status" -eq 0 ]
    assert_called "sgdisk -n 1:2048:+512M"
}
