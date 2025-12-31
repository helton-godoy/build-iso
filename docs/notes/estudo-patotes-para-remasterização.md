# PACOTES PARA MÁQUINA DE COMPILAÇÃO (HOST) - Essenciais para gerar a ISO remasterizada

## Ferramentas de Build de ISO Live - OBRIGATÓRIOS
- live-build # Ferramenta principal para construir sistemas live Debian
- live-config # Configuração padrão para sistemas live Debian
- debootstrap # Cria sistema Debian básico a partir do zero (essencial para chroot)
- squashfs-tools # Ferramentas para criar e manipular sistemas de arquivos SquashFS (formato compressivo para live)
- xorriso # Utilitário para criar e manipular imagens ISO 9660 (geração da imagem final)
- initramfs-tools # Gerencia initramfs (sistema de inicialização RAM)

## Desenvolvimento - OBRIGATÓRIOS
- dpkg-dev # Ferramentas de desenvolvimento para pacotes Debian (essencial para customização)
- build-essential # Meta-pacote com ferramentas essenciais para compilação (gcc, make, etc.)
- git # Sistema de controle de versão distribuído (necessário para obter fontes)
- wget # Baixador de arquivos via HTTP/FTP (download de pacotes e fontes)
- curl # Transferência de dados via URLs (complementa wget para APIs e recursos web)

## Sistema Base - OBRIGATÓRIOS
- sudo # Permite execução com privilégios de superusuário (configuração de sistema)
- bash # Shell padrão do Linux, interpretador de comandos (ambiente shell)
- coreutils # Conjunto de utilitários básicos do sistema Unix (comandos fundamentais)

# PACOTES PARA A ISO LIVE - OBRIGATÓRIOS (Indispensáveis ao funcionamento básico)

## Bootloaders - OBRIGATÓRIOS
- grub-pc-bin # Bootloader GRUB para sistemas PC tradicionais (compatibilidade legacy BIOS)
- grub-efi-amd64-bin # Bootloader GRUB para sistemas EFI AMD64 (sistemas modernos UEFI)

## Bootloader Personalizado - INTEGRAR MANUALMENTE
- zfsbootmenu # ZFSBootMenu (compilar e empacotar manualmente - não disponível no Debian 13 oficial)

## Sistema Base e Rede - OBRIGATÓRIOS
- sudo # Permite execução com privilégios de superusuário (administração do sistema)
- bash # Shell padrão do Linux, interpretador de comandos (ambiente de trabalho)
- coreutils # Conjunto de utilitários básicos do sistema Unix (ferramentas fundamentais)
- systemd-timesyncd # Serviço de sincronização de tempo via systemd (hora correta do sistema)
- iproute2 # Ferramentas avançadas para gerenciamento de roteamento IP (configuração de rede)
- iputils-ping # Utilitário para testar conectividade de rede via ping (diagnóstico de rede)
- curl # Transferência de dados via URLs (download e APIs web)
- wget # Baixador de arquivos via HTTP/FTP (download de conteúdo)
- openssh-server # Servidor SSH para acesso remoto seguro (conexão remota)
- dnsutils # Ferramentas para consultas DNS (resolução de nomes)
- ifupdown # Ferramentas para configurar interfaces de rede (gerenciamento de interfaces)
- network-manager # Gerenciador de conexões de rede para desktops (interface gráfica para rede)
- systemd-networkd # Gerenciamento de rede integrado ao systemd (serviço de rede automático)
- isc-dhcp-client # Cliente DHCP para obtenção automática de endereços IP (configuração automática)

## Kernel e Sistema - OBRIGATÓRIOS
- linux-image-amd64 # Imagem do kernel Linux para arquitetura AMD64 (núcleo do sistema)
- linux-headers-amd64 # Cabeçalhos do kernel necessários para módulos (compilação de drivers)
- busybox # Conjunto de utilitários Unix em um único executável (ferramentas compactas)

## Sistema de Arquivos ZFS - OBRIGATÓRIOS
- zfs-dkms # Módulo ZFS para kernel Linux via DKMS (suporte nativo ao ZFS)
- zfsutils-linux # Utilitários de linha de comando para ZFS (gerenciamento ZFS)
- zfs-initramfs # Suporte para ZFS no initramfs durante boot (boot com root ZFS)
- gdisk # Ferramenta para particionamento de discos GPT (preparação de discos)

## Instalador Calamares - OBRIGATÓRIOS
- calamares # Instalador gráfico universal para distribuições Linux (instalação do sistema)
- calamares-settings-debian # Configurações específicas do Debian para Calamares (integração Debian)

## Ambiente Desktop KDE Plasma Minimalista - OBRIGATÓRIOS
- kde-plasma-desktop # Meta-pacote para o ambiente desktop KDE Plasma (ambiente gráfico completo)
- plasma-desktop # Componente principal do desktop Plasma (interface desktop)
- kwin-x11 # Gerenciador de janelas para X11 no KDE (composição de janelas)
- sddm # Gerenciador de login simples e moderno (tela de login)
- xorg # Servidor X.Org para interface gráfica (sistema gráfico base)
- konsole # Emulador de terminal para KDE (acesso à linha de comando)
- dolphin # Gerenciador de arquivos para KDE (navegação de arquivos)
- kde-cli-tools # Ferramentas de linha de comando para KDE (utilitários KDE)
- plasma-workspace # Espaço de trabalho do Plasma (ambiente de trabalho completo)

## Localização Básica - OBRIGATÓRIOS
- locales # Pacote para configuração de locales do sistema (suporte a idiomas)
- console-setup # Configuração do console do sistema (configuração de terminal)
- keyboard-configuration # Configuração de layout de teclado (mapeamento de teclas)

## Segurança Básica - OBRIGATÓRIOS
- ca-certificates # Pacote com certificados de autoridades confiáveis (HTTPS/SSL)

# INTEGRAÇÃO DE PACOTES NÃO-OFICIAIS - ZFSBootMenu

## Como Integrar ZFSBootMenu ao Debian 13

### 1. Compilação e Empacotamento do ZFSBootMenu

O ZFSBootMenu não está disponível nos repositórios oficiais do Debian 13. Para integrá-lo à sua ISO personalizada:

#### Dependências para Compilação:
- build-essential # Ferramentas de compilação
- golang-go # Linguagem Go (ZFSBootMenu é escrito em Go)
- git # Para clonar repositórios
- make # Sistema de build
- kmod # Gerenciamento de módulos do kernel
- zfs-dkms # Dependência ZFS
- efibootmgr # Gerenciamento de entradas de boot EFI
- libbash # Biblioteca para scripts shell
- libudev-dev # Biblioteca para gerenciamento de dispositivos
- systemd # Sistema de inicialização

#### Processo de Compilação:
```bash
# 1. Clonar repositório oficial
git clone https://github.com/zbm-dev/zfsbootmenu.git
cd zfsbootmenu

# 2. Instalar dependências de compilação
sudo apt install build-essential golang-go git make kmod \
    zfs-dkms efibootmgr libbash libudev-dev systemd

# 3. Compilar
make

# 4. Instalar no sistema temporário
sudo make install

# 5. Criar pacote .deb usando equivs ou checkinstall
# (requer configuração adicional de controle de pacotes)
```

### 2. Integração com live-build

#### Arquivo de Configuração de Pacotes Locais:
Criar arquivo `config/package-lists/zfsbootmenu.list.chroot`:
```
# Incluir pacote ZFSBootMenu compilado
zfsbootmenu
```

#### Hook de Build Personalizado:
Criar script em `config/hooks/normal/0100-install-zfsbootmenu.chroot`:
```bash
#!/bin/bash
# Instalar ZFSBootMenu compilado no chroot
if [ -f "/tmp/zfsbootmenu_*.deb" ]; then
    dpkg -i /tmp/zfsbootmenu_*.deb
    apt-get install -f -y
fi
```

#### Configuração do GRUB para ZFSBootMenu:
Em `config/includes.binary/boot/grub/grub.cfg` ou via hook:
```bash
# Configurar GRUB para usar ZFSBootMenu
cat >> /target/etc/default/grub << EOF
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash zfsbootmenu.timeout=10"
GRUB_EARLY_INITRD_LINUX_CUSTOM="zfsbootmenu"
EOF

update-grub
```

### 3. Alternativa: Usar Apenas GRUB com Suporte ZFS

Caso não queira compilar o ZFSBootMenu, pode usar GRUB com suporte nativo ao ZFS:

#### Pacotes GRUB com ZFS:
- **grub-efi-amd64-bin**: GRUB para UEFI com suporte ZFS
- **grub-pc-bin**: GRUB para BIOS com suporte ZFS
- **grub-common**: Arquivos comuns do GRUB
- **grub-efi-amd64**: Meta-pacote para GRUB UEFI

#### Configuração Simplificada:
```bash
# Configurar GRUB para detectar pools ZFS automaticamente
# O GRUB 2.06+ tem suporte nativo a ZFS
grub-install --target=x86_64-efi --efi-directory=/boot/efi
update-grub
```

### 4. Verificação Pós-Build

Após a criação da ISO, verifique:
- [ ] ZFSBootMenu compila sem erros
- [ ] Pacote .deb é criado corretamente
- [ ] Hook de instalação funciona no chroot
- [ ] Bootloader é configurado corretamente
- [ ] Sistema boots em pools ZFS
- [ ] Menu ZFSBootMenu aparece durante o boot

### 5. Solução de Problemas Comuns

#### Erro de Compilação Go:
```bash
# Configurar variáveis de ambiente Go
go env GOROOT GOPATH
# Ajustar PATH se necessário
export PATH=$PATH:$GOROOT/bin
```

#### Dependências Faltando:
```bash
# Verificar dependências do ZFSBootMenu
ldd $(which zfsbootmenu)
# Instalar bibliotecas faltantes
```

#### Problemas de Boot:
```bash
# Verificar configuração do initramfs
echo 'ZFSBOOTMENU_BTRFS=1' >> /etc/zfsbootmenu/config
update-initramfs -c -k all
```

### Resumo da Implementação:
1. **Compilar ZFSBootMenu** manualmente no sistema de build
2. **Empacotar** como .deb usando equivs/checkinstall
3. **Integrar** via hooks do live-build
4. **Configurar** GRUB para usar ZFSBootMenu
5. **Testar** o boot com pools ZFS na ISO resultante

**Observação**: Até que o ZFSBootMenu esteja integrado, use GRUB puro com suporte ZFS para garantir boot funcional.

# PACOTES PARA A ISO LIVE - OPCIONAIS (Melhoram experiência, mas não são críticos)

## Ferramentas de Build Adicionais - OPCIONAIS
- mmdebstrap # Alternativa mais rápida ao debootstrap para criação de chroots (otimização de build)

## Sistema Base e Rede Adicionais - OPCIONAIS
- bash-completion # Sistema de auto-completar para comandos no bash (conveniência)
- traceroute # Utilitário para rastrear rotas de pacotes na rede (diagnóstico avançado)
- nmap # Scanner de portas e descoberta de hosts na rede (análise de segurança)
- mtr # Combinação de traceroute e ping para diagnóstico de rede (ferramenta híbrida)

## Desenvolvimento - OPCIONAIS
- dkms # Framework para módulos do kernel independentes de versão (compilação automática de drivers)

## Sistema de Arquivos ZFS Adicional - OPCIONAIS
- zfs-zed # Daemon de eventos e monitoramento para ZFS (monitoramento ZFS)
- libpam-zfs # Módulo PAM para integração com ZFS (autenticação com ZFS)
- libzfsbootenv1linux # Biblioteca para gerenciamento de ambientes de boot ZFS (gerenciamento de boot)
- libzfslinux-dev # Biblioteca de desenvolvimento para ZFS (desenvolvimento ZFS)

## Compressão e Arquivos - OPCIONAIS
- dosfstools # Ferramentas para sistemas de arquivos FAT/DOS (compatibilidade FAT)
- zstd # Compressor e descompressor Zstandard (alta velocidade)
- lz4 # Compressor LZ4 (otimizado para velocidade)
- lzop # Compressor LZO (balanceado entre velocidade e compressão)

## Hardware e Firmware - OPCIONAIS
- intel-microcode # Atualizações de microcódigo para processadores Intel (segurança CPU)
- thermald # Daemon para gerenciamento térmico do sistema (controle de temperatura)
- msr-tools # Ferramentas para acessar registros MSR dos processadores (ajustes avançados)
- firmware-iwlwifi # Firmware para dispositivos WiFi Intel (conectividade sem fio)
- firmware-linux # Coleção de firmwares para hardware Linux (suporte a hardware)
- firmware-realtek # Firmware para dispositivos Realtek (áudio e rede)
- firmware-bnx2 # Firmware para placas de rede Broadcom NetXtreme II (rede empresarial)
- firmware-bnx2x # Firmware para placas de rede Broadcom NetXtreme II 10Gb (rede 10Gb)
- firmware-intel-sound # Firmware para dispositivos de áudio Intel (áudio HD)
- ethtool # Utilitário para configuração de interfaces Ethernet (configuração de rede)
- pciutils # Ferramentas para inspeção de dispositivos PCI (informações de hardware)
- usbutils # Ferramentas para inspeção de dispositivos USB (informações USB)
- numactl # Controle de afinidade NUMA para processos (otimização NUMA)
- hwloc # Biblioteca para localização e descrição de hardware (topologia de hardware)
- smartmontools # Ferramentas para monitoramento S.M.A.R.T. de discos (saúde de discos)
- nvme-cli # Interface de linha de comando para dispositivos NVMe (controle NVMe)
- lshw # Utilitário para listar configuração de hardware (inventário completo)
- lm-sensors # Ferramentas para monitoramento de sensores de hardware (temperatura/voltagem)

## Ferramentas de Sistema - OPCIONAIS
- nano # Editor de texto simples e leve (edição básica)
- micro # Editor de texto moderno com recursos avançados (edição melhorada)
- htop # Monitor de processos interativo e colorido (visualização de processos)
- btop # Monitor de processos alternativo com interface moderna (alternativa ao htop)
- lsof # Lista arquivos abertos por processos (análise de arquivos)
- strace # Ferramenta para rastrear chamadas de sistema (debugging)
- rsync # Utilitário para sincronização eficiente de arquivos (sincronização)
- tar # Programa para arquivar e comprimir arquivos (compactação)
- zip # Compressor e descompressor ZIP (compatibilidade ZIP)
- unzip # Descompressor ZIP (extração ZIP)
- cron # Daemon para agendamento de tarefas (tarefas automatizadas)
- logrotate # Utilitário para rotação de arquivos de log (gerenciamento de logs)
- screen # Multiplexador de terminais para sessões persistentes (sessões terminais)
- tmux # Multiplexador de terminais moderno (alternativa ao screen)
- mc # Midnight Commander, gerenciador de arquivos em modo texto (navegação arquivo)

## Segurança - OPCIONAIS
- ufw # Firewall simples baseado em iptables (firewall amigável)
- iptables # Ferramentas para configuração de firewall via netfilter (firewall avançado)
- fail2ban # Sistema de prevenção de intrusões baseado em logs (proteção contra ataques)
- gnupg # Ferramentas para criptografia GPG/PGP (criptografia)

## Ferramentas Interativas e Decoração - OPCIONAIS
- gum # Biblioteca para criar interfaces interativas em scripts shell (interfaces bonitas)
- whiptail # Utilitário para criar caixas de diálogo em modo texto (diálogos texto)
- dialog # Biblioteca para interfaces de usuário em modo texto (interfaces TUI)
- lolcat # Ferramenta para colorizar saída de texto no terminal (diversão)
- figlet # Gerador de texto ASCII art (arte ASCII)
- fonts-noto-color-emoji # Fontes com suporte a emojis coloridos (emojis)

## Otimização de Desempenho - OPCIONAIS

### Otimização Geral - OPCIONAIS
- preload # Daemon que acelera o carregamento de aplicações pré-carregando bibliotecas
- zram-tools # Ferramentas para configurar swap comprimido em RAM (memória virtual)
- earlyoom # Mata processos automaticamente quando a memória está baixa (proteção contra OOM)
- tuned # Daemon para otimização automática de desempenho do sistema (otimização automática)

### Otimização de CPU - OPCIONAIS
- cpufrequtils # Ferramentas para controle de frequência e governor da CPU (controle CPU)
- powertop # Ferramenta para análise e otimização de consumo de energia/CPU (eficiência)

### Otimização de Disco/SSD - OPCIONAIS
- hdparm # Utilitário para configurar parâmetros de discos rígidos (configuração ATA)
- fstrim # Comando para TRIM em SSDs (otimização SSD)
- iotop # Monitor de I/O em tempo real para identificar gargalos de disco (monitoramento I/O)

### Otimização de Memória - OPCIONAIS
- numad # Daemon para otimização de afinidade NUMA em sistemas multi-socket (otimização NUMA)

### Otimização de Rede - OPCIONAIS
- tcpdump # Ferramenta para captura e análise de pacotes de rede (análise de tráfego)
- iperf3 # Ferramenta para medição de performance de rede (teste de velocidade)
- wondershaper # Utilitário para controle de largura de banda de rede (limitação de banda)

### Monitoramento de Desempenho - OPCIONAIS
- sysstat # Coleção de ferramentas para monitoramento de desempenho do sistema (sar, iostat)
- atop # Monitor avançado de sistema com histórico detalhado (monitoramento avançado)
- nload # Monitor de tráfego de rede em tempo real (gráficos de rede)

## Serviços de Rede e Servidores - OPCIONAIS

### Servidor de Arquivos Samba com ZFS ACLs - OPCIONAIS
- samba # Servidor SMB/CIFS para compartilhamento de arquivos (compartilhamento Windows)
- samba-common # Arquivos comuns e bibliotecas para Samba (bibliotecas Samba)
- samba-vfs-modules # Módulos VFS para Samba, incluindo zfsacl (ACLs ZFS no Samba)
- acl # Ferramentas para manipulação de listas de controle de acesso (ACLs POSIX)
- attr # Utilitários para atributos estendidos de arquivos (atributos estendidos)
- winbind # Serviço para integração com domínios Windows/Active Directory (integração AD)
- libnss-winbind # Plugin NSS para resolução de nomes via Winbind (name resolution AD)
- libpam-winbind # Módulo PAM para autenticação via Winbind (autenticação AD)

### Bootloader Personalizado Adicional - OPCIONAIS
- zfsbootmenu # ZFSBootMenu (se compilado e empacotado manualmente)

## Ambiente Desktop - OPCIONAIS

### KDE Plasma Adicional - OPCIONAIS
- kde-plasma-desktop # Meta-pacote para o ambiente desktop KDE Plasma (ambiente completo)
- plasma-desktop # Componente principal do desktop Plasma (interface desktop)
- kwin-x11 # Gerenciador de janelas para X11 no KDE (composição de janelas)
- sddm # Gerenciador de login simples e moderno (tela de login)
- xorg # Servidor X.Org para interface gráfica (sistema gráfico base)
- konsole # Emulador de terminal para KDE (acesso à linha de comando)
- dolphin # Gerenciador de arquivos para KDE (navegação de arquivos)
- kde-cli-tools # Ferramentas de linha de comando para KDE (utilitários KDE)
- plasma-workspace # Espaço de trabalho do Plasma (ambiente de trabalho completo)

## Localização e Documentação - OPCIONAIS
- manpages-pt-br # Páginas de manual traduzidas para português brasileiro (documentação PT-BR)
- manpages-pt-br-dev # Páginas de manual de desenvolvimento em português brasileiro (dev PT-BR)
- task-portuguese # Meta-pacote para suporte ao idioma português (idioma português)
- task-brazilian-portuguese # Meta-pacote para português brasileiro (idioma PT-BR)
- aspell-pt-br # Dicionário Aspell para português brasileiro (verificação ortográfica)
- ibrazilian # Dicionário Ispell para português brasileiro (alternativa aspell)
- wbrazilian # Lista de palavras para português brasileiro (lista de palavras)
- info # Sistema de documentação Info do GNU (documentação alternativa)
- info2man # Conversor de páginas Info para formato man (conversão documentação)