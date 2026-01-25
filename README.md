# 🚀 Gerador de ISO Debian Trixie Personalizada

Sistema completo e automatizado para gerar imagens ISO do Debian Trixie com configurações personalizadas, usando Docker e live-build para máxima reprodutibilidade.

## 📋 Índice

- [Características](#-características)
- [Especificações Técnicas](#-especificações-técnicas)
- [Pré-requisitos](#-pré-requisitos)
- [Instalação](#-instalação)
- [Uso](#-uso)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Personalização](#-personalização)
- [Solução de Problemas](#-solução-de-problemas)
- [FAQ](#-faq)

## ✨ Características

- ✅ **Build Reprodutível**: Ambiente Docker isolado garante builds consistentes
- ✅ **Totalmente Automatizado**: Script único executa todo o processo
- ✅ **Localização PT-BR**: Idioma, teclado e timezone pré-configurados
- ✅ **TTY Avançado**: kmscon com suporte a truecolor e emojis
- ✅ **ZFS Nativo**: Sistema de arquivos enterprise pronto para uso
- ✅ **Otimizado**: Kernel e sistema otimizados para servidores de arquivos
- ✅ **Verificação de Integridade**: Checksums SHA256 automáticos
- ✅ **Boot Híbrido**: Suporte a BIOS e UEFI
- ✅ **Instalador Automatizado**: Sistema completo de instalação incluído na ISO

## 🔧 Especificações Técnicas

### Sistema Base

- **Distribuição**: Debian Trixie (testing)
- **Arquitetura**: AMD64
- **Kernel**: Linux amd64 (latest)
- **Init**: systemd

### Localização

- **Idioma**: Português do Brasil (pt_BR.UTF-8)
- **Teclado**: ABNT2 (br-abnt2)
- **Timezone**: America/Sao_Paulo
- **Sincronização**: systemd-timesyncd

### Terminal (TTY)

- **Gerenciador**: kmscon
- **Suporte de Cores**: 24-bit truecolor
- **Renderização**: Unicode completo + emojis
- **Aceleração**: DRM/KMS

### Fontes

- Noto (completa)
- Noto Color Emoji
- DejaVu Sans Mono
- Liberation
- FreeFont

### Sistema de Arquivos

- **ZFS**: Suporte completo
  - zfs-dkms (módulos do kernel)
  - zfsutils-linux (ferramentas administrativas)
  - zfs-initramfs (suporte no initrd)

### Pacotes Incluídos

```
Kernel & Firmware:
- linux-image-amd64
- linux-headers-amd64
- firmware-linux
- firmware-linux-nonfree

Essenciais:
- curl, wget, git
- htop, tmux
- vim, nano
- openssh-server
- sudo
- rsync

Rede:
- network-manager
- wpasupplicant
- iw, wireless-tools
```

### Otimizações de Kernel

```bash
vm.swappiness=10                    # Reduz uso de swap
vm.vfs_cache_pressure=50            # Otimiza cache de inodes
vm.dirty_ratio=10                   # Controle de escrita em disco
vm.dirty_background_ratio=5         # Background flush
fs.file-max=2097152                 # Máximo de arquivos abertos
net.core.rmem_max=134217728         # Buffer de rede (recepção)
net.core.wmem_max=134217728         # Buffer de rede (envio)
```

### Usuário Padrão

- **Username**: debian
- **Password**: live
- **Sudo**: Sem senha (NOPASSWD)
- **Shell**: /bin/bash

## 📦 Pré-requisitos

### Software Necessário

- Docker 20.10+ (com suporte a privileged mode)
- Git
- 20GB+ de espaço em disco livre
- Conexão com internet estável

### Sistema Operacional

- Linux (testado em Ubuntu 22.04+, Debian 11+)
- WSL2 (Windows Subsystem for Linux 2)
- macOS com Docker Desktop (limitações em privileged mode)

### Instalação do Docker

**Ubuntu/Debian**:

```bash
# Remover versões antigas
sudo apt-get remove docker docker-engine docker.io containerd runc

# Instalar dependências
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Adicionar repositório Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

## 🚀 Instalação

### 1. Clone o Repositório

```bash
git clone <url-do-repositorio> build-iso
cd build-iso
```

Ou crie a estrutura manualmente:

```bash
mkdir build-iso
cd build-iso
```

### 2. Verifique os Scripts

Os scripts principais estão localizados em `scripts/`:

- `scripts/build-debian-trixie-zbm.sh` - Script principal de build
- `scripts/clean-build-artifacts.sh` - Limpeza de artefatos
- `scripts/download-zfsbootmenu.sh` - Download do ZFS Boot Menu

### 3. Torne os Scripts Executáveis

```bash
chmod +x scripts/*.sh
```

## 💻 Uso

### Build Padrão

```bash
./scripts/build-debian-trixie-zbm.sh
```

ou explicitamente:

```bash
./scripts/build-debian-trixie-zbm.sh build
```

### Rebuild Completo

Limpa tudo e reconstrói:

```bash
./scripts/build-debian-trixie-zbm.sh rebuild
```

### Outros Comandos

```bash
./scripts/build-debian-trixie-zbm.sh help        # Mostra ajuda
./scripts/clean-build-artifacts.sh              # Limpa artefatos de build
./scripts/download-zfsbootmenu.sh               # Baixa componentes ZFS Boot Menu
```

## 📁 Estrutura do Projeto

A estrutura reorganizada do projeto segue uma organização modular e clara, separando documentação, scripts, testes e componentes incluídos na ISO. Abaixo está a representação hierárquica atual:

```
📦 build-iso/
├── 📄 .gitignore                          # Configuração Git para ignorar arquivos não versionados
├── 📄 project_structure.md               # Documentação da estrutura do projeto
├── 📄 quick_start_guide.md               # Guia rápido para iniciar o projeto
├── 📄 README.md                          # Documentação principal do projeto
├── 📄 symbol_analysis_report.md          # Relatório de análise de símbolos do código
├── 📁 .agent/                            # Configurações de agentes/automação
├── 📁 cache/                             # Cache de arquivos temporários
│   ├── 📄 README.md                      # Documentação do cache
│   └── 📁 debs/                          # Cache de pacotes Debian
├── 📁 include/                           # Arquivos incluídos na ISO final
│   └── 📁 usr/                           # Estrutura de sistema Unix-like
│       ├── 📁 local/                     # Arquivos locais do sistema
│       │   └── 📁 bin/                   # Binários executáveis
│       │       ├── 📄 gum                # Ferramenta de interface de usuário
│       │       ├── 📄 install-system     # Script principal de instalação automatizada
│       │       └── 📁 installer/         # Sistema de instalação completo
│       │           ├── 📄 README.md      # Documentação do instalador
│       │           ├── 📁 components/    # Componentes do processo de instalação
│       │           │   ├── 📄 01-validate.sh      # Validação inicial do sistema
│       │           │   ├── 📄 02-partition.sh     # Particionamento de discos
│       │           │   ├── 📄 03-pool.sh          # Configuração de pool ZFS
│       │           │   ├── 📄 04-datasets.sh      # Criação de datasets ZFS
│       │           │   ├── 📄 05-extract.sh       # Extração de arquivos base
│       │           │   ├── 📄 06-chroot-configure.sh  # Configuração em ambiente chroot
│       │           │   ├── 📄 07-bootloader.sh    # Instalação do bootloader
│       │           │   ├── 📄 08-cleanup.sh       # Limpeza pós-instalação
│       │           │   └── 🛡️ AGENTS.md          # Documentação de agentes (protegido)
│       │           └── 📁 lib/            # Bibliotecas auxiliares do instalador
│       │               ├── 📄 chroot.sh   # Funções para operações chroot
│       │               ├── 📄 error.sh    # Tratamento de erros
│       │               ├── 📄 logging.sh  # Sistema de logging
│       │               ├── 📄 ui_gum.sh   # Interface com ferramenta gum
│       │               └── 📄 validation.sh  # Validações diversas
│       └── 📁 share/                      # Arquivos compartilhados do sistema
│           └── 📁 zfsbootmenu/            # Componentes do ZFS Boot Menu
│               ├── 📄 initramfs-bootmenu-recovery.img  # Imagem initramfs para recovery
│               ├── 📄 initramfs-bootmenu.img           # Imagem initramfs principal
│               ├── 📄 VMLINUZ-BACKUP.EFI               # Kernel backup EFI
│               ├── 📄 vmlinuz-bootmenu-recovery        # Kernel para recovery
│               ├── 📄 VMLINUZ-RECOVERY.EFI             # Kernel recovery EFI
│               └── 📄 VMLINUZ.EFI                      # Kernel principal EFI
├── 📁 plans/                             # Planos e documentação de desenvolvimento
│   └── 📄 code_analysis.md               # Análise de código do projeto
├── 📁 scripts/                           # Scripts de automação e build
│   ├── 📄 build-debian-trixie-zbm.sh     # Script principal de build da ISO
│   ├── 📄 clean-build-artifacts.sh       # Limpeza de artefatos de build
│   └── 📄 download-zfsbootmenu.sh        # Download do ZFS Boot Menu
└── 📁 tests/                             # Testes automatizados
    ├── 📄 test_installer.bats            # Testes do instalador (framework BATS)
    └── 📄 test-iso.sh                    # Testes da ISO gerada
```

### 📋 Legenda da Estrutura

- **📁**: Pasta/diretório
- **📄**: Arquivo regular
- **🛡️**: Arquivo com proteção especial ou configuração crítica

### 🔍 Componentes Principais

- **Documentação**: Arquivos `.md` na raiz fornecem guias e referências completas
- **Scripts de Build**: Localizados em `scripts/`, automatizam a criação da ISO
- **Instalador Automatizado**: Sistema completo em `include/usr/local/bin/installer/` para instalação automatizada
- **Componentes ZFS**: Suporte nativo ao ZFS com Boot Menu incluído
- **Testes**: Framework de testes em `tests/` para validação contínua
- **Cache**: Otimização de builds com cache de pacotes em `cache/debs/`

## 🔧 Sistema de Instalação Automatizada

A ISO inclui um instalador automatizado completo localizado em `/usr/local/bin/installer/` no sistema live. O instalador é composto por:

### Componentes de Instalação

1. **01-validate.sh**: Validação do ambiente e hardware
2. **02-partition.sh**: Particionamento automático de discos
3. **03-pool.sh**: Criação e configuração de pool ZFS
4. **04-datasets.sh**: Configuração de datasets ZFS
5. **05-extract.sh**: Extração do sistema base
6. **06-chroot-configure.sh**: Configurações finais em ambiente chroot
7. **07-bootloader.sh**: Instalação do bootloader
8. **08-cleanup.sh**: Limpeza e finalização

### Bibliotecas Auxiliares

- **chroot.sh**: Funções para operações em chroot
- **error.sh**: Tratamento centralizado de erros
- **logging.sh**: Sistema de logging estruturado
- **ui_gum.sh**: Interface de usuário com gum
- **validation.sh**: Validações diversas

### Como Usar o Instalador

Após boot da ISO:

```bash
sudo install-system
```

O instalador guiará através do processo de instalação automatizada com interface interativa.

## 🎨 Personalização

O projeto usa uma abordagem de configuração gerada dinamicamente. As personalizações são feitas modificando o script principal `scripts/build-debian-trixie-zbm.sh` e os arquivos em `include/`.

### Modificar Pacotes

Edite o script `scripts/build-debian-trixie-zbm.sh` na função `generate_live_build_config` e adicione pacotes à lista:

```bash
# Adicione seus pacotes aqui
EXTRA_PACKAGES=(
    "seu-pacote"
    "outro-pacote"
)
```

### Adicionar Hooks Personalizados

Crie novos hooks em `include/usr/local/bin/installer/components/` seguindo a numeração sequencial:

```bash
cat > include/usr/local/bin/installer/components/09-meu-hook.sh << 'EOF'
#!/bin/bash
set -e

# Suas personalizações aqui
echo "Executando personalização customizada"
EOF
chmod +x include/usr/local/bin/installer/components/09-meu-hook.sh
```

### Modificar Configurações de Boot

No script `scripts/build-debian-trixie-zbm.sh`, modifique os parâmetros de boot na função de configuração:

```bash
BOOT_PARAMS="boot=live components quiet splash locales=pt_BR.UTF-8 timezone=America/Sao_Paulo keyboard-layouts=br seu_parametro=valor"
```

### Alterar Locale/Timezone

Modifique as variáveis no início de `scripts/build-debian-trixie-zbm.sh`:

```bash
readonly LOCALE="en_US.UTF-8"      # Exemplo para inglês
readonly TIMEZONE="America/New_York"
readonly KEYBOARD="us"
```

### Personalizar Usuário Padrão

Edite o componente `06-chroot-configure.sh` em `include/usr/local/bin/installer/components/`:

```bash
useradd -m -s /bin/bash -G sudo meuusuario
echo "meuusuario:minhasenha" | chpasswd
```

### Adicionar Arquivos à ISO

Coloque arquivos adicionais em `include/` seguindo a estrutura do sistema de arquivos Unix. Eles serão incluídos automaticamente na ISO.

## 🔍 Processo de Build Detalhado

### Etapa 1: Validação (1-2 min)

- Verifica dependências (Docker, Git)
- Valida ambiente de execução
- Cria estrutura de diretórios

### Etapa 2: Geração de Arquivos (< 1 min)

- Cria Dockerfile
- Gera script de entrada Docker
- Configura live-build
- Prepara hooks de personalização

### Etapa 3: Build da Imagem Docker (5-10 min)

- Baixa imagem base Debian Trixie
- Instala live-build e dependências
- Configura locale PT-BR
- Prepara ambiente de build

### Etapa 4: Build da ISO (30-60 min)

- Executa debootstrap (10-15 min)
- Instala pacotes (15-25 min)
- Aplica hooks de personalização (5 min)
- Gera sistema de arquivos squashfs (5-10 min)
- Cria imagem ISO híbrida (2-5 min)
- Gera checksums SHA256 (< 1 min)

### Etapa 5: Finalização (< 1 min)

- Copia ISO para output/
- Exibe informações da ISO
- Limpa arquivos temporários

## 🩺 Solução de Problemas

### Erro: "Docker não está rodando"

```bash
# Verificar status
sudo systemctl status docker

# Iniciar Docker
sudo systemctl start docker

# Habilitar no boot
sudo systemctl enable docker
```

### Erro: "Permission denied" ao executar Docker

```bash
# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER

# Aplicar mudanças (fazer logout/login ou)
newgrp docker
```

### Build Muito Lento

**Causas comuns**:

- Conexão de internet lenta (download de pacotes)
- CPU limitada (compressão squashfs)
- Disco lento (I/O intensivo)

**Soluções**:

- Use mirror Debian brasileiro: adicione ao lb config:

  ```bash
  --mirror-bootstrap "http://deb.debian.org/debian/" \
  --mirror-chroot "http://deb.debian.org/debian/"
  ```

- Ative cache de pacotes (já configurado por padrão)

- Use SSD se possível

### ISO Não Boota

**Verificações**:

1. Verifique integridade da ISO:

   ```bash
   sha256sum -c output/*.sha256
   ```

2. Grave em modo DD no USB (não use UNetbootin):

   ```bash
   sudo dd if=output/debian-*.iso of=/dev/sdX bs=4M status=progress && sync
   ```

3. Verifique compatibilidade BIOS/UEFI:
   - A ISO é híbrida e suporta ambos
   - Em UEFI, pode ser necessário desabilitar Secure Boot

### Erro Durante Componentes do Instalador

Se um componente do instalador falhar, examine os logs:

```bash
# Logs são salvos em /var/log/installer/ no sistema instalado
# Durante o build, verifique a saída do Docker
docker logs <container-name>
```

Desabilite o componente problemático comentando-o ou removendo-o de `include/usr/local/bin/installer/components/`.

## ❓ FAQ

### P: Quanto tempo demora o build completo?

**R**: Entre 40-70 minutos, dependendo de:

- Velocidade da internet (download de pacotes: ~500MB-1GB)
- CPU (compressão e compilação)
- Disco (I/O intensivo)

### P: Qual o tamanho final da ISO?

**R**: Entre 800MB e 1.5GB, dependendo dos pacotes instalados. A compressão zstd reduz significativamente o tamanho.

### P: Posso usar em produção?

**R**: Sim, mas considere:

- Teste extensivamente antes
- Debian Trixie é testing (não estável)
- Para produção crítica, considere Debian Stable

### P: Como atualizar a ISO gerada?

**R**: A ISO é snapshot de um momento. Para atualizações:

1. Instale o sistema
2. Execute `sudo apt update && sudo apt upgrade`
3. Ou recrie a ISO periodicamente

### P: Posso adicionar drivers proprietários?

**R**: Sim! Adicione à lista de pacotes:

```bash
firmware-iwlwifi      # WiFi Intel
firmware-realtek      # Realtek
nvidia-driver         # NVIDIA
```

### P: Como testar a ISO sem gravar em USB?

**R**: Use máquina virtual:

```bash
# Com QEMU
qemu-system-x86_64 -cdrom output/debian-*.iso -m 2048 -boot d

# Com VirtualBox/VMware
# Importe a ISO como CD/DVD virtual
```

### P: A ISO suporta instalação em disco?

**R**: Não diretamente (debian-installer=false). É uma live ISO. Para instalar:

1. Boote a live ISO
2. Use `debootstrap` manualmente, ou
3. Habilite debian-installer modificando lb config

### P: Como usar ZFS na ISO live?

**R**: Execute após boot:

```bash
# Carregar módulo
sudo modprobe zfs

# Criar pool em disco (CUIDADO: apaga dados)
sudo zpool create -f mypool /dev/sdX

# Criar dataset
sudo zfs create mypool/data

# Verificar
zpool status
zfs list
```

### P: Como persistir dados entre boots?

**R**: Use pendrive com partição de persistência:

```bash
# Criar partição de persistência (após gravar ISO)
sudo mkfs.ext4 -L persistence /dev/sdX3

# Montar e configurar
sudo mount /dev/sdX3 /mnt
echo "/ union" | sudo tee /mnt/persistence.conf
sudo umount /mnt

# Boote com: boot=live persistence
```

## 🔧 Correções e Melhorias

### Problemas Resolvidos

#### 1. Falha no Componente de Instalação de Fontes

**Problema**: O build falhava com o erro `fc-cache: command not found` durante a execução do componente de instalação de fontes.

**Solução Implementada**:

- Adicionado o pacote `fontconfig` à lista de pacotes no script principal
- Modificado o componente para verificar se `fc-cache` está disponível antes de executá-lo
- Melhorado o tratamento de erros com mensagem de aviso quando o comando não está disponível

**Arquivos Modificados**:

- `scripts/build-debian-trixie-zbm.sh` (função `generate_live_build_config`)
- Componente `include/usr/local/bin/installer/components/XX-install-fonts.sh` (verificação de disponibilidade do comando)

#### 2. Erro de Sintaxe no Script de Limpeza

**Problema**: O script `clean-build-artifacts.sh` apresentava erro de sintaxe ao calcular o tamanho da imagem Docker.

**Solução Implementada**:

- Corrigido o cálculo de tamanho do Docker com tratamento de erros mais robusto
- Melhorado o uso do comando `bc` para evitar erros de sintaxe
- Adicionado tratamento de erros para quando o Docker não está disponível

**Arquivos Modificados**:

- `clean-build-artifacts.sh` (função `calculate_size`)

### Melhorias de Robustez

#### 1. Script Principal Mais Resiliente

**Melhorias**:

- O script principal agora gera automaticamente configurações corretas
- Todas as correções são aplicadas automaticamente em cada execução
- Estrutura modular com componentes em `include/` para fácil manutenção

#### 2. Nomenclatura Mais Clara

**Melhorias**:

- Script principal renomeado para`build-debian-trixie-zbm.sh`
- Nome mais descritivo que reflete a função e o conteúdo (ZFSBootMenu)
- Todos os arquivos de documentação atualizados para refletir o novo nome

### Como as Correções Funcionam

1. **Build Reprodutível**: Toda vez que você executa `./scripts/build-debian-trixie-zbm.sh`, o script gera automaticamente:
   - Configurações corretas com `fontconfig` incluído
   - Componentes com tratamento de erros melhorado
   - Scripts de entrada Docker atualizados

2. **Resiliência**: Mesmo após executar o script de limpeza, as correções persistirão porque:
   - O script principal regenera tudo automaticamente
   - As correções estão incorporadas no código gerador
   - Estrutura modular em `include/` facilita manutenção

3. **Manutenção Simplificada**: Para atualizar ou corrigir problemas:
   - Modifique apenas o script principal em `scripts/`
   - Execute o build novamente
   - Todas as configurações serão regeneradas automaticamente

## 📚 Referências

- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/)
- [Live Build Documentation](https://manpages.debian.org/testing/live-build/lb.1.en.html)
- [ZFS on Linux](https://openzfs.github.io/openzfs-docs/)
- [kmscon Documentation](https://www.freedesktop.org/wiki/Software/kmscon/)

## 📝 Licença

Este projeto é fornecido "como está", sem garantias. Use por sua conta e risco.

## 🤝 Contribuições

Sugestões e melhorias são bem-vindas! Para modificações:

1. Teste localmente
2. Documente mudanças
3. Verifique compatibilidade
4. Compartilhe resultados

## 📞 Suporte

Para problemas:

1. Verifique a seção "Solução de Problemas"
2. Consulte o FAQ
3. Examine logs do Docker: `docker logs <container-name>`
4. Verifique logs do instalador em `/var/log/installer/` (no sistema instalado)
5. Consulte documentação oficial do Debian

---

**Desenvolvido com ❤️ para a comunidade Debian Brasil**

_Última atualização: Janeiro 2026_
