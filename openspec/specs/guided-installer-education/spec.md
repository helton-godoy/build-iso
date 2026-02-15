## ADDED Requirements

### Requirement: Orientacao contextual por etapa
O instalador SHALL exibir, em cada etapa de decisao, uma orientacao curta contendo objetivo da etapa, impacto da escolha e recomendacao padrao para uso corporativo.

#### Scenario: Exibicao obrigatoria de orientacao
- **WHEN** o usuario entrar em qualquer etapa interativa do assistente
- **THEN** a interface deve renderizar um bloco de orientacao com texto didatico antes do controle de entrada

### Requirement: Linguagem adequada para perfil junior
O texto de interface MUST usar linguagem clara, sem jargao nao explicado, e incluir exemplos praticos para opcoes com maior risco operacional.

#### Scenario: Explicacao de opcao avancada
- **WHEN** uma opcao avancada de ZFS for apresentada
- **THEN** o instalador deve mostrar uma descricao simples, um exemplo de uso e um aviso de risco

### Requirement: Resumo pedagogico antes da execucao
Antes da etapa destrutiva, o instalador SHALL apresentar um resumo consolidado em formato legivel por iniciantes, incluindo o que sera alterado e o que nao sera alterado.

#### Scenario: Confirmacao com contexto completo
- **WHEN** o usuario acessar a tela de confirmacao final
- **THEN** o instalador deve exibir um resumo com escolhas principais, impacto esperado e token de confirmacao proporcional ao risco
