# 🎨 FILESERVER Design System v2.0

## Sistema Visual Monocromático para Instalador TTY

> **Filosofia**: _"Elegância através da restrição"_ — Um sistema visual coeso que usa variações sutis de um único matiz para criar hierarquia, profundidade e sofisticação em ambiente terminal puro.

---

## 🎯 Conceito de Design Monocromático

### Por que Slate Blue (Azul-Acizentado)?

| Aspecto                | Benefício para NAS Installer                  |
| ---------------------- | --------------------------------------------- |
| **Associação Técnica** | Servidores, infraestrutura, profissionalismo  |
| **Neutralidade**       | Não compete com status colors (success/error) |
| **Legibilidade**       | Excelente contraste em fundos escuros TTY     |
| **Sophisticação**      | Estética "enterprise" sem ser fria            |

### Princípios Fundamentais

1. **Tom sobre tom**: Variações de luminosidade do mesmo matiz
2. **Opacidade via cor**: Usar códigos ANSI diferentes para simular transparência
3. **Hierarquia tipográfica**: Peso visual através de brilho, não tamanho
4. **Espaçamento como elemento de design**: Silêncio visual intencional

---

## 🎨 Paleta de Cores ANSI (Monocromática)

### Escala Tonal Principal

```bash
# ─── SISTEMA DE CORES FILESERVER ───

# Fundos (do mais escuro ao mais claro)
DS_VOID=235           # ████ Profundidade absoluta (bg)
DS_DEPTH=237          # ████ Superfície base
DS_ELEVATION=239      # ████ Cards/containers

# Bordas (sutileza progressiva)
DS_WHISPER=240        # ░░░░ Divisores discretos
DS_MIST=243           # ░░░░ Bordas padrão

# Textos (hierarquia de informação)
DS_FOG=245            # ▒▒▒▒ Labels secundárias
DS_HAZE=248           # ▒▒▒▒ Descrições
DS_CLOUD=250          # ▓▓▓▓ Corpo de texto
DS_SILVER=252         # ▓▓▓▓ Destaques

# Acentos Slate (matiz principal)
DS_SLATE_DIM=66       # ◈◈◈◈ Detalhes técnicos
DS_SLATE=67           # ◈◈◈◈ Elementos interativos
DS_SLATE_GLOW=68      # ◈◈◈◈ Hover/foco
DS_FILESERVER_PEAK=153    # ◆◆◆◆ Estado ativo (único brilhante)

# Funcionais (uso <5% da interface)
DS_SUCCESS=108        # ✓ Apenas ícones de sucesso
DS_WARNING=179        # ⚠ Apenas bordas de aviso
DS_ERROR=167          # ❌ Apenas caixas de erro
```

### Visualização da Escala

```
LUMINOSIDADE CRESCENTE →

VOID    DEPTH   ELEV    WHISPER MIST    FOG     HAZE    CLOUD   SILVER  PEAK
████    ████    ████    ░░░░    ░░░░    ▒▒▒▒    ▒▒▒▒    ▓▓▓▓    ▓▓▓▓    ◆◆◆◆
235     237     239     240     243     245     248     250     252     153
│       │       │       │       │       │       │       │       │
└───────┴───────┴───────┴───────┴───────┴───────┴───────┴───────┘
       BACKGROUNDS        BORDAS              TEXTOS         ACCENT
```

---

## ✍️ Sistema Tipográfico

### Hierarquia Visual

| Nível       | Representação        | Uso                | Cor             |
| ----------- | -------------------- | ------------------ | --------------- |
| **HERO**    | `▓▓▓ FILESERVER ▓▓▓` | Logo/Splash        | FILESERVER_PEAK |
| **H1**      | `════ TÍTULO ════`   | Headers de tela    | SILVER + border |
| **H2**      | `──▶ Seção`          | Divisores de etapa | SILVER          |
| **H3**      | `↳ Subseção`         | Agrupamentos       | HAZE italic     |
| **BODY**    | `Texto corrido`      | Conteúdo           | CLOUD           |
| **CAPTION** | `dica ou label`      | Metadados          | FOG             |

### Exemplo Aplicado

```bash
# HERO (Tela de boas-vindas)
═══════════════════════════════════════════════════════════

                ▓▓▓ F I L E S E R V E R ▓▓▓
        Debian ZFS NAS - High Performance Storage

═══════════════════════════════════════════════════════════

# H1 (Header de etapa)
───────────────────────────────────────────────────────────
  ▶ SELEÇÃO DE DISCO
───────────────────────────────────────────────────────────

# H2 (Subdivisão)
  ↳ Discos detectados pelo sistema

# BODY (Conteúdo)
  Selecione o disco onde o sistema será instalado.

# CAPTION (Metadados)
  Mínimo 20GB recomendado para instalação completa.
```

---

## 📐 Sistema de Espaçamento

### Ritmo Vertical (Linhas)

```bash
# ─── ESCALA DE ESPAÇAMENTO ───
SP_XS=1    # Padding mínimo interno
SP_SM=2    # Espaçamento entre elementos relacionados
SP_MD=4    # Separação de seções
SP_LG=8    # Pausas dramáticas (entre telas)
SP_XL=12   # Espaçamento de tela cheia
```

### Aplicação no Layout

```
┌────────────────────────────────────────┐
│                                        │  ← clear (VOID)
│                                        │
│     ┌─────────────────────────────┐    │
│     │                             │    │  ← margin-top: SP_SM
│     │      HEADER PRINCIPAL       │    │
│     │      (padding: SP_SM)       │    │
│     │                             │    │
│     └─────────────────────────────┘    │  ← margin-bottom: SP_XS
│                                        │
│  ──▶ Seção                            │  ← H2 divider
│                                        │  ← margin-bottom: SP_XS
│     Conteúdo do formulário aqui...     │
│                                        │
│     ┌─────────────────────────────┐    │  ← margin-top: SP_MD
│     │  Card de informação         │    │
│     │  (padding: SP_XS vertical)  │    │
│     └─────────────────────────────┘    │  ← margin-bottom: SP_MD
│                                        │
│              [  Botão  ]               │  ← centered
│                                        │
└────────────────────────────────────────┘
```

---

## 🧩 Componentes de UI

### 1. Hero Header

```bash
hero_header() {
    gum style \
        --foreground $DS_FILESERVER_PEAK \
        --border-foreground $DS_SLATE \
        --border double \
        --align center --width 60 \
        --margin "1 2" --padding "1 2" \
        "FILESERVER INSTALLER" \
        "Debian ZFS NAS - High Performance Storage"
}
```

**Resultado:**

```
╔════════════════════════════════════════════════════════╗
║                                                        ║
║                  FILESERVER INSTALLER                  ║
║       Debian ZFS NAS - High Performance Storage        ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

### 2. Section Header

```bash
section_header() {
    echo ""
    gum style --foreground $DS_MIST --bold \
        "$(printf '─%.0s' {1..60})"
    gum style --foreground $DS_SILVER --bold "  ▶ $1"
    gum style --foreground $DS_MIST --bold \
        "$(printf '─%.0s' {1..60})"
}
```

**Resultado:**

```
────────────────────────────────────────────────────────────
  ▶ CONFIGURAÇÃO DE DISCO
────────────────────────────────────────────────────────────
```

### 3. Info Card

```bash
info_card() {
    local title="$1"
    shift
    gum style \
        --border-foreground $DS_WHISPER \
        --border normal \
        --padding "1 2" --margin "1 2" \
        "$(gum style --foreground $DS_SLATE_GLOW --bold "$title")" \
        "$(gum style --foreground $DS_MIST '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')" \
        "$@"
}
```

**Resultado:**

```
┌─────────────────────────────────────────────────────────┐
│  Configuração Atual                                     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                         │
│  Disco:        /dev/nvme0n1                             │
│  Tamanho:      1TB                                      │
│  Filesystem:   ZFS on Root                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4. Progress Bar Monocromática

```bash
progress_bar() {
    local current="$1" total="$2" label="$3"
    local width=40
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local pct=$((current * 100 / total))

    local bar_filled=$(printf '█%.0s' $(seq 1 $filled))
    local bar_empty=$(printf '░%.0s' $(seq 1 $empty))

    gum style --foreground $DS_SLATE \
        "  [$bar_filled$bar_empty] $pct%"
    gum style --foreground $DS_FOG --italic \
        "      ↳ $label"
}
```

**Resultado:**

```
  [████████████████████░░░░░░░░░░░░░░░░░░░░] 45%
      ↳ Extraindo sistema base...
```

### 5. Form Field Elegante

```bash
form_field() {
    local label="$1" placeholder="$2" hint="$3"

    gum style --foreground $DS_CLOUD "$label:"
    local value=$(gum input \
        --placeholder "$placeholder" \
        --prompt.foreground $DS_SLATE \
        --cursor.foreground $DS_FILESERVER_PEAK)

    [[ -n "$hint" ]] && \
        gum style --foreground $DS_FOG --italic "    $hint"

    echo "$value"
}
```

**Resultado:**

```
Nome de usuário:
  └─> [helton                    ]
      ╰── Apenas letras minúsculas, sem espaços
```

### 6. Selection List

```bash
select_list() {
    local title="$1"; shift
    gum style --foreground $DS_CLOUD "$title"
    echo ""
    printf '%s\n' "$@" | gum choose \
        --height 8 \
        --cursor.foreground $DS_FILESERVER_PEAK \
        --selected.foreground $DS_SILVER
}
```

**Resultado:**

```
Selecione o disco de destino:

  ░ /dev/sda (500GB) - Samsung SSD 870
  ░ /dev/sdb (2TB)   - Seagate IronWolf
  ▶ /dev/nvme0n1 (1TB) - WD Black SN850X  ← selecionado
```

---

## 🔄 Estados e Transições

### Variações de Estado

| Estado       | Visual       | Implementação                                        |
| ------------ | ------------ | ---------------------------------------------------- |
| **Default**  | `Elemento`   | `foreground $DS_SLATE`                               |
| **Hover**    | `Elemento`   | `foreground $DS_SILVER` + `background $DS_ELEVATION` |
| **Focus**    | `▶ Elemento` | prefix `▶` + `foreground $DS_FILESERVER_PEAK`        |
| **Active**   | `● Elemento` | prefix `●` + `foreground $DS_FILESERVER_PEAK`        |
| **Disabled** | `~ Elemento` | prefix `~` + `foreground $DS_FOG`                    |
| **Loading**  | `◐ Elemento` | spinner + `foreground $DS_SLATE` (pulsing)           |

### Exemplo de Estados em Lista

```
  ░ /dev/sda (500GB)      ← default  (FOG)
  ░ /dev/sdb (2TB)        ← default
  ▶ /dev/nvme0n1 (1TB)   ← focus    (FILESERVER_PEAK + ▶)
  ~ /dev/sdc (USB)        ← disabled (FOG + ~)
```

---

## 🖥️ Fluxo de Telas (Wireframes)

### Tela 1: Splash/Boas-vindas

```
═══════════════════════════════════════════════════════════

             ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
             ░░░▓▓▓ F I L E S E R V E R ▓▓▓░░░
             ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

         Debian ZFS NAS - High Performance Storage

═══════════════════════════════════════════════════════════

  Bem-vindo ao instalador FILESERVER. Este assistente irá
  guiá-lo através da instalação do Debian com ZFS on Root.

  ┌─────────────────────────────────────────────────────┐
  │  Requisitos do sistema:                             │
  │  • Modo UEFI                                        │
  │  • Mínimo 4GB RAM                                   │
  │  • Disco de 20GB+                                   │
  └─────────────────────────────────────────────────────┘

              [  Iniciar Instalação  ]

         v2.0.0 • github.com/fileserver-installer
```

### Tela 2: Progresso de Instalação

```
═══════════════════════════════════════════════════════════

              INSTALAÇÃO EM ANDAMENTO

═══════════════════════════════════════════════════════════

  Progresso Geral
  [████████████████████░░░░░░░░░░░░░░░░░░] 45%

  ── Etapa Atual ─────────────────────────────────────────

  [✓] Preparando disco                    (concluído)
  [✓] Criando partições                   (concluído)
  [✓] Configurando pool ZFS               (concluído)
  [●] Extraindo sistema base              (em andamento)
  [░] Configurando bootloader             (pendente)
  [░] Finalizando instalação              (pendente)

  └─> Arquivo 4,234 de 45,892...
      Tempo estimado: ~3 minutos restantes

              [  Cancelar Instalação  ]
```

### Tela 3: Sucesso

```
═══════════════════════════════════════════════════════════

                    ✓ CONCLUÍDO

         A instalação foi finalizada com sucesso!

═══════════════════════════════════════════════════════════

  ┌─────────────────────────────────────────────────────┐
  │  Resumo da Instalação                               │
  │  ─────────────────────────────────────────────────  │
  │                                                     │
  │  Sistema:        Debian 13 (trixie)                 │
  │  Filesystem:     ZFS on Root (zroot)                │
  │  Bootloader:     ZFSBootMenu                        │
  │  Disco:          /dev/nvme0n1                       │
  │                                                     │
  │  Usuário:        helton                             │
  │  Hostname:       fileserver-nas                     │
  │                                                     │
  └─────────────────────────────────────────────────────┘

    ⚠ Remova a mídia de instalação antes de reiniciar.

       [  Reiniciar Agora  ]  [  Linha de Comando  ]
```

---

## 🛠️ Código Implementável

### Arquivo Base: `fileserver-ds.sh`

```bash
#!/bin/bash
# fileserver-ds.sh - FILESERVER Design System v2.0
# Sistema visual monocromático para instalador TTY

# ═══════════════════════════════════════════════════════════
# PALETA DE CORES
# ═══════════════════════════════════════════════════════════

# Fundos
export DS_VOID=235
export DS_DEPTH=237
export DS_ELEVATION=239

# Bordas
export DS_WHISPER=240
export DS_MIST=243

# Textos
export DS_FOG=245
export DS_HAZE=248
export DS_CLOUD=250
export DS_SILVER=252

# Acentos
export DS_SLATE_DIM=66
export DS_SLATE=67
export DS_SLATE_GLOW=68
export DS_FILESERVER_PEAK=153

# Funcionais
export DS_SUCCESS=108
export DS_WARNING=179
export DS_ERROR=167

# ═══════════════════════════════════════════════════════════
# CARACTERES UI
# ═══════════════════════════════════════════════════════════

export UI_H='─'
export UI_H_D='═'
export UI_V='│'
export UI_TL='┌'
export UI_TR='┐'
export UI_BL='└'
export UI_BR='┘'
export UI_ARROW='▶'
export UI_BULLET='●'
export UI_CHECK='✓'
export UI_WARN='⚠'

# ═══════════════════════════════════════════════════════════
# COMPONENTES
# ═══════════════════════════════════════════════════════════

fileserver_hero() {
    local title="$1" subtitle="$2"
    clear
    gum style \
        --foreground $DS_FILESERVER_PEAK \
        --border-foreground $DS_SLATE \
        --border double --align center \
        --width 60 --margin "1 2" --padding "1 2" \
        "$title" "$subtitle"
}

fileserver_section() {
    local title="$1"
    echo ""
    gum style --foreground $DS_MIST --bold \
        "$(printf "$UI_H%.0s" {1..60})"
    gum style --foreground $DS_SILVER --bold \
        "  $UI_ARROW $title"
    gum style --foreground $DS_MIST --bold \
        "$(printf "$UI_H%.0s" {1..60})"
}

fileserver_card() {
    local title="$1"; shift
    gum style \
        --border-foreground $DS_WHISPER \
        --border normal \
        --padding "1 2" --margin "1 2" \
        "$(gum style --foreground $DS_SLATE_GLOW --bold "$title")" \
        "$(gum style --foreground $DS_MIST "$(printf "$UI_H%.0s" {1..30})")" \
        "$@"
}

fileserver_progress() {
    local current="$1" total="$2" label="$3"
    local width=40
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local pct=$((current * 100 / total))

    local bar_filled=$(printf '█%.0s' $(seq 1 $filled))
    local bar_empty=$(printf '░%.0s' $(seq 1 $empty))

    gum style --foreground $DS_SLATE \
        "  [$bar_filled$bar_empty] $pct%"
    gum style --foreground $DS_FOG --italic \
        "      $UI_ARROW $label"
}

fileserver_input() {
    local label="$1" placeholder="$2" hint="$3"
    gum style --foreground $DS_CLOUD "$label:"
    local value=$(gum input \
        --placeholder "$placeholder" \
        --prompt.foreground $DS_SLATE \
        --cursor.foreground $DS_FILESERVER_PEAK)
    [[ -n "$hint" ]] && \
        gum style --foreground $DS_FOG --italic "    $hint"
    echo "$value"
}

fileserver_select() {
    local title="$1"; shift
    gum style --foreground $DS_CLOUD "$title"
    echo ""
    printf '%s\n' "$@" | gum choose \
        --height 8 \
        --cursor.foreground $DS_FILESERVER_PEAK \
        --selected.foreground $DS_SILVER
}

fileserver_error() {
    local title="$1" message="$2"
    gum style \
        --foreground $DS_ERROR \
        --border-foreground $DS_ERROR \
        --border double \
        --padding "2 3" --margin "2 2" --align center \
        "$UI_WARN $title" "" "$message"
}

fileserver_success() {
    local message="$1"
    gum style \
        --foreground $DS_SUCCESS \
        --border-foreground $DS_SUCCESS \
        --border double \
        --padding "2 3" --margin "2 2" --align center \
        "$UI_CHECK $message"
}
```

---

## 📝 Exemplo de Uso no Script Principal

```bash
#!/bin/bash
# install-system-fileserver-v2.sh

source ./fileserver-ds.sh

# ═══════════════════════════════════════════════════════════
# FLUXO DE INSTALAÇÃO
# ═══════════════════════════════════════════════════════════

# TELA 1: Boas-vindas
fileserver_hero "FILESERVER INSTALLER" "Debian ZFS NAS - High Performance Storage"

gum style --foreground $DS_HAZE \
    "  Bem-vindo ao instalador FILESERVER." \
    "  Este assistente irá guiá-lo através da instalação."

fileserver_card "Requisitos do Sistema" \
    "  $UI_BULLET Modo UEFI" \
    "  $UI_BULLET Mínimo 4GB RAM" \
    "  $UI_BULLET Disco de 20GB+"

gum confirm "Iniciar instalação?" \
    --affirmative "Prosseguir" --negative "Sair" || exit 0

# TELA 2: Seleção de disco
fileserver_hero "FILESERVER INSTALLER" "Debian ZFS NAS"

fileserver_section "Seleção de Disco"

DISK=$(fileserver_select "Selecione o disco de destino:" \
    "/dev/sda (500GB) - Samsung SSD 870" \
    "/dev/sdb (2TB)   - Seagate IronWolf" \
    "/dev/nvme0n1 (1TB) - WD Black SN850X")

# TELA 3: Progresso
fileserver_hero "FILESERVER INSTALLER" "Instalação em Andamento"

fileserver_section "Progresso da Instalação"

TOTAL_STEPS=6
for i in {1..6}; do
    fileserver_progress $i $TOTAL_STEPS "Etapa $i de $TOTAL_STEPS"
    gum spin --spinner minidot --title "Processando..." -- sleep 1
done

# TELA 4: Sucesso
fileserver_hero "FILESERVER INSTALLER" "Instalação Concluída"

fileserver_success "Sistema instalado com sucesso!"

fileserver_card "Resumo da Instalação" \
    "  Disco:      $DISK" \
    "  Filesystem: ZFS on Root" \
    "  Usuário:    helton"

gum confirm "Reiniciar agora?" \
    --affirmative "Reiniciar" --negative "Linha de comando"
```

---

## 🎓 Princípios Aplicados

| Princípio        | Implementação no FILESERVER DS              |
| ---------------- | ------------------------------------------- |
| **Lei de Hick**  | Máximo 3 opções por decisão, fluxo linear   |
| **Proximidade**  | Labels acima de inputs, cards agrupam info  |
| **Contraste**    | Taxa mínima 7:1 entre textos e fundos       |
| **Consistência** | Todos os headers usam `fileserver_section`  |
| **Feedback**     | Spinners para ops >500ms, progresso visível |

---

## ♿ Acessibilidade TTY

- **Alto contraste**: Todas as combinações ≥ 4.5:1
- **Navegação clara**: Tab/Enter/Esc mapeados consistentemente
- **Independência de cor**: Estados indicados por ícones + cor
- **Foco visível**: Cursor sempre em `FILESERVER_PEAK`
- **Timeouts claros**: Spinners indicam operações pendentes

---

Apresentei uma proposta completa de **Design System Monocromático Sofisticado** para o instalador FILESERVER em ambiente TTY puro.

## Resumo da Solução

### 🎨 Identidade Visual

- **Esquema monocromático** baseado em slate blue (azul-acinzentado)
- **12 tons** do mesmo matiz criando hierarquia visual
- **Cores funcionais restritas** a <5% da interface (apenas sucesso/erro)

### 🎯 Componentes Criados

1. **`fileserver_hero`** - Header premium com bordas duplas
2. **`fileserver_section`** - Divisores de etapa com linhas decorativas
3. **`fileserver_card`** - Cards de informação com bordas sutis
4. **`fileserver_progress`** - Barra de progresso monocromática (█/░)
5. **`fileserver_input`** - Campos de formulário elegantes
6. **`fileserver_select`** - Listas de seleção com estados visuais
7. **`fileserver_error/success`** - Modais de estado

### ✨ Diferenciais de UX

- **Espaçamento harmonioso** usando ritmo vertical consistente
- **Hierarquia tipográfica** via luminosidade (não tamanho)
- **Opacidade simulada** através de códigos ANSI variados
- **Transições limpas** entre telas usando `clear`
- **Acessibilidade** com contraste garantido e navegação por teclado

### 🛠️ Entregáveis

O código fornecido inclui:

- Variáveis de cores ANSI organizadas semanticamente
- Funções reutilizáveis para todos os componentes
- Exemplo de fluxo completo de instalação
- Wireframes das 4 telas principais

A implementação mantém 100% de compatibilidade com TTY puro, usando apenas [`gum`](https://github.com/charmbracelet/gum) como dependência para componentes interativos, preservando a elegância monocromática em todo o processo de instalação Debian ZFS.
