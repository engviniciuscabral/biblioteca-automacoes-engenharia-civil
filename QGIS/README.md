# Rotinas QGIS — Python / PyQGIS

## Índice

1. [Código GIS Localizador Rodovia.txt](#código-gis-localizador-rodoviatxt)

## Código GIS Localizador Rodovia.txt

**Nome da rotina:** Localizador de trecho por coordenadas  
**Software:** QGIS  
**Linguagem:** Python / PyQGIS com interface PyQt  
**Objetivo:** Localizar visualmente um trecho definido por duas coordenadas, mesmo quando o sistema de referência informado difere do SRC do projeto.

**Funcionamento:** abre uma janela para entrada das coordenadas **E (Leste)** e **N (Norte)** do início e do fim, além de um código **EPSG**. Converte os dois pontos do SRC informado para o SRC do projeto, calcula um retângulo que engloba os pontos, amplia sua extensão para enquadramento e ajusta o zoom do mapa. Cria um marcador verde no início e vermelho no fim; permite mostrar ou ocultar esses marcadores.

**Como utilizar:** abra o QGIS e confira o SRC do projeto; acesse o **Console Python** do QGIS; carregue e execute o código de [Código GIS Localizador Rodovia.txt](C%C3%B3digo%20GIS%20Localizador%20Rodovia.txt); informe as coordenadas e o EPSG na janela; acione a localização e confira os marcadores.

**Dependências:** QGIS com API `qgis.core`, `qgis.gui` e PyQt disponíveis no Console Python; SRC de origem e de projeto válidos.

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** a ferramenta **não identifica automaticamente uma rodovia nem traça um percurso**: ela enquadra dois pontos informados. É necessário conhecer coordenadas e EPSG corretos. Os marcadores são elementos temporários do canvas, não uma camada vetorial persistente. Verifique as unidades e a ordem E/N.

---

[Voltar ao catálogo geral](../README.md)
