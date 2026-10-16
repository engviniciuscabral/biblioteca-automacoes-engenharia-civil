# Lisps — Catálogo de automações

Rotinas AutoLISP para AutoCAD e Civil 3D, incluindo medições, exportação de dados e edição geométrica.

[← Voltar ao catálogo geral](../README.md)

## Índice de rotinas

| Arquivo | Comando / entrada | Finalidade |
|---|---|---|
| [`CONT_AREA.lsp`](./CONT_AREA.lsp) | `CONT_AREA` | Exportação de áreas de hachuras e polilinhas fechadas para Excel. |
| [`CONT_AREA_POLILINHA.lsp`](./CONT_AREA_POLILINHA.lsp) | `CONT_AREA` | Exportação de áreas dos objetos selecionados para Excel. |
| [`COTAS_TALVEGUES.lsp`](./COTAS_TALVEGUES.lsp) | `COTASTALVEGUES` | Exportação de cotas e distâncias de perfis de talvegues do Civil 3D. |
| [`CONT_COMP.lsp`](./CONT_COMP.lsp) | `CONT_COMP` | Exportação dos comprimentos de polilinhas selecionadas para Excel. |
| [`GEOIMG.lsp`](./GEOIMG.lsp) | `GEOIMG` | Inserção de imagem PNG georreferenciada com arquivo PGW no AutoCAD. |
| [`UnirConectados.lsp`](./UnirConectados.lsp) | `UNIRCON / UNIRCONCFG` | União de entidades lineares conectadas por extremidades. |
| [`TEXTO_BACIA_2.lsp`](./TEXTO_BACIA_2.lsp) | `TEXTO_BACIAS_TODAS` / `TEXTO_BACIA` / `TEXTO_BACIA_CSV` / `TEXTO_BACIA_RECARREGAR` | Criação e atualização de chamadas MLEADER de bacias a partir de CSV. |
| [`BACIAS_QUADRO.lsp`](./BACIAS_QUADRO.lsp) | `BACIAS_QUADRO` / `BACIAS_NUMERAR` / `BACIAS_TABELA` / `BACIAS_CSV` / `BACIAS_RECARREGAR` / `BACIAS_APAGAR_BLOCOS` | Numeração das bacias em MLEADER com marcador circular e criação de quadro-resumo a partir de CSV. |
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

### 7. COTAS_TALVEGUES.lsp

**Arquivo:** [`COTAS_TALVEGUES.lsp`](./COTAS_TALVEGUES.lsp)  
**Comando / entrada:** `COTASTALVEGUES`  
**Objetivo:** Exportar cotas e distâncias amostradas ao longo de alinhamentos de talvegues do Civil 3D.

**Funcionamento:** Percorre objetos do Model Space identificados como alinhamentos, filtra nomes por prefixo (padrão `TALV`), procura um perfil associado (prioriza nomes contendo `PERFIL LONGITUDINAL`, `TERRENO` ou `EXISTENTE`), amostra elevações por intervalo automático ou fixo e gera um CSV por alinhamento, com colunas `Ponto;Cota (m);Distancia (m)`. Opcionalmente reordena as cotas em ordem decrescente, mantendo as distâncias, e registra as alterações em `Ajustes_Cotas.txt`.

**Como utilizar:** Abra um DWG salvo com alinhamentos e perfis longitudinais; carregue o LISP por `APPLOAD`; execute `COTASTALVEGUES`; informe o prefixo, escolha amostragem automática (100 m para extensões < 1.000 m; 200 m para < 3.000 m; 500 m para < 8.000 m; 1.000 m para extensões maiores) ou intervalo fixo e responda à pergunta sobre ajuste de cotas. Os arquivos são gravados na pasta `Perfis_Talvegues` junto ao DWG, em CSV compatível com Excel-BR (separador `;` e decimal `,`).

**Requisitos e dependências:** AutoCAD Civil 3D para Windows, AutoLISP/Visual LISP/ActiveX, alinhamentos com perfis associados e desenho salvo; valores presumidos em metros.

**Status:** Código original incluído sem alterações; compatibilidade com os métodos/propriedades ActiveX de leitura de perfis ainda não verificada por execução.

**Limitações e cuidados:** Recomenda-se responder **N** ao ajuste automático para preservar as cotas originais: a opção **S** reordena elevações e pode descaracterizar o perfil real. A verificação do sentido do alinhamento contém a expressão `(< (car cotas) (last cotas))`, que pode provocar erro de tipo. A rotina presume estação inicial zero, não valida intervalo fixo maior que zero, pode falhar com nomes de alinhamento inválidos como nomes de arquivo e depende da disponibilidade de `Profiles` e dos métodos de elevação na API COM. Revise os CSVs e teste em cópia do projeto antes de uso técnico.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### 8. TEXTO_BACIA_2.lsp

**Arquivo:** [`TEXTO_BACIA_2.lsp`](./TEXTO_BACIA_2.lsp)  
**Comandos:** `TEXTO_BACIAS_TODAS`, `TEXTO_BACIA`, `TEXTO_BACIA_CSV` e `TEXTO_BACIA_RECARREGAR`.  
**Objetivo:** Criar e atualizar chamadas de identificação de bacias com MLEADER a partir de dados de planilha exportados para CSV.

**Funcionamento:** Procura um CSV com `BACIA` no nome na pasta do DWG ou solicita a escolha manual. Interpreta campos de código da bacia, estaca, área, comprimento do talvegue, declividade e, quando disponível, curso d'água. Relaciona os códigos às layers `BC` numeradas no Model Space; para cada bacia escolhe prioritariamente a curva fechada de maior área, calcula um ponto interno de referência e insere um MLEADER na layer `TEXTO BACIAS`. Chamadas anteriormente criadas pela rotina são identificadas por XData e têm o texto atualizado sem perder a posição.

**Como utilizar:** No Excel, exporte a tabela de bacias para CSV separado por ponto e vírgula, preferencialmente com `BACIA` no nome e na pasta do DWG. No AutoCAD/Civil 3D para Windows, carregue o arquivo com `APPLOAD`. Execute `TEXTO_BACIAS_TODAS` para inserir/atualizar todas as chamadas; `TEXTO_BACIA` para selecionar uma bacia e posicionar uma chamada manualmente; `TEXTO_BACIA_CSV` para selecionar outro CSV; e `TEXTO_BACIA_RECARREGAR` para limpar o cache antes de reler dados alterados. Ajuste altura, cores, layer e afastamento nas variáveis `*bb:...` do início do arquivo.

**Requisitos e dependências:** AutoCAD/Civil 3D com AutoLISP, Visual LISP/ActiveX e suporte a MLEADER; desenho com layers de bacias `BC` e arquivo CSV no formato esperado. Não exige Excel instalado durante a execução, apenas o CSV exportado.

**Status:** Código original anexado incluído sem alterações; funcionamento não verificado em execução nesta revisão.

**Limitações e cuidados:** Os campos do CSV são reconhecidos por cabeçalhos e, quando ausentes, por posições predefinidas; confira a estrutura e as unidades da planilha (área em km², comprimento em km e declividade em %). Se houver mais de um CSV com `BACIA` no nome, a seleção automática pode não corresponder ao arquivo desejado. Sem curva fechada, a rotina usa a curva aberta mais longa como referência, o que exige conferência visual. O comando altera/adiciona entidades MLEADER no desenho; teste em uma cópia antes do uso.

[↑ Voltar ao índice](#índice-de-rotinas)


---

### BACIAS_QUADRO.lsp

**Arquivo:** [`BACIAS_QUADRO.lsp`](./BACIAS_QUADRO.lsp)  
**Comandos:** `BACIAS_QUADRO`, `BACIAS_NUMERAR`, `BACIAS_TABELA`, `BACIAS_CSV`, `BACIAS_RECARREGAR`, `BACIAS_APAGAR_BLOCOS`

**Objetivo:** Numerar bacias hidrográficas identificadas por layers iniciadas com `BC` e montar uma tabela-resumo no AutoCAD com os dados de uma planilha exportada para CSV.

**Funcionamento:** Para cada layer de bacia reconhecida, procura uma geometria no Model Space e cria uma MLEADER com a ponta de referência na bacia e o número dentro de um círculo. Também lê um CSV, associa os dados pelo código da bacia e gera uma tabela com estaca, curso d'água, área, comprimento do talvegue, desnível, declividade e tempo de concentração. A tabela anterior é substituída mantendo seu ponto de inserção; os marcadores já existentes mantêm a posição ao executar novamente.

**Como utilizar:**
1. No Excel, salve a planilha como CSV separado por ponto e vírgula, com dados/cabeçalhos compatíveis com a rotina.
2. Preferencialmente, deixe o arquivo CSV cujo nome contenha `BACIA` na mesma pasta do DWG; caso contrário, use `BACIAS_CSV` para selecioná-lo.
3. Carregue `BACIAS_QUADRO.lsp` com `APPLOAD`.
4. Execute `BACIAS_QUADRO` para numerar as bacias e criar/atualizar a tabela. Para tarefas separadas, use `BACIAS_NUMERAR` ou `BACIAS_TABELA`.
5. Depois de alterar o CSV, execute `BACIAS_RECARREGAR` antes de reler os dados.

**Requisitos e dependências:** AutoCAD com AutoLISP, Visual LISP/ActiveX e suporte a MLEADER e tabelas do AutoCAD. As layers das bacias devem começar com `BC`; os dados tabulares precisam estar em CSV.

**Status:** Arquivo incluído na biblioteca; não foi executado em ambiente AutoCAD nesta atualização.

**Limitações e cuidados:** A identificação da geometria usa objetos do Model Space na layer correspondente; quando não encontra curva fechada, pode usar a curva aberta mais longa como referência. A rotina usa mapeamento de cabeçalhos e posições predefinidas no CSV, então confira a correspondência dos campos, as unidades e os separadores decimais antes de gerar a tabela. A configuração inicial define altura, cores, layers e afastamento dos números. O comando `BACIAS_APAGAR_BLOCOS` destina-se a blocos de uma versão anterior, não às MLEADER atuais. Teste em cópia do DWG antes de usar em produção.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada pela leitura dos arquivos do repositório. Compatibilidade e resultados devem ser validados na versão de software utilizada.
