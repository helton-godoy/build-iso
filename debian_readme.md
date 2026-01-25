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

### 1. Clone o Repositório (ou crie os arquivos)

```bash
mkdir debian-trixie-builder
cd debian-trixie-builder
```

### 2. Copie o Script Principal

Salve o conteúdo do script `build-debian-trixie-zbm.sh` no diretório criado.

### 3. Torne o Script Executável

```bash
chmod +x build-debian-trixie-zbm.sh
```

## 💻 Uso

### Build Padrão

```bash
./build-debian-trixie-zbm.sh
```

ou explicitamente:

```bash
./build-debian-trixie-zbm.sh build
```

### Rebuild Completo

Limpa tudo e reconstrói:

```bash
./build-debian-trixie-zbm.sh help
```

## 📁 Estrutura do Projeto

```
debian-trixie-builder/
├── build-debian-trixie-zbm.sh      # Script principal
├── Dockerfile                   # Gerado automaticamente
├── docker-entrypoint.sh        # Gerado automaticamente
├── config/
│   ├── configure-live-build.sh # Configuração do live-build
│   ├── hooks/                  # Hooks de personalização
│   └── includes.chroot/        # Arquivos a incluir no sistema
├── build/                      # Diretório temporário de build
└── output/                     # ISOs e checksums gerados
    ├── debian-trixie-zbm-YYYYMMDD.iso
    └── debian-trixie-zbm-YYYYMMDD.iso.sha256
```

## 🎨 Personalização

### Modificar Pacotes

Edite `config/configure-live-build.sh` e modifique a seção:

```bash
cat > config/package-lists/custom.list.chroot << 'PKGLIST'
# Adicione seus pacotes aqui
seu-pacote
outro-pacote
PKGLIST
```

### Adicionar Hooks Personalizados

Crie novos hooks em `config/hooks/normal/`:

```bash
cat > config/hooks/normal/0050-meu-hook.hook.chroot << 'EOF'
#!/bin/bash
set -e

# Suas personalizações aqui
echo "Executando personalização customizada"
EOF
chmod +x config/hooks/normal/0050-meu-hook.hook.chroot
```

### Modificar Configurações de Boot

No script `configure-live-build.sh`, modifique a linha:

```bash
--bootappend-live "boot=live components quiet splash locales=pt_BR.UTF-8 timezone=America/Sao_Paulo keyboard-layouts=br seu_parametro=valor"
```

### Alterar Locale/Timezone

Modifique as variáveis no início de `build-debian-trixie.sh`:

```bash
readonly LOCALE="en_US.UTF-8"      # Exemplo para inglês
readonly TIMEZONE="America/New_York"
readonly KEYBOARD="us"
```

### Personalizar Usuário Padrão

Edite o hook `0030-configure-system.hook.chroot`:

```bash
useradd -m -s /bin/bash -G sudo meuusuario
echo "meuusuario:minhasenha" | chpasswd
```

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

### Erro Durante Hooks

Se um hook falhar, examine o log:

```bash
# Log é salvo em build/live-build-config/build.log
less build/live-build-config/build.log
```

Desabilite o hook problemático comentando-o ou removendo-o.

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

#### 1. Falha no Hook de Instalação de Fontes (0015-install-nerd-fonts)

**Problema**: O build falhava com o erro `fc-cache: command not found` durante a execução do hook de instalação de fontes.

**Solução Implementada**:

- Adicionado o pacote `fontconfig` à lista de pacotes no script principal
- Modificado o hook para verificar se `fc-cache` está disponível antes de executá-lo
- Melhorado o tratamento de erros com mensagem de aviso quando o comando não está disponível

**Arquivos Modificados**:

- `build-debian-trixie-zbm.sh` (função `generate_live_build_config`)
- Hook `0015-install-nerd-fonts.hook.chroot` (verificação de disponibilidade do comando)

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
- Não é mais necessário preservar manualmente o diretório `config/`

#### 2. Nomenclatura Mais Clara

**Melhorias**:

- Script principal renomeado de `debian_trixie_builder-v2.sh` para `build-debian-trixie-zbm.sh`
- Nome mais descritivo que reflete a função e o conteúdo (ZFSBootMenu)
- Todos os arquivos de documentação atualizados para refletir o novo nome

### Como as Correções Funcionam

1. **Build Reprodutível**: Toda vez que você executa `./build-debian-trixie-zbm.sh`, o script gera automaticamente:
   - Configurações corretas com `fontconfig` incluído
   - Hooks com tratamento de erros melhorado
   - Scripts de entrada Docker atualizados

2. **Resiliência**: Mesmo após executar o script de limpeza, as correções persistirão porque:
   - O script principal regenera tudo automaticamente
   - As correções estão incorporadas no código gerador
   - Não dependem de arquivos estáticos

3. **Manutenção Simplificada**: Para atualizar ou corrigir problemas:
   - Modifique apenas o script principal
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
3. Examine logs em `build/live-build-config/build.log`
4. Verifique documentação oficial do Debian

---

**Desenvolvido com ❤️ para a comunidade Debian Brasil**

_Última atualização: Janeiro 2026_
