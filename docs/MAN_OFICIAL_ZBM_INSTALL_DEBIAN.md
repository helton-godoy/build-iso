# Guia de Instalação Debian Bookworm (UEFI) com ZFSBootMenu

> **Fonte:** Adaptado da [documentação oficial do ZFSBootMenu](https://docs.zfsbootmenu.org/en/v3.1.x/guides/debian/uefi.html)

## 1. Preparação do Ambiente Live

Para instalar o Debian com ZFS na raiz, você precisa de um ambiente "Live" que suporte ZFS.

1. Baixe a imagem **Debian Live** padrão (ou utilize um ambiente como Ubuntu Live, desde que instale o ZFS).
2. Grave a imagem em um pen drive e inicie o computador no modo **UEFI**.
3. Abra um terminal e torne-se root:

```bash
sudo -i
```

### 1.1 Configurar Rede e Repositórios

Você precisará de acesso à internet. No ambiente live do Debian, configure o `apt` para permitir repositórios `contrib` e `non-free`, necessários para o ZFS.

```bash
# Identificar a versão do sistema
source /etc/os-release
export ID

# Editar sources.list para adicionar contrib e non-free-firmware
sed -i 's/main/main contrib non-free-firmware/g' /etc/apt/sources.list

apt update
apt install --yes debootstrap gdisk dkms zfsutils-linux curl dosfstools
```

### 1.2 Gerar /etc/hostid

```bash
zgenhostid -f 0x00bab10c
```

## 2. Preparação do Disco

Identifique o seu disco e defina variáveis.

```bash
# Listar discos disponíveis
ls -la /dev/disk/by-id/

# Defina a variável para o seu disco (ALTERE ISTO para o seu disco real)
# Use sempre /dev/disk/by-id/ para garantir consistência
export DISK=/dev/disk/by-id/ID_DO_SEU_DISCO

# Definir variáveis para partições
export BOOT_DISK="${DISK}"
export BOOT_PART="1"
export BOOT_DEVICE="${DISK}-part1"
export POOL_DEVICE="${DISK}-part2"
```

### 2.1 Limpar e Particionar

```bash
# Limpar tabela de partição antiga
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"

# Partição 1: EFI (1GB)
sgdisk -n "${BOOT_PART}:1m:+1g" -t "${BOOT_PART}:ef00" "$DISK"

# Partição 2: ZFS (Restante do disco)
sgdisk -n "2:0:-10m" -t "2:bf00" "$DISK"
```

## 3. Criação do ZFS Pool

### 3.1 Pool Sem Criptografia

```bash
zpool create -f -o ashift=12 \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -o autotrim=on \
    -o compatibility=openzfs-2.3-linux \
    -m none \
    zroot "$POOL_DEVICE"
```

### 3.2 Pool Com Criptografia Nativa (Opcional)

> **Nota:** O comando abaixo solicitará uma passphrase. Esta será a senha necessária para descriptografar seu disco no boot.

```bash
# Criar arquivo de chave (será armazenado no initramfs)
echo 'SuaPassphrase' > /etc/zfs/zroot.key
chmod 000 /etc/zfs/zroot.key

zpool create -f -o ashift=12 \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -O encryption=aes-256-gcm \
    -O keylocation=file:///etc/zfs/zroot.key \
    -O keyformat=passphrase \
    -o autotrim=on \
    -o compatibility=openzfs-2.3-linux \
    -m none \
    zroot "$POOL_DEVICE"
```

### 3.3 Criar Datasets (File Systems)

O ZFSBootMenu requer uma estrutura específica para gerenciar Boot Environments.

```bash
# Container para sistemas operacionais
zfs create -o mountpoint=none zroot/ROOT

# Sistema raiz do Debian (Boot Environment)
# IMPORTANTE: canmount=noauto é obrigatório para BEs
zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/${ID}

# Dataset para /home
zfs create -o mountpoint=/home zroot/home

# Definir bootfs (obrigatório para ZFSBootMenu)
zpool set bootfs=zroot/ROOT/${ID} zroot
```

> **Importante:** A propriedade `canmount=noauto` é **obrigatória** em qualquer dataset com `mountpoint=/`. Sem ela, o SO tentará automontar todos os datasets ZFS e falhará.

### 3.4 Exportar e Reimportar

```bash
zpool export zroot
zpool import -N -R /mnt zroot

# Se usou criptografia:
zfs load-key -L prompt zroot

zfs mount zroot/ROOT/${ID}
zfs mount -a

# Atualizar symlinks de dispositivos
udevadm trigger
```

Verifique:

```bash
mount | grep zroot
```

## 4. Instalação do Sistema Base

```bash
debootstrap ${ID} /mnt
```

## 5. Configuração Pré-Chroot

```bash
# Copiar hostid (essencial para ZFS)
cp /etc/hostid /mnt/etc/hostid

# Copiar chave de criptografia (se usada)
mkdir -p /mnt/etc/zfs
cp /etc/zfs/zroot.key /mnt/etc/zfs/ 2>/dev/null || true

# Copiar resolv.conf para ter rede no chroot
cp /etc/resolv.conf /mnt/etc/resolv.conf
```

### 5.1 Montar Diretórios de Sistema

```bash
mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -B /dev /mnt/dev
mount -t devpts pts /mnt/dev/pts
```

### 5.2 Entrar no Chroot

```bash
chroot /mnt /bin/bash --login
export ID=bookworm  # Redefinir no chroot
```

---

## ⚠️ A partir daqui, todos os comandos são executados DENTRO do novo sistema.

### 5.3 Configuração Básica

```bash
# Hostname
echo "zfsbootmenu-pc" > /etc/hostname
echo "127.0.1.1 zfsbootmenu-pc" >> /etc/hosts

# Configurar APT
cat << EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian ${ID} main contrib non-free-firmware
deb http://deb.debian.org/debian ${ID}-updates main contrib non-free-firmware
deb http://security.debian.org/debian-security ${ID}-security main contrib non-free-firmware
EOF

apt update

# Senha de root
passwd
```

## 6. Instalação do Kernel e ZFS

```bash
# Instalar pacotes base
apt install --yes linux-headers-amd64 linux-image-amd64 zfs-initramfs dosfstools

# Configurar DKMS para reconstruir initramfs
echo "REMAKE_INITRD=yes" > /etc/dkms/zfs.conf
```

### 6.1 Habilitar Serviços Systemd ZFS

```bash
systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target
```

### 6.2 Configurar e Reconstruir Initramfs

```bash
# Para criptografia, definir umask restritivo
echo "UMASK=0077" > /etc/initramfs-tools/conf.d/umask.conf

# Reconstruir initramfs (-c para criar)
update-initramfs -c -k all
```

## 7. Instalação do ZFSBootMenu

### 7.1 Definir Propriedades ZFS para Boot

```bash
# Linha de comando do kernel (herdado por todos os BEs)
zfs set org.zfsbootmenu:commandline="quiet" zroot/ROOT
```

### 7.2 Preparar Partição EFI

```bash
mkfs.vfat -F32 "$BOOT_DEVICE"

# Criar entrada no fstab
cat << EOF >> /etc/fstab
$( blkid | grep "$BOOT_DEVICE" | cut -d ' ' -f 2 ) /boot/efi vfat defaults 0 0
EOF

mkdir -p /boot/efi
mount /boot/efi
```

### 7.3 Baixar ZFSBootMenu

```bash
apt install --yes curl

mkdir -p /boot/efi/EFI/ZBM

# Baixar binário EFI pré-compilado oficial
curl -o /boot/efi/EFI/ZBM/VMLINUZ.EFI -L https://get.zfsbootmenu.org/efi

# Criar backup
cp /boot/efi/EFI/ZBM/VMLINUZ.EFI /boot/efi/EFI/ZBM/VMLINUZ-BACKUP.EFI
```

### 7.4 Configurar EFI Boot Manager

```bash
apt install --yes efibootmgr

# Montar efivarfs se necessário
mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true

# Criar entrada de backup (primeira)
efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
    -L "ZFSBootMenu (Backup)" \
    -l '\EFI\ZBM\VMLINUZ-BACKUP.EFI'

# Criar entrada principal (será a primeira na ordem de boot)
efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
    -L "ZFSBootMenu" \
    -l '\EFI\ZBM\VMLINUZ.EFI'
```

## 8. Finalização

### 8.1 Criar Usuário (Opcional)

```bash
apt install --yes sudo
useradd -m -s /bin/bash seu_usuario
passwd seu_usuario
usermod -aG sudo seu_usuario
```

### 8.2 Sair e Reiniciar

```bash
# Sair do chroot
exit

# Desmontar tudo
umount -n -R /mnt

# Exportar pool
zpool export zroot

# Reiniciar
reboot
```

---

## 9. Pós-Instalação

Ao reiniciar:

1. Você verá a tela do **ZFSBootMenu**.
2. Se usou criptografia, ele pedirá a passphrase do pool `zroot`.
3. Após desbloquear, verá o menu com `zroot/ROOT/bookworm`.
4. Um timer de contagem regressiva aparecerá. Pressione `Enter` para iniciar imediatamente ou aguarde.

### Teclas Úteis no ZFSBootMenu

| Tecla    | Ação                              |
| -------- | --------------------------------- |
| `Enter`  | Boot no BE selecionado            |
| `e`      | Editar linha de comando do kernel |
| `p`      | Pool status                       |
| `r`      | Recovery shell                    |
| `Ctrl+D` | Snapshot diff                     |

---

## Referências

- [Documentação Oficial ZFSBootMenu - Debian UEFI](https://docs.zfsbootmenu.org/en/v3.1.x/guides/debian/uefi.html)
- [ZFSBootMenu - Portable EFI](https://docs.zfsbootmenu.org/en/v3.1.x/general/portable.html)
- [ZFSBootMenu - Command Line](https://docs.zfsbootmenu.org/en/v3.1.x/man/zfsbootmenu.7.html)
