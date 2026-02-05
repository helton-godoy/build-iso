## Context

O projeto **build-iso** gera uma ISO Debian Live com módulos ZFS pré-compilados e ZFSBootMenu injetado. Atualmente, a ISO é funcional para boot, mas não possui um instalador automatizado — o usuário precisa executar comandos manualmente para instalar o sistema.

**Estado Atual:**
- ISO gerada via `live-build` em container Docker
- Módulos ZFS DKMS compilados durante build
- Binários ZFSBootMenu disponíveis em `/zbm/`
- Placeholder do instalador em `/usr/local/bin/install-zfs-debian`
- Binário `gum` já incluído na ISO

**Restrições:**
- Ambiente TTY puro (sem X11/Wayland)
- Suporte obrigatório a UEFI e Legacy BIOS (Hybrid Boot)
- Dependência exclusiva de `gum` para UI interativa
- Scripts em Bash com `set -euo pipefail`

## Goals / Non-Goals

**Goals:**
- Instalador interativo completo usando Design System v2.0 monocromático
- Detecção automática de firmware (UEFI/BIOS)
- Particionamento GPT híbrido funcional em ambos os modos
- Pool ZFS `zroot` com datasets otimizados para ZFSBootMenu
- Configuração básica de sistema (hostname, usuário, timezone)
- Instalação e configuração do ZFSBootMenu como bootloader

**Non-Goals:**
- Interface gráfica (GUI) — apenas TTY
- Configuração avançada de rede (DHCP padrão é suficiente)
- Suporte a RAID ZFS (mirror, raidz) — apenas single disk nesta versão
- Dual-boot com outros sistemas operacionais
- Criptografia ZFS nativa (feature futura)

## Decisions

### D1: Arquitetura Modular de Scripts

**Decisão:** Separar o instalador em módulos independentes em `scripts/lib/installer/`.

**Alternativas consideradas:**
- **Script monolítico único** — Difícil manutenção e teste
- **Módulos com source** — ✅ Escolhido: cada capability em arquivo separado

**Estrutura:**
```
scripts/
├── install-zfs-debian           # Entry point principal
└── lib/
    ├── fileserver-ds.sh         # Design System v2.0
    └── installer/
        ├── disk-detection.sh    # Listagem de discos
        ├── firmware-detection.sh # Detecção UEFI/BIOS
        ├── partitioning.sh      # Particionamento GPT
        ├── zfs-setup.sh         # Pool e datasets
        ├── system-config.sh     # Configuração de sistema
        └── zbm-install.sh       # Instalação ZFSBootMenu
```

**Rationale:** Facilita testes unitários por módulo e reutilização de código.

---

### D2: Esquema de Particionamento GPT Híbrido

**Decisão:** Criar 3 partições obrigatórias para suporte universal.

| # | Tipo | Tamanho | Propósito |
|---|------|---------|-----------|
| 1 | BIOS Boot (ef02) | 1 MB | Boot Legacy BIOS |
| 2 | ESP (ef00) | 512 MB | Boot UEFI + ZFSBootMenu |
| 3 | Solaris Root (bf00) | Restante | Pool ZFS `zroot` |

**Alternativas consideradas:**
- **Apenas ESP** — Não suporta Legacy BIOS
- **Partição /boot separada** — Desnecessário com ZFSBootMenu
- **Híbrido MBR+GPT** — ✅ Funciona mas GPT puro com BIOS Boot é mais limpo

**Rationale:** ZFSBootMenu lê diretamente do pool ZFS, eliminando necessidade de /boot separado.

---

### D3: Hierarquia de Datasets ZFS

**Decisão:** Seguir layout otimizado para ZFSBootMenu.

```
zroot                           # Pool raiz
├── ROOT                        # Container de boot environments
│   └── debian                  # BE padrão (mountpoint=/)
├── home                        # Dados de usuários (mountpoint=/home)
└── var                         # Dados variáveis
    ├── cache                   # Cache (com=off)
    ├── log                     # Logs (com=zstd)
    └── tmp                     # Temporários (com=off, sync=disabled)
```

**Propriedades críticas:**
- `zroot/ROOT`: `canmount=off`, `org.zfsbootmenu:commandline="quiet"`
- `zroot/ROOT/debian`: `canmount=noauto`, `mountpoint=/`

**Rationale:** Estrutura compatível com snapshots atômicos e boot environments.

---

### D4: Fluxo de Telas do Instalador

**Decisão:** Wizard linear de 6 etapas.

```
1. Welcome      → Requisitos e confirmação
2. Disk Select  → Seleção de disco alvo
3. Config       → Hostname, usuário, timezone
4. Confirm      → Resumo e confirmação final
5. Install      → Progresso de instalação
6. Complete     → Sucesso e opções de reinício
```

**Alternativas consideradas:**
- **Menu principal com opções** — Mais complexo, menos guiado
- **Wizard linear** — ✅ Escolhido: mais intuitivo para usuários

---

### D5: Hook de Inclusão na ISO

**Decisão:** Copiar scripts para `/usr/local/bin/` via `includes.chroot`.

**Implementação:**
- `config-overrides/includes.chroot/usr/local/bin/install-zfs-debian` (entry point)
- `config-overrides/includes.chroot/usr/local/lib/installer/` (módulos)

**Rationale:** `includes.chroot` é o mecanismo padrão do live-build para arquivos customizados.

## Risks / Trade-offs

| Risco | Mitigação |
|-------|-----------|
| **Destruição de dados** | Confirmação dupla antes de particionar; dry-run disponível |
| **Falha de detecção UEFI** | Fallback para verificação de `/sys/firmware/efi` |
| **gum não disponível** | Verificação de dependências no início do script |
| **Pool ZFS corrompido** | Uso de `zpool import -f` apenas como último recurso |
| **Boot falha após instalação** | Validação do ZFSBootMenu antes de finalizar |

**Trade-offs aceitos:**
- **Sem dry-run completo** — Particionamento é sempre destrutivo; apenas confirmação verbal
- **Single disk apenas** — Simplifica V1, mirror/raidz em versão futura
- **Sem rollback automático** — Usuário pode rebootar da ISO e tentar novamente
