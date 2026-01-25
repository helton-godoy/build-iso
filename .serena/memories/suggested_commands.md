# Comandos Sugeridos - Build-ISO

## Build da ISO

```bash
# Build padrão (completo)
./debian_trixie_builder-v2.sh

# Build explícito
./debian_trixie_builder-v2.sh build

# Rebuild completo (limpa e reconstrói)
./debian_trixie_builder-v2.sh rebuild

# Limpeza de arquivos temporários
./debian_trixie_builder-v2.sh clean

# Ajuda
./debian_trixie_builder-v2.sh help
```

## Docker

```bash
# Verificar imagem Docker
docker images | grep debian-trixie-zbm-builder

# Rebuild da imagem Docker
docker build -t debian-trixie-zbm-builder:latest .

# Inspecionar container em execução
docker ps
docker logs <container_id>
```

## Teste da ISO

```bash
# Testar com QEMU (modo rápido)
qemu-system-x86_64 -cdrom output/debian-*.iso -m 2048 -boot d

# Testar com KVM (se disponível)
qemu-system-x86_64 -enable-kvm -cdrom output/debian-*.iso -m 2048 -boot d
```

## Verificação

```bash
# Verificar integridade da ISO
sha256sum -c output/*.sha256

# Verificar estrutura do live-build
ls -la live-build-config/config/
```

## Git

```bash
# Status atual
git status

# Histórico recente
git log --oneline -10

# Diferenças
git diff
```

## Limpeza

```bash
# Limpar artefatos de build
./clean-build-artifacts.sh

# Limpar container e imagem Docker
docker system prune
```
