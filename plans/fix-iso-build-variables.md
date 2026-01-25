# Plano de Correção - Build da ISO e Variáveis de Ambiente

O build da ISO falhou porque as variáveis de ambiente necessárias para o `live-build` (como `DEBIAN_VERSION`) não foram passadas para o container Docker. Além disso, identifiquei uma corrupção de sintaxe no script principal.

## Tarefas

- [ ] Corrigir corrupção de sintaxe no script `build-debian-trixie-zbm.sh` (linha 1315).
- [ ] Atualizar a função `run_iso_build` no script `build-debian-trixie-zbm.sh` para passar as variáveis de ambiente necessárias via `docker run -e`.
- [ ] Verificar e limpar o script `clean-build-artifacts.sh` para garantir que não restam corrupções.
- [ ] Validar a geração do script `configure-live-build.sh`.

## Detalhes Técnicos

### Variáveis a serem passadas para o Docker

- `DEBIAN_VERSION`
- `ARCH`
- `LOCALE`
- `TIMEZONE`
- `KEYBOARD`

### Correção de Sintaxe

Substituir:
`print_message "error" "Comando inválido:$$$$$$${$}c}o}m}m}a}n}d"`
Por:
`print_message "error" "Comando inválido: ${command}"`

---

_Antigravity - Optimization Consultant_
