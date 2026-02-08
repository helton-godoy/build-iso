# Workflow AI-Driven e Spec-Driven

## Objetivo

Este guia documenta um fluxo operacional padrao para colaboradores e agentes LLM trabalharem no projeto com:

- previsibilidade (passos claros e repetiveis);
- automacao de build/teste/conexao em VM;
- rastreabilidade por especificacao (OpenSpec);
- execucao nao interativa (ideal para agentes com menor capacidade de inferencia).

---

## Ferramentas de Workflow Disponiveis

### 1) Interface de automacao do projeto (Makefile + scripts)

Use quando o foco for **build, boot de VM, conexao e validacao tecnica**.

- `make build-iso`
- `make test-vm-uefi`
- `make test-vm-bios`
- `make test-vm-all`
- `make vm-connect-uefi`
- `make vm-connect-bios`

Script-chave para agentes:

- `scripts/vm/vm-connent-agent-llm.sh`

### 2) Workflow AI-driven (OpenCode commands)

Use quando o foco for **ciclo de engenharia assistida por IA** (ticket -> pesquisa -> plano -> execucao -> revisao).

- `/ticket`
- `/research`
- `/plan`
- `/execute`
- `/review`
- `/commit`

### 3) Workflow Spec-driven (OpenSpec experimental)

Use quando o foco for **mudanca orientada por artefatos de especificacao**.

- `/opsx-new`
- `/opsx-explore`
- `/opsx-continue`
- `/opsx-apply`
- `/opsx-verify`
- `/opsx-sync`
- `/opsx-archive`

Regra pratica:

- Mudanca pequena/corretiva: AI-driven pode ser suficiente.
- Mudanca estrutural/multietapa: priorize Spec-driven com OpenSpec.

---

## Fluxo Recomendado de Desenvolvimento

```mermaid
flowchart TD
    A[Definir demanda] --> B{Escopo}
    B -->|Pequeno| C[/ticket + /research/]
    B -->|Estrutural| D[/opsx-new + /opsx-explore/]

    C --> E[/plan/]
    D --> F[/opsx-continue/]
    F --> G[/opsx-apply/]

    E --> H[/execute/]
    G --> H

    H --> I[Validar local: testes + bash -n + lsp]
    I --> J[Validar VM: make test-vm-*]
    J --> K[/review ou /opsx-verify/]
    K --> L{Aprovado?}
    L -->|Nao| E
    L -->|Sim| M[/commit/]
    M --> N[/opsx-sync + /opsx-archive/]
```

- No fluxo AI-driven, seu loop Não -> /plan está correto (replaneja e executa de novo).

```mermaid
flowchart TD
    A[Definir demanda] --> B{Escopo}
    B -->|Pequeno| C["/ticket + /research"]
    C --> D["/plan"]
    D --> E["/execute"]
    E --> F["/review"]
    F --> G{Aprovado?}
    G -->|Sim| H["/commit"]
    G -->|Nao| D
```

- No fluxo Spec-driven, o Não precisa decidir se o problema é:
  - de especificação/artifacts -> volta para /opsx-continue
  - de implementação -> volta para /opsx-apply

```mermaid
flowchart TD
    A[Definir demanda] --> B{Escopo}
    B -->|Estrutural| C["/opsx-new + /opsx-explore"]
    C --> D["/opsx-continue"]
    D --> E["/opsx-apply"]
    E --> F["Validar local: testes + bash -n + lsp"]
    F --> G["Validar VM: make test-vm-*"]
    G --> H["/opsx-verify"]
    H --> I{Aprovado?}
    I -->|Sim| J["/opsx-sync + /opsx-archive"]
    I -->|Nao| K{Falha em spec ou implementacao?}
    K -->|Spec/artifact| D
    K -->|Implementacao| E
```

```mermaid
flowchart LR

    A[Definir demanda] --> B{Escopo}

    subgraph AI["Workflow AI-driven (mudanças pequenas)"]

      direction TB
      C["/ticket + /research"] --> D["/plan"]
      D --> E["/execute"]
      E --> F["/review"]
      F --> G{Aprovado?}
      G -->|Sim| H["/commit"]
      G -->|Nao| D

    end

    subgraph OPSX["Workflow Spec-driven (mudanças estruturais)"]

      direction TB
      I["/opsx-new + /opsx-explore"] --> J["/opsx-continue"]
      J --> K["/opsx-apply"]
      K --> L["Validar local: testes + bash -n + lsp"]
      L --> M["Validar VM: make test-vm-*"]
      M --> N["/opsx-verify"]
      N --> O{Aprovado?}
      O -->|Sim| P["/opsx-sync + /opsx-archive"]
      O -->|Nao| Q{Falha em spec ou implementação?}
      Q -->|Spec/artifact| J
      Q -->|Implementação| K

    end

    B -->|Pequeno| C
    B -->|Estrutural| I
```

```mermaid
flowchart TD
    A[Definir demanda] --> B{Escopo}
    subgraph AI["Workflow AI-driven (mudanças pequenas)"]
      direction TB
      C["/ticket + /research"] --> D["/plan"]
      D --> E["/execute"]
      E --> F["/review"]
      F --> G{Aprovado?}
      G -->|Sim| H["/commit"]
      G -->|Nao| D
    end
    subgraph OPSX["Workflow Spec-driven (mudanças estruturais)"]
      direction TB
      I["/opsx-new + /opsx-explore"] --> J["/opsx-continue"]
      J --> K["/opsx-apply"]
      K --> L["Validar local: testes + bash -n + lsp"]
      L --> M["Validar VM: make test-vm-*"]
      M --> N["/opsx-verify"]
      N --> O{Aprovado?}
      O -->|Sim| P["/opsx-sync + /opsx-archive"]
      O -->|Nao| Q{Falha em spec ou implementação?}
      Q -->|Spec/artifact| J
      Q -->|Implementação| K
    end
    B -->|Pequeno| C
    B -->|Estrutural| I
```

---

## Fluxo de Conectividade para Agentes LLM (Nao Interativo)

O alvo `make vm-connect-bios` e `make vm-connect-uefi` usa `vm-connent-agent-llm.sh` como gateway.

Esse gateway automatiza:

1. Geracao de chave SSH local (`~/.ssh/id_ed25519`) se nao existir.
2. Descoberta de IP por `virsh` quando `VM_IP` nao for informado.
3. Bootstrap via serial socket da VM:
   - cria `~root/.ssh/authorized_keys`;
   - habilita `PermitRootLogin yes`;
   - habilita `PasswordAuthentication yes`;
   - define senha root como `x` (ambiente live/lab);
   - reinicia `ssh`.
4. Tentativa de `ssh-copy-id` com `sshpass` (se instalado).
5. Execucao por SSH; se indisponivel, fallback serial automatizado.

```mermaid
flowchart TD
    A[make vm-connect-<mode>] --> B[vm-connent-agent-llm.sh]
    B --> C{Chave local existe?}
    C -->|Nao| D[Gerar id_ed25519]
    C -->|Sim| E[Continuar]
    D --> E

    E --> F{VM_IP informado?}
    F -->|Sim| G[Usar VM_IP]
    F -->|Nao| H[Detectar IP com virsh]
    H --> G

    G --> I{SSH por chave responde?}
    I -->|Sim| J[Executar comando via SSH]
    I -->|Nao| K[Bootstrap SSH via socket serial]
    K --> L[Tentar ssh-copy-id com sshpass]
    L --> M{SSH pronto?}
    M -->|Sim| J
    M -->|Nao| N[Fallback: enviar comando via serial]
```

---

## Comandos Padrao para Agentes

### Bootstrap completo de ambiente

```bash
make setup-vm
make download-zbm
make setup-docker
make build-iso
```

### Subir VM de teste

```bash
make test-vm-bios
# ou
make test-vm-uefi
# ou
make test-vm-all
```

### Executar validacao remota nao interativa

Com IP explicito (mais estavel para automacao):

```bash
make vm-connect-bios VM_IP=192.168.100.207 VM_CMD="uname -a && lsblk -f"
```

Sem IP explicito (autodescoberta via `virsh`):

```bash
make vm-connect-bios VM_CMD="journalctl -p 3 -n 80"
```

### Exemplo de checks padrao de bugfix

```bash
make vm-connect-bios VM_IP=192.168.100.207 VM_CMD="bash -n /usr/local/bin/installer"
make vm-connect-bios VM_IP=192.168.100.207 VM_CMD="/usr/local/bin/installer --print-map"
make vm-connect-bios VM_IP=192.168.100.207 VM_CMD="ip -4 -o addr show"
```

---

## Como Manter o Workflow Eficiente

1. Sempre prefira comandos nao interativos (`VM_CMD=...`, `BatchMode=yes`, scripts idempotentes).
2. Use `VM_IP` explicito em CI/local quando possivel para reduzir ambiguidades de rede.
3. Separe ciclo em tres fases curtas:
   - especificacao (AI/spec-driven),
   - implementacao local,
   - verificacao em VM.
4. Em correcoes de bug, aplique mudanca minima e valide com comando objetivo na VM.
5. Mantenha evidencias de validacao no PR/relatorio (comandos executados + resultado).

---

## Reconstrucao do Ambiente (Disaster Recovery)

Quando o ambiente estiver inconsistente, use este reset rapido:

```bash
make clean
make setup-vm
make download-zbm
make setup-docker
make build-iso
make test-vm-bios
```

Se a conexao da VM falhar:

1. Verifique VMs ativas:

```bash
make vm-list
```

2. Recrie apenas VM de teste:

```bash
make vm-destroy
make test-vm-bios
```

3. Reforce bootstrap de conectividade para agente:

```bash
make vm-connect-bios VM_CMD="echo ready && hostname"
```

---

## Seguranca (Ambiente de Teste)

- A senha root `x` e a habilitacao de `PasswordAuthentication yes` sao aceitaveis apenas em ambiente de laboratorio/live.
- Para ambientes mais sensiveis, apos validacao, reverta para acesso por chave:

```bash
make vm-connect-bios VM_CMD="sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl restart ssh"
```

---

## Referencias Internas

- `scripts/vm/vm-connent-agent-llm.sh`
- `scripts/vm/vm-connent-ssh.sh`
- `scripts/vm/README_VM.md`
- `docs/PROJECT_STRUCTURE.md`
- `docs/INSTALLER_JUNIOR_PLAYBOOK.md`
- `AGENTS.md`
