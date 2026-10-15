# Lisps — Catálogo de automações

Rotinas AutoLISP para AutoCAD e Civil 3D, incluindo medições, exportação de dados e edição geométrica.

[← Voltar ao catálogo geral](../README.md)

## Índice de rotinas

| Arquivo | Comando / entrada | Finalidade |
|---|---|---|
| [`CONT_AREA.lsp`](./CONT_AREA.lsp) | `CONT_AREA` | Exportação de áreas de hachuras e polilinhas fechadas para Excel. |
| [`CONT_AREA_POLILINHA.lsp`](./CONT_AREA_POLILINHA.lsp) | `CONT_AREA` | Exportação de áreas dos objetos selecionados para Excel. |
| [`CONT_COMP.lsp`](./CONT_COMP.lsp) | `CONT_COMP` | Exportação dos comprimentos de polilinhas selecionadas para Excel. |
| [`GEOIMG.lsp`](./GEOIMG.lsp) | `GEOIMG` | Inserção de imagem PNG georreferenciada com arquivo PGW no AutoCAD. |
| [`UnirConectados.lsp`](./UnirConectados.lsp) | `UNIRCON / UNIRCONCFG` | União de entidades lineares conectadas por extremidades. |
| [`tlen.lsp`](./tlen.lsp) | `TLEN` | Soma dos comprimentos de entidades selecionadas. |

## Documentação das rotinas

### 1. CONT_AREA.lsp

**Arquivo:** [`CONT_AREA.lsp`](./CONT_AREA.lsp)  
**Comando / entrada:** `CONT_AREA`  
**Objetivo:** Exportação de áreas de hachuras e polilinhas fechadas para Excel.

**Funcionamento:** Seleciona hachuras e polilinhas (2D), verifica a propriedade de área e cria uma planilha Excel com identificação sequencial E-1, tipo do objeto e área.

**Como utilizar:** Carregue com APPLOAD, execute `CONT_AREA`, selecione as entidades e confira a nova pasta de trabalho do Excel.

**Requisitos e dependências:** AutoCAD com suporte a Visual LISP/ActiveX e Excel instalado no Windows.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** O README anterior registrava que só funcionava com hachuras; o código atual também contempla polilinhas fechadas. Polilinhas abertas ou objetos sem área válida são marcados como `Inválido`. Verificar em desenho de teste antes do uso.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 2. CONT_AREA_POLILINHA.lsp

**Arquivo:** [`CONT_AREA_POLILINHA.lsp`](./CONT_AREA_POLILINHA.lsp)  
**Comando / entrada:** `CONT_AREA`  
**Objetivo:** Exportação de áreas dos objetos selecionados para Excel.

**Funcionamento:** Aceita uma seleção sem filtro de tipos, tenta consultar a propriedade `Area` de cada entidade e gera colunas Elemento, Tipo e Área no Excel.

**Como utilizar:** Carregue com APPLOAD, execute `CONT_AREA`, selecione os objetos e examine os resultados no Excel.

**Requisitos e dependências:** AutoCAD com Visual LISP/ActiveX e Excel no Windows.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** Não exige que a entidade seja fechada; objetos sem propriedade `Area` são registrados como `Inválido`. **Define o mesmo comando `CONT_AREA` do arquivo anterior:** carregue apenas a versão pretendida por vez.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 3. CONT_COMP.lsp

**Arquivo:** [`CONT_COMP.lsp`](./CONT_COMP.lsp)  
**Comando / entrada:** `CONT_COMP`  
**Objetivo:** Exportação dos comprimentos de polilinhas selecionadas para Excel.

**Funcionamento:** Seleciona polilinhas, calcula o comprimento ao longo de cada curva e cria uma planilha com identificadores C-1, C-2 etc. e respectivos comprimentos.

**Como utilizar:** Carregue com APPLOAD, execute `CONT_COMP` e selecione as polilinhas.

**Requisitos e dependências:** AutoCAD com Visual LISP/ActiveX e Excel no Windows.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** Os valores são apresentados nas unidades do desenho. Não há tratamento detalhado de falhas em entidades atípicas.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 4. GEOIMG.lsp

**Arquivo:** [`GEOIMG.lsp`](./GEOIMG.lsp)  
**Comando / entrada:** `GEOIMG`  
**Objetivo:** Inserção de imagem PNG georreferenciada com arquivo PGW no AutoCAD.

**Funcionamento:** Solicita um PNG, procura o arquivo `.pgw` de mesmo nome, lê os seis parâmetros de georreferenciamento e ajusta posição, escala e orientação da imagem raster inserida.

**Como utilizar:** Mantenha `imagem.png` e `imagem.pgw` na mesma pasta; carregue com APPLOAD, execute `GEOIMG` e selecione o PNG.

**Requisitos e dependências:** AutoCAD com Visual LISP/ActiveX; arquivos PNG e PGW correspondentes.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** O arquivo PGW não define o sistema de coordenadas: confirme que o SRC e as unidades do desenho correspondem aos dados da imagem. A rotina insere uma referência à imagem, não incorpora seus bytes ao DWG.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 5. UnirConectados.lsp

**Arquivo:** [`UnirConectados.lsp`](./UnirConectados.lsp)  
**Comando / entrada:** `UNIRCON / UNIRCONCFG`  
**Objetivo:** União de entidades lineares conectadas por extremidades.

**Funcionamento:** Percorre cadeias de LINE, ARC e polilinhas abertas, identifica conexões por tolerância e produz polilinhas 2D. Há configurações para tolerância, filtro de camada e bifurcações.

**Como utilizar:** Carregue com APPLOAD; execute `UNIRCONCFG` para configurar, depois `UNIRCON` e selecione os elementos iniciais.

**Requisitos e dependências:** AutoCAD com Visual LISP/ActiveX.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** Ignora polilinhas fechadas, determinadas polilinhas ajustadas e camadas travadas. O resultado é 2D: elevações de polilinhas 3D não são preservadas integralmente. Teste em cópia do desenho, sobretudo em bifurcações.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 6. tlen.lsp

**Arquivo:** [`tlen.lsp`](./tlen.lsp)  
**Comando / entrada:** `TLEN`  
**Objetivo:** Soma dos comprimentos de entidades selecionadas.

**Funcionamento:** Calcula o comprimento total de linhas, arcos e outros tipos de curvas suportados, apresentando o resultado em uma caixa de diálogo.

**Como utilizar:** Carregue com APPLOAD, execute `TLEN` e selecione os objetos.

**Requisitos e dependências:** AutoCAD compatível com AutoLISP.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** O resultado usa as unidades do desenho. O cabeçalho do arquivo atribui autoria original a Tee Square Graphics (1998); preserve essa informação ao reutilizar ou distribuir.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada pela leitura dos arquivos do repositório. Compatibilidade e resultados devem ser validados na versão de software utilizada.
