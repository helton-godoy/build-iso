# Interação com Boot e GRUB

Referência para interagir com o processo de boot de VMs, incluindo navegação no menu GRUB, envio de teclas e console serial durante o boot.

## Por Que É Necessário

O `qemu-guest-agent` e SSH **só funcionam após o SO carregar**. Para interagir com o GRUB (bootloader), é necessário usar mecanismos de nível inferior:

| Ferramenta       | Funciona no GRUB | Funciona no SO |
| ---------------- | ---------------- | -------------- |
| `virsh send-key` | ✅               | ✅             |
| `virsh console`  | ✅ (com serial)  | ✅             |
| SSH              | ❌               | ✅             |
| guest-agent      | ❌               | ✅             |

## virsh send-key (Método Principal)

Envia teclas diretamente para a VM, funciona em qualquer estágio do boot:

```bash
# Pressionar Enter (avançar menu GRUB)
virsh send-key nas-test-uefi KEY_ENTER

# Navegar pelo menu GRUB
virsh send-key nas-test-uefi KEY_DOWN    # Descer no menu
virsh send-key nas-test-uefi KEY_UP      # Subir no menu

# Editar entrada do GRUB
virsh send-key nas-test-uefi KEY_E

# Combinações especiais
virsh send-key nas-test-uefi KEY_LEFTCTRL KEY_LEFTALT KEY_DELETE  # Ctrl+Alt+Del
virsh send-key nas-test-uefi KEY_ESC                               # Escape
virsh send-key nas-test-uefi KEY_TAB                               # Tab

# Enviar texto (letra por letra)
virsh send-key nas-test-uefi KEY_R KEY_O KEY_O KEY_T               # Digitar "root"
```

### Códigos de Teclas Comuns

| Código                 | Tecla               |
| ---------------------- | ------------------- |
| `KEY_ENTER`            | Enter / Return      |
| `KEY_UP`               | Seta para cima      |
| `KEY_DOWN`             | Seta para baixo     |
| `KEY_LEFT`             | Seta para esquerda  |
| `KEY_RIGHT`            | Seta para direita   |
| `KEY_ESC`              | Escape              |
| `KEY_TAB`              | Tab                 |
| `KEY_SPACE`            | Espaço              |
| `KEY_BACKSPACE`        | Backspace           |
| `KEY_DELETE`           | Delete              |
| `KEY_HOME`             | Home                |
| `KEY_END`              | End                 |
| `KEY_F1` ... `KEY_F12` | Teclas de função    |
| `KEY_A` ... `KEY_Z`    | Letras (maiúsculas) |
| `KEY_0` ... `KEY_9`    | Números             |
| `KEY_LEFTCTRL`         | Ctrl esquerdo       |
| `KEY_LEFTALT`          | Alt esquerdo        |
| `KEY_LEFTSHIFT`        | Shift esquerdo      |

> Referência completa: `/usr/include/linux/input-event-codes.h`

## Cenários Práticos

### 1. Avançar Timeout do GRUB

Quando o GRUB está aguardando com countdown:

```bash
# Aguardar VM iniciar e GRUB carregar
sleep 5

# Pressionar Enter para selecionar entrada padrão
virsh send-key nas-test-uefi KEY_ENTER
```

### 2. Selecionar Segunda Entrada do GRUB

```bash
# Navegar para segunda opção e selecionar
virsh send-key nas-test-uefi KEY_DOWN
virsh send-key nas-test-uefi KEY_ENTER
```

### 3. Editar Parâmetros de Kernel

```bash
# Editar entrada selecionada
virsh send-key nas-test-uefi KEY_E

# Navegar até a linha do kernel (3x para baixo, por exemplo)
sleep 0.5
virsh send-key nas-test-uefi KEY_DOWN
virsh send-key nas-test-uefi KEY_DOWN
virsh send-key nas-test-uefi KEY_DOWN

# Ir para fim da linha
virsh send-key nas-test-uefi KEY_END

# Adicionar parâmetro (ex: " single")
virsh send-key nas-test-uefi KEY_SPACE
virsh send-key nas-test-uefi KEY_S KEY_I KEY_N KEY_G KEY_L KEY_E

# Boot com Ctrl+X
virsh send-key nas-test-uefi KEY_LEFTCTRL KEY_X
```

### 4. Detectar Estado e Enviar Tecla Automaticamente

```bash
advance_grub_if_needed() {
  local vm_name="$1"
  local max_wait="${2:-30}"
  local elapsed=0

  while (( elapsed < max_wait )); do
    local state
    state=$(virsh domstate "$vm_name" 2>/dev/null)

    if [[ "$state" == "running" ]]; then
      # VM está rodando — verificar se o SO já carregou
      local ip
      ip=$(virsh domifaddr "$vm_name" 2>/dev/null \
        | awk '$3=="ipv4" {sub(/\/.*/, "", $4); print $4; exit}')

      if [[ -z "$ip" ]]; then
        # Sem IP = possivelmente ainda no GRUB
        virsh send-key "$vm_name" KEY_ENTER 2>/dev/null || true
      else
        # SO carregou, IP detectado
        return 0
      fi
    fi

    sleep 3
    elapsed=$((elapsed + 3))
  done

  return 1
}

# Uso
advance_grub_if_needed "nas-test-uefi" 30
```

## Console Serial com GRUB

Para ver a saída do GRUB no console serial, é necessária configuração prévia **dentro da VM**:

### Configurar GRUB para Console Serial

```bash
# Editar /etc/default/grub na VM
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1"
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"

# Aplicar mudanças
update-grub
```

### Acessar Console Serial

```bash
# Conectar ao console serial da VM
virsh console nas-test-uefi

# Ou via socket unix direto (padrão do projeto)
nc -U /tmp/nas-test-uefi.sock
```

## Comparação: send-key vs console

| Aspecto           | `virsh send-key`           | `virsh console` / socket     |
| ----------------- | -------------------------- | ---------------------------- |
| Requisitos        | Nenhum                     | Console serial configurado   |
| Ver saída do GRUB | ❌ Não                     | ✅ Sim (com serial)          |
| Enviar teclas     | ✅ Sim                     | ✅ Sim                       |
| Funciona pré-OS   | ✅ Sim                     | ✅ Sim                       |
| Automação         | ✅ Fácil (fire-and-forget) | ⚠️ Complexo (parse de saída) |

## Recomendação para Agentes LLM

1. **Use `virsh send-key KEY_ENTER`** para avançar o GRUB rapidamente
2. **Use `nc -U` socket** para ler saída do console serial (se configurado)
3. **Combine com polling de `virsh domifaddr`** para saber quando o SO carregou
4. **Nunca assuma o estado do GRUB** — sempre verifique `virsh domstate` primeiro
