#!/bin/bash
# Configurações
VM_NAME="aurora-nas-node"
DISK_PATH="./vm/disks/aurora-disk.qcow2"

echo "### Iniciando Aurora NAS via Disco Persistente ###"

# 1. Verifica se a VM já existe no Libvirt
if ! sudo virsh list --all | grep -q "$VM_NAME"; then
    echo "Erro: VM $VM_NAME não encontrada. Execute o script de instalação primeiro."
    exit 1
fi

# 2. Garante que a ordem de boot priorize o disco rígido (hd)
# Alteramos a configuração XML da VM dinamicamente para garantir o boot pelo disco
sudo virsh set-lifecycle-action destroy destroy --config
sudo virsh set-lifecycle-action restart restart --config

# 3. Inicia a VM
sudo virsh start "$VM_NAME" 2>/dev/null || echo "VM já está em execução."

# 4. Aguarda o QEMU Guest Agent sinalizar que o sistema operacional carregou
echo "Aguardando sistema operacional e QEMU Guest Agent..."
MAX_RETRIES=30
COUNT=0
while ! sudo virsh qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' >/dev/null 2>&1; do
    sleep 2
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "Timeout: O sistema no disco não respondeu ao agente."
        exit 1
    fi
done

echo "### Aurora NAS (Disk Boot) está ONLINE e pronto para o Agente LLM ###"

# 5. Exibe informações de rede para a LLM
echo "IPs Detectados:"
sudo virsh domifaddr "$VM_NAME"
