# Biblioteca de Automações para Engenharia Civil

Repositório de rotinas para apoiar atividades de projeto, desenho, geoprocessamento e tratamento de dados em engenharia civil. Os arquivos estão organizados por **ambiente/linguagem**, e cada pasta possui documentação com índice, modo de uso, dependências e limitações.

> **Atenção:** as descrições abaixo foram elaboradas a partir da leitura dos arquivos disponíveis no repositório. A presença no catálogo não significa que a rotina foi executada ou validada em todas as versões dos programas. Faça testes em cópias dos projetos antes de executar scripts que alteram desenhos ou dados.

## Catálogo de rotinas

### [Dynamo — Civil 3D](Dynamo/README.md)

| Rotina | Finalidade |
|---|---|
| [Dynamo Identificador de Queda (att)](Dynamo/README.md#dynamo-identificador-de-quedaattdyn) | Calcula a diferença entre cotas de fundo de tubos em estruturas de uma rede e registra o resultado no campo Material. |
| [Fluxo Dynamo Desap](Dynamo/README.md#fluxo-dynamo-desapdyn) | Obtém estações de alinhamentos, filtra estações intermediárias e cria pontos COGO a partir de posições dos alinhamentos. |

### [Lisps — AutoCAD / Civil 3D](Lisps/README.md)

| Rotina | Comando | Finalidade |
|---|---|---|
| [CONT_AREA.lsp](Lisps/README.md#cont_arealsp) | `CONT_AREA` | Exporta áreas de hachuras e polilinhas fechadas para o Excel. |
| [CONT_AREA_POLILINHA.lsp](Lisps/README.md#cont_area_polilinhalsp) | `CONT_AREA` | Exporta a propriedade Área dos objetos selecionados para o Excel, quando disponível. |
| [CONT_COMP.lsp](Lisps/README.md#cont_complsp) | `CONT_COMP` | Exporta comprimentos de polilinhas para o Excel. |
| [GEOIMG.lsp](Lisps/README.md#geoimglsp) | `GEOIMG` | Insere PNG georreferenciado a partir de arquivo PGW. |
| [UnirConectados.lsp](Lisps/README.md#unirconectadoslsp) | `UNIRCON`, `UNIRCONCFG` | Une elementos conectados pelas extremidades em polilinhas. |
| [tlen.lsp](Lisps/README.md#tlenlsp) | `TLEN` | Soma comprimentos/perímetros de objetos selecionados. |

### [QGIS — Python / PyQGIS](QGIS/README.md)

| Rotina | Finalidade |
|---|---|
| [Código GIS Localizador Rodovia](QGIS/README.md#código-gis-localizador-rodoviatxt) | Localiza um trecho por coordenadas e EPSG, ajusta o zoom e exibe marcadores no mapa. |

### [VBA — Microsoft Excel](VBA/README.md)

| Rotina | Finalidade |
|---|---|
| [Macro Automação Perfis](VBA/README.md#macro-automação-perfistxt) | Monta fórmula com dados das colunas E, G e H e apresenta resultados na coluna K. |
| [Macro Lista de Abas Automática Excel](VBA/README.md#macro-lista-de-abas-automática-exceltxt) | Insere os nomes das abas em células consecutivas a partir da célula ativa. |

## Como utilizar

1. Abra a pasta correspondente ao software utilizado.
2. Consulte o [README do Dynamo](Dynamo/README.md), [Lisps](Lisps/README.md), [QGIS](QGIS/README.md) ou [VBA](VBA/README.md).
3. Confira requisitos, entradas, alterações realizadas e limitações antes de carregar ou executar a rotina.
4. Faça backup de desenhos, planilhas e projetos antes de testar uma automação.

## Estrutura

```text
.
├── README.md
├── Dynamo/
│   ├── README.md
│   └── *.dyn
├── Lisps/
│   ├── README.md
│   └── *.lsp
├── QGIS/
│   ├── README.md
│   └── *.txt
└── VBA/
    ├── README.md
    └── *.txt
```

**Observação:** a classificação considera o software de execução. Os fluxos do Dynamo podem conter nós de Python; os scripts do QGIS usam PyQGIS; e os arquivos `.txt` em QGIS/VBA contêm código a ser executado no ambiente indicado.

## Estado da documentação

Documentação produzida por inspeção estática do código; não constitui teste funcional. Versões, configurações e dados de entrada podem afetar o resultado.
