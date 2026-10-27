# QAFAIXA.dll — passo a passo

[← Voltar ao catálogo Dynamo](../README.md) · [Guia do DUP_FAIXA.dyn](GUIA_DUP_FAIXA.md)

Plugin .NET para Civil 3D. Ele monta a **poligonal do perímetro da faixa de domínio**
a partir de vários alinhamentos e escreve o **memorial descritivo** (rumos/azimutes,
distâncias e coordenadas N/E de cada vértice) em um arquivo `.doc`.

Nome interno do assembly: `QAMemorial_faixa_poligonal_generico_v17.dll`.

> **Importante:** o QAFAIXA é uma extensão da **QAMemorial.dll**, que está nesta mesma
> pasta. Ele chama as rotinas internas dela para ler segmentos e escrever o RTF. Sem a
> QAMemorial, os comandos mostram `Nao encontrei os metodos internos da DLL original QAMemorial.`

---

## 1. Instalação

### 1.1 Baixe os arquivos

Baixe as **duas DLLs** desta pasta do repositório. Abra cada arquivo no GitHub e use o
botão **Download raw file** (ícone ⬇):

| Arquivo | Função |
|---|---|
| `QAMemorial.dll` | DLL base: leitura dos alinhamentos e escrita do memorial em RTF |
| `QAFAIXA.dll` | Extensão: comandos `QAFAIXA*` para o perímetro da faixa de domínio |

Salve as duas **na mesma pasta**, de preferência local, por exemplo `C:\QA\Plugins\`.
Não deixe no drive de rede: a pasta local carrega mais rápido e evita o aviso de
segurança.

O QAFAIXA procura a QAMemorial primeiro entre as DLLs já carregadas no Civil 3D e
depois **na mesma pasta onde ele está**. Por isso, mantendo as duas juntas, basta
dar NETLOAD na `QAMemorial.dll` e depois na `QAFAIXA.dll` (passo 1.4).

> A `QAMemorial.dll` publicada aqui é a da pasta interna `QAMemorial_Distribuicao`
> (versão de 04/05/2026). Não misture com a da pasta `QAMemorial_Distribuicao atualizado`,
> que é outra versão e não foi testada com este QAFAIXA.

### 1.2 Desbloqueie as DLLs (só na primeira vez)

DLLs vindas da internet ou da rede podem ser bloqueadas pelo Windows. Para cada uma:
botão direito → **Propriedades** → marque **Desbloquear** → **OK**.

### 1.3 Pasta confiável (opcional, evita o aviso de segurança)

No Civil 3D: **OPTIONS → Files → Trusted Locations → Add** e escolha a pasta da 1.1.

### 1.4 Carregar com NETLOAD

1. No Civil 3D, digite `NETLOAD` e pressione Enter.
2. Escolha **`QAMemorial.dll`** → *Open* → se aparecer o aviso, clique em **Load Once**.
3. Repita o `NETLOAD` e escolha **`QAFAIXA.dll`**.

Repita isso em **cada sessão** do Civil 3D. Para carregar automaticamente, coloque
no `acad.lsp` ou no *Startup Suite* (`APPLOAD` → *Contents*):

```lisp
(command "_.NETLOAD" "C:/QA/Plugins/QAMemorial.dll")
(command "_.NETLOAD" "C:/QA/Plugins/QAFAIXA.dll")
```

---

## 2. Preparação do desenho

1. Os alinhamentos do contorno devem formar uma **poligonal fechada**: o fim de um
   encosta no início do próximo.
2. Para os comandos por nome, use o padrão **`<PREFIXO> <NÚMERO>`** (ex.: `AL 1`,
   `AL 2`…), igual ao do [DUP_FAIXA](GUIA_DUP_FAIXA.md#11-nomeie-os-alinhamentos).
3. (Recomendado) Rode antes o **DUP_FAIXA.dyn**. O QAFAIXA procura COGO Points com
   nome ou descrição `Ponto N`, ou com número de ponto `N`, para usar a coordenada
   exata de cada vértice `PN`.
4. **Salve o DWG.** O memorial é gravado na pasta do desenho.

---

## 3. Qual comando usar?

São 6 rotinas, e cada uma tem um ou mais nomes de comando (atalhos):

| Comando(s) | Como escolhe os alinhamentos | Ordem da poligonal | Quando usar |
|---|---|---|---|
| **`QAFAIXA`**, `QAFAIXAFORCAR`, `QAFAIXANOMEFORCAR` | Por nome (prefixo/início/fim/modo) | **Forçada** na ordem dos nomes, mesmo com folgas | ✅ **Uso padrão.** Mais tolerante a pequenas falhas de encosto |
| `QAFAIXAAUTO`, `QAFAIXANOMES` | Por nome | Automática, por conexão | Nomes sem ordem confiável, mas alinhamentos bem encostados |
| `QAFAIXAORDEM`, `QAFAIXANOMEORDEM` | Por nome | Exata dos nomes | Nomes já em ordem e alinhamentos bem encostados |
| `QAFAIXASEL`, `QAFAIXAW` | Seleção por janela | Automática, por conexão | Alinhamentos sem padrão de nome |
| `QAFAIXASEGUIR`, `QAFAIXA1` | Você clica no **primeiro** e o plugin segue a partir dele | A partir do primeiro | A ordem automática começou no vértice errado |
| `QAFAIXAGEN`, `QAFAIXAG` | Clique em um por um | Exatamente a dos cliques | Controle total e poucos alinhamentos |

---

## 4. Passo a passo de cada comando

### 4.1 `QAFAIXA` (= `QAFAIXAFORCAR` / `QAFAIXANOMEFORCAR`) — recomendado

1. Digite `QAFAIXA` e pressione Enter.
2. **Prefixo dos alinhamentos**: digite `AL` (ou o seu prefixo) e pressione Enter.
3. **Numero inicial**: ex. `1`.
4. **Numero final**: ex. `20`.
5. **Modo de selecao [TODOS/PARES/IMPARES] \<IMPARES\>**: digite a opção, ou só Enter
   para aceitar `IMPARES`.
6. O plugin informa `Gerando forçado na ordem dos nomes: AL 1, AL 3, …`.
7. Se dois alinhamentos seguidos não se encostarem, aparece
   `Aviso: ligacao distante antes de AL x (… m). Gerando mesmo assim.`
   Anote os avisos e confira esses trechos no memorial.
8. No final: `Descricao da faixa de dominio salva em: <caminho>`.

Diferente dos outros comandos, este monta a sequência de segmentos por conta
própria. Por isso **não para** quando há uma folga entre os alinhamentos, e ainda
tenta usar os COGO Points `Ponto N` para acertar as coordenadas.

### 4.2 `QAFAIXAAUTO` (= `QAFAIXANOMES`)

1. Digite `QAFAIXAAUTO`.
2. Responda prefixo, número inicial, número final e modo (como na 4.1).
3. O plugin procura os alinhamentos e **testa a melhor sequência** ligando o fim de
   um ao início do outro (e invertendo quando precisa).
4. Se algum nome não existir:
   `Aviso: alguns alinhamentos nao foram encontrados e foram ignorados: …`
5. Mostra `Alinhamentos usados: …` e grava o memorial.

### 4.3 `QAFAIXAORDEM` (= `QAFAIXANOMEORDEM`)

1. Digite `QAFAIXAORDEM`.
2. Responda prefixo, número inicial, número final e modo.
3. Mostra `Gerando na ordem exata dos nomes: …`.
4. ⚠️ A DLL original **ainda exige** que os alinhamentos se encostem nessa ordem. Se
   não encostarem, use o `QAFAIXA` (4.1).

### 4.4 `QAFAIXASEL` (= `QAFAIXAW`)

1. Digite `QAFAIXASEL`.
2. **Selecione por janela os alinhamentos do contorno da faixa**: faça a janela e
   pressione Enter.
3. O plugin informa quantos alinhamentos achou na seleção (objetos que não são
   alinhamentos são ignorados).
4. Ordena por conexão e grava o memorial.

### 4.5 `QAFAIXASEGUIR` (= `QAFAIXA1`)

1. Digite `QAFAIXASEGUIR`.
2. **Selecione o PRIMEIRO alinhamento correto do perimetro**: clique nele.
3. Responda aos pedidos seguintes de seleção/parâmetros. O plugin monta a sequência
   **começando por esse alinhamento** e segue as conexões.
4. Use este comando quando o `QAFAIXAAUTO` ou o `QAFAIXASEL` gerarem o memorial
   começando no vértice errado.

### 4.6 `QAFAIXAGEN` (= `QAFAIXAG`)

1. Digite `QAFAIXAGEN`.
2. **Selecione o ALINHAMENTO 1 do contorno da faixa, na ordem da poligonal**: clique.
3. A cada clique aparece `Alinhamento adicionado. Total: N`.
4. Continue clicando na ordem do perímetro e pressione **Enter** para finalizar.
5. São necessários **pelo menos 2 alinhamentos**.

---

## 5. O resultado

- Arquivo: **`QAFAIXA_perimetro_faixa_dominio.doc`**, gravado **na pasta do DWG**.
  Se o desenho ainda não foi salvo, o arquivo vai para a pasta *Documentos*.
- Apesar da extensão `.doc`, o conteúdo é **RTF**. Abra no Word e use
  *Salvar como → .docx* se preferir.
- O texto começa com *"O perímetro da faixa de domínio inicia-se nas coordenadas N … e E …"*
  e descreve vértice a vértice (`P1`, `P2`…) com distâncias, até
  *"…fechando a poligonal nas coordenadas N … E …, encerrando a descrição."*
- Cada execução **sobrescreve** o arquivo anterior. Renomeie o arquivo se quiser
  guardar versões.

### Revisão obrigatória

1. Procure (Ctrl+L no Word) a palavra **`VERIFICAR`**. Ela aparece onde o plugin não
   conseguiu recalcular a coordenada de um vértice.
2. Confira se o último vértice fecha no primeiro (`P1`).
3. Compare algumas coordenadas com os COGO Points do desenho.

---

## 6. Mensagens e soluções

| Mensagem | Causa | Solução |
|---|---|---|
| `Nao encontrei os metodos internos da DLL original QAMemorial.` | QAMemorial não carregada nem na mesma pasta | `NETLOAD` da `QAMemorial.dll` antes do QAFAIXA ([1.4](#14-carregar-com-netload)) |
| `Metodo RtfWriter.WrapFaixaDominio nao encontrado.` | Versão da QAMemorial incompatível | Use a `QAMemorial.dll` desta pasta do repositório. Se outra versão já foi carregada na sessão, feche e reabra o Civil 3D |
| `Metodos internos de segmento da DLL original nao encontrados.` | Mesma causa acima (usado pelo `QAFAIXA`) | Idem |
| `A entidade selecionada nao parece ser um Alignment do Civil 3D.` | Clicou em polilinha, texto etc. | Clique no alinhamento |
| `Selecione pelo menos 2 alinhamentos…` | Só um foi escolhido | Selecione mais alinhamentos |
| `Nenhum nome gerado com esses parametros.` | Início/fim/modo não geram números (ex.: PARES de 1 a 1) | Ajuste os números ou o modo |
| `Foram encontrados apenas N alinhamento(s). Confira prefixo/inicio/fim/modo.` | Menos de 2 nomes existem no desenho | Confira os nomes (espaço, zeros à esquerda) |
| `Nao foi possivel montar uma sequencia com pelo menos 2 alinhamentos.` | Alinhamentos não se encostam | Ajuste a geometria ou use o `QAFAIXA` (forçado) |
| `Aviso: conexao/ligacao distante antes de … (x m)` | Folga entre dois alinhamentos | Corrija no desenho se *x* for grande e confira o memorial |
| `Nao foi possivel ler os pontos inicial/final dos alinhamentos.` | Alinhamento sem geometria | Recrie o alinhamento |
| `Aviso: GetAlignmentIds falhou; tentando varrer entidades do ModelSpace.` | Só informativo | Nenhuma ação |
| `Erro no QAFAIXA…: <detalhe>` | Erro inesperado | Anote o detalhe e o comando usado |
