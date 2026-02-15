# Design Document: Immersive TUI & KMSCON

## Contexto

Este documento detalha o design técnico para a mudança `design-kmscon-gum-immersive-tui-ux`, focada em elevar a experiência do usuário (UX) do instalador em ambiente TTY/Console. O objetivo é criar uma interface imersiva, "premium" e responsiva utilizando `gum` e `kmscon`, seguindo as diretrizes do projeto "Shell Gum Elite" e "Gum UI".

## Arquitetura e Decisões Técnicas

### 1. Runtime Environment (KMSCON)

Substituiremos o `getty` padrão pelo `kmscon` para permitir melhor renderização de fontes e suporte a mouse no framebuffer.

- **Pacote**: `kmscon` (verificar versão/backports em `tools.list.chroot`).
- **Service Override**: Criar um drop-in para `kmscon.service` ou desabilitar `getty@tty1` e habilitar `kmscon`.
- **Configuração**: `/etc/kmscon/kmscon.conf` customizado.
    - `font-name`: "Terminus" ou "Fira Mono" (via Nerd Fonts).
    - `font-size`: 12 a 16 (dependendo da deteção de DPI, se possível, ou um valor seguro default).
    - `term`: `xterm-256color` para suporte total a cores do `gum`.
    - `hwaccel`: `drm2d` (se disponível e estável).

### 2. Design System & Componentes (Gum)

Criaremos uma biblioteca de abstração `libs/ui-gum.sh` que substituirá ou estenderá `ui-utils.sh`. Esta biblioteca implementará os padrões do "Shell Gum Elite".

#### Padrões Visuais (Palette)
Baseado no Slate Blue do projeto e nas definições do skill:
- **Primary**: `#8ECAE6` (Cyan claro)
- **Accent**: `#FFB703` (Amarelo)
- **Background**: O `gum` usará o fundo do terminal (KMSCON).
- **Border**: Rounded, cor `#8ECAE6`.
- **Spinner**: `globe` ou `dot` (conforme skill).

#### Componentes Principais

1.  **`sys_gum_wrapper`**: Função central para verificar presença do `gum` e aplicar temas globais (variáveis de ambiente `GUM_*` conforme skill).
2.  **`sys_header`**: Renderiza o cabeçalho "FILESERVER INSTALLER" com `gum style` e bordas duplas/arredondadas.
3.  **`sys_page`**: Layout grid (Header + Content + Footer) usando `gum join --vertical`.
    - Calcula altura disponível (`tput lines`) para preencher a tela (Immersive mode).
4.  **`sys_select_filter`**: Wrapper para `gum filter` com ícones e fuzzy search.
    - Ícone de item: `➜` (ou similar Nerd Font).
    - Ícone de selecionado: `✔` (verde).
5.  **`sys_input`**: Wrapper para `gum input` com validação e placeholder.
6.  **`sys_confirm`**: Wrapper para `gum confirm` com timeout e default seguro ("No").

### 3. Integração com o Instalador

Os passos existentes (`steps/*.sh`) serão refatorados.

- **Fluxo**: O script controlador (`install.sh`) deve inicializar o ambiente `gum`.
- **Tratamento de Erro**: Trap global para cleanup (`gum spin` interrupted, etc).

## Estrutura de Arquivos

```
config-overrides/
├── config/
│   ├── includes.chroot/
│   │   ├── etc/
│   │   │   └── kmscon/
│   │   │       └── kmscon.conf  [NOVO] Configuração do KMSCON
│   │   ├── usr/
│   │   │   ├── local/
│   │   │   │   └── lib/
│   │   │   │       └── installer/
│   │   │   │           └── libs/
│   │   │   │               └── ui-gum.sh  [NOVO] Biblioteca de componentes Gum
│   │   │   └── share/
│   │   │       └── fonts/
│   │   │           └── (Nerd Fonts se não estiverem no pacote)
```

## Plano de Implementação

1.  **Setup KMSCON & Fonts**:
    - Garantir instalação do `kmscon` e fontes necessárias.
    - Criar `kmscon.conf`.
    - Configurar systemd units para iniciar `kmscon` no tty1.

2.  **Lib UI-Gum**:
    - Criar `ui-gum.sh` implementando `sys_*` functions.
    - Testar isoladamente com um script de "mock".

3.  **Refatoração Piloto**:
    - Selecionar um passo simples (ex: `00-welcome.sh`).
    - Converter para usar `sys_page` e `sys_confirm`.

4.  **Rollout**:
    - Converter todos os passos para o novo modelo.

## Verificação

- **VM Test**: Validar boot em modo BIOS e UEFI.
- **Visual Check**: Verificar se o layout quebra em 80x24 e se expande em 1920x1080.
- **Interactive Check**: Navegar por todos os menus usando teclado.
