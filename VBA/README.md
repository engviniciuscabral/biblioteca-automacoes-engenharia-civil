# Rotinas VBA — Microsoft Excel

Macros armazenadas como texto para consulta e inserção em módulos VBA do Excel.

## Índice

1. [Macro Automação Perfis.txt](#macro-automação-perfistxt)
2. [Macro Lista de Abas Automática Excel.txt](#macro-lista-de-abas-automática-exceltxt)

## Macro Automação Perfis.txt

**Nome da macro:** `GerarFormulaECalcular`  
**Software:** Microsoft Excel  
**Linguagem:** VBA  
**Objetivo:** Gerar uma fórmula a partir dos dados de uma planilha e apresentar o resultado em diferentes unidades.

**Funcionamento:** identifica a última linha preenchida da **coluna G**; da linha 4 até essa linha, monta a soma `G_i/RAIZ(H_i)`. Utiliza o valor da coluna **E na última linha** para calcular `((E_ultima / soma)^2)/1000`. Preenche **K4** com o resultado multiplicado por 1000, **K5** com o valor-base e **K6** com o resultado multiplicado por 100, aplicando formatos numéricos de 3, 4 e 2 casas decimais, respectivamente.

**Como utilizar:** no Excel, organize os dados nas colunas **E, G e H** a partir da linha 4; pressione `Alt+F11`; insira um módulo e cole o conteúdo de [Macro Automação Perfis.txt](Macro%20Automa%C3%A7%C3%A3o%20Perfis.txt); volte ao Excel e execute `GerarFormulaECalcular` com a planilha correta ativa.

**Dependências:** Excel com macros VBA habilitadas e funções locais em português (o código usa `FormulaLocal` e `RAIZ`).

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** depende de uma **estrutura fixa de células**; sobrescreve `K4:K6`; exige valores numéricos válidos e `H_i > 0`, além de denominador não nulo. A interpretação física do resultado deve ser confirmada conforme o método de cálculo adotado. Execute em cópia da planilha.

## Macro Lista de Abas Automática Excel.txt

**Nome da macro:** `ListarAbasOndeEuClicar`  
**Software:** Microsoft Excel  
**Linguagem:** VBA  
**Objetivo:** Listar os nomes das abas da pasta de trabalho em uma coluna a partir da célula selecionada.

**Funcionamento:** lê a linha e a coluna da célula ativa; percorre `Sheets(1)` até `Sheets(Sheets.Count)` e escreve o nome de cada aba nas linhas consecutivas da coluna selecionada.

**Como utilizar:** abra o editor VBA (`Alt+F11`), insira um módulo e cole [Macro Lista de Abas Automática Excel.txt](Macro%20Lista%20de%20Abas%20Autom%C3%A1tica%20Excel.txt); selecione a célula inicial na planilha de destino; execute `ListarAbasOndeEuClicar`.

**Dependências:** Excel com VBA habilitado.

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** **sobrescreve células** a partir da posição ativa, uma por aba. O código usa `Sheets` e `Cells` sem qualificar explicitamente a pasta de trabalho/planilha; confira o arquivo e a aba ativos antes de executar. A lista pode incluir abas de gráfico.

---

[Voltar ao catálogo geral](../README.md)
