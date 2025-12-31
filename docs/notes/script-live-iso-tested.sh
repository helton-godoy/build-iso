#!/bin/bash
set -e

## Nomes para a imagem:
# Γραμματεύς (Grammateús): Este termo refere-se a um escriba, secretário ou oficial responsável por escrever e guardar documentos. Portanto, a função de um grammateús era, em muitos aspetos, semelhante à de um arquivista.
# Ταμίας (Tamías):O tesoureiro, que muitas vezes também era responsável pela guarda de documentos importantes e registos financeiros.
# Φύλαξ (Fýlax): Guardião ou vigia. Em um sentido mais figurado, poderia se referir a alguém que guarda documentos.

echo "🔧 Instalando dependências..."
sudo apt update
sudo apt install -y live-build live-config debootstrap curl gnupg squashfs-tools grub-pc-bin grub-efi-amd64-bin xorriso

echo "📁 Criando diretório de build..."

mkdir -p live-zfs-server && cd live-zfs-server
mkdir -p config/package-lists
mkdir -p config/includes.chroot/lib/live/config/
mkdir -p config/hooks/live
mkdir -p config/includes.chroot/etc/apt/
mkdir -p config/includes.chroot/usr/local/bin/
mkdir -p config/hooks/binary/

lb clean

echo "🧰 Configurando live-build..."

lb config \
	--mode debian \
	--distribution trixie \
	--architectures amd64 \
	--debian-installer live \
	--bootappend-live "boot=live components username=live hostname=debian autologin" \
	--initramfs live-boot \
	--linux-packages linux-image \
	--binary-images iso-hybrid \
	--mirror-bootstrap http://deb.debian.org/debian \
	--mirror-chroot-security http://security.debian.org/debian-security \
	--archive-areas "main contrib non-free non-free-firmware" \
	--debootstrap-options "--variant=minbase"

echo "📦 Adicionando pacotes ao pacote list..."

cat >config/package-lists/zfs-server.list.chroot <<PKG_BASE

# ----- Pacotes para criação de imagem ISO -----
live-build 
live-config
debootstrap
mmdebstrap
squashfs-tools
grub-pc-bin
grub-efi-amd64-bin
xorriso

# ----- Comandos essenciais -----
sudo
bash
coreutils

# ----- Autocompletar comandos -----
bash-completion

# ----- Confiturar NTP ajute de hora -----
systemd-timesyncd

# ----- Rede -----
isc-dhcp-client

# Avivar comandos de rede:
# - ip	        Gerencia interfaces, endereços, rotas, etc.
# - ss	        Exibe conexões de rede (substitui netstat)
# - tc	        Controle de tráfego e QoS
# - bridge	    Gerencia interfaces de bridge
# - rtmon	      Monitora alterações de rota
# - devlink	    Gerencia dispositivos de rede avançados
# - tipc	      Gerencia rede TIPC (interprocess communication)
# - nstat	      Estatísticas de rede
# - ip monitor	Monitora eventos de rede

# 🧠 Exemplos de equivalência com pacote legado net-tools:

# :-------------------------:-----------------------------------:--------------------------------------:
# : Tarefa	                :  net-tools	                    : iproute2                             :
# :-------------------------:-----------------------------------:--------------------------------------:
# : Ver interfaces	        :  ifconfig -a	                    : ip link show                         :
# : Ativar interface	    :  ifconfig eth0 up	                : ip link set eth0 up                  :
# : Definir IP	            :  ifconfig eth0 192.168.0.1	    : ip addr add 192.168.0.1/24 dev eth0  :
# : Ver rotas	            :  route -n	                        : ip route show                        :
# : Adicionar rota padrão	:  route add default gw 192.168.0.1	: ip route add default via 192.168.0.1 :
# : Ver conexões TCP	    :  netstat -tulnp	                : ss -tulnp                            :
# :-------------------------:-----------------------------------:--------------------------------------:

iproute2


# 🔄 Comparativo rápido:
#
# :------------------:--------------------------------:-----------------------------------:
# : Método	         : Arquivo principal	          : Serviço ativo	Pacote necessário :
# :------------------:--------------------------------:-----------------------------------:
# : systemd-networkd : /etc/systemd/network/*.network : systemd-networkd	systemd       :
# : ifupdown	     : /etc/network/interfaces	      : networking.service	ifupdown      : 
# : NetworkManager	 : /etc/NetworkManager/*	      : NetworkManager	network-manager   : 
# :------------------:-------------------------------:------------------------------------:
# Ainda estou avaliando qual usar em difinitivo:
# ifupdown
# network-manager
# systemd-networkd

# Diagnóstico de rede
iputils-ping
curl
wget
openssh-server
dnsutils
traceroute
nmap
mtr

# ZFS e utilitários
dpkg-dev
build-essential
linux-image-amd64
linux-headers-amd64
dkms
zfs-dkms
zfs-zed
libpam-zfs
libzfsbootenv1linux
libzfslinux-dev
gdisk
zfsutils-linux
zfs-initramfs
mmdebstrap
dosfstools
zstd
lz4
lzop

# Intel Xeon e CPU tuning
intel-microcode
thermald
msr-tools

# Drivers de rede enterprise
firmware-iwlwifi
firmware-linux
firmware-realtek
firmware-bnx2
firmware-bnx2x
firmware-intel-sound
ethtool
pciutils
usbutils

# Diagnóstico e performance
numactl
hwloc
smartmontools
nvme-cli
lshw
lm-sensors

# ===== UTILITÁRIOS ===== #

# ----- Editores de texto ----- 
nano
micro

# ----- Monitoramento e diagnóstico de hardware -----
htop
btop
lsof
strace

# ----- Manipulação de arquivos -----
rsync
tar
zip
unzip

# ----- Agendamento e rotação de logs -----
cron
logrotate

# ----- Manter sessões remotas persistentes -----
screen
tmux

# ----- Gerenciador de arquivos em modo texto -----
mc

# ===== SEGURANÇA ===== #

# ----- Firewall -----
ufw
iptables

# ----- Proteção contra brute force -----
fail2ban

# ----- Segurança de conexões e pacotes -----
ca-certificates
gnupg

# ----- Usar em shell scripts -----
gum
whiptail
dialog

# ----- Estética terminal -----
lolcat 
figlet

# ----- Suporte a emojis no terminal gráfico -----
fonts-noto-color-emoji
PKG_BASE

# Pacotes de idioma para Português do Brasil
cat >config/package-lists/local.list.chroot <<PKG_PTBR
locales
console-setup
keyboard-configuration
manpages-pt-br
manpages-pt-br-dev
task-portuguese
task-brazilian-portuguese
aspell-pt-br
ibrazilian
wbrazilian
info
info2man
PKG_PTBR

# Esse script será executado automaticamente no boot do sistema live.
cat >config/includes.chroot/lib/live/config/99-setup.sh <<SETUP
# Mensagem de boas-vindas
cat <<MOTD > /etc/motd
🛠 Debian Trixie Live Server — Powered by ZFS & Xeon Optimization
📦 Kernel: $(uname -r)
🧠 Hostname: $(hostname)
👤 User: live (autologin ativado)
📡 Network: DHCP enabled — $(hostname -I)

🔍 Diagnóstico rápido:
  - zpool status          → para verificar pools ZFS
  - smartctl -a /dev/sdX  → para monitorar discos
  - numactl --hardware    → para topologia de memória
  - ethtool ethX          → para detalhes da interface de rede
  - ip a                  → interfaces de rede
  - htop                  → monitoramento de recursos
  - btop                  → monitoramento de recursos

💡 Dica: Este sistema é efêmero. Para persistência, instale no disco com ZFS raiz.

🚀 **Instalação do sistema**
Para iniciar o processo de instalação no disco com ZFS raiz, execute:

    instalar

Esse comando abrirá o assistente interativo de instalação via shell script personalizado.

📁 Script localizado em: /usr/local/bin/instalar
🔐 Requer privilégios de root: use 'sudo instalar' se necessário

📋 Etapas do assistente:
  1. Seleção de disco e layout ZFS
  2. Configuração de hostname e rede
  3. Criação de usuários
  4. Instalação de pacotes essenciais
  5. Finalização e reboot

📖 Documentação: https://wiki.debian.org/ZFS
MOTD
SETUP

# # Este script será incluído como parte do processo de build da imagem.
# cat > config/hooks/binary/framebuffer.hook.binary <<FRAMEBUFFER_SIS
# #!/bin/bash
# set -e

# echo "🔧 Configurando framebuffer no GRUB..."

# # Edita o arquivo de configuração do GRUB
# sed -i 's/^GRUB_GFXMODE=.*/GRUB_GFXMODE=1024x768/' /etc/default/grub || echo 'GRUB_GFXMODE=1024x768' >> /etc/default/grub
# sed -i 's/^GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/' /etc/default/grub || echo 'GRUB_GFXPAYLOAD_LINUX=keep' >> /etc/default/grub
# sed -i 's/^GRUB_TERMINAL=.*/#GRUB_TERMINAL=console/' /etc/default/grub

# # Atualiza o GRUB
# update-grub

# echo "📦 Instalando fbset e fontes para console..."
# apt-get update
# apt-get install -y fbset console-setup

# echo "📁 Carregando módulos do framebuffer..."
# echo -e "fbcon\nvesafb\nsimplefb\nefifb" >> /etc/modules

# echo "🖋️ Configurando fonte padrão para framebuffer..."
# echo 'FONT="ter-v24b"' >> /etc/default/console-setup

# echo "✅ Framebuffer configurado com sucesso!"
# FRAMEBUFFER_SIS

cat >config/hooks/live/framebuffer-console.hook.chroot <<FRAMEBUFFER_ISO
#!/bin/bash
set -e

echo "🖥️ Configurando framebuffer e console..."

# Carregar módulos de framebuffer no boot
echo -e "fbcon\nvesafb\nsimplefb\nefifb" >> /etc/modules

# Configurar fonte e layout do console
cat <<EOF > /etc/default/console-setup
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="Uni1"
FONTFACE="Terminus"
FONTSIZE="16"
XKBMODEL="abnt2"
XKBLAYOUT="br"
XKBVARIANT=""
XKBOPTIONS=""
EOF

echo "✅ Framebuffer configurado com sucesso no console."
FRAMEBUFFER_ISO

cat >config/hooks/live/ptbr-config.hook.chroot <<PTBR
#!/bin/bash
set -e

echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen pt_BR.UTF-8
update-locale LANG=pt_BR.UTF-8

echo 'LANG="pt_BR.UTF-8"' > /etc/default/locale

# Configura teclado ABNT2
cat <<TECLADO > /etc/default/keyboard
XKBMODEL="abnt2"
XKBLAYOUT="br"
XKBVARIANT=""
XKBOPTIONS=""
TECLADO

# Configura console para ABNT2
cat <<TERMINAL > /etc/default/console-setup
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="Lat15"
FONTFACE="Terminus"
FONTSIZE="16"
XKBMODEL="abnt2"
XKBLAYOUT="br"
XKBVARIANT=""
XKBOPTIONS=""
TERMINAL
PTBR

cat >config/includes.chroot/etc/apt/sources.list <<REPOSITORIO_BR
deb http://debian.c3sl.ufpr.br/debian/ trixie main contrib non-free non-free-firmware
deb-src http://debian.c3sl.ufpr.br/debian/ trixie main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware

deb http://debian.c3sl.ufpr.br/debian/ trixie-updates main contrib non-free non-free-firmware
deb-src http://debian.c3sl.ufpr.br/debian/ trixie-updates main contrib non-free non-free-firmware
REPOSITORIO_BR

cat >config/includes.chroot/lib/live/config/99-network-setup.sh <<'REDE'
#!/bin/bash
set -e

echo "[LIVE CONFIG] Iniciando configuração de rede com systemd-networkd..."

# Detecta a primeira interface Ethernet disponível
INTERFACE=$(ip -o link show | awk -F': ' '/en/{print $2; exit}')

# Define variáveis padrão (podem ser sobrescritas)
USE_DHCP="${USE_DHCP:-yes}"           # yes ou no
STATIC_IP="${STATIC_IP:-10.24.8.99/24}"
GATEWAY="${GATEWAY:-10.24.8.1}"
DNS1="${DNS1:-10.24.16.201}"
DNS2="${DNS2:-10.24.16.200}"

# Cria diretório de configuração
mkdir -p /etc/systemd/network

# Gera arquivo de configuração da interface
if [ "$USE_DHCP" = "yes" ]; then
  cat <<EOF > /etc/systemd/network/20-${INTERFACE}.network
[Match]
Name=$INTERFACE

[Network]
DHCP=yes
EOF
else
  cat <<EOF > /etc/systemd/network/20-${INTERFACE}.network
[Match]
Name=$INTERFACE

[Network]
Address=$STATIC_IP
Gateway=$GATEWAY
DNS=$DNS1
DNS=$DNS2
EOF
fi

# Ativa serviços de rede e DNS
systemctl enable systemd-networkd
systemctl enable systemd-resolved

# Garante que o resolv.conf aponte para o resolved
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
echo "[LIVE CONFIG] Rede configurada para interface $INTERFACE com ${USE_DHCP^^}."
REDE

cat >config/hooks/live/gum-installer.chroot <<GUM
#!/bin/bash
set -e
echo "🔧 Adicionando repositório do gum..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" > /etc/apt/sources.list.d/charm.list
apt update
apt install -y gum
GUM

cat >config/includes.chroot/usr/local/bin/heltonos-installer.sh <<'INSTALL'
#!/bin/bash
set -e
TMP="/tmp/heltonos-installer"
mkdir -p "$TMP"

# Função para exibir menu lateral
function show_step() {
  clear
  gum style --border double --padding "1 2" --margin "1" --foreground "#00FFFF" --bold "🧭 Instalador HeltonOS"
  gum style --border normal --padding "0 2" --margin "0" --foreground "#AAAAAA" "
[✓] Idioma
[✓] Teclado
[✓] Hostname
[✓] Rede
[✓] Usuário
[✓] Senha
[✓] Fuso horário
[✓] Disco
[✓] Resumo
[✓] Instalação
"
  gum style --foreground "#FFD700" --bold "➡️ Etapa atual: $1"
}

# Etapas
show_step "Idioma"
IDIOMA=$(gum choose pt_BR en_US)
echo "$IDIOMA" > "$TMP/idioma.txt"

show_step "Teclado"
TECLADO=$(gum choose br-abnt2 us)
echo "$TECLADO" > "$TMP/teclado.txt"

show_step "Hostname"
HOSTNAME=$(gum input --placeholder "Nome do computador")
echo "$HOSTNAME" > "$TMP/hostname.txt"

show_step "Rede"
REDE=$(gum choose DHCP Estático)
echo "$REDE" > "$TMP/rede.txt"

show_step "Usuário"
USUARIO=$(gum input --placeholder "Nome de usuário")
echo "$USUARIO" > "$TMP/usuario.txt"

show_step "Senha"
SENHA=$(gum input --password --placeholder "Senha")
echo "$SENHA" > "$TMP/senha.txt"

show_step "Fuso horário"
TZ=$(gum input --placeholder "America/Cuiaba")
echo "$TZ" > "$TMP/timezone.txt"

show_step "Disco"
DISCO=$(gum input --placeholder "/dev/sda")
echo "$DISCO" > "$TMP/disco.txt"

show_step "Resumo"
gum style --border normal --padding "1 2" --margin "1" --foreground "#00FFAA" --bold "📋 Resumo da instalação:"
gum format <<< "
**Idioma:** $IDIOMA  
**Teclado:** $TECLADO  
**Hostname:** $HOSTNAME  
**Rede:** $REDE  
**Usuário:** $USUARIO  
**Senha:** ********  
**Fuso horário:** $TZ  
**Disco:** $DISCO
"

gum confirm "Deseja continuar com a instalação simulada?" || exit 1

show_step "Instalação"
gum spin --title "Instalando HeltonOS..." -- sleep 4

gum style --border double --padding "1 2" --margin "1" --foreground "#00FF00" --bold "✅ Instalação simulada concluída com sucesso!"
gum style --foreground "#AAAAAA" "Você pode reiniciar o sistema para começar a usar o HeltonOS."
INSTALL

# Torne executável
chmod +x config/includes.chroot/usr/local/bin/heltonos-installer.sh
chmod +x config/includes.chroot/lib/live/config/99-network-setup.sh
#chmod +x config/hooks/live/framebuffer.hook.chroot
chmod +x config/hooks/live/framebuffer-console.hook.chroot
chmod +x config/hooks/live/gum-installer.chroot
chmod +x config/hooks/live/*.hook.chroot

# Antes de gerar a ISO, limpe caches e arquivos desnecessários:
apt clean
rm -rf /var/lib/apt/lists/*

echo "🧪 Iniciando build da imagem ISO..."
sudo lb build

echo "✅ ISO gerada com sucesso!"
ls -lh live-image-amd64.hybrid.iso
