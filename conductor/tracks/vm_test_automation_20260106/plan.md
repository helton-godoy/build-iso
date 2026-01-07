# Plano da Trilha: Automação de Testes em VM

## Fase 1: Infraestrutura e Detecção [checkpoint: 1e618fb]
- [x] Task: Criar função de detecção de dependências (QEMU, KVM, OVMF) 07504d3
- [x] Task: Implementar criação de disco virtual temporário 1e618fb

## Fase 2: Refatoração do Script de Lançamento [checkpoint: 664f045]
- [x] Task: Adicionar suporte a KVM e otimização de recursos (RAM/CPU) 51608d8
- [x] Task: Refinar suporte UEFI com caminhos de firmware detectados 07692f1
- [x] Task: Adicionar argumentos para controle do disco (ex: `--disk-size`, `--keep-disk`) 664f045

## Fase 3: Validação do Fluxo de Instalação [checkpoint: 59a8f93]
- [x] Task: Testar boot em modo BIOS e UEFI com o novo script 6612b83
- [x] Task: Realizar teste manual de instalação completa no disco virtual 59a8f93
- [x] Task: Conductor - User Manual Verification 'Automação de Testes em VM' (Protocol in workflow.md)
