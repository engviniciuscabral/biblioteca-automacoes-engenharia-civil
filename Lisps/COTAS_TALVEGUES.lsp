;;; ============================================================
;;; COTAS_TALVEGUES.lsp   (comando: COTASTALVEGUES)
;;;
;;; Varre os alinhamentos cujo nome comeca com um prefixo (ex.: "TALV")
;;; dentro do AutoCAD Civil 3D, encontra o Perfil (longitudinal) associado
;;; a cada um, amostra Cota (m) x Distancia (m) em intervalos regulares
;;; ao longo do talvegue e exporta um CSV por talvegue, no formato:
;;;
;;;     Ponto;Cota (m);Distancia (m)
;;;     C;880,000;0,000
;;;     1;853,000;1000,000
;;;     ...
;;;     E;767,000;12459,000
;;;
;;; (numeros com virgula decimal e ponto-e-virgula como separador de campo --
;;; padrao do Excel em português do Brasil, abre certinho com duplo clique)
;;;
;;; Uso:
;;;   1) Abra o desenho com os alinhamentos/perfis (ex.: TALV 01..TALV 09).
;;;   2) No AutoCAD Civil 3D: Gerenciar > Aplicativos > carregar este .lsp
;;;      (ou arraste o arquivo para dentro da area de desenho).
;;;   3) Digite o comando: COTASTALVEGUES
;;;   4) Informe o prefixo dos alinhamentos (padrao "TALV").
;;;   5) Escolha o intervalo de amostragem: por padrao a rotina decide
;;;      automaticamente PARA CADA TALVEGUE, por faixa de comprimento,
;;;      para manter sempre uma quantidade razoavel de pontos:
;;;        < 1000 m  -> passo de  100 m
;;;        < 3000 m  -> passo de  200 m
;;;        < 8000 m  -> passo de  500 m
;;;        >= 8000 m -> passo de 1000 m
;;;      Se preferir, pode informar um intervalo fixo unico para todos.
;;;   6) Escolha se quer o AJUSTE DE COTAS DECRESCENTES (padrao "S").
;;;
;;; AJUSTE DE COTAS DECRESCENTES (novo):
;;;   No sentido C -> E a cota nunca pode subir. Se aparecer uma cota mais
;;;   baixa seguida de uma mais alta (ex.: 615,500 e depois 615,800), as
;;;   duas sao INVERTIDAS (615,800 e depois 615,500). A inversao e repetida
;;;   ate que toda a sequencia fique decrescente -- ou seja, as distancias
;;;   ficam onde estao e as cotas sao reordenadas em ordem decrescente.
;;;   Assim nenhuma diferenca de altura entre pontos consecutivos da
;;;   negativa. Cada ajuste feito e mostrado na linha de comando e gravado
;;;   em "Ajustes_Cotas.txt" na pasta de saida (memoria do que foi mexido).
;;;   Se a correcao de algum ponto passar de LIMITE-AVISO-AJUSTE (2,0 m),
;;;   aparece um AVISO para voce conferir o perfil daquele talvegue.
;;;
;;; Saida: uma pasta "Perfis_Talvegues" ao lado do desenho, com um
;;; arquivo Perfil_<NomeDoAlinhamento>.csv para cada talvegue processado.
;;;
;;; NOTA TECNICA: esta versao NAO usa mais o objeto "AeccXUiLand.AeccApplication"
;;; (que dependia de adivinhar o numero de versao do Civil 3D e as vezes abria
;;; uma instancia paralela sem desenho). Em vez disso, ela varre diretamente
;;; as entidades do Model Space do desenho ativo e identifica os alinhamentos
;;; pelo ObjectName "AeccDbAlignment" -- forma que nao depende da versao do
;;; Civil 3D instalada.
;;;
;;; Se ainda assim aparecer erro ao ler "Profiles" ou ao calcular a cota
;;; (ElevationAt), copie a mensagem exata da linha de comando e me avise
;;; para eu ajustar o nome da propriedade/metodo.
;;; ============================================================

;; correcao (em metros) acima da qual a rotina emite um AVISO para conferir o perfil
(setq LIMITE-AVISO-AJUSTE 2.0)

(defun TENTAR-ELEVACAO (perfil estacao / metodos res elev)
  (setq metodos (list "ElevationAt" "GetElevationAtStation" "FindElevationAtStation" "ElevationByStation"))
  (setq elev nil)
  (foreach m metodos
    (if (not elev)
      (progn
        (setq res (vl-catch-all-apply 'vlax-invoke-method (list perfil m estacao)))
        (if (and (not (vl-catch-all-error-p res)) (numberp res))
          (setq elev res)
        )
      )
    )
  )
  ;; arredonda para 3 casas (mm), para nao inverter por diferencas de ponto flutuante
  (if elev (atof (rtos elev 2 3)) nil)
)

(defun FORMATA-NUM (str)
  ;; troca o ponto decimal por virgula (padrao numerico do Excel Brasil);
  ;; o delimitador de campo do CSV ja e ponto-e-virgula, compativel com isso
  (vl-string-subst "," "." str)
)

(defun NUM-BR (x) (FORMATA-NUM (rtos x 2 3)))

(defun ESCOLHE-INTERVALO (comprimento auto fixo)
  ;; auto = T -> decide o passo pela faixa de comprimento do talvegue,
  ;; buscando manter sempre uma quantidade razoavel de pontos (mais ou
  ;; menos 6 a 14 pontos, na maioria dos casos) para a declividade efetiva
  ;; nao ficar baseada em so 2-3 pontos nos talvegues de tamanho medio:
  ;;   <  1000 m -> passo 100 m
  ;;   <  3000 m -> passo 200 m
  ;;   <  8000 m -> passo 500 m
  ;;   >= 8000 m -> passo 1000 m
  ;; auto = nil -> usa o valor fixo informado pelo usuario
  (if auto
    (cond
      ((< comprimento 1000.0) 100.0)
      ((< comprimento 3000.0) 200.0)
      ((< comprimento 8000.0) 500.0)
      (T 1000.0)
    )
    fixo
  )
)

(defun ACHA-PERFIL (perfis / perfil p)
  ;; prioriza um perfil cujo nome contenha "PERFIL LONGITUDINAL" ou "TERRENO"/"EXISTENTE"
  (setq perfil nil)
  (vlax-for p perfis
    (if (and (not perfil)
             (or (vl-string-search "PERFIL LONGITUDINAL" (strcase (vlax-get-property p "Name")))
                 (vl-string-search "TERRENO" (strcase (vlax-get-property p "Name")))
                 (vl-string-search "EXISTENTE" (strcase (vlax-get-property p "Name")))
             )
        )
      (setq perfil p)
    )
  )
  (if (not perfil)
    (vlax-for p perfis (if (not perfil) (setq perfil p)))
  )
  perfil
)

(defun EH-ALINHAMENTO (ent / nomeobj res)
  (setq res (vl-catch-all-apply 'vla-get-ObjectName (list ent)))
  (if (vl-catch-all-error-p res)
    nil
    (progn
      (setq nomeobj (strcase res))
      (or (= nomeobj "AECCDBALIGNMENT")
          (wcmatch nomeobj "*ALIGNMENT*")
      )
    )
  )
)

(defun ORDENA-DECRESCENTE (cotas / trocou res lst a b)
  ;; "bubble sort": percorre a lista e, sempre que uma cota for MENOR que a
  ;; seguinte, inverte as duas. Repete ate nao haver mais inversao.
  ;; (nao usa vl-sort porque ele pode descartar valores repetidos)
  (setq trocou T)
  (while trocou
    (setq trocou nil res nil lst cotas)
    (while (cdr lst)
      (setq a (car lst) b (cadr lst))
      (if (< a b)
        (setq res (cons b res) lst (cons a (cddr lst)) trocou T)
        (setq res (cons a res) lst (cdr lst))
      )
    )
    (setq cotas (reverse (cons (car lst) res)))
  )
  cotas
)

(defun AJUSTA-COTAS (nome pontos arqLog / cotas novas i p nova dif maxDif nAjustes linha)
  ;; pontos = lista de (rotulo distancia cota)
  ;; devolve a mesma lista com as cotas ajustadas para ficarem decrescentes
  (setq cotas (mapcar 'caddr pontos))
  (setq novas (ORDENA-DECRESCENTE cotas))
  (setq nAjustes 0 maxDif 0.0 i 0)
  (foreach p pontos
    (setq nova (nth i novas))
    (setq dif (abs (- nova (caddr p))))
    (if (> dif 0.0005)
      (progn
        (setq nAjustes (1+ nAjustes))
        (if (> dif maxDif) (setq maxDif dif))
        (setq linha (strcat "  " nome " | ponto " (car p) " (dist " (NUM-BR (cadr p)) " m): "
                            (NUM-BR (caddr p)) " -> " (NUM-BR nova)))
        (princ (strcat "\n" linha))
        (write-line linha arqLog)
      )
    )
    (setq i (1+ i))
  )
  (if (= nAjustes 0)
    (write-line (strcat "  " nome " | sem ajustes (ja estava decrescente)") arqLog)
    (princ (strcat "\n  -> " nome ": " (itoa nAjustes) " cota(s) ajustada(s)."))
  )
  (if (> maxDif LIMITE-AVISO-AJUSTE)
    (progn
      (setq linha (strcat "  AVISO " nome ": ajuste maximo de " (NUM-BR maxDif)
                          " m -- confira o perfil / sentido do alinhamento."))
      (princ (strcat "\n" linha))
      (write-line linha arqLog)
    )
  )
  ;; aviso extra: se o inicio (C) era mais baixo que o fim (E), o alinhamento
  ;; provavelmente foi desenhado de jusante para montante
  (if (< (car cotas) (last cotas))
    (progn
      (setq linha (strcat "  AVISO " nome ": cota do inicio (C) menor que a do fim (E) -- "
                          "o alinhamento pode estar no sentido invertido (de E para C)."))
      (princ (strcat "\n" linha))
      (write-line linha arqLog)
    )
  )
  ;; remonta a lista de pontos com as cotas novas
  (setq i -1)
  (mapcar '(lambda (p) (setq i (1+ i)) (list (car p) (cadr p) (nth i novas))) pontos)
)

(defun C:COTASTALVEGUES ( / acaddoc ms ent nome prefixo perfis perfil intervalo
                          comprimento n ultimoNumerado i dist cota arq caminho contador
                          linha resp autoIntervalo intervaloFixo ajustar arqLog pontos temErro)

  (vl-load-com)

  (setq acaddoc (vl-catch-all-apply 'vla-get-ActiveDocument (list (vlax-get-acad-object))))
  (if (vl-catch-all-error-p acaddoc)
    (progn (princ "\nNao consegui obter o desenho ativo do AutoCAD.") (exit))
  )

  (setq ms (vl-catch-all-apply 'vla-get-ModelSpace (list acaddoc)))
  (if (vl-catch-all-error-p ms)
    (progn (princ "\nNao consegui obter o Model Space do desenho ativo.") (exit))
  )

  (setq prefixo (getstring T "\nPrefixo do nome dos alinhamentos a processar <TALV>: "))
  (if (or (not prefixo) (= prefixo "")) (setq prefixo "TALV"))

  (setq resp (getstring T "\nIntervalo automatico por faixa de comprimento (<1000m:100m <3000m:200m <8000m:500m >=8000m:1000m)? [S/N] <S>: "))
  (if (or (not resp) (= resp "") (= (strcase resp) "S"))
    (setq autoIntervalo T)
    (progn
      (setq autoIntervalo nil)
      (setq intervaloFixo (getreal "\nIntervalo fixo de amostragem em metros <1000>: "))
      (if (not intervaloFixo) (setq intervaloFixo 1000.0))
    )
  )

  (setq resp (getstring T "\nAjustar cotas para ficarem sempre decrescentes de C para E (inverte cotas fora de ordem)? [S/N] <S>: "))
  (setq ajustar (or (not resp) (= resp "") (= (strcase resp) "S")))

  (setq caminho (vl-filename-directory (vla-get-FullName acaddoc)))
  (setq caminho (strcat caminho "\\Perfis_Talvegues\\"))
  (vl-mkdir caminho)

  (setq arqLog nil)
  (if ajustar
    (progn
      (setq arqLog (open (strcat caminho "Ajustes_Cotas.txt") "w"))
      (write-line "AJUSTES DE COTAS - sequencia forcada a ser decrescente de C para E" arqLog)
      (write-line "(cotas fora de ordem foram invertidas; distancias mantidas)" arqLog)
      (write-line "" arqLog)
    )
  )

  (setq contador 0)

  (vlax-for ent ms
    (if (EH-ALINHAMENTO ent)
      (progn
        (setq nome (vl-catch-all-apply 'vlax-get-property (list ent "Name")))
        (if (not (vl-catch-all-error-p nome))
          (if (wcmatch (strcase nome) (strcat (strcase prefixo) "*"))
            (progn
              (setq comprimento (vl-catch-all-apply 'vlax-get-property (list ent "Length")))
              (if (vl-catch-all-error-p comprimento)
                (princ (strcat "\n  -> " nome ": nao consegui ler o comprimento (propriedade 'Length'). Pulei."))
                (progn
                  (setq perfis (vl-catch-all-apply 'vlax-get-property (list ent "Profiles")))
                  (if (or (vl-catch-all-error-p perfis) (not perfis))
                    (princ (strcat "\n  -> " nome ": nao consegui ler os perfis (propriedade 'Profiles'). Pulei."))
                    (progn
                      (setq perfil (ACHA-PERFIL perfis))
                      (if (not perfil)
                        (princ (strcat "\n  -> " nome ": nenhum perfil encontrado. Pulei."))
                        (progn
                          (setq intervalo (ESCOLHE-INTERVALO comprimento autoIntervalo intervaloFixo))
                          (princ (strcat "\nProcessando " nome " (perfil: " (vlax-get-property perfil "Name")
                                         ", extensao: " (rtos comprimento 2 2) " m, passo: " (rtos intervalo 2 0) " m)..."))

                          ;; n = quantos multiplos INTEIROS do intervalo cabem dentro do talvegue
                          ;; (ex.: 1703.73 m com passo 1000 m -> n=1 multiplo, que e o ponto "1" em 1000 m)
                          (setq n (fix (/ comprimento intervalo)))
                          ;; se o ultimo multiplo cair exatamente no fim do talvegue, ele vira o
                          ;; proprio ponto "E" em vez de virar um numero duplicado
                          (setq ultimoNumerado
                            (if (and (> n 0) (< (abs (- (* n intervalo) comprimento)) 0.001))
                              (1- n)
                              n
                            )
                          )

                          ;; 1) COLETA todos os pontos primeiro: lista de (rotulo distancia cota)
                          (setq pontos (list (list "C" 0.0 (TENTAR-ELEVACAO perfil 0.0))))
                          (setq i 1)
                          (while (<= i ultimoNumerado)
                            (setq dist (* i intervalo))
                            (setq pontos (cons (list (itoa i) dist (TENTAR-ELEVACAO perfil dist)) pontos))
                            (setq i (1+ i))
                          )
                          (setq pontos (cons (list "E" comprimento (TENTAR-ELEVACAO perfil comprimento)) pontos))
                          (setq pontos (reverse pontos))

                          ;; 2) AJUSTE: so aplica se todas as cotas foram lidas (sem "ERRO")
                          (setq temErro (vl-some '(lambda (p) (not (caddr p))) pontos))
                          (if ajustar
                            (if temErro
                              (progn
                                (princ (strcat "\n  -> " nome ": ha cota(s) com ERRO de leitura; ajuste NAO aplicado neste talvegue."))
                                (write-line (strcat "  " nome " | ajuste NAO aplicado (cota com ERRO de leitura)") arqLog)
                              )
                              (setq pontos (AJUSTA-COTAS nome pontos arqLog))
                            )
                          )

                          ;; 3) GRAVA o CSV
                          (setq arq (open (strcat caminho "Perfil_" nome ".csv") "w"))
                          (write-line "Ponto;Cota (m);Distancia (m)" arq)
                          (foreach p pontos
                            (setq cota (caddr p))
                            (setq linha (strcat (car p) ";" (if cota (NUM-BR cota) "ERRO") ";" (NUM-BR (cadr p))))
                            (write-line linha arq)
                          )
                          (close arq)
                          (setq contador (1+ contador))
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  (if arqLog (close arqLog))

  (if (= contador 0)
    (princ (strcat "\nNenhum alinhamento encontrado com prefixo \"" prefixo "\". Confira o nome dos alinhamentos."))
    (progn
      (princ (strcat "\n" (itoa contador) " talvegue(s) exportado(s) em: " caminho))
      (if ajustar (princ "\nAjustes de cota registrados em: Ajustes_Cotas.txt"))
      ;; abre a pasta de saida no Windows Explorer automaticamente
      (vl-catch-all-apply 'startapp (list "explorer" caminho))
    )
  )
  (princ)
)

(princ "\nComando COTASTALVEGUES carregado. Digite COTASTALVEGUES para exportar Cota x Distancia dos talvegues.")
(princ)