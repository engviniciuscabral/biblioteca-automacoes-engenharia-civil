# Projeto — Evolução da Biblioteca de Automações

Planejamento de melhorias para as rotinas AutoLISP, Dynamo, Python, QGIS e VBA. Baseado nos arquivos e READMEs do repositório em 22/10/2026. **Este documento é o template e backlog; não é um quadro nativo do GitHub Projects.** A criação do quadro na aba Projects deve ser feita pela interface do GitHub.

## Template recomendado: Team planning / Kanban

Criar um **GitHub Project** com visualização principal **Board (Kanban)** e visualização secundária **Table**.

**Colunas do Board (campo Status):**
1. **Backlog** — ideias registradas e ainda não priorizadas para execução
2. **Pronto para desenvolver** — escopo e critérios de aceite definidos
3. **Em desenvolvimento** — trabalho em branch ou análise ativa
4. **Em validação** — revisão de código, testes e conferência de resultados no software
5. **Concluído** — PR integrada, documentação e evidências de teste disponíveis

**Campos sugeridos:**
- **Priority** (Single select): `P0 - Crítica`, `P1 - Alta`, `P2 - Planejada`
- **Área** (Single select): `AutoLISP`, `Dynamo`, `Python`, `QGIS`, `VBA`, `Infraestrutura`
- **Tipo** (Single select): `Correção`, `Melhoria`, `Nova funcionalidade`, `Validação técnica`, `Documentação`
- **Versão alvo** (Text): versão/arquivo a alterar
- **Responsável** (Assignees, quando houver)
- **Esforço** (Single select): `P`, `M`, `G`

**Visualizações sugeridas:** Board agrupado por Status, ordenado por Priority; Table com todas as Issues; filtro por Área para revisar uma linguagem por vez. Limitar a duas Issues simultaneamente em `Em desenvolvimento`.

## Backlog inicial

| Prioridade | Área | Issue | Resultado esperado |
|---|---|---|---|
| P0 | AutoLISP | [#5 — COTAS_TALVEGUES](../../issues/5) | Corrigir comparação de cotas e validar exportação |
| P0 | Dynamo | [#6 — Valetas V48](../../issues/6) | Testes de continuidade, saídas e dissipadores |
| P0 | Python | [#7 — HUT GOINFRA](../../issues/7) | Validação numérica independente |
| P1 | AutoLISP | [#8 — BUEIROS_PERFIL](../../issues/8) | Reexecução sem duplicar objetos |
| P1 | Dynamo | [#9 — Identificador de Queda](../../issues/9) | Preservar campo Material das estruturas |
| P1 | AutoLISP | [#10 — CSV de drenagem](../../issues/10) | Importação com validação e diagnósticos |
| P1 | Infraestrutura | [#11 — GitHub Actions](../../issues/11) | Checagens estáticas em pull requests |
| P2 | Python | [#12 — HUT ampliado](../../issues/12) | Novos domínios e exportação de resultados |
| P2 | QGIS | [#13 — LocalizadorRodovia](../../issues/13) | Ferramenta reutilizável e saída GeoPackage |
| P2 | VBA | [#14 — Listagem de abas BC](../../issues/14) | Evitar sobrescrita e consolidar macros |
| A definir | AutoLISP | [#4 — Melhoria lisp bocas bueiros](../../issues/4) | Revisar a Issue existente, evitando duplicação |

## Ordem sugerida de execução

**Ciclo 1 — Confiabilidade técnica:** #5, #6 e #7. São rotinas que produzem ou modificam dados de engenharia, portanto exigem testes e conferência de resultados antes de ampliar funcionalidades.

**Ciclo 2 — Robustez e segurança dos dados:** #8, #9, #10 e #11. Reduzir duplicação, preservar propriedades originais e automatizar validações simples.

**Ciclo 3 — Expansão:** #12, #13, #14 e avaliação da #4. Desenvolver novas funcionalidades após estabilizar as rotinas principais.

## Critério de conclusão de cada Issue

- [ ] Escopo e comportamento esperado documentados.
- [ ] Alteração feita em branch própria e revisada em pull request.
- [ ] Evidências de testes registradas; para Civil 3D/AutoCAD/QGIS/Excel, testar no software correspondente.
- [ ] Casos limites, unidades e dados de entrada conferidos.
- [ ] README da pasta e README principal atualizados, quando necessário.
- [ ] Nenhum dado confidencial ou DWG real de cliente incluído nos testes.

## Como montar o quadro nativo na aba Projects

1. Abra a aba **Projects** do repositório e escolha **New project**, quando disponível. Dependendo das permissões e do contexto da conta, talvez seja necessário criar o Project no perfil do usuário e depois vinculá-lo ao repositório.
2. Escolha o modelo **Team planning** ou um quadro **Board** em branco.
3. Crie ou adapte os campos e Status descritos acima.
4. Use **Add item** para localizar e adicionar as Issues #4 a #14 deste repositório.
5. Deixe todas inicialmente em **Backlog**; mova #5, #6 e #7 para **Pronto para desenvolver** quando decidir iniciar o primeiro ciclo.
6. Configure a visualização **Table** e salve filtros por Área/Prioridade.

> Observação: sugestões de melhorias e novos recursos são propostas de trabalho, não defeitos comprovados nem funcionalidades já implementadas. O código e a documentação podem evoluir; revise o escopo de cada Issue antes de desenvolver.
