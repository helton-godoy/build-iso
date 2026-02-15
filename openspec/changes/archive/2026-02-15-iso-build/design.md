## Context

O projeto **build-iso** gera uma ISO Debian Live com módulos ZFS pré-compilados e ZFSBootMenu injetado. Atualmente, a ISO é funcional para boot, mas não possui um instalador automatizado — o usuário precisa executar comandos manualmente para instalar o sistema.

**Estado Atual:**
- ISO gerada via `live-build` em container Docker
- Módulos ZFS DKMS compilados durante build
- Binários ZFSBootMenu disponíveis em `/zbm/`
- Entrypoint do instalador em `/usr/local/bin/installer`
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
- Criação automática de topologias avançadas sem confirmação explícita do usuário
- Dual-boot com outros sistemas operacionais
- Criptografia ZFS nativa (feature futura)

## Decisions

### D1: Arquitetura Modular de Scripts

**Decisão:** Separar o instalador em módulos independentes em `config-overrides/config/includes.chroot/usr/local/lib/installer/`.

**Alternativas consideradas:**
- **Script monolítico único** — Difícil manutenção e teste
- **Módulos com source** — ✅ Escolhido: cada capability em arquivo separado

**Estrutura:**
```
config-overrides/config/includes.chroot/usr/local/
├── bin/installer                # Entry point principal
└── lib/installer/
    ├── libs/                    # Módulos utilitários por capability
    │   ├── disk-utils.sh
    │   ├── boot-utils.sh
    │   ├── partitioning.sh
    │   ├── zfs-utils.sh
    │   ├── system-config.sh
    │   └── zbm-install.sh
    └── steps/                   # Etapas do wizard
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
- `zroot/ROOT/debian`: `org.zfsbootmenu:commandline` inclui `root=zfs:zroot/ROOT/debian` e `spl.spl_hostid`

**Rationale:** Estrutura compatível com snapshots atômicos e boot environments.

---

### D4: Fluxo de Telas do Instalador

**Decisão:** Wizard guiado com fluxo expandido por etapas de coleta, revisão e execução.

```
1. Welcome e Preferências
2. Identidade, Rede e Tempo
3. Seleção de discos e estratégia ZFS
4. Configuração de propriedades e datasets
5. Revisão final
6. Instalação e pós-instalação
7. Tela de conclusão
```

**Alternativas consideradas:**
- **Menu principal com opções** — Mais complexo, menos guiado
- **Wizard linear** — ✅ Escolhido: mais intuitivo para usuários

---

### D5: Hook de Inclusão na ISO

**Decisão:** Copiar scripts para `/usr/local/bin/` via `includes.chroot`.

**Implementação:**
- `config-overrides/config/includes.chroot/usr/local/bin/installer` (entry point)
- `config-overrides/config/includes.chroot/usr/local/lib/installer/` (módulos)

**Rationale:** `includes.chroot` é o mecanismo padrão do live-build para arquivos customizados.

---

### D6: Cmdline do ZFSBootMenu no Dataset Bootável

**Decisão:** Aplicar `org.zfsbootmenu:commandline` diretamente em `zroot/ROOT/debian` com
`root=zfs:zroot/ROOT/debian` e `spl.spl_hostid=<hostid>` quando disponível.

**Rationale:** Evita ambiguidade de herança entre datasets e alinha explicitamente o artefato de
especificação com o comportamento de boot esperado.

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
- **Multi-disco com confirmação** — Fluxo aceita múltiplos discos, exigindo revisão explícita antes da instalação
- **Sem rollback automático** — Usuário pode rebootar da ISO e tentar novamente
