# Configuração do kmscon - Build-ISO

## Versão Compilada
- **Pacote**: `kmscon-custom_9.3.0_amd64.deb`
- **Fonte**: https://github.com/Aetf/kmscon.git (branch master)
- **Epoch**: `99:9.3.0-custom` (evita substituição por repos oficiais)

## Recursos Habilitados (v9.3+)

### Renderização
- **Motor**: Pango (suporte a Unicode, CJK, Emoji colorido)
- **Fonte**: FiraCode Nerd Font Mono
- **Aceleração**: Hardware via OpenGL ESv2 (gltex)
- **DPI**: Configurável (96=100%, 144=150%, 192=200%)

### Mouse (kmscon 9.3+)
- Suporte nativo via libinput
- Seleção de texto com clique+arrastar
- Colagem com clique central
- Compatível com vim, htop, mc

### Emojis Coloridos
- FontConfig com fallback para Noto Color Emoji
- Hinting habilitado para evitar bug Cairo/Pango
- Ref: https://www.reddit.com/r/archlinux/comments/j0z3a8/

### Múltiplas Sessões
- `session-control` habilitado
- Atalhos:
  - `Ctrl+Logo+Enter`: Nova sessão
  - `Ctrl+Logo+Right/Left`: Alternar sessões
  - `Ctrl+Logo+W`: Fechar sessão

### Tema
- Paleta Dracula (https://draculatheme.com/)

## Referências
- Fedora 44: https://fedoraproject.org/wiki/Changes/UseKmsconVTConsole
- Arch Wiki: https://wiki.archlinux.org/title/KMSCON
- Man page: https://manpages.debian.org/unstable/kmscon/kmscon.1.en.html
