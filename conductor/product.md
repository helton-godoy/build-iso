# Initial Concept

Automatização de implantação Debian com ZFS-on-root e ZFSBootMenu, suportando UEFI e BIOS legado através de uma ISO customizada e scripts de instalação.

# Visão Geral do Produto - Build-ISO (Debian ZFS-on-Root)

## Propósito
Este projeto fornece uma solução de automação para criar imagens ISO customizadas do Debian, projetadas especificamente para realizar instalações de sistemas com ZFS como sistema de arquivos raiz (Root-on-ZFS) e utilizando o ZFSBootMenu como gerenciador de boot. O diferencial central é a capacidade de gerar uma instalação universal que suporta boot tanto em firmwares UEFI quanto Legacy BIOS (Hybrid Boot).

## Público-Alvo
- **Administradores de Sistemas:** Que necessitam de uma ferramenta confiável para implantar frotas de servidores ou workstations com a robustez do ZFS.
- **Usuários Avançados de Linux:** Que desejam os benefícios do ZFSBootMenu (snapshots, clones, rollbacks nativos) sem a complexidade da configuração manual.
- **Desenvolvedores de Infraestrutura:** Que buscam uma base sólida e modular para construir suas próprias distribuições live ou instaladores personalizados.

## Objetivos Estratégicos
- **Automação e Confiabilidade:** Eliminar o erro humano em processos complexos de particionamento e configuração do ZFS.
- **Compatibilidade Universal:** Uma única imagem e uma única lógica de instalação que funciona em hardware antigo (BIOS) e moderno (UEFI).
- **Gestão Nativa de Boot:** Aproveitar ao máximo as propriedades do ZFS para gerenciar ambientes de boot de forma atômica.

## Funcionalidades Principais (MVP)
- **Pipeline de Build Isolado:** Geração da ISO via `live-build` dentro de containers Docker, garantindo repetibilidade.
- **Instalador Híbrido:** Script de instalação inteligente capaz de provisionar discos com esquema GPT contendo as partições necessárias para BIOS Boot e ESP.
- **Experiência de Usuário Equilibrada:** Detecção automática de hardware e discos, mantendo confirmações explícitas antes de operações destrutivas.
- **Criptografia Flexível:** Suporte opcional à criptografia nativa do ZFS durante o processo de instalação.