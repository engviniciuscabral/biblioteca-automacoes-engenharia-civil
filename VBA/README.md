# VBA — Catálogo de automações

Macros VBA para automatizar operações e cálculos em planilhas do Microsoft Excel.

[← Voltar ao catálogo geral](../README.md)

## Índice de rotinas

| Arquivo | Comando / entrada | Finalidade |
|---|---|---|
| [`Macro Automação Perfis.txt`](./Macro%20Automa%C3%A7%C3%A3o%20Perfis.txt) | `GerarFormulaECalcular` | Cálculo automatizado de uma fórmula em planilha de perfis. |
| [`Macro Lista de Abas Automática Excel.txt`](./Macro%20Lista%20de%20Abas%20Autom%C3%A1tica%20Excel.txt) | `ListarAbasOndeEuClicar` | Listagem automática dos nomes das abas de uma pasta de trabalho Excel. |

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

### 2. Macro Lista de Abas Automática Excel.txt

**Arquivo:** [`Macro Lista de Abas Automática Excel.txt`](./Macro%20Lista%20de%20Abas%20Autom%C3%A1tica%20Excel.txt)  
**Comando / entrada:** `ListarAbasOndeEuClicar`  
**Objetivo:** Listagem automática dos nomes das abas de uma pasta de trabalho Excel.

**Funcionamento:** Percorre `Sheets` e escreve o nome de cada aba, em linhas sucessivas, começando na célula ativa.

**Como utilizar:** Insira o código em um módulo VBA, selecione a célula inicial e execute `ListarAbasOndeEuClicar`.

**Requisitos e dependências:** Microsoft Excel com VBA.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** Sobrescreve células abaixo da posição selecionada. Como usa `Sheets` e `Cells` sem qualificação explícita de pasta/planilha, confirme a pasta de trabalho e a aba ativas.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada pela leitura dos arquivos do repositório. Compatibilidade e resultados devem ser validados na versão de software utilizada.
