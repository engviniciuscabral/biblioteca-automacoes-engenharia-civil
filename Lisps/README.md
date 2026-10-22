# Lisps — Catálogo de automações

Rotinas AutoLISP para AutoCAD e Civil 3D, incluindo medições, exportação de dados e edição geométrica.

[← Voltar ao catálogo geral](../README.md)

## Índice de rotinas

| Arquivo | Comando / entrada | Finalidade | Documentação |
|---|---|---|---|
| [`CONT_AREA.lsp`](./CONT_AREA.lsp) | `CONT_AREA` | Exportação de áreas de hachuras e polilinhas fechadas para Excel. | [Ver detalhes](#1-cont_arealsp) |
| [`CONT_AREA_POLILINHA.lsp`](./CONT_AREA_POLILINHA.lsp) | `CONT_AREA` | Exportação de áreas dos objetos selecionados para Excel. | [Ver detalhes](#2-cont_area_polilinhalsp) |
| [`COTAS_TALVEGUES.lsp`](./COTAS_TALVEGUES.lsp) | `COTASTALVEGUES` | Exportação de cotas e distâncias de perfis de talvegues do Civil 3D. | [Ver detalhes](#7-cotas_talvegueslsp) |
| [`CONT_COMP.lsp`](./CONT_COMP.lsp) | `CONT_COMP` | Exportação dos comprimentos de polilinhas selecionadas para Excel. | [Ver detalhes](#3-cont_complsp) |
| [`GEOIMG.lsp`](./GEOIMG.lsp) | `GEOIMG` | Inserção de imagem PNG georreferenciada com arquivo PGW no AutoCAD. | [Ver detalhes](#4-geoimglsp) |
| [`UnirConectados.lsp`](./UnirConectados.lsp) | `UNIRCON / UNIRCONCFG` | União de entidades lineares conectadas por extremidades. | [Ver detalhes](#5-unirconectadoslsp) |
| [`TEXTO_BACIA_2.lsp`](./TEXTO_BACIA_2.lsp) | `TEXTO_BACIAS_TODAS` / `TEXTO_BACIA` / `TEXTO_BACIA_CSV` / `TEXTO_BACIA_RECARREGAR` | Criação e atualização de chamadas MLEADER de bacias a partir de CSV. | [Ver detalhes](#8-texto_bacia_2lsp) |
| [`BACIAS_QUADRO.lsp`](./BACIAS_QUADRO.lsp) | `BACIAS_QUADRO` / `BACIAS_NUMERAR` / `BACIAS_TABELA` / `BACIAS_CSV` / `BACIAS_RECARREGAR` / `BACIAS_APAGAR_BLOCOS` | Numeração das bacias em MLEADER com marcador circular e criação de quadro-resumo a partir de CSV. | [Ver detalhes](#bacias_quadrolsp) |
| [`BUEIROS_PERFIL.lsp`](./Bueiros%20Perfil/BUEIROS_PERFIL.lsp) | `BUEIROPERFIL` | Criação de COGO points no eixo e desenho dos bueiros projetados (BSCC/BDCC/BTCC, BSTC/BDTC/BTTC) com legenda na vista de perfil do Civil 3D, a partir do cadastro de obras em CSV. | [Ver detalhes](#9-bueiros_perfillsp) |
| [`tlen.lsp`](./tlen.lsp) | `TLEN` | Soma dos comprimentos de entidades selecionadas. | [Ver detalhes](#6-tlenlsp) |
| [`TEMPLATE_BOCAS.lsp`](./TEMPLATE_BOCAS.lsp) | `BOCASCADASTRO` / `BOCASCADBASE` / `BOCASCADDIN` / `BOCASADDIN` | Criação e cadastro de blocos-modelo de bocas de bueiros. | [Ver detalhes](#template_bocaslsp) · [Guia passo a passo](./GUIA_BOCAS_BUEIROS.md) |
| [`BOCAS_BUEIRO.lsp`](./BOCAS_BUEIRO.lsp) | `BOCASBUEIRO` / `BBU` / `BBDIAG` | Inserção automática de bocas a montante/jusante e, quando aplicável, dissipador. | [Ver detalhes](#bocas_bueeirolsp) · [Guia passo a passo](./GUIA_BOCAS_BUEIROS.md) |

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

### 9. BUEIROS_PERFIL.lsp

**Arquivo:** [`BUEIROS_PERFIL.lsp`](./Bueiros%20Perfil/BUEIROS_PERFIL.lsp)  
**Comando / entrada:** `BUEIROPERFIL`  
**Arquivos de exemplo:** [`CADASTRO_OBRAS_exemplo.csv`](./Bueiros%20Perfil/CADASTRO_OBRAS_exemplo.csv) (cadastro das obras, ANSI/Windows-1252) e [`COGOpoints.csv`](./Bueiros%20Perfil/COGOpoints.csv) (pontos PNEZD). Os dados são fictícios: trecho, nomes de cursos d'água, cotas e coordenadas foram alterados; servem apenas para mostrar o formato esperado.  
**Objetivo:** Lançar os bueiros projetados do cadastro de obras de arte correntes no eixo e na vista de perfil do Civil 3D, com desenho da seção da obra e legenda.

**Funcionamento:**
1. Lê o CSV do **cadastro das obras** (separador `;`, decimal `,`, ANSI/Windows-1252 ou UTF-8). O cabeçalho é localizado pela linha que contém `ESTACA` e `COTA MONTANTE`; as colunas são reconhecidas pelos títulos `COD. BACIA`, `COD. BUEIRO`, `ESTACA` (com `+` e fração nas colunas seguintes ou no mesmo campo), `DESCRIÇÃO`, `OBRA PROJETADA`, `DECLIV.`/`INCLINA…`, `COTA MONTANTE` e `L PROJETADO`. Se algum título não for encontrado, usa posições predefinidas.
2. Opcionalmente lê o **COGOpoints.csv** (formato `PNEZD`, separador `,`). Cada ponto é projetado no eixo (`StationOffset`), associado à obra do cadastro de estaca mais próxima (tolerância de 30 m) e recriado como COGO point no eixo (offset 0), com a elevação do arquivo ou a cota montante do cadastro, à escolha do usuário. Se o COGOpoints for cancelado, usa estaca e cota montante do próprio cadastro.
3. Desenha a obra na vista de perfil, já na escala e no exagero vertical da vista: células retangulares para `BSCC`/`BDCC`/`BTCC`/`BQCC` (dimensões lidas do texto, ex.: `BDCC 3,0 x 3,0`) e tubos (lentes de dois arcos) para `BSTC`/`BDTC`/`BTTC` (diâmetro lido de `d = 1,2`). Obras de outro tipo recebem um marcador em cruz.
4. Insere abaixo da obra um MTEXT com Estaca, Descrição, Obra projetada, L, Cota montante e Inclinação.
5. Adiciona os pontos criados ao grupo de pontos `OAC - EIXO` e, por padrão, projeta-os na vista de perfil com `PROJECTOBJECTSTOPROF`. Tudo o que a rotina cria vai para a layer `OBRAS PROJETADAS`.

**Como utilizar:** Abra o DWG com o alinhamento e a vista de perfil; carregue com `APPLOAD`; execute `BUEIROPERFIL`; selecione a vista de perfil (o alinhamento é obtido dela ou solicitado); escolha o CSV do cadastro (passo 1) e o COGOpoints.csv (passo 2, ou Cancelar para usar só o cadastro). Com COGOpoints, responda à origem da elevação (`Cogo`/`Montante`) e se deve processar apenas pontos associados a uma obra. Na janela de estilos da projeção, confirme com OK. Se o arquivo de pontos for escolhido no passo 1 por engano, a rotina o reconhece e pede o cadastro novamente. Ajuste estaca (20 m), altura do texto, tolerância, ordem `PNEZD`/`PENZD`, grupo, layer e projeção automática nas variáveis `*bp:...` do início do arquivo.

**Requisitos e dependências:** AutoCAD Civil 3D para Windows com AutoLISP, Visual LISP/ActiveX e a API COM do Civil 3D (`AeccXUiLand`); `ADODB.Stream` para leitura dos CSVs; alinhamento com vista de perfil; valores em metros.

**Status:** Atualizado com a versão enviada em 19/10/2026; alteração conferida por comparação de código, sem validação por execução no Civil 3D.

**Alteração desta versão:** Na configuração `*bp:ref-cota* = "TOPO"`, a cota de referência passa a coincidir com o **topo interno** da seção do bueiro. O desenho é deslocado verticalmente pela espessura superior da seção celular (`esp`) ou tubular (`ew`), já considerando o exagero vertical da vista. A opção `"FUNDO"` continua referenciada ao fundo interno. Essa mudança corrige a interpretação da cota de referência sem alterar o fluxo de leitura dos CSVs e geração de pontos.

**Limitações e cuidados:**
- A estaca do cadastro é convertida em `estaca × 20 + fração`, presumindo que o alinhamento começa na estaca 0+0,00. Confira se o estaqueamento do eixo segue essa convenção.
- Com `*bp:ref-cota* = "TOPO"`, o **topo interno** da seção coincide com a cota do ponto; a face externa superior fica acima dessa cota pela espessura correspondente. Com `"FUNDO"`, a referência é o fundo interno. Confira se a cota montante do cadastro representa o topo ou o fundo pretendido antes de gerar o desenho.
- Cada execução cria novos COGO points e novos desenhos, sem atualizar os anteriores: para refazer, apague o que foi gerado (layer `OBRAS PROJETADAS`) e os pontos do grupo `OAC - EIXO`.
- Linhas do cadastro sem `COD. BACIA` geram descrição do ponto iniciada por ` - `.
- Obras fora do intervalo de estacas da vista de perfil são listadas no relatório e não são desenhadas.
- Teste em cópia do DWG antes de usar em produção.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### TEMPLATE_BOCAS.lsp

**Guia complementar:** [Bocas de bueiros — instalação, configuração e uso passo a passo](./GUIA_BOCAS_BUEIROS.md).

**Arquivo:** [`TEMPLATE_BOCAS.lsp`](./TEMPLATE_BOCAS.lsp)  
**Comandos principais:** `BOCASCADASTRO`, `BOCASCADBASE`, `BOCASCADDIN`, `BOCASADDIN`.  
**Objetivo:** disponibilizar modelos de bocas de bueiros tubulares de concreto e facilitar sua inserção e organização como blocos no AutoCAD/Civil 3D.

**Funcionamento:** contém 18 templates em planta para bueiros simples, duplos e triplos (`BSTC`, `BDTC` e `BTTC`), com diâmetros de 1,00, 1,20, 1,50, 2,00, 2,50 e 3,00 m. As geometrias são definidas por coordenadas em centímetros e convertidas conforme `INSUNITS`. A rotina cria camadas, tipos de linha e blocos; o comando de inserção solicita tipo, diâmetro, ponto e rotação. Também contém uma família de blocos com referência a modelos DNIT (BNAR, BNAA e BEAA 15°/30°/45°).

**Como utilizar:**
1. Abra preferencialmente um DWG novo e vazio para criar a biblioteca de blocos; confira as unidades do desenho.
2. Carregue a LISP com `APPLOAD`.
3. Execute `BOCASCADASTRO` para escolher BSTC/BDTC/BTTC, diâmetro, ponto de inserção e rotação.
4. Use `BOCASCADBASE` para criar os 18 blocos estáticos de cadastro; `BOCASCADDIN` (ou `BOCASADDIN`) tenta criar e validar um bloco dinâmico com 18 estados de visibilidade.
5. Confira os blocos e suas dimensões antes de aplicá-los em desenhos de projeto.

**Requisitos e dependências:** AutoCAD/Civil 3D para Windows, AutoLISP/Visual LISP e suporte aos comandos e à API ActiveX de edição de blocos. O código reconhece `INSUNITS` 6 (metros), 5 (centímetros), 4 (milímetros) e 0 (assume metros). A criação dinâmica depende da disponibilidade e do comportamento dos comandos do Editor de Blocos na versão utilizada.

**Status:** arquivo incluído na biblioteca em 19/10/2026; não houve validação de execução no AutoCAD/Civil 3D.

**Limitações e cuidados:**
- O cabeçalho cita DNIT IPR-736, Emenda 3, como referência para modelos BNAR/BNAA/BEAA; os diâmetros 2,00, 2,50 e 3,00 m desses modelos são **extrapolados** e não possuem respaldo declarado no álbum DNIT.
- Os 18 templates de cadastro são descritos no código como extraídos de um DWG de conferência. Verifique dimensões e adequação às especificações do projeto.
- O código redefine alguns comandos ao longo do arquivo; na versão final, `BOCASTESTE` chama `BOCASCADDIN` (não é apenas um teste simples, apesar da descrição inicial).
- A criação de blocos e layers **modifica o DWG**; execute inicialmente em um desenho de teste e faça backup.
- A criação de blocos dinâmicos pode depender de prompts específicos da versão e do idioma do AutoCAD; confira o resultado.

[↑ Voltar ao índice](#índice-de-rotinas)


---

### BOCAS_BUEIRO.lsp

**Arquivo:** [`BOCAS_BUEIRO.lsp`](./BOCAS_BUEIRO.lsp)  
**Comandos:** `BOCASBUEIRO` (atalho `BBU`) e `BBDIAG` (diagnóstico).

**Objetivo:** Automatizar a inserção de bocas de bueiros no Civil 3D, a montante e a jusante de tubos selecionados de uma ou mais redes de tubulação.

**Funcionamento:** A rotina agrupa tubos paralelos e próximos para identificar bueiros simples, duplos ou triplos. Lê as propriedades de dimensão, forma e extremidades dos tubos; usa as cotas Z para determinar o sentido do fluxo, considerando a extremidade de menor cota como jusante. Em seguida, insere os blocos de boca orientados conforme o eixo do bueiro e define o estado de visibilidade correspondente ao tipo e à dimensão. Para bueiros tubulares com diâmetro dentro do limite configurado (por padrão, até 1,50 m), também pode inserir um dissipador de energia a jusante.

**Como utilizar:**
1. Verifique se o desenho contém as redes de tubulação e os blocos dinâmicos ou blocos de boca esperados pela rotina.
2. Se necessário, ajuste as variáveis de configuração no início do arquivo, como nomes dos blocos, ângulos de orientação, limite de diâmetro do dissipador, camadas e tolerâncias de agrupamento.
3. Carregue `BOCAS_BUEIRO.lsp` com `APPLOAD`.
4. Execute `BOCASBUEIRO` (ou `BBU`) e selecione os tubos dos bueiros a processar.
5. Confira as bocas, o sentido do fluxo e os dissipadores inseridos. Use `BBDIAG` para diagnóstico quando necessário.

**Requisitos e dependências:** AutoCAD/Civil 3D para Windows, AutoLISP, Visual LISP/ActiveX e redes de tubulação (Pipe Networks) com propriedades de diâmetro/largura, altura e pontos inicial/final acessíveis. A rotina depende de blocos de boca compatíveis com os estados de visibilidade esperados; o dissipador é opcional e pode ser escolhido ou informado conforme os prompts.

**Status:** Arquivo incluído na biblioteca; não foi executado em ambiente AutoCAD/Civil 3D nesta atualização.

**Limitações e cuidados:**
- A direção do fluxo é inferida pela diferença de cota Z entre as extremidades. Se as cotas estiverem ausentes, iguais ou não representarem o sentido hidráulico real, confira manualmente a montante e a jusante.
- O agrupamento depende das tolerâncias de paralelismo e distância configuradas; tubos próximos de bueiros diferentes podem exigir seleção separada ou ajuste das tolerâncias.
- O dissipador é condicionado à forma tubular e ao limite de diâmetro configurado. O bloco e a orientação precisam ser verificados no desenho.
- A rotina insere entidades e pode criar ou alterar propriedades de blocos/camadas no DWG. Faça cópia de segurança e valide primeiro em um desenho de teste.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada pela leitura dos arquivos do repositório. Compatibilidade e resultados devem ser validados na versão de software utilizada.
