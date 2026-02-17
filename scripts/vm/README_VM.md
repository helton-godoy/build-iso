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
make vm-connect-uefi CMD="<comando>"  # Executa comando remoto na VM UEFI
make vm-connect-bios CMD="<comando>"  # Executa comando remoto na VM BIOS

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

# 4. Em outro terminal, executar análises remotas
make vm-connect-uefi CMD="lsblk -f"
# ou
make vm-connect-bios CMD="journalctl -p 3 -n 50"
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
   make vm-connect-uefi CMD="echo boot-ok && hostname"
   ```

2. **Inspeção de Armazenamento:**

   ```bash
   # Via comando único remoto
   make vm-connect-uefi CMD="lsblk -f"
   ```

3. **Logs de Sistema:**

   ```bash
   make vm-connect-uefi CMD="journalctl -p 3 -n 50"
   ```

4. **Finalização:**
   ```bash
   make vm-connect-uefi CMD="poweroff"
   ```

### Envio de Comandos via Makefile

Os alvos de conexão aceitam comandos pela variável `CMD`:

```bash
make vm-connect-uefi CMD="uname -a"
make vm-connect-bios CMD="cat /proc/mdstat"
make vm-show-ip
```

O alvo `vm-show-ip` exibe o estado atual do cache de IPs (`VM_IP_UEFI` e `VM_IP_BIOS`) em `scripts/vm/.cache/vm-ips.env`.

Se `CMD` não for informado, o script exibe ajuda com:

- finalidade do parâmetro `CMD`;
- IP detectado da VM (`VM_IP_UEFI` / `VM_IP_BIOS` em cache local);
- hostname live esperado por contexto (`debian-trixie-zbm-<tipo>-<uefi|bios>`);
- comando sugerido para acesso interativo manual quando necessário.

### Hostname dinâmico no Live Boot

Para reduzir ambiguidade entre VMs, o hostname da imagem live agora é ajustado em runtime por contexto:

- firmware: `uefi` ou `bios`;
- tipo de máquina: detectado por `systemd-detect-virt` (ex.: `kvm`, `qemu`) ou `physical`.

Formato final:

```text
debian-trixie-zbm-<tipo>-<firmware>
```

Exemplos comuns em laboratório:

- `debian-trixie-zbm-kvm-uefi`
- `debian-trixie-zbm-kvm-bios`

Importante: essa mudança entra em vigor após rebuild da ISO e novo boot da VM (`make build-iso` + `make test-vm-uefi`/`make test-vm-bios`).

### Exemplo de Uso Estratégico

```bash
# Terminal 1: Inicia ambas as VMs
make test-vm-all

# Terminal 2: Agente monitorando BIOS
make vm-connect-bios CMD="mdadm --detail /dev/md0" > raid_report.txt
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

Executa comando remoto via SSH com bootstrap automático:

- **Com `CMD`:** Executa análise remota de forma não interativa
- **Sem `CMD`:** Exibe ajuda, IP detectado e instrução para acesso interativo manual
- **Detecção de IP:** Fast-path via `virsh domifaddr` com fallback para leases DHCP

Variáveis úteis de performance:

- `VM_IP_DETECT_ATTEMPTS` (padrão: `6`)
- `VM_IP_DETECT_INTERVAL` (padrão: `1` segundo)
- `VM_DHCP_TIMEOUT` (padrão: `12` segundos no conector legado)
- `VM_LIVE_BOOT_WAIT` (padrão: `30`, usado apenas quando bootstrap serial é necessário)

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
