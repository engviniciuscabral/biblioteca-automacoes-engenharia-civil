# Rotinas AutoLISP — AutoCAD / Civil 3D

Índice das **6 rotinas** desta pasta. As descrições seguem o modelo de documentação anteriormente usado para `CONT_AREA.lsp`, ampliado com funcionamento, requisitos e limitações.

## Índice

1. [CONT_AREA.lsp](#cont_arealsp)
2. [CONT_AREA_POLILINHA.lsp](#cont_area_polilinhalsp)
3. [CONT_COMP.lsp](#cont_complsp)
4. [GEOIMG.lsp](#geoimglsp)
5. [UnirConectados.lsp](#unirconectadoslsp)
6. [tlen.lsp](#tlenlsp)

## CONT_AREA.lsp

**Nome do comando:** `CONT_AREA`  
**Software:** AutoCAD / Civil 3D com suporte a Visual LISP/ActiveX e automação do Excel  
**Linguagem:** AutoLISP / Visual LISP  
**Objetivo:** Exportar a área individual de hachuras e polilinhas fechadas para uma nova planilha do Excel.

**Funcionamento:** solicita a seleção de entidades `HATCH`, `LWPOLYLINE` e `POLYLINE`. Para cada entidade, tenta ler a propriedade `Area`; para polilinhas, exige que estejam fechadas. Cria uma pasta de trabalho do Excel e preenche as colunas **Elemento**, **Tipo** e **Área**, identificando os itens como `E-1`, `E-2` etc. Valores não obtidos são registrados como `Inválido`.

**Como utilizar:** carregue [CONT_AREA.lsp](CONT_AREA.lsp) pelo comando `APPLOAD`; digite `CONT_AREA`; selecione os elementos; confira a planilha criada e salve-a no Excel.

**Dependências:** Excel instalado e automação COM disponível (tipicamente Windows); unidades de área conforme as unidades do desenho.

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** polilinhas abertas ou sem propriedade de área válida são marcadas como inválidas; a ordem de exportação segue a ordem interna da seleção, que pode não corresponder à sequência de cliques. A documentação anterior afirmava que somente hachuras eram aceitas, mas a versão atual do código também trata polilinhas fechadas.

## CONT_AREA_POLILINHA.lsp

**Nome do comando:** `CONT_AREA` (**mesmo comando do arquivo anterior**)  
**Software:** AutoCAD / Civil 3D com Excel  
**Linguagem:** AutoLISP / Visual LISP  
**Objetivo:** Exportar a propriedade de área dos objetos selecionados, inclusive polilinhas quando possuírem área válida.

**Funcionamento:** permite seleção sem filtro de tipo; percorre os objetos, consulta a propriedade `Area` e cria uma planilha com **Elemento**, **Tipo** e **Área**. Se a consulta falhar, escreve `Inválido`.

**Como utilizar:** carregue [CONT_AREA_POLILINHA.lsp](CONT_AREA_POLILINHA.lsp) por `APPLOAD`; execute `CONT_AREA`; selecione os objetos e revise os resultados no Excel.

**Dependências:** Excel e interface COM/ActiveX.

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** a seleção aceita objetos sem área, que serão marcados como inválidos. **Conflito de comandos:** este arquivo e `CONT_AREA.lsp` definem `CONT_AREA`; ao carregar ambos, a definição carregada por último prevalece.

## CONT_COMP.lsp

**Nome do comando:** `CONT_COMP`  
**Software:** AutoCAD / Civil 3D com Excel  
**Linguagem:** AutoLISP / Visual LISP  
**Objetivo:** Exportar comprimentos individuais de polilinhas para uma planilha.

**Funcionamento:** seleciona `LWPOLYLINE` e `POLYLINE`, calcula a distância acumulada até o parâmetro final de cada curva e preenche as colunas **Nome** (`C-1`, `C-2` etc.) e **Comprimento** em uma nova pasta de trabalho.

**Como utilizar:** carregue [CONT_COMP.lsp](CONT_COMP.lsp) com `APPLOAD`, execute `CONT_COMP`, selecione as polilinhas e salve o resultado no Excel.

**Dependências:** Excel, automação COM e objetos compatíveis com as funções `vlax-curve`.

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** não soma outros tipos de entidades, como linhas avulsas; não calcula comprimento 3D de maneira independente da geometria suportada pela função. Unidades conforme o desenho.

## GEOIMG.lsp

**Nome do comando:** `GEOIMG`  
**Software:** AutoCAD / Civil 3D  
**Linguagem:** AutoLISP / Visual LISP  
**Objetivo:** Inserir imagem PNG posicionada e dimensionada conforme arquivo de georreferenciamento PGW.

**Funcionamento:** solicita um arquivo PNG, procura um `.pgw` com o mesmo nome na mesma pasta e lê seus seis parâmetros de transformação. Insere uma imagem raster no Model Space, ajusta ponto de inserção e vetores de pixel na entidade `IMAGE`, regenera o desenho e informa resolução, dimensões e posição calculadas.

**Como utilizar:** coloque `imagem.png` e `imagem.pgw` juntos; carregue [GEOIMG.lsp](GEOIMG.lsp) via `APPLOAD`; execute `GEOIMG`; escolha o PNG; confira posição e escala no desenho.

**Dependências:** arquivo PGW válido, imagem PNG acessível, AutoCAD com suporte à inserção raster e Visual LISP/ActiveX.

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** trabalha especificamente com PNG/PGW; **não transforma coordenadas entre sistemas de referência** — o desenho deve usar o mesmo sistema do PGW. Arquivo PGW ausente gera aviso. Confira imagens com rotação e escala antes de uso em projeto.

## UnirConectados.lsp

**Nomes dos comandos:** `UNIRCON` (unir) e `UNIRCONCFG` (configurar)  
**Software:** AutoCAD / Civil 3D  
**Linguagem:** AutoLISP / Visual LISP  
**Objetivo:** Agrupar cadeias de segmentos conectados pelas extremidades em polilinhas únicas.

**Funcionamento:** parte de entidades selecionadas e procura elementos conectados no desenho, com índice espacial para acelerar a busca. Aceita `LINE`, `ARC` e polilinhas abertas 2D/3D. Cria `LWPOLYLINE` 2D, preservando propriedades selecionadas da entidade de origem; quando a criação é bem-sucedida, remove os elementos substituídos. Informa quantos elementos foram unidos.

**Como utilizar:** carregue [UnirConectados.lsp](UnirConectados.lsp) via `APPLOAD`; opcionalmente execute `UNIRCONCFG` para definir tolerância, uso da mesma camada e comportamento em bifurcações; execute `UNIRCON` e selecione os elementos iniciais.

**Dependências:** AutoCAD com funções Visual LISP/ActiveX.

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** ignora entidades em camadas travadas, polilinhas fechadas, curvas ajustadas e malhas. **A geometria 3D é achatada para 2D** na saída; não use sem conferência quando a elevação dos vértices for relevante. A tolerância padrão é `0.01` em unidades do desenho; bifurcações podem interromper a união e receber marcações temporárias. **A rotina modifica e remove entidades originais:** teste em uma cópia.

## tlen.lsp

**Nome do comando:** `TLEN`  
**Software:** AutoCAD / Civil 3D  
**Linguagem:** AutoLISP  
**Objetivo:** Calcular o comprimento total de entidades selecionadas.

**Funcionamento:** soma comprimentos de linhas e arcos; para círculos, splines, polilinhas e elipses utiliza o comando `AREA` e consulta o perímetro. Apresenta o total em uma caixa de diálogo.

**Como utilizar:** carregue [tlen.lsp](tlen.lsp) com `APPLOAD`; execute `TLEN`; selecione os objetos e confira o valor exibido.

**Dependências:** AutoCAD compatível com os comandos utilizados.

**Status:** implementação de terceiros presente no repositório; não validada por execução nesta documentação.

**Limitações:** outros tipos de objetos contribuem com zero; o código não trata explicitamente seleção vazia; a medição depende das unidades do desenho. **Crédito presente no arquivo:** © 1998 Tee Square Graphics — preservar a atribuição e verificar condições de uso antes de redistribuir.

---

[Voltar ao catálogo geral](../README.md)
