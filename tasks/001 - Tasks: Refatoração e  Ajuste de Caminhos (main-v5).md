# 001 - Tasks: Refatoração, Isolamento e Sincronização (main-v5)

- [x] Isolar ambiente de build no diretório `build/`
    - [x] Atualizar `Makefile` para usar `rsync` de `config-overrides/config/` para `build/config/`
    - [x] Garantir que `logs/`, `output/` e `build/` sejam independentes da raiz
- [x] Refatorar script de build Docker
    - [x] Ajustar `scripts/build-iso-in-docker.sh` para operar dentro de `build/`
    - [x] Remover criação de links simbólicos na raiz do projeto
- [/] Validar Scripts de VM
    - [ ] Testar `scripts/vm/vm-start-test-boot-iso.sh` com ISO em `output/` [/]
    - [ ] Garantir que scripts de VM usem caminhos relativos ao diretório `scripts/vm` [/]
- [x] Limpeza e Organização
    - [x] Remover links simbólicos residuais na raiz (`config`, `cache`, `local`, `binary`, `.build`) usando `sudo` se necessário
    - [x] Mover `auto/` para `config-overrides/auto/` e sincronizar via `Makefile`
    - [x] Atualizar `.gitignore` para a nova estrutura
- [ ] Verificação Final
    - [ ] Executar build completo via `make build` [/]
    - [ ] Validar se a raiz permanece limpa de artefatos temporários [/]
