# Bocas de bueiros — guia passo a passo

Este guia acompanha os arquivos `TEMPLATE_BOCAS.lsp` e `BOCAS_BUEIRO.lsp` da biblioteca. A documentação descreve o fluxo de trabalho e deve ser conferida com a versão do código efetivamente carregada no AutoCAD/Civil 3D.

## 1. Para que serve cada arquivo

- **`TEMPLATE_BOCAS.lsp`**: cria os blocos-modelo de bocas de bueiros e o bloco dinâmico usado pela rotina de inserção automática. O bloco dinâmico esperado pela configuração padrão é `BOCA_DNIT_PLANTA_V4`.
- **`BOCAS_BUEIRO.lsp`**: identifica grupos de tubos selecionados em uma Pipe Network, infere montante/jusante pelas cotas das extremidades e insere as bocas. Para tubos que atendem aos critérios configurados, também pode inserir um dissipador de energia.

## 2. Preparação inicial da biblioteca de bocas

Faça esta etapa uma vez por desenho-biblioteca, ou quando precisar recriar os blocos.

1. Abra um **DWG novo de teste**. Não comece pelo desenho de projeto.
2. Confira as unidades com `UNITS` e a variável `INSUNITS`. O código interpreta `6` como metros, `5` como centímetros, `4` como milímetros e, em alguns trechos, `0` como metros.
3. Digite `APPLOAD` e carregue `TEMPLATE_BOCAS.lsp`.
4. Execute `BOCASCADASTRO` para acessar o fluxo de cadastro/inserção de modelos; siga as opções solicitadas pelo próprio comando.
5. Para criar a biblioteca de blocos estáticos, execute `BOCASCADBASE`, se disponível na versão carregada.
6. Para criar o bloco dinâmico consumido pela rotina automática, execute `BOCASCADDIN`. A versão pode oferecer também o comando alternativo `BOCASADDIN`.
7. Confira visualmente os blocos gerados e suas dimensões. A edição de blocos dinâmicos pode depender dos prompts e da versão/idioma do AutoCAD.
8. Salve o DWG como arquivo de biblioteca. Depois, abra ou insira essa biblioteca no desenho de trabalho, garantindo que o bloco dinâmico esteja disponível.

### Atenção aos modelos e às dimensões

O cabeçalho do template cita o álbum DNIT IPR-736, Emenda 3, para modelos BNAR/BNAA/BEAA. O próprio código informa que alguns diâmetros maiores são extrapolações, não dimensões respaldadas diretamente pelo álbum. Não trate o bloco como validação de projeto: confira a geometria com o desenho de referência aplicável e os critérios do empreendimento.

## 3. Inserção automática das bocas nos tubos

### Antes de executar

- O desenho deve conter uma Pipe Network com os tubos do bueiro modelados e selecionáveis.
- Os tubos que pertencem ao mesmo bueiro devem ter eixos paralelos e espaçamento compatível com as tolerâncias de agrupamento.
- O bloco de boca configurado deve estar disponível no desenho. Por padrão, a rotina procura `BOCA_DNIT_PLANTA_V4`.
- Se for usar dissipadores, disponibilize o bloco `DISSIPADOR` ou esteja preparado para escolhê-lo/informá-lo quando solicitado.
- Salve uma cópia do DWG antes de rodar a rotina.

### Passo a passo

1. Abra o desenho no Civil 3D e confirme que as redes e os tubos estão corretos.
2. Digite `APPLOAD` e carregue `BOCAS_BUEIRO.lsp`.
3. Confira as variáveis de configuração no início do arquivo, se necessário:
   - `*BB:BLK-BOCA*`: nome do bloco dinâmico de boca;
   - `*BB:BLK-DISSIP*`: nome do bloco do dissipador;
   - `*BB:ROT-BOCA*` e `*BB:ROT-DISSIP*`: ajustes de orientação; `nil` habilita a tentativa automática;
   - `*BB:DIAM-LIMITE*` e `*BB:DISSIP-ATE-LIMITE*`: regra de diâmetro para dissipador;
   - `*BB:LAYER-BOCA*` e `*BB:LAYER-DISSIP*`: camadas de destino;
   - `*BB:ANG-TOL*` e `*BB:FATOR-AGRUP*`: tolerâncias de agrupamento;
   - `*BB:USAR-Z*`: controla se as bocas acompanham a cota Z do tubo.
4. Digite `BOCASBUEIRO` ou o atalho `BBU`.
5. Selecione os tubos de um ou mais bueiros. Para evitar agrupar tubos de obras diferentes por proximidade, prefira processar cada conjunto separadamente quando houver dúvida.
6. Responda aos prompts apresentados pela rotina, incluindo a confirmação/ajuste de orientação do dissipador quando habilitada.
7. Aguarde a criação das bocas a montante e a jusante e dos dissipadores elegíveis.
8. Confira no desenho se o tipo e o tamanho do bloco correspondem ao tubo, se as alas estão voltadas para o lado correto e se o dissipador está alinhado com o fluxo.
9. Se houver comportamento inesperado, execute `BBDIAG` para obter diagnóstico e revise as configurações antes de repetir o processo.

## 4. Como a rotina determina montante e jusante

A rotina compara as cotas Z de `StartPoint` e `EndPoint`. A extremidade de menor cota é considerada **jusante** e a outra, **montante**. Essa é uma inferência geométrica, não uma verificação hidráulica: confira o sentido real do fluxo, especialmente quando as cotas são iguais, incompletas ou não representam o perfil projetado.

Tubos paralelos e próximos são agrupados como bueiro simples, duplo ou triplo. O resultado depende das tolerâncias configuradas e da qualidade da modelagem da Pipe Network.

## 5. Dissipador de energia

O dissipador é opcional. Na configuração padrão, a rotina considera tubos de forma tubular com diâmetro até o limite configurado (1,50 m, inclusive, conforme a variável de configuração). O afastamento, o encaixe e a escala podem ser automáticos ou definidos nas variáveis `*BB:DISSIP-*`.

Confira a orientação, o ponto de encaixe e a compatibilidade geométrica no desenho. A inserção automática não substitui o dimensionamento hidráulico nem a verificação dos detalhes construtivos.

## 6. Problemas comuns

- **Bloco de boca não encontrado:** carregue/crie a biblioteca com `TEMPLATE_BOCAS.lsp` e confira o nome em `*BB:BLK-BOCA*`.
- **Estado de visibilidade incorreto ou ausente:** confirme que o bloco dinâmico contém os estados esperados para o tipo e o diâmetro dos tubos.
- **Bocas viradas para o lado errado:** confira o eixo do tubo e os ajustes `*BB:ROT-BOCA*`; valide a convenção de orientação do bloco.
- **Tubos agrupados incorretamente:** diminua a área de seleção e revise `*BB:ANG-TOL*` e `*BB:FATOR-AGRUP*`.
- **Dissipador desalinhado ou afastado:** confira `*BB:ROT-DISSIP*`, `*BB:DISSIP-AFAST*`, `*BB:DISSIP-ENCAIXE*` e a escala.
- **Rotina falha durante criação de bloco dinâmico:** teste em um DWG vazio e verifique os prompts suportados pela versão/idioma do AutoCAD.

## 7. Requisitos e limites

- AutoCAD Civil 3D para Windows, AutoLISP/Visual LISP e suporte ActiveX/COM.
- Para a inserção automática, redes de tubulação (Pipe Networks) com propriedades de dimensões e extremidades acessíveis.
- Os comandos podem modificar o DWG, criar camadas/blocos e inserir entidades. Trabalhe em cópia e confira os resultados.
- Esta documentação não representa teste de execução. Antes de usar em projeto, valide os blocos, unidades, cotas, orientação e critérios hidráulicos/construtivos.
