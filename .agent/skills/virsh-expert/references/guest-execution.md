# Execução de Comandos Dentro da VM

Referência para executar comandos no sistema operacional guest via diferentes canais: `qemu-guest-agent`, SSH e console serial.

## Visão Geral dos Canais

| Canal                | Pré-requisito       | Stdin Interativo | Funciona sem SO | Funciona sem Rede |
| -------------------- | ------------------- | ---------------- | --------------- | ----------------- |
| **SSH**              | sshd + rede + chave | ✅ Sim           | ❌ Não          | ❌ Não            |
| **qemu-guest-agent** | agente instalado    | ❌ Não           | ❌ Não          | ✅ Sim            |
| **Console serial**   | socket unix         | ⚠️ Limitado      | ❌ Não          | ✅ Sim            |
| **virsh send-key**   | nenhum              | ❌ Não           | ✅ Sim          | ✅ Sim            |

## Canal 1: SSH (Preferencial para Agentes)

O projeto usa SSH como canal principal para execução remota.

### Fluxo de Bootstrap Automático

```bash
# Via Makefile (recomendado)
make vm-connect-uefi CMD="uname -a"
make vm-connect-bios CMD="zpool status"

# Via script direto
VM_CMD="lsblk -f" bash scripts/vm/vm-connect-agent-llm.sh uefi
```

### Detecção de IP + SSH Manual

```bash
# 1. Detectar IP da VM
VM_IP=$(virsh domifaddr nas-test-uefi | awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}')

# 2. Copiar chave SSH (primeira vez)
ssh-copy-id -o StrictHostKeyChecking=no "root@${VM_IP}"

# 3. Executar comando
ssh -o StrictHostKeyChecking=no -o BatchMode=yes "root@${VM_IP}" "lsblk -f"
```

### Bootstrap SSH via Serial (Ambiente Novo)

Quando a VM nunca recebeu chave SSH, o projeto injeta a chave via console serial:

```bash
SOCKET_PATH="/tmp/nas-test-uefi.sock"
PUBKEY="$(< ~/.ssh/id_ed25519.pub)"

# Enviar via serial (Ctrl+U limpa linha + comando)
printf '\025mkdir -p /root/.ssh && chmod 700 /root/.ssh\n' | nc -U -w 3 "$SOCKET_PATH"
printf '\025printf "%%s\\n" "%s" >> /root/.ssh/authorized_keys\n' "$PUBKEY" | nc -U -w 3 "$SOCKET_PATH"
printf '\025chmod 600 /root/.ssh/authorized_keys\n' | nc -U -w 3 "$SOCKET_PATH"
printf '\025systemctl restart ssh\n' | nc -U -w 3 "$SOCKET_PATH"
```

## Canal 2: QEMU Guest Agent (guest-exec)

Para execução sem rede. Requer `qemu-guest-agent` instalado e rodando na VM.

### Executar Comando

```bash
# Executa comando e obtém PID
virsh qemu-agent-command nas-test-uefi \
  '{"execute": "guest-exec", "arguments": {"path": "/usr/bin/hostname", "arg": [], "capture-output": true}}'

# Resposta:
# {"return":{"pid":12345}}
```

### Obter Resultado

```bash
# Consulta resultado pelo PID
virsh qemu-agent-command nas-test-uefi \
  '{"execute": "guest-exec-status", "arguments": {"pid": 12345}}'

# Resposta (base64):
# {"return":{"exitcode":0,"exited":true,"out-data":"ZGViaWFuLXRyaXhpZS16Ym0K"}}
```

### Decodificar Saída Base64

```bash
# Comando completo com decodificação
PID=$(virsh qemu-agent-command nas-test-uefi \
  '{"execute": "guest-exec", "arguments": {"path": "/usr/bin/uname", "arg": ["-a"], "capture-output": true}}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['return']['pid'])")

sleep 1

virsh qemu-agent-command nas-test-uefi \
  "{\"execute\": \"guest-exec-status\", \"arguments\": {\"pid\": $PID}}" \
  | python3 -c "import sys,json,base64; d=json.load(sys.stdin)['return']; print(base64.b64decode(d.get('out-data','')).decode())"
```

### Wrapper Bash para guest-exec

```bash
guest_exec() {
  local vm_name="$1"
  local cmd_path="$2"
  shift 2
  local args_json=""

  # Construir array JSON de argumentos
  if (( $# > 0 )); then
    args_json=$(printf '"%s",' "$@")
    args_json="[${args_json%,}]"
  else
    args_json="[]"
  fi

  # Executar comando
  local pid
  pid=$(virsh qemu-agent-command "$vm_name" \
    "{\"execute\": \"guest-exec\", \"arguments\": {\"path\": \"$cmd_path\", \"arg\": $args_json, \"capture-output\": true}}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['return']['pid'])")

  # Aguardar e obter resultado
  sleep 1
  virsh qemu-agent-command "$vm_name" \
    "{\"execute\": \"guest-exec-status\", \"arguments\": {\"pid\": $pid}}" \
    | python3 -c "import sys,json,base64; d=json.load(sys.stdin)['return']; print(base64.b64decode(d.get('out-data','')).decode(), end='')"
}

# Uso:
guest_exec "nas-test-uefi" "/usr/bin/hostname"
guest_exec "nas-test-uefi" "/usr/bin/ls" "-la" "/root"
```

### Outros Comandos do Guest Agent

```bash
# Verificar se o agente está respondendo
virsh qemu-agent-command nas-test-uefi '{"execute": "guest-ping"}'

# Obter informações do SO
virsh qemu-agent-command nas-test-uefi '{"execute": "guest-info"}'

# Listar interfaces de rede (dentro da VM)
virsh qemu-agent-command nas-test-uefi '{"execute": "guest-network-get-interfaces"}'

# Ler arquivo
virsh qemu-agent-command nas-test-uefi \
  '{"execute": "guest-file-open", "arguments": {"path": "/etc/hostname", "mode": "r"}}'
```

## Canal 3: Console Serial

Acesso direto ao TTY via socket Unix.

```bash
# Conexão interativa
nc -U /tmp/nas-test-uefi.sock

# Enviar comando único (Ctrl+U limpa linha)
printf '\025%s\n' "hostname" | nc -U -w 3 /tmp/nas-test-uefi.sock

# Múltiplos comandos sequenciais
for cmd in "uname -a" "lsblk" "free -h"; do
  printf '\025%s\n' "$cmd" | nc -U -w 3 /tmp/nas-test-uefi.sock
  sleep 1
done
```

### Limitações do Console Serial

- **Sem parsing confiável**: Saída mistura prompt + resultado + caracteres de controle
- **Sem exit code**: Não há como saber se o comando falhou
- **Sem captura limpa**: Use SSH ou guest-agent quando precisar processar a saída

## Interação com Scripts Gum (Não-Interativo)

O `qemu-guest-agent` **não suporta stdin interativo**, então scripts com `gum choose` ou `gum input` ficam travados. Soluções:

### Padrão Recomendado: Fallback por Argumentos

```bash
# No script: aceitar valor via argumento ou variável de ambiente
NAME="${1:-$(gum input --placeholder "Nome do usuário")}"
COUNTRY="${2:-$(gum choose "Brasil" "Argentina" "Chile")}"
```

### Executar Script com Parâmetros via guest-exec

```bash
virsh qemu-agent-command nas-test-uefi '{
  "execute": "guest-exec",
  "arguments": {
    "path": "/usr/local/bin/meu-script.sh",
    "arg": ["João Silva", "Brasil"],
    "capture-output": true
  }
}'
```

### Forçar Modo Não-Interativo

```bash
# Via variável de ambiente
FORCE_NONINTERACTIVE=1 /usr/local/bin/meu-script.sh
```
