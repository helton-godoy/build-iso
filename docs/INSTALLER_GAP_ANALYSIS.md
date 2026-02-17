# Análise de Gaps - Instalador vs Melhores Práticas

**Data:** 2026-02-15  
**Objetivo:** Mapear o que já existe no instalador vs. melhores práticas do setor

---

## ✅ O QUE JÁ ESTÁ IMPLEMENTADO

### 1. State Machine (Bom)

**Arquivo:** `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/state-utils.sh`

- ✅ Persistência de estado em arquivo (`STATE_FILE`)
- ✅ Funções `state_kv_set` / `state_kv_get` 
- ✅ Carregamento de estado com `state_load`
- ✅ Steps com flow control (`@INST_STEP_FLOW: prev=review, next=post_install`)
- ✅ Sanitização de chaves e valores

**Exemplo existente:**
```bash
# steps/install.sh
# @INST_STEP_FLOW: prev=review, next=post_install
state_kv_set "install_plan_mode" "$plan_mode"
```

### 2. Preflight Checks (Parcial)

**Arquivo:** `config-overrides/config/includes.chroot/usr/local/lib/installer/libs/validate-utils.sh`

- ✅ Validação de seleção de disco (`validate_disk_selection`)
- ✅ Checkpoint geral (`validate_all_checkpoint`)
- ✅ Validação em `step_install` antes de prosseguir

**Validações no install.sh:**
- ✅ Verificação de disco/pool definidos
- ✅ Validação de topologia vs contagem de discos
- ✅ Recusa de instalação em disco USB (`diskid_policy_refuse_usb_install`)
- ✅ Validação de target disk (`diskutils_validate_target_disk`)
- ✅ Modo offline verifica artefatos locais

### 3. VM Testing (Bom)

**Arquivos:**
- `tests/test_iso_qemu.sh` - Teste de boot com QEMU
- `tests/test_vm_boot_validation.sh` - Validação de boot
- `scripts/vm/vm-start-test-*.sh` - Scripts de teste VM

- ✅ Teste de boot UEFI e BIOS
- ✅ Criação de disco QCOW2 para testes
- ✅ Validação de tamanho da ISO
- ✅ Logs de execução
- ✅ Suporte a modo não-interativo (CI/CD)

### 4. Error Handling (Parcial)

- ✅ `set -euo pipefail` presente na maioria dos scripts
- ✅ Sanitização de inputs (`sanitize_path`, `sanitize_ws`)
- ✅ Confirmação antes de operações destrutivas (`ui_confirm`)

---

## ⚠️ GAPS IDENTIFICADOS (Alta Prioridade)

### 1. Logging Estruturado (Gap Crítico)

**Problema:** Logs básicos, sem níveis de severidade nem captura estruturada

**O que falta:**
- ❌ Níveis de log (DEBUG, INFO, WARN, ERROR, FATAL)
- ❌ Log em arquivo estruturado com timestamps
- ❌ Log de comandos executados (como `set -x` mas controlado)
- ❌ Captura automática de diagnósticos em falha

**Implementação recomendada:**
```bash
# Adicionar a libs/log-utils.sh
readonly LOG_LEVEL_DEBUG=7
readonly LOG_LEVEL_INFO=6
readonly LOG_LEVEL_WARN=4
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=0

log_info() { log_msg $LOG_LEVEL_INFO "$1"; }
log_error() { log_msg $LOG_LEVEL_ERROR "$1"; }
log_fatal() { log_msg $LOG_LEVEL_FATAL "$1"; exit 1; }
```

### 2. Retry/Resumability (Gap Médio)

**Problema:** Se a instalação falhar no meio, não há mecanismo claro de retry

**O que falta:**
- ❌ Tracking de retry por step
- ❌ Mecanismo de fall-through para resumir instalação
- ❌ Estado `FAILED` vs `RUNNING` vs `DONE` explícito

**Implementação recomendada:**
```bash
# Extensão ao state-utils.sh
step_set_status() {
  local step="$1" status="$2"
  state_kv_set "step_status_${step}" "$status"
  state_kv_set "step_timestamp_${step}" "$(date -Iseconds)"
}

step_get_status() {
  state_kv_get "step_status_${1}"
}
```

### 3. Rollback Automático (Gap Alto)

**Problema:** Não há rollback de steps em caso de falha

**O que falta:**
- ❌ Cleanup trap robusto
- ❌ Registro de recursos alocados (mounts, devices)
- ❌ Funções de rollback por step

**Implementação recomendada:**
```bash
# Adicionar a libs/cleanup-utils.sh
declare -a CLEANUP_MOUNTS=()
declare -a CLEANUP_DEVICES=()

register_mount() { CLEANUP_MOUNTS+=("$1"); }
register_device() { CLEANUP_DEVICES+=("$1"); }

cleanup() {
  for ((i=${#CLEANUP_MOUNTS[@]}-1; i>=0; i--)); do
    umount -R "${CLEANUP_MOUNTS[$i]}" 2>/dev/null || true
  done
  # ... etc
}
trap cleanup EXIT INT TERM
```

### 4. Diagnósticos em Falha (Gap Alto)

**Problema:** Quando falha, não coleta informações suficientes para debug

**O que falta:**
- ❌ Captura de `dmesg`, `zpool status`, `zfs list`
- ❌ Dump do estado do instalador
- ❌ Informações de hardware (memória, CPU)
- ❌ Compactação de logs para análise

**Implementação recomendada:**
```bash
# Adicionar a libs/diag-utils.sh
capture_diagnostics() {
  local diag_dir="${STATE_DIR}/diagnostics/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$diag_dir"
  
  dmesg > "${diag_dir}/dmesg.txt"
  zpool status > "${diag_dir}/zpool_status.txt" 2>/dev/null || true
  zfs list > "${diag_dir}/zfs_list.txt" 2>/dev/null || true
  cat /proc/meminfo > "${diag_dir}/meminfo.txt"
  cp "$STATE_FILE" "${diag_dir}/installer.state"
  
  tar czf "${STATE_DIR}/diagnostics.tar.gz" -C "$diag_dir" .
}
```

### 5. Validações de Recursos (Gap Médio)

**Problema:** Falta verificação de recursos mínimos

**O que falta:**
- ❌ Verificação de memória mínima (4GB para ZFS)
- ❌ Verificação de espaço em disco antes de particionar
- ❌ Verificação de arquitetura de CPU
- ❌ Detecção de ambiente virtualizado

**Implementação recomendada:**
```bash
# Extensão a validate-utils.sh
validate_system_resources() {
  local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local mem_gb=$((mem_kb / 1024 / 1024))
  
  if [[ $mem_gb -lt 4 ]]; then
    ui_error "Memória insuficiente: ${mem_gb}GB (mínimo 4GB para ZFS)"
    return 1
  fi
}
```

---

## 📋 CHECKLIST DE IMPLEMENTAÇÃO RECOMENDADA

### Prioridade 1 (Crítico - Blocks Release)
- [ ] Implementar logging estruturado em arquivo
- [ ] Adicionar captura de diagnósticos em falha
- [ ] Implementar cleanup trap com registro de recursos

### Prioridade 2 (Importante - Robustez)
- [ ] Adicionar validações de recursos (memória, disco)
- [ ] Implementar retry por step
- [ ] Criar funções de rollback específicas por step
- [ ] Adicionar validações de checksum para downloads

### Prioridade 3 (Melhoria - UX/Debug)
- [ ] Melhorar logs de console com cores e ícones
- [ ] Adicionar modo verbose controlado por flag
- [ ] Criar script de validação pós-instalação
- [ ] Documentar troubleshooting no AGENTS.md

---

## 🔧 ARQUITETURA PROPOSTA

```
config-overrides/config/includes.chroot/usr/local/lib/installer/
├── libs/
│   ├── state-utils.sh        # ✅ Já existe
│   ├── validate-utils.sh     # ✅ Já existe (expandir)
│   ├── log-utils.sh          # 🆕 NOVO: Logging estruturado
│   ├── cleanup-utils.sh      # 🆕 NOVO: Trap e rollback
│   ├── diag-utils.sh         # 🆕 NOVO: Captura de diagnósticos
│   └── ... outros
├── steps/
│   ├── install.sh            # ✅ Já existe (refatorar para usar novos utils)
│   └── ... outros
└── state/
    └── .installer/
        ├── state             # ✅ Já existe
        ├── install.log       # 🆕 NOVO: Log principal
        ├── debug.log         # 🆕 NOVO: Log detalhado
        └── diagnostics/      # 🆕 NOVO: Diagnósticos de falha
```

---

## 📊 REFERÊNCIAS

Documento completo de melhores práticas: `docs/BEST_PRACTICES_SHELL_INSTALLERS.md`

**Fontes pesquisadas:**
- ZFSBootMenu (logging em kernel message buffer)
- bash-installer-framework (state machine com tasks)
- Debian d-i (preseed e validações)
- Arch Linux install (chroot patterns)
- openQA (VM testing automation)

---

*Análise gerada em 2026-02-15*
