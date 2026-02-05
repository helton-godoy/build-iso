# Product Requirements Document (PRD) Preenchido

## 📝 Descrição: O que é?

O **build-iso** é um framework de automação para criação de imagens ISO personalizadas do Debian (Live) configuradas para realizar instalações com **ZFS-on-root** e **ZFSBootMenu**. O diferencial principal é o suporte universal a firmware, permitindo boot tanto em sistemas **UEFI** quanto **Legacy BIOS** (Hybrid Boot) a partir da mesma imagem e instalação.

> **Status do Projeto:** Build ISO em desenvolvimento
>
> - ✅ Estrutura de código implementada
> - ✅ Scripts de download ZBM implementados
> - ✅ Configuração live-build configurada
> - ✅ Suite de testes implementada

---

## 🔧 Problema: Que problema isso resolve?

O OpenZFS não pode ser distribuído pré-compilado diretamente no kernel Linux devido a incompatibilidades de licença (CDDL vs GPL). Tradicionalmente, isso obriga o instalador a:

1. **Baixar o código-fonte** (requer internet)
2. **Instalar compiladores** (`gcc`, `make`, `linux-headers`)
3. **Compilar módulos DKMS** durante a instalação (lento e consome CPU)

Além disso, o **GRUB** tem suporte limitado ao ZFS, frequentemente apresentando problemas de boot após `zpool upgrade` [Architectural Blueprint, linha 3].

---

## 🔎 Por que: Como sabemos que este é um problema real e que vale a pena resolver?

### Evidências documentadas

1. **Problemas conhecidos do GRUB com ZFS:**

   > "boot on ZFS no longer works with Debian's GRUB after 'zpool upgrade'" [Architectural Blueprint, ref. 1]
   > O GRUB deve incluir sua própria implementação ZFS limitada, frequentemente levando a situações onde atualizar um pool ZFS com feature flags modernos torna o sistema não-bootável [Blueprint, linha 3]

2. **Complexidade de deployment manual:**

   > A criação manual de ZFS-on-root requer conhecimento avançado de particionamento, configuração de bootloader e propriedades ZFS [PROPOSTA-DEBIAN-ZFS, seção 1]

3. **Demanda por automação:**
   > Scripts como `zbm-easy-install` e `zfsbootmenu-autoinstaller` já existem, mas não oferecem uma solução integrada de ISO [PROPOSTA-DEBIAN-ZFS, ref. 12, 13]

### Benefícios esperados

- **Redução de 70% no tempo de deployment automatizado** [PROPOSTA-DEBIAN-ZFS]
- **Recuperação de desastres em menos de 5 minutos** através de snapshots atômicos
- **Conformidade com padrões de segurança corporativa** através de suporte à criptografia nativa (**Opcional para o usuário**)

---

## 🏆 Sucesso: como sabemos se resolvemos esse problema?

### Critérios Funcionais

- [ ] ISO bootável em modo UEFI e BIOS legado
- [ ] Instalação completa em modo automático ou assistido
- [ ] Pool ZFS criado com criptografia nativa
- [ ] ZFSBootMenu funcional com menu de boot environments
- [ ] Sistema operacional funcional após instalação
- [ ] Boot environments funcionando (criação, seleção, rollback)

### Critérios de Qualidade

- [ ] Scripts passam em shellcheck (sem erros críticos)
- [ ] Logging estruturado em todas as operações
- [ ] Código documentado (comentários em português)
- [ ] Testes unitários com cobertura > 80%
- [ ] Testes de integração passando em UEFI e BIOS

### Critérios de Segurança

- [ ] Nenhuma credencial hardcoded
- [ ] Verificação de assinaturas GPG para binários ZFSBootMenu
- [ ] Checksums SHA256 para artefatos
- [ ] Modo dry-run disponível para operações destrutivas

---

## 🌍 Público-alvo: Para quem estamos criando?

| Perfil                          | Necessidade                                       | Modalidade  |
| ------------------------------- | ------------------------------------------------- | ----------- |
| **Administradores de Sistemas** | Deployment rápido e padronizado de servidores ZFS | Servidor    |
| **Profissionais de TI**         | Ambiente de trabalho padronizado com ZFS          | Workstation |
| **DevOps/Engenheiros**          | Pipeline de CI/CD para imagens ZFS                | Ferramenta  |
| **Entusiastas de ZFS**          | Facilidade de instalação e recovery               | Ambas       |

### Modalidades de Imagem

1. **Servidor (debian-server-trixie-zfs):** Foco em estabilidade, SSH, ferramentas de admin
2. **Workstation (debian-workstation-trixie-zfs):** KDE Plasma minimalista, ferramentas de desenvolvimento

---

## 🔬 O quê: Grosso modo, como isso se parece no produto?

### Componentes do Produto Final

```shell
build-iso/
├── output/
│   └── debian-live-amd64.hybrid.iso  # ISO final bootável
├── scripts/
│   ├── download-zfsbootmenu.sh       # Download dependências
│   └── docker/                       # Builder containerizado
├── config-overrides/                 # Configuração live-build
└── Makefile                          # Interface de comandos
```

### Arquitetura da Solução

```diagram
┌─────────────────────────────────────────────────────────────┐
│                    PIPELINE DE BUILD                        │
│  ┌─────────────────┐     ┌─────────────────┐                │
│  │ Docker Builder  │───▶│ Live-Build      │                │
│  │ (debian:trixie) │     │ (chroot)        │                │
│  └─────────────────┘     └─────────────────┘                │
│           │                       │                         │
│           ▼                       ▼                         │
│  Compilação ZFS DKMS     Injeção ZFSBootMenu                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ISO RESULTANTE                           │
│  • Kernel Linux 6.12 com módulos ZFS pré-compilados         │
│  • Binários ZFSBootMenu (vmlinuz + initramfs)               │
│  • Scripts de instalação (/usr/local/bin/install-zfs)       │
│  • Ferramentas de particionamento (gdisk, efibootmgr)       │
└─────────────────────────────────────────────────────────────┘
```

### Fluxo de Uso

```bash
# 1. Baixar dependências
make download-zbm

# 2. Build da ISO
make setup-docker
make build-iso

# 3. Testes em VMs
make setup-vm
make test-vm-all

# 4. Instalação no hardware
# Boot da ISO → sudo install-zfs-debian
```

---

## 🧪 Como: Qual é o plano do experimento?

### Fases de Implementação

| Fase       | Descrição                                                          | Status          |
| ---------- | ------------------------------------------------------------------ | --------------- |
| **Fase 1** | Infraestrutura do projeto (diretórios, Makefile, GitHub Actions)   | ✅ Concluída    |
| **Fase 2** | Build ISO (live-build, package-lists, hooks ZFS/DKMS)              | 🔄 Em Andamento |
| **Fase 3** | Installer automatizado (detecção firmware, particionamento, zpool) | Pending         |
| **Fase 4** | Configurações específicas (usuários, SSH, KDE, boot environments)  | Pending         |
| **Fase 5** | Testes e documentação (unitários, integração, guias)               | Pending         |
| **Fase 6** | Validação final (hardware real UEFI/BIOS, recovery)                | Pending         |

### Estratégia de Validação

1. **Testes Unitários:** Scripts em `tests/` (validação de estrutura, permissões, dependências)
2. **Testes de Integração:** VMs QEMU/KVM para UEFI e BIOS
3. **Testes de Hardware:** Validação em equipamentos reais

### Matriz de Testes

| Script de Teste              | Propósito                   |
| ---------------------------- | --------------------------- |
| `test_vm_uefi.sh`            | Testa boot UEFI             |
| `test_vm_bios.sh`            | Testa boot BIOS legado      |
| `test_iso_structure.sh`      | Valida estrutura da ISO     |
| `test_iso_pool_structure.sh` | Testa estrutura de pool ZFS |
| `test_zbm_hook.sh`           | Testa hooks do ZBM          |

---

## ⏳ Quando: Quando será lançado e quais são os marcos?

### Cronograma

| Marco  | Descrição                             | Data Alvo  |
| ------ | ------------------------------------- | ---------- |
| **M1** | Build ISO funcional (ambas firmwares) | 06/02/2026 |
| **M2** | Installer automatizado implementado   | 07/02/2026 |
| **M3** | Testes de integração passando         | 08/02/2026 |

### Marcos Detalhados

1. **Até 06/02/2026 (06 de fevereiro de 2026)**
   - Build ISO em container Docker funcional
   - Módulos ZFSDKMS compilados durante build
   - Binários ZFSBootMenu injetados na ISO
   - ISO híbrida UEFI+BIOS gerada

2. **Até 07/02/2026 (07 de fevereiro de 2026)**
   - Script `install-zfs-debian` implementado
   - Detecção automática de firmware (UEFI/BIOS)
   - Particionamento híbrido implementado
   - Criação de pool ZFS e datasets

3. **Até 08/02/2026 (08 de fevereiro de 2026)**
   - Testes de integração UEFI passando
   - Testes de integração BIOS passando
   - Documentação de uso completa
   - Suite de testes unitários > 80% cobertura

---

## 📎 Referências e Fontes

| Documento              | Localização                         | Propósito                      |
| ---------------------- | ----------------------------------- | ------------------------------ |
| Blueprint Arquitetural | `docs/Architectural Blueprint...md` | Arquitetura detalhada (inglês) |
| Arquitetura Técnica    | `docs/ARCHITECTURE.md`              | Estratégia de build offline    |
| Estrutura do Projeto   | `docs/PROJECT_STRUCTURE.md`         | Organização de diretórios      |
| Proposta Técnica       | `docs/PROPOSTA-DEBIAN-ZFS.md`       | Requisitos e especificação     |
| Convenções             | `AGENTS.md`                         | Diretrizes de desenvolvimento  |

---

**Documento gerado com base na análise dos documentos do projeto**  
**Data de criação:** 2026-02-05  
**Versão:** 1.0
