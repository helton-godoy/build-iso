# Plano da Trilha: Automação de Testes em VM

## Fase 1: Infraestrutura e Detecção [checkpoint: 1e618fb]
- [x] Task: Criar função de detecção de dependências (QEMU, KVM, OVMF) 07504d3
- [x] Task: Implementar criação de disco virtual temporário 1e618fb

## Fase 2: Refatoração do Script de Lançamento
- [ ] Task: Adicionar suporte a KVM e otimização de recursos (RAM/CPU)
- [ ] Task: Refinar suporte UEFI com caminhos de firmware detectados
- [ ] Task: Adicionar argumentos para controle do disco (ex: `--disk-size`, `--keep-disk`)

## Fase 3: Validação do Fluxo de Instalação
- [ ] Task: Testar boot em modo BIOS e UEFI com o novo script
- [ ] Task: Realizar teste manual de instalação completa no disco virtual
- [ ] Task: Conductor - User Manual Verification 'Automação de Testes em VM' (Protocol in workflow.md)
