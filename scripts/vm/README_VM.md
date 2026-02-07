# 🛠️ VM Test Framework: NAS Simulation

Automação para provisionamento e análise de VMs QEMU/KVM destinadas a testes de infraestrutura NAS. Suporta **BIOS** e **UEFI** simultaneamente.

---

## 📋 Interfaces Disponíveis

O projeto oferece duas formas de interagir com as VMs:

### 1. Via Makefile (Recomendado)

Todos os comandos centralizados no [`Makefile`](../Makefile):

```bash
# Setup inicial
make setup-vm              # Instala dependências de virtualização
make vm-create-disks       # Cria 4 discos virtuais para testes

# Testes
make test-vm-uefi           # Inicia VM em modo UEFI
make test-vm-bios           # Inicia VM em modo BIOS
make test-vm-all            # Inicia ambas as VMs simultaneamente

# Conexão
make vm-connect-uefi        # Conecta ao console serial UEFI
make vm-connect-bios        # Conecta ao console serial BIOS

# Gerenciamento
make vm-list                # Lista VMs em execução
make vm-destroy             # Destrói VMs ativas

# Limpeza
make clean                  # Remove artefatos e VMs
```

Execute `make help` para ver todos os comandos disponíveis.

### 2. Via Scripts Diretos

Para uso direto ou automação customizada:

| Script                                                                            | Propósito                                  |
| --------------------------------------------------------------------------------- | ------------------------------------------ |
| [`scripts/vm/vm-start-test-boot-iso.sh`](../scripts/vm/vm-start-test-boot-iso.sh) | Inicia VM de teste com ISO + 4 discos      |
| [`scripts/vm/vm-start-test-boot-disk.sh`](../scripts/vm/vm-start-test-boot-disk.sh) | Inicia VM a partir de disco instalado      |
| [`scripts/vm/vm-start-test-all.sh`](../scripts/vm/vm-start-test-all.sh)           | Executa testes BIOS + UEFI simultaneamente |
| [`scripts/vm/vm-connent-socket.sh`](../scripts/vm/vm-connent-socket.sh)           | Conexão ao console serial via socket       |
| [`scripts/vm/vm-setup.sh`](../scripts/vm/vm-setup.sh)                             | Instala dependências de virtualização      |

---

## 🚀 Uso Rápido

```bash
# 1. Setup do ambiente
make setup-vm
make vm-create-disks

# 2. Build da ISO (se ainda não tiver)
make build-iso

# 3. Testar em ambos os firmwares
make test-vm-all

# 4. Em outro terminal, conectar ao console
make vm-connect-uefi
# ou
make vm-connect-bios
```

---

## 💾 Boot a Partir de Disco Instalado

Para testar sistemas já instalados em discos virtuais, use o script [`vm-start-test-boot-disk.sh`](../scripts/vm/vm-start-test-boot-disk.sh):

### Uso Básico

```bash
# Boot UEFI com disco específico
./scripts/vm/vm-start-test-boot-disk.sh scripts/vm/disks/uefi/installed-system.qcow2

# Boot BIOS com disco específico
./scripts/vm/vm-start-test-boot-disk.sh -f bios scripts/vm/disks/bios/installed-system.qcow2
```

### Opções Disponíveis

| Opção | Descrição | Padrão |
| ----- | ---------- | ------- |
| `-f, --firmware` | Tipo de firmware (uefi/bios) | uefi |
| `-m, --memory` | Memória da VM | 4G |
| `-c, --cpus` | Número de CPUs | 2 |
| `-n, --name` | Nome da VM | disk-boot-<firmware> |
| `-h, --help` | Mostra ajuda | - |

### Exemplos Avançados

```bash
# Boot com configuração customizada
./scripts/vm/vm-start-test-boot-disk.sh \
  -f uefi \
  -m 8G \
  -c 4 \
  -n meu-teste-zfs \
  scripts/vm/disks/uefi/debian-zfs.qcow2

# Boot BIOS com recursos mínimos
./scripts/vm/vm-start-test-boot-disk.sh \
  -f bios \
  -m 2G \
  -c 1 \
  scripts/vm/disks/bios/debian-zfs.qcow2
```

### Validações Automáticas

O script realiza as seguintes validações antes de iniciar a VM:

- ✅ Verifica existência do arquivo de disco
- ✅ Detecta formato do disco (qcow2, raw, vmdk)
- ✅ Valida tamanho mínimo (1GB)
- ✅ Limpa VM anterior com mesmo nome (idempotência)
- ✅ Configura boot apropriado para firmware

### Conexão ao Console

Após iniciar a VM, conecte-se ao console serial:

```bash
# Via script de conexão
./scripts/vm/vm-connent-socket.sh disk-boot-uefi

# Via netcat direto
nc -U /tmp/disk-boot-uefi.sock
```

### Criação de Disco de Teste

Se precisar criar um disco de teste:

```bash
# Criar disco vazio de 20GB
qemu-img create -f qcow2 scripts/vm/disks/uefi/test-disk.qcow2 20G

# Criar disco com formato raw
qemu-img create -f raw scripts/vm/disks/bios/test-disk.raw 20G
```

---

## 🏗️ Arquitetura de Comunicação

A VM expõe console serial via **Unix Domain Socket**, eliminando necessidade de interfaces gráficas:

| Modo | Socket Path               |
| ---- | ------------------------- |
| UEFI | `/tmp/nas-test-uefi.sock` |
| BIOS | `/tmp/nas-test-bios.sock` |

---

## 🤖 Guia para Agentes LLM

### Protocolo de Diagnóstico

1. **Verificação de Boot:**

   ```bash
   make vm-connect-uefi
   ```

2. **Inspeção de Armazenamento:**

   ```bash
   # Dentro do console ou via comando único
   make vm-connect-uefi VM_CMD="lsblk -f"
   ```

3. **Logs de Sistema:**

   ```bash
   make vm-connect-uefi VM_CMD="journalctl -p 3 -n 50"
   ```

4. **Finalização:**
   ```bash
   make vm-connect-uefi VM_CMD="poweroff"
   ```

### Envio de Comandos via Makefile

O Makefile suporta envio de comandos através da variável `VM_CMD`:

```bash
make vm-connect-uefi VM_CMD="uname -a"
make vm-connect-bios VM_CMD="cat /proc/mdstat"
```

### Exemplo de Uso Estratégico

```bash
# Terminal 1: Inicia ambas as VMs
make test-vm-all

# Terminal 2: Agente monitorando BIOS
make vm-connect-bios VM_CMD="mdadm --detail /dev/md0" > raid_report.txt
```

---

## 📝 Referência de Comandos

### vm-start-test-boot-disk.sh

Inicia VM a partir de disco virtual com sistema instalado:

- Suporta formatos: qcow2, raw, vmdk
- Validações automáticas de disco
- Configuração flexível via flags
- Console serial acessível via socket
- Limpeza automática de VMs anteriores

### make test-vm-uefi / make test-vm-bios

Inicia VM isolada com:

- 4 discos virtuais de 10GB (formato QCOW2)
- ISO do live-build como mídia de boot
- Console serial acessível via socket
- Limpeza automática de VMs anteriores

### make vm-connect-uefi / make vm-connect-bios

Conecta ao console serial da VM:

- **Sem argumento:** Modo interativo (Ctrl+C para sair)
- **Com `VM_CMD`:** Envia comando e retorna saída

### make test-vm-all

Executa testes simultâneos:

- Inicia VMs UEFI e BIOS em background
- Captura primeiros 30s de boot em `logs/test-YYYYMMDD-HHMMSS/`
- Permite análise comparativa entre firmwares

---

## ⚠️ Notas Técnicas

- **Timeout:** Socket encerra após 5 segundos de inatividade
- **TTY:** Saída é texto puro (ASCII/UTF-8)
- **Console:** Kernel deve iniciar com `console=ttyS0`
- **Transiência:** VMs não persistem após desligamento
- **Permissões:** Usuário deve estar nos grupos `libvirt` e `kvm`

---

## 🔧 Solução de Problemas

| Problema              | Solução                                             |
| --------------------- | --------------------------------------------------- |
| VM não inicia         | Execute `make vm-destroy` antes de tentar novamente |
| Socket não encontrado | Verifique se a VM está rodando com `make vm-list`   |
| Permissão negada      | Faça logout/login ou execute `newgrp libvirt`       |
| Disco em uso          | Execute `make vm-destroy` para liberar recursos     |
| Disco não encontrado  | Verifique o caminho do disco ou crie um novo       |
| Boot falha            | Verifique se o disco contém sistema instalado válido  |
| Formato inválido      | Use `qemu-img info <disco>` para verificar formato   |
