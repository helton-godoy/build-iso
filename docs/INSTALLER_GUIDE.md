# Guia de Uso do Instalador ZFS Debian

## Visão Geral

O instalador **Fileserver Installer** é uma ferramenta interativa TTY para instalação automatizada de Debian com ZFS-on-Root e ZFSBootMenu.

## Iniciando o Instalador

1. Boot a ISO live do Fileserver
2. Faça login (usuário: `user`, senha: `live`)
3. Execute o instalador:
   ```bash
   sudo install-zfs-debian
   ```

## Fluxo de Instalação

O instalador segue um wizard de 6 etapas:

### 1. Boas-vindas
- Exibe informações sobre o instalador
- Mostra o modo de boot detectado (UEFI/BIOS)
- Solicita confirmação para iniciar

### 2. Seleção de Disco
- Lista todos os discos disponíveis (>20GB)
- Exibe modelo, tamanho e tipo (HDD/SSD)
- Permite selecionar um único disco de destino

**⚠️ Atenção**: Todos os dados no disco selecionado serão apagados.

### 3. Configuração do Sistema
- **Hostname**: Nome da máquina (ex: `fileserver`)
- **Usuário**: Nome do usuário administrativo
- **Senhas**: Senhas para o usuário e root

### 4. Confirmação
- Exibe resumo de todas as configurações
- Requer confirmação explícita antes de prosseguir
- **⚠️ Última chance de cancelar sem perda de dados**

### 5. Instalação
O instalador executa automaticamente:
1. **Particionamento**: Cria GPT híbrido (BIOS Boot + ESP + ZFS)
2. **ZFS**: Cria pool `zroot` com datasets otimizados
3. **Cópia**: Copia o sistema live para o disco
4. **Configuração**: Ajusta hostname, usuário, rede
5. **Bootloader**: Instala e configura ZFSBootMenu
6. **Finalização**: Atualiza initramfs e exporta pool

### 6. Conclusão
- Exibe mensagem de sucesso
- Oferece opção de reiniciar imediatamente

## Layout de Disco

O instalador cria o seguinte layout:

| Partição | Tamanho | Tipo | Propósito |
|----------|---------|------|-----------|
| 1 | 1 MB | BIOS Boot | Boot Legacy BIOS |
| 2 | 512 MB | ESP | Boot UEFI + ZBM |
| 3 | Restante | ZFS | Pool `zroot` |

## Estrutura ZFS

```
zroot
├── ROOT (canmount=off)
│   └── debian (mountpoint=/, canmount=noauto)
├── home (mountpoint=/home)
└── var (canmount=off, mountpoint=/var)
    ├── log
    └── tmp
```

## Requisitos

### Mínimos
- 20GB de espaço em disco
- 1GB de RAM
- Arquitetura x86_64

### Recomendados
- 50GB+ de espaço em disco
- 2GB+ de RAM
- SSD para melhor performance

## Suporte

### Firmware
- ✅ UEFI (recomendado)
- ✅ Legacy BIOS

### Armazenamento
- ✅ SATA/SSD/HDD
- ✅ NVMe
- ❌ RAID hardware (não suportado nesta versão)

## Troubleshooting

### O instalador não inicia
Verifique se está executando como root:
```bash
sudo install-zfs-debian
```

### Disco não aparece na lista
- Verifique se o disco tem pelo menos 20GB
- Discos menores são filtrados automaticamente
- Use `lsblk` para verificar discos disponíveis

### Falha na criação do pool ZFS
- Verifique se o disco não está em uso
- Certifique-se de que os módulos ZFS estão carregados: `modprobe zfs`

### Boot não funciona após instalação
- Verifique se o modo de boot (UEFI/BIOS) está correto
- No setup da BIOS/UEFI, selecione ZFSBootMenu como bootloader
- Verifique se a partição ESP está formatada corretamente

## Arquitetura do Instalador

O instalador é composto por módulos especializados:

```
scripts/
├── install-zfs-debian          # Entry point principal
└── lib/
    ├── fileserver-ds.sh        # Design System v2.0
    └── installer/
        ├── firmware-detection.sh
        ├── disk-detection.sh
        ├── partitioning.sh
        ├── zfs-setup.sh
        ├── system-config.sh
        └── zbm-install.sh
```

## Testes

Scripts de teste disponíveis:

```bash
# Testar UI
./tests/manual/validate_ui.sh

# Testar particionamento (requer disco de teste)
TEST_DISK=/dev/vda ./tests/test_installer_partitioning.sh

# Testar ZFS (requer partição de teste)
TEST_DEVICE=/dev/vda3 ./tests/test_installer_zfs.sh
```

## Limitações Conhecidas

- Apenas um disco suportado (sem mirror/raidz)
- Sem criptografia nativa ZFS (planejado para v2)
- Sem dual-boot com outros SOs
- Interface apenas TTY (sem GUI)

## Ver Também

- [Documentação do Projeto](PROJECT_STRUCTURE.md)
- [Blueprint Arquitetural](Architectural%20Blueprint%20-%20Debian%20ZFS%20on%20Root%20Installer.md)
- [ZFSBootMenu Docs](https://docs.zfsbootmenu.org/)
