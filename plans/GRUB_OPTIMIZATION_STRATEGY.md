# Estratégia de Otimização do GRUB para ZFSBootMenu

Esta estratégia detalha a abordagem para tornar o GRUB um carregador "invisível" e rápido, servindo apenas como ponte para o ZFSBootMenu em sistemas BIOS (Legacy) e UEFI (caso necessário como fallback).

## 1. Diagnóstico do Estado Atual

Atualmente, o script `install-DEBIAN_ZFS.sh` instala o GRUB e gera manualmente um arquivo `grub.cfg`.
- **Pontos Positivos:** Já evita o uso do `update-grub` e scripts complexos de `/etc/grub.d/`, o que nos dá controle total sobre o conteúdo.
- **Pontos de Melhoria:**
    - `timeout=5`: Adiciona uma espera desnecessária de 5 segundos.
    - Otimizações de terminal não estão explícitas.
    - Falta de configurações para ocultar o menu (`timeout_style`).

## 2. Princípios da Otimização

Como o **ZFSBootMenu** é o verdadeiro gerenciador de boot (capaz de gerenciar snapshots, clones, criptografia e kernels), o GRUB deve obedecer ao princípio de "Passagem Expressa":
1.  **Não deve perguntar nada ao usuário.**
2.  **Não deve mostrar nada na tela** (exceto erros críticos).
3.  **Deve carregar o Kernel do ZBM o mais rápido possível.**

## 3. Configurações Propostas (`grub.cfg`)

Substituiremos a geração atual do `grub.cfg` no script de instalação pela seguinte estrutura otimizada:

```grub
# Otimização: Timeout zero ou próximo de zero
set timeout=0
set timeout_style=hidden

# Otimização: Forçar modo texto (mais rápido que modos gráficos)
# Isso evita o carregamento de drivers de vídeo pesados no estágio do GRUB.
set terminal_input console
set terminal_output console

# Configuração Padrão
set default=0

# Módulos Essenciais (part_gpt e fat já são carregados, mas garantimos explicitamente)
insmod part_gpt
insmod fat

# Entrada Principal - ZFSBootMenu
menuentry "ZFSBootMenu" {
    # zbm.prefer_policy=hostid: Garante que o pool correto seja buscado
    # loglevel=0 systemd.show_status=false: Reduz overhead de log
    linux /zbm/vmlinuz zbm.prefer_policy=hostid quiet loglevel=0 systemd.show_status=false
    initrd /zbm/initramfs.img
}

# Entrada de Recuperação (acessível se segurar Shift/Esc durante o boot)
menuentry "ZFSBootMenu (Recovery)" {
    linux /zbm/vmlinuz zbm.prefer_policy=hostid zbm.show
    initrd /zbm/initramfs.img
}
```

## 4. Otimização de Instalação (`grub-install`)

Manteremos o comando `grub-install` executado pelo instalador (host), apontando para o diretório de boot correto. Isso grava o bootloader na MBR/ESP.

## 5. Eliminação de Interferências (Proteção contra Sobrescrita)

Para garantir que uma atualização futura do sistema (`apt upgrade`) não reconfigure o GRUB e sobrescreva nossas otimizações:

1.  **Remoção do GRUB do Alvo:** O sistema operacional instalado (Debian) **não precisa** ter os pacotes `grub-pc`, `grub-efi`, ou `os-prober` instalados. O bootloader já foi gravado pelo instalador.
2.  **Ação no Instalador:** Adicionaremos uma etapa no `install-DEBIAN_ZFS.sh` para remover esses pacotes de dentro do ambiente `chroot` antes de finalizar a instalação.
3.  **Resultado:** O sistema instalado gerenciará apenas seus kernels/initramfs (para o ZBM encontrar), sem tentar gerenciar o bootloader da BIOS/ESP.

## 6. Plano de Ação

1.  Modificar `install-DEBIAN_ZFS.sh` para injetar o novo `grub.cfg`.
2.  Adicionar parâmetros de terminal console, timeout 0 e style hidden.
3.  Implementar função para purgar pacotes GRUB (`apt-get purge -y grub* os-prober`) dentro do chroot.
4.  Validar parâmetros de kernel do ZBM.

Esta estratégia blinda o bootloader contra alterações acidentais do sistema operacional.
