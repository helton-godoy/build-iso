# Plano de Implementação: Otimização do Autologin Serial

O objetivo é reduzir o atraso percebido no autologin do console serial (`ttyS0`) na imagem Live.

## Considerações sobre KMSCON

O uso do `kmscon` afeta os terminais virtuais locais (`tty1` a `tty6`). O console serial (`ttyS0`), utilizado para automação e acesso remoto via BMC/Serial, é tratado de forma independente pelo `agetty`.

> [!NOTE]
> A migração para `kmscon` não deve atrasar o autologin serial. O plano abaixo garante essa independência ao remover `DefaultDependencies=no` do serial-getty, enquanto o KMSCON operará nos terminais locais (tty1+).

## Alterações propostas

### Componente: Pacotes Live-Build

#### [MODIFY] [tools.list.chroot](file:///home/helton/git/build-iso/config-overrides/config/package-lists/tools.list.chroot)

Adicionar pacotes para suporte a KMSCON e fontes de boa qualidade.

```text
kmscon
fonts-noto-mono
fonts-hack
```

### Componente: Configuração Systemd (KMSCON)

#### [NEW] [kmscon.service.d/override.conf](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/etc/systemd/system/kmscon.service.d/override.conf)

Garantir que o KMSCON inicie nos TTYs virtuais e tenha autologin configurado se desejado (para paridade com o comportamento anterior, embora o foco seja a UX).

```ini
[Service]
# Força autologin no KMSCON local também, se desejado para testes locais
ExecStart=
ExecStart=/usr/bin/kmscon --autologin root --vt %I --seat seat0 --no-switchvt --font-name "Hack" --font-size 12
```

> **Nota:** É necessário desabilitar o `getty@tty1` padrão ou garantir que o `kmscon` tome precedência. O pacote Debian geralmente lida com isso via `autovt`, mas forçaremos via link simbólico no hook se necessário.

### Componente: Systemd Overrides (Serial)

#### [MODIFY] [autologin.conf](file:///home/helton/git/build-iso/config-overrides/config/includes.chroot/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf)

Vamos transformar o arquivo de override para que ele não apenas configure o autologin, mas também force o serviço a iniciar o mais cedo possível, ignorando as dependências padrão que podem estar esperando por serviços de rede ou outros componentes do `live-config`.

```ini
[Unit]
Description=Serial Getty on %I (Fast Autologin)
# Ignora dependências padrão para iniciar antes do multi-user.target
DefaultDependencies=no
After=systemd-udev-settle.service local-fs.target
Before=getty.target

[Service]
ExecStart=
# Adicionado --noclear para evitar limpeza de tela que pode parecer atraso
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud 115200,38400,9600 %I $TERM
# Aumenta a prioridade do processo
Nice=-20
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=1
```

### Componente: Parâmetros de Boot

#### [MODIFY] [config](file:///home/helton/git/build-iso/config-overrides/auto/config)

Remover `quiet` e `splash` para reduzir a carga do kernel/initramfs (Plymouth) e permitir que as mensagens de boot apareçam imediatamente, o que ajuda a perceber que o sistema está progredindo. Também ajuda a evitar que o systemd "segure" o getty até que a animação termine.

> [!TIP]
> Remover `live-config.autologin` dos parâmetros de boot pode ser testado se ainda houver atraso, pois o nosso override de systemd é mais direto. Por enquanto, manteremos para garantir compatibilidade.

## Plano de Verificação

### Testes Automatizados

Não existem testes unitários para o tempo de boot, mas podemos usar o script de teste existente:

1. Execute `make build-iso` para gerar uma nova imagem com as alterações.
2. Execute `make test-vm-all`.
3. Use `make vm-connect-uefi CMD=\"echo boot-ok && hostname\"` e observe o tempo desde o início do boot até o sistema responder via SSH.

### Verificação Manual

*   Cronometrar o tempo de boot comparado à versão anterior.
*   Verificar se o login automático realmente ocorre sem intervenção.
*   Confirmar que o terminal está funcional imediatamente.
