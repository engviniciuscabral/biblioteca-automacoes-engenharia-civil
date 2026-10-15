# QGIS — Catálogo de automações

Scripts PyQGIS para tarefas de localização e visualização geoespacial.

[← Voltar ao catálogo geral](../README.md)

## Índice de rotinas

| Arquivo | Comando / entrada | Finalidade |
|---|---|---|
| [`Código GIS Localizador Rodovia.txt`](./C%C3%B3digo%20GIS%20Localizador%20Rodovia.txt) | `LocalizadorRodovia` | Localização de um trecho por coordenadas no QGIS. |

## Documentação das rotinas

### 1. Código GIS Localizador Rodovia.txt

**Arquivo:** [`Código GIS Localizador Rodovia.txt`](./C%C3%B3digo%20GIS%20Localizador%20Rodovia.txt)  
**Comando / entrada:** `LocalizadorRodovia`  
**Objetivo:** Localização de um trecho por coordenadas no QGIS.

**Funcionamento:** Script PyQGIS com interface gráfica para informar coordenadas inicial e final, escolher código EPSG, transformar para o SRC do projeto, ajustar o zoom e marcar as extremidades no mapa.

**Como utilizar:** Abra o QGIS, confira o SRC do projeto e execute o conteúdo do arquivo no console Python do QGIS; informe coordenadas e EPSG na janela.

**Requisitos e dependências:** QGIS com PyQGIS e PyQt disponíveis.

**Status:** Disponível na biblioteca; funcionamento não verificado por execução nesta revisão.

**Limitações e cuidados:** Use coordenadas compatíveis com o EPSG informado. Os marcadores são elementos temporários do mapa; o script não cria necessariamente uma camada vetorial persistente.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada pela leitura dos arquivos do repositório. Compatibilidade e resultados devem ser validados na versão de software utilizada.
