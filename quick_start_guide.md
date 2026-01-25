# ⚡ Guia de Início Rápido - Debian Trixie ISO Builder

## 🎯 TL;DR - 5 Passos para Sua ISO

```bash
# 1. Instalar Docker (se necessário)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 2. Criar diretório e baixar script
mkdir debian-iso-builder && cd debian-iso-builder
# Cole o script build-debian-trixie-zbm.sh aqui

# 3. Tornar executável
chmod +x build-debian-trixie-zbm.sh

# 4. Executar build (40-60 min)
./build-debian-trixie-zbm.sh

# 5. Sua ISO estará em output/
ls -lh output/
```

## 🚀 Uso Básico

### Primeira Execução

```bash
./build-debian-trixie.sh
```

### Verificar Integridade da ISO

```bash
cd output/
sha256sum -c *.sha256
```

### Gravar em USB (Linux)

```bash
# ATENÇÃO: Substitua sdX pelo seu dispositivo USB
# Isso APAGARÁ todos os dados do USB!

# Identificar dispositivo
lsblk

# Gravar ISO
sudo dd if=output/debian-trixie-custom-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## 🔥 Comandos Mais Usados

### Rebuild Completo

```bash
./build-debian-trixie.sh rebuild
```

### Apenas Limpar

```bash
./build-debian-trixie.sh clean
```

### Testar em VM (QEMU)

```bash
qemu-system-x86_64 \
    -cdrom output/debian-*.iso \
    -m 2048 \
    -enable-kvm \
    -boot d
```

## 🎨 Personalizações Rápidas

### Adicionar Pacote Rapidamente

Antes de executar o build, edite o script:

```bash
nano build-debian-trixie.sh
```

Procure por `cat > config/package-lists/custom.list.chroot` e adicione seus pacotes.

### Mudar Senha do Usuário Padrão

Após a ISO ser gerada, ou edite o hook `0030-configure-system.hook.chroot` antes do build:

```bash
# Procure por esta linha e altere:
echo "debian:live" | chpasswd
# Para:
echo "debian:suasenha" | chpasswd
```

### Alterar Hostname

No mesmo hook, procure por:

```bash
echo "debian-trixie-live" > /etc/hostname
# Altere para seu hostname
```

## 🐛 Troubleshooting Express

| Problema            | Solução Rápida                                   |
| ------------------- | ------------------------------------------------ |
| Docker não roda     | `sudo systemctl start docker`                    |
| Permission denied   | `sudo usermod -aG docker $USER && newgrp docker` |
| Build falha no meio | Verifique conexão internet e espaço em disco     |
| ISO não boota       | Grave com `dd`, não com Rufus/Etcher em modo ISO |
| Muito lento         | Normal! Primeira vez demora mais (cache vazio)   |

## 📊 Tempo Estimado

| Etapa                      | Tempo                 |
| -------------------------- | --------------------- |
| Primeira execução completa | 40-70 min             |
| Rebuilds subsequentes      | 20-30 min (com cache) |
| Apenas modificar hooks     | 15-20 min             |

## 💡 Dicas Pro

### 1. Cache de Pacotes

O Docker manterá cache de pacotes. Não delete a imagem Docker entre builds:

```bash
# Ver imagens
docker images | grep debian-trixie-builder

# NÃO delete entre builds para velocidade
```

### 2. Build Paralelo

Modifique o número de jobs no script (avançado):

```bash
# No configure-live-build.sh, adicione ao lb build:
lb build -- -j$(nproc)
```

### 3. Mirror Local

Para builds frequentes, use um mirror local:

```bash
# Instale apt-cacher-ng
sudo apt install apt-cacher-ng

# No lb config, adicione:
--apt-http-proxy "http://localhost:3142"
```

## 🎓 Próximos Passos

Depois da primeira ISO:

1. **Teste**: Boot em VM ou hardware real
2. **Personalize**: Adicione seus pacotes favoritos
3. **Automatize**: Configure CI/CD para builds automáticos
4. **Documente**: Mantenha registro de suas personalizações

## 📱 Checklist de Validação

Após criar a ISO, teste:

- [ ] Boota em BIOS
- [ ] Boota em UEFI
- [ ] Teclado ABNT2 funciona
- [ ] Locale PT-BR correto
- [ ] Timezone correto
- [ ] kmscon carrega
- [ ] Emojis renderizam (teste: `echo "🚀 ✅ 🔥"`)
- [ ] ZFS carrega (`sudo modprobe zfs && lsmod | grep zfs`)
- [ ] Rede funciona
- [ ] SSH habilitado
- [ ] Sudo sem senha funciona

## 🆘 Ajuda Rápida

```bash
# Ver logs de build
tail -f build/live-build-config/build.log

# Entrar no container para debug
docker run -it --rm debian-trixie-builder:latest bash

# Limpar tudo (incluindo Docker cache)
./build-debian-trixie.sh clean
docker system prune -a

# Ver espaço usado
du -sh build/ output/
docker system df
```

## 🔗 Links Úteis

- [README Completo](./README.md) - Documentação detalhada
- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/)
- [Docker Docs](https://docs.docker.com/)

---

**Criado algo legal? Compartilhe! 🚀**

_Para dúvidas, consulte o README.md completo_
