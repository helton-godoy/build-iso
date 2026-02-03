#!/usr/bin/env bash
set -euo pipefail

# Conecta via comando virsh no console serial da VM em execução
VM_NAME=${1:-nas-test-uefi}
# Verifica se a VM está rodando
if ! virsh list --name | grep -q "^$VM_NAME$"; then
    echo "❌ VM '$VM_NAME' não encontrada ou desligada."
    exit 1
fi

echo "🤖 Agente conectando ao console de $VM_NAME..."
# O comando abaixo permite que o agente envie comandos e receba logs do boot
virsh console "$VM_NAME"
