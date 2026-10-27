# DUP_FAIXA.dyn — passo a passo

[← Voltar ao catálogo Dynamo](../README.md) · [Guia do QAFAIXA.dll](GUIA_QAFAIXA.md)

Este script Dynamo para Civil 3D lê um grupo de alinhamentos pelo nome e cria um
**COGO Point em cada vértice** (início, fim e cada mudança de tangente/curva). Os
pontos recebem nomes sequenciais (`Ponto 1`, `Ponto 2`…), e as labels são giradas
perpendicularmente ao alinhamento.

Esses pontos servem de referência para o plugin [QAFAIXA](GUIA_QAFAIXA.md), que procura
COGO Points chamados `Ponto N` para confirmar as coordenadas dos vértices do memorial.

---

## 1. Antes de começar

### 1.1 Nomeie os alinhamentos

O script procura os alinhamentos pelo nome exato, no formato **`<PREFIXO> <NÚMERO>`**,
com um espaço entre o prefixo e o número:

| Certo | Errado |
|---|---|
| `AL 1`, `AL 2`, `AL 3` | `AL1`, `AL-1`, `AL 01` |

- Maiúsculas e minúsculas não importam (`al 1` também é aceito).
- Espaços sobrando no início ou no fim do nome são ignorados.
- Para renomear: *Prospector → Alignments* → botão direito → *Properties → Information → Name*.

### 1.2 Confira a ordem

O script percorre os números **em ordem crescente**, do `Início` ao `Fim`, e a
numeração dos pontos segue essa ordem. Portanto `AL 1`, `AL 2`… devem seguir a
sequência do contorno da faixa.

### 1.3 Salve o desenho

O script **grava objetos no DWG** (COGO Points). Salve antes de rodar para poder
voltar atrás com segurança.

---

## 2. Abrir o script

1. No Civil 3D, abra o desenho com os alinhamentos.
2. Na faixa de opções, vá em **Manage → Visual Programming → Dynamo**.
3. No Dynamo, use **File → Open** e escolha `DUP_FAIXA.dyn`.
4. Confirme no rodapé que o modo de execução está em **Manual**. O arquivo já vem
   salvo assim, e isso evita criar pontos por acidente enquanto você edita.

Se aparecer o aviso de motor Python (Dynamo 2.13 ou mais novo), veja
[Problemas comuns](#problemas-comuns).

---

## 3. Preencher as entradas

Os quatro nós de entrada ficam no canto esquerdo do gráfico:

| Nó | Valor no arquivo | O que significa |
|---|---|---|
| **String - Prefixo** | `AL` | Parte do nome antes do número |
| **Number - Inicio** | `1` | Primeiro número a buscar |
| **Number - Fim** | `3` | Último número a buscar (entra na busca) |
| **String - Modo TODOS/PARES/IMPARES** | `IMPARES` | Filtro dos números |

### Como o modo funciona

| Modo | Início = 1, Fim = 6 busca… |
|---|---|
| `TODOS` | AL 1, AL 2, AL 3, AL 4, AL 5, AL 6 |
| `PARES` (ou `PAR`) | AL 2, AL 4, AL 6 |
| `IMPARES` (ou `IMPAR`) | AL 1, AL 3, AL 5 |

> Use `PARES`/`IMPARES` quando os alinhamentos de um lado da faixa forem ímpares e
> os do outro lado forem pares. Assim você gera os pontos de **um lado por vez**.
> Qualquer valor diferente desses vira `TODOS`.

Se `Início` for maior que `Fim`, a busca anda de trás para frente, e a numeração
dos pontos também fica invertida.

---

## 4. Rodar

1. Clique em **Run**, no rodapé do Dynamo.
2. Aguarde a mensagem *Run completed*.
3. Confira os dois nós **Watch**:
   - **Watch - Pontos de Geometria**: lista dos pontos gerados.
   - **Watch - Ajuste Labels**: mostra uma mensagem como
     `Labels ajustadas em 96 de 96 COGO Points…`. Se os dois números forem iguais,
     todas as labels foram ajustadas.

---

## 5. O que o script faz (por dentro)

```
Prefixo/Início/Fim/Modo
        │
        ▼
[Python] Buscar alinhamentos via API Civil
   • monta a lista de nomes (ex.: "AL 1", "AL 3")
   • encontra cada um no desenho
   • lê as estacas de início/fim do alinhamento e de cada trecho interno
   • calcula X,Y em cada estaca (offset 0) e o ângulo da tangente
        │
        ├── item 0 → pontos ───────────────┐
        ├── item 1 → nomes ("Ponto N") ───┤
        ├── item 2 → descrições ──────────┤
        ▼                                 ▼
[Python] Ajustar Labels        CogoPoint.ByGeometry (layer "0")
   • aplica nome e descrição         │
   • gira a label +90°  ◄────────────┘
   • desvira o texto se ficar de cabeça para baixo
   • afasta a label 18 m ao longo do alinhamento
```

### Numeração dos pontos

- Os pontos são numerados a partir de **2**, na ordem: alinhamento por alinhamento
  e, dentro de cada um, da estaca menor para a maior.
- O **último ponto do último alinhamento** é renomeado para **`Ponto 1`**. Ele é o
  vértice de fechamento e de partida do perímetro.

Exemplo com `AL 1` (3 vértices) e `AL 3` (2 vértices):

| Alinhamento | Estaca | Nome |
|---|---|---|
| AL 1 | início | Ponto 2 |
| AL 1 | meio | Ponto 3 |
| AL 1 | fim | Ponto 4 |
| AL 3 | início | Ponto 5 |
| AL 3 | fim | **Ponto 1** |

### Valores fixos no código

Ficam dentro do nó **Ajustar Labels Perpendiculares**. Para mudar, dê dois cliques
no nó e edite as primeiras linhas:

| Variável | Padrão | Efeito |
|---|---|---|
| `deslocamento_label` | `0.0` | Afastamento perpendicular ao alinhamento, em metros |
| `deslocamento_ao_longo` | `-18.0` | Afastamento ao longo do alinhamento, em metros (negativo = para trás) |
| `rotacao_extra_graus` | `90.0` | Rotação somada à direção do alinhamento |
| `manter_texto_legivel` | `True` | Gira 180° quando o texto ficaria de cabeça para baixo |

A **layer** dos pontos é definida no nó `String` ligado ao `CogoPoint.ByGeometry`
(padrão `0`).

> Os nós `Number` (1000000) e `Boolean` (True) que aparecem soltos no gráfico **não
> estão ligados a nada** e não afetam o resultado.

---

## 6. Depois de rodar

1. Confira no desenho se há um ponto em cada vértice e se as labels estão legíveis.
2. Se os alinhamentos estiverem encostados (o fim de `AL 1` coincide com o início de
   `AL 3`), **dois pontos serão criados no mesmo lugar**. O script só elimina
   repetições dentro de um mesmo alinhamento. Apague o ponto duplicado, se precisar.
3. Siga para o [QAFAIXA](GUIA_QAFAIXA.md) para gerar o memorial.

### Rodar de novo

Cada execução **cria pontos novos**. Antes de rodar outra vez, apague os pontos da
execução anterior para não ficar com nomes repetidos.

---

## Problemas comuns

| Sintoma no Watch / Dynamo | Causa provável | Solução |
|---|---|---|
| `Nao encontrou alinhamento: AL 2` | Nome diferente do esperado | Verifique o espaço e os zeros à esquerda ([1.1](#11-nomeie-os-alinhamentos)) |
| `Alinhamento sem estacas legiveis` | Alinhamento vazio ou corrompido | Recrie o alinhamento ou use *Alignment → Edit Geometry* |
| `PointLocation falhou na estaca…` | Estaca fora do alinhamento | Normalmente é inofensivo, porque o ponto é pulado. Confira se faltou algum vértice |
| Lista de pontos vazia | Nenhum nome bateu, ou o modo filtrou tudo | Revise prefixo, início, fim e modo |
| `label nao moveu` / `label nao girou` | O estilo do ponto bloqueia arrastar ou girar a label | Use um *Point Label Style* que permita arrastar e girar |
| Erro de motor Python ao abrir (Dynamo 2.13+) | Os scripts usam IronPython2 | Instale o pacote **DynamoIronPython2.7** (*Packages → Search*) e escolha *IronPython2* no menu de cada nó Python |
| `Erro geral API Civil` | Desenho travado ou outro comando ativo | Pressione Esc no Civil 3D e rode de novo |
