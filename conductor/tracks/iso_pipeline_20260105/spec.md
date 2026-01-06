# Especificação da Trilha: Pipeline de Build ISO

## Objetivo
Criar um ambiente de construção reproduzível e isolado utilizando Docker para gerar uma imagem ISO do Debian Live. Esta ISO deve incluir o suporte a ZFS (via módulos DKMS compilados ou pré-compilados) e integrar os binários do ZFSBootMenu (Release e Recovery) que são baixados pelo script existente.

## Contexto
O projeto já possui um script para baixar os binários do ZFSBootMenu (`scripts/download-zfsbootmenu.sh`). O próximo passo lógico é usar esses artefatos para construir a mídia de instalação final. O uso do Docker é mandatório para evitar poluir o sistema do host e garantir que o build funcione em qualquer máquina.

## Requisitos Técnicos
1.  **Container de Build:**
    *   Baseado em `debian:trixie-slim` (conforme Tech Stack).
    *   Deve conter `live-build` e dependências necessárias.
2.  **Script de Orquestração (`scripts/build-iso-in-docker.sh`):**
    *   Deve montar o diretório atual no container.
    *   Deve gerenciar permissões de arquivo (usuário host vs root container).
3.  **Configuração do Live-Build:**
    *   Distribuição: `trixie`.
    *   Arquitetura: `amd64`.
    *   Imagem: `iso-hybrid`.
    *   Pacotes: `zfs-dkms`, `zfsutils-linux`, `dosfstools`, `gdisk`, `debootstrap`.
4.  **Integração ZFSBootMenu:**
    *   Os binários em `./zbm-binaries` (ou diretório configurado) devem ser copiados para a ISO.
    *   Configuração do carregamento UEFI e BIOS.

## Critérios de Aceitação
*   Execução do script `build-iso-in-docker.sh` termina com sucesso.
*   Arquivo `.iso` gerado no diretório raiz ou de saída.
*   A ISO contém os módulos ZFS e os utilitários de espaço de usuário.
*   A ISO contém a estrutura de diretórios correta para o ZFSBootMenu (EFI/BOOT, etc, conforme necessário para instalação manual ou automatizada).
