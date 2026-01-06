# Stack Tecnológico - Build-ISO

## Núcleo do Sistema e Scripts
- **Bash (Shell Scripting):** Linguagem principal para automação do instalador e scripts auxiliares. Utiliza padrões de segurança (`set -euo pipefail`) e modularidade.
- **Debian (Trixie/Sid):** Base do sistema operacional para a imagem Live e ambiente de build.

## Armazenamento e Boot
- **OpenZFS:** Fornece as capacidades de Root-on-ZFS, snapshots e criptografia nativa.
- **ZFSBootMenu (ZBM):** Gerenciador de boot via Kexec que permite a gestão nativa de datasets ZFS e recuperação do sistema.

## Infraestrutura de Build e Empacotamento
- **Docker/Podman:** Utilizado para isolar o ambiente de construção da ISO (`live-build`), garantindo que todas as dependências estejam presentes e as versões sejam consistentes.
- **Live-Build (Debian):** Ferramenta oficial para a criação de sistemas Debian Live customizados.

## Validação e Virtualização
- **QEMU/KVM:** Hipervisor utilizado para os ciclos de teste automatizados e manuais da ISO gerada.
- **OVMF (Open Virtual Machine Firmware):** Necessário para emular ambientes UEFI durante os testes.

## Convenções Técnicas
- **Particionamento GPT Híbrido:** Uso de partições `EF02` (BIOS Boot) e `EF00` (ESP) para suporte universal.
- **Criptografia Nativa ZFS:** Suporte a `encryption=on`, `keyformat=passphrase` e `keylocation=prompt`.
