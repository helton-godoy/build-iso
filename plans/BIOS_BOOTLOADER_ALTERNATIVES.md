# Alternativas ao GRUB para Boot BIOS (Legacy)

Para evitar a complexidade do GRUB e o risco de sobrescrita de configurações por automações do Debian, analisamos duas alternativas robustas para servir de "ponte" para o ZFSBootMenu em sistemas BIOS (Legacy). Na arquitetura UEFI, o ZFSBootMenu será carregado diretamente (`efibootmgr`), dispensando qualquer bootloader intermediário.

## Opção 1: Syslinux (Recomendada pela Disponibilidade)

O **Syslinux** é um bootloader leve, estável e disponível nos repositórios oficiais do Debian. Ele é excelente para lidar com partições FAT32 (nossa ESP) e não possui scripts de automação agressivos ("hooks") que reescrevem sua configuração sem permissão.

### Vantagens
- **Nativo Debian:** Pacotes `syslinux` e `syslinux-common` estão nos repositórios.
- **Configuração Estática:** O arquivo `syslinux.cfg` não é tocado por atualizações de kernel (diferente do `update-grub`).
- **Simplicidade:** Módulos simples para carregar kernel/initramfs.
- **Boot GPT:** Suporta GPT através do `gptmbr.bin`.

### Mudanças Necessárias no Instalador
1.  **Particionamento:**
    - Remover partição BIOS Boot (`EF02`) - não é usada pelo Syslinux.
    - Marcar a partição ESP (`EF00`) com o atributo "Legacy BIOS Bootable" (`sgdisk -A 2:set:2`).
2.  **Instalação MBR:**
    - Gravar MBR compatível com GPT: `dd if=/usr/lib/syslinux/mbr/gptmbr.bin of=/dev/sdX`.
3.  **Instalação Bootloader:**
    - Executar `syslinux --install /dev/sdX2` (instala na ESP).
4.  **Configuração:**
    - Criar `/boot/efi/syslinux.cfg` manual.

## Opção 2: Limine (Recomendada pela Modernidade)

O **Limine** é um bootloader moderno, extremamente leve e com sintaxe de configuração muito simples. É agnóstico de sistema operacional.

### Vantagens
- **Extremamente Leve:** Binário minúsculo.
- **Configuração Humana:** `limine.cfg` é muito legível.
- **Zero Dependência:** Não precisa de pacotes apt (baixamos o binário junto com o ZBM).

### Desvantagens
- **Não Oficial Debian:** Não está nos repositórios (requer download manual via `curl` ou inclusão no repo do projeto).

## Comparativo Final

| Característica | GRUB (Otimizado) | Syslinux | Limine |
| :--- | :--- | :--- | :--- |
| **Complexidade** | Alta | Baixa | Mínima |
| **Risco de Sobrescrita** | Médio (Requer purge) | **Nulo** (Sem hooks) | **Nulo** (Manual) |
| **Instalação** | Padrão Debian | Pacote Debian | Binário Externo |
| **Partição BIOS** | Requer `EF02` | Usa ESP (Legacy Attr) | Incorporado/ESP |
| **Segurança** | Robusto | Simples/Seguro | Moderno |

## Recomendação

Sugerimos adotar o **Syslinux** para BIOS. Ele resolve o problema do usuário ("instalação mais segura sem automação que sobrescreve") usando ferramentas padrão do Debian, mantendo a arquitetura limpa.

- **UEFI:** ZFSBootMenu direto (sem bootloader intermediário).
- **BIOS:** Syslinux (carrega ZFSBootMenu da ESP).

Dessa forma, o Debian instalado pode atualizar kernels e pacotes à vontade; ele nunca tocará no `syslinux.cfg` na ESP, garantindo a imunidade da nossa configuração.
