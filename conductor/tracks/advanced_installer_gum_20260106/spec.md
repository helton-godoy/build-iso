# Spec: Instalador Avançado com Gum

## Objetivo
Transformar o script de instalação CLI básico em uma ferramenta profissional, visualmente moderna e tecnicamente robusta, utilizando `gum` para a interface e implementando uma fase de configuração em `chroot`.

## Requisitos de Interface (UX)
- **Visual:** Uso de `gum` para menus, inputs, spinners e formatação Markdown.
- **Interatividade:** Seleção de disco filtrável, progresso visual das tarefas.
- **Segurança:** Confirmação explícita antes de operações destrutivas.

## Requisitos Técnicos
- **Ambiente:** O binário `gum` deve estar presente no ambiente Live da ISO.
- **Configuração:**
  - Hostname, Usuário (Sudoer) e Senhas.
  - Sincronização de `hostid` e `zpool.cache`.
  - Regeneração do `initramfs` dentro do sistema alvo.
- **Resiliência:** Tratamento de erros e limpeza (cleanup) de montagens/pools em caso de falha.

## Componentes Chave
- `config/includes.chroot/usr/local/bin/install-zfs-debian`: O script principal a ser refatorado.
- `scripts/download-zfsbootmenu.sh`: (Ou similar) para obter o binário do `gum`.
