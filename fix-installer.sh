#!/bin/bash
# Fix para o problema do subshell no instalador

INSTALADOR="/usr/local/bin/install-zfs-debian"

# Backup
cp "$INSTALADOR" "$INSTALADOR.bak.$(date +%s)"

echo "Aplicando correções..."

# Remover ds_spinner dos comandos críticos que definem variáveis
sed -i 's|ds_spinner "Limpando disco..." bash -c "partition_wipe_disk \$SELECTED_DISK"|partition_wipe_disk "\$SELECTED_DISK"|g' "$INSTALADOR"
sed -i 's|ds_spinner "Criando partições GPT..." bash -c "partition_create_gpt \$SELECTED_DISK"|partition_create_gpt "\$SELECTED_DISK"|g' "$INSTALADOR"
sed -i 's|ds_spinner "Formatando ESP..." partition_format_esp "\$part_esp"|partition_format_esp "\$part_esp"|g' "$INSTALADOR"

echo "Correção aplicada com sucesso!"
echo ""
echo "Verificando alterações:"
grep -n "partition_wipe_disk\|partition_create_gpt\|partition_format_esp" "$INSTALADOR" | grep -v "^.*#" | head -5
