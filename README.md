# Biblioteca de Automações para Engenharia Civil

Acervo de ferramentas e scripts para automatizar tarefas de engenharia, desenho, geoprocessamento e planilhas. Este repositório reúne códigos reutilizáveis, com histórico de versões e documentação de consulta rápida.

## Planejamento de melhorias

O [plano de evolução da biblioteca](./PLANEJAMENTO_PROJETO.md) reúne um template de GitHub Projects em formato de tabela (Table), backlog priorizado e Issues para correções, validações e novas funcionalidades.

## Como utilizar

1. Escolha uma categoria abaixo e abra o respectivo catálogo.
2. Consulte objetivo, comando, requisitos, instruções e limitações da rotina.
3. Baixe o arquivo desejado e teste em cópia de seus dados ou projeto antes de utilizá-lo em produção.
4. Registre melhorias em commits com mensagens descritivas.

## Catálogo por linguagem / software

| Categoria | Tecnologias | Rotinas | Documentação |
|---|---|---:|---|
| **Dynamo** | Dynamo / Civil 3D / .NET | 5 | [Ver catálogo](./Dynamo/README.md) |
| **Lisps** | AutoLISP / AutoCAD / Civil 3D | 13 | [Ver catálogo](./Lisps/README.md) |
| **QGIS** | PyQGIS / QGIS | 1 | [Ver catálogo](./QGIS/README.md) |
| **Python** | Python / Tkinter / NumPy / Matplotlib | 1 | [Ver catálogo](./Python/README.md) |
| **VBA** | VBA / Excel | 3 | [Ver catálogo](./VBA/README.md) |

## Índice completo de ferramentas

### [Dynamo](./Dynamo/README.md)

| Rotina | Descrição |
|---|---|
| [`Dynamo Identificador de Queda(att).dyn`](./Dynamo/Dynamo%20Identificador%20de%20Queda(att).dyn) | Identificação e registro de quedas em estruturas de redes de drenagem. |
| [`Fluxo Dynamo Desap.dyn`](./Dynamo/Fluxo%20Dynamo%20Desap.dyn) | Automação de pontos ao longo de alinhamentos para fluxo de desapropriação. |
| [`Criar_Valetas_Eixo_Saia_3m_V48.dyn`](./Dynamo/Criar_Valetas_Eixo_Saia_3m_V48.dyn) | Análise de drenagem lateral e criação de valetas de corte/aterro no Civil 3D, com saídas, dissipadores e relatórios CSV. |
| [`DUP_FAIXA.dyn`](./Dynamo/Faixa%20de%20Dominio/DUP_FAIXA.dyn) | COGO Points `Ponto N` nos vértices dos alinhamentos da faixa de domínio; [guia passo a passo](./Dynamo/Faixa%20de%20Dominio/GUIA_DUP_FAIXA.md). |
| [`QAFAIXA.dll`](./Dynamo/Faixa%20de%20Dominio/QAFAIXA.dll) | Plugin .NET (`NETLOAD` → `QAFAIXA`): memorial descritivo do perímetro da faixa de domínio; requer [`QAMemorial.dll`](./Dynamo/Faixa%20de%20Dominio/QAMemorial.dll), incluída na mesma pasta; [guia passo a passo](./Dynamo/Faixa%20de%20Dominio/GUIA_QAFAIXA.md). |

### [Lisps](./Lisps/README.md)

| Rotina | Descrição |
|---|---|
| [`CONT_AREA.lsp`](./Lisps/CONT_AREA.lsp) | Exportação de áreas de hachuras e polilinhas fechadas para Excel. |
| [`CONT_AREA_POLILINHA.lsp`](./Lisps/CONT_AREA_POLILINHA.lsp) | Exportação de áreas dos objetos selecionados para Excel. |
| [`COTAS_TALVEGUES.lsp`](./Lisps/COTAS_TALVEGUES.lsp) | Exportação de cotas e distâncias ao longo de perfis de talvegues do Civil 3D. |
| [`CONT_COMP.lsp`](./Lisps/CONT_COMP.lsp) | Exportação dos comprimentos de polilinhas selecionadas para Excel. |
| [`GEOIMG.lsp`](./Lisps/GEOIMG.lsp) | Inserção de imagem PNG georreferenciada com arquivo PGW no AutoCAD. |
| [`UnirConectados.lsp`](./Lisps/UnirConectados.lsp) | União de entidades lineares conectadas por extremidades. |
| [`TEXTO_BACIA_2.lsp`](./Lisps/TEXTO_BACIA_2.lsp) | Criação e atualização de chamadas MLEADER de bacias com dados de CSV. |
| [`BACIAS_QUADRO.lsp`](./Lisps/BACIAS_QUADRO.lsp) | Numeração de bacias por MLEADER e geração de quadro-resumo a partir de CSV. |
| [`BUEIROS_PERFIL.lsp`](./Lisps/Bueiros%20Perfil/BUEIROS_PERFIL.lsp) | Lançamento de bueiros projetados no eixo e na vista de perfil do Civil 3D, com desenho e legenda; referência `TOPO` ajustada ao topo interno da seção. [Arquivos de exemplo](./Lisps/Bueiros%20Perfil/). |
| [`tlen.lsp`](./Lisps/tlen.lsp) | Soma dos comprimentos de entidades selecionadas. |
| [`TEMPLATE_BOCAS.lsp`](./Lisps/TEMPLATE_BOCAS.lsp) | DNIT V4: 32 variantes de bocas (incluindo 9 tubulares extrapoladas), com `BOCA_DNIT_PLANTA_V4`; [guia passo a passo](./Lisps/GUIA_BOCAS_BUEIROS.md). |
| [`BOCAS_BUEIRO.lsp`](./Lisps/BOCAS_BUEIRO.lsp) | Versão v13: bocas em planta e perfil (`BBU`/`BBP`), modo combinado (`BBT`) e dissipadores DEB por tabela; [guia passo a passo](./Lisps/GUIA_BOCAS_BUEIROS.md). |
| [`SUAVBACIA.lsp`](./Lisps/SUAVBACIA.lsp) | Suavização de contornos de bacias derivados de raster/MDT por pontos médios, Douglas–Peucker e Chaikin; comando `SUAVBACIA`. |

### [Python](./Python/README.md)

| Rotina | Descrição |
|---|---|
| [`hut_goinfra.py`](./Python/hut_goinfra.py) | Aplicação gráfica para cálculo hidrológico com HUT, chuva efetiva SCS/CN e hidrogramas de projeto (caso implementado: A > 20 km² e Tc < 24 h). |

### [QGIS](./QGIS/README.md)

| Rotina | Descrição |
|---|---|
| [`Código GIS Localizador Rodovia.txt`](./QGIS/C%C3%B3digo%20GIS%20Localizador%20Rodovia.txt) | Localização de um trecho por coordenadas no QGIS. |

### [VBA](./VBA/README.md)

| Rotina | Descrição |
|---|---|
| [`Macro Automação Perfis.bas`](./VBA/Macro%20Automa%C3%A7%C3%A3o%20Perfis.bas) | Cálculo automatizado de uma fórmula em planilha de perfis. |
| [`Macro Lista de Abas Automática Excel.bas`](./VBA/Macro%20Lista%20de%20Abas%20Autom%C3%A1tica%20Excel.bas) | Versão legada: lista os nomes de todas as abas do Excel. |
| [`ListarAbasOndeEuClicar.bas`](./VBA/ListarAbasOndeEuClicar.bas) | Versão atual: lista somente planilhas com nomes iniciados por BC seguido de um dígito. |

## Padrão de documentação

Cada pasta contém um `README.md` com índice de arquivos e seções individuais de **objetivo**, **funcionamento**, **como utilizar**, **requisitos**, **status** e **limitações**. A documentação é baseada na leitura do código; não equivale a testes de execução.

## Boas práticas

- Mantenha os códigos-fonte e seus nomes originais, quando possível.
- Utilize branches e commits para registrar alterações.
- Faça cópias de segurança antes de executar rotinas que alterem desenhos ou planilhas.
- Não armazene credenciais, informações confidenciais ou arquivos de clientes sem autorização.
- Verifique unidades, sistema de coordenadas, versão do software e dependências antes de usar uma rotina.

## Observações

As duas variantes de `CONT_AREA` definem o **mesmo comando**; consulte as diferenças no catálogo de Lisps. As rotinas VBA são armazenadas em módulos `.bas` para facilitar a importação no editor VBA e o reconhecimento da linguagem pelo GitHub.

