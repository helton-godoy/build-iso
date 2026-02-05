# Fluxo de Trabalho do Projeto

## Princípios Orientadores

1. **O Plano é a Fonte da Verdade:** Todo o trabalho deve ser registrado em `plan.md`
2. **A Pilha de Tecnologias é Deliberada:** Alterações na pilha de tecnologias devem ser documentadas em `tech-stack.md` _antes_ da implementação
3. **Desenvolvimento Orientado a Testes (TDD):** Escreva testes unitários antes de implementar a funcionalidade
4. **Alta Cobertura de Código:** Busque uma cobertura de código superior a 80% para todos os módulos
5. **Experiência do Usuário em Primeiro Lugar:** Toda decisão deve priorizar a experiência do usuário
6. **Não Interativo e Compatível com CI:** Prefira comandos não interativos. Use `CI=true` para ferramentas de modo de observação (testes, linters) para garantir a execução única.

## Fluxo de Trabalho da Tarefa

Todas as tarefas seguem um ciclo de vida estrito:

### Fluxo de Trabalho Padrão da Tarefa

1. **Selecionar Tarefa:** Escolha a próxima tarefa disponível em `plan.md` em ordem sequencial.

2. **Marcar como Em Andamento:** Antes de começar a trabalhar, edite `plan.md` e altere a tarefa de `[ ]` para `[~]`.

3. **Escrever Testes com Falha (Fase Vermelha):**
   - Crie um novo arquivo de teste para o recurso ou correção de bug.
   - Escreva um ou mais testes unitários que definam claramente o comportamento esperado e os critérios de aceitação para a tarefa.
   - **CRÍTICO:** Execute os testes e confirme que eles falham conforme o esperado. Esta é a fase "Vermelha" do TDD. Não prossiga até que você tenha testes com falha.

4. **Implementar para Aprovar os Testes (Fase Verde):**
   - Escreva a quantidade mínima de código do aplicativo necessária para que os testes com falha sejam aprovados.
   - Execute o conjunto de testes novamente e confirme que todos os testes agora são aprovados. Esta é a fase "Verde".

5. **Refatoração (Opcional, mas Recomendada):**
   - Com a segurança de que os testes passaram, refatore o código de implementação e o código de teste para melhorar a clareza, remover duplicação e aprimorar o desempenho sem alterar o comportamento externo.
   - Execute os testes novamente para garantir que ainda passem após a refatoração.

6. **Verificar Cobertura:** Execute relatórios de cobertura usando as ferramentas escolhidas para o projeto. Por exemplo, em um projeto Python, isso pode ser feito da seguinte forma:

   ```bash
   pytest --cov=app --cov-report=html
   ```

   Meta: >80% de cobertura para o novo código. As ferramentas e comandos específicos variam de acordo com a linguagem e o framework.

7. **Documentar Desvios:** Se a implementação for diferente da pilha de tecnologias:
   - **PARE** a implementação
   - Atualize o arquivo `tech-stack.md` com o novo design
   - Adicione uma nota com a data explicando a alteração
   - Retome a implementação

8. **Confirmar Alterações de Código:**
   - Adicione todas as alterações de código relacionadas à tarefa à área de preparação. - Proponha uma mensagem de commit clara e concisa, por exemplo, `feat(ui): Criar estrutura HTML básica para a calculadora`.
   - Execute o commit.

9. **Anexar Resumo da Tarefa com Notas do Git:**

   - **Etapa 9.1: Obter Hash do Commit:** Obtenha o hash do commit recém-concluído (`git log -1 --format="%H"`).
   - **Etapa 9.2: Esboçar Conteúdo da Nota:** Crie um resumo detalhado para a tarefa concluída. Isso deve incluir o nome da tarefa, um resumo das alterações, uma lista de todos os arquivos criados/modificados e o principal motivo da alteração.
   - **Etapa 9.3: Anexar Nota:** Use o comando `git notes` para anexar o resumo ao commit.

      ```bash
      # O conteúdo da nota da etapa anterior é passado através da flag -m.
      git notes add -m "<conteúdo da nota>" <hash_do_commit>
      ```

10. **Obter e Registrar o SHA do Commit da Tarefa:**

- **Etapa 10.1: Atualizar o Plano:** Leia o arquivo `plan.md`, encontre a linha da tarefa concluída, atualize seu status de `[~]` para `[x]` e anexe os primeiros 7 caracteres do hash do commit _recém-concluído_.
- **Etapa 10.2: Gravar o Plano:** Grave o conteúdo atualizado de volta no arquivo `plan.md`.

1. **Atualização do Plano de Commit:**

- **Ação:** Preparar o arquivo `plan.md` modificado.
- **Ação:** Confirmar esta alteração com uma mensagem descritiva (por exemplo, `conductor(plan): Marcar tarefa 'Criar modelo de usuário' como concluída`).

### Protocolo de Verificação e Ponto de Controle de Conclusão de Fase

**Gatilho:** Este protocolo é executado imediatamente após a conclusão de uma tarefa que também conclui uma fase em `plan.md`.

1. **Anunciar Início do Protocolo:** Informar o usuário de que a fase foi concluída e que o protocolo de verificação e ponto de controle foi iniciado.

2. **Garantir Cobertura de Teste para Alterações de Fase:**
   - **Etapa 2.1: Determinar o Escopo da Fase:** Para identificar os arquivos alterados nesta fase, você deve primeiro encontrar o ponto de partida. Leia `plan.md` para encontrar o SHA do commit Git do ponto de controle da fase _anterior_. Se não houver um ponto de verificação anterior, o escopo abrange todas as alterações desde o primeiro commit.
   - **Etapa 2.2: Listar Arquivos Alterados:** Execute `git diff --name-only <previous_checkpoint_sha> HEAD` para obter uma lista precisa de todos os arquivos modificados durante esta fase.
   - **Etapa 2.3: Verificar e Criar Testes:** Para cada arquivo na lista:
      - **CRÍTICO:** Primeiro, verifique a extensão. Exclua arquivos que não sejam de código (por exemplo, `.json`, `.md`, `.yaml`).
      - Para cada arquivo de código restante, verifique se existe um arquivo de teste correspondente.
      - Se um arquivo de teste estiver faltando, você **deve** criar um. Antes de escrever o teste, **primeiro, analise outros arquivos de teste no repositório para determinar a convenção de nomenclatura e o estilo de teste corretos.** Os novos testes **devem** validar a funcionalidade descrita nas tarefas desta fase (`plan.md`).

3. **Execute testes automatizados com depuração proativa:**
   - Antes da execução, você **deve** anunciar o comando exato do shell que usará para executar os testes.
   - **Exemplo de anúncio:** "Executarei agora o conjunto de testes automatizados para verificar a fase. **Comando:** `CI=true npm test`"
   - Execute o comando anunciado.
   - Se os testes falharem, você **deve** informar o usuário e iniciar a depuração. Você pode tentar propor uma correção **no máximo duas vezes**. Se os testes ainda falharem após a segunda correção proposta, você **deve parar**, relatar a falha persistente e pedir orientação ao usuário.

4. **Proponha um plano de verificação manual detalhado e acionável:**
   - **CRÍTICO:** Para gerar o plano, primeiro analise `product.md`, `product-guidelines.md` e `plan.md` para determinar os objetivos da fase concluída voltados para o usuário.
   - Você **deve** gerar um plano passo a passo que oriente o usuário durante o processo de verificação, incluindo todos os comandos necessários e os resultados específicos esperados.
   - O plano apresentado ao usuário **deve** seguir este formato:

      **Para uma alteração no Frontend:**

      ```markdown
      Os testes automatizados foram aprovados. Para verificação manual, siga estas etapas:

      **Etapas de verificação manual:**
      1. **Inicie o servidor de desenvolvimento com o comando:** `npm run dev`
      2. **Abra seu navegador em:** `http://localhost:3000`
      3. **Confirme se você vê:** A nova página de perfil do usuário, com o nome e o e-mail do usuário exibidos corretamente.
      ```

      **Para uma alteração no Backend:**

      ```markdown
      Os testes automatizados foram aprovados. Para verificação manual, siga estes passos:

      **Passos para Verificação Manual:**
      1. **Certifique-se de que o servidor esteja em execução.**
      2. **Execute o seguinte comando no seu terminal:** `curl -X POST http://localhost:8080/api/v1/users -d '{"name": "test"}'`
      3. **Confirme se você recebeu:** Uma resposta JSON com o status `201 Created`.
      ```

5. **Aguarde o Feedback Explícito do Usuário:**
   - Após apresentar o plano detalhado, peça a confirmação do usuário: "**Isso atende às suas expectativas? Por favor, confirme com "sim" ou forneça feedback sobre o que precisa ser alterado.**"
   - **PAUSE** e aguarde a resposta do usuário. Não prossiga sem um "sim" explícito ou confirmação.

6. **Crie um Commit de Ponto de Verificação:**
   - Prepare todas as alterações. Se nenhuma alteração ocorreu nesta etapa, prossiga com um commit vazio.
   - Realize o commit com uma mensagem clara e concisa (por exemplo, `conductor(checkpoint): Checkpoint end of Phase X`).

7. **Anexar Relatório de Verificação Auditável usando Git Notes:**
   - **Etapa 8.1: Esboçar Conteúdo da Nota:** Crie um relatório de verificação detalhado, incluindo o comando de teste automatizado, as etapas de verificação manual e a confirmação do usuário.
   - **Etapa 8.2: Anexar Nota:** Use o comando `git notes` e o hash completo do commit da etapa anterior para anexar o relatório completo ao commit do checkpoint.

8. **Obter e Registrar o SHA do Checkpoint da Fase:**
   - **Etapa 7.1: Obter Hash do Commit:** Obtenha o hash do commit do checkpoint recém-criado (`git log -1 --format="%H"`).
   - **Etapa 7.2: Atualizar Plano:** Leia o arquivo `plan.md`, encontre o cabeçalho da fase concluída e anexe os primeiros 7 caracteres do hash do commit no formato `[checkpoint: <sha>]`.
   - **Etapa 7.3: Gravar Plano:** Grave o conteúdo atualizado de volta no arquivo `plan.md`.

9. **Atualização do Plano de Commit:**
   - **Ação:** Preparar o arquivo `plan.md` modificado.
   - **Ação:** Confirmar esta alteração com uma mensagem descritiva no formato `conductor(plan): Marcar a fase '<NOME DA FASE>' como concluída`.

10. **Anunciar Conclusão:** Informar o usuário que a fase foi concluída e o ponto de verificação foi criado, com o relatório de verificação detalhado anexado como uma nota do Git.

### Critérios de Qualidade

Antes de marcar qualquer tarefa como concluída, verifique:

- [ ] Todos os testes foram aprovados
- [ ] A cobertura de código atende aos requisitos (>80%)
- [ ] O código segue as diretrizes de estilo de código do projeto (conforme definido em `code_styleguides/`)
- [ ] Todas as funções/métodos públicos estão documentados (por exemplo, docstrings, JSDoc, GoDoc)
- [ ] A segurança de tipos é aplicada (por exemplo, dicas de tipo, tipos TypeScript, tipos Go)
- [ ] Não há erros de linting ou análise estática (usando as ferramentas configuradas do projeto)
- [ ] Funciona corretamente em dispositivos móveis (se aplicável)
- [ ] A documentação foi atualizada, se necessário
- [ ] Nenhuma vulnerabilidade de segurança foi introduzida

## Comandos de Desenvolvimento

**INSTRUÇÕES PARA O AGENTE DE IA: Esta seção deve ser adaptada à linguagem, framework e ferramentas de build específicos do projeto.**

### Configuração

```bash

# Exemplo: Comandos para configurar Ambiente de desenvolvimento (ex.: instalar dependências, configurar banco de dados)
# Ex.: para um projeto Node.js: npm install
# Ex.: para um projeto Go: go mod tidy
```

### Desenvolvimento Diário

```bash
# Exemplo: Comandos para tarefas diárias comuns (ex.: iniciar servidor de desenvolvimento, executar testes, verificar erros de sintaxe, formatar)
# Ex.: para um projeto Node.js: npm run dev, npm test, npm run lint
# Ex.: para um projeto Go: go run main.go, go test ./..., go fmt ./...
```

### Antes de Confirmar

```bash
# Exemplo: Comandos para executar todas as verificações pré-commit (ex.: formatar, verificar erros de sintaxe, verificar tipos, executar testes)
# Ex.: para um projeto Node.js: npm run check
# Ex.: para um projeto Go: `make check (if a Makefile exists)`
```

## Requisitos de Teste

### Testes Unitários

- Cada módulo deve ter testes correspondentes.
- Utilize mecanismos apropriados de configuração/desmontagem de testes (por exemplo, fixtures, beforeEach/afterEach).
- Simule dependências externas.
- Teste casos de sucesso e falha.

### Testes de Integração

- Testar fluxos de usuário completos
- Verificar transações no banco de dados
- Testar autenticação e autorização
- Verificar envios de formulários

### Testes em Dispositivos Móveis

- Testar em iPhones reais, quando possível
- Usar as ferramentas de desenvolvedor do Safari
- Testar interações por toque
- Verificar layouts responsivos
- Verificar o desempenho em redes 3G/4G

## Processo de Revisão de Código

### Lista de Verificação para Autoavaliação

Antes de solicitar a revisão:

1. **Funcionalidade**
   - O recurso funciona conforme especificado
   - Casos extremos tratados
   - Mensagens de erro amigáveis ​​ao usuário

2. **Qualidade do Código**
   - Segue o guia de estilo
   - Princípio DRY aplicado
   - Nomes de variáveis/funções claros
   - Comentários apropriados

3. **Testes**
   - Testes unitários abrangentes
   - Testes de integração aprovados
   - Cobertura adequada (>80%)

4. **Segurança**
   - Sem segredos embutidos no código
   - Validação de entrada presente
   - Injeção de SQL prevenida
   - Proteção contra XSS implementada

5. **Desempenho**
   - Consultas ao banco de dados otimizadas
   - Imagens Otimizado
   - Cache implementado onde necessário

6. **Experiência Móvel**
   - Áreas de toque adequadas (44x44px)
   - Texto legível sem zoom
   - Desempenho aceitável em dispositivos móveis
   - Interações com sensação nativa

## Diretrizes de Commit

### Formato da Mensagem

```markdown
<tipo>(<escopo>): <descrição>

[corpo opcional]

[rodapé opcional]
```

### Tipos

- `feat`: Novo recurso
- `fix`: Correção de bug
- `docs`: Apenas documentação
- `style`: Formatação, pontos e vírgulas ausentes, etc.
- `refactor`: Alteração de código que não corrige um bug nem adiciona um recurso
- `test`: Adição de testes ausentes
- `chore`: Tarefas de manutenção

### Exemplos

```bash
git commit -m "feat(auth): Adicionar funcionalidade 'lembrar-me'"
git commit -m "fix(posts): Geração correta de resumo para posts curtos"
git commit -m "test(comments): Adicionar testes para limites de reação de emojis"
git commit -m "style(mobile): Melhorar os alvos de toque do botão"
```

## Definição de Concluído

Uma tarefa é concluída quando:

1. Todo o código foi implementado conforme a especificação
2. Os testes unitários foram escritos e aprovados
3. A cobertura de código atende aos requisitos do projeto
4. A documentação está completa (se aplicável)
5. O código passa em todas as verificações de linting e análise estática configuradas
6. Funciona perfeitamente em dispositivos móveis (se aplicável)
7. Notas de implementação adicionadas ao `plan.md`
8. Alterações foram confirmadas com a mensagem apropriada
9. ​​Uma nota do Git com o resumo da tarefa foi anexada ao commit

## Procedimentos de Emergência

### Bug Crítico em Produção

1. Criar branch de correção rápida a partir da branch principal
2. Escrever um teste que falhe para o bug
3. Implementar a correção mínima
4. Testar minuciosamente, incluindo em dispositivos móveis
5. Implantar imediatamente
6. Documentar no `plan.md`

### Perda de Dados

1. Interromper todas as operações de escrita
2. Restaurar a partir do backup mais recente
3. Verificar a integridade dos dados
4. Documentar Incidente
5. Atualizar procedimentos de backup

### Violação de segurança

1. Rotacionar todos os segredos imediatamente
2. Revisar os logs de acesso
3. Corrigir a vulnerabilidade
4. Notificar os usuários afetados (se houver)
5. Documentar e atualizar os procedimentos de segurança

## Fluxo de Trabalho de Implantação

### Lista de Verificação Pré-Implantação

- [ ] Todos os testes aprovados
- [ ] Cobertura > 80%
- [ ] Sem erros de linting
- [ ] Testes em dispositivos móveis concluídos
- [ ] Variáveis ​​de ambiente configuradas
- [ ] Migrações de banco de dados prontas
- [ ] Backup criado

### Etapas de Implantação

1. Mesclar branch de recurso com a branch principal
2. Marcar a versão com a tag de lançamento
3. Enviar para o serviço de implantação
4. Executar migrações de banco de dados
5. Verificar a implantação
6. Testar caminhos críticos
7. Monitorar erros

### Pós-Implantação

1. Monitorar análises
2. Verificar logs de erros
3. Coletar feedback do usuário
4. Planejar a próxima iteração

## Melhoria Contínua

- Revisar o fluxo de trabalho semanalmente
- Atualizar com base em pontos problemáticos
- Documentar lições aprendidas
- Otimizar para a satisfação do usuário
- Manter a simplicidade e a facilidade de manutenção
