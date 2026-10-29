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
| [`BACIAS.lsp`](./BACIAS.lsp) | `BACIAS_QUADRO` / `BACIAS_NUMERAR` / `BACIAS_TABELA` / `BACIAS_TABELA_ONDE` / `TEXTO_BACIAS_TODAS` / `TEXTO_BACIA` / `BACIAS_CSV` / `BACIAS_RECARREGAR` | Rotina consolidada: numeração, quadro-resumo e chamadas textuais de bacias com um CSV compartilhado. | [Ver detalhes](#8-baciaslsp) |
| [`BACIAS_QUADRO.lsp`](./BACIAS_QUADRO.lsp) | `BACIAS_QUADRO` / `BACIAS_NUMERAR` / `BACIAS_TABELA` / `BACIAS_CSV` / `BACIAS_RECARREGAR` / `BACIAS_APAGAR_BLOCOS` | Numeração das bacias em MLEADER com marcador circular e criação de quadro-resumo a partir de CSV. | [Ver detalhes](#bacias_quadrolsp) |
| [`BUEIROS_PERFIL.lsp`](./Bueiros%20Perfil/BUEIROS_PERFIL.lsp) | `BUEIROPERFIL` | Criação de COGO points no eixo e desenho dos bueiros projetados (BSCC/BDCC/BTCC, BSTC/BDTC/BTTC) com legenda na vista de perfil do Civil 3D, a partir do cadastro de obras em CSV. | [Ver detalhes](#9-bueiros_perfillsp) |
| [`tlen.lsp`](./tlen.lsp) | `TLEN` | Soma dos comprimentos de entidades selecionadas. | [Ver detalhes](#6-tlenlsp) |
| [`TEMPLATE_BOCAS.lsp`](./TEMPLATE_BOCAS.lsp) | `BOCASCADASTRO` / `BOCASCADBASE` / `BOCASCADDIN` / `BOCASADDIN` | DNIT V4: 32 variantes, incluindo 9 tubulares extrapoladas; bloco dinâmico `BOCA_DNIT_PLANTA_V4`. | [Ver detalhes](#template_bocaslsp) · [Guia passo a passo](./GUIA_BOCAS_BUEIROS.md) |
| [`BOCAS_BUEIRO.lsp`](./BOCAS_BUEIRO.lsp) | `BOCASTUDO` / `BBT` / `BOCASBUEIRO` / `BBU` / `BOCASPERFIL` / `BBP` / `BOCASPERFILAUTO` / `BBCALIB` / `BBCALIBLIMPA` / `BBDIAG` | Versão v13: planta, perfil e modo combinado, com dissipadores DEB por tabela e diagnóstico. | [Ver detalhes](#bocas_bueirolsp) · [Guia passo a passo](./GUIA_BOCAS_BUEIROS.md) |

| [`SUAVBACIA.lsp`](./SUAVBACIA.lsp) | `SUAVBACIA` | Suavização de contornos de bacias raster/MDT, com preservação pretendida de divisórias compartilhadas. | [Ver detalhes](#suavbacialsp) |

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

### 8. BACIAS.lsp

**Arquivo:** [`BACIAS.lsp`](./BACIAS.lsp)  
**Comandos:** `BACIAS_QUADRO` (numeração + tabela), `BACIAS_NUMERAR` (somente números), `BACIAS_TABELA` (somente quadro), `BACIAS_TABELA_ONDE` (localiza o quadro), `TEXTO_BACIAS_TODAS` (chamadas completas de todas as bacias), `TEXTO_BACIA` (chamada individual), `BACIAS_CSV` / `TEXTO_BACIA_CSV` (seleção do CSV), `BACIAS_RECARREGAR` / `TEXTO_BACIA_RECARREGAR` (releitura dos dados) e `BACIAS_APAGAR_BLOCOS` (limpeza de blocos de versão antiga).

**Objetivo:** Consolidar as funcionalidades de `TEXTO_BACIA_2.lsp` e `BACIAS_QUADRO.lsp` em um único arquivo, usando uma fonte de dados CSV compartilhada para as chamadas textuais, a numeração e o quadro-resumo das bacias hidrográficas.

**Funcionamento:** Identifica bacias pelas layers iniciadas em `BC`, associa os códigos ao cadastro CSV, cria ou atualiza MLEADERs de identificação e de texto e produz uma tabela do AutoCAD. O código busca preservar a posição de chamadas existentes nas reexecuções e substitui a tabela anterior pela versão atualizada. Inclui `BACIAS_TABELA_ONDE` para localizar o quadro existente.

**Como utilizar:** Exporte a planilha para CSV separado por ponto e vírgula; prefira um arquivo com `BACIA` no nome, na mesma pasta do DWG. Carregue somente `BACIAS.lsp` pelo `APPLOAD`. Execute `BACIAS_QUADRO` para numeração e tabela ou `TEXTO_BACIAS_TODAS` para chamadas textuais. Use `BACIAS_CSV` para escolher outro arquivo e `BACIAS_RECARREGAR` após modificar os dados. Para uma chamada isolada, use `TEXTO_BACIA`.

**Requisitos e dependências:** AutoCAD/Civil 3D para Windows, AutoLISP/Visual LISP/ActiveX, suporte a MLEADER e tabelas, desenho com layers de bacias `BC` e CSV no formato esperado.

**Status:** Nova versão recebida e publicada sem modificações funcionais; execução no AutoCAD/Civil 3D não verificada nesta atualização.

**Limitações e cuidados:** A nova rotina também define os comandos `BACIAS_QUADRO`, `BACIAS_NUMERAR`, `BACIAS_TABELA`, `BACIAS_CSV`, `BACIAS_RECARREGAR` e `BACIAS_APAGAR_BLOCOS`, que existem no arquivo legado `BACIAS_QUADRO.lsp`. **Não carregue os dois arquivos na mesma sessão**, pois a última definição carregada prevalecerá. Confira cabeçalhos, unidades, separador e associação das layers antes do uso. Teste em uma cópia do DWG, especialmente a preservação de posições e a substituição da tabela.

[↑ Voltar ao índice](#índice-de-rotinas)

---

### BACIAS_QUADRO.lsp (legado)

**Atenção:** mantido apenas para compatibilidade e histórico. A nova [`BACIAS.lsp`](./BACIAS.lsp) incorpora os comandos deste arquivo e também os de chamadas textuais. Prefira a versão consolidada e **não carregue as duas rotinas juntas**, pois redefinem comandos de mesmo nome.


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

**Arquivo:** [`TEMPLATE_BOCAS.lsp`](./TEMPLATE_BOCAS.lsp)  
**Comandos recomendados:** `BOCASCADASTRO`, `BOCASCADBASE`, `BOCASCADDIN` e `BOCASADDIN`.  
**Guia completo:** [Bocas de bueiros — instalação, configuração e uso passo a passo](./GUIA_BOCAS_BUEIROS.md).

**Objetivo:** criar e cadastrar blocos-modelo de bocas de bueiros para utilização no AutoCAD/Civil 3D, incluindo o bloco dinâmico consumido pela rotina de inserção automática.

**Versão atual:** cabeçalho DNIT V4; o arquivo descreve modelos tubulares BNAA 01–11 e celulares quadrados BNAA 12–41. O cadastro final reúne 32 variantes: 11 tubulares BNAA, 9 tubulares extrapoladas (2,00/2,50/3,00 m em BSTC/BDTC/BTTC) e 12 celulares quadradas. O bloco dinâmico esperado pela rotina automática é `BOCA_DNIT_PLANTA_V4`.

**Como utilizar:**
1. Abra um DWG novo e vazio para montar a biblioteca e confira `INSUNITS`.
2. Carregue o arquivo com `APPLOAD`.
3. Execute `BOCASCADASTRO` para inserir/cadastrar uma variante conforme os prompts.
4. Execute `BOCASCADBASE` para gerar blocos estáticos e `BOCASCADDIN` para gerar o bloco dinâmico.
5. Confira estados de visibilidade, geometria e dimensões antes de copiar o bloco para desenhos de projeto.

**Requisitos e limitações:** AutoCAD/Civil 3D para Windows, AutoLISP/Visual LISP e suporte a edição de blocos. O cabeçalho cita o DNIT IPR-736, Emenda 3; o próprio código informa que os diâmetros 2,00, 2,50 e 3,00 m são extrapolados e não têm respaldo direto declarado no álbum. Valide as dimensões com as referências aplicáveis. A atualização do arquivo foi publicada no GitHub, mas não houve execução de teste no AutoCAD/Civil 3D nesta revisão.

[↑ Voltar ao índice](#índice-de-rotinas)


---

### BOCAS_BUEIRO.lsp

**Arquivo:** [`BOCAS_BUEIRO.lsp`](./BOCAS_BUEIRO.lsp) — versão recebida como `BOCAS_BUEIRO_4.lsp`, publicada com o nome padronizado do catálogo.

**Comandos:** `BOCASTUDO` (`BBT`, planta + perfil), `BOCASBUEIRO` (`BBU`, planta), `BOCASPERFIL` (`BBP`, clique na pipe no perfil), `BOCASPERFILAUTO` (seleção de Profile Views), `BBCALIB`, `BBCALIBLIMPA` e `BBDIAG`.

**Guia completo:** [Bocas de bueiros — instalação, configuração e uso passo a passo](./GUIA_BOCAS_BUEIROS.md).

**Objetivo:** automatizar a inserção de bocas a montante e jusante em bueiros representados por tubos de Pipe Network no Civil 3D e, quando aplicável, inserir dissipadores de energia.

**Funcionamento:** agrupa tubos paralelos e próximos para identificar bueiros simples, duplos ou triplos; lê as dimensões e as cotas das extremidades; considera a extremidade de menor cota como jusante; insere e orienta o bloco dinâmico `BOCA_DNIT_PLANTA_V4`. Para tubos tubulares dentro do limite configurado, pode inserir um dissipador. A v13 acrescenta cortes em Profile Views, modo combinado e geração de dissipadores DEB por tabela (padrão). `BBCALIB` e `BBCALIBLIMPA` atendem ao modo legado de bloco `DISSIPADOR`, ativado com `*BB:DISSIP-DNIT* = nil`; `BBDIAG` diagnostica a leitura de um tubo.

**Como utilizar:**
1. Garanta que o bloco dinâmico de boca esteja no desenho. Se necessário, crie-o com `TEMPLATE_BOCAS.lsp`.
2. Carregue o arquivo com `APPLOAD`.
3. Execute `BOCASBUEIRO`/`BBU` para planta, `BOCASPERFIL`/`BBP` para clicar na pipe no perfil ou `BOCASTUDO`/`BBT` para planta e perfis automaticamente (ENTER seleciona todos os tubos).
4. Confira a posição, orientação, estado de visibilidade e sentido de montante/jusante.
5. No modo legado (`*BB:DISSIP-DNIT* = nil`), use `BBCALIB` para calibrar o encaixe do dissipador, `BBCALIBLIMPA` para limpar a calibração e `BBDIAG` para investigar as propriedades de um tubo.

**Requisitos e limitações:** AutoCAD Civil 3D para Windows, AutoLISP/Visual LISP/ActiveX e Pipe Networks com propriedades de dimensões e extremidades acessíveis. O sentido do fluxo é inferido pelas cotas Z, portanto deve ser conferido manualmente. O agrupamento depende das tolerâncias configuradas. A rotina altera o DWG e deve ser testada em cópia. A versão foi publicada no repositório, mas não foi executada em ambiente AutoCAD/Civil 3D nesta revisão.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada pela leitura dos arquivos do repositório. Compatibilidade e resultados devem ser validados na versão de software utilizada.


---

### SUAVBACIA.lsp

**Arquivo:** [`SUAVBACIA.lsp`](./SUAVBACIA.lsp)  
**Comando / entrada:** `SUAVBACIA`  
**Objetivo:** Suavizar contornos de bacias hidrográficas com aparência em degraus, tipicamente gerados a partir de raster ou MDT, reduzindo vértices e buscando manter a coincidência das divisórias entre bacias vizinhas.

**Funcionamento:** Solicita a seleção de polilinhas leves (`LWPOLYLINE`) e constrói uma topologia de vértices compartilhados. Identifica pontos fixos (encontros de múltiplas bacias, pontas de linhas abertas, quinas não características de degraus, trechos longos e arcos), estima o tamanho de célula a partir do quartil inferior dos comprimentos de segmentos e aplica pontos médios, simplificação Douglas–Peucker e iterações de Chaikin nos trechos elegíveis. Ao final informa a quantidade de polilinhas e vértices processados e a variação percentual da soma das áreas fechadas.

**Como utilizar:** No AutoCAD/Civil 3D para Windows, abra uma cópia do DWG, carregue `SUAVBACIA.lsp` com `APPLOAD` e execute `SUAVBACIA`. Selecione **todas as bacias vizinhas e suas divisórias** que devam permanecer coincidentes. Informe o tamanho da célula do raster (ou aceite a estimativa), a tolerância de simplificação e o número de iterações de arredondamento. Escolha `Copiar` para criar as novas geometrias na layer `BACIAS_SUAVIZADAS` (recomendado para testes) ou `Substituir` para apagar as entidades originais após a criação das substitutas.

**Requisitos e dependências:** AutoCAD/Civil 3D para Windows, AutoLISP/Visual LISP/ActiveX e componente COM `Scripting.Dictionary`; trabalha com polilinhas leves 2D. Os parâmetros internos `*sb-fator-degrau*`, `*sb-prec*`, `*sb-ftol*`, `*sb-nch*`, `*sb-modo*` e `*sb-layer*` podem ser ajustados no código.

**Status:** Arquivo fornecido incluído sem alterações funcionais; não houve validação por execução no AutoCAD/Civil 3D.

**Limitações e cuidados:** A preservação de divisórias compartilhadas é uma intenção do algoritmo e **precisa ser comprovada em teste geométrico**, sobretudo quando as bacias possuem vértices ou segmentações diferentes ao longo da mesma divisa. A identificação de coincidências usa arredondamento de coordenadas a três casas decimais por padrão; confira a compatibilidade com as unidades e a precisão do desenho. A suavização pode alterar áreas e posições dos contornos. O relatório apresenta apenas a variação da **área total** das polilinhas fechadas, não um controle de área por bacia. Use inicialmente o modo `Copiar`, compare geometrias e áreas e só depois considere `Substituir`.

[↑ Voltar ao índice](#índice-de-rotinas)
