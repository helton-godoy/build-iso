# Arquitetura de Armazenamento ZFS: Guia de Topologias e VDEVs

Este documento detalha as opções de configuração de armazenamento do ZFS suportadas pelo Fileserver Installer, suas características, limitações e recomendações de uso.

## 1. Topologias de Dados (Data VDEVs)

A escolha da topologia do vdev principal define o desempenho, confiabilidade e capacidade do seu pool.

### Stripe (Single Disk / No Redundancy)

- **Descrição:** Dados distribuídos sem paridade ou espelhamento.
- **Redundância:** Nenhuma. Se um disco falhar, **todo o pool é perdido**.
- **Desempenho:** Alto (IOPS soma de todos os discos).
- **Uso Recomendado:** Apenas para dados temporários, cache descartável ou testes. **Nunca usar em produção**.
- **Mínimo:** 1 disco.

### Mirror (Espelhamento)

- **Descrição:** Dados idênticos gravados em 2 ou mais discos. Similar a RAID 1.
- **Redundância:** Alta. Suporta falha de N-1 discos no grupo.
- **Desempenho:**
  - **Leitura:** Excelente (lê de qualquer disco ocioso).
  - **Escrita:** Limitada pela velocidade do disco mais lento.
  - **Resilvering:** Muito rápido.
- **Capacidade:** 50% (para mirror de 2 vias).
- **Uso Recomendado:** Virtualização, bancos de dados, situações que exigem alto IOPS e resilvering rápido.
- **Mínimo:** 2 discos (recomendado par).

### RAIDZ1 (Paridade Simples)

- **Descrição:** Similar ao RAID 5. Um bloco de paridade por stripe.
- **Redundância:** Suporta falha de **1 disco**.
- **Desempenho:** Bom para leitura sequencial. Escrita penalizada por cálculo de paridade.
- **Risco:** Se um disco falhar e ocorrer erro de leitura (URE) durante a reconstrução em outro disco, dados podem ser corrompidos. Não recomendado para discos > 2TB.
- **Mínimo:** 3 discos.

### RAIDZ2 (Paridade Dupla)

- **Descrição:** Similar ao RAID 6. Dois blocos de paridade.
- **Redundância:** Suporta falha de **2 discos** simultâneos.
- **Recomendação Padrão:** É o padrão da indústria para armazenamento de arquivos geral (NAS/Backup) devido ao equilíbrio entre segurança e capacidade.
- **Desempenho:** Inferior ao Mirror em IOPS aleatórios, excelente para throughput sequencial.
- **Mínimo:** 4 discos.

### RAIDZ3 (Paridade Tripla)

- **Descrição:** Três blocos de paridade.
- **Redundância:** Suporta falha de **3 discos**.
- **Uso Recomendado:** Arrays muito grandes com discos de alta capacidade e tempo de reconstrução longo.
- **Mínimo:** 5 discos (idealmente arrays maiores).

### dRAID (Distributed RAID)

- **Descrição:** Variação moderna do RAIDZ que distribui spares integrados e paridade por todos os discos.
- **Vantagem:** Resilvering extremamente rápido (ordens de magnitude mais rápido que RAIDZ tradicional) pois todos os discos participam da reconstrução.
- **Uso Recomendado:** Enterprise arrays com dezenas de discos.
- **Limitação:** Complexidade de configuração; VDEVs são imutáveis (difícil expansão em algumas versões).

---

## 2. Discos Auxiliares (Special VDEVs)

Otimizam funções específicas do ZFS movendo cargas de trabalho para discos mais rápidos (SSDs/NVMe).

### L2ARC (Cache de Leitura Nível 2)

- **Função:** Extensão da RAM (ARC) em SSD. Armazena dados lidos frequentemente que não cabem na RAM.
- **Quando usar:**
  - Se a taxa de hit do ARC (RAM) estiver baixa (< 90%).
  - Se você tem muita leitura aleatória de dados "quentes".
- **Impacto:** Aumenta latência se o working set já couber na RAM (consome RAM para indexar o L2ARC).
- **Dispositivo:** SSD barato (leitura intensiva). Não precisa de redundância (se falhar, apenas perde cache).

### SLOG / ZIL (Log de Intenção de ZFS)

- **Função:** Acelera **escritas síncronas** (Bancos de dados, NFS, iSCSI/VMware).
- **Mito:** Não acelera escritas assíncronas (cópia de arquivos via SMB geralmente é assíncrona, a menos que forçado sync).
- **Segurança:** O ZIL reside no pool principal por padrão. O SLOG move isso para um dispositivo dedicado rápido.
- **Dispositivo:** SSD de altíssima resistência (Optane, Enterprise NVMe) e baixa latência. P.L.P. (Power Loss Protection) é essencial.
- **Redundância:** Recomendado Mirror (se perder o SLOG durante crash solita, perde as últimas transações).

### Special Allocation Class (Metadados)

- **Função:** Armazena metadados (lokup de arquivos) e blocos pequenos em SSDs dedicados.
- **Impacto:** Acelera drasticamente operações de `ls`, `find`, e acesso a milhões de arquivos pequenos.
- **Risco:** **CRÍTICO**. Se este VDEV falhar, **todo o pool é perdido**.
- **Redundância:** Obrigatório Mirror (mesmo nível de redundância do pool de dados).

---

## 3. Recomendações de Configuração

### Cenário 1: Fileserver Geral / SMB (Alta Capacidade)
- **Topologia:** RAIDZ2.
- **VDEV:** 6 a 10 discos por VDEV.
- **Auxiliar:** Special VDEV (Mirror SSD) se houver muitos arquivos pequenos. L2ARC se RAM for limitada (< 32GB).

### Cenário 2: Virtualização / Databases (Alto IOPS)
- **Topologia:** Mirror (Stripped Mirrors / RAID 10).
- **VDEV:** Pares de discos.
- **Auxiliar:** SLOG (Optane) obrigatório para NFS/iSCSI síncrono.

### Cenário 3: Backup Target (Write Once, Read Rarely)
- **Topologia:** RAIDZ2 ou RAIDZ3.
- **Compactação:** ZSTD-19 (máxima) ou GZIP-9.

## Checklist de Decisão (Instalador)

1. **Quantos discos você tem?**
   - 1: Stripe (Inseguro - Apenas Testes)
   - 2: Mirror
   - 3: RAIDZ1 (Risco moderado)
   - 4+: RAIDZ2 (Recomendado) ou Mirror (Performance)

2. **Qual o fluxo de trabalho?**
   - **VMS/DBs:** Use Mirror.
   - **Arquivos/Mídia:** Use RAIDZ.

3. **Auxiliares?**
   - Adicione **L2ARC** depois, se precisar.
   - Adicione **SLOG** apenas se souber que precisa (sync writes).
