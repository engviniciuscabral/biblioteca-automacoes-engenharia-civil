# Dynamo — Catálogo de automações

Grafos Dynamo associados a fluxos de trabalho do AutoCAD Civil 3D.

[← Voltar ao catálogo geral](../README.md)

## Índice de rotinas

| Arquivo | Comando / entrada | Finalidade |
|---|---|---|
| [`Dynamo Identificador de Queda(att).dyn`](./Dynamo%20Identificador%20de%20Queda(att).dyn) | `Grafo Dynamo` | Identificação e registro de quedas em estruturas de redes de drenagem. |
| [`Fluxo Dynamo Desap.dyn`](./Fluxo%20Dynamo%20Desap.dyn) | `Grafo Dynamo` | Automação de pontos ao longo de alinhamentos para fluxo de desapropriação. |

## Documentação das rotinas

### 1. Dynamo Identificador de Queda(att).dyn

**Arquivo:** [`Dynamo Identificador de Queda(att).dyn`](./Dynamo%20Identificador%20de%20Queda(att).dyn)  
**Comando / entrada:** `Grafo Dynamo`  
**Objetivo:** Identificação e registro de quedas em estruturas de redes de drenagem.

**Funcionamento:** Recebe o nome de uma rede, percorre estruturas e tubos conectados no Civil 3D, calcula a diferença entre cotas de fundo de entrada e saída quando há exatamente uma de cada e grava `QUEDA: ...m` no campo de material da estrutura; também retorna um relatório.

**Como utilizar:** Abra o desenho no Civil 3D e o grafo no Dynamo, configure o nome da rede na entrada de texto e execute manualmente após validar o modelo.

**Requisitos e dependências:** Civil 3D, Dynamo e APIs AutoCAD/Civil 3D utilizadas pelo nó Python.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** **Modifica dados das estruturas do desenho.** Em estruturas sem uma entrada e uma saída, o código tenta limpar o campo de material. Faça backup e teste em cópia antes de executar.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 2. Fluxo Dynamo Desap.dyn

**Arquivo:** [`Fluxo Dynamo Desap.dyn`](./Fluxo%20Dynamo%20Desap.dyn)  
**Comando / entrada:** `Grafo Dynamo`  
**Objetivo:** Automação de pontos ao longo de alinhamentos para fluxo de desapropriação.

**Funcionamento:** O grafo contém nós de alinhamento/estaqueamento e scripts Python que filtram estações intermediárias redundantes, calculam coordenadas ao longo do alinhamento e preparam pontos, nomes e descrições. O fluxo completo depende das conexões e configurações dos nós.

**Como utilizar:** Abra no Dynamo integrado ao Civil 3D; revise entradas, seleção do alinhamento, intervalos e saídas antes de executar. Confira os pontos gerados no desenho de teste.

**Requisitos e dependências:** Civil 3D e Dynamo com os nós e bibliotecas utilizados pelo grafo.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** Grafo extenso, com múltiplos nós; o comportamento completo não foi validado por execução. Confira parâmetros e eventuais operações de criação/alteração de objetos antes de rodar em projeto real.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada pela leitura dos arquivos do repositório. Compatibilidade e resultados devem ser validados na versão de software utilizada.
