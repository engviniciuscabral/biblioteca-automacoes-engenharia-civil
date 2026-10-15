# Rotinas Dynamo — Autodesk Civil 3D

Fluxos `.dyn` para automação de tarefas de projeto no Civil 3D. Os dois arquivos contêm nós e/ou scripts Python incorporados ao Dynamo.

## Índice

1. [Dynamo Identificador de Queda(att).dyn](#dynamo-identificador-de-quedaattdyn)
2. [Fluxo Dynamo Desap.dyn](#fluxo-dynamo-desapdyn)

## Dynamo Identificador de Queda(att).dyn

**Nome da rotina:** Dynamo Identificador de Queda (att)  
**Software:** Autodesk Civil 3D com Dynamo  
**Linguagem:** Grafo Dynamo com nó Python e API .NET do AutoCAD/Civil 3D  
**Objetivo:** Identificar a queda entre tubulações de entrada e saída de estruturas de uma rede de drenagem.

**Funcionamento:** recebe o **nome da rede** por um nó String ligado ao `IN[0]` do Python; percorre as estruturas da rede, identifica tubos conectados e calcula a cota de fundo pela cota do centro do tubo menos metade da altura interna. Para estruturas com **exatamente uma entrada e uma saída**, calcula `queda = fundo_entrada - fundo_saida`, arredonda a três casas e grava o texto `QUEDA: x.xxxm` no campo **Material** da estrutura. Quedas próximas de zero deixam esse campo vazio. Estruturas sem essa configuração também têm o campo Material limpo. O nó retorna um relatório para visualização no Watch.

**Como utilizar:** abra [Dynamo Identificador de Queda(att).dyn](Dynamo%20Identificador%20de%20Queda%28att%29.dyn) no Dynamo do Civil 3D; ajuste o nome da rede no nó String (exemplo existente: `REDE 01`); confira a rede e os campos envolvidos; execute em modo manual; inspecione o Watch e as propriedades das estruturas.

**Dependências:** Civil 3D com rede de tubulações e estruturas compatíveis com a API utilizada; ambiente Python do Dynamo com acesso às bibliotecas `AcMgd`, `AcDbMgd` e `AeccDbMgd`.

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** **altera diretamente dados de estruturas**, inclusive limpando o campo Material; pode sobrescrever informações preexistentes. Não calcula para estruturas com múltiplas entradas/saídas. A cota de fundo é estimada a partir do centro e da altura interna do tubo; valide a convenção adotada no projeto. Faça backup antes de executar.

## Fluxo Dynamo Desap.dyn

**Nome da rotina:** Fluxo Dynamo Desap  
**Software:** Autodesk Civil 3D com Dynamo  
**Linguagem:** Grafo Dynamo com nós Python e biblioteca de geometria DesignScript  
**Objetivo:** Extrair posições de estações de alinhamentos e criar pontos COGO associados a essas posições.

**Funcionamento:** o grafo possui quatro conjuntos semelhantes de nós que selecionam alinhamentos por nome, obtêm estações, processam listas com Python e geram pontos COGO. Os scripts Python preservam as estações extremas e filtram estações intermediárias comparando-as ao ponto médio das estações vizinhas (tolerância `0.01`); em seguida, geram pontos geométricos na coordenada XY do eixo com `Z = 0`, além de nomes e descrições sequenciais. Os nós seguintes utilizam esses dados para criar pontos COGO no desenho.

**Como utilizar:** abra [Fluxo Dynamo Desap.dyn](Fluxo%20Dynamo%20Desap.dyn) no Dynamo do Civil 3D; revise **todos os nomes de alinhamentos**, valores e opções dos nós de entrada; substitua os exemplos pelos alinhamentos do projeto; execute em cópia do desenho; verifique os pontos COGO gerados.

**Dependências:** Civil 3D, Dynamo e nós `Autodesk.Civil.DynamoNodes` e `Autodesk.AutoCAD.DynamoNodes`; alinhamentos existentes com nomes correspondentes aos informados.

**Status:** implementação disponível; não validada por execução nesta documentação.

**Limitações:** há **nomes de alinhamentos específicos gravados no grafo**, que precisam ser adaptados. Os pontos geométricos criados pelo script usam `Z = 0`; não representam automaticamente cotas do terreno ou perfil. O filtro de estações é baseado na relação entre estações consecutivas, não em uma análise hidráulica ou geométrica de desaprumo/desaparecimento. A criação de pontos altera o desenho; revise parâmetros e teste antes do uso definitivo.

---

[Voltar ao catálogo geral](../README.md)
