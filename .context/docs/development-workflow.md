---
type: doc
name: development-workflow
description: Day-to-day engineering processes, branching, and contribution guidelines
category: workflow
generated: 2026-01-25
status: unfilled
scaffoldVersion: "2.0.0"
---

## Development Workflow

O desenvolvimento neste projeto segue um fluxo simples baseado em Git. As mudanças são feitas diretamente na branch principal (main), com testes executados localmente antes do commit. Commits seguem Conventional Commits para facilitar o versionamento.

## Branching & Releases

- **Modelo**: Trunk-based development (desenvolvimento direto na branch main)
- **Releases**: Tags semânticas (v1.0.0, v1.1.0, etc.)
- **Branches**: Apenas branch main, sem branches de feature

## Local Development

- **Dependências**: Nenhuma instalação adicional necessária (usa ferramentas do sistema)
- **Execução**: `./build-debian-trixie-zbm.sh` para construir a ISO
- **Teste**: `./tests/test_installer.bats` para executar testes
- **Build**: O script principal já gera a ISO final

## Code Review Expectations

Revisões de código focam em:
- Segurança e robustez dos scripts Bash
- Tratamento adequado de erros
- Documentação clara de funções
- Testes cobrindo novos recursos

## Onboarding Tasks

Para novos contribuidores:
1. Executar os testes existentes
2. Construir uma ISO de teste
3. Revisar os componentes do installer
4. Familiarizar-se com ZFS e Debian
