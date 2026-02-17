<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# descubra como fazer uma SKILL para transformar o llm em especialista virsh, ele precisa ser capaz de acessar e manipular o sistema operacional dentro de uma vm

Para criar uma SKILL que transforme um LLM em especialista virsh capaz de acessar e manipular sistemas operacionais dentro de VMs, você precisa implementar um sistema de **function calling** (chamada de funções) que conecte o LLM a comandos virsh executados no host. O LLM não executa comandos diretamente; ele identifica a intenção do usuário, determina qual função chamar e fornece os parâmetros necessários em formato JSON estruturado.[^1_1][^1_2][^1_3]

## Arquitetura da SKILL

A implementação requer três componentes principais:

1. **Definição das ferramentas (tools)**: Crie um dicionário Python contendo o nome de cada função virsh, sua descrição e os parâmetros necessários[^1_4]
2. **Prompt do sistema**: Instrua o LLM sobre quando e como usar cada ferramenta virsh disponível
3. **Executor de comandos**: Um módulo Python que recebe as chamadas de função do LLM e executa os comandos virsh correspondentes via subprocess[^1_5]

## Funções Virsh Essenciais

### Gerenciamento Básico de VMs

As funções fundamentais incluem:

- `virsh list` ou `virsh list --all`: Lista VMs ativas ou todas as VMs[^1_6]
- `virsh start <nome-vm>`: Inicia uma máquina virtual[^1_6]
- `virsh shutdown <nome-vm>`: Desliga graciosamente uma VM[^1_6]
- `virsh define /path/to/config.xml`: Cria uma nova VM a partir de arquivo XML[^1_6]
- `virsh domifaddr --source agent <nome-vm>`: Obtém endereço IP da VM via qemu-guest-agent[^1_7]

### Execução de Comandos Dentro da VM

Para executar comandos dentro do sistema operacional da VM, você precisa do **qemu-guest-agent** instalado na VM. Use o comando:[^1_8][^1_7]

```python
virsh qemu-agent-command <nome-vm> '{"execute": "guest-exec", "arguments": {"path": "/usr/bin/comando", "arg": ["parametro1"], "capture-output": true}}'
```

Para recuperar o resultado, use o PID retornado:

```python
virsh qemu-agent-command <nome-vm> '{"execute": "guest-exec-status", "arguments": {"pid": 12345}}'
```

## Exemplo de Implementação

```python
import json
import subprocess
from openai import OpenAI

# Definição das ferramentas
VIRSH_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "virsh_list_vms",
            "description": "Lista todas as máquinas virtuais disponíveis",
            "parameters": {
                "type": "object",
                "properties": {
                    "all": {"type": "boolean", "description": "Se True, lista VMs inativas também"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "virsh_exec_command",
            "description": "Executa comando dentro da VM via qemu-guest-agent",
            "parameters": {
                "type": "object",
                "properties": {
                    "vm_name": {"type": "string", "description": "Nome da VM"},
                    "command": {"type": "string", "description": "Caminho completo do comando"},
                    "args": {"type": "array", "items": {"type": "string"}, "description": "Argumentos do comando"}
                },
                "required": ["vm_name", "command"]
            }
        }
    }
]

def execute_virsh_command(function_name, args):
    if function_name == "virsh_list_vms":
        cmd = ["virsh", "list"]
        if args.get("all"):
            cmd.append("--all")
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout

    elif function_name == "virsh_exec_command":
        qmp_command = {
            "execute": "guest-exec",
            "arguments": {
                "path": args["command"],
                "arg": args.get("args", []),
                "capture-output": True
            }
        }
        cmd = ["virsh", "qemu-agent-command", args["vm_name"], json.dumps(qmp_command)]
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout
```

## Considerações de Segurança Críticas

**ATENÇÃO**: Permitir que um LLM execute comandos virsh e acesse sistemas operacionais apresenta riscos severos de segurança.[^1_9][^1_10]

### Riscos Principais

1. **Execução arbitrária de código**: Atacantes podem injetar comandos maliciosos através de prompts manipulados[^1_11]
2. **Acesso a credenciais**: O LLM pode acessar arquivos .env, chaves SSH ou tokens do host[^1_9]
3. **Escalada de privilégios**: Comandos virsh geralmente requerem privilégios root ou grupo libvirt[^1_12]

### Mitigações Obrigatórias

- **Sandboxing rigoroso**: Execute o código do agente em containers isolados com restrições de rede e syscall filtering[^1_9]
- **Lista de bloqueio de comandos**: Impeça execução de comandos perigosos (rm -rf, dd, shutdown do host)[^1_10]
- **Validação de entrada**: Sanitize todos os parâmetros antes de passar para subprocess[^1_11]
- **Princípio do menor privilégio**: Conceda apenas permissões mínimas necessárias[^1_9]
- **Kill switch**: Implemente capacidade de terminação instantânea se o agente se comportar de forma inesperada[^1_10]
- **Auditoria e logging**: Registre todas as operações realizadas pelo LLM

### Alternativa Mais Segura

Considere restringir as operações a um conjunto limitado de ações pré-aprovadas, em vez de permitir execução arbitrária de comandos dentro das VMs.[^1_10]
<span style="display:none">[^1_13][^1_14][^1_15][^1_16][^1_17][^1_18][^1_19][^1_20]</span>

<div align="center">⁂</div>

[^1_1]: https://martinfowler.com/articles/function-call-LLM.html

[^1_2]: https://www.promptingguide.ai/applications/function_calling

[^1_3]: https://www.youtube.com/watch?v=PYFfKNUNWYM

[^1_4]: https://blog.christoolivier.com/p/llms-and-functiontool-calling

[^1_5]: https://www.redhat.com/en/blog/virsh-subcommands

[^1_6]: https://www.bdrshield.com/blog/7-vrish-commands-for-managing-kernel-virtual-machines/

[^1_7]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-using_the_qemu_guest_virtual_machine_agent_protocol_cli-libvirt_commands

[^1_8]: https://www.0xf8.org/2022/01/executing-arbitrary-commands-in-your-libvirt-qemu-virtual-machine-through-qemu-guest-agent/

[^1_9]: https://unit42.paloaltonetworks.com/agentic-ai-threats/

[^1_10]: https://www.mintmcp.com/blog/ai-agent-security

[^1_11]: https://sourcery.ai/vulnerabilities/python-aws-lambda-security-dangerous-subprocess-use

[^1_12]: https://documentation.suse.com/sles/15-SP7/html/SLES-all/cha-libvirt-config-virsh.html

[^1_13]: https://www.apideck.com/blog/llm-tool-use-and-function-calling

[^1_14]: https://www.youtube.com/watch?v=gMeTK6zzaO4

[^1_15]: https://www.redhat.com/ja/blog/virsh-subcommands

[^1_16]: https://dl.acronis.com/u/software-defined/html/AcronisCyberInfrastructure_3_admins_cmd_guide_en-US/advanced-tasks/running-commands-in-vms.html

[^1_17]: https://www.libvirt.org/manpages/virsh.html

[^1_18]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-domain_commands-connecting_the_serial_console_for_the_guest_virtual_machine

[^1_19]: https://habr.com/ru/articles/700196/

[^1_20]: https://www.reddit.com/r/learnpython/comments/1ilhdww/seeking_secure_python_code_execution_solutions/

---

# dessa forma o llm poderia interagir com scripts interativos, que utilizam gum para criar a interação com o usuário?

**Não diretamente** - o `virsh qemu-agent-command` não suporta interação bidirecional com stdin/stdout em tempo real, o que impede que o LLM interaja com scripts que usam `gum` de forma interativa. No entanto, existem **duas abordagens viáveis** para contornar essa limitação.[^2_1]

## Por Que Não Funciona Diretamente

O `qemu-guest-agent` utiliza o protocolo QMP (QEMU Machine Protocol), não um shell interativo. Quando você executa `guest-exec`, o comando:[^2_1]

1. É executado de uma vez com todos os argumentos pré-definidos
2. Captura stdout/stderr apenas após conclusão
3. Não permite envio de dados para stdin durante a execução[^2_2]

Isso significa que um script usando `gum input` ou `gum choose` ficaria aguardando input indefinidamente, resultando em timeout.[^2_2]

## Solução 1: Usar Gum em Modo Não-Interativo

O `gum` pode ser usado passando valores diretamente como argumentos da linha de comando, sem necessidade de interação:[^2_3]

```python
# Em vez de interativo:
# gum input --placeholder "Nome do usuário"

# Use modo não-interativo com valores fornecidos pelo LLM:
echo "João Silva" | gum input --placeholder "Nome do usuário"

# Ou para escolhas:
echo "opção2" | gum choose "opção1" "opção2" "opção3"
```

O LLM pode construir comandos onde os valores são pré-populados via pipe ou variáveis de ambiente.[^2_3]

## Solução 2: Usar Expect/Pexpect para Automação

Para scripts que exigem interação verdadeira, você pode criar wrappers usando `expect` (Linux) ou `pexpect` (Python) que automatizam as respostas:[^2_4][^2_5]

```python
# Script expect que automatiza interação com gum
#!/usr/bin/expect
spawn /caminho/para/script_com_gum.sh
expect "What is your name?" { send "João\n" }
expect "Choose option:" { send "2\n" }
expect EOF
```

O LLM pode:

1. Analisar o script para identificar prompts esperados
2. Gerar um script expect com as respostas apropriadas
3. Executar o wrapper expect via `guest-exec`[^2_4]

Você também pode usar `autoexpect` para gerar automaticamente scripts expect a partir de uma sessão interativa registrada.[^2_4]

## Solução 3: Modificar Scripts para Aceitar Variáveis

A abordagem mais robusta é refatorar seus scripts para aceitar parâmetros via:

```bash
#!/bin/bash
# Em vez de: NAME=$(gum input --placeholder "Nome")
# Use variáveis de ambiente ou argumentos:
NAME=${1:-$(gum input --placeholder "Nome")}

COUNTRY=${2:-$(gum choose "Brasil" "Argentina" "Chile")}
```

O LLM pode então executar via `guest-exec` passando valores:

```python
virsh qemu-agent-command vm01 '{
  "execute": "guest-exec",
  "arguments": {
    "path": "/usr/local/bin/meu_script.sh",
    "arg": ["João Silva", "Brasil"],
    "capture-output": true
  }
}'
```

## Consideração de Segurança

Ferramentas como `expect` e `pexpect` que automatizam interações com comandos privilegiados representam riscos adicionais, pois podem expor credenciais em texto plano nos scripts. Certifique-se de:[^2_5][^2_4]

- Nunca armazenar senhas diretamente em scripts expect
- Usar cofres de credenciais (Vault, secrets managers)
- Auditar todos os scripts gerados pelo LLM antes da execução
  <span style="display:none">[^2_10][^2_11][^2_12][^2_13][^2_14][^2_15][^2_16][^2_17][^2_18][^2_19][^2_20][^2_6][^2_7][^2_8][^2_9]</span>

<div align="center">⁂</div>

[^2_1]: https://www.0xf8.org/2022/01/executing-arbitrary-commands-in-your-libvirt-qemu-virtual-machine-through-qemu-guest-agent/

[^2_2]: https://forum.proxmox.com/threads/executing-command-through-qm-guest-exec-limitations.102051/

[^2_3]: https://commandmasters.com/commands/gum-common/

[^2_4]: https://linuxconfig.org/how-to-automate-interactive-cli-commands-with-expect

[^2_5]: https://stackoverflow.com/questions/45967099/how-to-automate-shell-interactive-commands-using-python-pexpect-module

[^2_6]: https://github.com/charmbracelet/gum

[^2_7]: https://ziggit.dev/t/user-friendly-interactive-cli-prompts/2800

[^2_8]: https://www.reddit.com/r/golang/comments/wa9iy3/gum_a_tool_for_glamorous_shell_scripts/

[^2_9]: https://www.x-cmd.com/pkg/gum/

[^2_10]: https://hexmos.com/freedevtools/tldr/common/gum/

[^2_11]: https://forrestcli.com/context/qm-guest-exec/qm-guest-exec:tldr:a3212

[^2_12]: https://www.digitaldesignjournal.com/python-subprocess-interactive/

[^2_13]: https://bjorn.now/til/2025-08-20-gum-is-a-cli-tool-that-helps-your-make-your-scripts-easy-to-interact-with/

[^2_14]: https://tldr.dendron.so/notes/linux.qm-guest-exec.html

[^2_15]: https://stackoverflow.com/questions/71026789/interactive-stdin-stdout-with-subprocess

[^2_16]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-using_the_qemu_guest_virtual_machine_agent_protocol_cli-libvirt_commands

[^2_17]: https://wiki.libvirt.org/Qemu_guest_agent.html

[^2_18]: https://lists.libvirt.org/archives/list/devel@lists.libvirt.org/message/TED6BN2SGMUFJVYAUAVX4EKMDCORHK2K/

[^2_19]: https://deepwiki.com/google-gemini/gemini-cli/3.7-non-interactive-mode-and-headless-usage

[^2_20]: https://technekey.com/simplifying-vm-management-executing-commands-in-guest-vms-using-virsh/

---

# seria possível com esses recursos o agente avançar o menu do grub se não tiver tempo para iniciar automático?

**Sim, é possível**, mas **não através do qemu-guest-agent** - você precisa usar o comando `virsh send-key`. O qemu-guest-agent só funciona após o sistema operacional iniciar, portanto não consegue interagir com o GRUB que aparece antes do SO carregar.[^3_1][^3_2][^3_3]

## Solução: virsh send-key

O comando `virsh send-key` permite enviar combinações de teclas diretamente para a VM, funcionando inclusive durante o boot no GRUB:[^3_3]

```python
# Enviar tecla Enter para selecionar opção do GRUB
virsh send-key nome-da-vm KEY_ENTER

# Navegar pelo menu do GRUB
virsh send-key nome-da-vm KEY_DOWN  # Descer no menu
virsh send-key nome-da-vm KEY_UP    # Subir no menu

# Enviar tecla 'e' para editar entrada do GRUB
virsh send-key nome-da-vm KEY_E
```

### Implementação para o Agente LLM

Você pode criar uma função na SKILL do LLM para interagir com o GRUB:

```python
{
    "type": "function",
    "function": {
        "name": "virsh_send_key",
        "description": "Envia tecla para VM, funciona durante boot e GRUB",
        "parameters": {
            "type": "object",
            "properties": {
                "vm_name": {"type": "string", "description": "Nome da VM"},
                "keys": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Sequência de teclas: KEY_ENTER, KEY_DOWN, KEY_UP, etc"
                }
            },
            "required": ["vm_name", "keys"]
        }
    }
}
```

O LLM poderia então:

1. Detectar que a VM está parada no GRUB (via timeout ou verificação de estado)
2. Enviar `KEY_ENTER` para avançar a inicialização
3. Ou navegar com `KEY_DOWN`/`KEY_UP` e selecionar entradas específicas

## Alternativa: virsh console (Requer Configuração)

Você também pode usar `virsh console` para acessar o console serial da VM, mas isso requer **configurar o GRUB para suportar console serial** dentro da VM:[^3_4][^3_5]

### Configuração necessária dentro da VM:

Edite `/etc/default/grub`:

```bash
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1"
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"
```

Aplique as mudanças:

```bash
update-grub  # Debian/Ubuntu
grub2-mkconfig -o /boot/grub2/grub.cfg  # RHEL/CentOS
```

### Após configuração, use:

```python
# Conectar ao console serial
virsh console nome-da-vm

# Enviar comandos interativamente
# O LLM pode usar pexpect para automatizar
```

## Limitações e Considerações

**virsh send-key** é mais robusto porque:

- Funciona imediatamente, sem configuração prévia na VM[^3_3]
- Não depende de console serial configurado
- Pode enviar qualquer combinação de teclas (Ctrl+Alt+Del, Esc, etc)

**virsh console** oferece:

- Acesso completo ao output do GRUB via texto
- Possibilidade de ler mensagens de erro
- Mas requer reconfiguração do GRUB antecipadamente[^3_6][^3_5]

Para um agente LLM autônomo, **virsh send-key é a melhor escolha** pois funciona universalmente sem modificações prévias nas VMs.
<span style="display:none">[^3_10][^3_7][^3_8][^3_9]</span>

<div align="center">⁂</div>

[^3_1]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_virtualization/assembly_connecting-to-virtual-machines_configuring-and-managing-virtualization

[^3_2]: https://wiki.qemu.org/Features/GuestAgent

[^3_3]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-editing_a_guest_virtual_machines_configuration_file-sending_keystoke_combinations_to_a_specified_domain

[^3_4]: https://forums.whonix.org/t/grub-serial-menu-in-virsh-console/8097

[^3_5]: https://www.suse.com/support/kb/doc/?id=000019728

[^3_6]: https://ravada.readthedocs.io/en/latest/docs/config_console.html

[^3_7]: https://documentation.suse.com/sles/15-SP7/html/SLES-all/cha-libvirt-config-virsh.html

[^3_8]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/configuring_and_managing_linux_virtual_machines/connecting-to-virtual-machines

[^3_9]: https://www.gnu.org/software/grub/manual/grub/html_node/sendkey.html

[^3_10]: https://www.gnu.org/software/grub/manual/grub/html_node/Platform-limitations.html
