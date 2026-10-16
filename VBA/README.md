# VBA — Catálogo de automações

Macros VBA para automatizar operações e cálculos em planilhas do Microsoft Excel.

[← Voltar ao catálogo geral](../README.md)

## Índice de rotinas

| Arquivo | Comando / entrada | Finalidade |
|---|---|---|
| [`Macro Automação Perfis.txt`](./Macro%20Automa%C3%A7%C3%A3o%20Perfis.txt) | `GerarFormulaECalcular` | Cálculo automatizado de uma fórmula em planilha de perfis. |
| [`Macro Lista de Abas Automática Excel.txt`](./Macro%20Lista%20de%20Abas%20Autom%C3%A1tica%20Excel.txt) | `ListarAbasOndeEuClicar` | Versão legada: lista todas as abas do Excel. |
| [`ListarAbasOndeEuClicar.bas`](./ListarAbasOndeEuClicar.bas) | `ListarAbasOndeEuClicar` | Versão atual: lista somente planilhas BC. |

## Documentação das rotinas

### 1. Macro Automação Perfis.txt

**Arquivo:** [`Macro Automação Perfis.txt`](./Macro%20Automa%C3%A7%C3%A3o%20Perfis.txt)  
**Comando / entrada:** `GerarFormulaECalcular`  
**Objetivo:** Cálculo automatizado de uma fórmula em planilha de perfis.

**Funcionamento:** Na planilha ativa, identifica a última linha preenchida na coluna G, constrói uma expressão com G e H desde a linha 4, utiliza o valor de E na última linha e escreve os resultados em K4 (m/km), K5 (m/m) e K6 (%).

**Como utilizar:** Abra o editor VBA do Excel (`Alt+F11`), insira o código em um módulo e execute `GerarFormulaECalcular` com a planilha de entrada ativa.

**Requisitos e dependências:** Microsoft Excel com VBA; fórmulas locais em português (`RAIZ`).

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** Pressupõe dados a partir da linha 4, valores válidos em G/H e E na última linha. Sobrescreve K4:K6; confira a fórmula e a unidade antes de usar em cálculos de projeto.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 2. Macro Lista de Abas Automática Excel.txt (legada)

**Arquivo:** [`Macro Lista de Abas Automática Excel.txt`](./Macro%20Lista%20de%20Abas%20Autom%C3%A1tica%20Excel.txt)  
**Comando / entrada:** `ListarAbasOndeEuClicar`  
**Objetivo:** Listagem automática de todas as abas de uma pasta de trabalho Excel (versão legada).

**Funcionamento:** Percorre `Sheets` e escreve o nome de cada aba, em linhas sucessivas, começando na célula ativa.

**Como utilizar:** Insira o código em um módulo VBA, selecione a célula inicial e execute `ListarAbasOndeEuClicar`.

**Requisitos e dependências:** Microsoft Excel com VBA.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** Sobrescreve células abaixo da posição selecionada. Como usa `Sheets` e `Cells` sem qualificação explícita de pasta/planilha, confirme a pasta de trabalho e a aba ativas.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 3. ListarAbasOndeEuClicar.bas (versão atual)

**Arquivo:** [`ListarAbasOndeEuClicar.bas`](./ListarAbasOndeEuClicar.bas)  
**Comando / entrada:** `ListarAbasOndeEuClicar`  
**Objetivo:** Listar apenas as planilhas cujo nome começa por `BC` seguido de um dígito, a partir da célula selecionada.

**Funcionamento:** Percorre `Worksheets` da mesma pasta de trabalho da planilha ativa usando `For Each`. A condição `UCase(ws.Name) Like "BC[0-9]*"` aceita nomes como `BC01 (RAC)`, `BC02 (RAC-MOD)` e `BC1`, independentemente de maiúsculas/minúsculas. O complemento entre parênteses não é analisado. Nomes como `PERFIL BC01` não passam no filtro. Os nomes completos são escritos em linhas consecutivas, respeitando a ordem das abas.

**Como utilizar:**
1. Abra o arquivo Excel e pressione `Alt+F11`.
2. No editor VBA, use **File → Import File** e selecione o arquivo `.bas`. Evite importar outro módulo com o mesmo nome sem antes verificar o projeto.
3. Volte ao Excel, selecione a célula inicial de saída e execute `ListarAbasOndeEuClicar` em **Alt+F8**.

**Requisitos e dependências:** Microsoft Excel com suporte a VBA. Para conservar a macro no arquivo Excel, salve-o em formato habilitado para macros (por exemplo, `.xlsm`).

**Status:** Versão testada no Excel pelo autor e informada como funcional; esta revisão da documentação não realizou novo teste de execução.

**Limitações e cuidados:** Sobrescreve as células de destino, inclusive em linhas ocultas; não limpa automaticamente nomes antigos que excedam a nova listagem. O padrão exige somente um dígito imediatamente após `BC`, portanto não valida um número fixo de dígitos nem a presença de parênteses. O nome da planilha de destino também será incluído caso satisfaça o filtro. Use uma área livre para executar a macro.

**Histórico:** O primeiro commit registrou a macro que listava todas as abas. O commit seguinte introduziu o filtro BC e referências explícitas à planilha de destino. O histórico de commits do GitHub permite comparar as versões.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada pela leitura dos arquivos do repositório. Compatibilidade e resultados devem ser validados na versão de software utilizada.
