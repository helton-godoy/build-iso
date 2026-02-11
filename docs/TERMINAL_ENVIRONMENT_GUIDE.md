# Guia rápido – Ecossistema de terminal bonito para servidor Debian (Samba + ZFS + AD)

Este guia é uma **versão condensada** do que foi descrito na conversa. Serve como base para você salvar, imprimir ou ir adaptando na sua distro.

---

## 1. Objetivo do ambiente

- Servidor NAS / AD (Samba sobre ZFS), administrado **100% via terminal**.
- Experiência amigável para iniciantes, inclusive usuários acostumados com Windows.
- Console local poderoso com **KMSCON**, fontes bonitas, ícones e até imagens.
- Acesso remoto via SSH focado em TUI (text user interfaces) e compatibilidade.

---

## 2. KMSCON – console gráfico leve

### 2.1 Instalação básica

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y kmscon kmscon-fonts \
  libdrm-dev libgbm-dev libegl-dev libgles2-mesa-dev
```

### 2.2 Ativar KMSCON nos TTYs

```bash
sudo systemctl enable kmscon@tty1.service
sudo systemctl enable kmscon@tty2.service
sudo systemctl enable kmscon@tty3.service
# repita para tty4–tty6 se quiser
```

### 2.3 Configuração base (exemplo)

Crie/edite `/etc/kmscon/kmscon.conf`:

```ini
video-engine=drm
text-encoding=utf8
mouse=yes
xterm-compat=yes
background=black
foreground=white
font-name=FiraCode Nerd Font Mono
font-size=13
scroll-back=5000
```

Reinicie para testar:

```bash
sudo reboot
```

---

## 3. Fonte recomendada (box-drawing + ícones)

Para um terminal bonito, legível, com bordas perfeitas e ícones:

### 3.1 FiraCode Nerd Font (recomendada)

```bash
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip
unzip FiraCode.zip
rm FiraCode.zip
fc-cache -fv
```

Depois, garanta em `/etc/kmscon/kmscon.conf`:

```ini
font-name=FiraCode Nerd Font Mono
```

### 3.2 Símbolos úteis (Unicode simples)

Você pode usar estes símbolos mesmo sem emoji colorido:

- Sucesso: ✓
- Erro: ✗
- Aviso: ⚠
- Info: ℹ
- Setas: → ← ↑ ↓
- Caixas: ─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼

Exemplo em script:

```bash
ICON_OK="✓"
ICON_FAIL="✗"

echo "$ICON_OK Operação concluída"
echo "$ICON_FAIL Falhou"
```

---

## 4. Núcleo visual: shell, prompt e multiplexador

### 4.1 Shell (Fish ou Bash)

Instale Fish (mais amigável para iniciantes):

```bash
sudo apt install -y fish
chsh -s /usr/bin/fish
```

### 4.2 Starship – prompt bonito e informativo

```bash
curl -sS https://starship.rs/install.sh | sh
```

Crie `~/.config/starship.toml` com algo simples:

```toml
[character]
success_symbol = "➜"
error_symbol = "➜"

[directory]
truncation_length = 3
style = "bold cyan"

[hostname]
ssh_only = false
format = "[$hostname]($style) "
style = "bold blue"

[time]
disabled = false
format = "🕒 [$time]($style) "
style = "bold white"
```

Para ativar:

- Bash: adicione a `~/.bashrc`:
  
  ```bash
  eval "$(starship init bash)"
  ```

- Fish: adicione a `~/.config/fish/config.fish`:
  
  ```fish
  starship init fish | source
  ```

### 4.3 Tmux – base para dashboards

```bash
sudo apt install -y tmux
```

Configuração rápida `~/.tmux.conf`:

```conf
set -g prefix C-b
set -g default-terminal "screen-256color"
set -g mouse on
set -g history-limit 10000
setw -g mode-keys vi

# Divisões rápidas
bind | split-window -h
bind - split-window -v
```

Dashboards em tmux (ideia): uma janela com `htop`/`btop`, outra com `tail -f` de logs do Samba, outra com status do ZFS.

---

## 5. Ferramentas essenciais para seu cenário

### 5.1 Administração geral

Instale em bloco:

```bash
sudo apt install -y \
  htop btop iotop iftop nethogs glances ncdu \
  ranger nnn vifm lsd bat ripgrep fzf jq yq \
  tree gum figlet cowsay lolcat
```

Sugestão de uso:

- `btop` – monitor de CPU/RAM/disk **bonito**.
- `glances` – visão geral do sistema (CPU/RAM/disk/rede).
- `ranger` ou `nnn` – gerenciador de arquivos em TUI.
- `lsd` – `ls` com ícones e cores.
- `bat` – `cat` melhorado com syntax highlight.
- `fzf` – seleção interativa (buscar usuário, dataset, arquivo etc.).

### 5.2 Samba + Active Directory

```bash
sudo apt install -y samba samba-dsdb-modules samba-vfs-modules smbclient ldap-utils
```

Comandos chave:

- Usuários AD:
  
  ```bash
  samba-tool user list
  samba-tool user create NOME SENHA
  samba-tool user delete NOME
  samba-tool user show NOME
  ```

- Grupos AD:
  
  ```bash
  samba-tool group list
  samba-tool group add NOME
  samba-tool group addmembers GRUPO USUARIO1 USUARIO2
  ```

- Máquinas/computadores:
  
  ```bash
  samba-tool computer list
  ```

### 5.3 ZFS (pools, datasets, snapshots)

```bash
sudo apt install -y zfsutils-linux zfs-auto-snapshot sanoid syncoid
```

Comandos chave:

- Pools:
  
  ```bash
  zpool list
  zpool status -v
  ```

- Datasets:
  
  ```bash
  zfs list
  zfs create tank/compartilhamento
  ```

- Snapshots:
  
  ```bash
  zfs snapshot tank/dados@diario-$(date +%Y%m%d)
  zfs list -t snapshot
  ```

- Auto-snapshots (zfs-auto-snapshot já cria periodicamente).

---

## 6. Menu e dashboard simples (para iniciantes)

### 6.1 Dashboard rápido

Crie `/usr/local/bin/dashboard-server.sh`:

```bash
#!/bin/bash
clear

echo "================ DASHBOARD SAMBA + ZFS ================"

# Samba
echo "[SAMBA]"
systemctl is-active --quiet samba && \
  echo "  ✔ Samba ativo" || echo "  ✗ Samba inativo"

# ZFS pools
echo ""
echo "[ZFS POOLS]"
if command -v zpool >/dev/null 2>&1; then
  zpool list
else
  echo "  ZFS não instalado"
fi

# Sistema
echo ""
echo "[SISTEMA]"
uptime
free -h | sed -n '1,2p'

echo "======================================================="
```

Dê permissão de execução:

```bash
sudo chmod +x /usr/local/bin/dashboard-server.sh
```

Execute com:

```bash
dashboard-server.sh
```

### 6.2 Menu administrativo simples

Crie `/usr/local/bin/admin-menu`:

```bash
#!/bin/bash

while true; do
  clear
  echo "╔══════════════════════════════════════╗"
  echo "║    MENU ADMINISTRAÇÃO SAMBA + ZFS    ║"
  echo "╚══════════════════════════════════════╝"
  echo "1) Dashboard"
  echo "2) Monitor (btop)"
  echo "3) Usuários AD"
  echo "4) Pools ZFS"
  echo "0) Sair"
  echo ""
  read -p "Escolha uma opção: " op

  case "$op" in
    1) /usr/local/bin/dashboard-server.sh ; read -p "Enter..." _ ;;
    2) btop ;;
    3) samba-tool user list | less ;;
    4) zpool list | less ;;
    0) exit 0 ;;
    *) echo "Opção inválida"; sleep 1 ;;
  esac
done
```

Permissão:

```bash
sudo chmod +x /usr/local/bin/admin-menu
```

Opcional: adicionar alias ao shell (em `~/.bashrc` ou `~/.config/fish/config.fish`):

```bash
alias menu='/usr/local/bin/admin-menu'
```

Assim, o usuário só precisa digitar:

```bash
menu
```

---

## 7. Imagens no terminal (console local)

Para visualização rápida (thumbnails, gráficos simples) no console local:

```bash
sudo apt install -y libsixel-bin chafa imagemagick ffmpeg
```

- Imagem como Sixel:
  
  ```bash
  img2sixel foto.jpg
  ```

- Converter imagem para ASCII colorido (compatível também com SSH):
  
  ```bash
  chafa --format=ansi imagem.jpg
  ```

Para algo mais avançado, use `timg` ou `viu` (compilados via `cargo`) – permitem mostrar grids de imagens e até PDFs direto no terminal.

---

## 8. Fluxo típico de uso (resumido)

1. **Console local** sobe com KMSCON, fonte FiraCode NF e cores bonitas.
2. Usuário faz login e vê mensagem: “Digite `menu` para administrar o servidor”.
3. No `menu`, escolhe:
   - Dashboard → ver saúde geral.
   - Usuários AD → ver lista rapidamente.
   - Pools ZFS → conferir espaço/capacidade.
4. Para tarefas mais avançadas, usa diretamente:
   - `samba-tool` (AD, grupos, computadores)
   - `zpool` / `zfs` (pools, datasets, snapshots)
5. Para monitoramento contínuo, abre `tmux` e deixa janelas com:
   - `btop`, logs do Samba, `zpool status`, etc.

---

## 9. Próximos passos sugeridos

- Criar **wizards** em shell (usando `gum`) para:
  - Criar usuário AD com perguntas passo a passo.
  - Criar compartilhamento ZFS+Samba (dataset + entrada no `smb.conf`).
- Criar dashboard mais rico com cores e box-drawing.
- Automatizar snapshots e backups com `sanoid` e `syncoid`.
- Escrever uma documentação em PT-BR voltada ao “usuário Windows” explicando:
  - Como entrar no servidor.
  - Como abrir o menu.
  - O que significam as principais opções.

---

Este arquivo é um ponto de partida. A partir dele você pode ir expandindo para chegar naquele ecossistema "distro temática de terminal" bem completo e amigável que você descreveu.