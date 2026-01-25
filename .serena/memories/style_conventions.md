# Estilo e Convenções - Build-ISO

## Shell Script (Bash)

### Estrutura de Funções

```bash
# Função com comentário descritivo
function_name() {
    local var1="$1"
    local var2="$2"

    # Lógica da função
}
```

### Variáveis

- `readonly` para constantes globais
- `local` para variáveis de função
- Nomes em UPPERCASE para constantes (ex: `DOCKER_IMAGE`)
- Nomes em snake_case para variáveis locais

### Mensagens de Log

O projeto usa função customizada `print_message`:

```bash
print_message "INFO" "Mensagem informativa"
print_message "SUCCESS" "Operação concluída"
print_message "WARNING" "Aviso importante"
print_message "ERROR" "Erro crítico"
```

### Tratamento de Erros

```bash
set -e  # Sair em qualquer erro
error_exit "Mensagem de erro"  # Função helper
```

## Docker

### Dockerfile

- Multi-stage builds para otimização
- Labels MAINTAINER, DESCRIPTION, VERSION
- `DEBIAN_FRONTEND=noninteractive` para builds silenciosos
- Limpeza de cache apt após instalações

## Documentação

### Markdown

- Emojis para seções (✨, 🔧, 📦, etc.)
- Blocos de código com linguagem especificada
- Índice para documentos longos

## Commits (Git Semantic)

```
feat: nova funcionalidade
fix: correção de bug
docs: documentação
refactor: refatoração
chore: tarefas de manutenção
```
