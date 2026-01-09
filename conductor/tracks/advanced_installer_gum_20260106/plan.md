# Plano da Trilha: Instalador Avançado com Gum

## Fase 1: Infraestrutura do `gum` [checkpoint: 387a2f1]

- [x] Task: Integrar download do `gum` (binário estático) no pipeline de build.
- [x] Task: Garantir a presença do `gum` em `/usr/local/bin/` na ISO.

## Fase 2: Refatoração da Interface (TUI) [checkpoint: 5a7e1f2]

- [x] Task: Implementar Welcome Screen e Seleção de Disco com `gum`.
- [x] Task: Implementar formulários de Hostname, Usuário e Senhas.
- [x] Task: Criar prompt de confirmação destrutiva estilizado.

## Fase 3: Lógica de Instalação e Chroot [checkpoint: d1e2f3a]

- [x] Task: Implementar montagem de sistemas virtuais e entrada em `chroot`.
- [x] Task: Executar tarefas de finalização (initramfs, users, locales) no alvo.
- [x] Task: Adicionar suporte a propriedades nativas do ZFSBootMenu.

## Fase 4: Resiliência e Testes [checkpoint: pending]

- [x] Task: Implementar logs de instalação e `trap` de limpeza.
- [~] Task: Validar instalação completa via `test-iso.sh`.
- [ ] Task: Conductor - User Manual Verification 'Instalador Avançado com Gum'
