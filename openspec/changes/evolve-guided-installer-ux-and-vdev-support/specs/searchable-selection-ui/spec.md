## ADDED Requirements

### Requirement: Selecao com filtro para listas extensas
O instalador SHALL oferecer selecao com busca/filtro para listas extensas (locale, teclado, timezone, discos e perfis), mantendo navegacao completa por teclado em TTY.

#### Scenario: Filtragem de locale
- **WHEN** o usuario digitar um termo no campo de busca da lista de locale
- **THEN** a interface deve reduzir os resultados em tempo real e permitir confirmacao por Enter

### Requirement: Fallback seguro para ambiente limitado
O instalador MUST fornecer fallback para selecao simples quando o recurso de filtro nao estiver disponivel no ambiente de execucao.

#### Scenario: Fallback automatico
- **WHEN** o componente de filtro nao puder ser inicializado
- **THEN** o instalador deve usar seletor alternativo e informar ao usuario que o modo reduzido foi ativado

### Requirement: Consistencia visual do design system
Todos os componentes de selecao com filtro SHALL respeitar a paleta e os estados visuais definidos no design system do projeto.

#### Scenario: Renderizacao consistente
- **WHEN** uma lista com filtro for exibida
- **THEN** cursor, item selecionado, destaque de correspondencia e mensagens de ajuda devem seguir o tema visual do instalador
