# Dynamo — Catálogo de automações

Grafos Dynamo associados a fluxos de trabalho do AutoCAD Civil 3D.

[← Voltar ao catálogo geral](../README.md)

## Índice de rotinas

| Arquivo | Comando / entrada | Finalidade |
|---|---|---|
| [`Dynamo Identificador de Queda(att).dyn`](./Dynamo%20Identificador%20de%20Queda(att).dyn) | `Grafo Dynamo` | Identificação e registro de quedas em estruturas de redes de drenagem. |
| [`Fluxo Dynamo Desap.dyn`](./Fluxo%20Dynamo%20Desap.dyn) | `Grafo Dynamo` | Automação de pontos ao longo de alinhamentos para fluxo de desapropriação. |
| [`Criar_Valetas_Eixo_Saia_3m_V48.dyn`](./Criar_Valetas_Eixo_Saia_3m_V48.dyn) | `Grafo Dynamo` | Análise de drenagem lateral e geração de valetas de corte/aterro, saídas, dissipadores e relatórios CSV. |
| [`DUP_FAIXA.dyn`](./Faixa%20de%20Dominio/DUP_FAIXA.dyn) | `Grafo Dynamo` | COGO Points numerados (`Ponto N`) nos vértices dos alinhamentos da faixa de domínio, com labels perpendiculares. [Guia](./Faixa%20de%20Dominio/GUIA_DUP_FAIXA.md) |
| [`QAFAIXA.dll`](./Faixa%20de%20Dominio/QAFAIXA.dll) | `NETLOAD` → `QAFAIXA` | Memorial descritivo do perímetro da faixa de domínio (RTF/.doc) a partir de vários alinhamentos. [Guia](./Faixa%20de%20Dominio/GUIA_QAFAIXA.md) |

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

### 3. Criar_Valetas_Eixo_Saia_3m_V48.dyn

**Arquivo:** [`Criar_Valetas_Eixo_Saia_3m_V48.dyn`](./Criar_Valetas_Eixo_Saia_3m_V48.dyn)  
**Comando / entrada:** grafo Dynamo com nó Python (IronPython) e entradas configuráveis.  
**Objetivo:** analisar o escoamento superficial nas laterais de uma rodovia e identificar, desenhar e documentar valetas de corte e aterro ao longo de um alinhamento do Civil 3D.

**Funcionamento:** o nó Python consulta um alinhamento e uma superfície do Civil 3D, lê um CSV de taludes e amostra o terreno em distâncias laterais configuradas. Avalia caimentos e condições de corte/aterro, agrupa trechos compatíveis, procura continuidade hidráulica e desenha polilinhas de valetas, saídas e dissipadores. O código inclui tolerâncias para unir pacotes próximos, evitar dissipadores quando a saída alcança outra valeta do mesmo lado, e gerar setas de caimento. Produz CSVs de análise, lista de valetas, base para planilha e diagnóstico dos pacotes, além de arquivo de status. Há modo de **somente nota de serviço**, que lê valetas existentes sem apagá-las ou redesenhá-las.

**Entradas do nó Python:** `IN[0]` nome do alinhamento; `IN[1]` nome da superfície; `IN[2]` caminho completo do CSV de taludes; `IN[3..7]` distâncias laterais de análise; `IN[8]` declividade mínima em direção à pista (%); `IN[9]` altura mínima para caracterizar corte (m); `IN[10]` intervalo máximo para unir pontos (m); `IN[11]` comprimento mínimo do trecho (m); `IN[12]` afastamento adicional além do encontro do talude (m); `IN[13]` tolerância de ruído vertical (m); `IN[14]` comprimento máximo de ruído pontual a absorver (m); `IN[15]` opção de somente nota de serviço (`True`).

**Como utilizar:** abra uma cópia do DWG no Civil 3D; carregue o grafo no Dynamo; substitua os nomes de alinhamento e superfície de exemplo pelos do projeto; informe um caminho válido para o CSV de taludes; revise as distâncias, tolerâncias e a opção de nota de serviço. Execute manualmente e confira a geometria criada e os relatórios antes de utilizar os resultados em projeto.

**Requisitos e dependências:** AutoCAD Civil 3D com Dynamo e nó Python compatível com IronPython e as bibliotecas .NET `AcMgd`, `AcDbMgd` e `AeccDbMgd`. O cabeçalho do script indica Civil 3D 2021 / Dynamo 2.5. Requer alinhamento, superfície e CSV com estrutura esperada pelo script.

**Status:** versão V48 incluída na biblioteca em 21/10/2026; estrutura JSON e código analisados, sem teste de execução no Civil 3D.

**Limitações e cuidados:** no modo normal, **cria e pode substituir polilinhas existentes no DWG**. Use uma cópia do projeto, confira layers, sentidos de escoamento, ligações entre valetas e dissipadores. A validação hidráulica, a capacidade de vazão e o dimensionamento das seções não são substituídos pela análise geométrica automatizada. O grafo contém nomes de alinhamento e superfície de exemplo, que devem ser alterados antes da execução. O código possui regras e tolerâncias específicas para continuidade de trechos, que precisam ser avaliadas conforme o projeto e os dados do CSV.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 4. DUP_FAIXA.dyn

**Arquivo:** [`Faixa de Dominio/DUP_FAIXA.dyn`](./Faixa%20de%20Dominio/DUP_FAIXA.dyn)  
**Comando / entrada:** `Grafo Dynamo` (prefixo, número inicial, número final e modo `TODOS`/`PARES`/`IMPARES`)  
**Objetivo:** lançar COGO Points nos vértices dos alinhamentos que formam o contorno da faixa de domínio, para servir de referência ao `QAFAIXA.dll`.

**Funcionamento:** um nó Python busca, pela API do Civil 3D, os alinhamentos chamados `<PREFIXO> <N>` (ex.: `AL 1`, `AL 3`), lê as estacas de início/fim de cada trecho interno e calcula as coordenadas e a direção da tangente. Os pontos são criados na layer `0` e nomeados `Ponto 2`, `Ponto 3`…, e o último ponto do último alinhamento vira `Ponto 1`. Um segundo nó Python gira as labels +90° em relação ao alinhamento, mantém o texto legível e as afasta 18 m ao longo do eixo.

**Como utilizar:** [guia passo a passo](./Faixa%20de%20Dominio/GUIA_DUP_FAIXA.md).

**Requisitos e dependências:** Civil 3D com Dynamo 2.5 (Civil 3D 2021) ou superior, nós Python em IronPython2 e as bibliotecas `AcMgd`, `AcDbMgd` e `AeccDbMgd`.

**Status:** grafo salvo após execução bem-sucedida (96 de 96 labels ajustadas, segundo o registro do arquivo).

**Limitações e cuidados:** **cria COGO Points no DWG** a cada execução; apague os da execução anterior antes de rodar de novo. Alinhamentos encostados geram pontos duplicados no vértice comum.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 5. QAFAIXA.dll

**Arquivo:** [`Faixa de Dominio/QAFAIXA.dll`](./Faixa%20de%20Dominio/QAFAIXA.dll)  
**Comando / entrada:** `NETLOAD`, depois `QAFAIXA` (recomendado), `QAFAIXAAUTO`, `QAFAIXAORDEM`, `QAFAIXASEL`, `QAFAIXASEGUIR` ou `QAFAIXAGEN`, além dos aliases  
**Objetivo:** gerar o memorial descritivo do perímetro da faixa de domínio a partir de vários alinhamentos do Civil 3D.

**Funcionamento:** plugin .NET (`QAMemorial_faixa_poligonal_generico_v17`) que estende a `QAMemorial.dll`. Ele escolhe os alinhamentos por nome, por janela ou por clique, ordena a poligonal (por conexão, pela ordem dos nomes ou de forma forçada), usa os COGO Points `Ponto N` para confirmar as coordenadas dos vértices e grava `QAFAIXA_perimetro_faixa_dominio.doc` (RTF) na pasta do DWG.

**Como utilizar:** [guia passo a passo](./Faixa%20de%20Dominio/GUIA_QAFAIXA.md), com instalação e uso de cada comando.

**Requisitos e dependências:** Civil 3D e a [`QAMemorial.dll`](./Faixa%20de%20Dominio/QAMemorial.dll), incluída na mesma pasta. Ela deve ser carregada com `NETLOAD` antes do QAFAIXA ou ficar na mesma pasta que ele.

**Status:** documentação elaborada a partir dos nomes de comandos e das mensagens contidas na DLL; sem código-fonte no repositório.

**Limitações e cuidados:** o arquivo gerado é sobrescrito a cada execução. Revise o memorial e procure a marca **VERIFICAR** nos vértices que não puderam ser recalculados.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada pela leitura dos arquivos do repositório. Compatibilidade e resultados devem ser validados na versão de software utilizada.
