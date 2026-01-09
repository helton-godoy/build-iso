# Diretrizes do Produto - Build-ISO

## Princípios de Design e Comunicação

- **Tom Educativo e Amigável:** A documentação e as mensagens do instalador devem explicar claramente o propósito de cada etapa. O objetivo é guiar o usuário com transparência, tornando a tecnologia ZFS acessível e compreensível.
- **Transparência Operacional:** Antes de qualquer ação destrutiva ou configuração crítica, o sistema deve informar o que será feito e por quê.

## Desenvolvimento e Qualidade de Código

- **Filosofia Fail Fast:** Operações críticas de particionamento e criação de sistemas de arquivos devem interromper a execução imediatamente em caso de falha. A segurança dos dados é a prioridade absoluta; estados inconsistentes não são permitidos.
- **Modularidade Funcional:** O código deve ser organizado em módulos independentes com responsabilidades claras (ex: `disk_part.sh`, `zfs_setup.sh`, `os_bootstrap.sh`). Um script orquestrador deve gerenciar o fluxo principal.
- **Portabilidade de Scripts:** Scripts devem ser escritos preferencialmente em Bash (com `set -euo pipefail`) visando compatibilidade com o ambiente Live do Debian.

## Gerenciamento de Dependências e Infraestrutura

- **Arquitetura Self-contained:** A imagem ISO gerada deve conter todos os binários, scripts e recursos necessários para a instalação completa (incluindo binários do ZFSBootMenu). Isso garante a integridade da instalação e permite operações em ambientes sem acesso à internet.
- **Build Reprodutível:** O pipeline de build da ISO deve ser containerizado (Docker/Podman) para garantir que o artefato final seja idêntico, independentemente do ambiente de quem executa o build.

## Experiência do Usuário (UX)

- **Instalação Assistida:** O instalador deve realizar a detecção automática de hardware e sugerir configurações seguras, mas sempre aguardar a confirmação do usuário para as etapas finais de aplicação.
