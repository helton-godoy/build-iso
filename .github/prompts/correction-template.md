# Template de Correção de Código

## Contexto do Projeto

**Projeto:** Build-ISO - Distribuição Linux baseada em Debian Trixie com ZFS-on-root e ZFSBootMenu

**Repositório:** https://github.com/helton/build-iso

**Branche:** {{BRANCH_NAME}}

**Commit:** {{COMMIT_SHA}}

---

## Visão Geral do Problema

A análise estática do código identificou os seguintes problemas que precisam ser corrigidos:

### Erros Detectados

{{ERRORS_SECTION}}

---

## Regras de Correção

### 1. Convenções de Código (OBRIGATÓRIO)

- **Shebang:** `#!/usr/bin/env bash` (para scripts com bashisms) ou `#!/bin/sh` (POSIX)
- **Sempre:** `set -euo pipefail`
- **Variáveis:** `CONSTANTE` (maiúsculas), `variavel` (minúsculas)
- **Funções:** `verbo_objeto` (ex: `create_zfs_pool`, `detect_firmware`)
- **Formatação:** 2 espaços, max 100 caracteres/linha

### 2. Contrato de Comentários Semânticos (OBRIGATÓRIO)

Siga o PDS-Bash para novos blocos lógicos:

- Sempre adicionar `@ID` + `@STEP` em blocos lógicos novos relevantes para fluxo
- Quando houver dependência de fluxo, adicionar `@REQ`
- Quando houver caminho de erro/contingência, adicionar `@FAIL`
- Quando houver I/O relevante (arquivo/rede/estado), adicionar `@DATA`

**Compatibilidade:** Não remover nem substituir o sistema atual `@INST_*`, `@DEV_*`, `@TEST_*`

### 3. Anti-Padrões a Evitar

#### Instalador / ZFS
- ❌ Nunca hardcode chaves de criptografia
- ❌ Nunca suponha caminhos de dispositivo (sempre validar)
- ❌ Nunca opere em disco sem verificação explícita (`--yes-really-destroy`)
- ❌ Não usar `wipefs` sem `sgdisk --zap-all`

#### NAS / Samba / AD
- ❌ Nunca habilitar `dedup` (impacto severo em performance e RAM)
- ❌ Nunca usar NFS e SMB no mesmo dataset (conflito de ACLs)
- ❌ Nunca hardcode senhas em scripts (usar SSH por chave ou prompt)

### 4. Padrões Obrigatórios

#### Uso de echo para erros
❌ **ERRADO:**
```bash
echo "Erro fatal: $msg" >&2
exit 1
```

✅ **CORRETO:**
```bash
ui_panic "Erro fatal: $msg"
```

#### Uso de chroot
❌ **ERRADO:**
```bash
chroot /target /bin/bash -c "command"
```

✅ **CORRETO:**
```bash
execute_in_chroot "/target" "command"
```

#### Uso de colchetes
❌ **ERRADO:**
```bash
if [ "$var" == "value" ]; then
```

✅ **CORRETO:**
```bash
if [[ "$var" == "value" ]]; then
```

#### Variáveis em aspas
❌ **ERRADO:**
```bash
if [ $var ]; then
```

✅ **CORRETO:**
```bash
if [[ "$var" ]]; then
```

---

## Schema de Estado

Use apenas chaves de estado registradas. Se necessário adicionar uma nova chave, atualize o schema em AGENTS.md.

### Chaves Registradas

| Chave | Descrição |
|-------|-----------|
| INST_DISK_TARGET | Disco selecionado (/dev/sda) |
| INST_ZFS_POOL | Nome do pool ZFS (zroot) |
| INST_ZFS_STRATEGY | Topologia (single, mirror, raidz1) |
| INST_HOSTNAME | Nome da máquina |
| INST_USER_ADMIN | Usuário admin |
| INST_SMB_COMPAT | Compatibilidade Windows (true/false) |
| INST_STEP_CURRENT | Step atual no workflow |

---

## Cadeia de Steps

Ao modificar steps do instalador, mantenha a integridade da cadeia:

1. Cada step deve ter `@INST_STEP_ID` único
2. `@INST_NEXT` deve apontar para um step existente
3. O último step deve ter `@INST_NEXT` vazio ou nulo

---

## Como Corrigir

1. **Analise cada erro** listado na seção "Erros Detectados"
2. **Aplique as correções** seguindo as regras acima
3. **Execute os scripts de validação** localmente:
   ```bash
   ./scripts/validate-semantic-tags.sh -v
   ./scripts/validate-agents-contract.sh -v
   ./scripts/validate-state-schema.sh -v
   ./scripts/validate-step-chain.sh -v
   ./scripts/check-forbidden-patterns.sh -v
   ```
4. **Rode ShellCheck** para garantir qualidade:
   ```bash
   shellcheck -x config-overrides/config/includes.chroot/usr/local/lib/installer/**/*.sh
   ```
5. **Faça commit** das correções com mensagem descritiva

---

## Recursos Adicionais

- [Documentação do Projeto](../docs/)
- [AGENTS.md](../AGENTS.md)
- [Convenções de Código](../docs/COMMENT_PROTOCOL_PDS_BASH.md)

---

*Este template foi gerado automaticamente pela análise estática do GitHub Actions*
