Esta é uma estrutura profissional e modular. Vamos organizar o diretório do projeto e criar o "maestro" (o script principal) que gerencia esse carregamento dinâmico.

Estrutura de Diretórios Recomendada

```text
/install-zfs/
├── install-system.sh             # Maestro (Script Principal)
├── disks-identify.sh             # Identifica hardware e define as libs
└── libs/                         # Pasta com as bibliotecas específicas
    ├── prepare-disks-single.sh
    ├── prepare-disks-mirror.sh
    ├── prepare-disks-raidz1.sh
    └── ... (demais tipos)
```

Use o código com cuidado.

---

1. O Maestro: `install-system.sh`

Este script coordena o fluxo, carrega as libs e executa a instalação.

```bash
#!/bin/bash

# Variáveis Globais (visíveis para todas as libs carregadas via source)
export POOL_NAME="rpool"
export DISKS=($(lsblk -dn -o NAME,TYPE | grep disk | awk '{print $1}'))
export NUM_DISKS=${#DISKS[@]}

# 1. Identificação e Carregamento Dinâmico
echo "--- Iniciando Identificador de Discos ---"
# O script de identificação vai retornar quais libs carregar
# com base em $NUM_DISKS
source ./disks-identify-suporte-types.sh

# 2. Exibição do Menu (As funções abaixo foram carregadas via source)
echo "Opções disponíveis para $NUM_DISKS disco(s):"
display_available_options

read -p "Selecione a opção: " OPCAO

# 3. Execução da Lógica Selecionada
case $OPCAO in
    1) execute_selection ;; # A lib carregada define o que execute_selection faz
    *) echo "Opção inválida"; exit 1 ;;
esac
```

---

2. O Identificador: `disks-identify-suporte-types.sh`

Este arquivo decide quais fontes de lógica serão incluídas no ambiente.

```bash
#!/bin/bash

# Limpa funções anteriores para evitar conflitos
display_available_options() { :; } 

case $NUM_DISKS in
    1)
        source ./libs/prepare-disks-single.sh
        display_available_options() {
            show_single_info
        }
        execute_selection() { install_single; }
        ;;
    2)
        # Se 2 discos, carregamos ambas as libs
        source ./libs/prepare-disks-mirror.sh
        source ./libs/prepare-disks-stripe.sh
        display_available_options() {
            show_mirror_info
            show_stripe_info
        }
        execute_selection() {
            # Se houver mais de uma, aqui você decide qual chamar 
            # (ou cria uma lógica de sub-menu)
            [[ "$OPCAO" == "1" ]] && install_mirror || install_stripe
        }
        ;;
    3)
        source ./libs/prepare-disks-raidz1.sh
        # ... e assim por diante
        ;;
esac
```

---

3. Exemplo de uma Lib: `libs/prepare-disks-mirror.sh`

Cada arquivo de lib foca exclusivamente na sua topologia.

```bash
#!/bin/bash

show_mirror_info() {
    echo "1) Mirror (RAID 1): Segurança. Tolera falha de 1 disco."
}

install_mirror() {
    echo "Limpando discos para Mirror..."
    for d in "${DISKS[@]}"; do
        wipefs -a "/dev/$d"
        sgdisk --zap-all "/dev/$d"
    done

    echo "Criando Pool ZFS em Mirror..."
    zpool create -f "$POOL_NAME" mirror "/dev/${DISKS[0]}" "/dev/${DISKS[1]}"

    if [ $? -eq 0 ]; then
        echo "Pool Mirror criado com sucesso!"
    fi
}
```

---

Análise do porquê isso facilita sua vida:

- **Padrão de Interface:** No script principal, você sempre chama `execute_selection`. Não importa se por baixo o comando é um `zpool create mirror` ou um `zpool create raidz2`. O "Maestro" não precisa saber os detalhes.
- **Debug Isolado:** Se o seu script de `RAID-Z3` estiver dando erro, você abre **apenas** o `prepare-disks-raidz3.sh`. O resto do sistema está protegido de erros de sintaxe desse arquivo.
- **Substituição Dinâmica:** Se você detectar que os discos são NVMe, você pode carregar uma lib `prepare-disks-mirror-nvme.sh` que tenha parâmetros de tunning específicos para SSDs, sem alterar o fluxo do instalador.

Para manter o seu projeto organizado, vou apresentar o conteúdo para os arquivos **RAID-Z2** (focado em segurança de nível servidor) e **dRAID** (focado em arrays de alto desempenho e reconstrução rápida).

Note que o **dRAID** possui uma sintaxe ligeiramente diferente, pois exige a definição do número de grupos de dados e redundância distribuída.

---

1. Lib: `libs/prepare-disks-raidz2.sh`

Esta lib é ideal para quando o usuário tem entre **4 e 6 discos** e prioriza a integridade dos dados acima de tudo.

```bash
#!/bin/bash

# Descrição para o Menu
show_raidz2_info() {
    local cap
    # Cálculo: (N - 2) discos de capacidade útil
    cap=$(echo "scale=1; ($NUM_DISKS - 2) * $DISK_SIZE_GB" | bc)
    echo "RAID-Z2 (RAID 6): Tolera a falha de 2 discos SIMULTÂNEOS. Capacidade aprox: ${cap}GB."
}

# Lógica de Instalação
install_raidz2() {
    echo "Iniciando preparação para RAID-Z2 em $NUM_DISKS discos..."

    # Chama uma função comum de limpeza (pode estar na lib-main)
    for d in "${DISKS[@]}"; do
        wipefs -a "/dev/$d"
        sgdisk --zap-all "/dev/$d"
    done

    # Criação do Pool
    # Sintaxe: zpool create [nome] raidz2 [discos...]
    zpool create -f -o ashift=12 \
        -O compression=lz4 \
        -O acltype=posixacl \
        -O xattr=sa \
        -O relatime=on \
        -O normalization=formD \
        "$POOL_NAME" raidz2 "${DISKS[@]}"

    if [ $? -eq 0 ]; then
        echo "Pool RAID-Z2 criado com sucesso!"
    else
        echo "Erro ao criar pool RAID-Z2."
        exit 1
    fi
}
```

---

2. Lib: `libs/prepare-disks-draid.sh`

O **dRAID** (Distributed RAID) é a tecnologia de ponta do OpenZFS para muitos discos. Ele é excelente para o seu caso de **8 a 10 discos ou mais**.

```bash
#!/bin/bash

show_draid_info() {
    echo "dRAID: RAID Distribuído. Reconstrução (resilver) ultrarrápida após falhas."
}

install_draid() {
    echo "Configurando dRAID (Declustered RAID)..."

    for d in "${DISKS[@]}"; do
        wipefs -a "/dev/$d"
        sgdisk --zap-all "/dev/$d"
    done

    # Sintaxe dRAID: draid[paridade]:[data_disks]d:[spares]s
    # Exemplo comum para dRAID2 (equivalente ao RAID-Z2 em paridade)
    # draid2: Suporta 2 falhas, com paridade distribuída em todos os discos.

    echo "Criando Pool dRAID2..."
    zpool create -f -o ashift=12 \
        -O compression=lz4 \
        "$POOL_NAME" draid2 "${DISKS[@]}"

    if [ $? -eq 0 ]; then
        echo "Pool dRAID2 criado com sucesso!"
    else
        echo "Erro ao criar pool dRAID."
        exit 1
    fi
}
```

---

Como o seu `disks-identify-suporte-types.sh` chamaria isso:

Para garantir que o usuário escolha entre RAID-Z2 e dRAID quando tiver muitos discos, seu identificador ficaria assim:

```bash
case $NUM_DISKS in
    # ... outros casos ...
    [8-9]|10)
        source ./libs/prepare-disks-raidz2.sh
        source ./libs/prepare-disks-draid.sh

        display_available_options() {
            echo "1) "; show_raidz2_info
            echo "2) "; show_draid_info
        }

        execute_selection() {
            if [ "$OPCAO" == "1" ]; then
                install_raidz2
            elif [ "$OPCAO" == "2" ]; then
                install_draid
            fi
        }
        ;;
esac
```

Principais Benefícios desta Implementação:

- **Otimização ZFS:** Note que incluí flags como `-o ashift=12` e `-O compression=lz4`. No modelo modular, você pode ajustar essas flags disco a disco sem poluir o script principal.
- **Flexibilidade de Paridade:** No arquivo `draid.sh`, você poderia facilmente mudar para `draid3` se o número de discos for muito alto (ex: 24 discos), apenas alterando aquela lib específica.

Esta é a configuração "padrão ouro" para quem busca **máxima performance de IOPS** (IO por segundo), sendo a escolha preferida para hospedar Máquinas Virtuais (Proxmox/KVM) ou Bancos de Dados no Debian.

O **RAID 10** no ZFS não é um comando único, mas sim um "Stripe de Mirrors" (vários espelhos somados).

---

Lib: `libs/prepare-disks-raid10.sh`

Esta lib deve validar se o número de discos é **par**, pois o RAID 10 exige pares para o espelhamento.

```bash
#!/bin/bash

show_raid10_info() {
    local cap
    # Cálculo: (N / 2) discos de capacidade útil
    cap=$(echo "scale=1; ($NUM_DISKS / 2) * $DISK_SIZE_GB" | bc)
    echo "RAID 10 (Striped Mirrors): Máxima performance de leitura/escrita. Tolera falhas de até 1 disco POR PAR. Capacidade aprox: ${cap}GB."
}

install_raid10() {
    # Validação de segurança: RAID 10 precisa de número par de discos
    if (( NUM_DISKS % 2 != 0 )); then
        echo "Erro: RAID 10 requer um número par de discos. Detectados: $NUM_DISKS"
        exit 1
    fi

    echo "Iniciando preparação para RAID 10 em $NUM_DISKS discos..."

    for d in "${DISKS[@]}"; do
        wipefs -a "/dev/$d"
        sgdisk --zap-all "/dev/$d"
    done

    # Construção dinâmica do comando: zpool create rpool mirror d1 d2 mirror d3 d4...
    local cmd="zpool create -f -o ashift=12 -O compression=lz4 -O xattr=sa -O acltype=posixacl $POOL_NAME"

    for ((i=0; i<NUM_DISKS; i+=2)); do
        cmd+=" mirror /dev/${DISKS[i]} /dev/${DISKS[i+1]}"
    done

    echo "Executando: $cmd"
    eval "$cmd"

    if [ $? -eq 0 ]; then
        echo "Pool RAID 10 criado com sucesso!"
    else
        echo "Erro ao criar pool RAID 10."
        exit 1
    fi
}
```

---

Por que esta lib é especial?

1. **Lógica de Pares:** O loop `for ((i=0; i<NUM_DISKS; i+=2))` agrupa os discos dois a dois automaticamente. Se você tiver 4 discos, ele cria `mirror d1 d2` e depois adiciona `mirror d3 d4` ao mesmo pool (fazendo o *stripe*).
2. **Performance:** Ao contrário do RAID-Z, o RAID 10 não precisa calcular paridade complexa, o que reduz o uso de CPU e elimina o "gargalo de escrita" em blocos pequenos.
3. **Resiliência:** Se um disco falhar, apenas o espelhamento daquele par fica degradado. A reconstrução (*resilver*) é extremamente rápida porque é apenas uma cópia direta bit-a-bit do parceiro sobrevivente.

Integração no Maestro (`disks-identify-suporte-types.sh`):

Para habilitar esta opção apenas quando houver discos suficientes e em número par:

```bash
case $NUM_DISKS in
    4|6|8|10|12)
        # Carrega RAID 10 além de outras opções (como RAID-Z2)
        source ./libs/prepare-disks-raid10.sh
        source ./libs/prepare-disks-raidz2.sh

        display_available_options() {
            echo "1) "; show_raid10_info
            echo "2) "; show_raidz2_info
        }

        execute_selection() {
            [[ "$OPCAO" == "1" ]] && install_raid10 || install_raidz2
        }
        ;;
esac
```

Com essas libs prontas, seu instalador agora cobre desde o usuário doméstico simples até servidores de alta performance.

Para manter a elegância da sua arquitetura modular, essa função deve residir em um arquivo de **configuração global** ou **funções base**. Como o seu maestro `install-system.sh` já exporta a lista de discos, essa função limpará tudo de forma atômica.

1. Criando a Base: `libs/common-utils.sh`

Este arquivo conterá tudo o que é repetitivo. Ao fazer o `source` dele, você garante que todos os scripts de `prepare-disks-*.sh` usem o mesmo padrão de limpeza.

```bash
#!/bin/bash

# Função Universal de Limpeza
prepare_common() {
    echo "--- Preparando mídias de armazenamento ---"

    # Verifica se a variável DISKS existe e não está vazia
    if [[ -z "${DISKS[*]}" ]]; then
        echo "Erro: Nenhuma mídia de armazenamento encontrada para limpeza."
        exit 1
    fi

    for disk in "${DISKS[@]}"; do
        echo "Limpando /dev/$disk..."

        # 1. Remove assinaturas de sistemas de arquivos (evita conflitos de exportação)
        wipefs -a "/dev/$disk" >/dev/null 2>&1

        # 2. Zera a tabela de partição (GPT/MBR)
        sgdisk --zap-all "/dev/$disk" >/dev/null 2>&1

        # 3. Informa o Kernel sobre a mudança na tabela de partições
        partprobe "/dev/$disk"
    done

    echo "Mídias prontas para provisionamento ZFS."
}
```

2. Como as Libs ficam simplificadas

Agora, seus arquivos específicos (como o `prepare-disks-raid10.sh`) não precisam mais de loops de limpeza. Eles ficam muito mais limpos:

```bash
#!/bin/bash

install_raid10() {
    # Chama a função global
    prepare_common 

    echo "Provisionando Striped Mirrors (RAID 10)..."
    # Lógica de criação do pool...
}
```

3. Ajuste no Maestro (`install-system.sh`)

Basta adicionar o `source` da utilidade comum antes de tudo:

```bash
#!/bin/bash
# ... (exportação de variáveis)

# Carrega as ferramentas comuns primeiro
source ./libs/common-utils.sh

# Carrega a lógica baseada na quantidade de discos
source ./disks-identify-suporte-types.sh

# ... (resto do script)
```

Análise Crítica da Limpeza:

- **Segurança:** O uso do `partprobe` após o `sgdisk` é vital. Sem ele, o instalador do Debian pode tentar criar o ZFS em uma tabela de partição que o kernel ainda acha que existe, causando falhas intermitentes.
- **Eficiência:** Centralizar o `wipefs` garante que, se você decidir adicionar uma limpeza mais profunda (como um `dd` nos primeiros MBs do disco no futuro), você alterará **apenas um arquivo** e todos os tipos de instalação (Mirror, RAID-Z, etc.) receberão a atualização.

Para completar seu script, você precisa definir os **Mount Points** padrão do Debian (como `/`, `/boot`, e `/home`) dentro do ZFS após a criação do pool? Isso é o que diferencia uma "instalação de storage" de uma "instalação de sistema operacional".

Para integrar o **ZFSBootMenu** com suporte a BIOS/UEFI, a estrutura de datasets e a hierarquia do pool precisam seguir o padrão de "propriedades de boot" do ZFS. O segredo aqui é que o ZFSBootMenu não lê arquivos no disco; ele lê **datasets** e suas propriedades.

Aqui está a estrutura de datasets e a configuração de boot compatível:

1. Lib: `libs/setup-datasets.sh`

Esta lib será chamada logo após a criação do pool (independente da topologia escolhida).

```bash
#!/bin/bash

setup_zfs_datasets() {
    echo "--- Configurando Hierarquia para ZFSBootMenu ---"

    # 1. Desativa a montagem automática no rpool
    zfs set mountpoint=none "$POOL_NAME"

    # 2. Cria o dataset raiz do sistema (Onde o ZFSBootMenu procura o OS)
    # Usamos 'debian' como identificador, mas pode ser qualquer nome
    zfs create -o mountpoint=none "$POOL_NAME/ROOT"
    zfs create -o mountpoint=/ -o canmount=noauto "$POOL_NAME/ROOT/debian"

    # Define este dataset como o dataset de boot padrão
    zpool set bootfs="$POOL_NAME/ROOT/debian" "$POOL_NAME"

    # 3. Cria datasets de sistema e dados (Seguindo o padrão FHS)
    zfs create -o setuid=off -o mountpoint=/home "$POOL_NAME/home"
    zfs create -o mountpoint=/root "$POOL_NAME/home/root"
    zfs create -o canmount=off -o setuid=off -o exec=off "$POOL_NAME/var"
    zfs create -o com.sun:auto-snapshot=false "$POOL_NAME/var/cache"
    zfs create "$POOL_NAME/var/log"
    zfs create "$POOL_NAME/var/spool"
    zfs create -o com.sun:auto-snapshot=false -o exec=on "$POOL_NAME/var/tmp"

    # 4. Configuração específica para o ZFSBootMenu identificar o Kernel
    # Ele procura por estas propriedades para carregar o initramfs corretamente
    zfs set org.zfsbootmenu:commandline="quiet root=zfs:AUTO" "$POOL_NAME/ROOT/debian"
}
```

2. Estrutura de Particionamento (BIOS + UEFI)

Para que o **Syslinux (BIOS)** e o **ZFSBootMenu (UEFI)** coexistam, a tabela GPT deve ser preparada na lib `common-utils.sh` desta forma:

| Partição      | Tamanho | Tipo   | Uso                                                  |
| ------------- | ------- | ------ | ---------------------------------------------------- |
| 1 (BIOS Boot) | 1MB     | `EF02` | Necessário para o GRUB/Syslinux em GPT/BIOS          |
| 2 (EFI)       | 512MB   | `EF00` | Onde ficará o binário do ZFSBootMenu (`vmlinuz.EFI`) |
| 3 (ZFS)       | Resto   | `BF01` | O Pool em si                                         |

3. A Camada de Compatibilidade (BIOS + Syslinux)

No seu script de finalização da instalação, você deve configurar o carregamento:

- **Para UEFI:** Você simplesmente copia o executável do ZFSBootMenu para `/boot/efi/EFI/zbm/zfsbootmenu.EFI` e cria a entrada com `efibootmgr`.
- **Para BIOS:** O Syslinux ou o GRUB deve ser instalado na partição de 1MB. Ele carregará um kernel básico e um initramfs que contém o binário do ZFSBootMenu. O ZFSBootMenu então assume, importa o pool e faz o kexec para o kernel do Debian.

Por que esta estrutura?

1. **`canmount=noauto`**: Essencial para que o ZFSBootMenu possa importar o pool sem que o sistema tente montar a raiz antes da hora.
2. **`org.zfsbootmenu:commandline`**: Esta propriedade do dataset é lida pelo menu antes do boot, permitindo que você altere parâmetros do kernel (como `nomodeset`) sem editar arquivos de configuração, apenas alterando a propriedade do ZFS.
3. **Ambiente UEFI Nativo**: Em máquinas modernas, o ZFSBootMenu funciona como uma aplicação EFI nativa, dispensando totalmente o GRUB ou Syslinux.

Sugestão de Próximo Passo:

Consulte a documentação oficial do ZFSBootMenu - Debian Guide para detalhes de dependências de pacotes como `kexec-tools`.

Para integrar o **ZFSBootMenu (ZBM)** como um `hook` no **Debian Live-Build**, precisamos garantir que a estrutura de partições e o carregamento do binário ZBM ocorram de forma transparente.

O segredo para o **Syslinux** não ser notado é configurá-lo com um `timeout 0` ou `1`, apontando diretamente para o kernel/initramfs do ZFSBootMenu. O Syslinux servirá apenas como o "trampolim" que o hardware BIOS precisa para ler a partição GPT e saltar para o ZBM.

Aqui está a implementação modular para essa finalidade:

1. Lib: `libs/setup-bootloader.sh`

Esta biblioteca cuida da dualidade BIOS/UEFI.

```bash
#!/bin/bash

setup_zbm_bootloader() {
    echo "--- Configurando Camada de Boot (ZFSBootMenu) ---"

    # 1. Montagem da partição EFI (comum a BIOS e UEFI neste layout)
    mkdir -p /mnt/boot/efi
    mount "/dev/${DISKS[0]}2" /mnt/boot/efi

    # 2. Download/Cópia do binário ZFSBootMenu (vmlinuz e initramfs)
    # No live-build, você pode já ter esses arquivos no chroot
    mkdir -p /mnt/boot/efi/EFI/zbm
    cp /usr/share/zfsbootmenu/vmlinuz-x86_64 /mnt/boot/efi/EFI/zbm/vmlinuz-zbm
    cp /usr/share/zfsbootmenu/initramfs-x86_64.img /mnt/boot/efi/EFI/zbm/initrd-zbm

    # 3. Configuração UEFI (Nativa)
    if [ -d /sys/firmware/efi ]; then
        echo "Configurando entrada UEFI..."
        efibootmgr -c -d "/dev/${DISKS[0]}" -p 2 -L "ZFSBootMenu" \
            -l '\EFI\zbm\vmlinuz-zbm' \
            -u "initrd=\EFI\zbm\initrd-zbm quiet root=zfs:AUTO"
    fi

    # 4. Camada BIOS (Syslinux invisível)
    echo "Configurando Syslinux para modo BIOS..."
    # Instala o MBR do Syslinux no disco
    dd bs=440 count=1 conv=notrunc if=/usr/lib/SYSLINUX/gptmbr.bin of="/dev/${DISKS[0]}"

    # Configura o arquivo syslinux.cfg para dar boot imediato no ZBM
    cat <<EOF > /mnt/boot/efi/syslinux.cfg
PROMPT 0
TIMEOUT 10
DEFAULT zbm

LABEL zbm
    LINUX /EFI/zbm/vmlinuz-zbm
    INITRD /EFI/zbm/initrd-zbm
    APPEND quiet root=zfs:AUTO
EOF

    # Instala o syslinux na partição VFAT (partição 2)
    syslinux -i "/dev/${DISKS[0]}2"
}
```

2. Ajuste no `libs/common-utils.sh` (Particionamento)

Para que os hooks do Live-Build funcionem, o particionamento deve prever a área do Syslinux e do ZBM:

```bash
prepare_common() {
    for disk in "${DISKS[@]}"; do
        sgdisk --zap-all "/dev/$disk"
        # 1: BIOS Boot (p/ Syslinux/GRUB em GPT) - 1MB
        sgdisk -n 1:2048:+1M -t 1:EF02 "/dev/$disk"
        # 2: EFI/Boot (ZFSBootMenu + Syslinux CFG) - 512MB
        sgdisk -n 2:4096:+512M -t 2:EF00 "/dev/$disk"
        # 3: ZFS Pool - Resto
        sgdisk -n 3:0:0 -t 3:BF01 "/dev/$disk"

        partprobe "/dev/$disk"
    done
}
```

3. Integração como Hook no Live-Build

No `live-build`, você colocaria esses scripts em `config/hooks/live/`. O script de hook chamaria seu maestro:

```bash
#!/bin/bash
# config/hooks/live/99-zfs-install.sh

# Carrega suas libs modulares
source /tmp/install/libs/common-utils.sh
source /tmp/install/libs/setup-datasets.sh
source /tmp/install/libs/setup-bootloader.sh

# Fluxo de execução
prepare_common
# ... (aqui entraria a lógica de criação do pool selecionado)
setup_zfs_datasets
setup_zbm_bootloader
```

Por que isso funciona perfeitamente:

1. **Syslinux em Partição VFAT:** O Syslinux pode ler kernels de partições FAT32. Ao colocar o ZFSBootMenu na partição EFI (que é FAT32), o Syslinux o encontra facilmente no modo BIOS.
2. **Invisibilidade:** Com `PROMPT 0` e um `TIMEOUT` baixo no `syslinux.cfg`, o usuário verá apenas a tela de post do computador e logo em seguida a interface moderna do ZFSBootMenu.
3. **Independência de Kernel:** O ZFSBootMenu contém seu próprio kernel Linux. Isso significa que mesmo que você atualize o kernel do Debian e algo quebre, o ZBM sempre iniciará, permitindo que você faça rollback de snapshots ZFS via interface gráfica antes mesmo do SO carregar.

**Dica Crítica:** Para o `live-build`, certifique-se de que os pacotes `syslinux`, `syslinux-common`, `gdisk` e `zfsbootmenu` estejam na lista de pacotes do seu arquivo de configuração (`config/package-lists/`).

Para que o **ZFSBootMenu (ZBM)** funcione com todo o seu potencial (gerenciamento de snapshots, rollback e múltiplos Boot Environments), ele precisa de um arquivo `config.yaml`. No entanto, como você está usando **hooks do live-build**, o ZBM pode ser configurado de duas formas: embutido no initramfs ou via arquivo externo na partição EFI.

Abaixo, apresento a lib para gerar essa configuração de forma automatizada, garantindo que o ZBM identifique o Debian e qualquer outro sistema no pool.

1. Lib: `libs/setup-zbm-config.sh`

Esta lib cria o diretório de configuração e o arquivo YAML que o ZFSBootMenu consulta ao iniciar.

```bash
#!/bin/bash

setup_zbm_yaml() {    echo "--- Gerando Configuração do ZFSBootMenu (YAML) ---"

    # Define o local da partição EFI montada (ajuste conforme seu hook)
    local efi_mnt="/mnt/boot/efi"
    mkdir -p "$efi_mnt/zfsbootmenu"

    cat <<EOF > "$efi_mnt/zfsbootmenu/config.yaml"Global:  ManageImages: true  BootMountPoint: $efi_mnt  DracutConfDir: /etc/zfsbootmenu/dracut.conf.dComponents:  ImageBuilder:    Enabled: true    # Garante que o binário gerado suporte ZFS    ExtraArgs: [ "--add", "zfs" ]Pools:  $POOL_NAME:    Config:      # Tempo de espera no menu do ZBM (em segundos)      MenuTimeout: 10    # Onde o ZBM salvará os kernels extraídos para boot rápido    PrebuiltCopies:      Enabled: true      Path: $efi_mnt/EFI/zbmEOF

    echo "Configuração config.yaml gerada em $efi_mnt/zfsbootmenu/"
}
```

2. O Pulo do Gato: Propriedades de Dataset

O ZFSBootMenu não depende apenas do YAML; ele "conversa" com o ZFS através de propriedades. No seu hook de instalação, após criar o dataset raiz, você deve definir estas chaves para que o ZBM saiba como carregar o kernel do Debian:

```bash
set_zbm_props() {    local target_dataset="$POOL_NAME/ROOT/debian"
        echo "Configurando propriedades de boot no dataset $target_dataset..."

    # 1. Define os argumentos do kernel (root=zfs:AUTO é mágico aqui)
    zfs set org.zfsbootmenu:commandline="quiet rw root=zfs:AUTO" "$target_dataset"

    # 2. (Opcional) Define qual kernel preferir se houver vários
    # zfs set org.zfsbootmenu:kernel="vmlinuz-*" "$target_dataset"
}
```

3. Integração no Hook do Live-Build

No final do processo, seu script de instalação deve seguir esta ordem:

1. **Cria o Pool** (usando as libs anteriores).
2. **Cria os Datasets** (incluindo o `ROOT/debian`).
3. **Define as Propriedades** (`set_zbm_props`).
4. **Cria o `config.yaml`** (`setup_zbm_yaml`).
5. **Instala o Syslinux/UEFI Binaries** (conforme a lib de bootloader).

---

Por que isso é importante para o seu projeto:

- **Boot Environments (BE):** Com essa config, se você usar o comando `zfs clone` para criar uma cópia do seu sistema antes de uma atualização arriscada, o ZFSBootMenu detectará automaticamente o novo dataset e o mostrará no menu de boot sem você precisar editar nada.
- **Snapshots:** Se o sistema não iniciar, você entra na interface do ZBM (que já estará carregada pelo Syslinux/UEFI), navega pelos snapshots do dataset `ROOT/debian` e escolhe "Boot do Snapshot" ou "Rollback".
- **Independência de Versão:** Como o ZBM é um kernel Linux próprio (geralmente baseado em Void Linux ou Alpine), ele tem suporte a versões de ZFS muito recentes, evitando o erro clássico do GRUB de "unsupported ZFS feature".

**Próximo Passo:**  

Esta abordagem é para criar uma **Golden Image** ou um sistema de recuperação imutável que roda diretamente do ZFS, mas mantém a eficiência de um Live-System. Para que o **ZFSBootMenu (ZBM)** carregue um sistema baseado em SquashFS contido em um Dataset ZFS, precisamos de um Chroot que prepare o `initramfs` para montar o SquashFS como a raiz real (`rootfs`).

Aqui está a lib de **Finalização e Chroot** focada em performance (LZ4/ZSTD) e suporte offline:

1. Lib: `libs/finalize-chroot.sh`

Esta lib entra no sistema, compila os módulos e prepara o suporte ao SquashFS.

```bash
#!/bin/bash

finalize_installation() {    echo "--- Entrando no Chroot para Configuração Final ---"

    # 1. Montagens necessárias para o Chroot
    mount -t proc proc "/mnt/proc"
    mount -t sysfs sys "/mnt/sys"
    mount -o bind /dev "/mnt/dev"
    mount -o bind /dev/pts "/mnt/dev/pts"

    # 2. Execução de comandos dentro do Chroot (via HEREDOC)
    chroot /mnt /bin/bash <<EOF        export DEBIAN_FRONTEND=noninteractive                # Atualiza repositórios e instala DKMS para o ZFS        apt-get update        apt-get install -y zfs-dkms zfsutils-linux squashfs-tools kexec-tools        # Força a compilação do módulo ZFS para o kernel atual        # Usamos compressão rápida no kernel (ZSTD nível 3 ou LZ4)        sed -i 's/COMPRESS=gzip/COMPRESS=zstd/' /etc/initramfs-tools/initramfs.conf                echo "Compilando módulos ZFS via DKMS (isso pode demorar)..."        dkms autoinstall        # Gera o Initramfs otimizado        update-initramfs -u -k allEOF
}
```

2. Otimização do SquashFS e Kernel

Para garantir a **compressão rápida** solicitada, adicione estas configurações ao seu processo de build:

- **No Kernel:** No arquivo `/etc/initramfs-tools/initramfs.conf`, mude `COMPRESS=zstd` (melhor balanço) ou `COMPRESS=lz4` (mais rápido de todos).

- **No SquashFS:** Se você estiver gerando o arquivo SquashFS manualmente para colocar no dataset, use:  `mksquashfs /origem /destino/root.squashfs -comp lz4 -Xhc` (O `-Xhc` garante uma compressão melhor mantendo a velocidade do LZ4).
3. Integração com ZFSBootMenu (Boot Offline)

Para que o ZBM suporte o boot offline via SquashFS, você deve configurar o `commandline` do dataset para instruir o initramfs a encontrar o arquivo squash:

```bash
setup_offline_squash_boot() {    # Supondo que seu SquashFS esteja em /boot/system.squashfs dentro do dataset
    local boot_args="quiet rw root=zfs:AUTO boot=live persistence"
        echo "Configurando argumentos de boot para SquashFS..."
    zfs set org.zfsbootmenu:commandline="$boot_args" "$POOL_NAME/ROOT/debian"
}
```

Por que usar LZ4 e ZSTD aqui?

1. **LZ4 no ZFS:** Se o seu Pool já tiver `compression=lz4`, colocar um SquashFS comprimido com LZ4 dentro dele é extremamente eficiente, pois o ZFS não tentará recomprimir o que já está comprimido, economizando CPU.
2. **ZSTD no Initramfs:** O ZSTD oferece um descompressão quase tão rápida quanto o LZ4, mas com tamanhos de arquivo muito menores, o que acelera o carregamento do kernel pelo **Syslinux/ZBM** em máquinas com discos lentos.

Resumo do Fluxo no Live-Build:

1. **Lib `prepare_disks`**: Cria o layout GPT (BIOS/UEFI).
2. **Lib `setup_datasets`**: Cria a hierarquia ZFS.
3. **Lib `finalize-chroot`**: Compila o ZFS com DKMS e configura o initramfs com ZSTD/LZ4.
4. **Lib `setup-bootloader`**: Instala o ZBM e o Syslinux "invisível".

O ZFSBootMenu facilita muito a criação dessa camada de persistência através de **Clones** e **Snapshots**.
