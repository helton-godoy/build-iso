## Why

O instalador em TTY já evoluiu em usabilidade, mas ainda não oferece uma experiência visual verdadeiramente imersiva para usuários comuns em console puro. Precisamos padronizar um modelo de UI full-width/full-height no `gum` e um perfil operacional do KMSCON para reduzir ansiedade, aumentar clareza e manter previsibilidade em hardware real sem desktop.

## What Changes

- Definir um padrão de layout responsivo para TUI com ocupação total de largura/altura do terminal, com grade visual e hierarquia para evitar poluição da tela.
- Padronizar componentes `gum` para navegação educativa (orientação contextual, seleção com filtro, multisseleção com filtro e cartões de resumo de impacto).
- Especificar perfil de execução KMSCON para ambiente de produção (TTY puro) com foco em renderização estável, mouse e parâmetros de experiência visual.
- Definir diretriz de tipografia/ícones para framebuffer (Nerd Font recomendada, critérios de fallback e consistência de box-drawing).
- Documentar critérios de nitidez de texto (fontconfig/hinting no ambiente base) e limites conhecidos do stack TTY/KMSCON.

## Capabilities

### New Capabilities
- `immersive-tui-layout`: Modelo de layout full-width/full-height com regras de composição visual para telas `gum` em TTY.
- `gum-responsive-components`: Biblioteca de padrões de componentes `gum` para filtros, seleções longas, orientação e feedback pedagógico.
- `kmscon-runtime-profile`: Perfil de configuração e inicialização do KMSCON para uso interativo em servidor físico com foco em UX.
- `tty-typography-and-icon-profile`: Requisitos de fonte, ícones, fallback e nitidez para alta legibilidade no framebuffer.
- `tui-ux-validation-checklist`: Critérios de validação manual/operacional para garantir consistência visual e ergonomia em KMSCON/TTY.

### Modified Capabilities
- Nenhuma (não há specs base em `openspec/specs` para delta no momento).

## Impact

- Bibliotecas e componentes do instalador em `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/` (especialmente `ui-utils.sh` e integrações de seleção/filtro).
- Steps interativos em `config-overrides/config/includes.chroot/usr/local/lib/installer/steps/` que exibem fluxos de locale, teclado, timezone, discos e revisão.
- Configuração operacional KMSCON no sistema live: package list, hook de ativação e override de serviço em `config-overrides/config/`.
- Documentação técnica e playbooks de validação para operação em TTY real.
