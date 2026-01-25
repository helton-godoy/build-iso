# Cache de Artefatos de Build

Este diretório contém artefatos compilados que podem ser reutilizados entre builds,
economizando tempo significativo de recompilação.

## Estrutura

```
cache/
├── debs/                    # Pacotes .deb customizados
│   └── kmscon-custom_*.deb  # kmscon compilado do source
├── packages.bootstrap/      # Cache APT do live-build (opcional)
└── README.md
```

## Artefatos Cacheados

### kmscon-custom_9.3.0_amd64.deb (~660KB)

- **Tempo de compilação economizado**: ~5-10 minutos
- **Volatilidade**: Baixa (atualizar apenas quando mudar versão upstream)
- **Origem**: Compilado do <https://github.com/Aetf/kmscon.git> (branch master)

## Uso

O script `build-debian-trixie-zbm.sh` automaticamente:

1. Verifica se existe cache em `cache/debs/`
2. Se existir, copia para o build sem recompilar
3. Se não existir, compila e salva no cache

## Limpeza

```bash
# Limpar build, preservando cache (padrão)
./clean-build-artifacts.sh

# Limpar TUDO, incluindo cache
./clean-build-artifacts.sh --full
```

## Manutenção

Para forçar recompilação de um artefato:

```bash
rm cache/debs/kmscon-custom_*.deb
./build-debian-trixie-zbm.sh build
```
