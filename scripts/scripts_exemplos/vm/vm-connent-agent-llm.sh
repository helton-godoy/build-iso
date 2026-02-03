#!/bin/bash
# Uso: ./vm-connent-agent-llm.sh "zpool status"
VM_NAME="aurora-nas-node"
COMMAND=$1

# 1. Espera o QEMU Guest Agent responder (Máquina Pronta)
until sudo virsh qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' >/dev/null 2>&1; do
    echo "Aguardando Aurora NAS iniciar..."
    sleep 2
done

# 2. Executa comando via QGA (como root)
# O QGA executa comandos e retorna JSON. Usamos jq para limpar.
sudo virsh qemu-agent-command "$VM_NAME" \
    "{\"execute\":\"guest-exec\", \"arguments\":{\"path\":\"/bin/bash\", \"arg\":[\"-c\", \"$COMMAND\"], \"capture-output\":true}}" \
    | jq -r '.return.out_data' | base64 -d

