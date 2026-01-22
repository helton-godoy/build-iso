# AGENTS.md - Live-build Config

**IDIOMA:** Comunicar-se sempre em **Português (pt_BR)**.

## OVERVIEW

Configuração live-build para geração da ISO Aurora OS (bootstrap → chroot → binary).

## WHERE TO LOOK

- **Adicionar/remover pacotes**: `package-lists/*.list.chroot` (categorias por funcionalidade)
- **Configurar sistema**: `config/binary` (boot params, bootloader), `config/common` (apt, distribuição)
- **Customizar chroot**: `hooks/live/*.hook.chroot` (ZFS, locale, QT, framebuffer)
- **Criar squashfs modulares**: `hooks/normal/0990-modular-squashfs.hook.binary`
- **Layers de sistema**: `layers/*.list.chroot` (dependências: 00 → 01 → 10 → 20)

## CONVENTIONS

- **Arquivos list**: `NN-descrição.list.chroot` (NN = ordem de execução)
- **Hooks live**: `NNNN-descrição.hook.chroot` (shebang obrigatório `#!/bin/sh`)
- **Hooks binary**: `NNNN-descrição.hook.binary` (modular squashfs = 0990)
- **Nomenclatura pacotes**: nome apenas (sem versão), linhas vazias separam categorias
- **Comentários**: `# === Categoria ===` para seções, `#` para itens
- **Variáveis LB_**: UPPER_CASE, prefixo `LB_` (ex: `LB_BOOTAPPEND_LIVE`)
- **Shebang**: `#!/bin/sh` em hooks (compatibilidade live-build)
- **Locale**: pt_BR.UTF-8, teclado br, fuso America/Cuiaba (obrigatório)

## ANTI-PATTERNS

- **NUNCA** usar `set -e` fora de hooks (quebra live-build)
- **NUNCA** modificar `LB_BUILD_WITH_CHROOT="false"` (segurança)
- **NUNCA** adicionar pacotes com versão fixa (ex: `pacote=1.2.3`)
- **NUNCA** instalar plymouth (quebra `LB_BOOTAPPEND_LIVE` sem splash)
- **NUNCA** colocar pacotes de teste em `00-core` (layer base imutável)
- **NUNCA** misturar layers sem ordem (dependem de 00 → 01 → 10 → 20)

## NOTES

- `hooks/normal/` contém symlinks para `/usr/share/live/build/hooks/normal/` (não modificar)
- `hooks/live/0010-*`, `hooks/live/0050-*` são symlinks upstream (não modificar)
- Squashfs modular separa layers por diretórios: `/live/filesystem.squashfs.*`
- `LB_COMPRESSION="none"` em `config/binary` (squashfs comprimido no hook 0990)
- `config/bootstrap`, `config/chroot` são autogerados (não editar)
- `config/source` está vazio (sem fontes do kernel customizadas)
- `package-lists/` e `layers/` têm conteúdo diferente (não duplicar)
- DKMS ZFS compilado em `hooks/live/0100-compile-zfs-dkms.hook.chroot`
