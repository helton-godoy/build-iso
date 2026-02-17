#!/usr/bin/env bash
set -euo pipefail

echo "Validação manual KMSCON/TTY - filtros e listas extensas

Pré-requisitos:
1) Executar em TTY/KMSCON (não em terminal gráfico)
2) Garantir resolução mínima 80x24

Checklist:
[ ] Locale: digitar 'pt_BR' e confirmar redução de lista
[ ] Teclado: digitar 'br' e confirmar seleção correta
[ ] Timezone: digitar 'America/Cuiaba' e confirmar filtro
[ ] Discos: usar filtro + marcação múltipla (Espaço/Enter)
[ ] Ajuda de teclado visível nos componentes de seleção
[ ] Cores consistentes com design system (sem artefatos ANSI)

Resultado esperado: sem travamentos, sem loop de navegação e sem códigos ANSI visíveis na UI."
