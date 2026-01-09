# Grub otimizado para ZFSBootMenu

Para otimizar o Grub e deixá-lo apenas como um carregador mínimo para o **ZFSBootMenu** (ZBM), o objetivo é desativar a detecção automática de outros sistemas operacionais e reduzir o tempo de espera ao mínimo.

## 1. Configuração Mínima no `/etc/default/grub`

Edite o arquivo de configuração principal (`sudo nano /etc/default/grub`) e aplique as seguintes alterações: 

- **Tempo de espera zero:** Para carregar o ZBM imediatamente.
  
  ```bash
  GRUB_TIMEOUT=0
  GRUB_TIMEOUT_STYLE=hidden
  ```

- **Desativar o OS-Prober:** Evita que o Grub procure e adicione outros sistemas operacionais (como Windows ou outras distros) ao menu.
  
  ```bash
  GRUB_DISABLE_OS_PROBER=true
  ```

- **Limpar a linha de comando:** Remova parâmetros desnecessários de `GRUB_CMDLINE_LINUX_DEFAULT` para manter o carregamento limpo. 

## 2. Criar a Entrada para o ZFSBootMenu

Em vez de depender de scripts complexos, crie uma entrada manual simples no arquivo `/etc/grub.d/40_custom`: 

```bash
menuentry "ZFSBootMenu" {
    # Ajuste 'hd0,gpt1' para a sua partição EFI onde o arquivo .EFI do ZBM está
    search --set=root --file /EFI/zfsbootmenu/vmlinuz.EFI
    chainloader /EFI/zfsbootmenu/vmlinuz.EFI
}
```

## 3. Remover Scripts Desnecessários

Para garantir que apenas a sua entrada customizada apareça, você pode remover a permissão de execução de scripts que geram entradas automáticas de kernel (opcional e avançado):

```bash
sudo chmod -x /etc/grub.d/10_linux /etc/grub.d/20_linux_xen /etc/grub.d/30_os-prober
```

## 4. Aplicar Alterações

Após as edições, gere o novo arquivo de configuração do Grub: 

```bash
sudo update-grub
# Ou em algumas distros:
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Alternativa Recomendada

A documentação oficial do ZFSBootMenu sugere que, em sistemas modernos com UEFI, o Grub pode ser removido completamente. Você pode usar o `efibootmgr` para registrar o ZFSBootMenu diretamente no firmware da placa-mãe, eliminando a necessidade do Grub como intermediário.

## 5. Avançado

Para otimizar o tempo de inicialização em 2026, você pode ir além das configurações básicas de tempo de espera. Aqui estão estratégias avançadas para o **GRUB** e ajustes específicos para o **ZFSBootMenu** (ZBM).

### 5.1. Otimização do GRUB (Nível Avançado)

Para tornar o GRUB o mais rápido possível antes de ele passar o controle para o ZBM:

- **Desativar Módulos Desnecessários:** O GRUB carrega vários drivers por padrão. Se você usa apenas o essencial para o ZBM via EFI, remova temas gráficos e fontes pesadas. No `/etc/default/grub`, defina:
  
  ```bash
  GRUB_TERMINAL=console
  # Desative o suporte gráfico que consome tempo de inicialização de vídeo
  ```

- **Remover o "Quiet Splash" do GRUB:** Embora pareça contraditório, remover animações de carregamento (Plymouth) reduz a carga de drivers de vídeo no estágio inicial. Use `GRUB_CMDLINE_LINUX_DEFAULT="noplymouth"`.

- **Reduzir a Verificação de Hardware:** Alguns sistemas permitem o **Fast Boot** na BIOS/UEFI, que pula a inicialização de periféricos USB e verificações de memória.

- **Substituição Total:** Em 2026, a recomendação para performance máxima é substituir o GRUB pelo **systemd-boot** ou **EFISTUB**. O ZFSBootMenu pode ser carregado diretamente pela UEFI, economizando de 2 a 5 segundos de processamento do GRUB. 

### 5.2. Otimização do ZFSBootMenu (ZBM)

O ZBM é um ambiente Linux minimalista; sua performance depende de como ele interage com os pools ZFS:

- **Pular o Menu (Fast Boot do ZBM):** Se você raramente troca de snapshot, configure o parâmetro `zbm.skip` na linha de comando do kernel do ZBM. Isso fará com que ele carregue o dataset padrão (`bootfs`) imediatamente sem exibir o menu.
- **Compressão do Kernel/Initramfs:** Certifique-se de que o binário `.EFI` do ZFSBootMenu foi gerado usando compressão **LZ4** ou **ZSTD**, que descompactam muito mais rápido que o GZIP tradicional.
- **Reduzir o Loglevel:** Adicione `loglevel=0` aos parâmetros do ZBM para evitar que mensagens de kernel atrasem a exibição da interface ou o carregamento do próximo kernel.
- **Otimização do Pool ZFS:**
  - **Recordsize:** Para o dataset de boot, um `recordsize=128k` (padrão) costuma ser ideal, mas evite valores muito pequenos que aumentam a sobrecarga de leitura durante o carregamento do kernel.
  - **Ajuste do HostID:** Use a propriedade `zbm.set_hostid` para garantir que o ZBM não perca tempo tentando resolver conflitos de importação de pool entre diferentes ambientes. 

#### Resumo de Performance para 2026

| Ação                 | Ferramenta       | Impacto Esperado                  |
| -------------------- | ---------------- | --------------------------------- |
| **Pular Menu**       | ZBM (`zbm.skip`) | Instantâneo para o Kernel         |
| **Remover GRUB**     | UEFI Direct Boot | ~2 a 5 segundos a menos           |
| **Terminal Console** | GRUB             | Carregamento de vídeo instantâneo |
| **LZ4 Compression**  | Kernel/Initramfs | Descompactação mais rápida        |
