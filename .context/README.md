# Sistema de Contexto do Build-ISO

Este diretório contém a configuração e estado do sistema de contexto para o projeto build-iso.

## Estrutura

```
.context/
├── config.json          # Configuração principal do sistema
├── README.md            # Este arquivo
└── workflow/            # (Opcional) Diretório de workflow PREVC
```

## Configuração Atual

- **Versão**: 1.0.0
- **Repositório**: build-iso
- **Descrição**: Debian Trixie ZBM ISO Builder
- **Data de Inicialização**: 25/01/2026

## Componentes Principais

### Core
- Scripts de build: `build-debian-trixie-zbm.sh`, `clean-build-artifacts.sh`
- Documentação: `debian_readme.md`, `quick_start_guide.md`
- Testes: `tests/test_installer.bats`

### Installer
- Localização: `include/usr/local/bin/installer/`
- Componentes: 8 scripts de instalação (validação, particionamento, pools, datasets, etc.)

### Cache
- Localização: `cache/`
- Artefatos preservados: Pacotes .deb compilados

## Workflow

O sistema segue um workflow de 5 fases:
1. **Prepare**: Preparação do ambiente
2. **Build**: Construção da ISO
3. **Test**: Testes de validação
4. **Package**: Empacotamento final
5. **Cleanup**: Limpeza de artefatos

## Manutenção

### Atualização de Configuração

Para atualizar as configurações, edite o arquivo `config.json` e ajuste os parâmetros necessários.

### Verificação de Integridade

```bash
# Verificar checksums dos arquivos críticos
sha256sum build-debian-trixie-zbm.sh clean-build-artifacts.sh > critical_checksums.txt

# Verificar estrutura do contexto
ls -la .context/
```

### Backup

```bash
# Criar backup do contexto
tar czvf context_backup_$(date +%Y%m%d).tar.gz .context/
```

## Limpeza

O sistema foi inicializado após uma limpeza completa de artefatos obsoletos em 25/01/2026.