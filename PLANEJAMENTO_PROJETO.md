# Projeto — Evolução da Biblioteca de Automações

Planejamento de melhorias para as rotinas AutoLISP, Dynamo, Python, QGIS e VBA. Baseado nos arquivos e READMEs do repositório em 22/10/2026. **Este documento é o template e backlog; não é um quadro nativo do GitHub Projects.** A criação do quadro na aba Projects deve ser feita pela interface do GitHub.

## Template recomendado: Roadmap em tabela (Table)

Use o template **Table** do GitHub Projects, com uma visão de portfólio de melhorias, em vez de Kanban. Cada linha representa uma Issue, permitindo ordenar por prioridade e agrupar por ciclo de execução.

**Campos sugeridos para o Project:**
- **Status** (Single select): `Não iniciado`, `Em análise`, `Em execução`, `Em validação`, `Concluído`.
- **Prioridade** (Single select): `P0 - Crítica`, `P1 - Alta`, `P2 - Planejada`.
- **Área** (Single select): `AutoLISP`, `Dynamo`, `Python`, `QGIS`, `VBA`, `Infraestrutura`.
- **Tipo** (Single select): `Correção`, `Melhoria`, `Nova funcionalidade`, `Validação técnica`.
- **Ciclo** (Single select): `1 - Confiabilidade`, `2 - Robustez`, `3 - Expansão`.
- **Esforço** (Single select): `P`, `M`, `G`.
- **Responsável** (Assignees).

**Visões recomendadas:** `Roadmap geral` (Table, agrupada por Ciclo, ordenada por Prioridade); `Prioridades críticas` (Table, filtro P0); `Por tecnologia` (Table, agrupada por Área). Se desejar prazos, crie um campo Date e uma visualização Roadmap adicional, sem inventar datas antecipadamente.

**Importante:** este arquivo registra o modelo e os links das Issues; não cria automaticamente um Project nativo na aba Projects.

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

## Como montar o projeto nativo em tabela

1. Abra a aba **Projects** do repositório (ou o Projects do perfil pessoal, se a interface exigir) e escolha **New project**.
2. Selecione **Table** (tabela) em vez de Board/Kanban; dê o nome `Evolução da Biblioteca de Automações`.
3. Configure os campos **Status, Prioridade, Área, Tipo, Ciclo e Esforço** conforme as definições acima.
4. Adicione as Issues **#4 a #14** pelo comando **Add item**, mantendo a Issue #4 existente.
5. Crie as visualizações **Roadmap geral**, **Prioridades críticas** e **Por tecnologia**. Agrupe o roadmap por Ciclo e ordene por Prioridade.
6. Inicialmente marque todas como `Não iniciado`. Ao começar o trabalho, mova o Status conforme o progresso.

> As Issues são sugestões de trabalho; não significam defeitos confirmados ou funcionalidades já implementadas. Valide resultados técnicos no software de engenharia correspondente.
