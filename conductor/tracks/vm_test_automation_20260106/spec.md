# Especificação da Trilha: Automação de Testes em VM (QEMU/KVM)

## Objetivo

Desenvolver um script robusto para validar a ISO gerada em um ambiente virtualizado, permitindo testar não apenas o boot (BIOS/UEFI), mas também o processo completo de instalação em um disco virtual.

## Contexto

Atualmente, o `scripts/test-iso.sh` apenas inicia a ISO sem um disco rígido virtual e com configurações básicas. Para garantir que o sistema de instalação (ZFS-on-root) funcione, precisamos de um ambiente que simule um hardware real com capacidade de escrita em disco.

## Requisitos Técnicos

1.  **Gerenciamento de Disco Virtual:**
    - Criação dinâmica de um disco `qcow2` (mínimo 20GB).
    - Opção para persistir ou descartar o disco após o teste.
2.  **Performance:**
    - Habilitar aceleração KVM (`-enable-kvm`) se disponível no host.
    - Configuração de memória (2GB+) e CPU (2+ cores).
3.  **Compatibilidade de Firmware:**
    - Suporte robusto a UEFI via OVMF.
    - Suporte a Legacy BIOS.
4.  **Integração com o Pipeline:**
    - Localização automática da ISO em `docker/artifacts/dist/`.
    - Logs de execução do QEMU.

## Critérios de Aceitação

- O script `scripts/test-iso.sh` inicia a VM com a ISO e o disco virtual acoplado.
- É possível realizar o particionamento e instalação do ZFS no disco virtual dentro da VM.
- O script detecta corretamente o caminho do OVMF no Debian/Ubuntu.
- A VM possui acesso à rede (User Mode Networking).
