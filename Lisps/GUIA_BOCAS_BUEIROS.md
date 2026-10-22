# Bocas de bueiros — guia passo a passo

Este guia corresponde às versões atuais de `TEMPLATE_BOCAS.lsp` e `BOCAS_BUEIRO.lsp` (arquivo recebido como `BOCAS_BUEIRO_4.lsp`, mantido no repositório com o nome padronizado). A versão atual da rotina automática informa **v11** no carregamento.

## 1. O que cada rotina faz

- **`TEMPLATE_BOCAS.lsp`**: cria blocos-modelo de bocas de bueiros, incluindo o bloco dinâmico `BOCA_DNIT_PLANTA_V4`, utilizado pela rotina automática. O cabeçalho descreve modelos tubulares BNAA 01–11 e celulares quadrados BNAA 12–41, com geometrias de referência DNIT e dimensões extrapoladas identificadas no próprio código.
- **`BOCAS_BUEIRO.lsp`**: seleciona tubos de Pipe Networks, agrupa tubos paralelos e próximos para identificar bueiros simples/duplos/triplos, infere montante e jusante pelas cotas e insere bocas orientadas. Para tubulares dentro do limite configurado, pode inserir dissipador de energia.
- **Comandos de calibração**: a versão atual inclui `BBCALIB` e `BBCALIBLIMPA`, além de `BBDIAG` para diagnóstico.

## 2. Criar a biblioteca de blocos

Faça esta preparação em um DWG separado, novo e vazio. Não comece pelo desenho definitivo do projeto.

1. Abra um DWG novo no AutoCAD/Civil 3D.
2. Confira as unidades do desenho com `UNITS` e a variável `INSUNITS`. O código interpreta 6 como metros, 5 como centímetros, 4 como milímetros e 0 como metros em seu cabeçalho/configuração.
3. Digite `APPLOAD` e carregue `TEMPLATE_BOCAS.lsp).
4. Execute `BOCASCADASTRO` para inserir um modelo de boca conforme as opções apresentadas pelo comando.
5. Para criar os blocos estáticos de cadastro, execute `BOCASCADBASE`.
6. Para criar o bloco dinâmico utilizado pela inserção automática, execute `BOCASCADDIN`. O comando alternativo `BOCASADDIN` também é definido no arquivo.
7. Confira o bloco dinâmico gerado, principalmente os estados de visibilidade e as dimensões. O nome esperado pela configuração padrão da rotina automática é `BOCA_DNIT_PLANTA_V4`.
8. Salve o DWG como biblioteca de blocos e disponibilize-o no desenho de trabalho (por exemplo, inserindo o bloco ou abrindo a biblioteca e copiando o bloco para o projeto).

O arquivo também contém os comandos legados `BOCASTESTE`, `BOCASDNIT` e `BOCASBASE`; a implementação final do arquivo redefine alguns desses nomes. Para o fluxo recomendado, priorize `BOCASCADASTRO`, `BOCASCADBASE` e `BOCASCADDIN`.

### Referência e validação dimensional

O cabeçalho cita o DNIT IPR-736, Emenda 3. Ele indica que diâmetros de 2,00, 2,50 e 3,00 m são extrapolados e não têm respaldo direto declarado no álbum DNIT. Confira os desenhos e as dimensões com a referência aplicável ao empreendimento; os blocos não substituem a validação de projeto.

## 3. Inserção automática de bocas no Civil 3D

### Pré-requisitos

- Pipe Network contendo os tubos do bueiro.
- Bloco dinâmico de boca presente no desenho, por padrão `BOCA_DNIT_PLANTA_V4`.
- Bloco de dissipador, se desejar essa inserção; a configuração padrão procura `DISSIPADOR`.
- Cópia de segurança do DWG antes da execução.

### Passo a passo

1. Abra o DWG no Civil 3D e confira as redes de tubulação e as dimensões dos tubos.
2. Se ainda não tiver o bloco dinâmico no desenho, crie-o com `TEMPLATE_BOCAS.lsp` e insira/copie o bloco para o desenho atual.
3. Digite `APPLOAD` e carregue `BOCAS_BUEIRO.lsp` (a versão recebida como `BOCAS_BUEIRO_4.lsp` foi publicada no repositório sob o nome `BOCAS_BUEIRO.lsp`).
4. Se necessário, revise as variáveis de configuração no início do LISP:
   - `*BB:BLK-BOCA*`: nome do bloco dinâmico de boca;
   - `*BB:BLK-DISSIP*`: nome do bloco do dissipador;
   - `*BB:ROT-BOCA*` e `*BB:ROT-DISSIP*`: ângulos de orientação; `nil` habilita a tentativa automática;
   - `*BB:DISSIP-AFAST*`, `*BB:DISSIP-FOLGA*` e `*BB:DISSIP-ENCAIXE*`: afastamento e encaixe do dissipador;
   - `*BB:DISSIP-ESCALAR*` e `*BB:DISSIP-FATOR-LARG*`: ajuste de escala/largura do dissipador;
   - `*BB:DIAM-LIMITE*` e `*BB:DISSIP-ATE-LIMITE*`: limite de diâmetro para inserir dissipador;
   - `*BB:TOL-DIAM*`, `*BB:TOL-Z*`, `*BB:ANG-TOL*` e `*BB:FATOR-AGRUP*`: tolerâncias de conferência e agrupamento;
   - `*BB:USAR-Z*`: controla se as bocas acompanham a cota Z dos tubos.
5. Digite `BOCASBUEIRO` ou o atalho `BBU`.
6. Selecione os tubos que deseja processar. Tubos paralelos e próximos podem ser agrupados em um único bueiro; selecione conjuntos separadamente se houver risco de misturar obras distintas.
7. Responda aos prompts apresentados pela rotina. Quando a confirmação automática de orientação do dissipador estiver habilitada, confira a primeira inserção e escolha a correção sugerida pelo comando, se necessário.
8. Confira visualmente as bocas a montante e jusante, os estados de visibilidade, a rotação e a posição dos dissipadores.
9. Se precisar ajustar o encaixe do dissipador, use `BBCALIB` e siga as solicitações do comando para calibrar a relação entre a boca e o dissipador. Para apagar a calibração gravada e voltar ao modo automático, execute `BBCALIBLIMPA`.
10. Para investigar a leitura de um tubo, execute `BBDIAG`, selecione **um** tubo e consulte o texto de diagnóstico no histórico de comandos (F2).

## 4. Como montante e jusante são determinados

A rotina lê as propriedades e as extremidades dos tubos. A extremidade com menor cota Z é considerada jusante; a extremidade de maior cota é considerada montante, respeitando a tolerância configurada em `*BB:TOL-Z*`. Essa é uma inferência baseada na geometria/cotas, não uma verificação hidráulica independente. Confira o sentido do fluxo em casos de cotas iguais, dados incompletos ou perfil que não represente a condição projetada.

O agrupamento de tubos em bueiros simples, duplos e triplos depende do paralelismo e da distância entre eles, conforme `*BB:ANG-TOL*` e `*BB:FATOR-AGRUP*). Verifique o resultado se houver tubos próximos pertencentes a obras diferentes.

## 5. Dissipadores de energia

A configuração padrão utiliza o nome de bloco `DISSIPADOR` e considera bueiros tubulares com diâmetro até 1,50 m, inclusive, conforme `*BB:DIAM-LIMITE*` e `*BB:DISSIP-ATE-LIMITE*). A escala pode ser ajustada para acompanhar a largura da boca. Distância, folga, encaixe e rotação são configuráveis.

Confira a orientação e o encaixe visual no desenho. A inserção automática não substitui o dimensionamento hidráulico nem a verificação dos detalhes construtivos.

## 6. Diagnóstico e problemas comuns

- **Bloco de boca não encontrado:** confira se `BOCA_DNIT_PLANTA_V4` está no desenho e se `*BB:BLK-BOCA*` aponta para o nome correto.
- **Estado de visibilidade errado:** verifique o bloco dinâmico criado por `BOCASCADDIN` e se os estados necessários estão disponíveis.
- **Boca girada para o lado errado:** confira a orientação geométrica do bloco e revise `*BB:ROT-BOCA*`.
- **Tubos agrupados incorretamente:** selecione menos tubos por execução e revise as tolerâncias de paralelismo e agrupamento.
- **Dissipador desalinhado ou com encaixe inadequado:** execute `BBCALIB`, confira os parâmetros de rotação, afastamento e escala; para remover a calibração salva, use `BBCALIBLIMPA`.
- **Leitura de tubo inesperada:** execute `BBDIAG` em um tubo e examine o resultado no histórico de comandos com F2.
- **Erro ao criar o bloco dinâmico:** teste em um DWG vazio e confira os prompts suportados pela versão e pelo idioma do AutoCAD.

## 7. Requisitos e limitações

- AutoCAD Civil 3D para Windows, AutoLISP/Visual LISP e suporte ActiveX/COM.
- A inserção automática depende de Pipe Networks com propriedades de dimensões e extremidades acessíveis.
- A criação de blocos dinâmicos pode variar conforme versão/idioma do AutoCAD.
- Os comandos criam ou alteram blocos, camadas e entidades. Trabalhe em cópia e confira unidades, dimensões, orientação, cotas e critérios construtivos antes do uso em projeto.
- Os arquivos foram substituídos no repositório, mas não foram executados em ambiente AutoCAD/Civil 3D durante esta atualização.
