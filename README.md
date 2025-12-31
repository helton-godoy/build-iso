# Debian-ZFS-ISO Builder

Sistema de automação para geração de ISOs Debian 13 (Trixie) com suporte a ZFS.

## Requisitos do Host

- Deepin 25 / Debian 12+ / Ubuntu 22.04+
- CPU com suporte a virtualização (VT-x/AMD-V)
- Mínimo 8GB RAM
- 50GB de espaço livre

## Uso Rápido

```bash
# Executar build completo
sudo ./scripts/host/build_master.sh
```

O script irá automaticamente:

1. Instalar KVM/libvirt (se necessário)
2. Criar VM Debian 13 headless
3. Executar build da ISO
4. Copiar resultado para `output/`

## Comandos

| Comando     | Descrição               |
| ----------- | ----------------------- |
| `build`     | Build completo (padrão) |
| `setup`     | Apenas configurar host  |
| `create-vm` | Apenas criar VM         |
| `status`    | Mostrar status da VM    |
| `ssh`       | Conectar na VM          |
| `stop`      | Parar VM                |
| `destroy`   | Remover VM              |

## Perfis de Instalação

A ISO gerada oferece dois perfis via Calamares:

| Perfil          | Descrição                 |
| --------------- | ------------------------- |
| **Server**      | Modo texto, headless, SSH |
| **Workstation** | KDE Plasma minimalista    |

Ambos com suporte a ZFS como sistema de arquivos.

## Estrutura

```
build-iso/
├── scripts/
│   ├── host/           # Scripts para o host
│   │   ├── build_master.sh
│   │   ├── setup_host.sh
│   │   └── create_vm.sh
│   └── vm/             # Scripts para a VM
│       └── build_iso.sh
├── config/
│   └── calamares/      # Configuração do instalador
├── output/             # ISOs geradas
└── logs/               # Logs de build
```
