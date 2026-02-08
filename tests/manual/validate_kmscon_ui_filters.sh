#!/usr/bin/env bash
set -euo pipefail

echo "Validação manual KMSCON/TTY - filtros e listas extensas"
echo ""
echo "Pré-requisitos:"
echo "1) Executar em TTY/KMSCON (não em terminal gráfico)"
echo "2) Garantir resolução mínima 80x24"
echo ""
echo "Checklist:"
echo "[ ] Locale: digitar 'pt_BR' e confirmar redução de lista"
echo "[ ] Teclado: digitar 'br' e confirmar seleção correta"
echo "[ ] Timezone: digitar 'Sao_Paulo' e confirmar filtro"
echo "[ ] Discos: usar filtro + marcação múltipla (Espaço/Enter)"
echo "[ ] Ajuda de teclado visível nos componentes de seleção"
echo "[ ] Cores consistentes com design system (sem artefatos ANSI)"
echo ""
echo "Resultado esperado: sem travamentos, sem loop de navegação e sem códigos ANSI visíveis na UI."
