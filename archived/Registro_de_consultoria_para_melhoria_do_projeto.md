<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Preciso saber se existe alguma forma de otimizar o ZFS no debian, para melhorar o desempenho, a depender do hardware que está sendo usado. Tenho a possibilidade de instalar o ZFS com debian, tanto em hardware antigo e limitado, quando em hardware modernos e com bastante recursos. Como ajustar de forma dinâmica baseado-se no hardware da máquina instada com zfs?

Sim, o ZFS pode ser otimizado de forma dinâmica no Debian ajustando parâmetros do kernel com base nas características do hardware. A principal forma de adaptação é através da configuração do ARC (Adaptive Replacement Cache) e outros tunáveis no arquivo `/etc/modprobe.d/zfs.conf`.[^1_1][^1_2]

## Configurações por Tipo de Hardware

### Hardware Limitado (2-8 GB de RAM)

Para máquinas com pouca memória, é crucial limitar o ARC para evitar que o ZFS consuma recursos excessivos:

- **ARC máximo**: Defina entre 1-2 GB para garantir estabilidade[^1_3]
- **ARC mínimo**: Configure pelo menos 512 MB (`zfs_arc_min`) para evitar que o cache caia para valores muito baixos (como 64 MB), o que prejudica a performance[^1_3]
- **Swap**: Utilize swap com `vm.swappiness=100` para compensar a falta de RAM[^1_3]

Exemplo de configuração para hardware limitado:

```bash
# /etc/modprobe.d/zfs.conf
options zfs zfs_arc_max=2147483648    # 2 GB
options zfs zfs_arc_min=536870912     # 512 MB
```


### Hardware Moderno (16+ GB de RAM)

Com mais recursos disponíveis, você pode maximizar o uso de cache:

- **ARC máximo**: Pode ser definido como 50% da RAM total, ou até 75% se o sistema for dedicado ao ZFS[^1_4][^1_5]
- **L2ARC**: Considere adicionar SSDs NVMe como cache de segundo nível[^1_4]
- **ZIL/SLOG**: Para workloads com muitas escritas síncronas, adicione dispositivos SLOG rápidos com proteção contra queda de energia[^1_6]

Exemplo para hardware robusto:

```bash
# /etc/modprobe.d/zfs.conf
options zfs zfs_arc_max=34359738368   # 32 GB em sistema com 64 GB
options zfs zfs_arc_min=8589934592    # 8 GB mínimo
options zfs zfs_dirty_data_max=8589934592
```


## Ajustes Dinâmicos Específicos

### Record Size

Ajuste o tamanho dos registros conforme o workload:[^1_7][^1_8]

- **Bancos de dados/VMs**: `recordsize=16K` ou `32K`
- **Arquivos grandes/mídia**: `recordsize=1M`
- **Uso geral**: `recordsize=128K` (padrão)


### Compressão

Ative compressão para reduzir I/O e armazenamento, especialmente em CPUs modernas:[^1_6]

```bash
zfs set compression=zstd-3 pool/dataset
```


### Outros Parâmetros Importantes

| Parâmetro | Hardware Limitado | Hardware Moderno |
| :-- | :-- | :-- |
| `zfs_prefetch_disable` | 1 (desativar) | 0 (ativar) [^1_8] |
| `atime` | `off` | `relatime` ou `off` [^1_8] |
| `xattr` | `sa` | `sa` [^1_8] |
| `sync` | `disabled` (se aceitável) | `standard` ou `always` |

## Aplicação das Configurações

Após editar `/etc/modprobe.d/zfs.conf`, recarregue o módulo:[^1_9][^1_1]

```bash
sudo update-initramfs -u
sudo modprobe -r zfs && sudo modprobe zfs
```

Para ajustes temporários sem reiniciar, modifique diretamente os parâmetros do kernel:[^1_1]

```bash
echo 2147483648 > /sys/module/zfs/parameters/zfs_arc_max
```


## Monitoramento

Utilize ferramentas para verificar a eficácia dos ajustes:[^1_10][^1_6]

- `arc_summary` — visão geral do cache ARC
- `zpool iostat -v` — estatísticas de I/O por vdev
- `arcstat` — monitoramento contínuo do ARC

Essas configurações permitem que você adapte o ZFS automaticamente através de scripts de instalação que detectam a quantidade de RAM e CPU disponíveis, aplicando os valores apropriados durante a configuração inicial do sistema.
<span style="display:none">[^1_11][^1_12][^1_13][^1_14][^1_15]</span>

<div align="center">⁂</div>

[^1_1]: https://wiki.niziak.spox.org/linux:fs:zfs:tuning

[^1_2]: https://klarasystems.com/articles/performance-tuning-arc-l2arc-slog/

[^1_3]: https://www.reddit.com/r/zfs/comments/vekogs/how_do_i_tune_zfs_for_low_ram_consumption/

[^1_4]: https://wiki.debian.org/ZFS

[^1_5]: https://forum.proxmox.com/threads/zfs-performance-tips.160991/

[^1_6]: https://www.youstable.com/blog/optimize-zfs-on-linux/

[^1_7]: https://klarasystems.com/articles/zfs-performance-tuning-optimizing-for-your-workload/

[^1_8]: https://www.reddit.com/r/zfs/comments/7l64mt/what_zol_performance_optimization_settings_do_you/

[^1_9]: https://forum.proxmox.com/threads/zfs-performance-tuning.27121/

[^1_10]: https://www.youstable.com/blog/optimize-zfs-on-linux

[^1_11]: https://www.reddit.com/r/zfs/comments/1nnwgxl/how_to_optimize_zfs_for_a_small_linux_workstation/

[^1_12]: https://forum.level1techs.com/t/zfs-guide-for-starters-and-advanced-users-concepts-pool-config-tuning-troubleshooting/196035

[^1_13]: https://news.ycombinator.com/item?id=11897571

[^1_14]: https://forum.proxmox.com/threads/zfs-tuning-high-memory.32508/

[^1_15]: https://docs.netgate.com/pfsense/en/latest/hardware/tune-zfs.html


---

# Atue como um especialista sênior em administração de sistemas Debian e desenvolva um guia abrangente de otimização de hardware focado em máxima eficiência e eficácia, aplicável tanto a equipamentos legados e limitados quanto a hardware moderno de alto desempenho. Aborde exaustivamente todas as variáveis configuráveis, incluindo parâmetros do Kernel (sysctl), escalonadores de E/S, gerenciamento de memória virtual e swap, sistema de arquivos, governors de CPU, parâmetros de inicialização e ajuste fino de serviços via systemd. Para cada variável apresentada, forneça não apenas a configuração recomendada, mas também uma metodologia detalhada de avaliação e diagnóstico, especificando quais ferramentas de monitoramento e benchmarking utilizar para medir o impacto e como interpretar esses dados para definir o valor ideal que garanta o equilíbrio perfeito entre estabilidade, throughput e latência.

A seguir está um guia abrangente, estruturado por camada, com recomendações de ajuste **para Debian**, **metodologia de avaliação** e **instrumentos de diagnóstico** para:

- hardware legado/limitado (pouca RAM, HDD, poucos núcleos);
- hardware moderno (SSD/NVMe, 16+ GB RAM, múltiplos núcleos, rede 1–10 GbE).

***

## 1. **Mindset: otimização com base em workload**

Antes de qualquer parâmetro, defina:

- **Perfil de carga**: I/O randômico (DB, VMs) ou sequencial (backup, media)?
- **Objetivo**: baixa latência, alto throughput ou consumo de CPU baixo?
- **Restrições**: RAM, disco, energia, calor.


### Etapas gerais de diagnóstico e ajuste

1. **Coletar baseline**:
    - `sar`, `iostat -x`, `vmstat`, `htop/top`, `dstat`, `iotop`.
2. **Aplicar uma mudança de cada vez**.
3. **Re‑testar** com um benchmark estável (vide seção de ferramentas).
4. **Avaliar**:
    - Latência (latência média de I/O, RTT, p99).
    - Throughput (MB/s, IOPS).
    - Estabilidade (erros de I/O, ocorrência de OOM, uso de swap).

Ferramentas de benchmark recomendadas:

- **I/O**: `fio`, `dd` (com `oflag=direct`, `bs=1M/4k`), `bonnie++`.
- **Rede**: `iperf3`, `netperf`.
- **Geral**: `phoronix-test-suite`, `sysbench` (CPU, memória, DB).

***

## 2. **Kernel: sysctl (rede, memória, geral)**

Arquivo principal: `/etc/sysctl.conf` ou `/etc/sysctl.d/99-tuning.conf`.

### a) **Rede – TCP e buffers**

Parâmetros orientativos para **servidor de rede** (ajuste conforme NIC speed):

```conf
# limites de memória e buffers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.optmem_max = 65536

net.ipv4.tcp_rmem = 4096 131072 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# fila de conexões
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 50000
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 5000

# ajuste de congestionamento
net.ipv4.tcp_congestion_control = bbr         # em kernels modernos
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_app_win = 30
```

- **Hardware legado**: reduza `net.core.rmem_max` e `tcp_rmem` para 4–8 MB para evitar saturar RAM.
- **Hardware moderno**: mantenha ou aumente ainda mais se usar links 1–10 GbE.

✅ **Diagnóstico / interpretação**:

- Use `ss -s` e `ss -i` para ver congestionamento de buffers.
- Use `netstat -s` para ver descarte de pacotes (`TcpExt: DelayedACKs`, `Pruning of TCP`).
- Use `tcpretrans` (via `bpftrace` ou `bcc`) ou `ss -i` para ver retransmissões.

Se houver aumento de retransmissões e perda de pacotes, reduza os buffers até estabilizar; se houver uso baixo de buffer e latência aceitável, aumente para ganhar throughput.

***

### b) **Memória virtual, swap e ARC (ZFS)**

```conf
# reduz uso excessivo de swap
vm.swappiness = 10            # servidores modernos; 40–60 é padrão

# limitar cache de arquivos (ZFS legado ou outros FS)
vm.vfs_cache_pressure = 50    # 100 é padrão; valores mais baixos mantêm mais cache
```

Para hardware legado com pouco RAM:

- `vm.swappiness = 40` (aceita mais swap, evita OOM).
- `vm.vfs_cache_pressure = 70–80` (cache de arquivos é largado mais rápido para liberar RAM).

Para hardware forte dedicado a ZFS:

- `vm.swappiness = 1–10` (quase não usa swap).
- `vm.vfs_cache_pressure = 30–50` (prioriza cache de arquivos / ARC).

✅ **Ferramentas**:

- `free -h`, `vmstat 1`, `slabtop` (para ARC/zfs).
- Para ZFS: `arc_summary`, `zpool iostat -v`, `zfs list -o space`.

Interpretação:

- Se `%idle` é alto mas `si`/`so` é alto: reduza `swappiness` ou aumente RAM.
- Se `%used` da ARC é alto e `freed` é baixo: o cache está funcionando bem; se `misses` são altos, aumente `zfs_arc_max` gradualmente.

***

### c) **Limites de arquivos e recursos**

```conf
fs.file-max = 2097152
fs.nr_open = 2000000

kernel.pid_max = 4194304
kernel.threads-max = 1048576
```

Para **servidores com muitas conexões** (web, proxy, DB):

- Aumente `fs.file-max` e, se necessário, `ulimit -n` para serviços.

✅ **Diagnóstico**:

- `lsof | wc -l`, `ss -s`, `ulimit -Sn`, `ulimit -Hn`.
- Se `too many open files` aparece em logs, ajuste `fs.file-max` e limite de arquivos por processo.

***

## 3. **Escalonadores de I/O (elevator)**

Verifique o atual:

```bash
cat /sys/block/sda/queue/scheduler
```

Recomendações:


| Hardware | Escalonador recomendado |
| :-- | :-- |
| HDD, armazenamento antigo | `cfq` ou `bfq` (se disponíveis) |
| HDD, servidor de arquivo | `deadline` |
| SSD/NVMe moderno | `none` (mq-deadline / noop) |

Mudar:

```bash
echo mq-deadline > /sys/block/sda/queue/scheduler
```

Para tornar permanente (Debian):

- Em `/etc/rc.local` ou script de inicialização, ou via `udev`:

```bash
# /etc/udev/rules.d/60-scheduler.rules
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="mq-deadline"
```

✅ **Diagnóstico**:

- `iostat -x 1`:
    - `await` e `svctm` baixos → boa resposta.
    - `util` perto de 100% com `await` alto → contensão de I/O.
- Se mudar o escalonador e `await` cair com mesmo workload, a escolha é correta.

***

## 4. **Governor de CPU**

Verifique o atual:

```bash
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do cat "$f"; done
```

Recomendações:

- **Servidor 24/7, workload pesado**: `performance`.
- **Bastidores, rack, baixo consumo**: `powersave`.
- **Desktop / uso misto**: `schedutil` (padrão moderno).

Mudar:

```bash
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance > "$f"
done
```

Para tornar permanente:

- Em `/etc/default/cpufrequtils` (se usar o pacote `cpufrequtils`):

```conf
ENABLE=true
GOVERNOR="performance"
```

ou em sistemas systemd:

- `cpupower` / `tuned` (em distros que usam `tuned`).

✅ **Diagnóstio**:

- Use `mpstat -P ALL 1` ou `sar -P ALL 1` para ver `%idle`, `%iowait`, `%user`.
- Se `%idle` estiver alto e você quer mais desempenho de CPU, use `performance`; se quer baixo consumo, use `powersave` ou `ondemand`.

***

## 5. **Sistema de arquivos (ext4, XFS, Btrfs, ZFS)**

### a) **Escolha geral (Debian)**

- **ext4**: bom padrão para root, baixa latência, simples.
- **XFS**: melhor para volumes grandes e throughput (media, arquivos grandes).
- **Btrfs**: snapshots, cmpressão, subvolumes, bom para desktop/server misto.
- **ZFS**: melhor para storage dedicado, alta confiabilidade, mas custo de RAM.


### b) **Otimização de montagem**

Exemplos de `/etc/fstab`:

**ext4 (servidor legado)**:

```fstab
UUID=... / ext4 defaults,discard,relatime,commit=30,noatime 0 1
```

**ext4 (servidor moderno)**:

```fstab
UUID=... / ext4 defaults,discard,relatime,commit=10 0 1
```

**XFS (volume de dados)**:

```fstab
UUID=... /data xfs defaults,largeio,inode64 0 2
```

**Btrfs (desktop / servidor misto)**:

```fstab
UUID=... / btrfs defaults,compress=zstd:3,space_cache=v2,ssd 0 0
```

Para ZFS:

```bash
# no create da pool
zpool create -o ashift=12 tank mirror /dev/sda /dev/sdb

# nas datasets
zfs set primarycache=all pool/dataset
zfs set secondarycache=all pool/dataset
zfs set recordsize=16K pool/dataset   # para DB
zfs set compression=zstd-3 pool/dataset
```

✅ **Diagnóstico**:

- Use `iostat -x 1` para ver latência (`await`, `svctm`) e `%util`.
- Use `fio` para comparar `bs=4k` (randômico) e `bs=1M` (sequencial).
- Use `zpool iostat -v` e `zfs get recordsize` para validar configuração.

***

## 6. **Parâmetros de inicialização do kernel**

Linux usa `GRUB`; ajuste em `/etc/default/grub`:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
```

Possíveis ajustes:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_pstate=enable elevator=mq-deadline"
```

Para sistemas com muitos núcleos, alguns parâmetros:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_pstate=enable isolcpus=1,2,3,4"
```

(guarda núcleos para tasks em tempo real, se usar aplicações específicas).

Depois:

```bash
sudo update-grub
```

✅ **Diagnóstico**:

- `dmesg` para ver se parâmetros foram aplicados.
- `cat /proc/cmdline` para confirmar.

***

## 7. **Ajuste fino de serviços via systemd**

Crie um `drop‑in` para limitar recursos:

```bash
sudo systemctl edit nginx.service
```

Conteúdo de `/etc/systemd/system/nginx.service.d/override.conf`:

```ini
[Service]
CPUQuota=80%
MemoryMax=2G
MemoryHigh=1G
MemorySwapMax=500M
IOWeight=80
TasksMax=1000
```

Valores típicos:

- `MemoryMax`: limite rígido.
- `MemoryHigh`: “soft limit” antes de forte pressão.
- `MemorySwapMax=0` para serviços críticos que não devem ir para swap.
- `CPUQuota` para evitar que um serviço monopólie CPU.

✅ **Diagnóstico**:

- `systemctl show nginx.service | grep -i memory`
- `systemd-cgtop` ou `htop` para ver uso de memória/CPU.

Ajuste conforme logs OOM (`dmesg | grep -i oom`) e `journalctl -u nginx`.

***

## 8. **Metodologia completa de ajuste por cenário**

### Cenário 1: Servidor de arquivo legado (HDD, 2–4 GB RAM)

**Objetivo**: baixa latência, evitar OOM, estabilidade.

1. Use `deadline` como escalonador.
2. `vm.swappiness = 40`, `vm.vfs_cache_pressure = 70`.
3. `sysctl` de rede moderado (buffers menores).
4. `noatime` e `relatime` em `ext4` ou `XFS`.
5. `CPU governor = powersave` se consumir pouco CPU.
6. Limite de serviços via `systemd` para não explodir memória.

**Benchmark**:

- `fio` com `bs=4k`, `bs=1M` e `iodepth=1..32`.
- `iostat -x` em paralelo.

Se `await` cai sem aumentar `util` além de 90%, a configuração é boa.

***

### Cenário 2: Servidor de banco de dados moderno (NVMe, 16+ GB RAM)

**Objetivo**: baixa latência de I/O, máximo throughput.

1. `mq-deadline` ou `none` (dependendo do subsistema).
2. `vm.swappiness = 10`, `vm.vfs_cache_pressure = 30`.
3. `sysctl` de rede agressivo (buffers grandes, `bbr`).
4. `ext4` ou `XFS` com `noatime`, `relatime`, `barrier=0` (se SSD/NVMe confiável).
5. `performance` como governor de CPU.
6. Serviço de DB via `systemd` com `MemoryMax` próximo ao limite real.

**Benchmark**:

- `sysbench fileio` ou `fio` com perfil DB (`rw=randrw`).
- `sysbench oltp` para PostgreSQL/MySQL.

Analise latência p99 de I/O e queries; se ambos melhorarem sem OOM, a configuração é boa.

***

## 9. **Como automatizar o “ajuste dinâmico” por hardware**

Você pode criar um script de provisionamento que:

1. Detecte:
    - RAM total (`free -m` ou `/proc/meminfo`).
    - tipo de disco (`lsblk -d -o NAME,ROTA,TRAN`).
    - CPU (`lscpu`).
2. Escolha:
    - escalonador de I/O;
    - valores de `vm.swappiness` / `vfs_cache_pressure`;
    - `zfs_arc_max` / `zfs_arc_min`;
    - `sysctl` agressivo ou moderado.
3. Gere `/etc/sysctl.d/99-hardware-tuning.conf`, `udev` para I/O, `systemd` para serviços.

Exemplo de lógica pseudo‑bash:

```bash
if [ $(free -m | awk '/^Mem:/ {print $2}') -lt 8192 ]; then
  echo "vm.swappiness = 40" > /etc/sysctl.d/99-hardware-tuning.conf
  echo "zfs_arc_max = 2147483648" >> /etc/sysctl.d/99-hardware-tuning.conf
else
  echo "vm.swappiness = 10" > /etc/sysctl.d/99-hardware-tuning.conf
  echo "zfs_arc_max = 8589934592" >> /etc/sysctl.d/99-hardware-tuning.conf
fi
```


***

## 10. **Resumo de ferramentas de monitoramento**

| Categoria | Ferramenta(s) recomendadas |
| :-- | :-- |
| CPU | `top`, `htop`, `mpstat`, `sar` |
| Memória | `free`, `vmstat`, `slabtop`, `arc_summary` |
| I/O | `iostat -x`, `iostat -d`, `iotop`, `dstat`, `blktrace` |
| Rede | `ss`, `netstat`, `ss`, `netstat -s`, `iperf3`, `bpftrace` |
| Serviços | `systemd-cgtop`, `systemctl status`, `journalctl` |
| Benchmark I/O | `fio`, `bonnie++`, `dbench` |
| Benchmark DB | `sysbench` (MySQL/PG), `pgbench` |


***

Se você quiser, na próxima resposta posso montar um **script de diagnóstico + tuning** para Debian que:

- identifica automaticamente HDD/SSD, RAM, CPU,
- aplica configurações de `sysctl`, escalonador, governors, swap e ZFS,
- e executa um
<span style="display:none">[^2_1][^2_10][^2_11][^2_12][^2_13][^2_14][^2_15][^2_16][^2_17][^2_18][^2_19][^2_2][^2_20][^2_21][^2_22][^2_23][^2_24][^2_25][^2_26][^2_27][^2_28][^2_29][^2_3][^2_30][^2_4][^2_5][^2_6][^2_7][^2_8][^2_9]</span>

<div align="center">⁂</div>

[^2_1]: https://sempreupdate.com.br/sysctl-conf-linux-otimizacao-desempenho-rede/

[^2_2]: https://docs.redhat.com/pt/documentation/red_hat_enterprise_linux/8/html/system_design_guide/configuring-kernel-parameters-permanently-with-sysctl_setting-kernel-parameters-at-runtime

[^2_3]: https://helpsysadmin.com.br/blog/guia-definitivo-sysctl-conf-performance/

[^2_4]: https://expressvps.com.br/guia-para-otimizacao-de-desempenho-em-servidores-linux/

[^2_5]: https://nerdexpert.com.br/tuning-de-rede-no-linux-otimizacao-de-throughput-com-sysctl-e-ethtool/

[^2_6]: https://www.kelvinsantiago.com.br/como-adicionar-swap-no-ubuntudebian/

[^2_7]: https://janssenlima.blogspot.com/2012/10/escalonamento-de-io-no-gnulinux.html

[^2_8]: https://www.shpv.fr/blog/sysctl-optimisation/

[^2_9]: https://plus.diolinux.com.br/t/swap-como-posso-fazer/68495

[^2_10]: https://wiki.archlinux.org/title/Improving_performance_(Portugu%C3%AAs)

[^2_11]: https://gist.github.com/Esl1h/65c0d67780ee6212ebce00efe76d6007

[^2_12]: https://plus.diolinux.com.br/t/reduzir-o-uso-da-swap-e-ajuste-do-cache-pressure/43865

[^2_13]: https://nerdexpert.com.br/otimizacao-de-i-o-e-rede-no-kernel-linux-tecnicas-avancadas-para-maximo-desempenho/

[^2_14]: https://www.youtube.com/watch?v=ybHP3OjpAbY

[^2_15]: https://www.debian.org/releases/stable/amd64/ch06s03.pt.html

[^2_16]: https://www.reddit.com/r/linux/comments/1kja0jy/bcachefs_btrfs_ext4_f2fs_xfs_filesystem/

[^2_17]: https://linuxcommunity.io/t/benchmarking-linux-filesystems-zfs-xfs-btrfs-vs-ext4/6405

[^2_18]: https://www.youtube.com/watch?v=KtkhoVj3hnk

[^2_19]: https://eagleeyet.net/blog/operating-systems/linux/file-systems/ext4-vs-btrfs-vs-xfs-vs-zfs-a-linux-file-system-comparison-for-beginners/

[^2_20]: https://www.it-server-room.com/en/linux-filesystem-comparison-ext4-xfs-zfs/

[^2_21]: https://blog.theravenhub.com/post/ht-limit-service-ressources-systemd

[^2_22]: https://documentation.ubuntu.com/real-time/latest/how-to/modify-kernel-boot-parameters/

[^2_23]: https://www.reddit.com/r/debian/comments/1lvfy36/xfs_or_ext4_as_preferred_filesystem_on_debian_in/

[^2_24]: https://aorith.github.io/posts/systemd-limits/

[^2_25]: https://www.linuxjournal.com/content/how-optimize-your-linux-kernel-custom-parameters

[^2_26]: https://www.youtube.com/watch?v=_fkxBD2L61c

[^2_27]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/resource_management_guide/sec-modifying_control_groups

[^2_28]: https://www.kernel.org/doc/html/v4.14/admin-guide/kernel-parameters.html

[^2_29]: https://www.dimoulis.net/posts/benchmark-of-postgresql-with-ext4-xfs-btrfs-zfs/

[^2_30]: https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html


---

# Atue como um especialista sênior em administração de sistemas Debian e desenvolva um guia abrangente de otimização de hardware focado em máxima eficiência e eficácia, aplicável tanto a equipamentos legados e limitados quanto a hardware moderno de alto desempenho. Aborde exaustivamente todas as variáveis configuráveis, incluindo parâmetros do Kernel (sysctl), escalonadores de E/S, gerenciamento de memória virtual e swap, sistema de arquivos, governors de CPU, parâmetros de inicialização e ajuste fino de serviços via systemd. Para cada variável apresentada, forneça não apenas a configuração recomendada, mas também uma metodologia detalhada de avaliação e diagnóstico, especificando quais ferramentas de monitoramento e benchmarking utilizar para medir o impacto e como interpretar esses dados para definir o valor ideal que garanta o equilíbrio perfeito entre estabilidade, throughput e latência. Contudo, considere o uso do ZFSBootMenu como padrão e do Syslinux em computadores sem UEFI, no lugar do Grub, o Syslinux será usado apenas como modo de compatibilidade, pois ele entregará a responsabilidade da gestão de boot imediatamente após conseguir iniciar, sendo utilizado de maneira transparente, preferencialmente nem deve ser notado sua presença. A intenção é utilizar ao máximo os recursos avançados do ZFSBootMenu.

Você consegue otimizar o Debian “por hardware” criando perfis de tuning (legado vs moderno) e aplicando-os automaticamente no boot/instalação, medindo impacto com um conjunto fixo de métricas (latência, throughput, pressão de memória) e ajustando iterativamente. Com ZFSBootMenu como padrão, o foco muda: você ajusta kernel/ZFS/serviços para o *runtime*, e o bootloader (UEFI ou Syslinux legado) só precisa entregar o kernel+initramfs do ZFSBootMenu e passar uma linha de comando correta.[^3_1][^3_2]

## Arquitetura de boot (ZFSBootMenu + Syslinux legado)

ZFSBootMenu constrói uma imagem baseada em um kernel Linux e um initramfs próprio; em UEFI costuma ser inicializável diretamente (EFI stub) ou via um boot manager, e em BIOS legado os componentes também podem ser iniciados por um bootloader BIOS comum como o syslinux.[^3_2][^3_1]
A recomendação prática é: **UEFI** → inicializar o ZFSBootMenu diretamente; **BIOS legado** → Syslinux apenas “carrega e entrega” o ZFSBootMenu (kernel+initramfs) e some do caminho.[^3_1][^3_2]

### Opções essenciais do ZFSBootMenu (linha de comando)

- `zbm.prefer=<pool>`: define o pool preferido a ser importado, e é o principal parâmetro para evitar detecção ambígua em máquinas com múltiplos pools.[^3_1]
- `zbm.show` e `zbm.skip`: você pode ter entradas “menu” e “boot direto” para operação normal e recuperação, respectivamente.[^3_1]
- `zbm.set_hostid`: por padrão, o ZFSBootMenu tenta ajustar o `spl.spl_hostid` do ambiente bootado para corresponder ao hostid usado na importação do pool, reduzindo problemas de importação ao mover discos entre hosts.[^3_3]


### Hostid e importação de pool (ponto crítico de estabilidade)

O ZFS/SPL usa hostid para decidir se um pool “pertence” ao host que está importando; em ambientes com initramfs via dracut, é possível sobrescrever isso com o parâmetro `spl_hostid=0x...`, e mudanças de hostid podem tornar o pool não importável sem procedimentos de recuperação.[^3_4]
O ZFSBootMenu documenta políticas e opções relacionadas a adoção de hostid e importações forçadas; trate isso como “segurança operacional” antes de qualquer tuning de performance.[^3_3]

### Dracut e isolamento de configuração do ZFSBootMenu

Se você gera a imagem do ZFSBootMenu com dracut, a documentação alerta para não reutilizar o mesmo diretório de `dracut.conf.d` do sistema, porque configurações de dracut do host podem interferir na criação do initramfs do ZFSBootMenu.[^3_5]

## Método de otimização (como evitar tuning “cego”)

Otimização que busca equilíbrio entre estabilidade, throughput e latência precisa de um ciclo fixo: baseline → mudança única → re-teste → decisão com critérios.
Use sempre os mesmos “testes mínimos” por camada (CPU, memória, disco, rede e aplicação), e grave resultados com horário e versão do kernel/ZFS para comparar.

Ferramentas base (Debian):

- Telemetria: `sar`/`pidstat` (sysstat), `vmstat`, `iostat -x`, `mpstat`, `ss`, `perf` (quando necessário).
- I/O: `fio` (principal), `zpool iostat -v` (ZFS), `blktrace/bpftrace` (quando precisar ir fundo).
- Serviços: `systemd-cgtop`, `systemctl show`, `journalctl`.

Interpretação “mínima viável”:

- Latência de disco: `iostat -x` → `await` e `%util`.
- Pressão de memória: `vmstat` → `si/so` (swap in/out) e `r` (run queue).
- Gargalo de CPU vs I/O: `mpstat` → `%iowait` alto sugere espera por disco; `%user/%sys` altos sugerem CPU.


## Kernel: parâmetros de boot (Syslinux/UEFI) e módulo

O kernel aceita parâmetros via linha de comando e também via `modprobe`, e parâmetros de módulos carregáveis podem ser observados/ajustados em `/sys/module/<modulo>/parameters/` (alguns em runtime).[^3_6]
Isso importa porque parte do tuning (ZFS/SPL, I/O, CPU isolation etc.) é mais estável quando fixado na linha de comando entregue pelo ZFSBootMenu/bootloader, e parte é melhor em sysctl/systemd para ajustes fáceis.[^3_6][^3_1]

### Metodologia (boot params)

1. Confirme a linha de comando real: `cat /proc/cmdline`.
2. Valide efeito: `dmesg -T | grep -E 'Command line|zfs|spl'` e arquivos em `/sys/module/.../parameters`. [^3_6]
3. Só então meça performance (fio/aplicação), porque parâmetros errados podem gerar “melhora” aparente com risco (ex.: importações forçadas).

## Sysctl (kernel runtime): rede, VM e FS

O sysctl é o lugar para tuning “de operação” que você quer aplicar por perfil sem mexer no bootloader.
No Debian, prefira arquivos em `/etc/sysctl.d/*.conf` por perfil (ex.: `10-legacy.conf`, `20-modern.conf`) e um seletor que habilita um link simbólico para o perfil.

### VM/memória (virtual memory)

O `vm.vfs_cache_pressure` controla a tendência do kernel em recuperar caches de dentries/inodes vs page cache; aumentar recupera VFS cache mais agressivamente, reduzir mantém mais esses caches em RAM.[^3_7]
A documentação do kernel reúne os sysctls do diretório `/proc/sys/vm` e é a referência para significado/efeitos colaterais.[^3_8]

Recomendações por classe (ponto de partida):

- Legado (pouca RAM): `vm.swappiness` mais alto (tolerar swap para evitar OOM), `vm.vfs_cache_pressure` mais alto (liberar caches mais cedo).
- Moderno (muita RAM, baixa latência): `vm.swappiness` baixo, `vm.vfs_cache_pressure` baixo/moderado.

Diagnóstico (como decidir valor ideal):

- Se `vmstat 1` mostra `si/so` frequentes e a latência da aplicação piora, você está “pagando” swap; reduza `swappiness` (se houver RAM) ou diminua consumo/ARC.
- Se `slabtop` mostra caches (dentry/inode) dominando e a aplicação sofre por falta de memória, aumente `vfs_cache_pressure`.
- Se o workload é “muitos arquivos pequenos” (git, maildir, etc.), manter VFS cache pode reduzir latência; reduza `vfs_cache_pressure` e valide com `perf stat`/tempo de operação.


### Rede (quando relevante)

Tuning de rede só faz sentido se seu gargalo é rede (backup via NFS/SMB, replicação ZFS, tráfego leste-oeste).
Metodologia: `iperf3` para throughput/CPU, `ss -i` e `netstat -s` para retransmissões/erros, e compare p95/p99 de latência da aplicação antes/depois.

## Escalonadores de E/S (I/O scheduler)

O kernel permite trocar o escalonador por dispositivo “on the fly” e os nomes comuns no stack atual incluem `mq-deadline`, `none`, `bfq` e outros, com impacto potencial em throughput/latência por tipo de dispositivo e workload.[^3_9]
Guias de referência geralmente recomendam `none` para SSD/NVMe e `mq-deadline` para discos rotacionais em muitos cenários, e o `bfq` aparece como opção voltada a interatividade/desktop.[^3_10][^3_11][^3_12]

Configuração/diagnóstico:

- Ver o atual: `cat /sys/block/<dev>/queue/scheduler`.[^3_12]
- Trocar em runtime: `echo mq-deadline > /sys/block/<dev>/queue/scheduler` (ou `none`/`bfq`).[^3_12][^3_9]
- Medir: `iostat -x 1` durante um `fio` representativo (mesmos arquivos, mesmo `iodepth`, mesma duração).

Como interpretar:

- Se `await` cai e o throughput se mantém (ou sobe) sem aumentar `%util` a ponto de “colar” em 100%, a troca ajudou.
- Se o throughput sobe mas a latência (principalmente p99 no `fio --output-format=json`) piora, você trocou “eficácia” (throughput) por “eficiência de resposta”; escolha conforme SLA.


## ZFS: variáveis que mais mudam performance

ZFS tem dezenas de knobs; na prática, poucos movem a agulha de forma previsível dependendo do hardware.

Prioridades:

- ARC (consumo de RAM vs cache hit rate).
- `recordsize` por dataset (alinha com I/O real).
- compressão (CPU vs I/O).
- layout e vdevs (não é “tuning”, é arquitetura).


### ARC e RAM (perfil dinâmico)

Estratégia por hardware:

- Legado: limitar ARC para não competir com processos; medir `arc_summary` (hit ratio) e `vmstat` (swap).
- Moderno: permitir ARC maior; medir se o hit ratio aumenta e se a latência de leitura cai em workload real.

Regra de ouro de diagnóstico:

- Se o sistema entra em swap sob carga, você precisa reduzir ARC/consumo, ou aumentar RAM; “otimizar sysctl” não compensa thrash.
- Se o hit ratio é baixo e o disco está ocupado, aumentar ARC pode melhorar latência/throughput — desde que não induza swap.


### Recordsize e sync

Metodologia:

- Crie 2 datasets idênticos, varie apenas `recordsize` (ex.: 16K vs 128K vs 1M), rode `fio` com padrão semelhante ao real (randread/randwrite, iodepth, blocksize), e compare p50/p95/p99.
- Para cargas com escrita síncrona (DB/VM com fsync), avalie SLOG; sem isso, mexer em `sync` pode “melhorar” números com custo de integridade (decisão de risco, não só técnica).


## Serviços e systemd: eficiência por limites e isolamento

No systemd, você pode limitar CPU, memória e I/O por unidade com as diretivas de controle de recursos, incluindo `CPUQuota=` e `IOWeight=`.[^3_13]
A documentação (manpage) deixa claro que `CPUQuota=` é uma porcentagem do tempo de CPU disponível em **um** CPU (e valores >100% equivalem a mais de um core), e que configurações de memória como limite máximo são parte do mesmo conjunto.[^3_14]

Recomendações práticas:

- Serviços “best-effort” (indexadores, backups) → limite CPU/I/O para proteger latência dos serviços críticos.
- Serviços críticos (DB, NFS/SMB, hypervisor) → preferir “proteções” (MemoryLow/High) e evitar swap (`MemorySwapMax=0`) quando a latência é requisito.

Metodologia:

1. Aplique override com `systemctl edit <serviço>`.
2. Monitore `systemd-cgtop` e `systemctl show -p CPUUsageNSec,MemoryCurrent,IOReadBytes,IOWriteBytes`.
3. Se houver OOM kills, aumente `MemoryMax` ou reduza concorrência/threads; valide em log com `journalctl`.

## Parâmetros “por classe de hardware” (perfis)

A forma mais robusta de “ajustar dinamicamente” é escolher perfis por heurísticas simples e auditáveis:

Detecção (inventário):

- RAM total: `/proc/meminfo`
- Tipo de disco: `lsblk -d -o NAME,ROTA,MODEL`
- CPU: `lscpu`
- ZFS pool: `zpool status`, `zpool get ashift`

Perfis sugeridos:

- `legacy-min`: 2–8 GB RAM, HDD/SSD SATA antigo, CPU fraca.
- `balanced`: 8–32 GB RAM, SSD, uso geral.
- `modern-perf`: 32+ GB RAM, NVMe, cargas intensas.

Aplicação:

- sysctl: habilitar arquivo do perfil em `/etc/sysctl.d/`
- I/O scheduler: udev rule por `ROTA==1` (HDD) vs `ROTA==0` (SSD)
- systemd: drop-ins para serviços “ruins vizinhos”
- ZFS: `zfs set` por dataset (não “pool inteiro” sem necessidade)


## Como validar “perfeito equilíbrio” (critérios)

Defina limites e aceite que não existe um único ponto ótimo para tudo:

- Estabilidade: zero OOM, zero “pool import falha”, zero erros de I/O.
- Throughput: MB/s/IOPS mínimo esperado em fio e no app.
- Latência: p95/p99 sob carga (fio e latência de requisição do serviço).

Só aceite tuning que melhora sua métrica-alvo **sem** piorar outra acima do seu limite (ex.: +10% throughput aceito se p99 não piorar mais que 5%).

***

Para eu te entregar um conjunto de perfis prontos (legacy/balanced/modern) + um script que detecta hardware e gera sysctl/udev/systemd/ZFS automaticamente, qual é o workload principal desse Debian com ZFS (NAS via SMB/NFS, host de VMs/containers, banco de dados, backup/replicação, ou desktop)?
<span style="display:none">[^3_15][^3_16][^3_17][^3_18][^3_19][^3_20][^3_21][^3_22][^3_23][^3_24][^3_25][^3_26][^3_27][^3_28][^3_29][^3_30]</span>

<div align="center">⁂</div>

[^3_1]: https://docs.zfsbootmenu.org/en/v2.3.x/general/uefi-booting.html

[^3_2]: https://docs.zfsbootmenu.org/en/v2.3.x/general/binary-releases.html

[^3_3]: https://docs.zfsbootmenu.org/en/v2.3.x/man/zfsbootmenu.7.html

[^3_4]: https://github.com/ubuntu/zfs/blob/master/contrib/dracut/README.dracut.markdown

[^3_5]: https://docs.zfsbootmenu.org/en/v2.3.x/man/generate-zbm.5.html

[^3_6]: https://www.kernel.org/doc/html/v4.14/admin-guide/kernel-parameters.html

[^3_7]: https://bbs.archlinux.org/viewtopic.php?id=184655

[^3_8]: https://docs.kernel.org/admin-guide/sysctl/vm.html

[^3_9]: https://docs.kernel.org/block/switching-sched.html

[^3_10]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/setting-the-disk-scheduler_monitoring-and-managing-system-status-and-performance

[^3_11]: https://docs.oracle.com/en/database/oracle/oracle-database/26/cwlin/setting-the-disk-io-scheduler-on-linux-8.html

[^3_12]: https://pve.proxmox.com/wiki/IO_Scheduler

[^3_13]: https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html

[^3_14]: https://manpages.ubuntu.com/manpages/jammy/man5/systemd.resource-control.5.html

[^3_15]: https://documentation.suse.com/pt-br/sled/15-SP6/html/SLED-all/cha-tuning-io.html

[^3_16]: https://access.redhat.com/solutions/5427

[^3_17]: https://prime-stake-pool.gitbook.io/node-setup-guide/server-setup-basics/linux-swap-space/kernel-cache-pressure-and-swappiness

[^3_18]: https://docs.kernel.org/admin-guide/kernel-parameters.html

[^3_19]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/managing_storage_devices/setting-the-disk-scheduler_managing-storage-devices

[^3_20]: https://wiki.archlinux.org/title/Kernel_parameters

[^3_21]: https://docs.oracle.com/cd/F19136_01/cwlin/setting-the-disk-io-scheduler-on-linux-8.html

[^3_22]: https://docs.gluster.org/en/main/Administrator-Guide/Linux-Kernel-Tuning/

[^3_23]: https://man.voidlinux.org/zfsbootmenu

[^3_24]: https://github.com/zbm-dev/zfsbootmenu/wiki/

[^3_25]: https://x.com/PrabirShrestha/status/1496006392771190788

[^3_26]: https://blog.theravenhub.com/post/ht-limit-service-ressources-systemd

[^3_27]: https://www.reddit.com/r/zfs/comments/dyagft/zfs_boot_menu_ready_for_testing/

[^3_28]: https://www.reddit.com/r/archlinux/comments/3fj3cr/question_can_a_legacy_bios_install_of_syslinux/

[^3_29]: https://www.reddit.com/r/zfs/comments/18b7w2m/zfsbootmenu_no_boot_environments_with_kernels/

[^3_30]: https://www.reddit.com/r/zfs/comments/vmqw63/announcing_zfsbootmenu_200/


---

# O foco será servidor de arquivos (NAS via SAMBA) com ZFS, será uma tentativa de reproduzir num Debian puro a compatibilidade avançada conquistada pelo Truenas SCALE. Será usado em ambiente corporativo com muitos usuários fazendo uso. A intenção do projeto é tornar o Debian o mais compatível com o Windows possível, oferecendo armazenamento via pasta compartilhada de alta velocidade e estabilidade. Utilizarei sobre servidores com controladoras RAID que não permitem entrega direta dos discos (JBOD/NONRAID). Por isso, para manter tudo seguro, já conhecendo das limitações e recomendações sobre o não uso de ZFS sobre controladoras RAID, pretendo criar um sistema de replicação usando DRBD, Pacemaker e Corosync, para replicação dos dados do servidor físico para uma máquina virtual, na intenção de torná-la uma redundância que será ativada caso o servidor físico passe por alguma indisponibilidade. Avalie quais são as otimizações que precisam ser aplicadas considerando essas soluções nesse cenário. Principalmente relacionadas com a combinação dessas tecnologias, como sincronização de tamanhos de blocos de disco, bem como qualquer outra configuração que garanta desempenho e estabilidade para esse cenário.

Para esse cenário (NAS corporativo via Samba sobre ZFS, rodando em cima de controladora RAID “fechada”, com redundância por DRBD+Pacemaker+Corosync para uma VM), as otimizações mais importantes não são “sysctl mágicos”, e sim: **(1)** alinhar corretamente tamanhos de bloco entre camadas, **(2)** reduzir custo de metadados/ACL para Windows (xattrs/ACL), **(3)** garantir sem falhas o fluxo HA (fencing/STONITH, ordem de subida/descida) e **(4)** evitar armadilhas de stack ZFS↔DRBD que podem causar travamentos em falhas reais.

## Arquitetura recomendada (para sua pilha)

O desenho mais controlável (e mais comum quando você *precisa* de DRBD) é: **RAID (controladora)** → **DRBD** → **ZFS (pool)** → **Samba**.
Esse empilhamento é delicado: há relatos de que “ZFS em cima de DRBD” pode travar de forma severa em certas falhas de I/O se o DRBD não propagar corretamente o erro para o ZFS, exigindo tratamento específico de `on-io-error` (detectar e *detach* do recurso em ambos os peers para o ZFS conseguir FAULT/seguir).[^4_1]

Se você insistir em HA por DRBD+Pacemaker, assuma desde o projeto que será **ativo-passivo** (apenas 1 primário exportando SMB), e que o HA precisa mandar no ciclo: DRBD Primary → import do pool → mount → start do Samba, e o inverso para parar.

## HA (DRBD + Pacemaker/Corosync): estabilidade primeiro

Sem fencing/STONITH “de verdade”, DRBD em cluster vira risco direto de split-brain, e o próprio ecossistema Pacemaker/DRBD é explícito que você precisa de STONITH funcional e integração de fencing (ex.: `crm-fence-peer.sh`) para o nó sobrevivente ter certeza de que o outro não pode permanecer Primary.[^4_2]
Minha recomendação prática é tratar fencing como requisito de aceite do projeto (testes de cabo de rede, reboot forçado, perda de storage, etc.), porque “otimização de desempenho” não compensa corrupção por split-brain.

### Evite auto-import do pool no boot (quando HA controla)

Se o HA (Pacemaker) é quem decide quando importar/exportar o pool, evite que serviços padrão tentem importar automaticamente durante boot; um método citado é criar o pool com `cachefile` fora do caminho padrão usado por import automático, para não ocorrer import indevido antes do cluster decidir.[^4_1]
Isso também simplifica o papel do ZFSBootMenu: ele cuida do boot do sistema, e o *data pool* fica sob controle do cluster.

## Alinhamento de blocos (RAID ↔ DRBD ↔ ZFS): onde ganha ou perde tudo

### ZFS: `ashift` (setar uma vez, para sempre)

No ZFS, `ashift` define o alinhamento mínimo de bloco; em stacks com DRBD, há uma recomendação prática de usar DRBD “sync unit” de 4 KiB e ZFS `ashift=12` (4 KiB) para alinhar bitmap de mudança do DRBD com o menor bloco do ZFS.[^4_1]
Em controladoras RAID que expõem um LUN “mentiroso” (512e/4kn por trás), `ashift=12` costuma ser o “seguro” para evitar write amplification por desalinhamento (e você valida por benchmark).

**Metodologia para decidir**:

- Confirme o que o SO enxerga: `lsblk -t`, `cat /sys/block/<dev>/queue/{logical_block_size,physical_block_size}`.
- Rode `fio` com escrita aleatória 4k e 16k no block device (antes de produzir dados) e compare latência p95/p99 e IOPS.
- Se 4k randwrite tiver latência “serrilhada” e throughput baixo sem CPU alta, suspeite desalinhamento.


### DRBD: unidade de sincronização / bitmap

A experiência relatada no empilhamento ZFS-on-DRBD usa “synchronization unit” de 4 KiB justamente para casar com `ashift=12` e ter granularidade de resync eficiente.[^4_1]
Se você desalinha (ex.: DRBD marca mudanças em granularidade diferente do menor bloco do ZFS), pode aumentar resync e amplificação de escrita.

### Se você usar ZVOL (evite, mas se precisar)

Se alguma parte do desenho acabar usando ZVOL (por exemplo, export iSCSI interno, ou backing store), ajuste `volblocksize` **na criação**: o manual ressalta que `volblocksize` não pode ser alterado depois que o volume recebe escrita, e o padrão é 8K, com potências de 2 entre 512B e 128K .
ZVOL + DRBD normalmente aumenta complexidade (TRIM/space accounting, camadas extras), então para file server via SMB eu tentaria manter datasets (filesystem) e não ZVOL.

## ZFS para Samba/Windows: propriedades que realmente importam

Em ambiente corporativo com muitos usuários, SMB costuma ser pesado em **metadados + ACL + xattr** (listar diretórios grandes, checar permissões, atributos DOS, etc.). Aqui estão as propriedades que mais impactam.

### ACL e xattrs (o “pulo do gato”)

- `acltype=posixacl`: habilita ACL POSIX em Linux .
- `xattr=sa`: o manual do ZFS recomenda fortemente `xattr=sa` para melhor performance ao usar `posixacl`, pois armazena xattrs/ACL de forma mais eficiente e reduz I/O de disco; também descreve que `xattr=sa` guarda até 64K por arquivo na área de system attributes, com fallback para xattr em diretório se faltar espaço .

**Como medir/validar ganho**:

- Benchmark “real” de SMB: no Windows, use `diskspd` e também testes de enumerar diretórios (pasta com muitos arquivos pequenos); no Linux, use `smbclient`/cópia massiva e observe tempo de `dir`.
- Em paralelo, monitore: `iostat -x 1` (latência), `zpool iostat -v 1` (vdev busy), e `perf top` para ver se o gargalo migra de I/O para CPU.


### Mapeamento de ACL NTFS: `vfs_acl_xattr`

Para compatibilidade com Windows ACL (mais fiel que “traduzir” tudo para POSIX), o módulo Samba `vfs_acl_xattr` armazena ACLs NT no xattr `security.NTACL` e permite “full mapping” de ACL Windows mesmo se a implementação de ACL local não for suficiente.[^4_3]
A própria documentação do `vfs_acl_xattr` aponta a opção `acl_xattr:ignore system acls`; quando `yes`, o Samba deixa de fazer o “best effort mapping” com ACLs do sistema e pode melhorar compatibilidade para ambientes acessados somente via Samba.[^4_3]

**Metodologia**:

- Valide consistência com Windows: aplique ACL complexa (herança, grupos) e leia de volta; compare antes/depois.
- Valide no Linux: `getfattr -n security.NTACL <arquivo>` (o manpage orienta que você precisa pedir explicitamente esse nome).[^4_3]


### `primarycache` e desempenho de Samba

Evite `primarycache=metadata` para datasets servidos por Samba: há um issue antigo relatando “muito baixa performance” de Samba com `primarycache=metadata`.[^4_4]
Para file server, comece com `primarycache=all` e só restrinja cache se sua RAM for insuficiente (e mesmo assim valide com carga real).

### `recordsize`: não “otimize por reflexo”

O manual avisa que mudar `recordsize` em filesystem de uso geral é fortemente desencorajado e pode piorar desempenho, e que ele é mais indicado em casos específicos como bases que leem pedaços pequenos de arquivos grandes .
Para SMB corporativo (mix de arquivos), minha prática é manter `recordsize=128K` na maioria dos shares e só separar datasets “mídia/backup” (grandes sequenciais) se o seu benchmark indicar ganho claro.

**Como decidir com dados**:

- Crie 2 datasets idênticos (mesmas opções), mudando só `recordsize` (ex.: 128K vs 1M).
- Rode: cópia grande (arquivo >10GB), cópia de árvore com muitos pequenos, e um teste de “browse/listing”.
- Se 1M melhora sequencial mas piora muito listing/pequenos, use datasets separados por perfil.


### `sync` e `logbias`: cuidado com o que o Windows pede

O manual define `sync=standard|always|disabled` e alerta que `sync=disabled` dá maior performance, mas é perigoso por ignorar demandas síncronas de aplicações (risco de perda/corrupção sob falha) .
Em SMB corporativo, eu manteria `sync=standard` e trataria ganho de escrita síncrona com arquitetura (SLOG adequado, controladora com cache protegido, etc.), não “desligando sync”.

O `logbias` define se o ZFS otimiza operações síncronas para baixa latência usando log devices (se existirem) ou para throughput global; `latency` é o padrão e `throughput` reduz o uso de log device .
Se você tiver SLOG de verdade, `logbias=latency` tende a fazer sentido; se não tiver, avalie `throughput` apenas após medir.

### `atime` e `canmount` (operações e HA)

`atime`/`relatime` impactam escrita de metadados; para shares SMB típicos, `atime=off` costuma reduzir ruído de escrita (valide caso a caso).
Para HA, `canmount=noauto` pode ser útil em datasets que você não quer que montem automaticamente fora do controle do Pacemaker (o manual descreve o comportamento de `canmount=on|off|noauto`) .

### Evite dedup em file server corporativo

O manual do ZFS traz um aviso explícito para não habilitar deduplicação sem necessidade e sem dimensionamento correto, porque é extremamente intensiva em recursos e pode causar problemas graves de performance/estabilidade .
Se a meta for eficiência, prefira compressão (ex.: lz4/zstd) e snapshots/replicação, não dedup.

## DRBD + ZFS: pontos de falha e “otimizações obrigatórias”

### Propagação de erro de I/O (evitar deadlock)

Há relato de que ZFS-on-DRBD pode “falhar miseravelmente” (lockup total) se um disco local falhar, e a correção é garantir que, em erro de I/O, o DRBD detach tanto o recurso local quanto remoto para que o ZFS enxergue o erro, FAULT o device e siga usando redundância quando aplicável.[^4_1]
O mesmo texto destaca que o handler de `on-io-error` precisa completar (sair) para o erro ser propagado ao ZFS; caso contrário, uma TXG pode ficar travada (processo `txg_sync`) e “congelar” operações ZFS.[^4_1]

Mesmo se você estiver em cima de um único LUN RAID (sem vdevs redundantes ZFS), isso continua relevante para **evitar travamento** e para forçar failover limpo.

### Fencing integrado ao DRBD/Pacemaker

Quando o link cai e existe risco de ambos lados virarem Primary em momentos diferentes, o split-brain aparece, e o Pacemaker mailing list reforça que sem STONITH funcional você não tem proteção real; também cita o uso de scripts de fencing integrados (ex.: `crm-fence-peer.sh`).[^4_2]
Isso não é “tuning”, é pré-condição para você poder perseguir performance sem medo.

## Samba: tuning orientado a Windows + medição

### “Windows ACL” com `acl_xattr`

Para compatibilidade, o caminho típico é usar `vfs objects = acl_xattr`, pois esse módulo armazena ACL NT no `security.NTACL` xattr e busca mapear melhor o mundo Windows.[^4_3]
Se o share for acessado **somente por SMB**, considerar `acl_xattr:ignore system acls = yes` pode melhorar compatibilidade NT (e às vezes desempenho por reduzir trabalho duplo), mas você deve validar com seus requisitos de acesso local/NFS.[^4_3]

### Benchmark de SMB que realmente reflete “muitos usuários”

Não confie só em `iperf3`/MBps: o gargalo em ambiente corporativo geralmente é *metadata + locks + ACL checks*.

Sugestão de bateria de testes:

- Windows:
    - `diskspd` para leitura/escrita com diferentes tamanhos (4k rand, 64k seq).
    - `robocopy /MIR /COPYALL /DCOPY:DAT` em árvore grande (mede metadados/ACL).
- Linux:
    - `fio` no dataset local (limite do storage).
    - `smbclient` cópia/listagem (limite do Samba + ZFS).
- Observabilidade:
    - `iostat -x 1`, `zpool iostat -v 1`, `arc_summary`, `smbstatus`, `journalctl -u smbd`.

Interpretação:

- Se `fio` local é rápido, mas SMB é lento → gargalo está em Samba/ACL/xattr/CPU.
- Se `zpool iostat` mostra vdev 90–100% busy e `await` alto → gargalo é storage, e sysctl/Samba não vão salvar.


## O que eu faria como “checklist” de implantação

1. **Decidir e documentar**: ativo-passivo, RPO/RTO, e testes de failover.
2. `ashift=12` no pool (e DRBD 4KiB) e confirmar alinhamento por benchmark.[^4_1]
3. Dataset(s) SMB: `acltype=posixacl` + `xattr=sa` + `atime=off` + compressão leve; validar “browse/listing” .
4. Samba: `vfs_acl_xattr` e definir política `ignore system acls` conforme necessidade de acesso local; validar ACL round-trip no Windows.[^4_3]
5. HA: STONITH obrigatório e testado; integrar fencing ao DRBD conforme orientação do ecossistema.[^4_2]
6. DRBD: implementar `on-io-error`/procedimento que garante detach e propagação de erro (evitar deadlock).[^4_1]
7. Evitar auto-import do data pool no boot fora do cluster; use `cachefile` dedicado e ordene recursos no Pacemaker.[^4_1]

Se você me disser **quantos TB**, tipo de RAID (RAID10/6/60), se há **cache com bateria/flash** na controladora, e se o servidor vai entrar em **AD/SSSD/Winbind**, eu monto uma matriz de parâmetros “legado vs moderno” (sysctl, ARC, Samba, DRBD) + um plano de benchmark com critérios de aceite (p95/p99) para você chegar no melhor ponto com segurança.
<span style="display:none">[^4_10][^4_11][^4_12][^4_13][^4_14][^4_15][^4_16][^4_17][^4_18][^4_19][^4_20][^4_21][^4_22][^4_23][^4_24][^4_25][^4_26][^4_27][^4_28][^4_29][^4_30][^4_5][^4_6][^4_7][^4_8][^4_9]</span>

<div align="center">⁂</div>

[^4_1]: https://www.reddit.com/r/zfs/comments/1nnwgxl/how_to_optimize_zfs_for_a_small_linux_workstation/

[^4_2]: https://oss.clusterlabs.org/pipermail/pacemaker/2012-December/087389.html

[^4_3]: https://man.archlinux.org/man/extra/samba/vfs_acl_xattr.8.en

[^4_4]: https://github.com/openzfs/zfs/issues/1773

[^4_5]: https://forums.freebsd.org/threads/acl-trouble-on-zfs-with-a-bit-of-samba.81090/

[^4_6]: https://www.reddit.com/r/zfs/comments/135uzkr/property_recommendations_for_media_and_document/

[^4_7]: https://openzfs.github.io/openzfs-docs/man/v0.6/8/zfs.8.html

[^4_8]: https://forums.freebsd.org/threads/xattr-sa-effect-on-samba4-directory-browsing-performance.47904/

[^4_9]: http://cedric.dufour.name/blah/IT/ZfsOnTopOfDrbd.html

[^4_10]: http://www.nerdblog.com/2013/10/zfs-xattr-tuning-on-linux.html

[^4_11]: https://www.truenas.com/community/threads/on-disk-cache-and-zfs-performance.70267/

[^4_12]: http://www.bic.mni.mcgill.ca/PersonalMalouinjeanfrancois/ClusterSetup

[^4_13]: https://www.reddit.com/r/zfs/comments/3ui60i/zfs_and_os_x_files_xattr_smb_acls_normalization/

[^4_14]: https://www.reddit.com/r/zfs/comments/n35jde/how_to_speed_up_the_write_on_zfs/

[^4_15]: https://www.reddit.com/r/linuxadmin/comments/lm2rzu/corosyncpacemakerdrbd_dont_do_split_brain/

[^4_16]: https://www.reddit.com/r/zfs/comments/1l7z3yn/zfs_samba_acl_metadataspecial_vdev/

[^4_17]: https://www.reddit.com/r/zfs/comments/jwk3zj/can_i_use_zfs_to_speedup_file_writes/

[^4_18]: https://docs.redhat.com/pt-br/documentation/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/proc_enabling-windows-acl-support_assembly_setting-up-a-share-that-uses-windows-acls

[^4_19]: https://www.truenas.com/community/threads/disabling-dos-attributes-to-improve-samba-browsing-performance.24906/

[^4_20]: https://docs.oracle.com/cd/E88353_01/html/E72487/vfs-acl-xattr-8.html

[^4_21]: https://docs.oracle.com/cd/F16636_01/html/E72378/vfs-acl-xattr-8.html

[^4_22]: https://wiki.amahi.org/index.php/Make_Samba_Go_Faster

[^4_23]: https://www.reddit.com/r/Proxmox/comments/121r7f0/proxmox_zfs_samba_vm_shadow_copy_clamav_xattr/

[^4_24]: https://manpages.opensuse.org/Leap-15.6/samba/vfs_acl_xattr.8.en.html

[^4_25]: https://groups.google.com/g/linux.samba/c/r-YO_2gkqx0

[^4_26]: https://www.reddit.com/r/zfs/comments/8pl8my/what_is_the_actual_status_of_zfs_on_linux_samba/

[^4_27]: https://calomel.org/samba_optimize.html

[^4_28]: https://bbs.archlinux.org/viewtopic.php?id=173211

[^4_29]: https://github.com/openzfs/zfs/issues/5568

[^4_30]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/monitoring_and_managing_system_status_and_performance/assembly_tuning-the-performance-of-a-samba-server_monitoring-and-managing-system-status-and-performance


---

# Para o meu cenário que não tenho como ignorar a controladora raid, qual seria a melhor forma de construir essa arquitetura de servidor de arquivos SAMBA? Estou criando um Debian remasterizado, incluindo na ISO apenas os pacotes que precisarei para torná-lo um servidor de arquivos robusto, estilo TrueNAS SCALE, preciso que o Debian seja extremamente compatível com windows e capaz de se integrar de modo otimizado para trabalhar como cliente de um controlador de domínio Windows Server. As pastas serão compartilhadas com autenticação do Active Directory. Apresente a melhor solução de servidor Debian com SAMBA capaz de compartilhar arquivos para estação Windows no domínio (AD). Avalie a melhor solução, considerando a possibilidade de reproduzi-la mais facilmente, fazendo uso da estratégia de criar uma imagem customizada do Debian preparada com qualquer ajuste necessário previamente, criando uma imagem pelo Live-Build do Debian.

Para o seu cenário “não dá para fugir da controladora RAID”, a melhor arquitetura de NAS Debian estilo TrueNAS SCALE é: **controladora RAID bem configurada e monitorada → ZFS como camada de integridade/snapshots (mas não como RAID real) → Samba AD member com Winbind (ACL NT em xattr) → automação reprodutível via live-build + primeiro-boot para “domain join”**. Em AD corporativo, priorize Winbind no servidor de arquivos porque há funções que o SSSD não cobre (ex.: NTLM/NetBIOS) e também não é recomendado usar SSSD como plugin de ID mapping do Winbind.[^5_1]

## Arquitetura de storage com RAID “fechado”

Como a controladora não entrega discos individuais, você deve aceitar que o ZFS **não terá visibilidade de disco** e, portanto, não consegue fazer “self-heal” como faria em mirror/RAIDZ reais (o máximo que ele garante é **detectar** corrupção via checksum).

Opções “menos ruins”, em ordem de robustez (e de custo):

- **A (preferida): 2 LUNs RAID independentes → ZFS mirror**: crie dois arrays RAID separados (idealmente em grupos físicos distintos; se possível, até controladoras distintas) e apresente como dois LUNs; então crie um `mirror` no ZFS em cima desses 2 block devices.
- **B: 1 LUN RAID único → ZFS single vdev**: simples e rápido, mas se a controladora “mentir”/corromper, o ZFS vai detectar mas pode não conseguir corrigir.
- **C: ZFS em cima de DRBD**: é viável, porém há relatos de travamento severo quando ocorre falha de I/O se o DRBD não propagar corretamente o erro para o ZFS (exigindo política explícita de “detach em erro”).[^5_1]

Se você vai manter o plano DRBD+Pacemaker como “cópia quente”/failover, trate isso como HA **ativo-passivo** (um único primário exportando SMB) e projete o ciclo de recursos: DRBD Primary → import ZFS → mount → start Samba; stop na ordem inversa.

## ZFS “pronto para Samba/Windows”

O que mais melhora compatibilidade e performance em shares Windows é reduzir custo de **ACL/xattr** e manter o dataset com propriedades coerentes para workload misto.

Recomendações de dataset para shares SMB:

- ACL e xattr: `acltype=posixacl` e `xattr=sa` (o manual recomenda fortemente `xattr=sa` para melhor performance quando `posixacl` está ativo).
- Cache: evite `primarycache=metadata` em datasets servidos por Samba, porque há relatos de degradação grande de performance.[^5_2]
- Tamanho de registro: comece com `recordsize=128K` (padrão) e só mude por dataset com benchmark, porque o manual alerta que alterar `recordsize` em filesystem de uso geral pode piorar desempenho.

Exemplo (um dataset “SHARES”):

```bash
zfs create tank/SHARES
zfs set acltype=posixacl tank/SHARES
zfs set xattr=sa tank/SHARES
zfs set atime=off tank/SHARES
# compressão: escolha conservadora (ex.: lz4/zstd leve) e valide em benchmark
```

`acltype`, `xattr` e `recordsize` são propriedades documentadas no `zfs(8)`.

## Samba em domínio AD: por que Winbind (e não “só SSSD”)

Para um servidor de arquivos Samba em AD, Winbind continua sendo a escolha mais previsível quando você precisa de recursos que o SSSD não fornece (ex.: autenticação NTLM e lookup NetBIOS).[^5_1]
A mesma referência também ressalta que não é recomendado usar SSSD como “ID mapping plug-in” do Winbind.[^5_1]

## Configuração-base: Samba AD member + mapeamento de IDs estável

O “esqueleto” de um AD member server em modo ADS é consistente nas documentações: `security = ADS` e `realm = SEU.REALM` (Kerberos).[^5_3][^5_4]
Um exemplo prático em Debian inclui ainda `kerberos method = secrets and keytab` e um backend de idmap (como `autorid`) com ranges definidos, e usa `net ads join` para ingressar no domínio.[^5_5]

Exemplo mínimo (ponto de partida) para `/etc/samba/smb.conf`:

```ini
[global]
   security = ADS
   realm = EXEMPLO.COM
   workgroup = EXEMPLO

   kerberos method = secrets and keytab

   # ID mapping: escolha UMA estratégia e mantenha para sempre
   idmap config * : backend = autorid
   idmap config * : range = 1000000-19999999
   idmap config * : rangesize = 1000000
```

As diretivas `security = ADS`/`realm` para “AD member” e o fluxo de join estão descritos em guias de ADS member.[^5_4][^5_3]
O uso de `kerberos method = secrets and keytab`, `autorid` e o join via `net ads join` em Debian aparece em exemplos de integração.[^5_5]

### ACL NTFS “de verdade” no share

Para ficar próximo do comportamento Windows, use `vfs_acl_xattr` para armazenar ACL NT no xattr `security.NTACL` (isso melhora fidelidade do modelo Windows sobre POSIX).[^5_6]
Depois você valida do lado Windows (Security tab) e, do lado Linux, com leitura explícita do xattr `security.NTACL` conforme o próprio manpage orienta.[^5_6]

## Live-build: como tornar isso reprodutível na sua ISO

O live-build permite “carimbar” arquivos no filesystem do sistema (includes) e executar comandos durante o build (hooks), o que é ideal para embutir `smb.conf`, `krb5.conf`, sysctl, units do systemd e scripts.
Você coloca arquivos prontos em `config/includes.chroot/` (isso sobrescreve arquivos de pacotes após a instalação) e scripts em `config/hooks/live/*.hook.chroot` (rodando dentro do chroot ao final da customização).

Estrutura típica do seu projeto:

- `config/package-lists/nas.list.chroot`: lista de pacotes (samba, winbind, zfsutils-linux, etc.)
- `config/includes.chroot/etc/samba/smb.conf`: config padrão do Samba
- `config/includes.chroot/etc/krb5.conf`: template Kerberos (realm/DCs ajustados)
- `config/hooks/live/99-hardening.hook.chroot`: habilitar serviços, criar diretórios, defaults
- (opcional) hooks de boot via live-config: você pode adicionar scripts em `config/includes.chroot/lib/live/config/` seguindo a ordem numérica.


### Domain join: faça no “primeiro boot”, não na ISO

Para ambientes corporativos, a prática segura é o sistema subir “pronto”, mas **não ingressado** no domínio, e rodar um *wizard* no primeiro boot (TUI/CLI) que:

- configura hostname/DNS (crítico para Kerberos),
- executa `net ads join ...`,
- grava keytab/segredos localmente,
- reinicia `smbd/winbind` e valida com `wbinfo`.

Isso evita embutir credenciais na ISO e facilita replicar a imagem em várias filiais.

## Observações sobre ZFSBootMenu (no seu remaster)

Se ZFSBootMenu é o padrão, mantenha Syslinux apenas como “ponte” para BIOS legado e preserve o modelo em que ele só carrega o kernel+initramfs do ZFSBootMenu, deixando a lógica avançada (seleção/boot de ambientes ZFS) para o ZFSBootMenu.[^5_7][^5_8]

***

Qual é a sua preferência para **mapeamento de identidade** no AD: vocês têm RFC2307 (uidNumber/gidNumber) padronizado no AD, ou você precisa de um idmap “automático” (tipo RID/AUTORID) consistente sem atributos Unix no diretório?
<span style="display:none">[^5_10][^5_11][^5_12][^5_13][^5_14][^5_15][^5_16][^5_17][^5_18][^5_19][^5_20][^5_21][^5_22][^5_23][^5_24][^5_25][^5_26][^5_27][^5_28][^5_29][^5_30][^5_31][^5_32][^5_33][^5_34][^5_35][^5_9]</span>

<div align="center">⁂</div>

[^5_1]: https://www.reddit.com/r/zfs/comments/1nnwgxl/how_to_optimize_zfs_for_a_small_linux_workstation/

[^5_2]: https://github.com/openzfs/zfs/issues/1773

[^5_3]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/4/html/reference_guide/s2-samba-ads-security-mode

[^5_4]: https://docs.oracle.com/en/operating-systems/oracle-linux/6/admin/ol_ads_samba.html

[^5_5]: https://www.server-world.info/en/note?os=Debian_12\&p=samba\&f=4

[^5_6]: https://man.archlinux.org/man/extra/samba/vfs_acl_xattr.8.en

[^5_7]: https://docs.zfsbootmenu.org/en/v2.3.x/general/uefi-booting.html

[^5_8]: https://docs.zfsbootmenu.org/en/v2.3.x/general/binary-releases.html

[^5_9]: https://www.reddit.com/r/linuxadmin/comments/1egqa1z/in_an_ad_based_domain_does_it_make_sense_to_use/

[^5_10]: https://www.reddit.com/r/linuxadmin/comments/8ku7qo/winbind_or_sssd_for_samba_ad_member_and_why/

[^5_11]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/windows_integration_guide/smb-sssd

[^5_12]: https://help.univention.com/t/extended-domain-services-documentation-sssd-vs-winbind-for-samba-fileshares/20247

[^5_13]: https://www.redhat.com/en/blog/sssd-vs-winbind

[^5_14]: https://www.howtoforge.com/samba_ads_security_mode_p2

[^5_15]: https://lists.debian.org/debian-live/2013/02/msg00179.html

[^5_16]: https://www.reddit.com/r/linux4noobs/comments/kbnly2/winbind_vs_sssd_what_is_the_best_way_to_join_a/

[^5_17]: https://github.com/systemd/systemd/issues/5260

[^5_18]: https://docs.merox.dev/operations/storage/SMB/samba-sssd-winbind/

[^5_19]: https://docs.redhat.com/de/documentation/red_hat_enterprise_linux/4/html/reference_guide/s2-samba-ads-security-mode

[^5_20]: https://live-team.pages.debian.net/live-manual/html/live-manual/customizing-contents.en.html

[^5_21]: https://winehq.org.ru/SambaSSSDvsWinbind

[^5_22]: https://www.reddit.com/r/sysadmin/comments/t8kfe7/samba_idmap_confusion/

[^5_23]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/system-level_authentication_guide/winbind-auth

[^5_24]: https://groups.google.com/g/linux.samba/c/n63HDIE_0Ss

[^5_25]: https://www.reddit.com/r/sysadmin/comments/s2yiim/problems_with_smbconf_winbind_authentication/

[^5_26]: https://staff.ie.cuhk.edu.hk/~sfluk/wordpress/?p=2460

[^5_27]: https://www.spinics.net/lists/samba/msg186088.html

[^5_28]: https://www.suse.com/support/kb/doc/?id=000020593

[^5_29]: https://std.rocks/gnulinux_samba_winbind.html

[^5_30]: https://linux.samba.narkive.com/MmUC7xbZ/samba-vfs-streams-xattr-and-create-mask-0640-don-t-play-well-together

[^5_31]: https://www.reddit.com/r/linuxadmin/comments/8g7xk0/allowing_trusted_domain_windows_ad_user_to_login/

[^5_32]: https://www.server-world.info/en/note?f=4\&os=Debian_12\&p=samba

[^5_33]: https://www.truenas.com/community/threads/when-using-fruit-in-an-smb-share-ea-support-yes-or-no.83482/

[^5_34]: http://linux-training.be/servers/ch16.html

[^5_35]: https://wiki.debian.org/AuthenticatingLinuxWithActiveDirectory


---

# Pretendo utilizar um servidor Dell 2950 com 32 GiB de RAM, 2 CPU octa core, este servidor possui uma controladora raid iperc5 ou 6, não me lembro qual é ao certo, com suporte para 6 discos SAS, atualmente tenho discos de 600 GiB (RPM 15k) além das 2 interfaces de rede onboard de 1G também possui um placa de rede com saída dupla de 10 GiB, qual seria o tipo de RAID mais adequado para reproduzir suas recomendações?

Para o seu Dell 2950 com 6×600 GiB SAS 15k atrás de uma PERC 5/i ou 6/i (sem JBOD), a melhor escolha “padrão corporativo” para um file server SMB com muitos usuários é **RAID10**, porque esse tipo de carga tende a ser pesada em metadados e pequenas escritas aleatórias (pior caso para RAID com paridade).[^6_1]

## RAID recomendado (melhor equilíbrio)

### Opção preferida: RAID10 (6 discos)

RAID10 é indicado quando você quer o melhor desempenho de **random write**, e a própria orientação da Dell (em política de RAID) aponta RAID10 como recomendado para workloads que exigem o nível mais alto de desempenho de I/O em escritas aleatórias, especialmente com discos 10K/15K RPM.[^6_1]
Em RAID com paridade, pequenas escritas sofrem “penalidade” maior; uma explicação comum é que RAID6 pode chegar a penalidade de escrita de 6 operações por write pequeno (read-modify-write), o que degrada latência sob carga.[^6_2]
Com 6×15k e SMB concorrente, RAID10 costuma entregar latência mais estável (p95/p99 melhores) do que RAID6/5, mesmo sacrificando capacidade.[^6_2][^6_1]

**Como configurar na PERC (prática):**

- Virtual Disk único em **RAID10** com os 6 discos.[^6_1]
- **Write-back cache só com BBU/CacheVault** (ou proteção equivalente): cache pode “esconder” a penalidade de RAID com paridade e melhorar percepção do host, mas isso depende de cache seguro e política correta.[^6_3]


## Alternativas (quando capacidade pesa mais)

### RAID50 (6 discos) — só se você aceitar mais variância de latência

A política da Dell lista RAID50 como um “ótimo conjunto de performance, disponibilidade e capacidade” em sistemas com menos de 24 drives e discos 10K/15K.[^6_1]
Ainda assim, RAID50 continua sendo paridade (conjunto de RAID5s), então a latência em escrita aleatória tende a ser pior e mais variável que RAID10 conforme a concorrência sobe (o que aparece muito em SMB corporativo).[^6_2][^6_1]

### Evite RAID5 (para dados corporativos)

A mesma política da Dell recomenda não usar RAID5 para dados business-critical, citando risco maior durante rebuild e vulnerabilidade a erro irrecuperável no processo.[^6_1]

## Como decidir com dados (benchmark do seu caso)

Para escolher “RAID10 vs RAID50” com segurança, use um teste que reflita seu uso:

- **No Linux (local, sem rede):** `fio` no filesystem ZFS do dataset SMB para separar limite de storage do limite de rede/Samba.
- **No Windows (via SMB):** `diskspd` para medir o que o usuário final sente (latência e throughput por share).

**Métricas que mandam:**

- Latência p95/p99 em escrita 4K/16K randômica (sensível a metadados/ACL).[^6_2]
- `await` e `%util` no `iostat -x 1` durante pico (se `%util` cola em 100% e `await` dispara, o array está saturando).
- Se RAID50 entregar throughput bom mas p99 ruim sob concorrência, RAID10 normalmente é a troca correta para “ambiente com muitos usuários”.


## O que isso muda no seu design ZFS+Samba

Como você não tem discos “crus”, o ZFS não consegue substituir o RAID da controladora; então o objetivo é: **usar o RAID da PERC para redundância real** e o ZFS para integridade por checksum, snapshots e gerenciamento.[^6_1]
Para compatibilidade/performance de ACL com Windows, mantenha datasets SMB com `acltype=posixacl` e `xattr=sa`, porque o manual recomenda fortemente `xattr=sa` para performance quando `posixacl` está ativo.

## Recomendação final (objetiva)

- Se prioridade é **desempenho e estabilidade de latência** para muitos usuários SMB: **RAID10 com 6 discos**.[^6_1]
- Se prioridade é **capacidade** e você tolera mais variação de latência: considere **RAID50**, mas valide com `diskspd`/`fio` e monitore latências (p95/p99).[^6_2][^6_1]
- Evite RAID5 para dados críticos.[^6_1]

Sua PERC tem BBU/CacheVault (para habilitar write-back com segurança) e ela permite criar mais de um Virtual Disk (por exemplo, separar OS e dados)?
<span style="display:none">[^6_10][^6_11][^6_12][^6_13][^6_14][^6_15][^6_4][^6_5][^6_6][^6_7][^6_8][^6_9]</span>

<div align="center">⁂</div>

[^6_1]: https://psonlinehelp.dell.com/en/V8.0/GUID-5381BB60-C7E1-4B1B-8C63-DB06008B7422.html

[^6_2]: https://theithollow.com/2012/03/21/understanding-raid-penalty/

[^6_3]: https://www.dell.com/community/en/conversations/vnx/can-fast-cache-soften-raid6-write-penalty/647f4216f4ccf8a8de9d65e8

[^6_4]: https://www.reddit.com/r/homelab/comments/90nx5s/perc_6i_low_performances/

[^6_5]: https://www.reddit.com/r/sysadmin/comments/1dditww/sas_ssd_raid_6_or_10/

[^6_6]: https://quickbooks.intuit.com/learn-support/en-us/other-questions/raid-10-vs-raid-6-read-write-intensive-qb-on-dell-server/00/443202

[^6_7]: https://www.reddit.com/r/sysadmin/comments/9gkc3k/raid_6_vs_raid_10_performance/e64q73z/

[^6_8]: https://www.dell.com/community/en/conversations/poweredge-hddscsiraid/raid-5-best-practice/647eaae9f4ccf8a8de83427b

[^6_9]: https://www.reddit.com/r/storage/comments/l4jon4/help_me_make_up_my_mind_4x_8t_disks_as_2x_raid_10/

[^6_10]: https://www.reddit.com/r/netapp/comments/go6d1p/write_penalty/

[^6_11]: https://www.reddit.com/r/homelab/comments/9mb69a/is_raid5_reliable_enough_or_should_i_use_6_or_10/

[^6_12]: https://www.ibm.com/support/pages/performance-myth-busting

[^6_13]: https://www.overclockers.com/forums/threads/perc-5-i-benchmark-thread.628456/

[^6_14]: https://community.broadcom.com/vmware-cloud-foundation/discussion/pe2900-perc6i-das-raid10-read-performance

[^6_15]: https://www.reddit.com/r/synology/comments/1cgsonh/the_raid_6_myth_actual_performance/


---

# A controladora permite eu criar mais de um Virtual Disk, mas para isso eu preciso utilizar a grupos de discos dedicadas para cada Virtual Disck. Até seria possível separar, mas sacrificando armazenamento para sistema operacional, que será muito pouco, pois será um Linux dedicado apenas para compartilhamentos SAMBA. Também perderia a possibilidade de utilizar snapshots do sistema, para usar como ponto de restauração durante o boot com o ZFSBootMenu.

Qual seria a escolha de configuração que traria maior benefício para o servidor de arquivos, ignore a minha escolha inicial sobre a stack técnica, apresente uma solução que seja mais vantajosa possível para este cenário, avalie estatisticamente a melhor probabilidade de garantir sucesso, entregando desempenho, estabilidade, com maior número de recursos convenientes ao uso do SAMBA integrado com o AD, em ambiente corporativo.

A configuração com maior probabilidade de “dar certo” (desempenho estável + compatibilidade Windows/AD + facilidade de replicar via ISO) é: **um único Virtual Disk RAID10 na PERC usando todos os 6 discos**, um **pool ZFS único** por cima dele (com boot environments para o sistema via ZFSBootMenu) e **Samba como AD member usando Winbind + ACLs NT em xattr**.[^7_1][^7_2][^7_3]

## Por que um único Virtual Disk

Em controladoras RAID, criar múltiplos arrays/VDs pode introduzir riscos operacionais quando um array falha e o controlador/OS “reenumera” identificadores de arrays restantes, o que pode confundir importações baseadas em cache/paths.[^7_4]
Como você perde muito espaço se separar discos para “VD do sistema”, e quer snapshots/boot environments com ZFSBootMenu, a estratégia mais consistente é **um VD só** e separar “sistema vs dados” por **datasets**, não por VDs.[^7_2][^7_4]

## RAID ideal na PERC

Para NAS SMB corporativo com muitos usuários (muita operação pequena e concorrente), **RAID10** tende a entregar a melhor latência e previsibilidade de escrita aleatória, e é explicitamente recomendado pela Dell quando se busca o nível mais alto de desempenho de I/O em random writes (especialmente com discos 10K/15K).[^7_3]
RAID5 é explicitamente desaconselhado pela Dell para dados “business-critical” (maior risco durante rebuild e vulnerabilidade a erro irrecuperável).[^7_3]
RAID50 pode ser aceitável quando capacidade pesa, mas ainda carrega penalidade de paridade em escritas pequenas; para “muitos usuários SMB”, isso costuma aparecer como pior p95/p99 de latência sob pico.[^7_5][^7_3]

Recomendação objetiva para seus 6×600G 15k: **RAID10 com todos os 6 discos no mesmo VD**.[^7_3]

## Layout ZFS para ZFSBootMenu

O ZFSBootMenu espera que um boot environment seja **exatamente um filesystem** para que snapshots/rollbacks/clones representem um estado consistente do sistema.[^7_2]
Então, mantenha o sistema em um dataset único por BE (ex.: `tank/ROOT/debian`) e os dados do servidor de arquivos em datasets separados (ex.: `tank/DATA/shares`), evitando que rollback do sistema afete dados.[^7_2]

Para boot automático, configure `bootfs` e force o ZFSBootMenu a preferir seu pool com `zbm.prefer=<pool>!` (isso evita seleção “por ordem alfabética” quando houver outros pools).[^7_6][^7_7]

## Propriedades ZFS que mais importam ao SMB

Para shares SMB com ACLs, ative ACL POSIX e use xattrs em SA:

- `acltype=posixacl` habilita ACL POSIX no dataset.
- `xattr=sa` é **fortemente recomendado** para melhorar performance quando `posixacl` está ativo, armazenando xattrs (incluindo ACLs) de forma mais eficiente.

Evite “otimizações reflexas”:

- `recordsize`: o manual alerta que mudar `recordsize` em filesystem de uso geral é fortemente desencorajado e pode piorar performance; ajuste só com benchmark por dataset.
- Dedup: o manual traz aviso forte para não habilitar dedup sem real necessidade e dimensionamento, por custo alto e risco de degradação severa.


## Samba + AD: caminho mais compatível

Para servidor de arquivos membro de domínio AD, o caminho mais previsível é **Samba em ADS + Winbind**, porque há recursos que o SSSD não cobre (por exemplo NTLM/NetBIOS) e também não é recomendado usar SSSD como plugin de ID mapping do Winbind.[^7_8]
A compatibilidade de ACL NTFS melhora quando você usa `vfs_acl_xattr`, que armazena ACLs NT no extended attribute `security.NTACL` e permite mapeamento completo das ACLs Windows.[^7_1]
O manpage também explica `acl_xattr:ignore system acls`: se seus dados forem acessados *somente via Samba*, `yes` pode melhorar compatibilidade NT; se você precisa que ACLs “do sistema” também funcionem para acesso local/NFS, mantenha `no`.[^7_1]

## Pré‑requisitos críticos (AD/Kerberos)

Para ingressar e operar bem no domínio, você precisa de DNS resolvendo o domínio AD e do horário do host sincronizado com o AD.[^7_9]
Kerberos rejeita autenticações quando o “clock skew” excede o limite; uma referência descreve 300 segundos (5 minutos) como padrão e recomenda NTP para manter relógios sincronizados.[^7_10]

Na sua ISO, isso vira checklist automático:

- resolver DNS apontando para DCs,
- `chrony`/timesync ativo,
- validação: `kinit`, `wbinfo -u/-g`, acesso SMB de um cliente.


## 10GbE e SMB Multichannel (opcional, mas valioso)

O SMB Multichannel cria múltiplas conexões TCP por sessão para somar throughput e dar tolerância a falha de NIC, e o Windows documenta esse comportamento (inclusive com RSS/RDMA quando disponível).[^7_11]
Em Samba, há configurações usadas na prática para habilitar multichannel (`server multi channel support = yes`) e recomendações de ativar async I/O para um único fluxo conseguir alimentar múltiplas NICs; trate isso como feature **a ser validada** no seu ambiente (drivers/RSS/switch).[^7_12]

## “Alta disponibilidade”: o que maximiza chance de sucesso

Para maximizar estabilidade num primeiro ciclo corporativo, minha recomendação é **não** começar com DRBD+Pacemaker por baixo/ao lado do ZFS quando você já está sobre controladora RAID “opaca”, porque você adiciona camadas de falha e casos difíceis (propagação de erro de I/O, fencing, split-brain).[^7_13][^7_8]
Em vez disso, use o que o ZFS entrega com alta previsibilidade: **snapshots + replicação `zfs send | zfs receive`** para um destino (de preferência outro host), mantendo o destino pronto para “promover” em incidente.
Se a sua exigência for “failover automático”, construa isso depois de ter baseline e testes de falha (energia, rede, DC indisponível), porque o custo de operar cluster mal testado é maior que o ganho inicial de automação.[^7_13]

## ISO reprodutível (live-build)

O live-build permite incluir arquivos prontos no sistema e executar hooks durante a construção do chroot, o que é ideal para “carimbar” `smb.conf`, `krb5.conf`, sysctl, units e scripts de first-boot.
A forma típica é colocar arquivos em `config/includes.chroot/` e hooks em `config/hooks/live/*.hook.chroot`, garantindo que toda máquina instalada nasça idêntica e só precise do “join no domínio” no primeiro boot.

***

Se você responder duas coisas, eu consigo te devolver uma proposta fechada (layout ZFS completo + `smb.conf` modelo + plano de testes `fio`/`diskspd` + checklist AD):

1) Você terá **BBU/CacheVault** na PERC (para write-back seguro) ou ficará em write-through?
2) Os shares serão acessados **somente via SMB** ou também por acesso local/NFS (isso define `acl_xattr:ignore system acls`)?
<span style="display:none">[^7_14][^7_15][^7_16][^7_17][^7_18][^7_19][^7_20][^7_21][^7_22][^7_23][^7_24][^7_25][^7_26][^7_27][^7_28][^7_29][^7_30][^7_31][^7_32][^7_33][^7_34][^7_35][^7_36][^7_37][^7_38][^7_39][^7_40][^7_41][^7_42][^7_43][^7_44][^7_45][^7_46][^7_47][^7_48][^7_49]</span>

<div align="center">⁂</div>

[^7_1]: https://manpages.opensuse.org/Leap-15.6/samba/vfs_acl_xattr.8.en.html

[^7_2]: https://docs.zfsbootmenu.org/en/latest/general/bootenvs-and-you.html

[^7_3]: https://psonlinehelp.dell.com/en/V8.0/GUID-5381BB60-C7E1-4B1B-8C63-DB06008B7422.html

[^7_4]: https://openzfs.github.io/openzfs-docs/Performance and Tuning/Hardware.html

[^7_5]: https://theithollow.com/2012/03/21/understanding-raid-penalty/

[^7_6]: https://docs.zfsbootmenu.org/en/v2.3.x/man/zfsbootmenu.7.html

[^7_7]: https://zfsbootmenu.org

[^7_8]: https://www.reddit.com/r/zfs/comments/1nnwgxl/how_to_optimize_zfs_for_a_small_linux_workstation/

[^7_9]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_using_network_file_services/assembly_using-samba-as-a-server_configuring-and-using-network-file-services

[^7_10]: https://docs.oracle.com/cd/E23824_01/html/821-1456/setup-192.html

[^7_11]: https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/manage-smb-multichannel

[^7_12]: https://blog.chaospixel.com/linux/2016/09/samba-enable-smb-multichannel-support-on-linux.html

[^7_13]: https://oss.clusterlabs.org/pipermail/pacemaker/2012-December/087389.html

[^7_14]: https://forum.proxmox.com/threads/yet-another-zfs-on-hw-raid-thread-with-benchmarks.138947/

[^7_15]: https://www.reddit.com/r/zfs/comments/1e1u43k/i_keep_reading_that_zfs_shouldnt_be_run_on_top_of/

[^7_16]: https://klarasystems.com/articles/zfs-vs-raid-zfs-redundancy-done-right/

[^7_17]: https://www.starline.de/en/magazine/technical-articles/raid-controller-backplane-and-chassis-under-openzfs

[^7_18]: https://www.jurisic.org/post/2021/11/24/SAMBA-Domain-Member-as-File-Server

[^7_19]: https://www.reddit.com/r/zfs/comments/1f9xie6/zfs_3_different_ways_on_raid_controller_has/

[^7_20]: https://www.reddit.com/r/DataHoarder/comments/2t0765/zfs_use_existing_hardware_raid_controllers_as/

[^7_21]: https://docs.zfsbootmenu.org/en/v2.3.x/online/snapshot-management.html

[^7_22]: https://www.voelker-hud.de/de/administration/linux/samba-fileserver-auf-member-server-mit-acl-support

[^7_23]: https://www.starline.de/magazin/technische-artikel/raid-backplane-und-chassis-fuer-openzfs

[^7_24]: https://codeinsecurity.wordpress.com/2020/05/18/setting-up-smb-multi-channel-between-freenas-or-any-bsd-linux-and-windows-for-20gbps-transfers/

[^7_25]: https://documentation.suse.com/pt-br/sles/12-SP5/html/SLES-all/cha-samba.html

[^7_26]: https://pubs.lenovo.com/smbcifs_reference/514BE8CE-FD6D-4944-B4DB-C75578E358B7_

[^7_27]: https://stackoverflow.com/questions/63372848/how-to-enable-smb1-as-default-and-disable-smb2-and-smb3-on-ubuntu-18-04-server

[^7_28]: https://www.truenas.com/community/threads/when-using-fruit-in-an-smb-share-ea-support-yes-or-no.83482/

[^7_29]: https://www.snia.org/sites/default/files/SDC15_presentations/smb/MichaelAdam_SMB3_Multi_Channel_%20rev.pdf

[^7_30]: https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3

[^7_31]: https://manpages.debian.org/stretch/samba-vfs-modules/vfs_fruit.8.en.html

[^7_32]: https://www.reddit.com/r/samba/comments/10r1akh/samba_smb_multichannel_not_working/

[^7_33]: https://docs.redhat.com/pt-br/documentation/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/assembly_configuring-samba-to-be-compatible-with-clients-that-require-an-smb-version-lower-than-the-default_assembly_using-samba-as-a-server

[^7_34]: https://www.samba.gr.jp/project/translation/current/htmldocs/manpages/vfs_fruit.8.html

[^7_35]: https://www.truenas.com/community/threads/samba-4-15-and-multi-channel-now-enabled-by-default.96716/

[^7_36]: https://www.samba.gr.jp/project/translation/4.6/htmldocs/manpages/vfs_fruit.8.html

[^7_37]: https://community.fortinet.com/t5/FortiGate/Troubleshooting-Tip-Time-Skew-error-in-Kerberos-Authentication/ta-p/364917

[^7_38]: https://support.globalsign.com/Certificate-Automation-Manager/how-identify-and-solve-clock-skew-problems-ntp

[^7_39]: https://support.kerioconnect.gfi.com/article/115027-kerberos-authentication-failing-because-of-clock-offset-difference

[^7_40]: https://docs.oracle.com/cd/E19253-01/816-4557/setup-192/index.html

[^7_41]: https://help.ubuntu.com/community/SmallBusinessServer/SAMBA/Configure

[^7_42]: https://docs.vertica.com/12.0.x/en/security-and-authentication/client-authentication/kerberos-authentication/troubleshooting-kerberos-authentication/

[^7_43]: https://docs.oracle.com/cd/E36784_01/html/E37126/ksetup-192.html

[^7_44]: https://www.suse.com/ja-jp/support/kb/doc/?id=000016990

[^7_45]: https://www.reddit.com/r/redhat/comments/xckd6u/syncing_with_chrony/

[^7_46]: https://groups.google.com/g/comp.protocols.kerberos/c/uSJM_A9I4Uc

[^7_47]: https://samba.tranquil.it/doc/en/samba_config_server-server_install_ntp_debian.html

[^7_48]: https://documentation.ubuntu.com/server/how-to/networking/chrony-client/

[^7_49]: https://tldp.org/HOWTO/Kerberos-Infrastructure-HOWTO/time-sync.html


---

# O foco é compartilhamento via SMB, se eu precisar de um compartilhamento NFS para entregar algum material a servidores, como isso impactaria nesses ajustes? Sobre a controladora, pretendo utilizar a que for mais vantajoso para meu cenário, não tenho um opinião formada sobre isso.

Se o seu foco é **SMB puro**, você consegue otimizar para máxima compatibilidade com Windows (ACLs NT bem fiéis) e bom desempenho. Se você precisar expor **a mesma árvore de dados via NFS**, o ajuste muda: você deve priorizar ACL/POSIX coerentes para Linux/UNIX e aceitar uma pequena perda de “fidelidade NT” — ou, melhor ainda, separar datasets por protocolo.[^8_1]

## Quando é só SMB (recomendado)

Para SMB-only, a abordagem mais compatível é armazenar ACL NTFS em xattrs e evitar que o Samba fique tentando “traduzir” tudo para ACL do sistema. O `vfs_acl_xattr` tem a opção `acl_xattr:ignore system acls`; quando `yes`, ele **não** faz o mapeamento best-effort com ACL POSIX e isso costuma entregar melhor compatibilidade NT, sendo sugerido quando os dados são acessados apenas via Samba.[^8_1]

Recomendação prática (por share SMB-only):

- `vfs objects = acl_xattr`
- `acl_xattr:ignore system acls = yes` (SMB-only)[^8_1]


## Se você precisar de NFS (impacto e melhor padrão)

Se você exportar via NFS (ou precisar de acesso local POSIX consistente), você quer que permissões/ACL do sistema reflitam o controle de acesso, porque clientes NFS não “entendem” o `security.NTACL` do Samba como fonte primária de autorização.

Aqui a própria documentação do `vfs_acl_xattr` já deixa a regra operacional: com `acl_xattr:ignore system acls = no` (padrão), o Samba mantém e avalia **tanto** ACLs do sistema **quanto** ACLs NT, e isso é melhor se você precisa que ACLs do sistema sirvam para acesso local ou NFS.[^8_1]

Melhor solução para maximizar chance de sucesso (e reduzir problemas de permissão “misteriosa”):

1) **Não compartilhe o mesmo dataset por SMB e NFS** quando possível.
2) Crie **dois datasets**:

- Dataset A (SMB-only): NT ACL “puro”, `ignore system acls = yes`.[^8_1]
- Dataset B (NFS/servidores): POSIX “puro”, `ignore system acls = no` (ou até sem `acl_xattr`), e política de permissões/ACL definida para Linux.

Se você for obrigado a expor *a mesma pasta* via SMB e NFS, então use:

- `vfs_acl_xattr` + `acl_xattr:ignore system acls = no`, e passe a tratar permissões como “POSIX primeiro” (a compatibilidade NT ainda funciona, mas pode haver mais fricção em herança/semântica).[^8_1]

Observação: o modelo de ACL do NFSv4 é mais rico e com semântica “NT-style” quando comparado a POSIX tradicional, mas isso só ajuda se sua pilha inteira (FS + servidor NFS + clientes) estiver realmente alinhada nesse modelo.[^8_2]

## Controladora RAID: o que mais importa para ZFS+SMB

Já que você não pode ter JBOD, o “fator decisivo” para desempenho e estabilidade no seu cenário é a controladora permitir **write-back cache com proteção contra queda de energia** (BBU/CacheVault).

A documentação da Dell descreve claramente:

- Em **Write-Through**, a controladora só sinaliza conclusão ao host depois que o subsistema de disco recebeu os dados.[^8_3]
- Em **Write-Back**, a controladora sinaliza conclusão assim que os dados entram no cache e depois grava em disco em background; isso dá vantagem de desempenho, mas há risco de perda se faltar energia antes de drenar o cache — mitigado por BBU em controladoras compatíveis.[^8_3]

Então, a escolha “mais vantajosa” de controladora (entre as que você tiver acesso) é:

- A que te permita operar em **Write-Back com BBU/CacheVault saudável**, firmware atualizado, sem “Force WB sem bateria”.[^8_3]

Isso tende a impactar mais o “sentir” do SMB (principalmente em picos com muitos commits/metadados) do que trocar pequenos sysctls.

## RAID level: melhor probabilidade de sucesso (seu caso)

Com 6× SAS 15k e objetivo de baixa latência e I/O aleatório concorrente típico de SMB corporativo, **RAID10** segue sendo o mais previsível para estabilidade de latência (p95/p99) e para absorver escrita pequena. A própria orientação de política RAID da Dell posiciona RAID10 como recomendado quando você busca o nível mais alto de desempenho de I/O em escritas aleatórias.[^8_4]

## O que eu implementaria na sua ISO (para ficar “TrueNAS-like”)

Itens que eu “fixaria” no remaster (independe de NFS):

- Templates prontos de `smb.conf` para os dois perfis: **SMB-only** e **SMB+NFS**, alternando `acl_xattr:ignore system acls` conforme acima.[^8_1]
- Um script de “first boot” que pergunta: “vai ter NFS na mesma árvore?” e escolhe o perfil, criando datasets separados automaticamente.
- Um verificador de controladora no pós-instalação: alerta se a PERC está em Write-Through ou se write-back não está protegido, porque isso muda a expectativa de desempenho e risco.[^8_3]

Você pretende que NFS (quando existir) aponte para **o mesmo conjunto de pastas** compartilhadas no SMB, ou você aceita separar em um dataset/share próprio?
<span style="display:none">[^8_10][^8_11][^8_12][^8_13][^8_14][^8_15][^8_16][^8_5][^8_6][^8_7][^8_8][^8_9]</span>

<div align="center">⁂</div>

[^8_1]: https://manpages.debian.org/bullseye/samba-vfs-modules/vfs_acl_xattr.8.en.html

[^8_2]: https://docs.oracle.com/cd/E19253-01/819-5461/ftyxi/index.html

[^8_3]: https://www.dell.com/community/en/conversations/poweredge-hddscsiraid/perc-write-caching-option-and-its-interaction-with-os-level-drive-caching/647f1902f4ccf8a8debdc3db

[^8_4]: https://psonlinehelp.dell.com/en/V8.0/GUID-5381BB60-C7E1-4B1B-8C63-DB06008B7422.html

[^8_5]: https://docs.oracle.com/cd/E88353_01/html/E72487/vfs-acl-xattr-8.html

[^8_6]: https://docs.oracle.com/cd/F16636_01/html/E72378/vfs-acl-xattr-8.html

[^8_7]: https://groups.google.com/g/linux.samba/c/ID5DnCndvWA

[^8_8]: https://manpages.ubuntu.com/manpages/xenial/man8/vfs_acl_xattr.8.html

[^8_9]: https://www.reddit.com/r/truenas/comments/119bh22/process_for_converting_a_dataset_acl_type_between/

[^8_10]: https://manpages.debian.org/experimental/samba-vfs-modules/vfs_acl_xattr.8.en.html

[^8_11]: https://www.reddit.com/r/linuxadmin/comments/17hqvku/zfs_smb_should_i_use_posix_or_nfsv4_acls/

[^8_12]: https://www.dell.com/community/en/conversations/rack-servers/cannot-change-write-cache-polity-from-write-through-to-write-back/647f78fbf4ccf8a8de7126a1

[^8_13]: https://www.systutorials.com/docs/linux/man/8-vfs_acl_xattr/

[^8_14]: https://forums.freebsd.org/threads/acl-on-zfs-convert-from-nfsv4-to-posixacl.86607/

[^8_15]: https://www.dell.com/support/manuals/en-us/poweredge-rc-h840/perc10_ug/controller-cache-preservation?guid=guid-ab3e6ff3-97e4-4a2a-a654-135293ec3857\&lang=en-us

[^8_16]: https://man.archlinux.org/man/extra/samba/vfs_acl_xattr.8.en


---

# Acredito o modelo de ACL do NFSv4 é justamente o que adota do TrueNAS, eu posso criar scripts que aplicam 3 tipos de templates, SMB-Only, NFS-Only, SMB+NFS, vou criar um sistema de scripts para ajudar com essa gestão, com certeza, pretendo criar sempre um dataset novo para cada compartilhamento que precisar ser feito, quase sempre será SMB-Only, pretendo ter as outras opções apenas por garantia. Mas se alguma configuração garantir uma vantagem maior, mesmo que eu tenha que manter o servidor apenas para compartilhamento SMB posso considerar criar um servidor para NFS separado, desde que a vantagem seja muito grande, o TruNAS oferece compartilhamento para os dois, como ele faz? Tem alguma opção de configuração superior a escolhida pelo TrueNAS para garantir compatibilidade e desempenho em ambiente com Windows e AD?

O TrueNAS consegue entregar SMB e NFS no mesmo dataset porque ele padroniza o dataset com ACLs **NFSv4** (no ZFS) e ajusta a integração do Samba para falar “bem” com ACLs desse tipo, além de oferecer presets de permissão pensados para multiprotocolo.[^9_1][^9_2]
No Debian, o caminho com maior chance de sucesso em ambiente Windows+AD é você tratar **SMB-only** como “primeira classe” (NT ACL em xattr via Samba) e oferecer NFS como exceção (idealmente em datasets separados), porque isso evita conflitos de semântica de ACL entre mundos.[^9_3]

## Como o TrueNAS faz (e o que copiar)

A documentação do TrueNAS SCALE descreve que ele oferece dois tipos de ACL: **POSIX** e **NFSv4**, e que o “Dataset Preset” define o tipo de ACL do dataset.[^9_1]
No lado Samba↔ZFS, o módulo `vfs_zfsacl` existe justamente para integração de ACLs com ZFS e fornece interfaces NFSv4 ACL; o próprio manpage recomenda que, para datasets “somente Samba”, `aclmode=restricted` e `aclinherit=passthrough` dão herança mais consistente com NTFS.[^9_2]

Em outras palavras: o TrueNAS “puxa” o dataset para um modelo de ACL rico (NFSv4) e tenta alinhar a herança/edição de permissões ao comportamento NTFS visto pelo Windows.[^9_2][^9_1]

## Melhor estratégia no Debian (alta compatibilidade com Windows/AD)

Para um servidor corporativo SMB integrado ao AD, a solução mais previsível no Debian é: ZFS com `acltype=posixacl` + `xattr=sa` (performance de xattr/ACL) e Samba com `vfs_acl_xattr` (ACL NT armazenada em xattr `security.NTACL`).[^9_3]
O `vfs_acl_xattr` foi feito para “full mapping” de ACL Windows e armazena as ACLs NTFS em `security.NTACL`; o manpage também explica que esse EA não aparece em `getfattr -d` e precisa ser consultado explicitamente com `getfattr -n security.NTACL`.[^9_3]
Para SMB-only, a própria documentação recomenda `acl_xattr:ignore system acls = yes` para melhor compatibilidade NT ACL, porque o Samba deixa de tentar fazer mapeamento best-effort com a camada POSIX.[^9_3]

## O que muda quando você adiciona NFS

Quando você precisa de acesso local/NFS com as *mesmas* permissões, o `vfs_acl_xattr` recomenda manter `acl_xattr:ignore system acls = no` (padrão), porque o Samba passa a definir e avaliar tanto ACLs do sistema quanto ACLs NT, o que é melhor para acesso local/NFS.[^9_3]
Isso normalmente reduz a “pureza NTFS” (e pode aumentar custo de metadados/ACL), então a solução com maior taxa de sucesso é exatamente o que você descreveu: **um dataset por share** e, quando NFS entrar, ele entra em dataset próprio com template próprio.[^9_3]
Se NFS for raro e só para “entrega a servidores”, separar datasets (ou até um host NFS separado) traz uma vantagem grande de **previsibilidade operacional**, mais do que um ganho bruto de throughput.

## Templates que eu recomendo

### Template SMB-only (padrão corporativo)

ZFS (dataset do share):

- `acltype=posixacl`
- `xattr=sa` (o manual descreve `xattr=sa` e recomenda fortemente esse modo para melhorar performance com `posixacl`)

Samba (por share):

```ini
vfs objects = acl_xattr
acl_xattr:ignore system acls = yes
```

`acl_xattr:ignore system acls = yes` é explicitamente sugerido para dados acessados somente via Samba, visando melhor compatibilidade NT ACL.[^9_3]

### Template NFS-only (para servidores Linux/Unix)

- Evite `acl_xattr` (não agrega valor ao NFS).
- Use permissões POSIX/ACL POSIX de forma “Linux first”.
- (Opcional) mantenha `acltype=posixacl` no dataset.


### Template SMB+NFS (somente quando inevitável)

Samba:

```ini
vfs objects = acl_xattr
acl_xattr:ignore system acls = no
```

Esse modo é documentado como melhor quando você precisa que ACLs do sistema funcionem para acesso local/NFS além do Samba.[^9_3]

ZFS:

- mantenha `acltype=posixacl` e `xattr=sa` para não degradar performance de metadados/ACL.


## Existe algo “superior” ao TrueNAS aqui?

Se você ficar em SMB-only, o conjunto ZFS (`xattr=sa` + `posixacl`) + Samba (`vfs_acl_xattr` com `ignore system acls = yes`) costuma ser o caminho mais direto para compatibilidade Windows no Linux, porque ele preserva ACL NTFS em `security.NTACL` e evita brigar com ACLs POSIX.[^9_3]
Já o modelo TrueNAS (ACL NFSv4 no dataset, com `aclmode`/`aclinherit` alinhados ao NTFS via `vfs_zfsacl`) é excelente para multiprotocolo quando sua plataforma realmente usa esse modelo de ACL como “fonte da verdade” no filesystem.[^9_1][^9_2]
No Debian, o que tende a ser “melhor” na prática é você tratar multiprotocolo como **exceção** e não como regra, porque isso reduz muito chamados de permissão e comportamento inesperado.[^9_3]

Você quer que a administração de permissões seja feita principalmente pelo Windows (aba Security/ACL NTFS) ou você precisa que admins Linux consigam ajustar permissões localmente com ferramentas POSIX e que isso reflita fielmente no Windows?
<span style="display:none">[^9_10][^9_11][^9_12][^9_13][^9_14][^9_15][^9_16][^9_17][^9_18][^9_19][^9_20][^9_21][^9_22][^9_23][^9_24][^9_25][^9_4][^9_5][^9_6][^9_7][^9_8][^9_9]</span>

<div align="center">⁂</div>

[^9_1]: https://www.truenas.com/docs/scale/scaletutorials/datasets/permissionsscale/

[^9_2]: https://forum.proxmox.com/threads/zfs-performance-tuning.27121/

[^9_3]: https://manpages.debian.org/bullseye/samba-vfs-modules/vfs_acl_xattr.8.en.html

[^9_4]: https://www.truenas.com/community/threads/home-directory-share-nfs-and-smb-how-to-set-acl-correctly.109879/

[^9_5]: https://www.truenas.com/community/threads/how-to-configure-nfsv4-smb-shares-with-proper-default-inheritable-new-file-directory-permissions.100884/

[^9_6]: https://www.reddit.com/r/truenas/comments/vuwezk/i_dont_understand_how_to_set_acl_for_a_smb_share/

[^9_7]: https://www.reddit.com/r/truenas/comments/119bh22/process_for_converting_a_dataset_acl_type_between/

[^9_8]: https://www.reddit.com/r/truenas/comments/snbpu3/truenas_acl_permissions_smb_share/

[^9_9]: https://www.samba.gr.jp/project/translation/current/htmldocs/manpages/vfs_zfsacl.8.html

[^9_10]: https://github.com/zfsonlinux/zfs/issues/170

[^9_11]: https://www.youtube.com/watch?v=FNhusHrAzA8

[^9_12]: https://fossies.org/linux/samba/docs/manpages/vfs_zfsacl.8

[^9_13]: https://github.com/openzfs/zfs/issues/4966

[^9_14]: https://www.youtube.com/watch?v=FNhusHrAzA8\&vl=en

[^9_15]: https://forums.freebsd.org/threads/samba-with-nfsv4-zfs-acl-support.17627/

[^9_16]: https://forum.proxmox.com/threads/acls-on-zfs-whats-the-right-way.106252/

[^9_17]: https://www.reddit.com/r/truenas/comments/13ow7v1/nfsv4_permissions_wont_work_for_smb_shares/

[^9_18]: https://docs.oracle.com/cd/E88353_01/html/E72487/vfs-zfsacl-8.html

[^9_19]: https://www.truenas.com/community/threads/smb-permissions-behaves-different-after-scale-22-02-3-22-02-4-upgrade.104448/

[^9_20]: https://www.truenas.com/community/threads/truenas-scale-smb-acl-permissions-dont-inherit.106105/

[^9_21]: https://www.truenas.com/community/threads/who-can-explain-aclmode-discard-passthrough-and-restricted-with-example.116509/

[^9_22]: https://forums.truenas.com/t/inherit-permissions-for-smb-share/11396

[^9_23]: https://www.truenas.com/docs/scale/scaletutorials/shares/addingnfsshares/

[^9_24]: https://www.reddit.com/r/truenas/comments/10j47yy/acl_does_not_seem_to_set_permissions_correctly/

[^9_25]: https://www.truenas.com/docs/scale/24.10/scaletutorials/datasets/permissionsscale/


---

# Seria ótimo poder fazer a configuração usando a aba Security do Windows, mas pretendo criar algum modo para fazer isso pelo linux também direto no servidor, não quero me fechar a apenas uma possibilidade para esse tipo de configuração, minha ideia agora é criar um servidor puramente para SMB, quero criar um sistema que seja o mais fiel possível ao windows, com o maior desempenho possível, considere que o servidor será full SMB e que NFS nunca será compartilhada junta com SMB, isso será a última opção de todas, tanto NFS puro, quanto NFS+SMB, serão tratadas como EXTREMA EXCEÇÃO. Forneça as instruções que devo fornecer via prompt ao meu agente LLM local, para reproduzir essa arquitetura que discutimos. Escreva como se fosse eu apresentando diretamente ao agente LLM, todas as instruções de arquitetura do projeto, bem como todas as instruções de customização e otimização, não esqueça de incluir a maneira de enviar as informações para o servidor secundário (vou usar sempre ATIVO+PASSIVO), minha ideia é garantir desempenho sobre hardware real, manter a VM como backup numa necessidade estrema, contudo quero configurar uma maneira de que essa delegação de servidor seja automática, entregue as instruções sobre a maneira de configurar esse envio de dados do servidor principal (FÍSICO) para o servidor de secundário (VIRTUAL).

Abaixo está um texto pronto (em formato de “prompt de projeto”) para você colar no seu agente LLM local e mandá-lo gerar a implementação e os arquivos. Ele assume **SMB-only como padrão**, NFS como exceção em datasets separados, e replica dados do físico para uma VM para failover **ativo+passivo**.

```text
Você é meu agente LLM local e deve atuar como arquiteto + engenheiro de implementação (Debian + ZFS + ZFSBootMenu + Samba/AD + HA). Entregue uma solução reproduzível via Debian live-build (ISO customizada) para um NAS corporativo SMB integrado ao Active Directory, com máximo desempenho e compatibilidade Windows.

OBJETIVO
- Servidor Debian “estilo TrueNAS SCALE”, porém Debian puro, dedicado a compartilhamentos SMB (Samba) com autenticação/ACL gerenciáveis via Windows (aba Security) e também por ferramentas no Linux quando necessário.
- Ambiente corporativo com muitos usuários concorrentes.
- Hardware físico: Dell PowerEdge 2950, 32 GiB RAM, 2× CPU 8 cores, controladora RAID Dell PERC (sem JBOD), 6× SAS 600 GiB 15k, NICs 1Gb + placa 10Gb dual.
- Boot padrão: ZFSBootMenu; em máquinas BIOS sem UEFI usar Syslinux apenas como “ponte” transparente para iniciar o ZFSBootMenu. (UEFI quando existir deve bootar ZFSBootMenu diretamente.)
- Foco: estabilidade + latência consistente + throughput alto em SMB.
- Exceções: NFS-only e SMB+NFS existirão como templates, mas serão raros e SEMPRE em datasets separados.

PRINCIPAIS DECISÕES DE ARQUITETURA (justificadas)
1) STORAGE/RAID (obrigatório por controladora):
   - Criar 1 (um) Virtual Disk na PERC usando todos os 6 discos em RAID10.
   - Motivo: RAID10 é o mais indicado quando o objetivo é o mais alto desempenho em random write (latência e previsibilidade), típico de workloads concorrentes como SMB corporativo. (Referência: recomendação de RAID policy da Dell.) [web:142]
   - Evitar RAID5 em dados críticos; a Dell desaconselha RAID5 para business-critical. [web:142]
   - Se a controladora permitir Write-Back com proteção (BBU/CacheVault), habilitar Write-Back; caso contrário, operar em Write-Through e ajustar expectativas de performance. (Write-Through vs Write-Back: descrição Dell.) [web:193]
   - Eu NÃO quero dividir discos em 2 VDs (SO vs dados), porque sacrificaria capacidade e complexificaria; vou separar via datasets e boot environments no ZFS.

2) ZFS em cima de hardware RAID (aceito a limitação):
   - Aceito que ZFS não verá discos individuais; usarei ZFS para integridade (checksums), snapshots, boot environments e gerenciamento, e a redundância física estará no RAID10 do controlador.

3) Layout ZFS e Boot Environments com ZFSBootMenu:
   - Usar 1 pool (ex.: tank) no VD RAID10, com:
     - dataset para ROOT/boot environments (ex.: tank/ROOT/debian)
     - dataset separado para estado Samba/AD (ex.: tank/SYS/samba-state)
     - datasets separados para shares (ex.: tank/SHARES/<nome_share>)
   - Regras:
     - Cada Boot Environment deve corresponder a exatamente 1 filesystem (um dataset), para snapshots/rollbacks consistentes. [web:159]
     - O dataset de “estado Samba/AD” deve ser separado do ROOT para não ser revertido em rollback de BE.
   - Configurar ZFSBootMenu para preferir o pool explicitamente com zbm.prefer=<pool>! para não depender de ordem/heurística em máquinas com múltiplos pools. [web:60]

4) ZFS otimizado para SMB/ACL
   - Para datasets de share SMB-only aplicar:
     - acltype=posixacl (habilita ACL POSIX no dataset). [page:0]
     - xattr=sa (ZFS armazena xattrs em system attributes e o manual recomenda fortemente esse modo para performance com posixacl). [page:0]
     - atime=off
     - compressão “leve” (defina no template; eu validarei em benchmark)
   - NÃO habilitar dedup por padrão; o manual do ZFS adverte que dedup é caro e pode causar problemas graves se mal dimensionado. [page:0]
   - NÃO alterar recordsize “no escuro”; o manual alerta que mudar recordsize em FS de uso geral é desencorajado e pode piorar performance. [page:0]

5) Samba + AD (member server) com ACL Windows fiel
   - O servidor será membro do domínio AD (security=ADS + Kerberos) e autenticará via AD.
   - Para ACL Windows fiel em SMB-only:
     - Usar módulo vfs_acl_xattr; ele armazena ACL NTFS em EA security.NTACL para full mapping de ACL Windows. [web:95]
     - Definir acl_xattr:ignore system acls = yes para o perfil SMB-only, pois é recomendado quando dados são acessados somente via Samba, visando melhor compatibilidade NT ACL. [web:190]
   - Manter capacidade de administrar ACL também via Linux:
     - Usar smbcacls para ler/escrever ACLs NT em shares SMB (é uma ferramenta do Samba para manipular NT ACLs em compartilhamentos SMB). [web:240]
     - Usar samba-tool ntacl (possui subcomandos “Manage NT ACLs”, incluindo ntacl get e ntacl set). [web:245]
   - Observação operacional: quando necessário um nome de serviço diferente (alias/VIP), registrar SPN cifs/<alias> no AD para Kerberos funcionar com alias; há evidência de que adicionar cifs/<alias> SPN resolve acesso Kerberos a CNAME/alias. [web:232]

6) SMB performance de rede (10GbE)
   - Habilitar SMB Multichannel no Samba e validar no Windows, pois SMB Multichannel aumenta performance e redundância com múltiplas conexões. (Documentação Microsoft sobre SMB Multichannel.) [web:164]
   - Desabilitar SMBv1 no servidor; manter SMB2/SMB3 (Microsoft documenta detecção/controle de SMBv1/2/3). [web:167]

7) Replicação para servidor secundário (VM) e failover automático (ativo+passivo)
   - Eu quero replicar dados do físico (primário) para uma VM (secundário), onde a VM fica standby e assume automaticamente em falha do físico.
   - A replicação será feita por snapshots + zfs send/receive incremental, de forma automatizada e “policy-driven”.
   - Preferência de ferramenta: Sanoid/Syncoid para snapshots e replicação (Syncoid: ferramenta de replicação no ecossistema Sanoid). [web:236]
   - O failover automático será via cluster (Pacemaker/Corosync) em 2 nós, com um Virtual IP e start/stop ordenado de serviços (modelo ativo/passivo com IP virtual é padrão em guias de HA). [web:237]
   - Requisito: STONITH/fencing real e testado; sem isso, cluster/auto-failover não é considerado pronto para produção.

ENTREGÁVEIS (o que você deve gerar)
A) Um “design doc” curto com:
   - diagrama lógico (texto) das camadas: RAID10 VD -> ZFS pool -> datasets -> Samba/Winbind -> AD
   - política de datasets/templates: SMB-only padrão, NFS-only e SMB+NFS como exceção
   - plano de testes (fio + diskspd + testes de ACL)
   - plano de falhas (poweroff, queda de rede, falha de host) e critérios de aceite

B) Um repositório de build do Debian live-build (estrutura de diretórios) contendo:
   - lista de pacotes (ZFS, ZFSBootMenu, Samba, Winbind, Kerberos, Chrony, ferramentas de benchmark/monitoramento)
   - config/includes.chroot com:
     - /etc/sysctl.d/ tuning
     - /etc/samba/smb.conf (template SMB-only padrão)
     - /etc/krb5.conf (template, sem segredos)
     - units systemd customizadas
   - hooks do live-build para:
     - habilitar serviços systemd necessários
     - criar datasets padrão e setar propriedades ZFS nos templates
     - preparar ZFSBootMenu e, em BIOS, Syslinux “ponte” para ZFSBootMenu

C) Scripts idempotentes (com logs) para:
   1) First-boot wizard (sem hardcode de senha):
      - configurar hostname, DNS (apontando DC), timezone
      - habilitar e validar sincronismo de tempo (Chrony/NTP), pois Kerberos depende de relógio sincronizado (tolerância típica 5 min/300s). [web:174]
      - ingressar no domínio AD
      - criar keytab e validar kinit
      - validar winbind (wbinfo) e listar usuários/grupos
      - criar share dataset (tank/SHARES/<share>) e aplicar propriedades do template SMB-only (acltype=posixacl, xattr=sa, etc.) [page:0]
      - habilitar SMB Multichannel e reiniciar serviços, depois instruir validação em cliente Windows [web:164]

   2) Replicação física -> VM (assíncrona, incremental):
      - Política de snapshots no físico: horários (ex.: 15min/1h/dia) com retenção (ex.: 2 dias/4 semanas/6 meses)
      - Syncoid via SSH do físico para a VM:
        - replicar tank/SHARES e também tank/SYS/samba-state (para manter credenciais/estado quando a VM assumir)
        - replicação recursiva e incremental
      - Rotina de verificação:
        - checar último snapshot replicado
        - checar consistência do receive side
        - alertar se atraso de replicação exceder RPO

   3) Failover automático ativo+passivo (Pacemaker/Corosync):
      - Recursos gerenciados:
        - Virtual IP (VIP) “filesvc” (IP fixo para clientes)
        - Import/mount ZFS do lado ativo (no nó que estiver servindo)
        - Start de winbind/smbd (apenas no ativo)
      - Ordem obrigatória: VIP -> ZFS mount -> Samba/Winbind.
      - No failover:
        - garantir nó antigo está “dead” via fencing
        - promover nó standby para ativo
        - levantar VIP e serviços
      - Considerar Kerberos com nome de serviço:
        - clientes acessam via DNS “filesvc.seudominio”
        - registrar SPNs cifs/filesvc e cifs/filesvc.seudominio no AD para o machine account do Samba (para Kerberos funcionar com alias). [web:232]
      - Testes de validação pós-failover:
        - autenticação Kerberos em share
        - leitura/escrita
        - ACLs via Windows Security

D) Arquivos de configuração (conteúdos completos) que você deve produzir
1) Exemplo de /etc/samba/smb.conf (SMB-only) com:
   - security = ADS + realm + workgroup
   - winbind e idmap coerentes
   - desabilitar SMB1 (min protocol >= SMB2) [web:167]
   - habilitar multichannel (server multi channel support = yes) e orientar validação [web:164]
   - vfs objects = acl_xattr + acl_xattr:ignore system acls = yes [web:190]
   - parâmetros de performance (socket options NÃO agressivos por padrão; use defaults modernos)
2) Exemplo de templates de share:
   - template SMB-only (default)
   - template NFS-only (exceção)
   - template SMB+NFS (exceção extrema)
3) sysctl tuning (conservador, voltado a NAS)
4) systemd units:
   - zfs-mount order (dependências)
   - samba dependente de zfs mount
   - serviços de replicação (timer)
5) Documentação de uso de smbcacls e samba-tool ntacl:
   - como ler ACL de um caminho
   - como aplicar ACL (exemplo) [web:240][web:245]

REGRAS DE QUALIDADE
- Tudo precisa ser reproduzível: sem etapas manuais “escondidas”.
- Nada deve armazenar credenciais na ISO; first-boot wizard pede credenciais ou usa um mecanismo seguro.
- Cada script deve ser idempotente e registrar logs.
- Incluir checklist de troubleshooting (DNS, NTP, Kerberos, winbind, performance, ZFS health).
- Incluir plano de benchmark:
  - fio local para medir limite do storage
  - diskspd em cliente Windows para medir experiência SMB
  - medir p95/p99 latência de escrita e browse/listing

INFORMAÇÕES QUE VOCÊ DEVE ME PEDIR (perguntas finais no output)
- Nome do domínio/realm
- IPs dos DCs/DNS
- IP do VIP e interface usada (10Gb)
- Nome do pool ZFS (tank) e datasets
- RPO desejado (atraso máximo aceitável da replicação)
- Estratégia de idmap (RID/AUTORID ou RFC2307)
- Se a PERC terá BBU/CacheVault habilitando write-back

Agora gere:
1) design doc
2) árvore do projeto live-build + arquivos
3) scripts first-boot, replication, pacemaker
4) configs completos (smb.conf, krb5.conf template, sysctl, systemd units)
5) plano de testes e aceitação
```

Se quiser, eu também posso adaptar esse prompt para ficar “mais executável” (com placeholders padronizados e um checklist que seu agente deve preencher) e incluir um conjunto mínimo de testes automatizados (ex.: um `make verify` que roda validações de DNS/NTP/AD, checa propriedades ZFS e faz um smoke test de SMB).
<span style="display:none">[^10_1][^10_10][^10_11][^10_12][^10_13][^10_14][^10_15][^10_16][^10_17][^10_18][^10_19][^10_2][^10_20][^10_21][^10_22][^10_23][^10_24][^10_25][^10_26][^10_27][^10_28][^10_29][^10_3][^10_30][^10_4][^10_5][^10_6][^10_7][^10_8][^10_9]</span>

<div align="center">⁂</div>

[^10_1]: https://github.com/jimsalterjrs/sanoid/issues/629

[^10_2]: https://www.reddit.com/r/zfs/comments/mwaxpb/a_few_questions_about_send_recv_existing/

[^10_3]: https://forums.freebsd.org/threads/frequent-incremental-zfs-backup-problems.87187/

[^10_4]: https://discourse.practicalzfs.com/t/syncoid-no-rollback-usage/2144

[^10_5]: https://discourse.practicalzfs.com/t/syncoid-target-does-not-match-incremental-source/1554

[^10_6]: https://oss.clusterlabs.org/pipermail/pacemaker/2012-January/012731.html

[^10_7]: https://www.reddit.com/r/sysadmin/comments/18veruv/aliases_and_spns_in_the_dmz/

[^10_8]: https://www.reddit.com/r/zfs/comments/rnsf4w/zfs_backups_sanoid_and_syncoid_help/

[^10_9]: https://documentation.suse.com/pt-br/sle-ha/15-SP6/html/SLE-HA-all/article-nfs-storage.html

[^10_10]: https://www.spinics.net/lists/samba/msg173688.html

[^10_11]: https://www.reddit.com/r/zfs/comments/10coexx/minimum_zfs_delegated_permissions_for_syncoid/

[^10_12]: https://forum.proxmox.com/threads/pathfinder4diy-pve-and-high-performance-zfs-over-iscsi-storage-with-high-availability-active-passiv-via-tcp-or-rdma-on-commodity-hw.171582/

[^10_13]: https://www.reddit.com/r/activedirectory/comments/1m7ye9l/how_to_configure_spn_for_cifs_in_case_clients_are/

[^10_14]: https://github.com/jimsalterjrs/sanoid/wiki/Syncoid

[^10_15]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/configuring_and_managing_high_availability_clusters/configuring-active-passive-http-server-in-a-cluster

[^10_16]: https://helgeklein.com/blog/samba-file-server-with-windows-acls-in-a-docker-container/

[^10_17]: https://community.nethserver.org/t/samba-acl-setfacl/26516

[^10_18]: https://manpages.ubuntu.com/manpages/bionic/en/man1/smbcacls.1.html

[^10_19]: https://groups.google.com/g/linux.samba/c/udfxCU-cPyc

[^10_20]: https://github.com/samba-team/samba/blob/master/source3/utils/smbcacls.c

[^10_21]: https://manpages.opensuse.org/Leap-15.6/samba/vfs_acl_xattr.8.en.html

[^10_22]: https://groups.google.com/g/linux.samba/c/0z4i6HIfrfk

[^10_23]: https://github.com/avati/samba/blob/master/source3/utils/smbcacls.c

[^10_24]: https://manpages.debian.org/bullseye/samba-common-bin/samba-tool.8.en.html

[^10_25]: https://docs.oracle.com/cd/E88353_01/html/E72487/vfs-acl-xattr-8.html

[^10_26]: https://manpages.debian.org/experimental/samba-common-bin/samba-tool.8.en.html

[^10_27]: https://docs.redhat.com/pt-br/documentation/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/proc_enabling-windows-acl-support_assembly_setting-up-a-share-that-uses-windows-acls

[^10_28]: https://manpages.ubuntu.com/manpages/jammy/man8/samba-tool.8.html

[^10_29]: https://groups.google.com/g/linux.samba/c/fY1UQmiXFbk

[^10_30]: https://code.tools/man/8/samba-tool/


---

# Com certeza vou precisar disso, quero ajudar ao máximo meu agente local, garantindo o máximo de informação de qualidade, para que não tenha que gastar janela de contexto com pesquisas na internet buscando entender algum passo ou para tomada de decisão. Observei que no "vfs objects" não foi citado nenhum com o nome ZFS, como é no TrueNAS, incluí-los não traria mais desempenho ao SAMBA para trabalhar com o ZFS? Se esta maneira é mais performática e garante maior desempenho, ficamos com essa opção mesmo.

Respondendo sua dúvida a controladora RAID consegue fazer whriteback.
Tenho a intenção de entregar esse prompt que acaba de entregar, pois está muito bem detalhado, considere o próximo prompt uma continuação dessa interação,  ou defina outra estratégia melhor para manter, na intenção de garantir a qualidade máxima da informação para o projeto. Ele deve possuir qualidade nível PROFISSIONAL PREMIUM. Se for preciso, forneça artefatos que posso salvar no diretório do projeto, depois referenciá-los.
O projeto já foi iniciado, já tenho um ambiente funcional para criação da imagem, usando live-build dentro de um docker com "debian:trixie-slim". Tenho uma imagem gerada com um Debian Trixie básico, com um instalador customizado em shell script, já que o instalador oficial do Debian não oferece opção de instalação sobre ZFS por padrão. A agente LLM precisa ajustar alguns detalhes ainda, como incluir o recurso de multi seleção de discos, para permitir todos os tipos de vdevs suportados pelo ZFS (stripe, mirror, raidz1, raidz2, raidz3, draid, slog, l2arc, special, dedup, spere) apenas para que a ISO esteja preparada para essas possibilidades no futuro em outro equipamento.

No Debian com OpenZFS, **incluir `zfsacl` nos `vfs objects` normalmente não traz ganho de desempenho para SMB-only**; ele é um módulo voltado principalmente a interfaces de ACL NFSv4 no ZFS e a ajustar semântica de herança/ACL, não um “acelerador” de I/O.[^11_1]
Além disso, no TrueNAS SCALE há casos em que `zfsacl`/`zfs_space` aparecem como “não permitidos” em shares SMB, o que na prática indica que essa pilha não é a escolhida/validada ali (o SCALE acaba usando outra estratégia de ACL/integração).[^11_2]

## Quais `vfs objects` usar (SMB-only com Windows/AD)

Para o seu perfil “Windows-first, SMB-only”, a combinação mais útil costuma ser:

- `acl_xattr`: guarda ACL NTFS no xattr `security.NTACL` e permite “full mapping” das ACLs do Windows; o próprio manpage documenta `acl_xattr:ignore system acls` e recomenda `yes` quando os dados são acessados somente via Samba (caso SMB-only).[^11_3]
- `streams_xattr`: implementa NTFS Alternate Data Streams (ADS) gravando-os em xattrs POSIX (por padrão `user.DosStream."ADS-NAME"`), o que evita perda de metadados/streams em cópias e melhora compatibilidade com certos fluxos de aplicação Windows.[^11_4]

Template recomendado (por share SMB-only):

```ini
[share]
   path = /mnt/tank/SHARES/share
   read only = no

   vfs objects = acl_xattr streams_xattr
   acl_xattr:ignore system acls = yes
```

O comportamento e objetivo de `acl_xattr` (incluindo `ignore system acls`) e de `streams_xattr` (ADS em xattrs) estão descritos nos respectivos manpages.[^11_4][^11_3]

### E o `zfsacl` “do TrueNAS”?

O `vfs_zfsacl` existe e o manpage diz que ele fornece interfaces de ACL NFSv4 e recomenda `aclmode=restricted` + `aclinherit=passthrough` para datasets destinados somente a shares Samba (herança mais parecida com NTFS).[^11_1]
Só que isso faz sentido principalmente quando você está realmente operando com ACL NFSv4 no ZFS (o ZFS expõe `acltype=nfsv4` como opção) e quer acoplar essa semântica com o Samba.[^11_1]
Como você quer SMB-only em Debian/OpenZFS e também quer editar via Windows *e* via Linux sem entrar em um “labirinto de semântica”, a rota mais previsível é **`acl_xattr + streams_xattr` + dataset com `xattr=sa` e `acltype=posixacl`**.[^11_3]

## ZFS dataset “padrão SMB” (o que fixar)

No dataset do share, fixe pelo menos:

- `acltype=posixacl` (habilita ACL POSIX)
- `xattr=sa` (o manual recomenda fortemente esse modo para performance quando `posixacl` está ativo)

Exemplo:

```bash
zfs create tank/SHARES/financeiro
zfs set acltype=posixacl tank/SHARES/financeiro
zfs set xattr=sa tank/SHARES/financeiro
zfs set atime=off tank/SHARES/financeiro
```

As propriedades `acltype` e `xattr` e a recomendação de `xattr=sa` com `posixacl` estão no `zfs(8)`.

## Controladora RAID: write-back (ótimo, com ressalvas)

Write-back **melhora muito** o comportamento de escrita percebido pelo host porque a controladora confirma a escrita quando os dados entram no cache e depois drena para disco em background; já write-through só confirma após o disco receber os dados.[^11_5]
A mesma referência deixa claro o risco: write-back sem preservação de cache/energia pode perder dados em queda de energia, então trate “write-back” como válido apenas com proteção (BBU/CacheVault) saudável e política correta.[^11_5]

## “Prompt contínuo” (premium) — estratégia melhor do que um único prompt gigante

Em vez de um único prompt enorme crescendo indefinidamente, use um **Prompt Pack** com artefatos versionados no seu repositório, e um prompt “curto” que diz ao agente local: “leia estes arquivos como fonte da verdade e implemente”. Isso reduz gasto de janela de contexto e melhora consistência.

Crie estes arquivos no diretório do projeto (para o agente referenciar):

1) `docs/00_SOURCE_OF_TRUTH.md`

- Decisões fixas: RAID10 no PERC, 1 VD, 1 pool, datasets separados, SMB-only default, ZFSBootMenu padrão, Syslinux ponte em BIOS.

2) `docs/10_SMB_STACK.md`

- `vfs objects = acl_xattr streams_xattr`, `acl_xattr:ignore system acls=yes` (SMB-only), e quando mudar para `no` (apenas no template SMB+NFS).[^11_4][^11_3]

3) `docs/20_ZFS_DATASET_TEMPLATES.md`

- Template “SMB-only”: `acltype=posixacl`, `xattr=sa`, `atime=off`, compressão leve.

4) `docs/30_AD_JOIN_AND_ALIAS.md`

- Checklist DNS/NTP/Kerberos e nota de alias/SPN: se for usar VIP/alias DNS (ex.: `filesvc.dominio`), registrar SPNs `cifs/<alias>` para Kerberos funcionar com alias.[^11_6][^11_7]

5) `docs/40_FAILOVER_REPLICATION.md`

- Replicação por snapshots + `zfs send/receive` (via syncoid) para VM standby; failover ativo+passivo via Pacemaker/Corosync + VIP.[^11_8][^11_9]

6) `artifacts/templates/smb/smb.conf.smb-only.template`

- Seu template final do Samba (SMB-only), com `acl_xattr`, `streams_xattr`, SMB2/3, multichannel etc.[^11_10][^11_11][^11_3][^11_4]

7) `artifacts/installer/vdev_planner_spec.json`

- Especificação do “planejador de vdev” do seu instalador (UI/validações), para o agente implementar sem pesquisar.


## Prompt de continuação (cole no seu agente local)

Abaixo está um “Prompt 2” para você usar como continuação do anterior, focado em (a) VFS ZFS/TrueNAS, (b) write-back, (c) melhorias do instalador (multi-seleção e vdev planner), (d) estrutura de artefatos.

```text
CONTINUAÇÃO — IMPLEMENTAÇÃO PREMIUM (sem pesquisas externas)

Contexto: Projeto Debian remaster (Trixie) via live-build em docker debian:trixie-slim. Já existe ISO gerando um Debian básico + instalador custom em shell (porque Debian não instala ZFS root por padrão). Agora preciso elevar qualidade e completude.

1) Samba VFS objects e ZFS
- Atualize as recomendações de vfs objects para meu cenário SMB-only Windows/AD:
  - Use: vfs objects = acl_xattr streams_xattr
  - Use: acl_xattr:ignore system acls = yes (SMB-only)
  - Justifique tecnicamente com base nos manpages: acl_xattr armazena NT ACL em security.NTACL; streams_xattr implementa NTFS ADS em xattrs. [web:190][web:263]
- NÃO adicionar vfs_zfsacl por padrão: ele é orientado a interfaces NFSv4 ACL e não é um “otimizador de performance”; além disso há evidência prática de que no TrueNAS SCALE zfsacl/zfs_space não são permitidos em shares SMB. [web:208][web:254]
- Gerar três templates:
  - SMB-only (default): acl_xattr + streams_xattr + ignore system acls = yes
  - NFS-only (exceção): sem acl_xattr
  - SMB+NFS (exceção extrema): acl_xattr + ignore system acls = no [web:190]
- Criar artifacts/templates/smb/ com smb.conf completo + includes por share (um arquivo por share).

2) ZFS dataset templates
- Para SMB-only, o dataset do share deve aplicar:
  - acltype=posixacl
  - xattr=sa (fortemente recomendado para performance com posixacl)
  - atime=off
- Não habilitar dedup; não mexer em recordsize sem benchmark. [page:0]

3) Controladora RAID / desempenho
- Presumir write-back disponível e habilitar write-back seguro (com proteção BBU/CacheVault) como requisito.
- Documentar em docs/00_SOURCE_OF_TRUTH.md a exigência de write-back seguro e como validar (health da bateria/cache).
- Referenciar definição de write-through vs write-back conforme documentação Dell. [web:193]

4) Live-build: artefatos e layout (criar arquivos no repo)
Crie estes arquivos no repo:
- docs/00_SOURCE_OF_TRUTH.md
- docs/10_SMB_STACK.md
- docs/20_ZFS_DATASET_TEMPLATES.md
- docs/30_AD_JOIN_AND_ALIAS.md (inclui NTP/clock skew e SPNs cifs/<alias> para VIP) [web:174][web:232]
- docs/40_FAILOVER_REPLICATION.md (syncoid + pacemaker/corosync A/P) [web:236][web:237]
- artifacts/templates/smb/smb.conf.smb-only.template
- artifacts/templates/smb/smb.conf.smb+nfs.template
- artifacts/templates/nfs/exports.template
- artifacts/installer/vdev_planner_spec.json

5) Instalador: multi seleção e “Vdev Planner”
Ajuste o instalador custom em shell:
- Implementar “multi-seleção de discos” (TUI: whiptail/dialog).
- Implementar um “planejador de vdev” com validações:
  - stripe: >=1 disco
  - mirror: >=2 discos, preferível número par
  - raidz1: >=3
  - raidz2: >=4
  - raidz3: >=5
  - draid: exigir parâmetros (data/parity/spares) e validações mínimas
  - spare: 1+ discos
  - slog: 1+ (espelhado recomendado se usado)
  - l2arc: 1+
  - special: 1+ (espelhado recomendado) — marcar como opcional
  - dedup: NÃO tratar como vdev; tratar como “property/policy” com alerta forte, e só permitir se houver special vdev e RAM suficiente
- Gerar automaticamente os comandos zpool/zfs (dry-run + apply), e registrar em /var/log/installer-zfs.log.
- Atenção: neste hardware específico (PERC sem JBOD) provavelmente só existirá 1 block device do VD; o planejador precisa detectar isso e avisar “modo controller-RAID: sem vdev multi-disco no ZFS”.

6) Replicação + Failover ativo/passivo (Físico -> VM)
- Implementar replicação por snapshots + syncoid sobre SSH:
  - datasets replicados: tank/SHARES (recursivo) + tank/SYS/samba-state (para manter estado/metadata de AD/Samba)
  - timers systemd: snapshot + sync
  - relatórios: último snapshot replicado, atraso atual (RPO)
- Implementar cluster A/P (Pacemaker/Corosync):
  - recursos: VIP + import/mount ZFS + start winbind/smbd
  - ordem: VIP -> ZFS mount -> samba
  - requisito: fencing obrigatório e testado (documentar opções possíveis)
- Documentar SPN de alias/VIP para Kerberos: registrar cifs/<alias> e cifs/<alias.fqdn>. [web:232]

7) SMB Multichannel
- Incluir opção no template global: habilitar multichannel.
- Documentar validação no Windows (Get-SmbMultichannelConnection).
- Referenciar docs MS sobre SMB Multichannel. [web:164]

Agora gere:
- conteúdo completo dos arquivos listados
- patches ou pseudocódigo para o instalador (shell) com funções e validações
- exemplos de unit files systemd e timers para replicação
- exemplos de configuração Pacemaker (crmsh pcs ou raw CIB)
- checklist de testes (fio local + diskspd do Windows + validação AD + validação ACL via Windows Security)
```


## Nota final: “vfs_zfsacl” e o que vale a pena copiar do TrueNAS

O “ganho” do TrueNAS com módulos ZFS no Samba costuma estar mais ligado a **modelo de ACL e herança** do que a throughput puro; o manpage do `vfs_zfsacl` fala justamente de interfaces NFSv4 ACL e de ajustar `aclmode/aclinherit` para comportamento parecido com NTFS.[^11_1]
Para o seu objetivo SMB-only com máxima compatibilidade Windows/AD, o que tende a dar retorno real é: **write-back protegido na PERC**, `xattr=sa` no ZFS, `acl_xattr + streams_xattr` no Samba, e (se usar VIP/alias) SPNs corretos para Kerberos.[^11_6][^11_3][^11_5][^11_4]

Quer que eu inclua no prompt do agente um `smb.conf` base já “Windows-first” (SMB2/3 only, multichannel, tuning conservador) e um script de validação automatizada (DNS/NTP/Kerberos/winbind/ACL smoke test)?
<span style="display:none">[^11_12][^11_13][^11_14][^11_15][^11_16][^11_17][^11_18][^11_19][^11_20][^11_21][^11_22][^11_23][^11_24][^11_25][^11_26][^11_27][^11_28][^11_29][^11_30][^11_31][^11_32][^11_33][^11_34][^11_35]</span>

<div align="center">⁂</div>

[^11_1]: https://fossies.org/linux/samba/docs/manpages/vfs_zfsacl.8

[^11_2]: https://www.truenas.com/community/threads/zfsacl-is-not-a-permitted-vfs-object-on-scale-migration-core-to-scale.99381/

[^11_3]: https://manpages.debian.org/bullseye/samba-vfs-modules/vfs_acl_xattr.8.en.html

[^11_4]: https://docs.oracle.com/cd/E88353_01/html/E72487/vfs-streams-xattr-8.html

[^11_5]: https://www.dell.com/community/en/conversations/poweredge-hddscsiraid/perc-write-caching-option-and-its-interaction-with-os-level-drive-caching/647f1902f4ccf8a8debdc3db

[^11_6]: https://www.spinics.net/lists/samba/msg173688.html

[^11_7]: https://docs.oracle.com/cd/E23824_01/html/821-1456/setup-192.html

[^11_8]: https://github.com/jimsalterjrs/sanoid/wiki/Syncoid

[^11_9]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/configuring_and_managing_high_availability_clusters/configuring-active-passive-http-server-in-a-cluster

[^11_10]: https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3

[^11_11]: https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/manage-smb-multichannel

[^11_12]: https://www.truenas.com/community/threads/samba-share-improper-inheritance-ixnas-vs-zfsacl-on-macos.107059/

[^11_13]: https://www.truenas.com/community/threads/default-vfs-objects-for-a-windows-smb-shares-have-changed-are-different-in-11-3-u1.82693/

[^11_14]: https://www.truenas.com/community/threads/11-3-to-12-upgrade-prep-samba-vfs-objects-zfs_space-zfsacl-ixnas.89427/

[^11_15]: https://www.truenas.com/community/threads/question-on-acl-for-smb-share.79798/

[^11_16]: https://forums.freebsd.org/threads/zfs-samba-performance-issue.20476/

[^11_17]: https://forums.freebsd.org/threads/samba-with-nfsv4-zfs-acl-support.17627/

[^11_18]: https://www.ixsystems.com/documentation/truenas/11.3-U2.2/sharing.html

[^11_19]: https://docs.oracle.com/cd/E88353_01/html/E72487/vfs-zfsacl-8.html

[^11_20]: https://www.youtube.com/watch?v=DeXNFUzpeFI

[^11_21]: https://www.samba.gr.jp/project/translation/current/htmldocs/manpages/vfs_zfsacl.8.html

[^11_22]: https://groups.google.com/g/mailing.unix.samba/c/NCFFsvv1Sq8

[^11_23]: https://www.reddit.com/r/truenas/comments/qsulh2/is_there_a_smb_setup_guide_for_scale/

[^11_24]: https://www.samba.gr.jp/project/translation/4.14/htmldocs/manpages/vfs_zfsacl.8.html

[^11_25]: https://www.mankier.com/package/samba

[^11_26]: https://manpages.debian.org/testing/samba-vfs-modules/vfs_fruit.8.en.html

[^11_27]: https://docs.oracle.com/cd/F16635_01/html/E72377/vfs-streams-xattr-8.html

[^11_28]: https://www.samba.gr.jp/project/translation/4.4/htmldocs/manpages/vfs_streams_xattr.8.html

[^11_29]: https://groups.google.com/g/linux.samba/c/_YN7KG-NlL4

[^11_30]: https://www.samba.gr.jp/project/translation/current/htmldocs/manpages/vfs_streams_xattr.8.html

[^11_31]: https://forum.openmediavault.org/index.php?thread%2F10598-alternate-data-streams-ads-samba-4%2F

[^11_32]: https://stackoverflow.com/questions/58496277/samba-4-10-server-config-using-module-vfs-fruit-changes-file-creation-mask-fo

[^11_33]: https://stackoverflow.com/questions/66488533/sambav-4-10-16-win10-cant-open-the-files-like-xlsx-pptx-that-has-set-exten

[^11_34]: https://www.truenas.com/community/threads/table-10-4b-available-vfs-modules-is-missing-some-parameters.39107/

[^11_35]: https://www.ixsystems.com/documentation/freenas/11.3-U2/sharing.html


---

# sim

Sim — abaixo vão (1) um `smb.conf` base “Windows-first” (SMB-only, AD, ACL NT fiel, ADS/streams) e (2) um script de validação automatizada (DNS/NTP/Kerberos/Winbind/Samba/ACL smoke test), além de um “Prompt 3” pronto para você colar no seu agente local como continuação.

## VFS “ZFS” no Samba

No seu caso **SMB-only**, o módulo que mais entrega compatibilidade Windows de forma previsível é `acl_xattr` (NT ACL em xattr `security.NTACL`) e, para compatibilidade com Windows (especialmente metadados), `streams_xattr` para Alternate Data Streams (ADS) via xattrs.[^12_1][^12_2]
O `vfs_zfsacl` existe, mas ele é voltado principalmente a interfaces de ACL NFSv4 no ZFS e a ajustar herança/semântica (ex.: recomendação de `aclmode=restricted` e `aclinherit=passthrough` para shares Samba), não sendo “upgrade de performance” para SMB-only.[^12_3]
Como você vai tratar NFS como exceção (em dataset separado), a estratégia mais robusta é **não** acoplar seu SMB à semântica NFSv4 ACL via `zfsacl` no perfil padrão.[^12_3]

## Artefatos para salvar

Salve estes arquivos no seu repositório (paths sugeridos) e diga ao seu agente local para tratá-los como “fonte da verdade”:

- `artifacts/templates/smb/smb.conf.smb-only.template` (abaixo)
- `artifacts/scripts/validate_ad_smb.sh` (abaixo)
- `artifacts/docs/windows_validate_multichannel.md` (abaixo)


## `smb.conf` base (SMB-only, Windows-first)

> Arquivo: `artifacts/templates/smb/smb.conf.smb-only.template`

```ini
# SMB-only / Windows-first / AD member
# Requer: DNS e tempo corretos (Kerberos), join no domínio, winbind funcional.

[global]
   server role = member server
   security = ADS
   realm = EXEMPLO.COM
   workgroup = EXEMPLO

   kerberos method = secrets and keytab

   # SMB1 é legado/inseguro; force SMB2/3.
   # Nota: Samba chama SMB1 de "NT1" em várias configs/históricos.
   server min protocol = SMB2
   server max protocol = SMB3

   # Multi-channel (SMB3): aumenta throughput e tolerância a falha quando há múltiplas NICs/paths.
   # No Samba, habilite multichannel e AIO; AIO é frequentemente recomendado para alimentar múltiplos links.
   server multi channel support = yes
   aio read size = 1
   aio write size = 1

   # Interfaces: ajuste conforme seu ambiente (recomendado em servidores multi-homed).
   # Exemplo:
   # interfaces = 10.0.10.0/24 10.0.20.0/24
   # bind interfaces only = yes

   # Logs
   log file = /var/log/samba/log.%m
   logging = file
   max log size = 5000

   # Winbind (AD)
   winbind use default domain = yes
   winbind enum users = no
   winbind enum groups = no
   winbind refresh tickets = yes
   winbind offline logon = yes

   # Idmap (ajuste conforme sua estratégia; AUTORID é bom p/ não-RFC2307, mas defina ranges)
   idmap config * : backend = autorid
   idmap config * : range = 1000000-19999999
   idmap config * : rangesize = 1000000

   # Compatibilidade/performance gerais
   load printers = no
   disable spoolss = yes

   # ACL Windows fiel (SMB-only)
   vfs objects = acl_xattr streams_xattr
   acl_xattr:ignore system acls = yes

   # Streams/ADS via xattr (streams_xattr). (Sem isso, ADS podem se perder em certas cópias).
   # A implementação grava ADS em xattrs user.DosStream."NOME". (Conforme manpage do módulo).
   # Nenhuma opção extra é obrigatória para o básico.

   # Recomendações de segurança
   # (Se você usar assinatura/cripto SMB, habilite conforme política do domínio.)
   # server signing = default
   # smb encrypt = desired

[SHARE_EXEMPLO]
   path = /mnt/tank/SHARES/SHARE_EXEMPLO
   read only = no

   # Crie um dataset por share e gerencie ACL pelo Windows (Security tab) como padrão.
   # Se precisar administrar ACL via Linux, use smbcacls/samba-tool (ver docs e script de validação).
```

Notas (para você colocar como comentário no doc do projeto):

- `acl_xattr` armazena ACL NT no xattr `security.NTACL` e o parâmetro `acl_xattr:ignore system acls = yes` é recomendado quando os dados são acessados somente via Samba, visando melhor compatibilidade NT ACL.[^12_1]
- `streams_xattr` implementa NTFS Alternate Data Streams em xattrs (ex.: `user.DosStream."ADS-NAME"`).[^12_2]
- Para multichannel, o Windows documenta que ele cria múltiplas conexões TCP por sessão (podendo somar banda e manter sessão em falha de NIC), e também mostra como habilitar/desabilitar via PowerShell.[^12_4]


## Script “Premium” de validação (AD + SMB + ACL + multichannel)

> Arquivo: `artifacts/scripts/validate_ad_smb.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Uso:
#   sudo ./validate_ad_smb.sh --realm EXEMPLO.COM --domain EXEMPLO --vip-fqdn filesvc.exemplo.com \
#      --share //filesvc/SHARE_EXEMPLO --user 'EXEMPLO\Administrador'
#
# Observação: este script valida o lado Linux. A validação de multichannel é do lado Windows (ver .md).

REALM=""
DOMAIN=""
VIP_FQDN=""
SHARE=""
USER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --realm) REALM="$2"; shift 2;;
    --domain) DOMAIN="$2"; shift 2;;
    --vip-fqdn) VIP_FQDN="$2"; shift 2;;
    --share) SHARE="$2"; shift 2;;
    --user) USER="$2"; shift 2;;
    *) echo "Argumento desconhecido: $1"; exit 2;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Faltando comando: $1"; exit 1; }; }

echo "[1/9] Checando comandos necessários"
need testparm
need smbclient
need smbcacls
need wbinfo
need net
need kinit
need host
need timedatectl

echo "[2/9] Checando sincronismo de tempo (Kerberos é sensível a clock skew)"
timedatectl status | sed -n '1,12p' || true
echo "Dica: Kerberos costuma falhar se o desvio de relógio excede ~300s; use NTP/chrony corretamente."  # referência no doc do projeto

echo "[3/9] Validando resolução DNS (VIP/FQDN)"
if [[ -n "${VIP_FQDN}" ]]; then
  host "${VIP_FQDN}" || { echo "ERRO: DNS não resolve ${VIP_FQDN}"; exit 1; }
fi

echo "[4/9] Validando Kerberos (keytab)"
if [[ -n "${REALM}" ]]; then
  echo "Tentando kinit -k (keytab). Se falhar: DNS/tempo/realm/keytab."
  kinit -k || { echo "ERRO: kinit -k falhou"; exit 1; }
fi

echo "[5/9] Validando join no domínio (net ads testjoin)"
net ads testjoin || { echo "ERRO: net ads testjoin falhou"; exit 1; }

echo "[6/9] Validando Winbind (trust e enum básico)"
wbinfo -t || { echo "ERRO: wbinfo -t falhou"; exit 1; }
wbinfo --online-status || true
wbinfo -u | head -n 5 || true
wbinfo -g | head -n 5 || true

echo "[7/9] Validando configuração do Samba (testparm)"
testparm -s >/dev/null || { echo "ERRO: testparm encontrou problemas"; exit 1; }

echo "[8/9] Smoke test de acesso ao share via smbclient"
if [[ -n "${SHARE}" && -n "${USER}" ]]; then
  echo "Tentando listar share. Informe senha quando solicitado."
  smbclient "${SHARE}" -U "${USER}" -c 'ls' || { echo "ERRO: smbclient ls falhou"; exit 1; }
else
  echo "Pulando smbclient (faltou --share e/ou --user)"
fi

echo "[9/9] Smoke test de ACL via smbcacls"
# smbcacls manipula NT ACL em shares SMB e pode operar em SMB2/SMB3 (max-protocol). [web:275]
if [[ -n "${SHARE}" && -n "${USER}" ]]; then
  echo "Consultando ACL do diretório raiz do share. Informe senha quando solicitado."
  smbcacls "${SHARE}" / -U "${USER}" --maximum-access || true
  echo "Dica: use --sddl para export/import ACL em formato SDDL se necessário."
else
  echo "Pulando smbcacls (faltou --share e/ou --user)"
fi

echo "OK: validações básicas concluídas."
echo "Para validar SMB Multichannel, rode os comandos no Windows conforme artifacts/docs/windows_validate_multichannel.md."
```

Complemento importante: o `smbcacls` é documentado como ferramenta para manipular NT ACLs em shares SMB e tem opções para SMB2/SMB3 e para consultar permissões efetivas (`--maximum-access`).[^12_5][^12_6]

## Validação do SMB Multichannel no Windows

> Arquivo: `artifacts/docs/windows_validate_multichannel.md`

```md
# Validar SMB Multichannel (lado Windows)

O Windows documenta SMB Multichannel como mecanismo que cria múltiplas conexões TCP por sessão para throughput agregado e tolerância a falha.  
Fonte: https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/manage-smb-multichannel [web:164]

## Checar se está ativo (PowerShell)

- Ver conexões multichannel:
  Get-SmbMultichannelConnection

- Ver conexões SMB:
  Get-SmbConnection

## Habilitar/Desabilitar (se necessário)

- No servidor Windows (se aplicável):
  Set-SmbServerConfiguration -EnableMultiChannel $true
  Set-SmbServerConfiguration -EnableMultiChannel $false

Fonte: mesma doc MS. [web:164]
```


## “Prompt 4” (continuação premium) para seu agente local

Cole isso como continuação do prompt anterior (ele referencia os artefatos acima e pede ao agente para integrá-los ao live-build e ao instalador):

```text
CONTINUAÇÃO PREMIUM — incluir smb.conf base + validação automatizada

1) Criar no repositório estes arquivos exatamente:
- artifacts/templates/smb/smb.conf.smb-only.template  (conteúdo fornecido nesta conversa)
- artifacts/scripts/validate_ad_smb.sh                (conteúdo fornecido)
- artifacts/docs/windows_validate_multichannel.md     (conteúdo fornecido)

2) Integrar ao live-build:
- Copiar smb.conf.smb-only.template para o sistema em:
  /usr/local/share/my-nas/templates/smb/smb.conf.smb-only.template
- Copiar validate_ad_smb.sh para:
  /usr/local/sbin/validate_ad_smb.sh  (chmod +x)
- Copiar windows_validate_multichannel.md para:
  /usr/local/share/my-nas/docs/windows_validate_multichannel.md

3) Instalador/first-boot:
- Ao criar um share SMB-only, gerar uma seção [share] a partir do template e gravar em /etc/samba/smb.conf.d/<share>.conf
- Incluir um include central em /etc/samba/smb.conf:
  include = /etc/samba/smb.conf.d/*.conf
- Após join no AD e criação do share, rodar automaticamente:
  /usr/local/sbin/validate_ad_smb.sh --realm <REALM> --domain <DOM> --vip-fqdn <VIP_FQDN> --share //<VIP>/<SHARE> --user '<DOM>\Administrador'
  (sem falhar a instalação; apenas registrar em log e mostrar “o que corrigir”)

4) Regras:
- SMB-only default: vfs objects = acl_xattr streams_xattr e acl_xattr:ignore system acls = yes. [web:190][web:263]
- Multichannel default: server multi channel support = yes + aio read/write size = 1, e incluir doc para validar no Windows. [web:163][web:164]
- SMB1 desabilitado via server min protocol = SMB2 (não suportar NT1/SMB1). [web:277][web:167]

5) Entregar também exemplos de administração de ACL via Linux:
- Documentar uso de smbcacls (listar e alterar ACL) e apontar que ele manipula NT ACLs em shares SMB. [web:279]
- Documentar que acl_xattr guarda ACL NT em security.NTACL e que ignore system acls = yes é recomendado p/ dados SMB-only. [web:190]
```

Se você me disser qual nome você quer padronizar para o VIP/alias (ex.: `filesvc`), eu incluo no próximo artefato um `docs/30_AD_JOIN_AND_ALIAS.md` já com os comandos de SPN/alias (Kerberos) e checklist de DNS/tempo (o ponto que mais derruba join/SSO).[^12_7][^12_8]
<span style="display:none">[^12_10][^12_11][^12_12][^12_13][^12_14][^12_15][^12_16][^12_17][^12_18][^12_19][^12_20][^12_9]</span>

<div align="center">⁂</div>

[^12_1]: https://manpages.debian.org/bullseye/samba-vfs-modules/vfs_acl_xattr.8.en.html

[^12_2]: https://docs.oracle.com/cd/E88353_01/html/E72487/vfs-streams-xattr-8.html

[^12_3]: https://fossies.org/linux/samba/docs/manpages/vfs_zfsacl.8

[^12_4]: https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/manage-smb-multichannel

[^12_5]: https://manpages.ubuntu.com/manpages/jammy/man1/smbcacls.1.html

[^12_6]: https://docs.redhat.com/fr/documentation/red_hat_enterprise_linux/9/html/configuring_and_using_network_file_services/assembly_managing-acls-on-an-smb-share-using-smbcacls_assembly_using-samba-as-a-server

[^12_7]: https://www.spinics.net/lists/samba/msg173688.html

[^12_8]: https://docs.oracle.com/cd/E23824_01/html/821-1456/setup-192.html

[^12_9]: https://codeinsecurity.wordpress.com/2020/05/18/setting-up-smb-multi-channel-between-freenas-or-any-bsd-linux-and-windows-for-20gbps-transfers/

[^12_10]: https://forum.proxmox.com/threads/enabling-smb3-multichannel-in-proxmox.139414/

[^12_11]: https://blog.chaospixel.com/linux/2016/09/samba-enable-smb-multichannel-support-on-linux.html

[^12_12]: https://www.truenas.com/community/threads/smb-multichannel.100133/

[^12_13]: https://stackoverflow.com/questions/63372848/how-to-enable-smb1-as-default-and-disable-smb2-and-smb3-on-ubuntu-18-04-server

[^12_14]: https://www.reddit.com/r/synology/comments/rrb4r1/how_to_enable_smb_multichannel_for_125_mb_between/

[^12_15]: https://www.reddit.com/r/linuxquestions/comments/i8p13b/question_set_preferred_samba_protocol_version/

[^12_16]: https://manpages.ubuntu.com/manpages/bionic/en/man1/smbcacls.1.html

[^12_17]: https://www.reddit.com/r/homelab/comments/opi4s6/anyone_know_how_to_setup_smb_multichannel_on/

[^12_18]: https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3

[^12_19]: https://www.reddit.com/r/samba/comments/10r1akh/samba_smb_multichannel_not_working/

[^12_20]: https://bbs.archlinux.org/viewtopic.php?id=231870


---

# pode usar o nome fileserver

Perfeito — vou padronizar o VIP/alias como **`fileserver`** e te entregar (a) um artefato “pronto para salvar” com SPN/DNS/Kerberos e (b) um bloco para você colar no prompt do seu agente local para ele incorporar isso no fluxo de first-boot e no HA (VIP).

## Artefato para salvar: alias `fileserver` + SPN

Salve como `docs/30_AD_JOIN_AND_ALIAS.md` no seu projeto.

```md
# AD + Kerberos + Alias (VIP) para Samba: fileserver

Este documento padroniza o nome lógico do serviço SMB como `fileserver` (VIP/alias) para clientes Windows, independente do nome do host físico/VM. [web:232]  
Para Kerberos funcionar com alias/CNAME/VIP, é necessário registrar SPNs (principalmente `cifs/`) para o nome usado pelos clientes. [web:232][web:287]

## Nomes e DNS

Padrões:
- Nome curto (NetBIOS/DNS curto): `fileserver`
- FQDN do serviço: `fileserver.<SEU_DOMINIO_FQDN>` (ex.: `fileserver.corp.exemplo.com`)

Recomendação de DNS:
- Preferir registro **A** apontando para o VIP do nó ativo; alternativamente, um CNAME apontando para um A do VIP, desde que os SPNs correspondam ao nome usado pelos clientes. [web:281]

## SPNs necessários (no AD)

Objetivo: permitir Kerberos ao acessar `\\fileserver\SHARE` e `\\fileserver.<dominio>\SHARE`. [web:232]  

Execute no AD (com permissão de administrar SPN) usando `setspn`:
- Listar SPNs atuais do objeto de computador (ex.: `HOSTFISICO$` ou a conta usada no cluster):
  - `setspn -L <DOMINIO>\HOSTFISICO$` [web:287]
- Adicionar SPN CIFS para o alias curto:
  - `setspn -S cifs/fileserver <DOMINIO>\HOSTFISICO$` [web:287]
- Adicionar SPN CIFS para o FQDN do alias:
  - `setspn -S cifs/fileserver.<SEU_DOMINIO_FQDN> <DOMINIO>\HOSTFISICO$` [web:287]

Notas:
- `setspn` lê/modifica SPNs no AD para uma conta de serviço (inclui computer accounts). [web:287]  
- Quando clientes usam alias, a falta de SPN correto costuma resultar em erro de principal desconhecido/queda para NTLM, então o SPN do alias é parte do “pronto para produção”. [web:232]

## Time sync (NTP/Chrony) é obrigatório

Kerberos requer relógios sincronizados; referências descrevem limite típico de 300 segundos (5 minutos) e recomendam NTP para manter sincronismo entre clientes e KDC/DC. [web:174]  

Checklist Debian:
- `timedatectl status` deve mostrar sincronismo ativo.
- `chrony` ou `systemd-timesyncd` deve apontar para os DCs (ou NTP corporativo).

## Checklist de validação pós-join (Linux)

- `kinit -k` (keytab) deve funcionar.
- `net ads testjoin` deve retornar OK.
- `wbinfo -t` deve retornar OK.
- Acesso SMB via `\\fileserver\share` deve usar Kerberos (validar no cliente Windows).

## Checklist de validação pós-failover (A/P)

Após mover VIP do físico para a VM:
- DNS deve resolver `fileserver` para o VIP novo (se o VIP mudou de nó; em geral o VIP é o mesmo IP, apenas muda quem responde). [web:281]
- Clientes Windows devem conseguir reconectar e autenticar.
- Se Kerberos falhar, revisar SPNs `cifs/fileserver*` e se o serviço está respondendo com o mesmo nome/IP esperado.
```


## Bloco para adicionar no seu prompt do agente local (continuação)

Cole isto no final do seu “Prompt Pack” (ou como “Prompt 5”):

```text
PADRÃO DE ALIAS/VIP: usar sempre "fileserver"

- O nome lógico do serviço SMB para clientes será:
  - curto: fileserver
  - FQDN: fileserver.<DOMINIO_FQDN>
- DNS: criar registro A (preferido) apontando para o VIP do cluster (ou CNAME para um A do VIP), conforme procedimento de alias em SMB clustered. [web:281]
- Kerberos: registrar SPNs CIFS para o alias no AD, usando setspn (setspn lê/modifica SPNs para a conta de serviço no AD). [web:287]
  - setspn -S cifs/fileserver <DOMINIO>\HOSTATIVO$
  - setspn -S cifs/fileserver.<DOMINIO_FQDN> <DOMINIO>\HOSTATIVO$
- Incluir docs/30_AD_JOIN_AND_ALIAS.md no repo e referenciar no first-boot wizard e no módulo de HA.
- Time sync obrigatório: Kerberos falha com clock skew; referência aponta limite típico 300s/5min e recomenda NTP. [web:174]
```

Se você me disser qual formato de domínio vocês usam com mais frequência (ex.: `corp.empresa.local` vs `empresa.com.br`) e se o `fileserver` vai ser **A record** (recomendado) ou **CNAME**, eu posso ajustar o doc para refletir a prática mais segura do seu AD e incluir um trecho de “runbook” com comandos exatos (PowerShell/Windows) para criar o registro DNS e listar/verificar os SPNs.[^13_1][^13_2]
<span style="display:none">[^13_10][^13_11][^13_12][^13_13][^13_14][^13_15][^13_3][^13_4][^13_5][^13_6][^13_7][^13_8][^13_9]</span>

<div align="center">⁂</div>

[^13_1]: https://techcommunity.microsoft.com/blog/failoverclustering/how-to-configure-an-alias-for-a-clustered-smb-share-with-windows-server-2012/371737

[^13_2]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setspn

[^13_3]: https://community.synology.com/enu/forum/17/post/90236

[^13_4]: https://community.netapp.com/t5/ONTAP-Discussions/What-authentication-method-does-CIFS-server-use-for-CIFS-clients/m-p/158928

[^13_5]: https://www.reddit.com/r/activedirectory/comments/1m7ye9l/how_to_configure_spn_for_cifs_in_case_clients_are/

[^13_6]: https://www.reddit.com/r/activedirectory/comments/1m7ye9l/how_to_configure_spn_for_cifs_in_case_clients_are/n4vgd19/

[^13_7]: https://www.veritas.com/support/en_US/article.100074197

[^13_8]: https://michlstechblog.info/blog/windows-enable-share-access-for-alias-cname-or-ip-address-and-kerberos/

[^13_9]: https://kb.netapp.com/on-prem/ontap/da/NAS/NAS-KBs/Why_is_kerberos_not_being_used_when_connecting_to_a_CIFS_server_by_IP

[^13_10]: http://raunomagi.blogspot.com/2012/10/how-to-change-windows-file-server-name.html

[^13_11]: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/how-to-configure-spn

[^13_12]: https://groups.google.com/g/linux.samba/c/VfjW9Af92Wg

[^13_13]: https://md3v.com/enable-windows-server-smb-2-0-alias-cname

[^13_14]: https://wanderingengineer.hatenablog.com/entry/2020/02/23/015338

[^13_15]: https://stackoverflow.com/questions/67404157/how-to-use-kerberos-for-samba-authentication


---

# fileserver será A e o padrão adotado é empresa.com.br

Ótimo — então vamos fixar `fileserver` como **registro A** em `empresa.com.br` e completar o runbook (DNS + SPN + validação) para seu agente local não precisar pesquisar nada.[^14_1][^14_2]

## Atualização do artefato (A record)

Atualize (ou crie) o arquivo `docs/30_AD_JOIN_AND_ALIAS.md` com estas decisões “fechadas”:

- Alias/VIP: `fileserver.empresa.com.br` (registro **A**, não CNAME).
- Clientes devem acessar sempre `\\fileserver\share` ou `\\fileserver.empresa.com.br\share` (consistência para Kerberos/SPN).
- SPNs `cifs/fileserver` e `cifs/fileserver.empresa.com.br` devem existir na *conta correta* no AD.[^14_1]


## Runbook Premium (DNS + SPN + validação)

Salve como `docs/31_RUNBOOK_FILESERVICE_FILESERVERSMB_AD.md`.

```md
# RUNBOOK: Serviço SMB "fileserver" (A record) + Kerberos/SPN (empresa.com.br)

## 1) DNS (registro A)

Criar (ou garantir) registro A:
- Nome: fileserver
- Zona: empresa.com.br
- Tipo: A
- IP: <VIP_IPV4>

Observação: usar A record reduz variáveis e evita nuances de CNAME+Kerberos. [web:281]

## 2) SPN (Kerberos para alias)

O comando setspn lê/modifica SPNs em uma conta de serviço do AD (inclui computer accounts). [web:287]  
Adicione SPNs do serviço CIFS para o alias que os clientes usam:

### 2.1 Descobrir em qual conta registrar
Escolha UMA conta-alvo:
- Opção mais comum: a computer account do servidor Samba que hospeda o serviço (ex.: FILESERVER-PHYSICAL$), ou uma conta dedicada ao serviço se você usar modelo mais avançado.

Primeiro liste os SPNs existentes:
- `setspn -L EMPRESA\FILESERVER-PHYSICAL$` [web:287]

E confirme se já existe algo como `cifs/fileserver*`.

### 2.2 Adicionar SPNs (recomendado: usar -S)
`-S` adiciona e verifica duplicidade antes (evita SPNs duplicados que quebram Kerberos). [web:287]

- `setspn -S cifs/fileserver EMPRESA\FILESERVER-PHYSICAL$` [web:287]
- `setspn -S cifs/fileserver.empresa.com.br EMPRESA\FILESERVER-PHYSICAL$` [web:287]

Depois valide:
- `setspn -L EMPRESA\FILESERVER-PHYSICAL$` [web:287]
- `setspn -Q cifs/fileserver` [web:287]
- `setspn -Q cifs/fileserver.empresa.com.br` [web:287]

## 3) Requisito de tempo (NTP/Chrony)

O valor padrão de clock skew máximo em Kerberos é 300 segundos (5 minutos) e a recomendação é usar NTP para sincronizar clientes e KDC. [web:178]  
No Debian:
- `timedatectl status` deve indicar sincronismo ativo.
- Use chrony apontando para DCs/NTP corporativo.

## 4) Validação no Linux (servidor Samba)

- `kinit -k` (keytab) deve funcionar.
- `net ads testjoin` deve retornar OK.
- `wbinfo -t` deve retornar OK.
- `testparm -s` deve retornar OK.

(Use também o script /usr/local/sbin/validate_ad_smb.sh do projeto.)

## 5) Validação no Windows (cliente)

- Acesse `\\fileserver\SHARE`.
- Verifique se Kerberos está sendo usado (ex.: logs/diagnóstico do cliente, ou observe que não caiu para NTLM).
- Para SMB Multichannel, use:
  - `Get-SmbMultichannelConnection` (PowerShell)
  (Documentação Microsoft sobre SMB Multichannel.) [web:164]
```


## Bloco para colar no prompt do seu agente local (ajuste final)

```text
PADRÃO DEFINITIVO (empresa.com.br + A record)

- Alias/VIP do serviço SMB: fileserver.empresa.com.br (registro DNS A -> VIP)
- Clientes devem usar \\fileserver\share ou \\fileserver.empresa.com.br\share
- SPNs obrigatórios (usar setspn -S):
  - cifs/fileserver
  - cifs/fileserver.empresa.com.br
  Setspn lê/modifica SPNs de conta de serviço no AD. [web:287]
- Requisito NTP: clock skew padrão máximo do Kerberos é 300s; usar NTP/chrony. [web:178]
- Adicionar docs/31_RUNBOOK_FILESERVICE_FILESERVERSMB_AD.md com passos e validações.
```

Se você me disser qual será o **nome do computador** no AD para o host físico (ex.: `NAS2950-01`) e o nome da VM standby (ex.: `NASVM-01`), eu ajusto o runbook para já incluir os comandos `setspn` com os nomes reais e regras de “quem é a conta dona do SPN” no seu desenho ativo+passivo.
<span style="display:none">[^14_10][^14_11][^14_12][^14_13][^14_14][^14_15][^14_3][^14_4][^14_5][^14_6][^14_7][^14_8][^14_9]</span>

<div align="center">⁂</div>

[^14_1]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setspn

[^14_2]: https://docs.oracle.com/cd/E19253-01/816-4557/setup-192/index.html

[^14_3]: https://learn.microsoft.com/pt-br/windows-server/administration/windows-commands/setspn

[^14_4]: https://www.reddit.com/r/activedirectory/comments/1m7ye9l/how_to_configure_spn_for_cifs_in_case_clients_are/

[^14_5]: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/how-to-configure-spn

[^14_6]: https://www.veritas.com/support/en_US/article.100074197

[^14_7]: https://techcommunity.microsoft.com/blog/failoverclustering/how-to-configure-an-alias-for-a-clustered-smb-share-with-windows-server-2012/371737

[^14_8]: https://artemis.wszib.edu.pl/~mdudek/win7/setspn.html

[^14_9]: https://learn.microsoft.com/en-us/answers/questions/306283/failover-cluster-is-adding-dns-a-record-for-cluste

[^14_10]: https://docs.oracle.com/cd/E37838_01/html/E61026/kplan-clocks.html

[^14_11]: https://pen2.com/cmd/setspn/

[^14_12]: https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/dns-cname-alias-cannot-access-smb-file-server-share

[^14_13]: https://kioptrix.com/krb-ap-err-skew-fix/

[^14_14]: https://github.com/MicrosoftDocs/windowsserverdocs/blob/main/WindowsServerDocs/administration/windows-commands/setspn.md

[^14_15]: https://learn.microsoft.com/pt-br/windows-server/networking/core-network-guide/cncg/server-certs/create-an-alias-cname-record-in-dns-for-web1


---

# no nome será EMPRESA-BM-NAS (Bare Metal) e EMPRESA-VM-NAS

Fechado: nós do cluster serão **EMPRESA-BM-NAS** (bare metal) e **EMPRESA-VM-NAS** (standby VM), e o serviço para os clientes será sempre `fileserver` via **registro A** em `empresa.com.br`.[^15_1]

## O ponto crítico: em qual conta ficam os SPNs do `fileserver`

O `setspn` altera a propriedade de SPN em uma conta do AD (usuário ou **computer account**) e a recomendação é usar `-S` para evitar SPN duplicado.[^15_2][^15_3]
Para **ativo+passivo**, o caminho com maior taxa de sucesso é manter os SPNs do alias **sempre na mesma identidade** (uma conta dedicada ao serviço), evitando ter que “mover SPN” em cada failover.[^15_2]

### Estratégia recomendada (mais robusta): conta dedicada `FILESERVER$` (serviço)

Crie uma **computer account** dedicada no AD para o serviço, por exemplo `EMPRESA\FILESERVER$` (nome NetBIOS `FILESERVER`, DNS `fileserver.empresa.com.br`).[^15_2]
Registre **uma vez** os SPNs nela (e nunca mais mova), assim o Kerberos continua coerente mesmo quando o VIP muda de nó.[^15_2]

Comandos (rodar no AD):

```bat
setspn -L EMPRESA\FILESERVER$                             
setspn -S cifs/fileserver EMPRESA\FILESERVER$            
setspn -S cifs/fileserver.empresa.com.br EMPRESA\FILESERVER$
setspn -Q cifs/fileserver
setspn -Q cifs/fileserver.empresa.com.br
```

`-L` lista SPNs, `-S` adiciona verificando duplicidade, e `-Q` consulta existência do SPN.[^15_2]

**O que seu agente deve implementar no Debian**: documentar e automatizar (no first-boot/HA) o uso de uma identidade de serviço única para o Samba quando o acesso for via `\\fileserver\share`, garantindo que apenas o nó ativo sobe `smbd/winbind` (ativo+passivo).

### Estratégia alternativa (não recomendada): SPN no nó ativo e mover no failover

Você poderia registrar o SPN em `EMPRESA\EMPRESA-BM-NAS$` e, no failover, removê-lo e adicionar em `EMPRESA\EMPRESA-VM-NAS$`, mas isso aumenta risco operacional e exige credenciais AD elevadas dentro do cluster.[^15_2]
Se você quer “premium e previsível”, mantenha SPN fixo numa identidade dedicada.[^15_2]

## Artefato atualizado (com seus nomes)

Crie/atualize este arquivo no repo: `docs/30_AD_JOIN_AND_ALIAS.md` (substitua o trecho de SPN pelo abaixo).

```md
# AD + Kerberos + Alias (VIP) para Samba: fileserver (empresa.com.br)

Nomes fixos:
- Nó físico: EMPRESA-BM-NAS
- Nó VM standby: EMPRESA-VM-NAS
- Serviço (VIP/alias): fileserver
- Domínio DNS: empresa.com.br
- FQDN do serviço: fileserver.empresa.com.br

## DNS
- Criar registro A: fileserver.empresa.com.br -> <VIP_IPV4> (VIP é movido pelo cluster). [web:281]

## SPN (Kerberos)
Use setspn para ler/modificar SPNs em contas do AD. [web:287]

### Recomendado: conta dedicada do serviço
- Computer account: EMPRESA\FILESERVER$

Comandos:
- setspn -S cifs/fileserver EMPRESA\FILESERVER$ [web:287]
- setspn -S cifs/fileserver.empresa.com.br EMPRESA\FILESERVER$ [web:287]
- setspn -Q cifs/fileserver [web:287]
- setspn -Q cifs/fileserver.empresa.com.br [web:287]

## Time sync
Kerberos depende de relógios sincronizados; referência descreve tolerância típica de 300s (5 min) e recomenda NTP. [web:178]
```


## Bloco para adicionar no prompt do seu agente (continuação)

```text
ATUALIZAÇÃO (nomes reais)

- Nós:
  - EMPRESA-BM-NAS (bare metal)
  - EMPRESA-VM-NAS (standby)
- Serviço SMB:
  - alias/VIP: fileserver
  - FQDN: fileserver.empresa.com.br
  - DNS: registro A fileserver.empresa.com.br -> VIP (não usar CNAME) [web:281]
- SPN Kerberos:
  - Usar uma identidade dedicada fixa: EMPRESA\FILESERVER$
  - Registrar SPNs com setspn -S (evita duplicidade). [web:287]
    - cifs/fileserver
    - cifs/fileserver.empresa.com.br
- Cluster é ativo+passivo: apenas o nó ativo sobe smbd/winbind + VIP.
- Time sync é requisito: Kerberos tolera skew típico de 300s e recomenda NTP. [web:178]
```


## Próximo passo (para ficar 100% executável)

Você quer que a conta dedicada do serviço no AD se chame exatamente **FILESERVER** (ou prefere algo como **EMPRESA-FILESERVER** para evitar colisões/ambiguidade em domínios grandes)?
<span style="display:none">[^15_10][^15_11][^15_12][^15_13][^15_14][^15_15][^15_16][^15_4][^15_5][^15_6][^15_7][^15_8][^15_9]</span>

<div align="center">⁂</div>

[^15_1]: https://techcommunity.microsoft.com/blog/failoverclustering/how-to-configure-an-alias-for-a-clustered-smb-share-with-windows-server-2012/371737

[^15_2]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setspn

[^15_3]: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/how-to-configure-spn

[^15_4]: https://www.ibm.com/docs/en/spss-statistics/30.0.0?topic=sso-registering-service-principle-name-spn

[^15_5]: https://help.highbond.com/helpdocs/analytics-exchange/5/Content/ax_administration/t_adding_a_spn_account_for_the_ax_core_desktop_connector_service.html

[^15_6]: https://artemis.wszib.edu.pl/~mdudek/win7/setspn.html

[^15_7]: https://www.reddit.com/r/sysadmin/comments/15mge7f/kerberos_with_dfs_spn/

[^15_8]: https://groups.google.com/g/linux.samba/c/zxeIKVjnPqk

[^15_9]: https://pen2.com/cmd/setspn/

[^15_10]: https://www.veritas.com/support/en_US/article.100074197

[^15_11]: https://docs.netapp.com/us-en/ontap/smb-config/create-server-active-directory-domain-task.html

[^15_12]: https://github.com/MicrosoftDocs/windowsserverdocs/blob/main/WindowsServerDocs/administration/windows-commands/setspn.md

[^15_13]: https://www.reddit.com/r/activedirectory/comments/1m7ye9l/how_to_configure_spn_for_cifs_in_case_clients_are/

[^15_14]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_high_availability_clusters/assembly_configuring-active-active-samba-in-a-cluster-configuring-and-managing-high-availability-clusters

[^15_15]: https://www.ibm.com/docs/no/domino/9.0.1?topic=utility-assigning-spns-using-setspn

[^15_16]: https://docs.aws.amazon.com/ja_jp/fsx/latest/WindowsGuide/step2-configure-spn-kerberos.html


---

# pode ser EMPRESA-FILESERVER

Perfeito — vamos padronizar a identidade dedicada do serviço como **`EMPRESA-FILESERVER`** (computer account) e travar isso nos seus artefatos e prompts para ficar “à prova de failover” (SPN não precisa mover entre EMPRESA-BM-NAS e EMPRESA-VM-NAS).[^16_1]

## Decisão final (fonte da verdade)

- Nós do cluster: **EMPRESA-BM-NAS** (ativo normal) e **EMPRESA-VM-NAS** (standby).
- Alias/VIP: **fileserver.empresa.com.br** (registro **A** apontando para o VIP).[^16_2]
- SPNs do serviço CIFS/SMB: **fixos** na conta dedicada **EMPRESA\\EMPRESA-FILESERVER\$**.[^16_1]
- Ferramenta oficial para SPN: `setspn` (lê/modifica SPNs e `-S` evita duplicidades).[^16_1]


## Atualize os artefatos do projeto

### 1) `docs/30_AD_JOIN_AND_ALIAS.md` (substitua pelo trecho abaixo)

```md
## SPN (Kerberos) — conta dedicada do serviço (recomendado)

Conta dedicada do serviço (computer account):
- EMPRESA\EMPRESA-FILESERVER$

O utilitário setspn lê/modifica SPNs em contas de serviço/computadores no AD; use -S para adicionar evitando SPNs duplicados. [web:287]

Comandos:
- setspn -L EMPRESA\EMPRESA-FILESERVER$ [web:287]
- setspn -S cifs/fileserver EMPRESA\EMPRESA-FILESERVER$ [web:287]
- setspn -S cifs/fileserver.empresa.com.br EMPRESA\EMPRESA-FILESERVER$ [web:287]
- setspn -Q cifs/fileserver [web:287]
- setspn -Q cifs/fileserver.empresa.com.br [web:287]
- setspn -X  (verificar SPNs duplicados no domínio) [web:287]
```


### 2) `docs/31_RUNBOOK_FILESERVICE_FILESERVERSMB_AD.md` (ajuste a conta-alvo)

Troque qualquer referência a `FILESERVER$` por `EMPRESA-FILESERVER$`.

## Bloco pronto para colar no prompt do seu agente local (continuação)

```text
ATUALIZAÇÃO FINAL (identidade dedicada do serviço)

- Conta dedicada do serviço SMB no AD (computer account):
  - EMPRESA\EMPRESA-FILESERVER$
- SPNs CIFS do alias devem ficar FIXOS nesta conta (não mover em failover):
  - cifs/fileserver
  - cifs/fileserver.empresa.com.br
- Usar setspn -S (evita duplicidade) e setspn -Q/-L para validar; setspn gerencia SPNs no AD. [web:287]

Comandos no AD:
  setspn -L EMPRESA\EMPRESA-FILESERVER$ [web:287]
  setspn -S cifs/fileserver EMPRESA\EMPRESA-FILESERVER$ [web:287]
  setspn -S cifs/fileserver.empresa.com.br EMPRESA\EMPRESA-FILESERVER$ [web:287]
  setspn -Q cifs/fileserver [web:287]
  setspn -Q cifs/fileserver.empresa.com.br [web:287]
  setspn -X [web:287]

- DNS do serviço: A record fileserver.empresa.com.br -> VIP. [web:281]
- Nós: EMPRESA-BM-NAS (ativo) e EMPRESA-VM-NAS (passivo); apenas o ativo sobe smbd/winbind + VIP.
```


## Observação importante (evitar armadilha de “\$”)

Computer accounts no AD aparecem como `NOME$` (ex.: `EMPRESA-FILESERVER$`), e `setspn` aceita `domain\name` como accountname (incluindo computer accounts).[^16_1]
Evite criar **user accounts** terminando com `$` para serviços: a Microsoft documenta que isso pode causar problemas de compatibilidade; por isso a escolha por computer account dedicada é a mais limpa.[^16_3]

Se você quiser, no próximo passo eu te entrego um mini-artefato `docs/32_AD_OBJECTS_CHECKLIST.md` com checklist de “objetos do AD que precisam existir” (computer account do serviço, permissões mínimas, DNS A record, SPNs, validações) para seu agente usar como “gate” de prontidão antes de marcar o cluster como pronto.
<span style="display:none">[^16_10][^16_11][^16_12][^16_13][^16_14][^16_15][^16_16][^16_4][^16_5][^16_6][^16_7][^16_8][^16_9]</span>

<div align="center">⁂</div>

[^16_1]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setspn

[^16_2]: https://techcommunity.microsoft.com/blog/failoverclustering/how-to-configure-an-alias-for-a-clustered-smb-share-with-windows-server-2012/371737

[^16_3]: https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/compatibility-user-accounts-end-dollar-sign

[^16_4]: https://help.hcl-software.com/domino/11.0.1/admin/conf_examplesofaccountchoicesandspns_r.html

[^16_5]: https://community.spiceworks.com/t/how-to-change-attribute-of-ad-accounts-ending-with-dollar-sign/933742

[^16_6]: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/how-to-configure-spn

[^16_7]: https://learn.microsoft.com/pt-br/windows-server/identity/ad-fs/deployment/manually-configure-a-service-account-for-a-federation-server-farm

[^16_8]: https://learn.microsoft.com/en-us/iis/configuration/system.webserver/security/authentication/windowsauthentication/extendedprotection/spn

[^16_9]: https://pen2.com/cmd/setspn/

[^16_10]: https://www.microsoft.com/en-us/dynamics-365/blog/it-professional/2009/08/06/configuring-service-principal-names/

[^16_11]: https://help.nintex.com/en-us/k2blackpearl/icg/4.6.10/SETSPN.html

[^16_12]: https://alpha.uucp.hu/mirror/ss64.com/nt/setspn.html

[^16_13]: https://learn.microsoft.com/pt-br/windows-server/identity/ad-ds/manage/group-managed-service-accounts/group-managed-service-accounts/configure-kerberos-delegation-group-managed-service-accounts

[^16_14]: https://docs.bmc.com/xwiki/bin/view/Automation-DevSecOps/Server-Automation/TrueSight-Smart-Reporting-for-Server-Automation/tssrsa232/Administering/Implementing-authentication/Domain-authentication/Registering-an-Authentication-Service-in-an-Active-Directory-domain/

[^16_15]: https://mskb.pkisolutions.com/kb/924177

[^16_16]: https://learn.microsoft.com/en-us/answers/questions/528076/spns-on-non-sql-service-accounts


---

# sim.

A seguir vai o artefato “gate de prontidão” que você pediu, com checklist **dos objetos e configurações no AD** para o seu serviço SMB `fileserver.empresa.com.br` com identidade dedicada `EMPRESA-FILESERVER$`, mais comandos de verificação que o agente pode automatizar. Tudo foi escrito para ser salvo no repositório e usado como referência única.[^17_1][^17_2]

## Artefato para salvar

Crie este arquivo: `docs/32_AD_OBJECTS_CHECKLIST.md`

```md
# Checklist AD: SMB "fileserver" + Kerberos/SPN (empresa.com.br)

Contexto fixo do projeto:
- Nós: EMPRESA-BM-NAS (bare metal) e EMPRESA-VM-NAS (standby)
- Serviço para clientes: \\fileserver\SHARE e \\fileserver.empresa.com.br\SHARE
- DNS: A record fileserver.empresa.com.br -> VIP (IP movido pelo cluster)
- Identidade dedicada do serviço (AD computer account): EMPRESA\EMPRESA-FILESERVER$

Objetivo: garantir que autenticação Kerberos e acesso SMB funcionem de forma previsível no modo ativo+passivo, sem mover SPN em failover.

---

## 1) Objetos obrigatórios no AD

### 1.1 Computer account dedicada do serviço
- Deve existir: EMPRESA-FILESERVER (computer object; referenciado como EMPRESA\EMPRESA-FILESERVER$ em setspn)

Validação (rodar em DC / host com RSAT):
- `setspn -L EMPRESA\EMPRESA-FILESERVER$`  [web:287]

Saída esperada:
- Lista de SPNs (incluindo HOST/...) e, após configuração, CIFS/...

---

## 2) DNS obrigatório (A record)

### 2.1 Registro A
- `fileserver.empresa.com.br` -> `<VIP_IPV4>`

Validação:
- `nslookup fileserver.empresa.com.br`
- Confirmar que o VIP responde na porta 445 no nó ativo (ex.: Test-NetConnection no Windows)

Nota: A record (não CNAME) reduz variáveis para SMB/Kerberos. [web:281]

---

## 3) SPNs obrigatórios (Kerberos)

O utilitário `setspn` lê/modifica SPNs e `-S` adiciona verificando duplicidade (recomendado). [web:287]  
SPNs CIFS precisam existir para o nome usado pelo cliente (`fileserver` e o FQDN). [web:287]

### 3.1 Adicionar SPNs (uma vez)
Rodar:
- `setspn -S cifs/fileserver EMPRESA\EMPRESA-FILESERVER$`  [web:287]
- `setspn -S cifs/fileserver.empresa.com.br EMPRESA\EMPRESA-FILESERVER$`  [web:287]

### 3.2 Verificar SPNs por nome
Rodar:
- `setspn -Q cifs/fileserver`  [web:287]
- `setspn -Q cifs/fileserver.empresa.com.br`  [web:287]

### 3.3 Checar duplicidade (domínio/floresta)
Rodar:
- `setspn -X`  [web:287]

Critério de aceite:
- NÃO existir duplicidade para `cifs/fileserver*` (duplicidade quebra Kerberos por ambiguidade).

---

## 4) Delegação de permissão (opcional, mas recomendada)

Se você quer que um grupo (ex.: "Linux NAS Admins") consiga registrar SPNs sem ser Domain Admin, delegue a permissão “Validated write to service principal name” conforme orientação da Microsoft. [web:290]

Critério de aceite:
- A conta/grupo delegado consegue executar `setspn -S ...` na conta EMPRESA-FILESERVER$ sem erros de permissão.

---

## 5) Requisitos operacionais do AD (para o Linux)

### 5.1 Tempo (NTP)
Kerberos exige relógio sincronizado; use NTP/chrony em todos os membros e DCs.
Critério de aceite:
- Debian: `timedatectl status` indica sincronismo ativo.
- Diferença de relógio pequena (prática: segundos, não minutos).

### 5.2 DNS para DCs
Critério de aceite:
- O Debian aponta DNS para os DCs (ou resolvers internos que encaminham corretamente) e resolve SRV records do AD.

---

## 6) Checklist de validação rápida (pós-join)

No Debian (nó ativo):
- `kinit -k` (keytab)
- `net ads testjoin`
- `wbinfo -t`
- `testparm -s`
- Acesso `smbclient //fileserver/SHARE -U EMPRESA\\usuario -c ls`

No Windows:
- Acessar `\\fileserver\SHARE`
- Validar SMB Multichannel se habilitado:
  - `Get-SmbMultichannelConnection` (PowerShell) [web:164]

---

## 7) Regras de failover (A/P)

- Em failover, o VIP permanece o mesmo IP; apenas muda o nó que responde.
- SPNs NÃO devem ser movidos entre EMPRESA-BM-NAS$ e EMPRESA-VM-NAS$.
- A identidade dedicada EMPRESA-FILESERVER$ é a fonte de verdade do Kerberos para CIFS.
```


## Bloco para adicionar no prompt do seu agente local

```text
Criar docs/32_AD_OBJECTS_CHECKLIST.md (conteúdo fornecido) e tratar como gate:
- Antes de marcar “pronto para produção”, validar:
  - A record fileserver.empresa.com.br -> VIP
  - SPNs CIFS do alias existem em EMPRESA\EMPRESA-FILESERVER$ (setspn -S / -Q)
  - Sem SPNs duplicados (setspn -X)
  - Permissão delegada (opcional) conforme guia Microsoft de configuração de SPN [web:290]
```

Se você quiser, eu também posso gerar um script PowerShell “AD-side” (`artifacts/scripts/ad_setup_fileserver.ps1`) que cria/verifica o A record, cria/verifica a computer account `EMPRESA-FILESERVER`, aplica SPNs com `setspn`, roda `setspn -X`, e salva um relatório (para o seu agente local chamar como etapa opcional).
<span style="display:none">[^17_10][^17_11][^17_12][^17_13][^17_14][^17_15][^17_3][^17_4][^17_5][^17_6][^17_7][^17_8][^17_9]</span>

<div align="center">⁂</div>

[^17_1]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setspn

[^17_2]: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/how-to-configure-spn

[^17_3]: https://support.microsoft.com/en-us/topic/duplicate-spn-check-on-windows-server-2012-r2-based-domain-controller-causes-restore-domain-join-and-migration-failures-aa11508f-7dfd-4444-835b-7febc303ed5e

[^17_4]: https://www.reddit.com/r/activedirectory/comments/171f4n7/duplicate_spn/

[^17_5]: https://help.salesforce.com/s/articleView?id=001474108\&language=en_US\&type=1

[^17_6]: https://community.spiceworks.com/t/major-domain-controller-issues-possible-duplicate-spn-records/308709

[^17_7]: https://github.com/MicrosoftDocs/windowsserverdocs/blob/main/WindowsServerDocs/identity/ad-ds/manage/how-to-configure-spn.md

[^17_8]: https://support.microfocus.com/kb/doc.php?id=7013120

[^17_9]: https://pen2.com/cmd/setspn/

[^17_10]: https://learn.microsoft.com/pt-br/windows-server/identity/ad-ds/manage/how-to-configure-spn

[^17_11]: https://techcommunity.microsoft.com/blog/sqlserversupport/searching-for-duplicate-spns-got-a-little-easier/315651

[^17_12]: https://alpha.uucp.hu/mirror/ss64.com/nt/setspn.html

[^17_13]: https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal

[^17_14]: https://www.dell.com/support/kbdoc/en-us/000032723/find-duplicate-service-principal-names-spns-in-active-directory

[^17_15]: https://github.com/MicrosoftDocs/windowsserverdocs/blob/main/WindowsServerDocs/administration/windows-commands/setspn.md


---

# sim

Abaixo está o artefato PowerShell “AD-side” que você pediu, pronto para salvar no seu repo e ser chamado pelo seu agente local como etapa opcional (ou manual) para preparar **DNS A record + computer account dedicada + SPNs CIFS + verificação de duplicidade** para o serviço `fileserver.empresa.com.br` com identidade `EMPRESA-FILESERVER`. Os comandos e comportamentos do `setspn` e dos cmdlets de DNS estão documentados pela Microsoft.[^18_1][^18_2][^18_3]

## Artefato: script PowerShell (AD-side)

Salve como `artifacts/scripts/ad_setup_fileserver.ps1`.

```powershell
<#
AD-side setup for Debian Samba A/P service alias:
- DNS A record: fileserver.empresa.com.br -> VIP
- Dedicated computer account: EMPRESA-FILESERVER
- SPNs: cifs/fileserver and cifs/fileserver.empresa.com.br on EMPRESA-FILESERVER$
- Duplicate SPN scan

Requirements:
- Run on a Windows Server with RSAT / DNS Server tools (DnsServer module)
- Must have permissions to create DNS records in the zone and to create/modify the computer object
- Must have permissions to manage SPNs (setspn)

References:
- Add-DnsServerResourceRecordA usage/examples [web:334]
- Get-DnsServerResourceRecord usage/examples [web:341]
- setspn syntax, -S, -Q, -X, computer accounts [web:287]
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory=$true)]
  [string] $ZoneName = "empresa.com.br",

  [Parameter(Mandatory=$true)]
  [string] $VipIPv4,

  [Parameter(Mandatory=$false)]
  [string] $DnsServer = $env:COMPUTERNAME,

  [Parameter(Mandatory=$false)]
  [string] $AliasHost = "fileserver",

  [Parameter(Mandatory=$false)]
  [string] $ServiceComputer = "EMPRESA-FILESERVER",

  [Parameter(Mandatory=$false)]
  [string] $NetbiosDomain = "EMPRESA",

  [switch] $SkipComputerAccount,

  [switch] $SkipDns,

  [switch] $SkipSpn
)

function Require-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing command: $Name"
  }
}

function Ensure-DnsARecord {
  param(
    [string] $DnsServer, [string] $ZoneName, [string] $Name, [string] $IPv4
  )

  Require-Command Get-DnsServerResourceRecord
  Require-Command Add-DnsServerResourceRecordA

  $existing = Get-DnsServerResourceRecord -ComputerName $DnsServer -ZoneName $ZoneName -Name $Name -RRType "A" -ErrorAction SilentlyContinue
  if ($existing) {
    $ips = @($existing | ForEach-Object { $_.RecordData.IPv4Address.IPAddressToString }) | Sort-Object -Unique
    if ($ips -contains $IPv4) {
      Write-Host "DNS OK: A $Name.$ZoneName -> $IPv4"
      return
    }
    throw "DNS record exists but IP mismatch. Existing: $($ips -join ', '), desired: $IPv4. Fix manually to avoid breaking clients."
  }

  if ($PSCmdlet.ShouldProcess("$Name.$ZoneName", "Create A record -> $IPv4 on $DnsServer")) {
    # Example syntax from Microsoft docs [web:334]
    Add-DnsServerResourceRecordA -ComputerName $DnsServer -Name $Name -ZoneName $ZoneName -IPv4Address $IPv4 -TimeToLive 01:00:00 | Out-Null
    Write-Host "DNS CREATED: A $Name.$ZoneName -> $IPv4"
  }
}

function Ensure-ComputerAccount {
  param([string] $Name)

  Require-Command Get-ADComputer
  Require-Command New-ADComputer

  $obj = Get-ADComputer -Identity $Name -ErrorAction SilentlyContinue
  if ($obj) {
    Write-Host "AD OK: computer account exists: $Name"
    return
  }

  if ($PSCmdlet.ShouldProcess($Name, "Create AD computer account")) {
    New-ADComputer -Name $Name -SamAccountName $Name -Enabled $true | Out-Null
    Write-Host "AD CREATED: computer account: $Name"
  }
}

function Ensure-Spns {
  param([string] $Domain, [string] $Computer, [string] $ZoneName, [string] $AliasHost)

  Require-Command setspn

  $acct = "$Domain\$Computer$"
  $spn1 = "cifs/$AliasHost"
  $spn2 = "cifs/$AliasHost.$ZoneName"

  Write-Host "Target account: $acct"
  Write-Host "Ensuring SPNs: $spn1, $spn2"

  if ($PSCmdlet.ShouldProcess($acct, "setspn -S $spn1")) {
    # -S adds SPN and checks for duplicates [web:287]
    & setspn -S $spn1 $acct | Out-Host
  }
  if ($PSCmdlet.ShouldProcess($acct, "setspn -S $spn2")) {
    & setspn -S $spn2 $acct | Out-Host
  }

  Write-Host "Querying SPNs:"
  & setspn -Q $spn1 | Out-Host     # -Q queries existing SPNs [web:287]
  & setspn -Q $spn2 | Out-Host

  Write-Host "Listing SPNs on account:"
  & setspn -L $acct | Out-Host     # -L lists SPNs on the account [web:287]

  Write-Host "Checking duplicate SPNs (domain/targets):"
  & setspn -X | Out-Host           # -X searches duplicate SPNs [web:287]
}

Write-Host "=== AD setup for SMB service alias ==="
Write-Host "Zone: $ZoneName  Alias: $AliasHost  VIP: $VipIPv4"
Write-Host "Service computer: $ServiceComputer  Domain: $NetbiosDomain  DNS server: $DnsServer"

if (-not $SkipDns) {
  Ensure-DnsARecord -DnsServer $DnsServer -ZoneName $ZoneName -Name $AliasHost -IPv4 $VipIPv4
} else {
  Write-Host "Skipping DNS step."
}

if (-not $SkipComputerAccount) {
  # Uses ActiveDirectory module; if not present, user can create manually
  if (Get-Module -ListAvailable ActiveDirectory) {
    Import-Module ActiveDirectory
    Ensure-ComputerAccount -Name $ServiceComputer
  } else {
    Write-Host "ActiveDirectory module not available; skipping computer account creation."
  }
} else {
  Write-Host "Skipping computer account step."
}

if (-not $SkipSpn) {
  Ensure-Spns -Domain $NetbiosDomain -Computer $ServiceComputer -ZoneName $ZoneName -AliasHost $AliasHost
} else {
  Write-Host "Skipping SPN step."
}

Write-Host "DONE."
```


## Como usar (exemplos)

1) Executar criando DNS A record + SPNs (e computer account se o módulo AD existir):
```powershell
.\ad_setup_fileserver.ps1 -ZoneName empresa.com.br -VipIPv4 10.10.10.50 -DnsServer DC01 -NetbiosDomain EMPRESA
```

2) Só validar/forçar SPNs (sem mexer em DNS):
```powershell
.\ad_setup_fileserver.ps1 -ZoneName empresa.com.br -VipIPv4 10.10.10.50 -SkipDns -NetbiosDomain EMPRESA
```

Esses cmdlets (`Add-DnsServerResourceRecordA`, `Get-DnsServerResourceRecord`) e as flags do `setspn` (`-S`, `-Q`, `-X`, `-L`) têm sintaxe e exemplos documentados pela Microsoft.[^18_2][^18_3][^18_1]

## Bloco para o prompt do seu agente local (para chamar o script)

```text
Adicionar artefato AD-side:
- artifacts/scripts/ad_setup_fileserver.ps1

Documentar no runbook que o script deve ser rodado em um DC/DNS com permissões:
- cria A record fileserver.empresa.com.br -> VIP via Add-DnsServerResourceRecordA [web:334]
- valida/consulta A record via Get-DnsServerResourceRecord [web:341]
- cria/valida SPNs CIFS na conta EMPRESA\EMPRESA-FILESERVER$ via setspn -S/-Q/-L e checa duplicidade com setspn -X [web:287]
```

Se você quiser que isso fique ainda mais “zero toque”, posso adaptar o script para também:

- criar um relatório JSON (para sua pipeline/CI),
- e aplicar `-WhatIf` por padrão, exigindo um `-Apply` explícito (mais seguro em produção).
<span style="display:none">[^18_10][^18_11][^18_12][^18_13][^18_14][^18_15][^18_4][^18_5][^18_6][^18_7][^18_8][^18_9]</span>

<div align="center">⁂</div>

[^18_1]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserverresourcerecorda?view=windowsserver2025-ps

[^18_2]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setspn

[^18_3]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/get-dnsserverresourcerecord?view=windowsserver2025-ps

[^18_4]: https://documentation.commvault.com/v11/commcell-console/creating_dns_record_using_powershell_commands.html

[^18_5]: https://stackoverflow.com/questions/72986587/powershell-to-add-a-record-to-a-dns-sub-domain

[^18_6]: https://www.manageengine.com/products/ad-manager/powershell-dns-commands/add-dns-server-resource-recordA.html

[^18_7]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserverresourcerecorda?view=windowsserver2022-ps

[^18_8]: https://www.reddit.com/r/PowerShell/comments/tos28h/how_to_get_just_the_root_level_records_with/

[^18_9]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserverresourcerecord?view=windowsserver2025-ps

[^18_10]: https://documentation.agilepoint.com/supportportal/docs/productdocumentation/05.02.0000/documentationlibrary/maps/preinstallSetSPN.html

[^18_11]: https://jotelulu.com/en-gb/blog/deploy-dns-server-using-powershell-commands/

[^18_12]: https://stackoverflow.com/questions/35097158/how-to-get-the-real-recorddata-from-dnsserverresourcerecord-using-powershell

[^18_13]: https://www.ibm.com/docs/SSKTMJ_9.0.1/admin/conf_assigningspnsusingthesetspnutility_t.html

[^18_14]: https://stackoverflow.com/questions/39286570/registering-a-record-in-dns-remotely-using-powershell

[^18_15]: https://forums.powershell.org/t/get-dnsserverresourcerecord/4308


---

# sim

Ajusto perfeito: vamos transformar o `ad_setup_fileserver.ps1` em “dry-run por padrão”, exigindo `-Apply` para mudanças, e vamos gerar um relatório JSON ao final. Isso aproveita o padrão do PowerShell de `SupportsShouldProcess` (habilita `-WhatIf`/`-Confirm` quando você envolve mudanças com `ShouldProcess`) e também o fato de cmdlets de DNS como `Add-DnsServerResourceRecordA` suportarem `-WhatIf` e `-Confirm`.[^19_1][^19_2]

## Artefato atualizado (dry-run default + JSON)

Substitua o conteúdo do arquivo `artifacts/scripts/ad_setup_fileserver.ps1` por este (ou salve como `ad_setup_fileserver.premium.ps1` e depois renomeie):

```powershell
<#
Premium AD-side setup (dry-run by default) for Samba A/P service alias:

Creates/verifies:
- DNS A record: fileserver.empresa.com.br -> VIP
- Dedicated computer account: EMPRESA-FILESERVER (or your chosen name)
- SPNs: cifs/fileserver and cifs/fileserver.empresa.com.br on EMPRESA-FILESERVER$
- Duplicate SPN scan

Defaults:
- DRY-RUN unless -Apply is specified
- Writes a JSON report (success/errors) to -ReportPath

References:
- ShouldProcess enables -WhatIf/-Confirm patterns [web:348]
- Add-DnsServerResourceRecordA has -WhatIf/-Confirm [web:338]
- setspn options -S/-Q/-L/-X [web:287]
- JSON writing via ConvertTo-Json + Set-Content -Encoding UTF8 [web:353]
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
  [Parameter(Mandatory = $false)]
  [string] $ZoneName = "empresa.com.br",

  [Parameter(Mandatory = $true)]
  [string] $VipIPv4,

  [Parameter(Mandatory = $false)]
  [string] $DnsServer = $env:COMPUTERNAME,

  [Parameter(Mandatory = $false)]
  [string] $AliasHost = "fileserver",

  [Parameter(Mandatory = $false)]
  [string] $ServiceComputer = "EMPRESA-FILESERVER",

  [Parameter(Mandatory = $false)]
  [string] $NetbiosDomain = "EMPRESA",

  [Parameter(Mandatory = $false)]
  [string] $ReportPath = ".\ad_setup_fileserver.report.json",

  [switch] $SkipComputerAccount,
  [switch] $SkipDns,
  [switch] $SkipSpn,

  # Safety: script does NOT change anything unless you explicitly pass -Apply
  [switch] $Apply
)

# Dry-run default (even if caller forgets -WhatIf)
if (-not $Apply) {
  $WhatIfPreference = $true
}

$report = [ordered]@{
  timestamp = (Get-Date).ToString("o")
  mode      = $(if ($Apply) { "apply" } else { "dry-run" })
  inputs    = [ordered]@{
    ZoneName        = $ZoneName
    VipIPv4         = $VipIPv4
    DnsServer       = $DnsServer
    AliasHost       = $AliasHost
    ServiceComputer = $ServiceComputer
    NetbiosDomain   = $NetbiosDomain
    ReportPath      = $ReportPath
    SkipDns         = [bool]$SkipDns
    SkipComputerAccount = [bool]$SkipComputerAccount
    SkipSpn         = [bool]$SkipSpn
  }
  steps = @()
  ok    = $true
}

function Add-StepResult {
  param(
    [string]$Name,
    [string]$Status,
    [string]$Message,
    $Data = $null
  )
  $script:report.steps += [ordered]@{
    name = $Name
    status = $Status
    message = $Message
    data = $Data
  }
  if ($Status -ne "ok") { $script:report.ok = $false }
}

function Require-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing command: $Name"
  }
}

function Ensure-DnsARecord {
  param([string] $DnsServer, [string] $ZoneName, [string] $Name, [string] $IPv4)

  Require-Command Get-DnsServerResourceRecord
  Require-Command Add-DnsServerResourceRecordA

  $step = "dns_a_record"
  try {
    $existing = Get-DnsServerResourceRecord -ComputerName $DnsServer -ZoneName $ZoneName -Name $Name -RRType "A" -ErrorAction SilentlyContinue
    if ($existing) {
      $ips = @($existing | ForEach-Object { $_.RecordData.IPv4Address.IPAddressToString }) | Sort-Object -Unique
      if ($ips -contains $IPv4) {
        Add-StepResult -Name $step -Status "ok" -Message "DNS OK: A $Name.$ZoneName -> $IPv4" -Data @{existingIps=$ips}
        return
      }
      Add-StepResult -Name $step -Status "error" -Message "DNS A exists but IP mismatch (existing: $($ips -join ', '), desired: $IPv4). Fix manually." -Data @{existingIps=$ips; desiredIp=$IPv4}
      return
    }

    if ($PSCmdlet.ShouldProcess("$Name.$ZoneName on $DnsServer", "Create A record -> $IPv4")) {
      Add-DnsServerResourceRecordA -ComputerName $DnsServer -Name $Name -ZoneName $ZoneName -IPv4Address $IPv4 -TimeToLive 01:00:00 -WhatIf:$WhatIfPreference -Confirm:$false | Out-Null
      Add-StepResult -Name $step -Status "ok" -Message "DNS A created (or would be created in dry-run): $Name.$ZoneName -> $IPv4"
    } else {
      Add-StepResult -Name $step -Status "warn" -Message "DNS step skipped by ShouldProcess"
    }
  } catch {
    Add-StepResult -Name $step -Status "error" -Message ("DNS step failed: " + $_.Exception.Message)
  }
}

function Ensure-ComputerAccount {
  param([string] $Name)

  $step = "ad_computer_account"
  try {
    if (-not (Get-Module -ListAvailable ActiveDirectory)) {
      Add-StepResult -Name $step -Status "warn" -Message "ActiveDirectory module not available; create computer account manually: $Name"
      return
    }

    Import-Module ActiveDirectory

    $obj = Get-ADComputer -Identity $Name -ErrorAction SilentlyContinue
    if ($obj) {
      Add-StepResult -Name $step -Status "ok" -Message "AD OK: computer account exists: $Name"
      return
    }

    if ($PSCmdlet.ShouldProcess("AD computer $Name", "Create computer account")) {
      New-ADComputer -Name $Name -SamAccountName $Name -Enabled $true -WhatIf:$WhatIfPreference -Confirm:$false | Out-Null
      Add-StepResult -Name $step -Status "ok" -Message "AD computer created (or would be created in dry-run): $Name"
    } else {
      Add-StepResult -Name $step -Status "warn" -Message "Computer account step skipped by ShouldProcess"
    }
  } catch {
    Add-StepResult -Name $step -Status "error" -Message ("Computer account step failed: " + $_.Exception.Message)
  }
}

function Ensure-Spns {
  param([string] $Domain, [string] $Computer, [string] $ZoneName, [string] $AliasHost)

  $step = "spn_cifs"
  try {
    Require-Command setspn

    $acct = "$Domain\$Computer$"
    $spn1 = "cifs/$AliasHost"
    $spn2 = "cifs/$AliasHost.$ZoneName"

    $planned = @(
      "setspn -S $spn1 $acct",
      "setspn -S $spn2 $acct",
      "setspn -Q $spn1",
      "setspn -Q $spn2",
      "setspn -L $acct",
      "setspn -X"
    )

    if (-not $Apply) {
      Add-StepResult -Name $step -Status "ok" -Message "DRY-RUN: would run setspn commands" -Data @{commands=$planned}
      return
    }

    # External command: gate it with ShouldProcess (setspn itself has no -WhatIf)
    if ($PSCmdlet.ShouldProcess($acct, "Add/verify CIFS SPNs for fileserver")) {
      & setspn -S $spn1 $acct | Out-String | Out-Null
      & setspn -S $spn2 $acct | Out-String | Out-Null
      $q1 = & setspn -Q $spn1 2>&1 | Out-String
      $q2 = & setspn -Q $spn2 2>&1 | Out-String
      $l  = & setspn -L $acct 2>&1 | Out-String
      $x  = & setspn -X 2>&1 | Out-String

      Add-StepResult -Name $step -Status "ok" -Message "SPNs applied and verified" -Data @{
        account=$acct; spn1=$spn1; spn2=$spn2;
        query1=$q1; query2=$q2; list=$l; dupScan=$x
      }
    } else {
      Add-StepResult -Name $step -Status "warn" -Message "SPN step skipped by ShouldProcess" -Data @{commands=$planned}
    }
  } catch {
    Add-StepResult -Name $step -Status "error" -Message ("SPN step failed: " + $_.Exception.Message)
  }
}

Write-Host "=== AD setup: $AliasHost.$ZoneName -> $VipIPv4  (mode: $($report.mode)) ==="

if (-not $SkipDns) { Ensure-DnsARecord -DnsServer $DnsServer -ZoneName $ZoneName -Name $AliasHost -IPv4 $VipIPv4 }
else { Add-StepResult -Name "dns_a_record" -Status "warn" -Message "Skipped by parameter" }

if (-not $SkipComputerAccount) { Ensure-ComputerAccount -Name $ServiceComputer }
else { Add-StepResult -Name "ad_computer_account" -Status "warn" -Message "Skipped by parameter" }

if (-not $SkipSpn) { Ensure-Spns -Domain $NetbiosDomain -Computer $ServiceComputer -ZoneName $ZoneName -AliasHost $AliasHost }
else { Add-StepResult -Name "spn_cifs" -Status "warn" -Message "Skipped by parameter" }

# Write JSON report (UTF-8)
try {
  $json = $report | ConvertTo-Json -Depth 10
  $json | Set-Content -Path $ReportPath -Encoding UTF8
  Write-Host "Report written: $ReportPath"
} catch {
  Write-Host "Failed to write report: $($_.Exception.Message)"
  exit 3
}

if (-not $report.ok) { exit 2 }
```


### Por que isso é “premium” (e seguro)

- **Dry-run por padrão**: sem `-Apply`, ele não muda nada e ainda gera um relatório “o que faria”.
- **DNS cmdlets com -WhatIf/-Confirm**: `Add-DnsServerResourceRecordA` suporta `-WhatIf`/`-Confirm`, então conseguimos simular criação sem risco.[^19_2]
- **ShouldProcess**: o padrão para suportar `-WhatIf`/`-Confirm` é usar `SupportsShouldProcess` e proteger ações mutáveis com `ShouldProcess`.[^19_1]
- **Relatório JSON UTF‑8**: escrever JSON com `ConvertTo-Json` e `Set-Content -Encoding UTF8` é um caminho comum para evitar problemas de encoding no consumo posterior.[^19_3]
- **SPN**: usa `setspn -S/-Q/-L/-X` (adicionar com verificação de duplicidade, consultar, listar e checar duplicados).[^19_4]


## Como rodar

Dry-run (default, sem mudanças):

```powershell
.\ad_setup_fileserver.ps1 -VipIPv4 10.10.10.50 -DnsServer DC01
```

Aplicar de verdade (mudanças reais):

```powershell
.\ad_setup_fileserver.ps1 -VipIPv4 10.10.10.50 -DnsServer DC01 -Apply
```

Gerar relatório em caminho específico:

```powershell
.\ad_setup_fileserver.ps1 -VipIPv4 10.10.10.50 -DnsServer DC01 -Apply -ReportPath C:\Temp\fileserver_ad_report.json
```

Se você quiser, eu também consigo te entregar um “wrapper” no Debian (`/usr/local/sbin/ad-precheck-fileserver`) que:

- pergunta `VIP`, `DC/DNS`, `credenciais`,
- executa remotamente esse PS1 via WinRM/SSH (conforme sua política),
- e anexa o JSON no log do instalador.
<span style="display:none">[^19_10][^19_11][^19_12][^19_13][^19_14][^19_15][^19_16][^19_5][^19_6][^19_7][^19_8][^19_9]</span>

<div align="center">⁂</div>

[^19_1]: https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess?view=powershell-7.5

[^19_2]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserverresourcerecorda?view=windowsserver2022-ps

[^19_3]: https://powershellfaqs.com/write-json-to-file-in-powershell/

[^19_4]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setspn

[^19_5]: https://stackoverflow.com/questions/34749333/powershell-guidelines-for-confirm-force-and-whatif

[^19_6]: https://becomelotr.wordpress.com/2013/05/01/supports-should-process-oh-really/

[^19_7]: https://jdhitsolutions.com/blog/scripting/1869/add-whatif-support-to-your-powershell-scripts/

[^19_8]: https://rakhesh.com/powershell/powershell-confirm-and-whatif/

[^19_9]: https://stackoverflow.com/questions/46183443/how-not-to-propagate-whatif-and-confirm

[^19_10]: https://debay.blog/2019/10/03/powershell-utf8-and-bom/

[^19_11]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserverresourcerecord?view=windowsserver2025-ps

[^19_12]: https://stackoverflow.com/questions/7180271/how-do-you-support-powershells-whatif-confirm-parameters-in-a-cmdlet-that-c

[^19_13]: https://stackoverflow.com/questions/67724862/create-json-file-with-encoding-utf-8-using-powershell-script

[^19_14]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserverresourcerecorda?view=windowsserver2025-ps

[^19_15]: https://www.reddit.com/r/PowerShell/comments/rdg7gd/supportsshouldprocess_options_for_formatting/

[^19_16]: https://stackoverflow.com/questions/33936043/modify-a-json-file-with-powershell-without-writing-bom


---

# sim

A seguir está o “wrapper” Debian-side que você pediu, em nível **profissional**, com duas opções de execução remota do script AD-side:

1) **SSH para Windows** (preferido quando você consegue habilitar OpenSSH Server no DC/servidor de administração; é simples e auditável).[^20_1][^20_2]
2) **WinRM via pywinrm** (funciona bem, mas costuma exigir mais ajustes e política de segurança; use se SSH não for permitido).[^20_3][^20_4]

Também inclui artefatos para salvar no repo, para seu agente local só “plugar” no live-build.

***

## Artefato 1: script Debian-side (wrapper)

Salve como `artifacts/scripts/ad_precheck_fileserver.sh` e instale no sistema final em `/usr/local/sbin/ad-precheck-fileserver`.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Wrapper Debian-side to run the AD-side PowerShell script that:
# - creates/verifies DNS A record fileserver.empresa.com.br -> VIP
# - creates/verifies computer account EMPRESA-FILESERVER
# - sets SPNs cifs/fileserver and cifs/fileserver.empresa.com.br
# - writes JSON report
#
# Remote exec methods:
#   (A) SSH to Windows (recommended) -> runs pwsh
#   (B) WinRM via pywinrm (optional)

usage() {
  cat <<'EOF'
Usage:
  ad-precheck-fileserver --method ssh --host DC01.empresa.com.br --user 'EMPRESA\admin' \
    --vip 10.10.10.50 --dns-server DC01 --report /var/log/my-nas/ad_report.json [--apply]

  ad-precheck-fileserver --method winrm --host DC01.empresa.com.br --user 'EMPRESA\admin' \
    --vip 10.10.10.50 --dns-server DC01 --report /var/log/my-nas/ad_report.json [--apply]

Notes:
- Without --apply, it is DRY-RUN (safe).
- Requires artifacts/scripts/ad_setup_fileserver.ps1 present locally.
EOF
}

METHOD=""
HOST=""
USER=""
VIP=""
DNSSERVER=""
REPORT="/var/log/my-nas/ad_setup_fileserver.report.json"
APPLY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method) METHOD="$2"; shift 2;;
    --host) HOST="$2"; shift 2;;
    --user) USER="$2"; shift 2;;
    --vip) VIP="$2"; shift 2;;
    --dns-server) DNSSERVER="$2"; shift 2;;
    --report) REPORT="$2"; shift 2;;
    --apply) APPLY="true"; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

[[ -n "$METHOD" && -n "$HOST" && -n "$USER" && -n "$VIP" && -n "$DNSSERVER" ]] || { usage; exit 2; }

SCRIPT_LOCAL="/usr/local/share/my-nas/scripts/ad_setup_fileserver.ps1"
[[ -f "$SCRIPT_LOCAL" ]] || { echo "Missing $SCRIPT_LOCAL"; exit 1; }

mkdir -p "$(dirname "$REPORT")"

run_ssh() {
  command -v ssh >/dev/null 2>&1 || { echo "ssh not installed"; exit 1; }

  # Copy script to Windows temp and run with pwsh.
  # PowerShell remoting over SSH is an official approach; pwsh can be used as the remote host process. [web:363]
  # OpenSSH server on Windows can be installed/enabled via Microsoft guidance. [web:362]
  tmp="C:/Windows/Temp/ad_setup_fileserver.ps1"

  echo "Copying PS1 to Windows via scp..."
  command -v scp >/dev/null 2>&1 || { echo "scp not installed"; exit 1; }
  scp -q "$SCRIPT_LOCAL" "${USER}@${HOST}:${tmp}"

  # Build command (dry-run by default; script needs -Apply to change)
  args="-VipIPv4 ${VIP} -DnsServer ${DNSSERVER} -ReportPath C:/Windows/Temp/ad_setup_fileserver.report.json"
  if [[ "$APPLY" == "true" ]]; then args="${args} -Apply"; fi

  echo "Running remote PowerShell via SSH..."
  ssh -o BatchMode=no "${USER}@${HOST}" "pwsh -NoProfile -ExecutionPolicy Bypass -File ${tmp} ${args}"

  echo "Fetching JSON report..."
  scp -q "${USER}@${HOST}:C:/Windows/Temp/ad_setup_fileserver.report.json" "$REPORT"
}

run_winrm() {
  # Uses pywinrm to run PS remotely. [web:367]
  command -v python3 >/dev/null 2>&1 || { echo "python3 not installed"; exit 1; }
  python3 - <<PY
import getpass, json, pathlib
import winrm  # pip install pywinrm  [web:367]

host = "${HOST}"
user = "${USER}"
vip  = "${VIP}"
dns  = "${DNSSERVER}"
apply = ${"True" if APPLY=="true" else "False"}
script_path = "${SCRIPT_LOCAL}"
report_path = "${REPORT}"

pw = getpass.getpass("WinRM password for %s: " % user)

ps = pathlib.Path(script_path).read_text(encoding="utf-8")
# Invoke the script content, then call it as a function-like invocation by writing it to temp and executing.
# For simplicity: run script text directly + call with params.
cmd = ps + "\n" + f"\n& ad_setup_fileserver.ps1 -VipIPv4 '{vip}' -DnsServer '{dns}' -ReportPath '{report_path}'" + (" -Apply" if apply else "")

s = winrm.Session(host, auth=(user, pw))
r = s.run_ps(cmd)
if r.status_code != 0:
    raise SystemExit("WinRM failed: %s" % r.std_err.decode(errors="ignore"))
print(r.std_out.decode(errors="ignore"))
PY
}

case "$METHOD" in
  ssh) run_ssh;;
  winrm) run_winrm;;
  *) echo "Invalid --method (use ssh|winrm)"; exit 2;;
esac

echo "OK. Report saved to: $REPORT"
```

**Referências (por que isso é válido):**

- OpenSSH Server no Windows tem guia oficial de instalação/uso.[^20_1]
- PowerShell Remoting sobre SSH é suportado oficialmente, com sessão remota iniciando um processo PowerShell no host destino.[^20_2]
- `pywinrm` permite executar scripts PowerShell remotamente via WinRM e tem exemplos de `run_ps()`.[^20_4]

***

## Artefato 2: instalar OpenSSH Server (lado Windows) — mini runbook

Salve como `docs/33_WINDOWS_ENABLE_SSH_FOR_AD_AUTOMATION.md`.

```md
# Habilitar OpenSSH Server no Windows (para automação AD via SSH)

A Microsoft documenta instalação e primeiro uso do OpenSSH Server no Windows via PowerShell. [web:362]

Resumo:
- Instalar capability OpenSSH.Server
- Iniciar e habilitar serviço sshd
- Liberar firewall se necessário
- Usar uma conta com permissão para DNS/SPN

Depois, do Debian, executar:
- scp do script ad_setup_fileserver.ps1
- ssh para rodar pwsh remotamente
```


***

## Artefato 3: integrar no live-build

Inclua esses arquivos no filesystem da ISO:

- `config/includes.chroot/usr/local/share/my-nas/scripts/ad_setup_fileserver.ps1`
- `config/includes.chroot/usr/local/sbin/ad-precheck-fileserver` (chmod +x)

E inclua dependências:

- Para método ssh: `openssh-client` (Debian), e no Windows `OpenSSH.Server`[^20_1]
- Para método winrm: `python3` + `python3-pip` + `pywinrm` (se você realmente quiser suportar).

***

## Bloco para o prompt do seu agente local (para incorporar o wrapper)

```text
Adicionar execução AD-side opcional (zero toque, mas seguro):
- Instalar /usr/local/sbin/ad-precheck-fileserver (wrapper Debian)
- Incluir /usr/local/share/my-nas/scripts/ad_setup_fileserver.ps1 no sistema
- Método preferido: SSH -> pwsh (documentado como PowerShell remoting over SSH) [web:363]
- Windows: habilitar OpenSSH Server conforme guia MS [web:362]
- O wrapper deve rodar em DRY-RUN por padrão e só mudar AD/DNS com --apply
- O wrapper deve sempre salvar o JSON report em /var/log/my-nas/
```

Se você preferir **não depender** de habilitar SSH no DC, posso ajustar o wrapper para rodar o `.ps1` em uma “jump box” Windows (workstation admin) com RSAT/DNS tools, e só exigir acesso a essa jump box (bem mais comum em empresas).
<span style="display:none">[^20_10][^20_11][^20_12][^20_13][^20_14][^20_5][^20_6][^20_7][^20_8][^20_9]</span>

<div align="center">⁂</div>

[^20_1]: https://learn.microsoft.com/pt-br/windows-server/administration/openssh/openssh_install_firstuse

[^20_2]: https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/ssh-remoting-in-powershell?view=powershell-7.5

[^20_3]: https://adamtheautomator.com/python-winrm/

[^20_4]: https://github.com/diyan/pywinrm/

[^20_5]: https://www.reddit.com/r/sysadmin/comments/imjjuf/run_powershell_over_ssh_from_linux_to_windows/

[^20_6]: https://stackoverflow.com/questions/6423879/execute-powershell-command-over-ssh

[^20_7]: https://www.youtube.com/watch?v=Zin9xhU5P58

[^20_8]: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse

[^20_9]: https://stackoverflow.com/questions/53034988/powershell-script-ssh-into-server

[^20_10]: https://www.ionos.com/digitalguide/server/configuration/powershell-ssh/

[^20_11]: https://www.reddit.com/r/PowerShell/comments/11zr8gh/remotely_enable_psremoting/

[^20_12]: https://www.reddit.com/r/PowerShell/comments/gxtrzz/execute_powershell_commands_via_ssh/

[^20_13]: https://www.sentinel.com/resources/blog/sentinel-blog/2023/12/13/powershell-remoting-over-ssh

[^20_14]: https://github.com/diyan/pywinrm


---

# sim

Perfeito — dá para deixar isso “enterprise-friendly” usando uma **jump box** Windows (workstation/admin VM) com RSAT e ferramentas de DNS, em vez de habilitar SSH/WinRM diretamente no DC. Isso normalmente aumenta a chance de aprovação por segurança e ainda mantém automação.

A Microsoft descreve que o módulo **DnsServer** (PowerShell) pode ser obtido instalando o role DNS Server **ou** adicionando o componente “DNS Server Tools” do **RSAT**.[^21_1][^21_2]

## Estratégia recomendada (Jump Box)

### Visão geral

- Você terá um host Windows de administração (jump box) com:
    - RSAT (incluindo DNS Server Tools)[^21_1]
    - `setspn` disponível (Windows)[^21_3]
    - OpenSSH Server habilitado **só na jump box** (opcional), para o Debian rodar o script via SSH[^21_4]
- O script `ad_setup_fileserver.ps1` roda na jump box e conversa com:
    - DNS do AD (criando/validando A record) via cmdlets do módulo DnsServer[^21_5][^21_6]
    - AD para SPN via `setspn -S/-Q/-L/-X`[^21_3]

Isso evita expor DC a SSH/WinRM, e você mantém rastreabilidade no host administrativo.

## Artefato extra: runbook para Jump Box

Salve como `docs/34_JUMPBOX_SETUP.md`.

```md
# Jump Box Windows (Admin Host) para automação AD/DNS/SPN

Objetivo: executar artifacts/scripts/ad_setup_fileserver.ps1 em um host Windows administrativo, sem habilitar automação no DC.

## Requisitos
- RSAT instalado; DNS Server Tools incluído (fornece DNS Manager + módulo DnsServer do PowerShell). [web:374][web:375]
- Permissão da conta admin para:
  - criar/alterar registro A em empresa.com.br
  - criar/alterar SPNs na conta EMPRESA\EMPRESA-FILESERVER$

## Opções de execução remota a partir do Debian
- Preferida: SSH para a jump box e executar pwsh remoto (PowerShell remoting over SSH cria processo PowerShell no alvo). [web:363]
- Alternativa: WinRM/pywinrm (somente se política permitir).

## Observação
- O script usa Add-DnsServerResourceRecordA / Get-DnsServerResourceRecord e isso requer o módulo DnsServer (via RSAT DNS Tools ou role DNS). [web:334][web:341][web:375]
```


## Atualização do wrapper Debian-side

No `artifacts/scripts/ad_precheck_fileserver.sh`, trate `--host` como “jump box” (não DC), e mantenha `--dns-server` apontando para o DC/DNS real (ex.: `DC01`).
Isso funciona porque `Get-DnsServerResourceRecord` aceita `-ComputerName` para apontar o DNS server alvo (o script já usa isso).[^21_5]

Exemplo de uso (Debian → JumpBox):

```bash
sudo ad-precheck-fileserver \
  --method ssh \
  --host JUMPBOX-ADM.empresa.com.br \
  --user 'EMPRESA\admin' \
  --vip 10.10.10.50 \
  --dns-server DC01 \
  --report /var/log/my-nas/ad_report.json \
  --apply
```


## Bloco para o prompt do seu agente local

```text
MODO JUMP BOX (preferido)

- Não habilitar SSH/WinRM no DC.
- Criar uma jump box Windows com RSAT (inclui DNS Server Tools e módulo DnsServer). [web:374][web:375]
- Rodar artifacts/scripts/ad_setup_fileserver.ps1 na jump box:
  - DNS A record via Add-DnsServerResourceRecordA / Get-DnsServerResourceRecord [web:334][web:341]
  - SPNs via setspn -S/-Q/-L/-X [web:287]
- Debian chama a jump box via SSH (PowerShell remoting over SSH cria host process no alvo). [web:363]
- Wrapper ad-precheck-fileserver: --host = jump box, --dns-server = DC real
```

Se você quiser, eu também ajusto os artefatos para suportar **chave SSH** (sem senha) na jump box, e para o wrapper Debian fazer “upload, executar, baixar JSON” com verificação de hash (integridade) e rotação de relatórios.
<span style="display:none">[^21_10][^21_11][^21_12][^21_13][^21_14][^21_15][^21_16][^21_17][^21_7][^21_8][^21_9]</span>

<div align="center">⁂</div>

[^21_1]: https://learn.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/remote-server-administration-tools

[^21_2]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/?view=windowsserver2025-ps

[^21_3]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setspn

[^21_4]: https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/ssh-remoting-in-powershell?view=powershell-7.5

[^21_5]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/get-dnsserverresourcerecord?view=windowsserver2025-ps

[^21_6]: https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserverresourcerecorda?view=windowsserver2025-ps

[^21_7]: https://www.pdq.com/blog/how-to-install-remote-server-administration-tools-rsat/

[^21_8]: https://activedirectorypro.com/install-rsat-remote-server-administration-tools-windows-10/

[^21_9]: https://www.reddit.com/r/PowerShell/comments/ykyo3a/connecting_to_a_dns_server_through_powershell/

[^21_10]: https://www.reddit.com/r/sysadmin/comments/10b1qjg/windows_as_ssh_jump_host/

[^21_11]: https://stackoverflow.com/questions/71197103/import-powershell-dns-server-module/73347338

[^21_12]: https://www.reddit.com/r/PowerShell/comments/tos28h/how_to_get_just_the_root_level_records_with/

[^21_13]: https://stackoverflow.com/questions/60101828/how-to-retrieve-all-dns-records-using-powershell-without-dnsserver-module

[^21_14]: https://www.techtarget.com/searchwindowsserver/tutorial/PowerShell-7-remoting-expands-management-horizons

[^21_15]: https://stackoverflow.com/questions/71197103/import-powershell-dns-server-module

[^21_16]: https://www.pluralsight.com/resources/blog/tech-operations/windows-vista-rsat

[^21_17]: https://learn.microsoft.com/th-th/powershell/scripting/security/remoting/ssh-remoting-in-powershell?view=powershell-7.4


---

# sim

A seguir estão os artefatos e ajustes para deixar o modo Jump Box com **SSH por chave**, **verificação de integridade**, **relatórios JSON rotacionados**, e execução “upload → run → download” totalmente automatizada.

***

## Artefato: SSH por chave na Jump Box (Windows)

Salve como `docs/35_JUMPBOX_SSH_KEYS.md`.

```md
# Jump Box: SSH por chave (Windows OpenSSH) para automação do NAS

Objetivo: permitir que o Debian (instalador/first-boot) rode scripts PowerShell na Jump Box via SSH sem senha.

## 1) Key-based auth no OpenSSH do Windows

A Microsoft documenta que, para contas administrativas, as chaves públicas devem ir em:
%ProgramData%\ssh\administrators_authorized_keys
e recomenda ajustar permissões com icacls para Administrators e SYSTEM. [web:386]

Exemplo (rodar na Jump Box em PowerShell como admin):
- Criar/editar arquivo:
  $path = "$env:ProgramData\ssh\administrators_authorized_keys"
  New-Item -Force -Path $path | Out-Null
  Add-Content -Force -Path $path -Value '<COLE_AQUI_A_PUBLIC_KEY_DO_DEBIAN>'
- Fixar ACLs:
  icacls.exe "$path" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

## 2) Observação importante
- Para contas não-admin, o authorized_keys pode ficar no perfil do usuário; para admin, o comportamento padrão usa administrators_authorized_keys. [web:386]
```


***

## Artefato: PowerShell “subsystem” opcional (PS Remoting over SSH)

Se você quiser evoluir depois de “rodar pwsh -File”, a Microsoft documenta o uso de *subsystem* do PowerShell no `sshd_config` (em `$Env:ProgramData\ssh`) para hospedar um processo PowerShell via SSH.[^22_1]

Salve como `docs/36_POWERSHELL_OVER_SSH_SUBSYSTEM.md`:

```md
# PowerShell Remoting over SSH (subsystem) - opção futura

A Microsoft descreve que é possível adicionar um Subsystem "powershell" no sshd_config para hospedar um processo PowerShell via SSH. [web:363]

Benefício: sessões PowerShell mais "nativas" via SSH.
Risco/custo: mexe em sshd_config, exige restart do serviço e padronização do caminho do pwsh. [web:363]
```


***

## Artefato: wrapper Debian-side “premium” (chave, hostkey, hash, rotação)

Substitua seu `artifacts/scripts/ad_precheck_fileserver.sh` por esta versão (ou salve como `ad_precheck_fileserver.premium.sh` e use ela).

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ad-precheck-fileserver --host JUMPBOX-ADM.empresa.com.br --user 'EMPRESA\admin' \
    --vip 10.10.10.50 --dns-server DC01 --report-dir /var/log/my-nas/ad-precheck \
    [--apply] [--identity /root/.ssh/id_ed25519] [--known-hosts /etc/ssh/ssh_known_hosts.d/jumpbox] \
    [--keep 30]

Notes:
- DRY-RUN default (no changes) unless --apply is passed.
- Requires ad_setup_fileserver.ps1 installed at /usr/local/share/my-nas/scripts/ad_setup_fileserver.ps1
EOF
}

HOST=""; USER=""; VIP=""; DNSSERVER=""
REPORT_DIR="/var/log/my-nas/ad-precheck"
IDENTITY=""
KNOWN_HOSTS=""
APPLY="false"
KEEP="30"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2;;
    --user) USER="$2"; shift 2;;
    --vip) VIP="$2"; shift 2;;
    --dns-server) DNSSERVER="$2"; shift 2;;
    --report-dir) REPORT_DIR="$2"; shift 2;;
    --identity) IDENTITY="$2"; shift 2;;
    --known-hosts) KNOWN_HOSTS="$2"; shift 2;;
    --apply) APPLY="true"; shift 1;;
    --keep) KEEP="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

[[ -n "$HOST" && -n "$USER" && -n "$VIP" && -n "$DNSSERVER" ]] || { usage; exit 2; }

command -v ssh >/dev/null 2>&1 || { echo "ssh not installed"; exit 1; }
command -v scp >/dev/null 2>&1 || { echo "scp not installed"; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum not installed"; exit 1; }

SCRIPT_LOCAL="/usr/local/share/my-nas/scripts/ad_setup_fileserver.ps1"
[[ -f "$SCRIPT_LOCAL" ]] || { echo "Missing $SCRIPT_LOCAL"; exit 1; }

mkdir -p "$REPORT_DIR"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_LOCAL="${REPORT_DIR}/ad_setup_fileserver.${ts}.json"
HASH_LOCAL="${REPORT_LOCAL}.sha256"

# rotate (keep N newest)
ls -1t "${REPORT_DIR}"/ad_setup_fileserver.*.json 2>/dev/null | tail -n +"$((KEEP+1))" | xargs -r rm -f
ls -1t "${REPORT_DIR}"/ad_setup_fileserver.*.json.sha256 2>/dev/null | tail -n +"$((KEEP+1))" | xargs -r rm -f

ssh_opts=(-o LogLevel=ERROR -o StrictHostKeyChecking=yes -o BatchMode=yes)
if [[ -n "$IDENTITY" ]]; then ssh_opts+=(-i "$IDENTITY"); fi
if [[ -n "$KNOWN_HOSTS" ]]; then ssh_opts+=(-o UserKnownHostsFile="$KNOWN_HOSTS"); fi

tmp_ps1="C:/Windows/Temp/ad_setup_fileserver.ps1"
tmp_json="C:/Windows/Temp/ad_setup_fileserver.report.json"

echo "Uploading PS1..."
scp -q "${ssh_opts[@]}" "$SCRIPT_LOCAL" "${USER}@${HOST}:${tmp_ps1}"

args="-VipIPv4 ${VIP} -DnsServer ${DNSSERVER} -ReportPath ${tmp_json}"
if [[ "$APPLY" == "true" ]]; then args="${args} -Apply"; fi

echo "Running remote PowerShell..."
# Use pwsh if available; fallback to powershell if needed (agent can decide later).
ssh "${ssh_opts[@]}" "${USER}@${HOST}" "pwsh -NoProfile -ExecutionPolicy Bypass -File ${tmp_ps1} ${args}"

echo "Downloading JSON report..."
scp -q "${ssh_opts[@]}" "${USER}@${HOST}:${tmp_json}" "$REPORT_LOCAL"

sha256sum "$REPORT_LOCAL" | tee "$HASH_LOCAL" >/dev/null
echo "OK: report=$REPORT_LOCAL hash=$HASH_LOCAL"
```

O ponto-chave aqui é que você passa a usar autenticação por chave (sem senha), valida hostkey via `StrictHostKeyChecking=yes`, e sempre deixa evidência rastreável com JSON + SHA256.

***

## Artefato: known_hosts fixo para a Jump Box (evita TOFU)

Salve como `artifacts/docs/jumpbox_known_hosts.md`:

```md
# known_hosts da Jump Box

Recomendação: não usar "Trust On First Use" em produção.
1) Coletar a chave host SSH da Jump Box por canal confiável.
2) Gravar em /etc/ssh/ssh_known_hosts.d/jumpbox (no Debian do NAS).
3) Executar wrapper com --known-hosts apontando para esse arquivo.
```


***

## O que seu agente local deve fazer (prompt de continuação)

Cole isso como continuação do prompt do seu agente:

```text
Adicionar modo Jump Box "premium":

- Criar docs/35_JUMPBOX_SSH_KEYS.md com instruções de key-based auth no OpenSSH do Windows, usando administrators_authorized_keys e icacls conforme Microsoft. [web:386]
- (Opcional) Criar docs/36_POWERSHELL_OVER_SSH_SUBSYSTEM.md citando que Microsoft documenta Subsystem powershell no sshd_config para PS remoting over SSH. [web:363]

- Substituir wrapper Debian-side por artifacts/scripts/ad_precheck_fileserver.sh (versão premium):
  - SSH com chave (BatchMode=yes)
  - StrictHostKeyChecking=yes + UserKnownHostsFile específico
  - upload PS1 -> run -> download JSON
  - gerar sha256 do relatório
  - rotação de relatórios (--keep N)
- Integrar no live-build:
  - /usr/local/share/my-nas/scripts/ad_setup_fileserver.ps1
  - /usr/local/sbin/ad-precheck-fileserver (chmod +x)
  - diretório /etc/ssh/ssh_known_hosts.d/ para armazenar chave da jump box
```

Se você me disser qual SO será a Jump Box (Windows 10/11, ou Windows Server) e se vocês preferem autenticação SSH com **chave** para uma conta AD (ex.: `EMPRESA\svc-nas-automation`) ou para uma conta local, eu ajusto o `docs/35_...` com o caminho exato e o modelo de conta recomendado.
<span style="display:none">[^22_10][^22_11][^22_12][^22_13][^22_14][^22_15][^22_2][^22_3][^22_4][^22_5][^22_6][^22_7][^22_8][^22_9]</span>

<div align="center">⁂</div>

[^22_1]: https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/ssh-remoting-in-powershell?view=powershell-7.5

[^22_2]: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement

[^22_3]: https://stackoverflow.com/questions/16212816/setting-up-openssh-for-windows-using-public-key-authentication

[^22_4]: https://jadaptive.com/openssh-windows-administrators-authorized-keys/

[^22_5]: https://github.com/PowerShell/Win32-OpenSSH/issues/1324

[^22_6]: https://learn.microsoft.com/en-us/answers/questions/3796004/(solved)-openssh-server-on-windows-10-using-key-in

[^22_7]: https://www.thomasmaurer.ch/2020/04/enable-powershell-ssh-remoting-in-powershell-7/

[^22_8]: https://github.com/PowerShell/Win32-OpenSSH/issues/1948

[^22_9]: https://github.com/PowerShell/Win32-OpenSSH/issues/1942

[^22_10]: https://www.techtarget.com/searchwindowsserver/tutorial/PowerShell-7-remoting-expands-management-horizons

[^22_11]: https://github.com/PowerShell/Win32-OpenSSH/issues/2254

[^22_12]: https://www.ssh.com/academy/ssh/authorized-keys-openssh

[^22_13]: https://learn.microsoft.com/th-th/powershell/scripting/security/remoting/ssh-remoting-in-powershell?view=powershell-7.4

[^22_14]: https://erwin.co/configuring-openssh-server-sshd-on-windows-11/

[^22_15]: https://www.reddit.com/r/sysadmin/comments/ls1n0b/key_based_authentication_on_windows_server_2019/


---

## Artefato final (Jump Box WS2019 + chave em conta AD)

Salve como `docs/37_JUMPBOX_WS2019_AD_KEYAUTH.md`.

```md
# Jump Box Windows Server 2019 (AD account + SSH key) — padrão do projeto

Objetivo: permitir que o Debian (NAS) execute o script `ad_setup_fileserver.ps1` remotamente na Jump Box via SSH usando **autenticação por chave** em uma **conta do AD**, sem habilitar SSH/WinRM nos DCs.

## Premissas e referências
- OpenSSH no Windows suporta autenticação por chave para **contas locais e contas Active Directory (domínio)**. [web:386]
- OpenSSH no Windows **não suporta** `AuthorizedKeysCommand`/`AuthorizedKeysCommandUser`, então não dá para “puxar chaves dinamicamente do AD” via esses mecanismos. [web:386]
- Para contas administrativas, o Windows OpenSSH usa `administrators_authorized_keys` em vez do `authorized_keys` do perfil do usuário. [web:386]
- A Jump Box deve ter RSAT/DNS Tools para fornecer o módulo PowerShell `DnsServer` (ou então ser o próprio servidor DNS). [web:374][web:375]
- A execução remota via SSH pode rodar PowerShell no alvo (PowerShell Remoting over SSH é suportado e documentado). [web:363]
- Nosso `ad_setup_fileserver.ps1` é DRY-RUN por padrão e só muda AD/DNS/SPN com `-Apply`, usando `ShouldProcess`/`-WhatIf` onde aplicável (ex.: cmdlets DNS). [web:348][web:338]

## 1) Conta do AD (recomendada)
Criar uma conta de serviço (usuário do AD), por exemplo:
- `EMPRESA\svc-nas-automation`

Conceder permissões **delegadas** para:
- Criar/alterar o A record `fileserver.empresa.com.br` na zona `empresa.com.br`.
- Registrar SPNs CIFS **apenas** no objeto `EMPRESA\EMPRESA-FILESERVER$` (conta dedicada do serviço SMB).

## 2) Instalar e habilitar OpenSSH Server na Jump Box
Seguir o guia oficial de “install/first use” do OpenSSH Server no Windows. [web:362]

## 3) Autenticação por chave (conta AD)

### 3.1 Caso A (preferido): conta do AD **NÃO** é admin local
Use o arquivo do próprio perfil:
- `%USERPROFILE%\.ssh\authorized_keys`

Passos (rodar como o próprio usuário do AD na Jump Box, ou como admin criando diretórios/ACLs corretamente):
1) Criar diretório e arquivo:
- `mkdir %USERPROFILE%\.ssh`
- criar `%USERPROFILE%\.ssh\authorized_keys` e colar a chave pública do NAS (Debian)

2) Garantir permissões restritas (somente o usuário e SYSTEM/Administrators), pois permissões incorretas são causa comum de “publickey denied” em OpenSSH no Windows. (Padronize via GPO/ACL conforme sua política.)

### 3.2 Caso B: conta do AD É admin local (evite, mas se precisar)
Para contas administrativas, a Microsoft orienta usar:
- `%ProgramData%\ssh\administrators_authorized_keys` [web:386]

Exemplo (PowerShell admin), conforme a própria doc, incluindo `icacls`:
- Adicionar chave pública:
  `Add-Content -Force -Path $env:ProgramData\ssh\administrators_authorized_keys -Value '<PUBLIC_KEY>'` [web:386]
- Fixar ACLs (somente Administrators e SYSTEM):
  `icacls.exe "$env:ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"` [web:386]

## 4) Restringir superfície de ataque (recomendado)
- Restringir quem pode logar via SSH (AllowUsers / AllowGroups) no `sshd_config`.
- Restringir origem (firewall) para aceitar SSH apenas do IP do NAS (ou da rede de provisão).
- Usar host key pinning no Debian (StrictHostKeyChecking=yes + known_hosts dedicado).

## 5) Execução a partir do Debian (NAS)
O NAS deve:
- Enviar o `ad_setup_fileserver.ps1` via SCP para `C:\Windows\Temp\`.
- Executar `pwsh -File` remotamente via SSH.
- Baixar o JSON report e gravar SHA256 local para auditoria.

(Usar `artifacts/scripts/ad_precheck_fileserver.sh` versão premium do projeto.)

## 6) “Gate” de prontidão (precisa dar OK)
- `fileserver.empresa.com.br` resolve para o VIP.
- SPNs existem e não há duplicidade:
  - `setspn -Q cifs/fileserver`
  - `setspn -Q cifs/fileserver.empresa.com.br`
  - `setspn -X` [web:287]
- Jump Box consegue executar cmdlets `DnsServer` e o `setspn` com a conta `svc-nas-automation`. [web:375][web:287]
```

45%
<span style="display:none">[^23_1][^23_10][^23_11][^23_12][^23_13][^23_14][^23_15][^23_2][^23_3][^23_4][^23_5][^23_6][^23_7][^23_8][^23_9]</span>

<div align="center">⁂</div>

[^23_1]: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement

[^23_2]: https://learn.microsoft.com/pt-br/windows-server/administration/openssh/openssh_keymanagement

[^23_3]: https://www.reddit.com/r/sysadmin/comments/ls1n0b/key_based_authentication_on_windows_server_2019/

[^23_4]: https://github.com/PowerShell/Win32-OpenSSH/wiki/Setup-public-key-based-authentication-for-windows/f70d1108fab9bdc087d4ca6c2da3c499c44e354f

[^23_5]: https://woshub.com/using-ssh-key-based-authentication-on-windows/

[^23_6]: http://behymertech.com/posts/windows-server-2019-ssh-key-auth/

[^23_7]: https://www.techtarget.com/searchwindowsserver/tutorial/PowerShell-7-remoting-expands-management-horizons

[^23_8]: https://www.phillipsj.net/posts/ssh-key-based-auth-for-windows/

[^23_9]: https://askai.glarity.app/search/How-can-I-resolve-permission-issues-with-the-authorized-keys-file-on-a-Windows-SSH-server

[^23_10]: https://www.sentinel.com/resources/blog/sentinel-blog/2023/12/13/powershell-remoting-over-ssh

[^23_11]: https://github.com/PowerShell/Win32-OpenSSH/issues/1316

[^23_12]: https://learn.microsoft.com/en-gb/windows-server/administration/openssh/openssh_keymanagement

[^23_13]: https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/ssh-remoting-in-powershell?view=powershell-7.5

[^23_14]: https://github.com/PowerShell/Win32-OpenSSH/issues/1942

[^23_15]: https://www.youtube.com/watch?v=eUt9O10Vn84


---

# Para garantir o sucesso absoluto desse projeto, eu pretendo trabalhar agora nas habilidades do meu agente local, preciso realizar uma curadoria de ferramentas para incorporar ao fluxo de desenvolvimento desse projeto.

Atualmente, venho utilizando para interagir com o agente LLM interfaces como: Opencode, Gemini-cli, Antigravity, VsCode (com as extensões: Kilo Code, Roo e Cline) preciso criar uma estratégia matadora que garanta a qualidade do projeto.
Pesquise quais ferramentas eu devo utilizar no projeto que envolva: automação para formater, lint, commit semântico, gestão de contexto, gestão de tarefas, skills, personas de agente, servidores MCP, ci/cd. Tudo voltado para boas práticas para programação BASH, remasterização do Debian com live-build, SAMBA, Active Directory, Powershell, otimização de Linux com ZFS+SAMBA+Domínio Windows.
Preciso garantir qualidade desse levantamento. Portanto, caso você disponha de capacidades avançadas de gestão de contexto, otimização, compactação e mais, podemos continuar com esse novo foco, caso contrário, preciso aproveitar que está com uma margem segura de contexto, para criar um ótimo prompt focado em levar todo o contexto da nossa discussão, para o agente que será utilizado numa nova sessão, sem todo o entendimento que você tem do projeto, para que seja capaz de compreender o cenário crítico do projeto, bem como, conseguir, de maneira apurada e precisa, turbinar o workflow do meu projeto, se for pertinente preciso também saber qual IDE ou ferramenta CLI, devo usar para trabalhar com agentes LLM, que ofereça os melhores recursos para transformar meus ambiente de desenvolvimento assistido por IA em algo poderoso, mesmo fazendo uso de recursos gratuitos, de código aberto, incluindo o agente LLM local.

A estratégia “matadora” para seu projeto é padronizar tudo em três camadas: **qualidade local** (format/lint/test antes do commit), **qualidade no CI** (reproduzível, sem depender do seu PC) e **qualidade operacional** (smoke tests AD/Samba/ZFS antes de promover uma ISO/release).[^24_1][^24_2][^24_3]

## Núcleo obrigatório (Bash + infra)

Para Bash, eu recomendo você tratar como “baseline” **shfmt + shellcheck + testes** com um framework de shell.[^24_4][^24_2][^24_1]
Use `pre-commit` para orquestrar hooks e garantir que `shellcheck` e `shfmt` rodem antes de cada commit (há hooks prontos para isso).[^24_2][^24_1]
Para testes automatizados de scripts (instalador, wrappers, idempotência), use Bats-core ou ShellSpec: Bats é um framework de testes para Bash, e ShellSpec é um BDD framework para shells POSIX com recursos avançados.[^24_5][^24_4]

## PowerShell/AD (qualidade e lint)

Para PowerShell, adote **PSScriptAnalyzer** como padrão: ele é um “static code checker” com regras para qualidade e também pode formatar código (Invoke-Formatter).[^24_6][^24_7]
No CI, faça o stage “lint” rodar `Invoke-ScriptAnalyzer -EnableExit -Recurse -Path .` para falhar pipeline se houver violações (isso está alinhado ao uso típico do PSScriptAnalyzer).[^24_8][^24_9]

## Commits semânticos e releases automáticos

Para padronização de commits, use **Conventional Commits** com “assistente” + “verificador”: Commitizen guia o dev a produzir mensagens consistentes e pode automatizar versionamento/changelog, e commitlint valida mensagens no pipeline/gancho.[^24_10][^24_11]
Se você quiser release automatizado, `semantic-release` + Conventional Commits é um fluxo comum (ex.: `fix` incrementa patch, `feat` incrementa minor, e `BREAKING CHANGE` incrementa major).[^24_10]

## Secret scanning (projeto corporativo)

Como você vai ter scripts e runbooks que encostam em AD/DNS/SPN, trate “vazamento de segredo” como classe A e coloque um scanner no `pre-commit` e no CI.[^24_12]
Um padrão muito usado é rodar Gitleaks via hook e também no pipeline para garantir que nada passe.[^24_12]

## CI/CD (o que validar neste projeto)

No CI, separe em pipelines “rápidos” e “pesados”.
Os rápidos rodam sempre: shellcheck/shfmt, PSScriptAnalyzer, validação de sintaxe Samba com `testparm`, e validação de YAML/JSON; os pesados rodam em merge/release: build da ISO live-build em runner controlado e execução de smoke tests em VM.[^24_3][^24_6]

Sugestão prática para Bash no GitHub Actions: use uma action que combine shellcheck+shfmt+checkbashisms (tem action pronta que faz essa análise).[^24_3]

## Gestão de contexto (para não estourar janela)

A melhor forma de “economizar contexto” é transformar decisões em **artefatos versionados** (docs/runbooks/templates) e fazer seu agente sempre “ler antes de agir”.[^24_13]
O Continue é uma extensão open-source para VS Code/JetBrains que suporta criar e compartilhar “assistentes” com regras, prompts e docs, o que casa exatamente com seu modelo de Prompt Pack e artefatos no repo.[^24_13]

## IDE/CLI para agentes LLM (open source/gratuito)

Para IDE, o melhor custo/benefício open-source hoje é consolidar em **VS Code + Continue** quando você quer “regras + prompts + contexto de repo” e usar seus agentes (Cline/Roo/Kilo) para tarefas mais autônomas.[^24_13]
Para CLI orientada a mudanças controladas em código, mantenha um fluxo “patch-based” (estilo diff) e exija que o agente gere commits pequenos e verificáveis; isso reduz regressões e facilita auditoria.

## Servidores MCP (o que faz sentido aqui)

Como você já está montando um ecossistema de agentes, MCP vale quando você quer que o agente use ferramentas com “contratos” (ex.: git, filesystem, docker, ssh, HTTP) em vez de inventar passos.
Para este projeto, os MCP servers mais úteis são os que dão acesso controlado a: repositório Git, filesystem do workspace, docker (para live-build), ssh (para jump box), e execução de comandos em ambientes isolados.

## Uma stack “premium” recomendada (curta e implementável)

| Área | Ferramentas recomendadas |
| :-- | :-- |
| Format/lint Bash | `shfmt`, `shellcheck`, `pre-commit` hooks [^24_1][^24_2] |
| Testes Bash | Bats-core (rápido) ou ShellSpec (mais recursos) [^24_4][^24_5] |
| Lint PowerShell | PSScriptAnalyzer (Invoke-ScriptAnalyzer/Invoke-Formatter) [^24_6][^24_7] |
| Commits semânticos | Commitizen + commitlint + Conventional Commits [^24_11][^24_10] |
| Secret scanning | Gitleaks no pre-commit + CI [^24_12] |
| CI para shell | action de checagem shell (shellcheck/shfmt/checkbashisms) [^24_3] |
| Gestão de contexto no IDE | Continue (assistentes com regras/prompts/docs) [^24_13] |

Se você quiser, eu monto um “Prompt Pack” já pronto para seu agente local implementar o workflow (com arquivos `.pre-commit-config.yaml`, config do PSScriptAnalyzer, templates de commit, pipeline CI, e um `Makefile`/`justfile` que padroniza os comandos) — e integro isso ao seu repositório live-build para que cada build da ISO seja rastreável e repetível.
<span style="display:none">[^24_14][^24_15][^24_16][^24_17][^24_18][^24_19][^24_20][^24_21][^24_22][^24_23][^24_24][^24_25][^24_26][^24_27][^24_28][^24_29][^24_30]</span>

<div align="center">⁂</div>

[^24_1]: https://github.com/fauust/pre-commit-shell

[^24_2]: https://github.com/jumanjihouse/pre-commit-hooks

[^24_3]: https://github.com/luizm/action-sh-checker

[^24_4]: https://github.com/bats-core/bats-core

[^24_5]: https://shellspec.info

[^24_6]: https://github.com/PowerShell/PSScriptAnalyzer

[^24_7]: https://learn.microsoft.com/ja-jp/powershell/module/psscriptanalyzer/?view=ps-modules

[^24_8]: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules

[^24_9]: https://www.benjaminrancourt.ca/lint-powershell-scripts-with-psscriptanalyzer/

[^24_10]: https://deployn.de/en/blog/automatische-release-generierung-mit-semantic-release-und-commitizen/

[^24_11]: https://commitizen-tools.github.io/commitizen/

[^24_12]: https://dev.to/sirlawdin/secret-scanning-in-ci-pipelines-using-gitleaks-and-pre-commit-hook-1e3f

[^24_13]: https://github.com/continuedev/continue/tree/main

[^24_14]: https://bats-core.readthedocs.io

[^24_15]: https://www.hackerone.com/blog/testing-bash-scripts-bats-practical-guide

[^24_16]: https://shellspec.info/comparison.html

[^24_17]: https://shellspec.info/why.html

[^24_18]: https://github.com/pecigonzalo/pre-commit-shfmt

[^24_19]: https://www.youtube.com/watch?v=u70zctCPaLc

[^24_20]: https://github.com/shellspec/shellspec/

[^24_21]: https://www.youtube.com/watch?v=708R-BYmjEk

[^24_22]: https://www.youtube.com/watch?v=EHUE3i8izew

[^24_23]: https://megalinter.io/v4.47.0/descriptors/powershell_powershell/

[^24_24]: https://www.virtualizationhowto.com/2024/03/psscriptanalyzer-the-ultimate-powershell-script-analyzer-and-linter/

[^24_25]: https://webinstall.dev/psscriptanalyzer/

[^24_26]: https://mhx.be/blog/conventional-commits

[^24_27]: https://www.stepsecurity.io/blog/orchestrate-secret-scanning-and-linting-pre-commit-hooks-with-stepsecurity

[^24_28]: https://www.reddit.com/r/devsecops/comments/1ofppbf/how_are_you_handling_localprecommit_secret/

[^24_29]: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules

[^24_30]: https://dev.to/vitordevsp/padronizacao-de-commit-com-commitlint-husky-e-commitizen-3g1n


---

# sim

A seguir vai um **Prompt Pack/workflow** (com arquivos prontos para colar no seu repositório) para elevar seu projeto a um nível “CI-first”: formatação, lint, testes, commits semânticos, gestão de contexto para agentes, e pipelines para live-build + Bash + PowerShell (AD).[^25_1][^25_2][^25_3]

## Ferramentas (curadoria “matadora”)

### Qualidade local (antes do commit)

- **pre-commit** como orquestrador de hooks (format/lint/secret scan).[^25_4]
- Bash: **ShellCheck** + **shfmt** (e opcionalmente `checkbashisms`).[^25_5][^25_1]
- PowerShell: **PSScriptAnalyzer** com settings versionado no repo e executado por hook local.[^25_6][^25_3]
- Segredos: **Gitleaks** no pre-commit e no CI (evita vazar credenciais/keys).[^25_7]
- Testes Bash: **bats-core** (rápido) ou **ShellSpec** (mais expressivo).[^25_8][^25_9]


### Commits semânticos / releases

- **Commitizen** para padronizar Conventional Commits e automatizar versionamento/changelog quando você quiser.[^25_10][^25_11]


### Contexto/skills/personas (para agentes)

- **Continue** (open-source) no VS Code, com regras no `.continue/rules` carregadas automaticamente e em ordem lexicográfica (você controla com prefixos `01-...`).[^25_2][^25_12]


### CI/CD (reprodutível)

- GitHub Actions:
    - Lint shell com **luizm/action-sh-checker** (shellcheck + shfmt + checkbashisms).[^25_1]
    - Lint PowerShell com PSScriptAnalyzer (via `Invoke-ScriptAnalyzer` com `-Settings`).[^25_3][^25_6]

***

## Estrutura sugerida do repo

Crie estes diretórios/arquivos (além do que você já tem com live-build):

```
.
├─ artifacts/
│  ├─ scripts/
│  ├─ templates/
│  └─ docs/
├─ config/                           # live-build
├─ scripts/                          # seus scripts bash (instalador etc.)
├─ powershell/                       # scripts ps1/psd1
├─ docs/
├─ tests/
├─ .continue/
│  └─ rules/
├─ .github/workflows/
├─ .pre-commit-config.yaml
├─ .editorconfig
├─ Makefile
└─ PSScriptAnalyzerSettings.psd1
```


***

## Arquivos prontos (copiar/colar)

### 1) `.editorconfig` (padroniza whitespace/encoding)

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.{sh,bash}]
indent_style = space
indent_size = 2

[*.ps1]
indent_style = space
indent_size = 2

[*.{yml,yaml}]
indent_style = space
indent_size = 2

[Makefile]
indent_style = tab
```


### 2) `.shellcheckrc` (baseline conservador)

```conf
# Ajuste conforme seu estilo; prefira corrigir warnings a silenciar.
# Exemplo: exclude um warning específico quando fizer sentido:
# disable=SC2034
```


### 3) `PSScriptAnalyzerSettings.psd1` (settings versionado)

A Microsoft documenta o uso de `Invoke-ScriptAnalyzer -Settings <arquivo>` com settings em hashtable.[^25_6][^25_3]

```powershell
@{
  Severity = @('Error','Warning')

  # Base (ajuste com o tempo)
  ExcludeRules = @(
    'PSAvoidUsingWriteHost'
  )
}
```


### 4) `.pre-commit-config.yaml` (format/lint/secret scan)

Use hooks existentes + hooks locais. (A ideia é: tudo que roda no CI também roda local.)[^25_4][^25_7]

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-merge-conflict
      - id: check-yaml
      - id: check-json

  # shfmt (formatação)
  - repo: https://github.com/pecigonzalo/pre-commit-shfmt
    rev: v2.2.0
    hooks:
      - id: shfmt
        args: ["-w", "-s", "-i", "2"]

  # ShellCheck (lint bash/sh)
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0.1
    hooks:
      - id: shellcheck
        args: ["--severity=warning"]

  # Gitleaks (segredos) - rode também no CI
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks

  # PowerShell lint (hook local via pwsh)
  - repo: local
    hooks:
      - id: psscriptanalyzer
        name: PSScriptAnalyzer
        language: system
        entry: pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path ./powershell -Recurse -Settings ./PSScriptAnalyzerSettings.psd1"
        pass_filenames: false
```


### 5) `Makefile` (comandos únicos e estáveis)

```makefile
.PHONY: lint test build-iso

lint:
	pre-commit run --all-files

test:
	# escolha bats ou shellspec (abaixo deixo bats como default)
	bats -r tests

build-iso:
	# Ajuste para seu docker debian:trixie-slim + live-build
	./scripts/build_iso.sh
```


### 6) GitHub Actions: `.github/workflows/lint.yml`

O `sh-checker` executa shellcheck + shfmt + checkbashisms em scripts shell.[^25_1]
Para PowerShell, use `Invoke-ScriptAnalyzer -Settings` como descrito na doc.[^25_3][^25_6]

```yaml
name: lint

on:
  pull_request:
  push:
    branches: [ "main" ]

jobs:
  shell:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Shell lint (shellcheck/shfmt/checkbashisms)
        uses: luizm/action-sh-checker@master
        env:
          SHELLCHECK_OPTS: "--severity=warning"
          SHFMT_OPTS: "-i 2 -s"
        with:
          sh_checker_checkbashisms_enable: true
```

E um job separado para PowerShell:

```yaml
  powershell:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install PSScriptAnalyzer
        shell: pwsh
        run: |
          Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
          Install-Module PSScriptAnalyzer -Force
      - name: Run PSScriptAnalyzer (repo settings)
        shell: pwsh
        run: |
          Invoke-ScriptAnalyzer -Path ./powershell -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```


### 7) Continue (contexto/personas/skills): `.continue/rules/`

O Continue suporta regras locais em `.continue/rules` e carrega em ordem lexicográfica; prefixe com números para controlar prioridade.[^25_12][^25_2]

Crie `/.continue/rules/01-project-source-of-truth.yaml`:

```yaml
name: Project source of truth
version: 0.0.1
schema: v1
rules:
  - Sempre leia docs/00_SOURCE_OF_TRUTH.md antes de propor mudanças
  - Nunca invente passos; gere arquivos/patches idempotentes
  - Prefira mudanças pequenas com testes e logs
```

Crie `/.continue/rules/02-bash-standards.yaml`:

```yaml
name: Bash standards
version: 0.0.1
schema: v1
rules:
  - Scripts bash devem usar set -euo pipefail
  - Sempre rodar shellcheck e shfmt; não silenciar warnings sem justificativa
  - Logs devem ir para /var/log/my-nas/ e conter timestamps
```

Crie `/.continue/rules/03-ad-samba-standards.yaml`:

```yaml
name: AD + Samba standards
version: 0.0.1
schema: v1
rules:
  - SMB-only default: vfs objects = acl_xattr streams_xattr; ignore system acls = yes
  - Alias/VIP: fileserver.empresa.com.br via A record; SPNs em EMPRESA-FILESERVER$
  - Sempre produzir runbooks e scripts de validação
```


***

## Gestão de tarefas (simples e eficaz)

Para manter a disciplina do projeto sem ferramenta pesada:

- Use GitHub Issues + labels (ex.: `area:bash`, `area:ad`, `area:samba`, `area:live-build`, `type:bug`, `type:enhancement`, `prio:p0`).
- Crie um `docs/ROADMAP.md` com 3 fases (MVP ISO, Hardening/CI, HA/failover) e “Definition of Done” por fase.

***

## “Prompt de migração” (caso você abra nova sessão)

Se você trocar de sessão/agente, mantenha um arquivo `docs/00_SOURCE_OF_TRUTH.md` e mande o agente ler primeiro (isso economiza muito contexto).
Se quiser, eu preparo esse arquivo para você com um resumo do projeto + links internos para todos os artefatos/runbooks.

Quer que eu gere agora um `docs/00_SOURCE_OF_TRUTH.md` completo (com o estado atual do seu projeto, decisões fixas, templates SMB-only, jump box, SPN/DNS, replicação e HA), pronto para o agente usar como “memória permanente”?
<span style="display:none">[^25_13][^25_14][^25_15][^25_16][^25_17][^25_18][^25_19][^25_20][^25_21]</span>

<div align="center">⁂</div>

[^25_1]: https://github.com/luizm/action-sh-checker

[^25_2]: https://docs.continue.dev/customize/deep-dives/rules

[^25_3]: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules

[^25_4]: https://github.com/jumanjihouse/pre-commit-hooks

[^25_5]: https://github.com/koalaman/shellcheck

[^25_6]: https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-scriptanalyzer?view=ps-modules

[^25_7]: https://dev.to/sirlawdin/secret-scanning-in-ci-pipelines-using-gitleaks-and-pre-commit-hook-1e3f

[^25_8]: https://github.com/bats-core/bats-core

[^25_9]: https://shellspec.info

[^25_10]: https://commitizen-tools.github.io/commitizen/

[^25_11]: https://deployn.de/en/blog/automatische-release-generierung-mit-semantic-release-und-commitizen/

[^25_12]: https://github.com/continuedev/continue/blob/main/docs/docs/customize/deep-dives/rules.md

[^25_13]: https://www.ravenswoodtechnology.com/improving-your-powershell-scripts-with-psscriptanalyzer/

[^25_14]: https://github.com/PSModule/Invoke-ScriptAnalyzer/

[^25_15]: https://learn.microsoft.com/pt-br/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules

[^25_16]: https://blog.ironmansoftware.com/psscriptanalyzer-custom-rules/

[^25_17]: https://packages.ecosyste.ms/registries/github actions/packages/luizm/action-sh-checker

[^25_18]: https://github.com/continuedev/continue/issues/6076

[^25_19]: https://github.com/PowerShell/PSScriptAnalyzer/blob/master/docs/Cmdlets/Invoke-ScriptAnalyzer.md

[^25_20]: https://github.com/marketplace/actions/sh-checker

[^25_21]: https://www.reddit.com/r/PowerShell/comments/lt5w8q/where_do_i_place_the_psscriptanalyzersettingspsd1/


---

# sim

Abaixo está um `docs/00_SOURCE_OF_TRUTH.md` **completo** (pode copiar/colar no seu repo) que “fixa” o projeto, além de um pequeno conjunto de arquivos de workflow para seu agente local usar como *memória permanente* e reduzir pesquisas. Ele referencia decisões e artefatos que já definimos (SMB-only, ZFS, alias/SPN, jump box, scripts). Também incluo notas de como integrar isso ao Continue (regras) e ao CI.[^26_1][^26_2]

***

## `docs/00_SOURCE_OF_TRUTH.md` (copie/cole)

```md
# Fonte da Verdade (SoT) — Projeto NAS Debian (ZFS + Samba/AD + ZFSBootMenu)

Este documento é a referência principal do projeto. Qualquer mudança de arquitetura deve ser registrada aqui antes de alterar scripts/ISO.

## 1) Objetivo do produto

Entregar uma ISO Debian Trixie remasterizada via live-build que instala um NAS corporativo com:
- ZFS + ZFSBootMenu (boot environments e rollback do sistema)
- Samba (SMB-only como padrão) integrado ao Active Directory
- Máxima compatibilidade com Windows (ACLs gerenciáveis via aba Security)
- Alta performance e estabilidade operacional
- Replicação do físico para VM standby e failover automático ativo+passivo

NFS existe apenas como exceção e NUNCA deve compartilhar o mesmo dataset com SMB no modo padrão.

## 2) Hardware alvo inicial (baseline)

Servidor físico:
- Dell PowerEdge 2950
- 32 GiB RAM
- 2× CPU octa-core
- Controladora RAID Dell PERC (sem JBOD)
- 6× SAS 600 GiB 15k
- NICs: 2×1Gb onboard + 2×10Gb (placa dual)

## 3) Storage/RAID: decisão fixa

Como não há JBOD, a redundância real fica na controladora.

Decisão:
- Criar 1 Virtual Disk usando todos os 6 discos em RAID10.
- Habilitar write-back (somente com proteção/estado saudável), pois write-back melhora latência percebida e throughput de escrita; write-through é mais conservador e tende a ser mais lento. (Documentação Dell: write-through vs write-back.) [web:193]
- NÃO dividir discos em VDs distintos para SO/dados no baseline.

## 4) ZFS: layout e regras

Pool:
- Nome padrão: tank (pode ser configurável)

Datasets (exemplo):
- tank/ROOT/debian            -> Boot Environment (sistema)
- tank/SYS/samba-state        -> estado Samba/AD (segredos/keytab/tdb etc.) separado do ROOT
- tank/SHARES/<share_name>    -> 1 dataset por share SMB

Regras:
- Cada Boot Environment deve ser exatamente 1 filesystem/dataset (coerência de snapshot/rollback). [web:159]
- Dados de shares nunca devem ficar dentro do dataset de ROOT (para rollback do sistema não afetar dados).
- Propriedades recomendadas para SMB-only em cada dataset de share:
  - acltype=posixacl [page:0]
  - xattr=sa (fortemente recomendado com posixacl para performance de xattr/ACL) [page:0]
  - atime=off
- NÃO habilitar dedup no baseline; dedup tem custo alto e pode degradar severamente. [page:0]
- NÃO alterar recordsize sem benchmark; o manual alerta que mudar recordsize em FS de uso geral é desencorajado e pode piorar performance. [page:0]

ZFSBootMenu:
- Configurar para preferir o pool explicitamente com `zbm.prefer=<pool>!`. [web:60]
- Syslinux só existe como “ponte” para BIOS legacy quando necessário.

## 5) Samba: SMB-only (padrão)

Perfil padrão do produto: SMB-only com Windows-first ACL.

VFS modules:
- `vfs objects = acl_xattr streams_xattr`
- `acl_xattr:ignore system acls = yes` (SMB-only)
Justificativa:
- `acl_xattr` armazena ACL NT em xattr `security.NTACL` e recomenda ignore system acls=yes quando dados são acessados somente via Samba. [web:190]
- `streams_xattr` implementa NTFS Alternate Data Streams via xattrs (compatibilidade Windows). [web:263]

Protocolos:
- Desabilitar SMB1; usar SMB2/SMB3.
(Referência Microsoft sobre detecção/controle SMBv1/2/3.) [web:167]

SMB Multichannel:
- Habilitar multichannel e validar no Windows.
(Referência Microsoft SMB Multichannel.) [web:164]

Templates:
- artifacts/templates/smb/smb.conf.smb-only.template
- (Exceção) SMB+NFS: ignore system acls = no (somente se for inevitável) [web:190]
- (Exceção) NFS-only: dataset separado

Validação Linux:
- Usar /usr/local/sbin/validate_ad_smb.sh (script do projeto)
- `smbcacls` pode ler/alterar ACLs NT em shares SMB e tem opções como --maximum-access. [web:275]

## 6) AD + Kerberos + Alias/VIP (fixo)

Serviço para clientes:
- alias/VIP: fileserver
- FQDN: fileserver.empresa.com.br
- DNS: registro A fileserver.empresa.com.br -> VIP

Nós:
- EMPRESA-BM-NAS (bare metal)
- EMPRESA-VM-NAS (standby VM)

Identidade dedicada do serviço (AD computer account):
- EMPRESA\EMPRESA-FILESERVER$

SPNs:
- cifs/fileserver
- cifs/fileserver.empresa.com.br
Gerenciar via setspn; usar -S e checar duplicidades com -X. [web:287]

Runbooks:
- docs/30_AD_JOIN_AND_ALIAS.md
- docs/31_RUNBOOK_FILESERVICE_FILESERVERSMB_AD.md
- docs/32_AD_OBJECTS_CHECKLIST.md

## 7) Jump Box (AD-side automation)

Jump Box:
- Windows Server 2019
- Acesso preferido: SSH por chave (conta AD)

Conta AD para automação:
- EMPRESA\svc-nas-automation (preferido; não-admin local)

Automação AD-side:
- artifacts/scripts/ad_setup_fileserver.ps1 (dry-run default; -Apply para mudanças; gera JSON)
- Execução a partir do Debian:
  - artifacts/scripts/ad_precheck_fileserver.sh (wrapper premium: hostkey pinning, upload/run/download, SHA256, rotação)

Docs:
- docs/34_JUMPBOX_SETUP.md
- docs/35_JUMPBOX_SSH_KEYS.md
- docs/37_JUMPBOX_WS2019_AD_KEYAUTH.md

## 8) Replicação + Failover (ativo/passivo)

Objetivo:
- Replicar tank/SHARES (recursivo) + tank/SYS/samba-state do físico para a VM standby
- Failover automático com VIP e start/stop ordenado dos serviços

Ferramenta:
- Syncoid/Sanoid para snapshots e replicação (quando adotado). [web:236]

Cluster:
- Pacemaker/Corosync, ativo+passivo, com fencing obrigatório
- Ordem: VIP -> import/mount ZFS -> Samba/Winbind

## 9) Qualidade de código e CI/CD (fixo)

Qualidade local:
- pre-commit com shfmt + shellcheck + gitleaks
- PSScriptAnalyzer para PowerShell (settings em PSScriptAnalyzerSettings.psd1) [web:437]
- testes bash (bats ou shellspec)

CI:
- GitHub Actions com shell lint (sh-checker) [web:421]
- PSScriptAnalyzer job
- build ISO (job pesado, apenas em merge/release)

IA/Agentes:
- VS Code + Continue (regras locais em .continue/rules) [web:442]

## 10) Proibição e limites

- Nunca armazenar credenciais AD na ISO.
- Nunca depender de CNAME para o alias padrão (usar A record).
- Nunca exportar NFS sobre o mesmo dataset usado por SMB no modo padrão.
```


***

## Pequeno ajuste importante (Continue rules)

O Continue atualmente recomenda regras em `.md` com frontmatter YAML e também aceita YAML; a doc explica onde ficam e a ordem de carregamento.[^26_1]
Se quiser padronizar, crie suas regras como Markdown em `.continue/rules/*.md` (mais fácil de editar).

***

## Próximo passo (se você quiser que eu continue)

Eu consigo agora gerar um “kit mínimo” de **tarefas/labels** (`docs/ROADMAP.md` + `.github/labels.yml`) e um `justfile`/`Makefile` para padronizar o uso do agente (build ISO, lint, test, pacote).
<span style="display:none">[^26_10][^26_11][^26_12][^26_13][^26_14][^26_15][^26_3][^26_4][^26_5][^26_6][^26_7][^26_8][^26_9]</span>

<div align="center">⁂</div>

[^26_1]: https://docs.continue.dev/customize/deep-dives/rules

[^26_2]: https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-scriptanalyzer?view=ps-modules

[^26_3]: https://docs.continue.dev/reference

[^26_4]: https://github.com/continuedev/continue/issues/6905

[^26_5]: https://docs.openwebui.com/tutorials/integrations/continue-dev/

[^26_6]: https://github.com/continuedev/continue/blob/main/docs/docs/customize/deep-dives/rules.md

[^26_7]: https://blog.ironmansoftware.com/psscriptanalyzer-custom-rules/

[^26_8]: https://dev.to/sirlawdin/secret-scanning-in-ci-pipelines-using-gitleaks-and-pre-commit-hook-1e3f

[^26_9]: https://docs.continue.dev/guides/configuring-models-rules-tools

[^26_10]: https://www.reddit.com/r/PowerShell/comments/6tmprp/calling_ps_script_analyzer_with_pester/

[^26_11]: https://m3ssap0.github.io/2023/09/29/pre-commit-gitleaks.html

[^26_12]: https://continue-docs.mintlify.app/guides/configuring-models-rules-tools

[^26_13]: https://github.com/gitleaks/gitleaks/discussions/1104

[^26_14]: https://github.com/continuedev/continue/blob/main/docs/docs/yaml-migration.md

[^26_15]: https://www.powershellgallery.com/packages/PSNow/0.0.1.39/Content/Build\PSScriptAnalyzerSettings.psd1


---

# sim

Abaixo está um kit pronto (artefatos para salvar no repo) com **ROADMAP**, **labels como código**, **auto-label em PR**, e um **justfile** para padronizar comandos (lint/test/build/release) — tudo alinhado a boas práticas e às capacidades do Continue para regras/contexto.[^27_1][^27_2][^27_3]

## `docs/ROADMAP.md`

```md
# Roadmap — NAS Debian (ZFS + Samba/AD + HA)

## Fase 0 — Guardrails (obrigatório antes de avançar)
Critérios de aceite:
- pre-commit habilitado (shfmt, shellcheck, gitleaks, PSScriptAnalyzer)
- CI “lint” passando em PR
- docs/00_SOURCE_OF_TRUTH.md atualizado como gate

Entregas:
- .pre-commit-config.yaml
- .github/workflows/lint.yml
- PSScriptAnalyzerSettings.psd1
- justfile

## Fase 1 — ISO MVP (instala e sobe SMB-only)
Critérios de aceite:
- ISO live-build gera e instala em VM
- ZFS root + ZFSBootMenu funcionando
- SMB-only com AD join e ACL editável via Windows (Security tab)
- validate_ad_smb.sh passa no nó ativo (Linux-side)
- documentação de operação mínima

Entregas:
- templates smb.conf (SMB-only)
- first-boot wizard idempotente
- scripts de validação e logs

## Fase 2 — Hardening + Observabilidade
Critérios de aceite:
- Logs padronizados (/var/log/my-nas)
- Métricas básicas (samba/zfs/disk/network)
- Threat model mínimo (segredos, chaves, AD automation)

Entregas:
- hardening docs
- alertas básicos e runbooks

## Fase 3 — HA ativo+passivo + replicação
Critérios de aceite:
- replicação física -> VM (RPO definido)
- failover automático (VIP + ZFS mount + samba) com fencing
- SPNs fixos na identidade EMPRESA-FILESERVER$ (não mover em failover)

Entregas:
- pacemaker/corosync configs
- runbook de failover
- testes de caos (poweroff, link down, etc.)
```


## Labels como código (do jeito que funciona “de verdade”)

Há duas necessidades diferentes:

1) **Criar/atualizar labels do repositório** (labels “existirem”).
2) **Aplicar labels automaticamente em PRs** baseado em paths.

O GitHub `actions/labeler` cobre bem o item (2) e lê `.github/labeler.yml`.[^27_4][^27_1]
Para o item (1), eu recomendo o caminho mais estável: um workflow simples que cria labels via API/`gh`/`github-script` (ou um action de “label management as code”); se preferir manter minimalista, você pode começar só com auto-label e criar labels manualmente 1 vez.

Vou te entregar ambos: **auto-label** + **labels.json** para criação.

***

## `labels/labels.json` (fonte de verdade dos labels)

Crie `labels/labels.json`:

```json
[
  { "name": "area:bash", "color": "1f6feb", "description": "Bash/scripts/installer" },
  { "name": "area:live-build", "color": "1f6feb", "description": "Debian live-build/ISO" },
  { "name": "area:samba", "color": "1f6feb", "description": "Samba/SMB config" },
  { "name": "area:ad", "color": "1f6feb", "description": "Active Directory/Kerberos/SPN/DNS" },
  { "name": "area:powershell", "color": "1f6feb", "description": "PowerShell tooling/scripts" },
  { "name": "area:ha", "color": "1f6feb", "description": "Pacemaker/Corosync/VIP/fencing" },
  { "name": "area:zfs", "color": "1f6feb", "description": "ZFS layout/tuning/replication" },
  { "name": "type:bug", "color": "d73a4a", "description": "Defeito" },
  { "name": "type:enhancement", "color": "a2eeef", "description": "Melhoria" },
  { "name": "type:docs", "color": "0075ca", "description": "Documentação" },
  { "name": "prio:p0", "color": "b60205", "description": "Bloqueador" },
  { "name": "prio:p1", "color": "d93f0b", "description": "Alta prioridade" },
  { "name": "prio:p2", "color": "fbca04", "description": "Média prioridade" }
]
```


***

## `/.github/labeler.yml` (auto-label por paths)

O `actions/labeler` lê `.github/labeler.yml` e aplica labels em PRs conforme padrões.[^27_1]

```yaml
area:live-build:
  - changed-files:
      - any-glob-to-any-file:
          - "config/**"
          - "auto/**"

area:bash:
  - changed-files:
      - any-glob-to-any-file:
          - "scripts/**"
          - "**/*.sh"
          - "**/*.bash"

area:samba:
  - changed-files:
      - any-glob-to-any-file:
          - "artifacts/templates/smb/**"
          - "**/smb.conf*"

area:zfs:
  - changed-files:
      - any-glob-to-any-file:
          - "docs/**zfs**"
          - "artifacts/**zfs**"

area:ad:
  - changed-files:
      - any-glob-to-any-file:
          - "docs/**AD**"
          - "docs/**SPN**"
          - "docs/**DNS**"

area:powershell:
  - changed-files:
      - any-glob-to-any-file:
          - "powershell/**"
          - "**/*.ps1"
          - "**/*.psd1"

area:ha:
  - changed-files:
      - any-glob-to-any-file:
          - "docs/**HA**"
          - "docs/**failover**"
          - "artifacts/**pacemaker**"
          - "artifacts/**corosync**"
```


***

## `/.github/workflows/pr-labeler.yml`

O action explica requisitos de permissões (`pull-requests: write`) e como usar.[^27_1]

```yaml
name: pr-labeler

on:
  pull_request_target:

permissions:
  contents: read
  pull-requests: write

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/labeler@v5
        with:
          configuration-path: .github/labeler.yml
          repo-token: ${{ secrets.GITHUB_TOKEN }}
```


***

## `justfile` (runner de tarefas padronizado)

O `just` é um command runner e o repositório oficial mostra a estrutura de `justfile` e como listar/rodar recipes.[^27_2]

Crie `justfile`:

```make
set shell := ["bash", "-euo", "pipefail", "-c"]

default:
  @just --list

lint:
  pre-commit run --all-files

test:
  bats -r tests

build-iso:
  ./scripts/build_iso.sh

ci-lint:
  just lint

ci-test:
  just test

ad-precheck-dry:
  sudo /usr/local/sbin/ad-precheck-fileserver --host {{HOST}} --user {{USER}} --vip {{VIP}} --dns-server {{DC}} --report-dir /var/log/my-nas/ad-precheck

ad-precheck-apply:
  sudo /usr/local/sbin/ad-precheck-fileserver --host {{HOST}} --user {{USER}} --vip {{VIP}} --dns-server {{DC}} --report-dir /var/log/my-nas/ad-precheck --apply
```


***

## Continue: “regra de ouro” (para governar agentes)

A doc do Continue cobre como criar/gerenciar Rules; mantenha as suas em `.continue/rules/` e faça seu agente sempre começar lendo `docs/00_SOURCE_OF_TRUTH.md`.[^27_3]

Crie `.continue/rules/00-entrypoint.md`:

```md
---
name: Entrypoint obrigatório
version: 0.0.1
---

Antes de qualquer mudança:
1) Ler docs/00_SOURCE_OF_TRUTH.md e citar qual seção está sendo implementada
2) Propor mudanças pequenas (patches) com comandos para validar (lint/test)
3) Nunca alterar arquitetura sem atualizar a SoT
```


***

## Observação importante (PSScriptAnalyzer no CI)

A Microsoft documenta `Invoke-ScriptAnalyzer` e o uso de settings via `-Settings`, então mantenha `PSScriptAnalyzerSettings.psd1` no repo e rode em CI e no pre-commit.[^27_5]

***

Quer que eu também gere um `docs/HANDOFF_PROMPT_NEW_SESSION.md` (um prompt de “transferência de contexto”) para você abrir uma nova sessão com outro agente e ele já cair executando esse kit sem depender da memória desta conversa?
<span style="display:none">[^27_10][^27_11][^27_12][^27_13][^27_14][^27_15][^27_16][^27_17][^27_6][^27_7][^27_8][^27_9]</span>

<div align="center">⁂</div>

[^27_1]: https://github.com/actions/labeler

[^27_2]: https://github.com/casey/just

[^27_3]: https://docs.continue.dev/customize/deep-dives/rules

[^27_4]: https://github.com/marketplace/actions/labeler

[^27_5]: https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-scriptanalyzer?view=ps-modules

[^27_6]: https://github.com/marketplace/actions/auto-labeler

[^27_7]: https://dev.to/programequity/github-actions-labeler-vs-github-script-d04

[^27_8]: https://github.com/marketplace/actions/github-labeler

[^27_9]: https://til.simonwillison.net/github-actions/creating-github-labels

[^27_10]: https://www.youtube.com/watch?v=W3pSSVwx--k

[^27_11]: https://github.com/commitizen-tools/commitizen/discussions/847

[^27_12]: https://github.com/actions/labeler/blob/main/action.yml

[^27_13]: https://commitizen-tools.github.io/commitizen/config/

[^27_14]: https://berkkaraal.com/blog/2024/12/06/just-start-using-it/

[^27_15]: https://commitizen-tools.github.io/commitizen/

[^27_16]: https://github.com/marketplace/actions/label-actions

[^27_17]: https://news.ycombinator.com/item?id=34315779


---

# sim

Salve o arquivo abaixo como `docs/HANDOFF_PROMPT_NEW_SESSION.md` e use-o como o **primeiro** prompt em uma nova sessão (ou com outro agente) para ele “pegar” todo o contexto e já começar a turbinar o workflow do projeto sem depender do histórico.

```md
# HANDOFF PROMPT — Nova sessão (NAS Debian ZFS + Samba/AD + HA)

Você é meu agente LLM local (arquitetura + implementação + CI/CD + qualidade).  
Seu objetivo é elevar a qualidade do projeto (workflow, automação, padronização e validação) e manter a arquitetura/decisões já fixadas como “fonte da verdade”.

## 0) Regras de operação (obrigatórias)
- Antes de qualquer mudança, **leia** `docs/00_SOURCE_OF_TRUTH.md` e trate como contrato (se quiser mudar algo, proponha PR/patch e atualize a SoT primeiro).
- Faça mudanças pequenas e verificáveis, sempre acompanhadas de comandos de validação (lint/test/build).
- Nunca invente passos dependentes de internet durante execução; tudo deve estar documentado e versionado no repo.
- Produza outputs como: patches (diff), arquivos completos, e runbooks.

## 1) Contexto do projeto (resumo)
- Projeto: ISO Debian Trixie remasterizada via live-build dentro de docker `debian:trixie-slim`, com instalador custom em shell (porque Debian não instala ZFS root por padrão).
- Foco: servidor **full SMB** (Samba) integrado ao Active Directory, com ACLs gerenciáveis via Windows (Security tab) e também via Linux quando necessário.
- Hardware baseline: Dell PowerEdge 2950 + controladora PERC (sem JBOD), com RAID10 e write-back habilitado.
- Boot: ZFSBootMenu (Syslinux só “ponte” em BIOS).
- NFS: apenas exceção; nunca misturar SMB+NFS no dataset padrão.

## 2) Decisões fixas (não quebre)
- Alias/VIP para clientes: `fileserver` / `fileserver.empresa.com.br` (DNS A record -> VIP).
- Nós: `EMPRESA-BM-NAS` (bare metal) e `EMPRESA-VM-NAS` (standby VM).
- Identidade dedicada do serviço (AD computer account): `EMPRESA\EMPRESA-FILESERVER$`.
- SPNs CIFS fixos nessa identidade:
  - `cifs/fileserver`
  - `cifs/fileserver.empresa.com.br`
  Gerenciar via `setspn` com `-S`, validar com `-Q/-L` e checar duplicidade com `-X`. [web:287]
- Samba SMB-only padrão:
  - `vfs objects = acl_xattr streams_xattr`
  - `acl_xattr:ignore system acls = yes` (SMB-only)
  - SMB1 desabilitado (SMB2/3 apenas).
  - SMB Multichannel habilitado e validado no Windows. [web:164][web:167]

## 3) Jump Box (automação AD-side)
- Jump Box é Windows Server 2019; eu acesso do Linux.
- Quero autenticação SSH por **chave** em conta do AD (ex.: `EMPRESA\svc-nas-automation`).
- O NAS deve conseguir: upload PS1 -> executar via SSH (pwsh) -> baixar JSON report -> registrar SHA256 -> rotacionar relatórios.
- Docs relevantes:
  - `docs/37_JUMPBOX_WS2019_AD_KEYAUTH.md`
  - `docs/35_JUMPBOX_SSH_KEYS.md` (inclui `administrators_authorized_keys` quando for admin) [web:386]
  - `docs/34_JUMPBOX_SETUP.md`

## 4) Artefatos existentes (você deve respeitar e evoluir)
- Samba template:
  - `artifacts/templates/smb/smb.conf.smb-only.template`
- Validação Linux-side:
  - `artifacts/scripts/validate_ad_smb.sh`
- AD-side setup (dry-run default, -Apply para mudanças, gera JSON):
  - `artifacts/scripts/ad_setup_fileserver.ps1`
- Wrapper Debian-side (premium):
  - `artifacts/scripts/ad_precheck_fileserver.sh`
- Runbooks AD/SPN/DNS:
  - `docs/30_AD_JOIN_AND_ALIAS.md`
  - `docs/31_RUNBOOK_FILESERVICE_FILESERVERSMB_AD.md`
  - `docs/32_AD_OBJECTS_CHECKLIST.md`

## 5) O que eu quero de você AGORA (novo foco: workflow “matador”)
Implemente (com arquivos prontos no repo) um workflow completo cobrindo:
1) Automação local:
   - `.editorconfig`
   - `pre-commit` com shfmt + shellcheck + gitleaks + PSScriptAnalyzer
2) Lint/test:
   - Bash: shellcheck + shfmt + testes (bats-core ou shellspec)
   - PowerShell: PSScriptAnalyzer via `Invoke-ScriptAnalyzer -Settings` (settings versionado). [web:437][web:479]
3) Commits semânticos:
   - Conventional Commits com Commitizen (config versionada) e validação no CI.
4) Gestão de contexto para agentes:
   - Continue no VS Code com regras em `.continue/rules/` (ordem por prefixo numérico), e regra “ler SoT antes de agir”. [web:442]
5) CI/CD:
   - GitHub Actions:
     - lint shell (shellcheck/shfmt/checkbashisms)
     - lint PowerShell (PSScriptAnalyzer)
     - build ISO (job pesado, só em merge/release)
6) Gestão de tarefas:
   - `docs/ROADMAP.md` + labels padrão do repo
   - auto-label de PR por paths via actions/labeler e `.github/labeler.yml`. [web:460][web:467]

## 6) Entregáveis (o que você deve produzir nesta sessão)
- Lista objetiva de arquivos a criar/editar
- Conteúdo completo de cada arquivo (copiar/colar)
- Comandos de instalação/uso (Linux)
- Checklist de validação final (o que rodar local e no CI)

## 7) Restrições
- Não colocar segredos no repo nem na ISO.
- Sempre preferir ferramentas open-source/gratuitas quando possível.
- Não mudar a arquitetura (SoT) sem propor explicitamente e justificar.
```

<span style="display:none">[^28_1][^28_10][^28_11][^28_12][^28_13][^28_14][^28_15][^28_2][^28_3][^28_4][^28_5][^28_6][^28_7][^28_8][^28_9]</span>

<div align="center">⁂</div>

[^28_1]: https://strapi.io/blog/what-is-single-source-of-truth

[^28_2]: https://docs.continue.dev/customize/deep-dives/rules

[^28_3]: https://www.thoughtspot.com/data-trends/best-practices/single-source-of-truth

[^28_4]: https://www.youtube.com/watch?v=Al4xGXJ9HCQ

[^28_5]: https://continue-docs.mintlify.app/customize/deep-dives/rules

[^28_6]: https://dev.to/programequity/github-actions-labeler-vs-github-script-d04

[^28_7]: https://blog.ironmansoftware.com/psscriptanalyzer-custom-rules/

[^28_8]: https://www.datablast.io/post/building-a-ssot-8-best-practices-for-data-integration

[^28_9]: https://github.com/actions/labeler/blob/main/action.yml

[^28_10]: https://learn.microsoft.com/pt-br/powershell/module/psscriptanalyzer/invoke-scriptanalyzer?view=ps-modules

[^28_11]: https://docs.continue.dev/customize/rules

[^28_12]: https://stackoverflow.com/questions/71362028/github-action-for-auto-labeler

[^28_13]: https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-scriptanalyzer?view=ps-modules

[^28_14]: https://www.reddit.com/r/developersIndia/comments/1modq98/too_many_rules_and_instruction_files_to_manage_my/

[^28_15]: https://github.com/marketplace/actions/auto-labeler


---

# Algumas coisas vem ganhando destaque em projetos assistidos por IA, que vem demonstrando uma melhora significativa na qualidade das entregas dos agentes LLM, sendo algumas delas:

- Padronização do arquivos AGENTS.md como fonte de informação padronizada para agentes. (Existe instruções de como criar esse artefato)
- Spec-Driven: Open-Spec, Spec-Kit, Conductor, BMAD-METHOD.
- MCPs para ajudar na gestão de contexto e outras estratégias para otimizar a execução do agente.
- RAG Hibrido.
- CLI para IA, que vem se destacando e vem recebendo muitos plugins que prometem melhorar e automatizar a interação com agentes LLM, criando comandos definidos para agilidade de workflow com agentes, alguns chegam a tornar o agente autônomo. Plugins avançados e customizações como Oh My OpenCode e vários outros produzidas pela comunidade e divulgada no site oficial.
Um workflows que somasse o manterial que você entregou com algum fluxo de trabalho já existente (guiado) como OpenSpec, Conductor, BMAD etc, junto do que você entregou não poderia turbinar mais a capacidade do meu agente local, principalmente por ele ser um modelo menor com menos capacidade de inferência?

Sim — **integrar um fluxo Spec-Driven + um padrão tipo `AGENTS.md` + MCP/RAG** pode turbinar bastante o seu agente local (especialmente sendo menor), porque você reduz a carga de inferência e “decisão implícita” e passa a trabalhar com artefatos explícitos e verificáveis.[^29_1][^29_2]
O ganho vem de transformar o trabalho em uma sequência fixa: **especificar → planejar → executar → verificar**, com gates de lint/test/build e um “single source of truth” para instruções de agente.[^29_3][^29_4]

## Por que isso ajuda modelo pequeno

Modelos menores falham mais em: manter contexto, lembrar decisões e manter consistência em longas cadeias de passos.[^29_2]
Spec-driven + `AGENTS.md` fazem o agente “ler regras” e operar com **artefatos versionados**, reduzindo retrabalho e aumentando a previsibilidade.[^29_4][^29_1]

## O que eu recomendo para o seu caso (prático, baixo overhead)

Para um projeto “infra + OS remaster + AD/Samba/ZFS”, eu sugiro uma abordagem híbrida:

- **`AGENTS.md`** na raiz do repo como “README para agentes”, padronizando: setup, comandos, testes, estilo, proibições, onde estão os artefatos SoT/runbooks.[^29_1][^29_2]
- **Spec-driven leve** (estilo OpenSpec/Open-Spec “markdown-first”) para features grandes e mudanças críticas (ex.: HA, replicação, instalador vdev planner), porque isso mantém cadência sem burocracia.[^29_3]
- “BMAD” só para itens muito grandes se você realmente quer simular papéis (PM/Arquiteto/QA), porque ele tende a aumentar overhead; no seu projeto, o risco é virar documentação demais e execução de menos.[^29_3]


## MCP/RAG: quando vale (e quando não vale)

- **MCP** vale muito para “contratos de ferramentas”: git/diff, executar lint/test, docker build ISO, ssh para jump box, leitura de arquivos do repo, e coleta de logs. Isso evita que o agente invente comandos ou esqueça etapas.[^29_5]
- **RAG híbrido** vale quando o agente precisa consultar *conhecimento estável* e grande: manpages, runbooks internos, templates e decisões SoT; isso pode ser só “RAG local” em cima do seu próprio repo + um diretório `kb/` de PDFs/HTML/manpages, sem internet.[^29_4]
- Não use RAG para substituir as decisões: use para **recuperar** documentos e reduzir janela de contexto.


## OpenCode + plugins (Oh My OpenCode) no seu cenário

Uma CLI com plugins e comandos padronizados pode acelerar muito o workflow e dar autonomia (ex.: comandos “specify/plan/implement/verify”), e a comunidade do OpenCode tem plugins como oh-my-opencode que automatizam orquestração e ciclo de vida.[^29_6][^29_7]
O risco é “complexidade do meta-sistema”: mantenha plugins como opcionais e garanta que o repositório continue operável com `just`/`make` + CI mesmo sem OpenCode.

## Artefato que faltava: `AGENTS.md` (pronto para salvar)

Crie **na raiz** do repo: `AGENTS.md` (o formato é pensado como padrão aberto para guiar agentes).[^29_2][^29_1]

```md
# AGENTS.md — NAS Debian (ZFS + Samba/AD + HA)

Este arquivo é o guia padronizado para agentes de código. Ele complementa o README humano e serve como “fonte de instruções para máquinas”. [web:490][web:483]

## 1) Fonte da verdade
- SEMPRE leia `docs/00_SOURCE_OF_TRUTH.md` antes de propor mudanças.
- Se uma decisão não estiver na SoT, crie/atualize a SoT primeiro.

## 2) Objetivo do projeto
- ISO Debian Trixie remaster via live-build (em docker), com instalador custom (shell) para ZFS root + ZFSBootMenu.
- Servidor SMB-only integrado ao AD, Windows-first ACL.
- HA ativo+passivo: físico (EMPRESA-BM-NAS) -> VM standby (EMPRESA-VM-NAS), alias `fileserver.empresa.com.br`.

## 3) Comandos padrão (use estes)
- Lint: `just lint`
- Testes: `just test`
- Build ISO: `just build-iso`
- AD precheck (dry): `just ad-precheck-dry HOST=<jumpbox> USER=<ad_user> VIP=<vip> DC=<dc>`
- AD precheck (apply): `just ad-precheck-apply HOST=<jumpbox> USER=<ad_user> VIP=<vip> DC=<dc>`

## 4) Regras de mudança (obrigatório)
- Mudanças pequenas e reversíveis; sempre fornecer patch/diff.
- Não inserir segredos no repo, ISO ou logs.
- Sempre rodar lint/test antes de finalizar.

## 5) Locais importantes no repo
- Templates Samba: `artifacts/templates/smb/`
- Scripts validação Linux-side: `artifacts/scripts/validate_ad_smb.sh`
- Automação AD-side (PowerShell): `artifacts/scripts/ad_setup_fileserver.ps1`
- Wrapper Debian-side (SSH jump box): `artifacts/scripts/ad_precheck_fileserver.sh`
- Runbooks AD/SPN/DNS: `docs/30_*.md`, `docs/31_*.md`, `docs/32_*.md`, `docs/37_*.md`

## 6) Critérios de aceite (qualidade)
- CI lint passando em PR.
- Qualquer alteração que toque em AD/DNS/SPN deve atualizar runbook e (se aplicável) scripts.
```


## Como encaixar “Spec-Driven” no seu repo (mínimo viável)

Crie:

- `specs/` para specs aprovadas
- `specs/_drafts/` para rascunhos

Template de spec (um arquivo por mudança grande), ex.: `specs/ha-active-passive.md`:

- Problema / objetivos / não-objetivos
- Requisitos funcionais e não funcionais
- Interfaces/artefatos (arquivos que devem existir)
- Plano de implementação em etapas pequenas
- Plano de testes e critérios de aceite
- Checklist de rollback

Isso dá o mesmo benefício do Spec-Driven sem depender de uma ferramenta específica.

## Pergunta de decisão (para eu ajustar a recomendação)

Você quer adotar um fluxo Spec-Driven como **processo oficial do repo** (CI exige spec para mudanças em HA/instalador/AD), ou só como “modo recomendado” para features grandes?
<span style="display:none">[^29_10][^29_11][^29_12][^29_13][^29_14][^29_15][^29_16][^29_8][^29_9]</span>

<div align="center">⁂</div>

[^29_1]: https://agents.md

[^29_2]: https://www.infoq.com/news/2025/08/agents-md/

[^29_3]: https://www.nosam.com/spec-driven-development-openspec-vs-spec-kit-vs-bmad-which-ones-actually-worth-your-time/

[^29_4]: https://tessl.io/blog/the-rise-of-agents-md-an-open-standard-and-single-source-of-truth-for-ai-coding-agents/

[^29_5]: https://docs.continue.dev/customize/deep-dives/rules

[^29_6]: https://deepwiki.com/code-yeongyu/oh-my-opencode/2.1-installation

[^29_7]: https://meyer-laurent.com/playing-with-oh-my-open-code

[^29_8]: https://github.com/openai/agents.md

[^29_9]: https://agentsmd.net

[^29_10]: https://github.com/agentsmd/agents.md

[^29_11]: https://tutorial.theaibuilders.dev/tutorials/Vibe Coding/agents_md

[^29_12]: https://videohighlight.com/v/sGYvGUkerA0

[^29_13]: https://www.builder.io/blog/agents-md

[^29_14]: https://www.reddit.com/r/BMAD_Method/comments/1obaopd/bmad_vs_spek_kit_vs_open_spec_which_ai_coding/

[^29_15]: https://deepwiki.com/code-yeongyu/oh-my-opencode

[^29_16]: https://redreamality.com/blog/-sddbmad-vs-spec-kit-vs-openspec-vs-promptx/


---

# eu gostaria de ter um fluxo mais previsível de interação, com passos bem definidos, comandos que já dizem boa parte do que o agente precisa, sem de peder de formulações manuais exaustivas para instruir corretamente o agente, isso tem um efeito equivalente para humanos que tendem a se cançar muito com processos desse logos e repetitivos que dependem de esforços cognitivos prolongados, provocando perde de performance, assim como ocorre com agentes de LLM com janela de contexto cheia.

Adotar alguma abordabem como Spec-Driven pode ser uma possibilidade, desde que não crie uma sobrecarga de burocracia, isso prejuticaria mais do que ajudaria.

Sim — um workflow guiado tipo **Spec-Driven** (OpenSpec/Spec-Kit) + `AGENTS.md` + “comandos de fluxo” (CLI/just/opencode plugins) tende a **aumentar muito** previsibilidade e qualidade, especialmente com modelo local menor, desde que você adote a versão **lightweight** (fast lane) e coloque “burocracia” só onde dói (mudanças críticas).[^30_1][^30_2][^30_3]

## O que adotar (mínimo burocrático)

Eu recomendo uma abordagem **2 trilhas**:

- **Trilha Rápida (default)**: mudanças pequenas e médias sem spec formal pesada, mas com passos fixos e automatizados (checklist + comandos).
- **Trilha Spec (obrigatória só para crítico)**: para HA/replicação, instalador (vdev planner), AD/SPN/DNS automation, e qualquer mudança que impacte “fileserver”/Kerberos.

Isso replica o que frameworks como BMAD chamam de “Quick Flow” versus trilhas mais completas, evitando sobrecarga para tarefas pequenas.[^30_4][^30_3]

## Por que OpenSpec/Spec-Kit ajudam (em termos práticos)

Ferramentas Spec-Driven geralmente padronizam o ciclo em etapas tipo **Specify → Plan → Tasks → Implement**, com artefatos markdown por etapa, o que reduz o “prompting manual” e transforma a interação em comandos previsíveis.[^30_2][^30_5]
OpenSpec especificamente descreve um workflow baseado em artefatos (delta specs/changes + tasks), que serve como “mapa” para o agente implementar e marcar tarefas concluídas.[^30_6][^30_7]

## Onde OpenCode + plugins entram

Se você já usa OpenCode e a comunidade tem plugins/“Oh My OpenCode”, isso pode virar sua “camada de comando” para agentes (slash commands, automações, indexação, execução), reduzindo esforço cognitivo e repetição.[^30_8][^30_9]
A doc do OpenCode descreve um sistema de plugins carregados de paths fixos (`.opencode/plugins/` no projeto e `~/.config/opencode/plugins/` global), com ordem de carregamento e possibilidade de criar ferramentas customizadas.[^30_8]

## Minha recomendação final (para seu projeto)

- **Adote `AGENTS.md`** como padrão de instrução para qualquer agente. (Já te entreguei um draft; mantenha conciso e com comandos.)[^30_10][^30_11]
- **Adote Spec-Driven “leve”** com estrutura de pasta `specs/` + templates e um conjunto de comandos no `justfile` que simulam `/specify /plan /tasks /apply`.[^30_2]
- Se você quiser ferramenta externa, **OpenSpec** é uma opção porque se posiciona explicitamente como “lightweight spec-driven framework” e tem workflow guiado por artefatos; mas você também pode implementar o mesmo comportamento “em casa” com `just` + templates, sem depender de outra ferramenta.[^30_1][^30_6]

***

## Artefato: `docs/WORKFLOW_AI.md` (passos fixos + gates)

Crie este arquivo (ele vira “processo” com pouquíssima burocracia):

```md
# Workflow de desenvolvimento assistido por IA (previsível e leve)

## Trilha Rápida (default) — 5 a 20 minutos
Use para: docs, ajustes pequenos de script, templates, refactors localizados.

Passos:
1) `just lint`
2) (se aplicável) `just test`
3) Agente gera patch pequeno (diff) + explica impacto
4) Você revisa
5) Commit semântico + CI lint

Artefatos mínimos:
- Issue/Task com título e critério de aceite em 2-3 linhas.

## Trilha Spec (obrigatória para CRÍTICO)
Obrigatório para:
- HA/failover/replicação
- instalador ZFS (vdev planner, seleção de discos)
- AD/DNS/SPN/Kerberos (fileserver.*)
- mudanças no smb.conf global, vfs objects, protocolo SMB, multichannel

Passos:
1) Criar spec: `specs/NNN-nome/requirements.md`
2) Planejar: `specs/NNN-nome/plan.md`
3) Tarefas: `specs/NNN-nome/tasks.md`
4) Implementar por tarefas (uma PR/commit por bloco se possível)
5) Verificar gates: lint/test/build-iso (quando aplicável)

Critérios de aceite:
- requirements tem cenários GIVEN/WHEN/THEN quando aplicável
- plan define arquivos afetados e rollback
- tasks são checkboxes e podem ser marcadas durante implementação
```

Isso te dá Spec-Driven sem instalar nada.

***

## Artefato: templates de spec (copiar/colar)

Crie:

### `specs/_templates/requirements.md`

```md
# Requirements — <NOME>

## Objetivo
## Não-objetivos
## Requisitos funcionais
- R1:
## Requisitos não funcionais
- NFR1:
## Cenários (GIVEN/WHEN/THEN)
- S1:
## Critérios de aceite
- AC1:
```


### `specs/_templates/plan.md`

```md
# Plan — <NOME>

## Abordagem
## Arquivos afetados
## Compatibilidade/risco
## Rollback
## Testes
- lint:
- test:
- build-iso:
- validações AD/Samba:
```


### `specs/_templates/tasks.md`

```md
# Tasks — <NOME>

- [ ] T1
- [ ] T2
- [ ] T3
```


***

## Artefato: comandos “tipo Spec Kit” no `justfile`

Você ganha previsibilidade “/specify /plan /tasks /apply” mesmo sem instalar Spec Kit.

Adicione ao `justfile`:

```make
# Cria um novo spec folder com templates
spec-new NAME:
  @set -euo pipefail; \
  n=$$(ls -1 specs 2>/dev/null | grep -E '^[0-9]{3}-' | tail -n 1 | cut -d- -f1); \
  if [ -z "$$n" ]; then n=0; fi; \
  nn=$(printf "%03d" $((10#$$n + 1))); \
  dir="specs/$${nn}-{{NAME}}"; \
  mkdir -p "$$dir"; \
  cp specs/_templates/requirements.md "$$dir/requirements.md"; \
  cp specs/_templates/plan.md "$$dir/plan.md"; \
  cp specs/_templates/tasks.md "$$dir/tasks.md"; \
  echo "Created $$dir"

spec-open NAME:
  @echo "Open specs folder: specs/*-{{NAME}} (use your editor)"
```


***

## Gate anti-burocracia (o segredo)

- **Trilha rápida** não exige spec, só exige lint/test e patch pequeno.
- **Trilha spec** só é obrigatória para “áreas críticas” (as que quebram produção e são difíceis de depurar).
- Você mantém previsibilidade sem “doc por doc”.

***

## Como usar isso com seu agente local (modelo pequeno)

Quando for pedir algo ao agente, você só precisa dizer:

- “Use Trilha Rápida” **ou** “Use Trilha Spec”
- “Entregue: spec + patch + comandos de validação”.

Isso reduz o esforço cognitivo humano e também a necessidade de inferência do agente.[^30_5][^30_2]

***

Se você quiser, eu também posso:

1) escrever um `AGENTS.md` revisado já apontando para `docs/WORKFLOW_AI.md`, e
2) adicionar um workflow de CI que **falha** se uma PR tocar em `artifacts/scripts/ad_*`, `artifacts/templates/smb/`, `docs/30_*.md`, `docs/31_*.md`, `docs/32_*.md`, `specs/` etc. sem incluir/atualizar spec (política leve, só para “crítico”).
<span style="display:none">[^30_12][^30_13][^30_14][^30_15][^30_16][^30_17]</span>

<div align="center">⁂</div>

[^30_1]: https://openspec.dev

[^30_2]: https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html

[^30_3]: http://docs.bmad-method.org/explanation/features/quick-flow/

[^30_4]: https://redreamality.com/garden/notes/bmad-method-guide/

[^30_5]: https://blog.kilo.ai/p/spec-driven-development-what-it-is

[^30_6]: https://github.com/Fission-AI/OpenSpec

[^30_7]: https://intent-driven.dev/knowledge/openspec/

[^30_8]: https://opencode.ai/docs/plugins/

[^30_9]: https://meyer-laurent.com/playing-with-oh-my-open-code

[^30_10]: https://www.infoq.com/news/2025/08/agents-md/

[^30_11]: https://agents.md

[^30_12]: https://www.linkedin.com/posts/vinaybajjuri_day-9798-from-idea-to-production-exploring-activity-7389364165515145217-53vm

[^30_13]: https://www.youtube.com/watch?v=d3Glwdf_xA8

[^30_14]: https://www.linkedin.com/pulse/spec-driven-development-openspec-source-truth-hari-krishnan--obrfc

[^30_15]: https://recruit.group.gmo/engineer/jisedai/blog/the-bmad-method-a-framework-for-spec-oriented-ai-driven-development/

[^30_16]: https://www.youtube.com/watch?v=G_Snfh2M41M

[^30_17]: https://www.youtube.com/watch?v=UtZyvtexJRM


---

# sim

Perfeito — dá para deixar isso **bem previsível e pouco burocrático** criando uma “política leve” no CI: **se tocar em áreas críticas, exige spec**; caso contrário, segue Trilha Rápida. Isso reduz esforço cognitivo (humano e do agente) e aumenta consistência.

Abaixo vão os artefatos prontos para salvar no repo.

## Artefato 1: Política “Spec required” (documento)

Crie `docs/POLICY_SPEC_REQUIRED.md`:

```md
# Política: Spec obrigatório (somente para áreas críticas)

Objetivo: manter previsibilidade e qualidade sem burocracia.

## Quando SPEC é obrigatório
Se a PR tocar em qualquer arquivo/pasta abaixo, ela deve incluir um spec em `specs/NNN-*/` (requirements+plan+tasks) OU atualizar um spec existente:
- HA / cluster: pacemaker/corosync, VIP, fencing, failover
- Replicação: syncoid/sanoid, zfs send/recv, timers
- AD/DNS/SPN/Kerberos / alias fileserver.*
- Samba global/templates (smb.conf, vfs objects, multichannel, SMB protocol)
- Instalador (vdev planner, seleção de discos, ZFS root, bootloader/ZFSBootMenu)

Padrões de paths (críticos):
- artifacts/templates/smb/**
- artifacts/scripts/ad_*
- artifacts/scripts/validate_ad_smb.sh
- docs/30_*.md, docs/31_*.md, docs/32_*.md, docs/37_*.md
- scripts/** (instalador e automações)
- config/** (live-build)
- powershell/**

## Quando SPEC NÃO é obrigatório
- Docs não críticos (ex.: README, comentários), desde que não alterem decisões na SoT.
- Refactors pequenos que não mudem comportamento (ainda assim: lint/test obrigatórios).

## O que conta como “spec presente”
- Deve existir um diretório `specs/NNN-<slug>/` contendo:
  - requirements.md
  - plan.md
  - tasks.md
```


## Artefato 2: CI gate (detecta mudanças críticas e exige spec)

A forma mais simples e robusta é usar uma action de “paths filter” para detectar mudanças por glob e então falhar se não houver arquivos de spec na PR. O `dorny/paths-filter` é bem conhecido para condicionar jobs/steps baseado em arquivos modificados.[^31_1][^31_2]

Crie `.github/workflows/spec-required.yml`:

```yaml
name: spec-required

on:
  pull_request:

permissions:
  contents: read
  pull-requests: read

jobs:
  spec_gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect critical changes
        id: filter
        uses: dorny/paths-filter@v3
        with:
          filters: |
            critical:
              - 'artifacts/templates/smb/**'
              - 'artifacts/scripts/ad_*'
              - 'artifacts/scripts/validate_ad_smb.sh'
              - 'docs/30_*.md'
              - 'docs/31_*.md'
              - 'docs/32_*.md'
              - 'docs/37_*.md'
              - 'scripts/**'
              - 'config/**'
              - 'powershell/**'

            specs:
              - 'specs/**'

      - name: Enforce spec when critical changes exist
        if: steps.filter.outputs.critical == 'true' && steps.filter.outputs.specs != 'true'
        run: |
          echo "::error::Mudanças críticas detectadas, mas nenhum spec em specs/** foi incluído."
          echo "Crie um spec via: just spec-new NAME=<slug> e preencha requirements/plan/tasks."
          exit 1
```

Observação: essa estratégia funciona justamente porque ações de “path filter” conseguem comparar base/head e dizer se certos arquivos mudaram, permitindo condicionar a execução de steps/jobs.[^31_2][^31_1]

## Artefato 3: fortalecer `AGENTS.md` para o fluxo previsível

Atualize o `AGENTS.md` (raiz) adicionando um bloco “Como pedir coisas ao agente”:

```md
## 7) Fluxo previsível (sem burocracia)
- Mudança pequena: diga “Trilha Rápida” e peça patch + `just lint` + (se aplicável) `just test`.
- Mudança crítica (HA/AD/Samba/instalador/live-build): diga “Trilha Spec”.
  - Primeiro: criar/atualizar spec em `specs/NNN-*/`
  - Depois: implementar por tasks, uma mudança pequena por vez.
```


## Artefato 4: comandos `just` para reduzir esforço manual

No `justfile`, adicione um comando “wizard” que cria spec + abre checklist (você já tem `spec-new`; vou completar com “spec-critical”):

```make
spec-critical NAME:
  just spec-new {{NAME}}
  @echo ""
  @echo "Preencha:"
  @echo "  - specs/*-{{NAME}}/requirements.md"
  @echo "  - specs/*-{{NAME}}/plan.md"
  @echo "  - specs/*-{{NAME}}/tasks.md"
  @echo ""
  @echo "Depois peça ao agente: 'Implementar T1..Tn e rodar just lint/test'"
```


## Artefato 5: “Como usar” (runbook curto)

Crie `docs/WORKFLOW_QUICKSTART.md`:

```md
# Quickstart — Workflow com agentes (baixo esforço)

## Mudança pequena (Trilha Rápida)
1) Peça ao agente: “Trilha Rápida, faça X”
2) Exija: patch + comandos de validação
3) Rode: `just lint` (e `just test` se houver testes)

## Mudança crítica (Trilha Spec)
1) Rode: `just spec-critical NAME=<slug>`
2) Preencha requirements/plan/tasks
3) Peça ao agente: “Trilha Spec, implemente T1”
4) Rode: `just lint`, `just test`, (e `just build-iso` quando aplicável)

## CI (automático)
- Se tocar em áreas críticas e não houver `specs/**`, a PR falha com erro “spec required”.
```


***

Se você quiser deixar ainda mais “mão na roda”, eu posso adaptar o gate para aceitar também **“spec mínima”** (um único arquivo `specs/NNN-*/spec.md`) para mudanças críticas muito pequenas, mantendo seu objetivo de evitar burocracia.
<span style="display:none">[^31_10][^31_11][^31_12][^31_13][^31_14][^31_15][^31_3][^31_4][^31_5][^31_6][^31_7][^31_8][^31_9]</span>

<div align="center">⁂</div>

[^31_1]: https://github.com/dorny/paths-filter

[^31_2]: https://nedbatchelder.com/blog/202505/filtering_github_actions_by_changed_files

[^31_3]: https://github.com/marketplace/actions/path-filter

[^31_4]: https://github.com/RasaHQ/pr-changed-files-filter

[^31_5]: https://github.com/yumemi-inc/path-filter

[^31_6]: https://github.com/marketplace/actions/list-files-changed-in-a-pull-request

[^31_7]: https://github.com/marketplace/actions/configurable-required-approvals

[^31_8]: https://github.com/marketplace/actions/changed-files-with-filter

[^31_9]: https://stackoverflow.com/questions/74218948/get-list-of-files-changed-by-github-pull-request-using-git

[^31_10]: https://github.com/marketplace/actions/check-pull-request-body-diff-and-files

[^31_11]: https://docs.github.com/articles/filtering-files-in-a-pull-request-by-file-type

[^31_12]: https://stackoverflow.com/questions/25071579/list-all-files-changed-in-a-pull-request-in-git-github

[^31_13]: https://stackoverflow.com/questions/69348532/github-actions-required-status-check-doesnt-run-due-to-files-in-paths-not-chan

[^31_14]: https://github.com/marketplace/actions/paths-changes-filter

[^31_15]: https://github.com/marketplace/actions/list-files-in-pull-request

