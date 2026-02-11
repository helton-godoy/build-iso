# HANDOFF PROMPT — Nova sessão (NAS Debian ZFS + Samba/AD + HA)

Você está assumindo o desenvolvimento de um projeto complexo de NAS baseado em Debian com ZFS, Samba integrado ao Active Directory, e alta disponibilidade ativo-passivo. Este é um projeto de nível profissional que requer atenção meticulosa aos detalhes técnicos, segurança e melhores práticas.

## Contexto do Projeto

O projeto visa criar uma ISO Debian remasterizada via live-build que instala um servidor NAS corporativo com:

- **ZFS + ZFSBootMenu**: Para boot environments e rollback seguro do sistema.
- **Samba SMB-only**: Integração com AD, ACLs editáveis via Windows Security tab, máxima compatibilidade.
- **Alta Disponibilidade**: Replicação ZFS send/receive para failover ativo-passivo com VIP via Pacemaker/Corosync.
- **Automação AD**: Scripts PowerShell executados remotamente via SSH ou WinRM de jump box.
- **Qualidade de Código**: Pre-commit hooks, linting (ShellCheck, PSScriptAnalyzer), CI GitHub Actions.

## Arquivos Principais (Fonte da Verdade)

O projeto usa um modelo de "artefatos versionados" no repositório para reduzir dependência de histórico de conversas. Os arquivos chave são:

- `docs/00_SOURCE_OF_TRUTH.md`: Documento principal de arquitetura e decisões fixas.
- `docs/10_SMB_STACK.md`: Configuração da pilha SMB.
- `docs/20_ZFS_DATASET_TEMPLATES.md`: Templates para datasets ZFS.
- `docs/30_AD_JOIN_AND_ALIAS.md`: Checklist para join AD e SPNs.
- `docs/31_RUNBOOK_FILESERVICE_FILESERVERSMB_AD.md`: Runbook do serviço SMB.
- `docs/32_AD_OBJECTS_CHECKLIST.md`: Checklist de objetos AD obrigatórios.
- `docs/35_JUMPBOX_SSH_KEYS.md`: Configuração SSH na jump box.
- `docs/36_POWERSHELL_OVER_SSH_SUBSYSTEM.md`: Opção PowerShell over SSH.
- `docs/40_FAILOVER_REPLICATION.md`: Replicação e failover.
- `artifacts/templates/smb/smb.conf.smb-only.template`: Template smb.conf.
- `artifacts/scripts/validate_ad_smb.sh`: Script de validação Linux-side.
- `artifacts/scripts/ad_precheck_fileserver.sh`: Wrapper para automação AD.
- `artifacts/docs/windows_validate_multichannel.md`: Validação SMB multichannel.
- `artifacts/installer/vdev_planner_spec.json`: Especificação do planner de vdev.
- `.editorconfig`: Padronização de formato.
- `.pre-commit-config.yaml`: Hooks pre-commit.
- `PSScriptAnalyzerSettings.psd1`: Config PSScriptAnalyzer.
- `.github/workflows/pr-labeler.yml`: Workflow para labels em PR.
- `justfile`: Comandos padronizados.
- `docs/ROADMAP.md`: Roadmap com fases e critérios de aceite.
- `labels/labels.json`: Labels do repositório.

## Seu Papel

Como agente LLM responsável, sua tarefa é implementar e melhorar o projeto seguindo as melhores práticas. Use os arquivos acima como fonte primária de contexto. Se algo não estiver claro, consulte `docs/00_SOURCE_OF_TRUTH.md` primeiro.

## Instruções Iniciais

1. Leia `docs/00_SOURCE_OF_TRUTH.md` para entender a arquitetura.
2. Verifique se todos os arquivos listados existem e estão atualizados.
3. Implemente melhorias seguindo o roadmap em `docs/ROADMAP.md`.
4. Mantenha qualidade de código com linting e testes.
5. Documente todas as mudanças nos arquivos apropriados.

Comece lendo `docs/00_SOURCE_OF_TRUTH.md` e proponha os próximos passos.
