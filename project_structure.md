# Estrutura de Diretórios do Projeto Build-ISO

Este documento descreve a estrutura de diretórios reorganizada do projeto Build-ISO, uma ferramenta para construção de imagens ISO do Debian com ZFS Boot Menu.

## 📁 Estrutura Geral

```
build-iso/
├── .agent/                          # Arquivos de arquitetura e agentes
│   └── ARCHITECTURE.md             # Documentação da arquitetura
├── .gitignore                      # Arquivos ignorados pelo Git
├── AGENTS.md                       # Documentação dos agentes
├── quick_start_guide.md            # Guia de início rápido
├── README.md                       # Documentação principal
├── symbol_analysis_report.md       # Relatório de análise de símbolos
├── cache/                          # Diretório de cache
│   ├── README.md                   # Documentação do cache
│   └── debs/                       # Pacotes Debian em cache
├── include/                        # Arquivos incluídos na ISO
│   └── usr/
│       ├── local/
│       │   └── bin/
│       │       ├── gum              # Ferramenta Gum
│       │       ├── install-system   # Script principal de instalação
│       │       └── installer/       # Sistema de instalação
│       │           ├── README.md    # Documentação do instalador
│       │           ├── components/  # Componentes do instalador
│       │           │   ├── 01-validate.sh          # Validação
│       │           │   ├── 02-partition.sh         # Particionamento
│       │           │   ├── 03-pool.sh             # Criação de pool ZFS
│       │           │   ├── 04-datasets.sh         # Datasets ZFS
│       │           │   ├── 05-extract.sh          # Extração
│       │           │   ├── 06-chroot-configure.sh # Configuração chroot
│       │           │   ├── 07-bootloader.sh       # Bootloader
│       │           │   ├── 08-cleanup.sh          # Limpeza
│       │           │   └── AGENTS.md              # Agentes do instalador
│       │           └── lib/          # Bibliotecas do instalador
│       │               ├── chroot.sh    # Funções chroot
│       │               ├── error.sh     # Tratamento de erros
│       │               ├── logging.sh   # Logging
│       │               ├── ui_gum.sh    # Interface com Gum
│       │               └── validation.sh # Validação
│       └── share/
│           └── zfsbootmenu/          # Arquivos ZFS Boot Menu
│               ├── initramfs-bootmenu-recovery.img
│               ├── initramfs-bootmenu.img
│               ├── VMLINUZ-BACKUP.EFI
│               ├── vmlinuz-bootmenu-recovery
│               ├── VMLINUZ-RECOVERY.EFI
│               └── VMLINUZ.EFI
├── plans/                          # Planos e documentação de planejamento
│   └── code_analysis.md            # Análise de código
├── scripts/                        # Scripts de automação
│   ├── build-debian-trixie-zbm.sh  # Script de construção da ISO
│   ├── clean-build-artifacts.sh    # Limpeza de artefatos
│   └── download-zfsbootmenu.sh     # Download do ZFS Boot Menu
└── tests/                          # Testes
    ├── test_installer.bats         # Testes do instalador (BATS)
    └── test-iso.sh                 # Testes da ISO
```

## 📋 Descrição dos Diretórios Principais

### Raiz do Projeto

- **.agent/**: Contém documentação de arquitetura e configurações de agentes
- **cache/**: Armazenamento temporário para downloads e artefatos de construção
- **include/**: Arquivos que serão incluídos na imagem ISO final
- **plans/**: Documentação de planejamento e análise
- **scripts/**: Scripts de automação para construção e manutenção
- **tests/**: Conjunto de testes para validar a funcionalidade

### Sistema de Instalação (`include/usr/local/bin/installer/`)

- **components/**: Scripts sequenciais que executam as etapas da instalação
- **lib/**: Bibliotecas compartilhadas utilizadas pelos componentes

### Arquivos ZFS Boot Menu (`include/usr/share/zfsbootmenu/`)

- Contém os arquivos necessários para o ZFS Boot Menu na imagem ISO

## 🔗 Referências Cruzadas

- [README.md](README.md) - Documentação principal do projeto
- [quick_start_guide.md](quick_start_guide.md) - Guia de início rápido
- [AGENTS.md](AGENTS.md) - Documentação dos agentes utilizados
- [.agent/ARCHITECTURE.md](.agent/ARCHITECTURE.md) - Arquitetura detalhada

## 📊 Estatísticas da Estrutura

- **Total de arquivos**: ~40 arquivos
- **Profundidade máxima**: 6 níveis
- **Principais categorias**:
  - Scripts de instalação: 8 componentes + 5 bibliotecas
  - Scripts de automação: 3 scripts principais
  - Documentação: 6 arquivos Markdown
  - Testes: 2 arquivos de teste
  - Cache/ZFS: 7 arquivos

Esta estrutura foi reorganizada para melhorar a clareza, separação de responsabilidades e facilidade de manutenção do projeto Build-ISO.
