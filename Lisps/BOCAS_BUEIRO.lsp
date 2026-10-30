;;; =====================================================================
;;;  BOCAS_BUEIRO.LSP  -  Insercao automatica de bocas de bueiro (Civil 3D)
;;; ---------------------------------------------------------------------
;;;  Comando : BOCASTUDO     (atalho: BBT)  - planta + perfil de todos
;;;            BBTB / BBTD                  - so bocas / so dissipadores
;;;            BBX                          - escolhe o que e onde inserir
;;;            BOCASBUEIRO   (atalho: BBU)  - bocas em planta
;;;            BOCASPERFIL   (atalho: BBP)  - bocas em corte no Profile View
;;;                                           (clique na pipe dentro do perfil)
;;;            BBATERRO                     - so recalcula a altura de aterro
;;;                                           no eixo e grava na pipe (label)
;;;            BBCOGO                       - so os COGO points no eixo (1 por bueiro)
;;;            BBOBRA                       - so o tipo de obra (BDCC 3.00x3.00m,
;;;                                           BTTC d=1.50m) nas labels de planta e perfil
;;;            BBPLANILHA                   - planilha Excel dos bueiros (cotas, aterro,
;;;                                           L, montante/jusante, estaca no eixo)
;;;            BBGRADE                      - tira as bands e ajusta a grade dos
;;;                                           Profile Views (um por um ou todos)
;;;            BBGREIDE                     - esquece o greide escolhido (pergunta de novo)
;;;            BBLIMPA                      - apaga o que a LISP fez nos bueiros
;;;                                           selecionados (bocas/dissip/textos/cotas)
;;;            BBLIMPAANTIGO                - idem, para o que versoes antigas fizeram
;;;                                           (sem etiqueta); mostra e pede confirmacao
;;;  Rodar de novo num bueiro apaga antes o que a LISP ja tinha feito nele
;;;  (*BB:SUBSTITUIR*), so do que vai ser refeito.
;;;
;;;  O que faz:
;;;   1. Voce seleciona os canos (Pipes de Pipe Network) de um ou varios
;;;      bueiros de uma vez (janela, crossing, etc).
;;;   2. Os canos paralelos e proximos sao agrupados em um bueiro:
;;;        1 cano = Simples (BS..), 2 = Duplo (BD..), 3 = Triplo (BT..)
;;;   3. Le as propriedades de cada cano:
;;;        - InnerDiameterOrWidth / InnerHeight  -> diametro e forma
;;;        - StartPoint / EndPoint (cota Z)      -> sentido do fluxo
;;;      A extremidade de cota mais BAIXA e a JUSANTE.
;;;   4. Insere o bloco dinamico das bocas na montante e na jusante,
;;;      rotacionado conforme o eixo do bueiro, e ajusta o estado de
;;;      visibilidade (ex.: "BDTC 1.20 - TEMPLATE").
;;;   5. Se o bueiro for TUBULAR e D < 1,50 m, insere o dissipador de
;;;      energia logo a frente da boca de JUSANTE (apos as alas).
;;;
;;;  Carregar: APPLOAD -> BOCAS_BUEIRO.lsp  -> digitar BOCASBUEIRO
;;; =====================================================================

(vl-load-com)

;;; ------------------------- CONFIGURACAO ------------------------------
;;; Nome do bloco dinamico das bocas. nil = detectar automaticamente
;;; (procura o bloco que tenha estados "BSTC..", "BDTC..", "BTTC..").
(setq *BB:BLK-BOCA*     "BOCA_DNIT_PLANTA_V4")  ; criado pelo TEMPLATE_BOCAS (BOCASCADDIN)

;;; Nome do bloco do dissipador de energia (se nao existir, o comando
;;; pede para selecionar um dissipador no desenho ou digitar o nome).
(setq *BB:BLK-DISSIP*   "DISSIPADOR")

;;; Orientacao dos blocos (graus), medida NO DESENHO DO BLOCO:
;;;  *BB:ROT-BOCA*   = direcao para onde as alas "abrem" (lado de fora do
;;;                    bueiro). 0 = +X, 90 = +Y, 180 = -X, 270 = -Y.
;;;  *BB:ROT-DISSIP* = direcao do fluxo dentro do desenho do dissipador.
;;;  nil = AUTOMATICO: o eixo do bueiro e tomado perpendicular a maior
;;;        dimensao do bloco e o lado "de fora" e o que tem mais geometria
;;;        a partir do ponto base. Se sair errado, informe o angulo aqui.
(setq *BB:ROT-BOCA*     nil)
(setq *BB:ROT-DISSIP*   nil)
;;; T = no 1o dissipador de cada execucao, pergunta se a rotacao esta certa
;;;     (Ok / Girar 90 / Inverter 180 / Anti-horario 90) e usa a resposta
;;;     nos demais. So vale quando *BB:ROT-DISSIP* = nil.
(setq *BB:DISSIP-CONFIRMAR* T)

;;; Distancia do dissipador ao ponto de insercao da boca de jusante.
;;;  nil = automatico (fim das alas do bloco, medido na geometria visivel)
;;;  numero = distancia fixa em metros.
(setq *BB:DISSIP-AFAST* nil)
(setq *BB:DISSIP-FOLGA* 0.0)    ; folga extra somada ao modo automatico
;;; Bueiro com D (ou largura) ACIMA disto e CELULAR (BSCC/BDCC/BTCC), mesmo
;;; que a pipe esteja modelada como tubo. Ate este valor = tubular.
;;; nil = decide so pela pipe (familia/descricao/altura).
(setq *BB:CELULAR-ACIMA* 1.50)
;;; Encaixe: o dissipador avanca sobre a boca ate a sua face INTERNA
;;; (linha transversal logo apos a borda de tras, ex.: a tracejada)
;;; coincidir com a face externa da boca (ponta das alas).
;;;  nil = automatico (detectado nas linhas do bloco) | numero = metros | 0 = sem encaixe
(setq *BB:DISSIP-ENCAIXE* nil)
;;; Tamanho do dissipador: T = escala uniforme para ficar com a mesma
;;; largura da boca (ponta a ponta das alas) x fator. nil = tamanho do bloco.
(setq *BB:DISSIP-ESCALAR*    T)
(setq *BB:DISSIP-FATOR-LARG* 1.0)

(setq *BB:DIAM-LIMITE*  1.50)   ; diametro limite para o dissipador (tubular)
(setq *BB:DISSIP-ATE-LIMITE* T) ; T = D <= limite recebe dissipador | nil = so D < limite
(setq *BB:TOL-DIAM*     0.05)   ; tolerancia p/ avisar diametro fora do padrao
(setq *BB:TOL-Z*        0.001)  ; diferenca minima de cota p/ definir fluxo (m)
(setq *BB:ANG-TOL*      3.0)    ; tolerancia de paralelismo entre canos (graus)
(setq *BB:FATOR-AGRUP*  3.0)    ; canos agrupados se dist. < 1 + fator*D
(setq *BB:USAR-Z*       nil)    ; T = insere blocos na cota do cano; nil = Z 0
(setq *BB:LAYER-BOCA*   "OBRAS PROJETADAS")  ; "" = layer corrente
(setq *BB:LAYER-DISSIP* "OBRAS PROJETADAS")  ; "" = layer corrente
(setq *BB:COR-LAYER*    5)      ; cor da layer quando ela e criada (5 = blue)
;;; Cor de toda a geometria da boca (inclusive dentro dos blocos aninhados
;;; do bloco dinamico). 5 = blue | nil = nao mexe na cor
(setq *BB:COR-BOCA*     5)
;;; O que inserir (os comandos ajustam: BBT tudo, BBTB so bocas, BBTD so
;;; dissipadores, BBX pergunta)
(setq *bb:fazer-bocas* T *bb:fazer-dissip* T *bb:fazer-planta* T *bb:fazer-perfil* T)
;;; T = ao rodar de novo num bueiro, apaga antes o que a LISP ja tinha
;;; feito nele (so o que vai ser refeito: bocas e/ou dissipador, planta
;;; e/ou perfil). nil = nao apaga nada (pode duplicar).
(setq *BB:SUBSTITUIR* T)
;;; ---------------------------------------------------------------------


;;; ========================= UTILITARIOS ===============================
(defun bb:rad (g) (* pi (/ g 180.0)))
(defun bb:true-p (v) (if (member v (list :vlax-true -1 T)) T nil))
(defun bb:v- (a b) (mapcar '- a b))
(defun bb:v+ (a b) (mapcar '+ a b))
(defun bb:vs (v s) (mapcar '(lambda (x) (* x s)) v))
(defun bb:dot2 (a b) (+ (* (car a) (car b)) (* (cadr a) (cadr b))))
(defun bb:cross2 (a b) (- (* (car a) (cadr b)) (* (cadr a) (car b))))
(defun bb:d2 (a b) (distance (list (car a) (cadr a)) (list (car b) (cadr b))))
(defun bb:media (pts) (bb:vs (apply 'mapcar (cons '+ pts)) (/ 1.0 (length pts))))
(defun bb:unit2 (v / l)
  (setq l (distance '(0.0 0.0) (list (car v) (cadr v))))
  (if (> l 1e-9) (list (/ (car v) l) (/ (cadr v) l) 0.0))
)

;;; Converte variant / safearray em dados LISP
(defun bb:var->lisp (v / l)
  (cond
    ((= (type v) 'VARIANT) (bb:var->lisp (vlax-variant-value v)))
    ((= (type v) 'SAFEARRAY)
     (setq l (vl-catch-all-apply 'vlax-safearray->list (list v)))
     (if (vl-catch-all-error-p l) nil (mapcar 'bb:var->lisp l))
    )
    (T v)
  )
)

;;; Le propriedade COM com seguranca (nil se nao existir / erro)
(defun bb:prop (obj name / r)
  (if (and obj (vlax-property-available-p obj name))
    (progn
      (setq r (vl-catch-all-apply 'vlax-get (list obj name)))
      (if (vl-catch-all-error-p r) nil (bb:var->lisp r))
    )
  )
)

(defun bb:ponto-p (p) (and (listp p) (= 3 (length p)) (vl-every 'numberp p)))

(defun bb:layer (obj nome)
  (if (and nome (/= nome ""))
    (progn
      (if (not (tblsearch "LAYER" nome))
        (vla-put-Color
          (vla-Add (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object))) nome)
          *BB:COR-LAYER*)
      )
      (vla-put-Layer obj nome)
    )
  )
)

;;; Pinta com a cor COR toda a geometria da definicao do bloco NOME e dos
;;; blocos aninhados nela (as variantes do bloco dinamico sao blocos
;;; inseridos dentro dele). Cada definicao e pintada uma vez por execucao.
(defun bb:pintar-def (nome cor / blk)
  (if (and cor (not (member nome *bb:pintados*)))
    (progn
      (setq *bb:pintados* (cons nome *bb:pintados*)
            blk (vl-catch-all-apply 'vla-item
                  (list (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))) nome)))
      (if (not (vl-catch-all-error-p blk))
        (vlax-for e blk
          (if (= (vla-get-ObjectName e) "AcDbBlockReference")
            (bb:pintar-def (vla-get-Name e) cor)
          )
          (vl-catch-all-apply 'vla-put-Color (list e cor))
        )
      )
    )
  )
)

;;; Pinta a definicao dinamica e a anonima (*U..) usada pela referencia
(defun bb:pintar-ref (ref cor)
  (if cor
    (progn
      (bb:pintar-def (vla-get-EffectiveName ref) cor)
      (bb:pintar-def (vla-get-Name ref) cor)
      (vla-put-Color ref cor)
      (vla-Update ref)
    )
  )
)

(defun bb:inserir (blk pt ang lay / ms obj)
  (setq ms  (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object)))
        obj (vla-InsertBlock ms (vlax-3d-point pt) blk 1.0 1.0 1.0 ang))
  (bb:layer obj lay)
  (bb:tag obj)
)


;;; ================= ETIQUETA (XDATA) E LIMPEZA =========================
;;; Tudo o que a LISP cria no Model (blocos, textos, cotas) recebe XDATA
;;; "BOCAS_BUEIRO" com: tipo ("B" = bocas + textos/cotas, "D" = dissipador,
;;; "C" = COGO point no eixo),
;;; onde ("PL" planta, "PF" perfil) e os handles das pipes do bueiro.
;;; Ao rodar de novo, o que for refeito e apagado antes (BBLIMPA = manual).
(setq *bb:tag-key*  nil)   ; handles das pipes do bueiro em processamento
(setq *bb:tag-tipo* "B")
(setq *bb:tag-onde* "PL")
(setq *bb:limpos*   nil)   ; bueiro+onde ja limpos nesta execucao

;;; Handles (ordenados) das pipes de um grupo/lista de canos
(defun bb:chave (canos)
  (vl-sort (mapcar '(lambda (c) (vla-get-Handle (car c))) canos) '<))

;;; Grava a etiqueta no objeto (vla-object ou ename). Devolve o objeto.
(defun bb:tag (obj / o lst tp vl i)
  (if (and *bb:tag-key* obj)
    (progn
      (setq o (if (= (type obj) 'ENAME) (vlax-ename->vla-object obj) obj))
      (regapp "BOCAS_BUEIRO")
      (setq lst (append (list (cons 1001 "BOCAS_BUEIRO")
                              (cons 1000 *bb:tag-tipo*)
                              (cons 1000 *bb:tag-onde*))
                        (mapcar '(lambda (h) (cons 1000 h)) *bb:tag-key*))
            tp  (vlax-make-safearray vlax-vbInteger (cons 0 (1- (length lst))))
            vl  (vlax-make-safearray vlax-vbVariant (cons 0 (1- (length lst))))
            i   0)
      (foreach x lst
        (vlax-safearray-put-element tp i (car x))
        (vlax-safearray-put-element vl i (vlax-make-variant (cdr x) vlax-vbString))
        (setq i (1+ i)))
      (vl-catch-all-apply 'vla-SetXData (list o tp vl))))
  obj)

;;; Apaga os objetos etiquetados das pipes HS (lista de handles), dos
;;; TIPOS ("B" "D") e locais ONDES ("PL" "PF"). Devolve quantos apagou.
(defun bb:limpar (hs tipos ondes / ss i e vals n)
  (setq n 0)
  (if (setq ss (ssget "_X" '((-3 ("BOCAS_BUEIRO")))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq e    (ssname ss i)
              i    (1+ i)
              vals (if (entget e)                 ; ja apagado -> ignora
                     (mapcar 'cdr (cdr (cadr (assoc -3 (entget e '("BOCAS_BUEIRO"))))))))
        ;; vals = (tipo onde handle1 handle2 ...)
        ;; apaga com ENTDEL (o vla-Delete em objeto do Civil 3D, ex. COGO
        ;; point, pode derrubar o comando com "Access Violation")
        (if (and vals
                 (member (car vals) tipos)
                 (member (cadr vals) ondes)
                 (vl-some '(lambda (h) (member h hs)) (cddr vals))
                 (not (vl-catch-all-error-p (vl-catch-all-apply 'entdel (list e)))))
          (setq n (1+ n))))))
  n)

;;; Antes de refazer um bueiro em ONDE: apaga o que a execucao anterior
;;; criou ali e que este comando vai recriar (bocas e/ou dissipador).
;;; Uma vez por bueiro+local por execucao (o bueiro pode estar em 2 perfis).
(defun bb:limpar-auto (onde / k tipos n)
  (if (and *BB:SUBSTITUIR* *bb:tag-key* (not *bb:so-aterro*))
    (progn
      (setq k (strcat onde (apply 'strcat *bb:tag-key*)))
      (if (not (member k *bb:limpos*))
        (progn
          (setq *bb:limpos* (cons k *bb:limpos*)
                tipos (append (if *bb:fazer-bocas* '("B")) (if *bb:fazer-dissip* '("D"))))
          (if (and tipos (> (setq n (bb:limpar *bb:tag-key* tipos (list onde))) 0))
            (princ (strcat "\n  (" (itoa n) " objeto(s) da execucao anterior apagado(s) em "
                           (if (= onde "PL") "planta" "perfil") ")"))))))))

(defun bb:zoom (a b / c h)
  (setq c (bb:media (list a b))
        h (max 10.0 (* 1.5 (bb:d2 a b))))
  (vl-catch-all-apply 'vla-ZoomCenter
    (list (vlax-get-acad-object) (vlax-3d-point c) h))
)


;;; ===================== BLOCO DINAMICO / ESTADOS =======================
;;; Lista ((propriedade . (valores-texto ...)) ...) do bloco dinamico
(defun bb:props-str (ref / res vals)
  (if (bb:true-p (bb:prop ref 'IsDynamicBlock))
    (foreach p (vlax-invoke ref 'GetDynamicBlockProperties)
      (setq vals (vl-catch-all-apply 'vlax-get-property (list p 'AllowedValues)))
      (if (not (vl-catch-all-error-p vals))
        (progn
          (setq vals (bb:var->lisp vals))
          (if (and vals (listp vals)
                   (vl-every '(lambda (x) (= (type x) 'STR)) vals))
            (setq res (cons (cons p vals) res))
          )
        )
      )
    )
  )
  res
)

;;; T se a referencia tem estados no padrao das bocas (BSTC, BDTC, ...)
(defun bb:eh-boca (ref / ok)
  (foreach pv (bb:props-str ref)
    (foreach s (cdr pv)
      (if (wcmatch (strcase s) "B[SDT]TC*,B[SDT]CC*") (setq ok T))
    )
  )
  ok
)

;;; Ajusta o estado de visibilidade mais proximo de CODE + diametro D.
;;; Celular: estado "BSCC 2.00X1.50 ..." = largura X altura; se H for
;;; informado, a altura tambem entra na escolha.
;;; Retorna (estado diferenca) ou nil se nao houver estado com CODE.
(defun bb:set-vis (ref code d h / best bestd num pr txt px dif)
  (foreach pv (bb:props-str ref)
    (foreach s (cdr pv)
      (if (wcmatch (strcase s) (strcat code "*"))
        (progn
          (setq txt (vl-string-translate "," "." (substr s (1+ (strlen code))))
                num (atof (vl-string-left-trim " -_" txt))
                px  (vl-string-search "X" (strcase txt))
                dif (+ (abs (- num d))
                       (if (and h px) (abs (- (atof (substr txt (+ px 2))) h)) 0.0)))
          (if (or (null bestd) (< dif bestd))
            (setq best s bestd dif pr (car pv))
          )
        )
      )
    )
  )
  (if best
    (if (vl-catch-all-error-p
          (vl-catch-all-apply 'vla-put-Value
            (list pr (vlax-make-variant best vlax-vbString))))
      nil
      (progn (vla-Update ref) (list best bestd))
    )
  )
)

;;; Limites da geometria VISIVEL do bloco, em coordenadas do proprio bloco
;;; e relativos ao ponto base: (minX maxX minY maxY)
(defun bb:ext-local (ref / doc blk org a b pa pb x0 x1 y0 y1 s)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        blk (vla-item (vla-get-Blocks doc) (vla-get-Name ref))
        org (vlax-get blk 'Origin)
        s   (abs (vla-get-XScaleFactor ref)))
  (vlax-for e blk
    (if (and (/= (vla-get-ObjectName e) "AcDbAttributeDefinition")
             (bb:true-p (bb:prop e 'Visible))
             (not (vl-catch-all-error-p
                    (vl-catch-all-apply 'vla-GetBoundingBox (list e 'a 'b)))))
      (progn
        (setq pa (bb:v- (vlax-safearray->list a) org)
              pb (bb:v- (vlax-safearray->list b) org))
        (setq x0 (if x0 (min x0 (car pa)) (car pa))
              x1 (if x1 (max x1 (car pb)) (car pb))
              y0 (if y0 (min y0 (cadr pa)) (cadr pa))
              y1 (if y1 (max y1 (cadr pb)) (cadr pb)))
      )
    )
  )
  (if x0 (mapcar '(lambda (v) (* v s)) (list x0 x1 y0 y1)) '(0.0 0.0 0.0 0.0))
)

;;; Direcao "para fora" do bloco (graus, no desenho do bloco), detectada:
;;; o eixo do bueiro e perpendicular a maior dimensao do bloco (a boca e
;;; mais larga do que profunda) e o lado de fora e o que tem mais geometria
;;; a partir do ponto base (alas).
(defun bb:auto-off (ext / x0 x1 y0 y1)
  (setq x0 (nth 0 ext) x1 (nth 1 ext) y0 (nth 2 ext) y1 (nth 3 ext))
  (if (>= (- x1 x0) (- y1 y0))
    (if (>= y1 (- y0)) 90.0 270.0)
    (if (>= x1 (- x0)) 0.0 180.0)
  )
)

;;; Extensao do bloco para frente (sinal 1) ou para tras (sinal -1)
;;; ao longo da direcao offDeg
(defun bb:ext-ao-longo (ext offDeg sinal / u mx d)
  (setq u  (list (cos (bb:rad offDeg)) (sin (bb:rad offDeg)))
        mx 0.0)
  (foreach c (list (list (nth 0 ext) (nth 2 ext)) (list (nth 1 ext) (nth 2 ext))
                   (list (nth 0 ext) (nth 3 ext)) (list (nth 1 ext) (nth 3 ext)))
    (setq d (* sinal (bb:dot2 c u)))
    (if (> d mx) (setq mx d))
  )
  mx
)

;;; Largura do bloco perpendicular a direcao offDeg (ponta a ponta)
(defun bb:largura (ext offDeg)
  (+ (bb:ext-ao-longo ext (+ offDeg 90.0) 1.0)
     (bb:ext-ao-longo ext (+ offDeg 90.0) -1.0))
)

;;; Gira o bloco para que sua direcao "para fora" (offDeg) aponte para vetor w
(defun bb:orientar-bloco (ref offDeg w)
  (vla-put-Rotation ref (- (angle '(0.0 0.0) (list (car w) (cadr w))) (bb:rad offDeg)))
)

;;; Direcao do fluxo no desenho do DISSIPADOR (graus).
;;; O dissipador nao e "mais largo que fundo" como a boca (costuma ser
;;; quadrado ou mais comprido no sentido do fluxo), entao a regra da boca
;;; nao serve. Regra: o ponto base fica na borda que encosta na boca, logo
;;; o fluxo vai do ponto base para o centro da geometria. Se o ponto base
;;; estiver no centro do bloco, usa o eixo da MAIOR dimensao como fluxo.
(defun bb:auto-off-dissip (ext / x0 x1 y0 y1 cx cy w h)
  (setq x0 (nth 0 ext) x1 (nth 1 ext) y0 (nth 2 ext) y1 (nth 3 ext)
        cx (/ (+ x0 x1) 2.0) cy (/ (+ y0 y1) 2.0)
        w  (- x1 x0)         h  (- y1 y0))
  (cond
    ((and (> (abs cx) (* 0.2 w)) (>= (abs cx) (abs cy))) (if (> cx 0.0) 0.0 180.0))
    ((> (abs cy) (* 0.2 h))                               (if (> cy 0.0) 90.0 270.0))
    ((>= w h) 0.0)
    (T 90.0)
  )
)

;;; Segmentos retos (LINE e trechos de LWPOLYLINE) visiveis de um bloco,
;;; em coordenadas do bloco relativas ao ponto base: ((p1 p2) ...)
(defun bb:segs-bloco (ref / doc blk org segs c pts pa)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        blk (vla-item (vla-get-Blocks doc) (vla-get-Name ref))
        org (vlax-get blk 'Origin))
  (vlax-for e blk
    (if (bb:true-p (bb:prop e 'Visible))
      (cond
        ((= (vla-get-ObjectName e) "AcDbLine")
         (setq segs (cons (list (bb:v- (vlax-get e 'StartPoint) org)
                                (bb:v- (vlax-get e 'EndPoint) org)) segs)))
        ((= (vla-get-ObjectName e) "AcDbPolyline")
         (setq c (vlax-get e 'Coordinates) pts nil)
         (while c
           (setq pts (cons (list (- (car c) (car org)) (- (cadr c) (cadr org)) 0.0) pts)
                 c   (cddr c)))
         (setq pts (reverse pts))
         (if (bb:true-p (bb:prop e 'Closed)) (setq pts (append pts (list (car pts)))))
         (while (cdr pts)
           (setq segs (cons (list (car pts) (cadr pts)) segs)
                 pts  (cdr pts))))
      )
    )
  )
  segs
)

;;; Encaixe do dissipador (m, ja na escala do bloco): distancia entre a
;;; face de tras do dissipador (borda externa) e a sua face INTERNA
;;; (a proxima linha transversal ao fluxo - ex.: a linha tracejada).
;;; E quanto o dissipador "entra" sobre a boca para que a face interna
;;; coincida com a face externa da boca.
(defun bb:encaixe-dissip (ref offD / u ext larg tol s lst smin s2 v l)
  (cond
    ((numberp *BB:DISSIP-ENCAIXE*) *BB:DISSIP-ENCAIXE*)
    (T
     (setq u    (list (cos (bb:rad offD)) (sin (bb:rad offD)))
           ext  (bb:ext-local ref)
           larg (/ (bb:largura ext offD) (max 1e-9 (abs (vla-get-XScaleFactor ref))))
           tol  (* 0.002 larg))
     ;; linhas transversais ao fluxo com pelo menos 50% da largura
     (foreach sg (bb:segs-bloco ref)
       (setq v (bb:v- (cadr sg) (car sg))
             l (distance '(0.0 0.0) (list (car v) (cadr v))))
       (if (and (> l (* 0.5 larg))
                (< (abs (bb:dot2 v u)) (* 0.05 l)))
         (setq lst (cons (bb:dot2 (bb:media sg) u) lst))
       )
     )
     (if lst
       (progn
         (setq smin (apply 'min lst))
         (foreach s lst
           (if (and (> s (+ smin tol)) (or (not s2) (< s s2))) (setq s2 s))
         )
         (if (and s2 (< (- s2 smin) (* 0.5 larg)))
           (* (- s2 smin) (abs (vla-get-XScaleFactor ref)))
           0.0
         )
       )
       0.0
     )
    )
  )
)

;;; Escala, posiciona (centrado no eixo do bueiro) e gira o dissipador
;;; para que sua direcao de fluxo offD aponte para dir.
;;; Pontas extremas de um bloco na direcao offDeg (sinal 1 = frente,
;;; -1 = tras), em coordenadas do bloco ja escaladas:
;;;   (s tmin tmax)  s = posicao ao longo de offDeg, t = lateral (offDeg+90)
;;; Boca (frente)      -> pontas das alas (face externa)
;;; Dissipador (tras)  -> pontas das "alas" do dissipador (polilinhas de encaixe)
(defun bb:pontas (ref offDeg sinal / u v pts smx tol sel tmin tmax esc lat)
  (setq u   (list (cos (bb:rad offDeg)) (sin (bb:rad offDeg)))
        v   (list (- (cadr u)) (car u))
        esc (abs (vla-get-XScaleFactor ref)))
  (foreach sg (bb:segs-bloco ref)
    (setq pts (cons (car sg) (cons (cadr sg) pts))))
  (if pts
    (progn
      (setq lat (mapcar '(lambda (p) (bb:dot2 p v)) pts)
            tol (* 0.01 (- (apply 'max lat) (apply 'min lat)))
            smx (apply 'max (mapcar '(lambda (p) (* sinal (bb:dot2 p u))) pts)))
      (foreach p pts
        (if (>= (* sinal (bb:dot2 p u)) (- smx tol))
          (setq sel (cons (bb:dot2 p v) sel))))
      (setq tmin (apply 'min sel)
            tmax (apply 'max sel))
      (if (> (- tmax tmin) (* 10.0 tol))
        (mapcar '(lambda (x) (* x esc)) (list (* sinal smx) tmin tmax))
      )
    )
  )
)

;;; Face INTERNA do dissipador (a linha tracejada logo depois da borda de
;;; tras): e nela que as pontas das alas da boca devem encostar.
;;; Agrupa as linhas transversais ao fluxo pela posicao (aceita tracejado
;;; feito por linetype ou desenhado em pedacos), ordena de tras para frente
;;; e devolve a 2a linha: (s tmin tmax) ja escalado, ou nil.
(defun bb:face-interna-dissip (ref offD / u v esc segs lat w tol lst cur grp dv l a b)
  (setq u    (list (cos (bb:rad offD)) (sin (bb:rad offD)))
        v    (list (- (cadr u)) (car u))
        esc  (abs (vla-get-XScaleFactor ref))
        segs (bb:segs-bloco ref))
  (foreach sg segs
    (setq lat (cons (bb:dot2 (car sg) v) (cons (bb:dot2 (cadr sg) v) lat))))
  (if lat
    (progn
      (setq w   (- (apply 'max lat) (apply 'min lat))
            tol (* 0.005 w))
      ;; segmentos transversais: (s tmin tmax)
      (foreach sg segs
        (setq dv (bb:v- (cadr sg) (car sg))
              l  (distance '(0.0 0.0) (list (car dv) (cadr dv))))
        (if (and (> l 1e-9) (< (abs (bb:dot2 dv u)) (* 0.05 l)))
          (setq a   (bb:dot2 (car sg) v)
                b   (bb:dot2 (cadr sg) v)
                lst (cons (list (bb:dot2 (bb:media sg) u) (min a b) (max a b)) lst))
        )
      )
      ;; junta os que estao na mesma posicao (pedacos do tracejado)
      (foreach x (vl-sort lst '(lambda (p q) (< (car p) (car q))))
        (if (and cur (< (- (car x) (car cur)) tol))
          (setq cur (list (car cur) (min (cadr cur) (cadr x)) (max (caddr cur) (caddr x))))
          (progn
            (if cur (setq grp (cons cur grp)))
            (setq cur x)
          )
        )
      )
      (if cur (setq grp (cons cur grp)))
      ;; so as linhas que atravessam o dissipador (>= 50% da largura)
      (setq grp (vl-remove-if-not '(lambda (g) (> (- (caddr g) (cadr g)) (* 0.5 w)))
                                  (reverse grp)))
      (if (and (cadr grp) (< (- (car (cadr grp)) (car (car grp))) (* 0.5 w)))
        (mapcar '(lambda (x) (* x esc)) (cadr grp))
      )
    )
  )
)

(defun bb:escalar (ref e)
  (vla-put-XScaleFactor ref e)
  (vla-put-YScaleFactor ref e)
  (vla-put-ZScaleFactor ref e)
  (vla-Update ref)
)

;;; Escala, posiciona e gira o dissipador para que sua direcao de fluxo
;;; offD aponte para dir. Modo principal: a linha tracejada do dissipador
;;; (face interna) fica sobre a linha das pontas das alas da boca, com o
;;; mesmo comprimento (escala) e centrada no eixo; a borda de tras do
;;; dissipador passa um pouco por cima das alas.
(defun bb:posicionar-dissip (refD offD PJ dir extB offB / extD escD dist cx cy lat perp ptD pB pD)
  (vla-put-Rotation refD 0.0)
  (bb:escalar refD 1.0)
  (setq extD (bb:ext-local refD)
        perp (list (- (cadr dir)) (car dir) 0.0)
        pB   (if (and (not (numberp *BB:DISSIP-AFAST*)) *bb:boca-jus*)
               (bb:pontas *bb:boca-jus* offB 1.0))
        ;; referencia do dissipador = linha tracejada (face interna);
        ;; sem ela, usa as pontas de tras
        pD   (if pB (cond ((bb:face-interna-dissip refD offD))
                          ((bb:pontas refD offD -1.0)))))
  (if (and pB pD)
    ;; ---------- encaixe ponta a ponta ----------
    (progn
      (setq escD (if *BB:DISSIP-ESCALAR*
                   (/ (* (- (caddr pB) (cadr pB)) *BB:DISSIP-FATOR-LARG*)
                      (- (caddr pD) (cadr pD)))
                   1.0))
      (bb:escalar refD escD)
      (setq ptD (bb:v+ PJ
                  (bb:v+ (bb:vs dir  (+ (car pB) (- (* escD (car pD))) *BB:DISSIP-FOLGA*))
                         (bb:vs perp (- (/ (+ (cadr pB) (caddr pB)) 2.0)
                                        (* escD (/ (+ (cadr pD) (caddr pD)) 2.0)))))))
      (vla-put-InsertionPoint refD (vlax-3d-point ptD))
      (bb:orientar-bloco refD offD dir)
      (vla-Update refD)
      ptD
    )
    (bb:posicionar-dissip-caixa refD offD PJ dir extB offB)
  )
)

;;; Modo alternativo (antigo): pelos limites (caixa) da geometria
(defun bb:posicionar-dissip-caixa (refD offD PJ dir extB offB / extD escD dist cx cy lat perp ptD)
  (setq extD (bb:ext-local refD))
  ;; mesma largura da boca (ponta a ponta das alas) x fator
  (if (and *BB:DISSIP-ESCALAR* (> (bb:largura extD offD) 1e-6))
    (progn
      (setq escD (/ (* (bb:largura extB offB) *BB:DISSIP-FATOR-LARG*)
                    (bb:largura extD offD)))
      (vla-put-XScaleFactor refD escD)
      (vla-put-YScaleFactor refD escD)
      (vla-put-ZScaleFactor refD escD)
      (vla-Update refD)
      (setq extD (bb:ext-local refD))
    )
  )
  ;; distancia ao longo do eixo + correcao lateral (centra no eixo)
  (setq dist (if (numberp *BB:DISSIP-AFAST*)
               *BB:DISSIP-AFAST*
               (+ (bb:ext-ao-longo extB offB 1.0)      ; face externa da boca
                  (bb:ext-ao-longo extD offD -1.0)     ; recuo do ponto base
                  (- (bb:encaixe-dissip refD offD))    ; encaixe: face interna
                  *BB:DISSIP-FOLGA*))
        cx   (/ (+ (nth 0 extD) (nth 1 extD)) 2.0)
        cy   (/ (+ (nth 2 extD) (nth 3 extD)) 2.0)
        lat  (bb:dot2 (list cx cy) (list (cos (bb:rad (+ offD 90.0))) (sin (bb:rad (+ offD 90.0)))))
        perp (list (- (cadr dir)) (car dir) 0.0)
        ptD  (bb:v- (bb:v+ PJ (bb:vs dir dist)) (bb:vs perp lat)))
  (vla-put-InsertionPoint refD (vlax-3d-point ptD))
  (bb:orientar-bloco refD offD dir)
  (vla-Update refD)
  ptD
)

;;; Mostra o 1o dissipador e pergunta se a rotacao esta certa.
;;; Retorna o offD final (ja corrigido).
(defun bb:confirmar-dissip (refD offD PJ dir extB offB ptD / k)
  (bb:zoom PJ (bb:v+ ptD (bb:vs (bb:v- ptD PJ) 1.0)))
  (while
    (progn
      (initget "Ok Girar Inverter Anti")
      (setq k (getkword
        "\nDissipador com rotacao certa? [Ok/Girar 90 horario/Inverter 180/Anti-horario 90] <Ok>: "))
      (and k (/= k "Ok"))
    )
    (setq offD (rem (+ offD (cond ((= k "Girar") 90.0) ((= k "Inverter") 180.0) (T 270.0))) 360.0))
    (setq ptD (bb:posicionar-dissip refD offD PJ dir extB offB))
  )
  (princ (strcat "\n>> Rotacao do dissipador = " (rtos offD 2 0)
                 " graus. Para nao perguntar mais, use (setq *BB:ROT-DISSIP* "
                 (rtos offD 2 0) ") na configuracao."))
  offD
)


;;; ===================== LOCALIZAR BLOCOS ==============================
(defun bb:achar-boca (doc / nm ss i ref ms tmp)
  ;; 1) nome configurado
  (if (and *BB:BLK-BOCA* (tblsearch "BLOCK" *BB:BLK-BOCA*))
    (setq nm *BB:BLK-BOCA*)
  )
  ;; 2) referencias ja inseridas no desenho
  (if (and (not nm) (setq ss (ssget "_X" '((0 . "INSERT")))))
    (progn
      (setq i 0)
      (while (and (not nm) (< i (sslength ss)) (< i 20000))
        (setq ref (vlax-ename->vla-object (ssname ss i)))
        (if (bb:eh-boca ref) (setq nm (vla-get-EffectiveName ref)))
        (setq i (1+ i))
      )
    )
  )
  ;; 3) definicoes de blocos dinamicos (insercao temporaria p/ testar)
  (if (not nm)
    (progn
      (setq ms (vla-get-ModelSpace doc))
      (vlax-for b (vla-get-Blocks doc)
        (if (and (not nm)
                 (not (bb:true-p (bb:prop b 'IsLayout)))
                 (not (bb:true-p (bb:prop b 'IsXRef)))
                 (/= (substr (vla-get-Name b) 1 1) "*")
                 (bb:true-p (bb:prop b 'IsDynamicBlock)))
          (progn
            (setq tmp (vl-catch-all-apply 'vla-InsertBlock
                        (list ms (vlax-3d-point '(0.0 0.0 0.0)) (vla-get-Name b) 1.0 1.0 1.0 0.0)))
            (if (not (vl-catch-all-error-p tmp))
              (progn
                (if (bb:eh-boca tmp) (setq nm (vla-get-Name b)))
                (vla-Delete tmp)
              )
            )
          )
        )
      )
    )
  )
  ;; 4) perguntar ao usuario
  (if (not nm)
    (progn
      (princ "\nBloco das bocas nao identificado automaticamente.")
      (setq ref (entsel "\nSelecione uma boca de bueiro existente <ENTER = digitar nome>: "))
      (if (and ref (= "INSERT" (cdr (assoc 0 (entget (car ref))))))
        (setq nm (vla-get-EffectiveName (vlax-ename->vla-object (car ref))))
        (progn
          (setq nm (getstring T "\nNome do bloco das bocas: "))
          (if (not (tblsearch "BLOCK" nm))
            (progn (princ (strcat "\nBloco \"" nm "\" nao existe no desenho.")) (setq nm nil))
          )
        )
      )
    )
  )
  (if nm (setq *BB:BLK-BOCA* nm))
  nm
)

(defun bb:achar-dissip ( / nm e)
  (cond
    ((and *BB:BLK-DISSIP* (tblsearch "BLOCK" *BB:BLK-DISSIP*)) (setq nm *BB:BLK-DISSIP*))
    (T
     (princ (strcat "\nBloco do dissipador \"" (vl-princ-to-string *BB:BLK-DISSIP*)
                    "\" nao encontrado."))
     (setq e (entsel "\nSelecione um dissipador existente <ENTER = digitar nome>: "))
     (if (and e (= "INSERT" (cdr (assoc 0 (entget (car e))))))
       (setq nm (vla-get-EffectiveName (vlax-ename->vla-object (car e))))
       (progn
         (setq nm (getstring T "\nNome do bloco do dissipador <ENTER = nao inserir dissipadores>: "))
         (cond
           ((= nm "") (setq nm nil))
           ((not (tblsearch "BLOCK" nm))
            (princ (strcat "\nBloco \"" nm "\" nao existe. Dissipadores nao serao inseridos."))
            (setq nm nil))
         )
       )
     )
     (if nm (setq *BB:BLK-DISSIP* nm))
    )
  )
  nm
)

(defun bb:get-dissip ()
  (if (not *bb:dissip-perguntado*)
    (setq *bb:dissip-nome*       (bb:achar-dissip)
          *bb:dissip-perguntado* T)
  )
  *bb:dissip-nome*
)


;;; ======================= LEITURA DOS CANOS ===========================
;;; Mostra no console o que foi lido de cada cano (T = sim)
(setq *BB:DEBUG* T)

;;; Le propriedade .NET pelo getpropertyvalue (nil se nao existir)
(defun bb:gpv (en name / r)
  (setq r (vl-catch-all-apply 'getpropertyvalue (list en name)))
  (if (vl-catch-all-error-p r) nil (bb:var->lisp r))
)

;;; Normaliza ponto: aceita (x y) ou (x y z); devolve (x y z) ou nil
(defun bb:pt (p)
  (cond
    ((bb:ponto-p p) p)
    ((and (listp p) (= 2 (length p)) (vl-every 'numberp p)) (list (car p) (cadr p) 0.0))
  )
)

(defun bb:num (lst / r)
  (foreach v lst (if (and (not r) (numberp v)) (setq r v)))
  r
)

(defun bb:fmt-pt (p)
  (strcat "(" (rtos (car p) 2 3) "," (rtos (cadr p) 2 3) "," (rtos (caddr p) 2 3) ")")
)

;;; Forma: "TC" tubular (circular) | "CC" celular (retangular/galeria)
(defun bb:forma (en obj d h / txt v)
  (setq txt "")
  (foreach v (append
               (mapcar '(lambda (p) (bb:gpv en p)) '("PartFamilyName" "PartSizeName" "Description"))
               (mapcar '(lambda (p) (bb:prop obj p)) '(Description PartFamilyName PartSizeName)))
    (if (= (type v) 'STR) (setq txt (strcat txt " " (strcase v))))
  )
  (cond
    ((wcmatch txt "*RETANG*,*RECTANG*,*BOX*,*CELUL*,*GALERIA*,*ADUELA*") "CC")
    ;; Description gravada pela propria LISP (tipo de obra: BSCC, BDCC, BTCC)
    ((wcmatch txt "* B[SDT]CC *") "CC")
    ((and (numberp h) (> (abs (- h d)) 0.01)) "CC")
    ;; acima do limite (1,50 m) o bueiro e CELULAR, mesmo modelado como tubo
    ((and (numberp d) *BB:CELULAR-ACIMA* (> d (+ *BB:CELULAR-ACIMA* 1e-6))) "CC")
    (T "TC")
  )
)

;;; Retorna (obj P_inicio P_fim D forma) ou nil.
;;; Tenta 3 fontes de geometria e so aceita a que tiver comprimento > 1 cm:
;;;   NET  = getpropertyvalue (API .NET do Civil 3D)
;;;   COM  = propriedades ActiveX
;;;   CURVA= funcoes vlax-curve
;;; Le uma propriedade de qualquer objeto COM (mesmo sem typelib)
(defun bb:try (o name / r)
  (setq r (vl-catch-all-apply 'vlax-get-property (list o name)))
  (if (vl-catch-all-error-p r)
    (setq r (vl-catch-all-apply 'vlax-get (list o name)))
  )
  (if (vl-catch-all-error-p r) nil (bb:var->lisp r))
)

;;; Converte o objeto IAeccPoint3d do Civil 3D (ou lista) em (x y z)
(defun bb:obj->pt (o / x y z c)
  (if (= (type o) 'VLA-OBJECT)
    (cond
      ((and (numberp (setq x (bb:try o 'X))) (numberp (setq y (bb:try o 'Y))))
       (list x y (if (numberp (setq z (bb:try o 'Z))) z 0.0)))
      ((setq c (bb:pt (bb:try o 'Coordinates))) c)
      ((setq c (bb:pt (bb:try o 'Location))) c)
      ((and (numberp (setq x (bb:try o 'Easting))) (numberp (setq y (bb:try o 'Northing))))
       (list x y (if (numberp (setq z (bb:try o 'Elevation))) z 0.0)))
    )
    (bb:pt o)
  )
)

;;; Ponto do cano no parametro t (metodo PointAtParam do Civil 3D)
(defun bb:pap (obj tt / r)
  (setq r (vl-catch-all-apply 'vlax-get-property (list obj 'PointAtParam tt)))
  (if (vl-catch-all-error-p r)
    nil
    (bb:obj->pt (bb:var->lisp r))
  )
)

(defun bb:ler-cano (en / obj cands p1 p2 fonte d h L2 L3 fd)
  (setq obj   (vlax-ename->vla-object en)
        L2    (bb:num (list (bb:prop obj 'Length2D) (bb:gpv en "Length2D")))
        L3    (bb:num (list (bb:prop obj 'Length3D) L2))
        cands (list
                ;; parametro normalizado 0..1 (inicio..fim)
                (list "PARAM" (bb:pap obj 0.0) (bb:pap obj 1.0))
                ;; parametro por comprimento 0..L
                (list "PARAM-L" (bb:pap obj 0.0) (if L3 (bb:pap obj L3)))
                (list "COM"   (bb:obj->pt (bb:prop obj 'StartPoint)) (bb:obj->pt (bb:prop obj 'EndPoint)))
                (list "NET"   (bb:pt (bb:gpv en "StartPoint")) (bb:pt (bb:gpv en "EndPoint")))
                (list "CURVA" (bb:pt (vl-catch-all-apply 'vlax-curve-getStartPoint (list obj)))
                              (bb:pt (vl-catch-all-apply 'vlax-curve-getEndPoint   (list obj))))))
  ;; aceita a primeira fonte coerente: comprimento > 1 cm e, se o
  ;; Length2D for conhecido, compativel com ele (5%)
  (foreach c cands
    (if (and (not fonte) (cadr c) (caddr c)
             (> (bb:d2 (cadr c) (caddr c)) 0.01)
             (or (not L2)
                 (< (abs (- (bb:d2 (cadr c) (caddr c)) L2)) (max 0.05 (* 0.05 L2)))))
      (setq fonte (car c) p1 (cadr c) p2 (caddr c))
    )
  )
  (setq d  (bb:num (list (bb:prop obj 'InnerDiameterOrWidth) (bb:gpv en "InnerDiameterOrWidth")
                         (bb:prop obj 'OuterDiameterOrWidth) (bb:gpv en "OuterDiameterOrWidth")))
        h  (bb:num (list (bb:prop obj 'InnerHeight) (bb:gpv en "InnerHeight")))
        fd (bb:num (list (bb:prop obj 'FlowDirection))))
  ;; catalogo em mm com desenho em m
  (if (and d (> d 20.0)) (setq d (/ d 1000.0)))
  (if (and h (> h 20.0)) (setq h (/ h 1000.0)))
  ;; cotas iguais -> usa a FlowDirection do Civil 3D (1 = inicio->fim, 2 = fim->inicio)
  (if (and fonte (< (abs (- (caddr p1) (caddr p2))) 1e-6))
    (cond
      ((= fd 1) (setq p1 (list (car p1) (cadr p1) (+ (caddr p1) 0.01))))
      ((= fd 2) (setq p2 (list (car p2) (cadr p2) (+ (caddr p2) 0.01))))
    )
  )
  (cond
    ((not fonte)
     (princ (strcat "\n  Cano " (vl-princ-to-string en)
                    ": nao foi possivel ler inicio/fim (rode BBDIAG neste cano)."))
     nil)
    ((not d)
     (princ (strcat "\n  Cano " (vl-princ-to-string en)
                    ": diametro nao encontrado (rode BBDIAG neste cano)."))
     nil)
    (T
     (if *BB:DEBUG*
       (princ (strcat "\n  Cano [" fonte "] ini=" (bb:fmt-pt p1) " fim=" (bb:fmt-pt p2)
                      " D=" (rtos d 2 3)))
     )
     (list obj p1 p2 d (bb:forma en obj d h) h))
  )
)

(defun bb:inverter (c) (list (nth 0 c) (nth 2 c) (nth 1 c) (nth 3 c) (nth 4 c) (nth 5 c)))

;;; Agrupa canos paralelos e proximos (cada grupo = um bueiro) e confere
;;; se as cotas das pipes do mesmo bueiro sao coerentes entre si.
(defun bb:agrupar (canos)
  (mapcar 'bb:z-coerente (bb:agrupar-0 canos)))

;;; Pipes de um mesmo bueiro (duplo/triplo) ficam lado a lado, na mesma
;;; cota. Uma pipe com cota muito diferente das outras (ex.: copiada com
;;; deslocamento em Z) estragava a media: geratriz, COGO, aterro e perfil
;;; saiam centenas de metros fora. No triplo, a pipe fora da mediana tem as
;;; cotas trocadas (so na leitura, o desenho nao muda) e e avisada; no
;;; duplo nao da para saber qual esta certa: so avisa.
(defun bb:z-coerente (g / zs med tol zm dzc out)
  (if (> (length g) 1)
    (progn
      (setq zs  (mapcar '(lambda (c) (/ (+ (caddr (nth 1 c)) (caddr (nth 2 c))) 2.0)) g)
            tol (max 1.0 (apply 'max (mapcar 'cadddr g))))
      (cond
        ((> (length g) 2)
         (setq med (nth (/ (length zs) 2) (vl-sort zs '<)))
         (foreach c g
           (setq zm  (/ (+ (caddr (nth 1 c)) (caddr (nth 2 c))) 2.0)
                 dzc (- med zm))
           (if (> (abs dzc) tol)
             (progn
               (princ (strcat "\n  AVISO: pipe " (vla-get-Handle (car c)) " com cota "
                              (rtos zm 2 3) " fora das outras do bueiro (" (rtos med 2 3)
                              "). Usada a cota das outras; CORRIJA A PIPE NO DESENHO."))
               (setq c (list (nth 0 c)
                             (list (car (nth 1 c)) (cadr (nth 1 c)) (+ (caddr (nth 1 c)) dzc))
                             (list (car (nth 2 c)) (cadr (nth 2 c)) (+ (caddr (nth 2 c)) dzc))
                             (nth 3 c) (nth 4 c) (nth 5 c)))))
           (setq out (cons c out)))
         (setq g (reverse out)))
        ((> (abs (- (car zs) (cadr zs))) tol)
         (princ (strcat "\n  AVISO: pipes " (vla-get-Handle (car (car g))) " e "
                        (vla-get-Handle (car (cadr g))) " do mesmo bueiro com cotas "
                        (rtos (car zs) 2 3) " e " (rtos (cadr zs) 2 3)
                        ". CORRIJA A PIPE ERRADA NO DESENHO (cotas e aterro saem errados)."))))))
  g)

(defun bb:agrupar-0 (canos / grupos r g rest u1 u2 lim)
  (while canos
    (setq r     (car canos)
          canos (cdr canos)
          g     (list r)
          rest  nil
          u1    (bb:unit2 (bb:v- (nth 2 r) (nth 1 r))))
    (foreach o canos
      (setq u2  (bb:unit2 (bb:v- (nth 2 o) (nth 1 o)))
            lim (+ 1.0 (* *BB:FATOR-AGRUP* (max (nth 3 r) (nth 3 o)))))
      (if (and u1 u2
               (< (abs (bb:cross2 u1 u2)) (sin (bb:rad *BB:ANG-TOL*)))
               (< (min (bb:d2 (nth 1 r) (nth 1 o)) (bb:d2 (nth 1 r) (nth 2 o))) lim))
        (setq g (cons o g))
        (setq rest (cons o rest))
      )
    )
    (setq canos  (reverse rest)
          grupos (cons (reverse g) grupos))
  )
  (reverse grupos)
)

;;; Alinha todos os canos do grupo no mesmo sentido e soma (Zini - Zfim)
(defun bb:orientar (g / ref out dz)
  (setq ref (bb:unit2 (bb:v- (nth 2 (car g)) (nth 1 (car g))))
        dz  0.0)
  (foreach c g
    (if (and ref (bb:unit2 (bb:v- (nth 2 c) (nth 1 c)))
             (< (bb:dot2 (bb:unit2 (bb:v- (nth 2 c) (nth 1 c))) ref) 0.0))
      (setq c (bb:inverter c))
    )
    (setq dz  (+ dz (- (caddr (nth 1 c)) (caddr (nth 2 c))))
          out (cons c out))
  )
  (list (reverse out) dz)
)


;;; ================= DISSIPADOR DNIT (DEB) - planta e corte =============
;;; T = usa o dissipador DNIT (DEB) gerado pela tabela; nil = bloco antigo
;;; "DISSIPADOR" escalado (*BB:BLK-DISSIP*, BBCALIB).
(setq *BB:DISSIP-DNIT* T)
(setq *BB:COR-DISSIP*  7)       ; cor do dissipador (7 = white | nil = ByLayer)
(setq *BB:DISSIP-HATCH* "GRAVEL") ; hatch da pedra de mao em planta (nil = desenhar pedras)
(setq *BB:DISSIP-HATCH-ESC* 0.05) ; escala do hatch

;;; (codigo D comprimento largura) em cm - DEB "Comprimento" x "Largura"
;;; Largura = largura total da boca (L); comprimento = 3 x D.
(setq *bb:deb* '(
  ("BSTC" 0.60 180 263) ("BSTC" 0.80 240 316) ("BSTC" 1.00 300 366)
  ("BSTC" 1.20 360 414) ("BSTC" 1.50 450 551)
  ("BDTC" 1.00 300 511) ("BDTC" 1.20 360 584) ("BDTC" 1.50 450 746)
  ("BTTC" 1.00 300 666) ("BTTC" 1.20 360 754) ("BTTC" 1.50 450 956)))

;;; (bloco comprimento largura rotulo) - medidas em metros, rotulo no padrao
;;; DNIT "DEB 300-366" - ou nil se nao houver DEB
(defun bb:deb-param (code d / best)
  (foreach r *bb:deb*
    (if (and (= (car r) code) (<= (abs (- (cadr r) d)) 0.05)) (setq best r)))
  (if best
    (list (strcat "DEB_" code (itoa (fix (+ 0.5 (* 100.0 (cadr best))))))
          (* 0.01 (caddr best))
          (* 0.01 (cadddr best))
          (strcat "DEB " (itoa (caddr best)) "-" (itoa (cadddr best))))))

;;; ----------------------- TEXTOS E COTAS ------------------------------
;;; Textos (DEB, MONTANTE, JUSANTE) e cotas a partir do eixo, planta e perfil
(setq *BB:ROTULOS*   T)                    ; nil = nao escreve textos nem cotas
(setq *BB:TXT-ALT*   0.50)                 ; altura dos textos (unidades do desenho)
(setq *BB:COR-TXT*   7)                    ; 7 = white
(setq *BB:LAYER-TXT* "OBRAS PROJETADAS")
(setq *BB:EIXO-NOME* "")                   ; alinhamento do eixo da rodovia ("" = automatico)
(setq *BB:COTA-DESL* 1.0)                  ; cota: distancia da linha abaixo do fundo do cano
;;; Estilos de cota (padrao wcmatch, sem acento: "?" = qualquer letra;
;;; se nao existir no desenho, fica o corrente com texto Arial)
(setq *BB:COTA-ESTILO*     "COTA - SE??ES")  ; PLANTA: cotas a partir do eixo ("COTA - SECOES" com acento)
(setq *BB:COTA-ESTILO-PF*  "DIM MONT JUS. PERFIL") ; PERFIL: cotas do eixo ate montante/jusante
(setq *BB:COTA-ESTILO-REC* "PERFIL,REC PERFIL") ; PERFIL: recobrimento (altura de aterro) e diametro
(setq *BB:COTA-ESTILO-DPL* "Macc_Esc100")    ; PLANTA: diametro (DIM) do bueiro
(setq *BB:TXT-ALT-PL*      0.80)             ; PLANTA: altura de MONTANTE / JUSANTE
(setq *BB:LAYER-COGO*      "COGOPOINTBUEIRO"); layer dos COGO points no eixo
(setq *BB:TXT-DESL-BOCA* 1.0)              ; perfil: MONTANTE/JUSANTE descem mais isto
(setq *BB:TXT-DESL-DEB*  2.0)              ; perfil: nome do DEB anda isto p/ fora (fluxo)
(setq *BB:TXT-FOLGA*     0.8)              ; planta: folga entre a ponta e o texto
(setq *BB:COTA-DESL-PL*  1.5)              ; planta: cota afastada isto alem da lateral dos tubos

;;; ---------------- ALTURA DE ATERRO NA LABEL DA PIPE ------------------
;;; O recobrimento calculado no eixo (greide - topo externo do cano) e
;;; gravado numa propriedade NUMERICA da propria pipe que nao e usada em
;;; bueiro: Energy Grade Line Up (EGL). O "Maximum Cover" nao pode ser
;;; gravado (o Civil 3D calcula sozinho) e a Description fica livre.
;;; Na label style da pipe, troque o "Maximum Cover" por
;;; "Energy Grade Line Up" (precisao 0.1).
;;; ATENCAO: se rodar analise hidraulica no Civil 3D, ela sobrescreve a
;;; EGL -> rode BBATERRO de novo depois.
(setq *BB:ATERRO-GRAVAR* T)              ; nil = nao grava nada na pipe
;;; nomes possiveis da propriedade (.NET / COM), tentados em ordem
(setq *BB:ATERRO-PROP*   '("EnergyGradeLineUp" "EGLUp" "EnergyGradeLineUpstream"))
(setq *BB:ATERRO-PREC*   3)              ; casas gravadas (a label arredonda)
;;; ---------------- TIPO DE OBRA NAS LABELS (PLANTA E PERFIL)--------------
;;; Grava na Description de cada pipe o tipo de obra (mesmo da BBPLANILHA):
;;;   celular (3o caractere do tipo = C): "BDCC 3.00x3.00m" (largura x altura)
;;;   tubular:                            "BTTC d=1.50m"
;;; e troca, nos estilos das labels de PLANTA e PERFIL dessas pipes, o diametro
;;; (%%C:<[Pipe Inner Diameter or Width]>) pelo campo da Description.
;;; Refeito a cada execucao - BBT, BBTB, BBTD, BBX, BBU, BBATERRO e BBOBRA.
(setq *BB:OBRA-GRAVAR* T)                ; nil = nao grava nem mexe no estilo
(setq *BB:OBRA-CAMPO*  "<[Pipe Description(CP)]>")
(setq *BB:OBRA-CASAS*  2)                ; casas das dimensoes (3.00)
;;; linha posta no fim da label se o estilo nao mostrar a altura de aterro
(setq *BB:ATERRO-LINHA* "\\PAltura de Aterro: <[Energy Grade Line Up(Um|P2|RN|AP|GC|UN|Sn|OF)]>m")
;;; Labels de planta e perfil dos bueiros voltam a seguir o estilo: descarta o texto
;;; editado na propria label (Edit Label Text, plugin AlturaAterroV4), que
;;; passa por cima do estilo e esconderia o tipo de obra.
(setq *BB:OBRA-LIMPA-LABEL* T)           ; nil = nao mexe nas labels
;;; ---------------- COGO POINT NO EIXO ---------------------------------
;;; UM COGO point por bueiro (simples, duplo ou triplo), onde o eixo da
;;; rodovia cruza o alinhamento (linha de centro) do bueiro, com a cota
;;; da face escolhida. Refeito (apaga o anterior) a cada
;;; execucao - BBT, BBTB, BBTD, BBX, BBU, BBP e BBATERRO.
(setq *BB:COGO*      T)                  ; nil = nao cria COGO points
;;; "SUP" = geratriz superior interna (teto interno = fundo + diametro)
;;; "INF" = geratriz inferior interna (fundo) | "EXT" = topo externo
(setq *BB:COGO-FACE* "SUP")
(setq *BB:COGO-DESC* "BUEIRO EIXO")     ; descricao (raw description) do ponto
(setq *bb:civ-progid* nil)               ; interno: ProgID do Civil 3D achado

(setq *bb:so-aterro* nil)                ; interno: T no comando BBATERRO
(setq *bb:canos-cota* nil)               ; interno: canos do bueiro em processamento
(setq *bb:aterro-nome* nil)              ; interno: nome da propriedade que funcionou

(setq *BB:TXT-ESTILO* "BB_ARIAL")         ; estilo dos textos e cotas
(setq *BB:TXT-FONTE*  "arial.ttf")        ; fonte do estilo (criado se nao existir)

;;; Estilo de texto Arial (cria se nao existir); devolve o nome
(defun bb:estilo-txt ()
  (if (not (tblsearch "STYLE" *BB:TXT-ESTILO*))
    (entmake (list '(0 . "STYLE") '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbTextStyleTableRecord") (cons 2 *BB:TXT-ESTILO*)
                   '(70 . 0) '(40 . 0.0) '(41 . 1.0) '(50 . 0.0) '(71 . 0) '(42 . 0.5)
                   (cons 3 *BB:TXT-FONTE*) '(4 . ""))))
  (if (tblsearch "STYLE" *BB:TXT-ESTILO*) *BB:TXT-ESTILO* (getvar "TEXTSTYLE")))

(defun bb:layer-txt (/ lay)
  (setq lay (if (and *BB:LAYER-TXT* (/= *BB:LAYER-TXT* "")) *BB:LAYER-TXT* (getvar "CLAYER")))
  (if (not (tblsearch "LAYER" lay))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbLayerTableRecord")
                   (cons 2 lay) '(70 . 0) (cons 62 *BB:COR-LAYER*) '(6 . "Continuous"))))
  lay)

;;; Texto de uma linha (DTEXT) em PT. J72/J73 = justificacao horizontal /
;;; vertical (1/3 = centro/topo, 1/2 = centro/meio, 1/1 = centro/base).
(defun bb:texto (str pt alt j72 j73 rot)
  (if (and *BB:ROTULOS*
           (entmake (append
                      (list '(0 . "TEXT") (cons 8 (bb:layer-txt))
                            (cons 10 pt) (cons 11 pt) (cons 40 alt) (cons 1 str) (cons 50 rot)
                            (cons 7 (bb:estilo-txt)) (cons 72 j72) (cons 73 j73))
                      (if *BB:COR-TXT* (list (cons 62 *BB:COR-TXT*))))))
    (bb:tag (entlast))))

;;; Texto em planta que COMECA em PT e cresce no sentido FORA (vetor),
;;; sem passar por cima da boca/dissipador: justificado a esquerda ou a
;;; direita conforme o angulo de leitura ANG.
(defun bb:texto-fora (str pt fora ang)
  (if (>= (bb:dot2 (list (cos ang) (sin ang)) fora) 0.0)
    (bb:texto str pt *BB:TXT-ALT-PL* 0 2 ang)     ; meio-esquerda
    (bb:texto str pt *BB:TXT-ALT-PL* 2 2 ang)))   ; meio-direita

;;; Angulo de texto ao longo de V, sempre legivel (nunca de cabeca p/ baixo)
(defun bb:ang-legivel (v / a)
  (setq a (angle '(0.0 0.0) (list (car v) (cadr v))))
  (if (and (> a (* 0.5 pi)) (<= a (* 1.5 pi))) (- a pi) a))

;;; Comprimento total da boca tubular (m) = onde o dissipador encaixa
(defun bb:boca-comp (code d / prm)
  (if (setq prm (bb:corte-param "TC" code d nil)) (nth 7 prm)))

;;; Numero pseudo-aleatorio 0..1 (repetivel: mesma semente = mesmas pedras)
(defun bb:rnd ()
  (setq *bb:seed* (rem (* *bb:seed* 16807.0) 2147483647.0))
  (/ *bb:seed* 2147483647.0))

;;; Pedra de mao irregular (poligono) de raio ~r em (cx cy)
(defun bb:pedra (spc cx cy r / n i a rr pts)
  (setq n (+ 7 (fix (* 3.0 (bb:rnd)))) i 0)
  (repeat n
    (setq a   (+ (* i (/ (* 2.0 pi) n)) (* 0.3 (- (bb:rnd) 0.5)))
          rr  (* r (+ 0.75 (* 0.35 (bb:rnd))))
          pts (cons (list (+ cx (* rr (cos a))) (+ cy (* rr (sin a)))) pts)
          i   (1+ i)))
  (bb:addpl-c spc (reverse pts) T *BB:COR-DISSIP*))

(defun bb:novo-bloco (nome)
  (vla-Add (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object)))
           (vlax-3d-point '(0.0 0.0 0.0)) nome))

;;; Hatch (sem associatividade) dentro da polilinha fechada BND
(defun bb:hatch (spc bnd pat esc cor / h arr)
  (setq h (vl-catch-all-apply 'vla-AddHatch (list spc acHatchPatternTypePreDefined pat :vlax-false)))
  (if (not (vl-catch-all-error-p h))
    (progn
      (setq arr (vlax-make-safearray vlax-vbObject '(0 . 0)))
      (vlax-safearray-put-element arr 0 bnd)
      (if (vl-catch-all-error-p
            (vl-catch-all-apply 'vla-AppendOuterLoop (list h (vlax-make-variant arr))))
        (progn (vla-Delete h) (setq h nil))
        (progn
          (vla-put-PatternScale h esc)
          (if cor (vla-put-Color h cor))
          (vl-catch-all-apply 'vla-Evaluate (list h))
          h)))))

;;; DEB em PLANTA (m). Origem = ponto de encaixe (face externa da boca) no
;;; eixo; +X = sentido do fluxo. Pedra de mao de 0 a C (hatch); paredes
;;; laterais de 10 cm avancando 30 cm para tras; parede final de 10 cm.
(defun bb:deb-planta (deb / nome c h blk s tt bnd)
  (setq nome (strcat (car deb) "_PL2"))
  (if (not (tblsearch "BLOCK" nome))
    (progn
      (setq c (nth 1 deb) h (/ (nth 2 deb) 2.0) blk (bb:novo-bloco nome) *bb:seed* 12345.0)
      (bb:addpl-c blk (list (list -0.30 (+ h 0.10)) (list (+ c 0.10) (+ h 0.10))
                            (list (+ c 0.10) (- (+ h 0.10))) (list -0.30 (- (+ h 0.10)))
                            (list -0.30 (- h)) (list c (- h)) (list c h) (list -0.30 h))
                  T *BB:COR-DISSIP*)
      ;; area da pedra de mao
      (setq bnd (bb:addpl-c blk (list (list 0.0 (- h)) (list c (- h)) (list c h) (list 0.0 h))
                            T *BB:COR-DISSIP*))
      (if (not (and *BB:DISSIP-HATCH*
                    (bb:hatch blk bnd *BB:DISSIP-HATCH* *BB:DISSIP-HATCH-ESC* *BB:COR-DISSIP*)))
        ;; sem hatch: desenha as pedras
        (progn
          (setq s 0.16)
          (while (< s (- c 0.12))
            (setq tt (+ (- h) 0.16))
            (while (< tt (- h 0.12))
              (bb:pedra blk (+ s (* 0.08 (- (bb:rnd) 0.5))) (+ tt (* 0.08 (- (bb:rnd) 0.5)))
                        (+ 0.06 (* 0.05 (bb:rnd))))
              (setq tt (+ tt 0.32)))
            (setq s (+ s 0.32)))))))
  nome)

;;; DEB em CORTE (m). Origem = ponto de encaixe na cota do fundo da boca
;;; (topo do concreto de fixacao); +X = fluxo. Laje 10 + concreto 10 abaixo,
;;; pedras de mao por cima, paredes 15 cm acima do fundo.
(defun bb:deb-corte (deb / nome c blk s)
  (setq nome (strcat (car deb) "_CT2"))
  (if (not (tblsearch "BLOCK" nome))
    (progn
      (setq c (nth 1 deb) blk (bb:novo-bloco nome) *bb:seed* 54321.0)
      (bb:addpl-c blk (list (list 0.0 0.0) (list 0.0 -0.20) (list (+ c 0.10) -0.20)
                            (list (+ c 0.10) 0.15) (list c 0.15) (list c 0.0))
                  T *BB:COR-DISSIP*)
      (bb:addpl-c blk (list (list 0.0 -0.10) (list c -0.10)) nil *BB:COR-DISSIP*)
      (bb:addpl-c blk (list (list -0.30 0.0) (list -0.30 0.15) (list c 0.15)) nil *BB:COR-DISSIP*)
      (setq s 0.16)
      (while (< s (- c 0.12))
        (bb:pedra blk (+ s (* 0.06 (- (bb:rnd) 0.5))) (+ 0.03 (* 0.02 (bb:rnd)))
                  (+ 0.075 (* 0.045 (bb:rnd))))
        (setq s (+ s 0.30)))))
  nome)


;;; ======================= PROCESSA UM BUEIRO ==========================
(defun bb:processar (g idx blk / n txt res canos dz pk PM PJ D HC shp dir code
                                 refM refJ stM refD blkD dist ptD dis extB offB extD offD escD cal
                                 deb mB debL mT ang)
  (setq n   (length g)
        txt (strcat "\nBueiro " (itoa idx) ": "))
  (if (> n 3)
    (progn
      (princ (strcat txt (itoa n) " canos paralelos (maximo = triplo). Ignorado."))
      nil
    )
    (progn
      ;; ---------- sentido do fluxo (montante -> jusante) ----------
      (setq *bb:etapa* "fluxo")
      (setq res   (bb:orientar g)
            canos (car res)
            dz    (cadr res))
      (cond
        ((> dz *BB:TOL-Z*))                                   ; inicio = montante
        ((< dz (- *BB:TOL-Z*)) (setq canos (mapcar 'bb:inverter canos)))
        (T
         (bb:zoom (bb:media (mapcar 'cadr canos)) (bb:media (mapcar 'caddr canos)))
         (setq pk (getpoint (strcat txt "cotas iguais nas extremidades. Clique perto da JUSANTE <ENTER = pular>: ")))
         (if pk
           (progn
             (setq pk (trans pk 1 0))
             (if (< (bb:d2 pk (bb:media (mapcar 'cadr canos)))
                    (bb:d2 pk (bb:media (mapcar 'caddr canos))))
               (setq canos (mapcar 'bb:inverter canos))
             )
           )
           (setq canos nil)
         )
        )
      )
      (if (not canos)
        (progn (princ (strcat txt "pulado.")) nil)
        (progn
          ;; ---------- geometria ----------
          (setq PM  (bb:media (mapcar 'cadr canos))
                PJ  (bb:media (mapcar 'caddr canos))
                D   (apply 'max (mapcar 'cadddr canos))
                shp (if (member "CC" (mapcar '(lambda (c) (nth 4 c)) canos)) "CC" "TC")
                HC  (if (= shp "CC")
                      (bb:num (list (apply 'max (cons 0.0 (vl-remove-if-not 'numberp
                                                  (mapcar '(lambda (c) (nth 5 c)) canos)))))))
                dir (bb:unit2 (bb:v- PJ PM)))
          (if (and HC (<= HC 0.0)) (setq HC nil))
          (if (not *BB:USAR-Z*)
            (setq PM (list (car PM) (cadr PM) 0.0)
                  PJ (list (car PJ) (cadr PJ) 0.0))
          )
          (setq code (strcat "B" (nth (1- n) '("S" "D" "T")) shp))

          ;; ---------- etiqueta + apaga o que a execucao anterior fez aqui ----------
          (setq *bb:tag-key*  (bb:chave canos)
                *bb:tag-onde* "PL"
                *bb:tag-tipo* "B"
                *bb:canos-cota* canos)          ; p/ o L da obra nas cotas do eixo
          (bb:limpar-auto "PL")
          (bb:cogo-bueiro canos)              ; COGO point no eixo

          ;; ---------- boca de montante ----------
          (setq *bb:etapa* "boca montante")
          (setq refM (bb:inserir blk PM 0.0 *BB:LAYER-BOCA*)
                stM  (bb:set-vis refM code D HC))
          (if (not stM)
            (progn
              (vla-Delete refM)
              (princ (strcat txt "o bloco \"" blk "\" nao tem estado para " code ". Ignorado."))
              nil
            )
            (progn
              ;; orientacao: manual (numero) ou detectada pela geometria
              (setq extB (bb:ext-local refM)
                    offB (if (numberp *BB:ROT-BOCA*) *BB:ROT-BOCA* (bb:auto-off extB)))
              (bb:orientar-bloco refM offB (bb:vs dir -1.0))
              ;; ---------- boca de jusante ----------
              (setq *bb:etapa* "boca jusante")
              (setq refJ (bb:inserir blk PJ 0.0 *BB:LAYER-BOCA*))
              (bb:set-vis refJ code D HC)
              (bb:orientar-bloco refJ offB dir)
              (bb:pintar-ref refM *BB:COR-BOCA*)
              (bb:pintar-ref refJ *BB:COR-BOCA*)
              (if (> (cadr stM) *BB:TOL-DIAM*)
                (princ (strcat txt "AVISO - o bloco \"" blk "\" nao tem estado para "
                               code " " (rtos D 2 2) " m; usado \"" (car stM) "\"."
                               "\n   Se o bloco for antigo, carregue o TEMPLATE_BOCAS e rode"
                               " BOCASCADDIN para recriar com todos os tamanhos."))
              )
              ;; ---------- dissipador (tubular e D <= / < limite) ----------
              (setq dis "nao" *bb:tag-tipo* "D")
              (if (and *bb:fazer-dissip*
                       (= shp "TC")
                       (if *BB:DISSIP-ATE-LIMITE*
                         (<= D (+ *BB:DIAM-LIMITE* 1e-6))
                         (<  D (- *BB:DIAM-LIMITE* 1e-6))))
                (cond
                  ;; ---- DNIT: DEB gerado pela tabela, encaixado na ponta da boca ----
                  ((and *BB:DISSIP-DNIT*
                        (setq deb (bb:deb-param code D))
                        (setq mB (bb:boca-comp code D)))
                   (setq *bb:etapa* "dissipador")
                   (setq refD (bb:inserir (bb:deb-planta deb)
                                          (bb:v+ PJ (bb:vs dir mB))
                                          (angle '(0.0 0.0) dir)
                                          *BB:LAYER-DISSIP*))
                   (setq debL (+ (nth 1 deb) 0.10)
                         dis  (strcat "sim (" (car deb) ")")))
                  (*BB:DISSIP-DNIT*
                   (setq dis (strcat "nao (sem DEB DNIT para " code " " (rtos D 2 2) ")")))
                  ((setq blkD (bb:get-dissip))
                    (setq *bb:etapa* "dissipador")
                    (setq refD (bb:inserir blkD PJ 0.0 *BB:LAYER-DISSIP*))
                    (bb:set-vis refD code D HC)  ; se o dissipador tambem for dinamico
                    (if (setq cal (bb:calib-ler))
                      ;; ---- calibrado com BBCALIB: copia o encaixe modelo ----
                      (bb:posicionar-calib refD refJ offB cal)
                      ;; ---- sem calibracao: deteccao automatica ----
                      (progn
                        (setq extD (bb:ext-local refD)
                              offD (cond ((numberp *BB:ROT-DISSIP*) *BB:ROT-DISSIP*)
                                         (*bb:rot-dissip-sessao*)
                                         (T (bb:auto-off-dissip extD))))
                        (setq *bb:boca-jus* refJ
                              ptD (bb:posicionar-dissip refD offD PJ dir extB offB))
                        ;; 1o dissipador sem angulo definido: confirma com o usuario
                        (if (and *BB:DISSIP-CONFIRMAR*
                                 (not (numberp *BB:ROT-DISSIP*))
                                 (not *bb:rot-dissip-sessao*))
                          (setq offD (bb:confirmar-dissip refD offD PJ dir extB offB ptD)
                                *bb:rot-dissip-sessao* offD)
                        )
                      )
                    )
                    (setq dis (strcat "sim (escala " (rtos (vla-get-XScaleFactor refD) 2 2) ")"))
                  )
                  (T (setq dis "nao (bloco indisponivel)"))
                )
              )
              ;; textos MONTANTE / JUSANTE alem da ponta de cada boca
              ;; (na jusante, alem do dissipador)
              (setq *bb:tag-tipo* "B")
              (if (and *bb:fazer-bocas* *BB:ROTULOS*
                       (setq mT (nth 7 (bb:corte-param shp code D HC))))
                (progn
                  (setq ang (bb:ang-legivel dir))
                  (bb:texto-fora "MONTANTE" (bb:v- PM (bb:vs dir (+ mT *BB:TXT-FOLGA*)))
                                 (bb:vs dir -1.0) ang)
                  (bb:texto-fora "JUSANTE"
                                 (bb:v+ PJ (bb:vs dir (+ mT (if debL debL 0.0) *BB:TXT-FOLGA*)))
                                 dir ang)
                  ;; cotas do eixo da rodovia ate as pontas (largura do feixe de tubos)
                  (bb:planta-cotas PM PJ dir (+ (* n D) (* (1- n) 0.5)))
                  ;; diametro (DIM) do 1o cano na montante
                  (bb:planta-cota-diam (nth 1 (car canos)) dir (nth 3 (car canos)))))
              ;; "so dissipador": as bocas serviram so de referencia
              (if (not *bb:fazer-bocas*)
                (progn (vla-Delete refM) (vla-Delete refJ)))
              (princ (strcat txt (itoa n) " x D=" (rtos D 2 2) " m "
                             (if (= shp "TC") "tubular" "celular")
                             " -> \"" (car stM) "\""
                             " | jusante em " (rtos (car PJ) 2 3) "," (rtos (cadr PJ) 2 3)
                             " | dissipador: " dis
                             " | giro boca: " (rtos offB 2 0) " graus"))
              T
            )
          )
        )
      )
    )
  )
)


;;; ============================ COMANDO ================================
(defun c:BOCASBUEIRO (/ *error* doc blk ss i c canos grupos idx ok falhas)
  (defun *error* (msg)
    (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg "  (etapa: " (vl-princ-to-string *bb:etapa*) ")"))
    )
    (princ)
  )
  (princ "\n[BOCAS_BUEIRO - planta]")
  (bb:modo T T T T)
  (setq doc                    (vla-get-ActiveDocument (vlax-get-acad-object))
        *bb:dissip-perguntado* nil
        *bb:dissip-nome*       nil
        *bb:rot-dissip-sessao* nil
        *bb:pintados*          nil
        falhas                 0
        ok                     0)

  (if (not (setq blk (bb:achar-boca doc)))
    (progn (princ "\nBloco das bocas nao definido. Comando cancelado.") (exit))
  )
  (princ (strcat "\nBloco das bocas: " blk))

  (princ "\nSelecione os canos (pipes) dos bueiros: ")
  (if (not (setq ss (ssget '((0 . "AECC_PIPE")))))
    (progn (princ "\nNenhum cano selecionado.") (exit))
  )
  (setq *bb:etapa* "leitura dos canos" i 0)
  (repeat (sslength ss)
    (if (setq c (bb:ler-cano (ssname ss i)))
      (setq canos (cons c canos))
      (setq falhas (1+ falhas))
    )
    (setq i (1+ i))
  )
  (if (> falhas 0)
    (princ (strcat "\n" (itoa falhas) " cano(s) sem propriedades legiveis foram ignorados."))
  )
  (if (not canos) (exit))
  (setq *bb:etapa* "agrupamento")
  (setq grupos (bb:agrupar (reverse canos)))
  (princ (strcat "\n" (itoa (length canos)) " cano(s) -> " (itoa (length grupos)) " bueiro(s)."))

  (vla-StartUndoMark doc)
  (setq idx 0)
  (foreach g grupos
    (setq idx (1+ idx))
    (if (bb:processar g idx blk) (setq ok (1+ ok)))
  )
  ;; altura de aterro na label da pipe (pelos Profile Views do desenho)
  (setq *bb:etapa* "altura de aterro")
  (bb:aterro-perfis grupos)
  ;; tipo de obra nas labels de planta e perfil
  (setq *bb:etapa* "tipo de obra")
  (if *BB:OBRA-GRAVAR* (bb:obra-grupos grupos))
  (vla-EndUndoMark doc)
  (princ (strcat "\nConcluido: " (itoa ok) " de " (itoa (length grupos))
                 " bueiro(s) com bocas inseridas. (U desfaz tudo)"))
  (princ)
)

(defun c:BBU () (c:BOCASBUEIRO))


;;; ===================== BOCAS NO PERFIL (BOCASPERFIL) =================
;;; Voce seleciona um ou mais Profile Views. Para cada um, o programa le
;;; todos os canos do desenho, agrupa em bueiros, ve quais estao sobre o
;;; alinhamento do perfil e insere a boca em CORTE na montante e na
;;; jusante, na geratriz inferior e na escala vertical do perfil.
;;;
;;; Onde a boca fica em relacao a ponta do cano no perfil:
;;;  "TESTA"   = face EXTERNA da testa na ponta do cano (o cano atravessa
;;;              a testa; alas, soleira e dente ficam para fora do cano)
;;;  "INTERNA" = face interna da testa na ponta do cano
;;;  "PONTA"   = extremidade externa da boca (dente) na ponta do cano
(setq *BB:PERFIL-REF*     "INTERNA")
(setq *BB:PERFIL-DZ*      0.0)    ; correcao vertical manual da boca no perfil (m)
(setq *BB:PERFIL-TOL-OFF* 5.0)    ; afastamento max. (m) do bueiro ao alinhamento
(setq *BB:PERFIL-UM*      T)      ; T = so 1 bueiro por perfil (o mais proximo do alinhamento)
(setq *BB:CORTE-DENTE*    20.0)   ; largura do dente no fim da soleira (cm)

;;; Corte das bocas (cm), tabelas DNIT BNAA:
;;;  b = testa, c = ala, h = altura da testa acima da geratriz inferior,
;;;  e = soleira, n = dente abaixo da soleira, p = altura da ponta da ala,
;;;  M = comprimento total
;;; Tubular: (codigo D b c h e n p M)
(setq *bb:corte-tc* '(
  ("BSTC" 0.60 20 125  88 15 30 20 155)
  ("BSTC" 0.80 25 145 120 20 30 20 180)
  ("BSTC" 1.00 30 165 142 25 40 25 205)
  ("BSTC" 1.20 40 180 163 30 40 25 230)
  ("BSTC" 1.50 50 260 194 35 40 30 320)
  ("BDTC" 1.00 30 165 142 30 40 25 205)
  ("BDTC" 1.20 40 180 163 35 40 25 230)
  ("BDTC" 1.50 50 260 194 35 40 30 320)
  ("BTTC" 1.00 30 165 142 35 40 25 205)
  ("BTTC" 1.20 40 180 163 40 40 25 230)
  ("BTTC" 1.50 50 260 194 40 40 30 320)
  ;; 2.00 / 2.50 / 3.00 = EXTRAPOLADO (fora das tabelas DNIT)
  ("BSTC" 2.00  65 345 244 35 45 45 420)
  ("BSTC" 2.50  85 435 294 40 50 60 530)
  ("BSTC" 3.00 100 520 344 40 55 70 630)
  ("BDTC" 2.00  65 345 244 35 45 45 420)
  ("BDTC" 2.50  85 435 294 40 50 60 530)
  ("BDTC" 3.00 100 520 344 40 55 70 630)
  ("BTTC" 2.00  65 345 244 35 45 45 420)
  ("BTTC" 2.50  85 435 294 40 50 60 530)
  ("BTTC" 3.00 100 520 344 40 55 70 630)))
;;; Celular (por altura H; o corte nao depende da largura nem do n. de celulas)
;;; (H b c h e n p M) - n e p NAO constam da tabela DNIT (valores adotados)
(setq *bb:corte-cc* '(
  (1.50 15 285 200 20 40 30 320)
  (2.00 20 355 250 20 40 30 395)
  (2.50 25 425 300 20 40 30 470)
  (3.00 30 495 350 25 40 30 545)))

;;; Parametros do corte em metros: (bloco b xa h e n p M)
;;; xa = onde termina a ala (tubular: b+c; celular: ate o fim da soleira)
(defun bb:corte-param (shp code d h / best bd dif v)
  (if (= shp "TC")
    (foreach r *bb:corte-tc*
      (if (= (car r) code)
        (progn
          (setq dif (abs (- (cadr r) d)))
          (if (or (null bd) (< dif bd)) (setq best r bd dif)))))
    (foreach r *bb:corte-cc*
      (setq dif (abs (- (car r) (if h h d))))
      (if (or (null bd) (< dif bd)) (setq best (cons "CC" r) bd dif))))
  (if best
    (progn
      (setq v (mapcar '(lambda (x) (* 0.01 x)) (cddr best)))   ; b c h e n p M
      ;; (bloco b xa h e n p M dc) - dc = diametro/altura interna do cano
      (list (strcat "BB_CORTE2_" (car best) (itoa (fix (+ 0.5 (* 100.0 (cadr best))))))
            (nth 0 v)
            (if (= shp "TC") (+ (nth 0 v) (nth 1 v)) (nth 6 v))
            (nth 2 v) (nth 3 v) (nth 4 v) (nth 5 v) (nth 6 v)
            (cadr best)))))

;;; Espessura de parede usual do tubo de concreto (m) p/ diametro interno d
(defun bb:parede-padrao (d) (+ 0.025 (/ d 12.0)))

(defun bb:addpl-c (spc pts fech cor / arr i o)
  (setq arr (vlax-make-safearray vlax-vbDouble (cons 0 (1- (* 2 (length pts)))))
        i   0)
  (foreach p pts
    (vlax-safearray-put-element arr i (float (car p)))
    (vlax-safearray-put-element arr (1+ i) (float (cadr p)))
    (setq i (+ i 2)))
  (setq o (vla-AddLightWeightPolyline spc (vlax-make-variant arr)))
  (if fech (vla-put-Closed o :vlax-true))
  (if cor (vla-put-Color o cor))
  o)

(defun bb:addpl (spc pts fech) (bb:addpl-c spc pts fech *BB:COR-BOCA*))

;;; Bloco do corte (m). Origem = geratriz inferior na face interna da
;;; testa; +X = para fora do bueiro. Cria so se ainda nao existir.
(defun bb:corte-bloco (prm / blk b xa h e n p mm wd dc w)
  (if (not (tblsearch "BLOCK" (car prm)))
    (progn
      (setq b (nth 1 prm) xa (nth 2 prm) h (nth 3 prm) e (nth 4 prm)
            n (nth 5 prm) p (nth 6 prm) mm (nth 7 prm) wd (* 0.01 *BB:CORTE-DENTE*)
            dc (nth 8 prm) w (bb:parede-padrao dc)
            blk (vla-Add (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object)))
                         (vlax-3d-point '(0.0 0.0 0.0)) (car prm)))
      (bb:addpl blk (list (list 0.0 0.0) (list b 0.0) (list b h) (list 0.0 h)) T)       ; testa
      (bb:addpl blk (list (list b h) (list xa p) (list xa 0.0)) nil)                     ; ala
      (bb:addpl blk (list (list 0.0 0.0) (list mm 0.0) (list mm (- e)) (list 0.0 (- e))) T) ; soleira
      (bb:addpl blk (list (list (- mm wd) (- e)) (list mm (- e))                         ; dente
                          (list mm (- (+ e n))) (list (- mm wd) (- (+ e n)))) T)
      ;; projecao do cano atravessando a testa (fundo/topo interno e externo):
      ;; alinha com as linhas da pipe no perfil
      (foreach y (list (- w) 0.0 dc (+ dc w))
        (bb:addpl blk (list (list 0.0 y) (list b y)) nil))))
  (car prm))

;;; Ponto (x y) do Profile View para estaca e cota (nil se falhar)
(defun bb:pv-xy-0 (pv sta el / x y r)
  (setq r (vl-catch-all-apply 'vlax-invoke-method
            (list pv 'FindXYAtStationAndElevation sta el 'x 'y)))
  (if (and (not (vl-catch-all-error-p r))
           (numberp (setq x (bb:var->lisp x)))
           (numberp (setq y (bb:var->lisp y))))
    (list x y)))

;;; Idem, aceitando estaca FORA do Profile View (o Civil 3D da erro): o
;;; dissipador e os textos da jusante passam do fim do alinhamento quando
;;; o bueiro termina perto dele. Extrapola pela escala horizontal do perfil.
(defun bb:pv-xy (pv sta el / p s0 s1 c c2 a b)
  (cond
    ((setq p (bb:pv-xy-0 pv sta el)) p)
    ((and (numberp (setq s0 (bb:try pv 'StationStart)))
          (numberp (setq s1 (bb:try pv 'StationEnd)))
          (> (- s1 s0) 1.0)
          (setq c  (max s0 (min s1 sta))
                c2 (if (> (+ c 1.0) s1) (- c 1.0) (+ c 1.0)))
          (setq a (bb:pv-xy-0 pv c el))
          (setq b (bb:pv-xy-0 pv c2 el)))
     (list (+ (car a) (* (- sta c) (/ (- (car b) (car a)) (- c2 c))))
           (cadr a)))))

;;; (estaca afastamento) de um ponto no alinhamento (nil se falhar).
;;; Para ponto fora do alcance do alinhamento o Civil 3D pode devolver
;;; estaca/afastamento 0 sem erro; por isso o resultado e conferido
;;; voltando ao ponto (PointLocation) e pelas estacas inicial/final.
(defun bb:al-sta (al pt / sta off r e n s0 s1)
  (setq r (vl-catch-all-apply 'vlax-invoke-method
            (list al 'StationOffset (car pt) (cadr pt) 'sta 'off)))
  (if (and (not (vl-catch-all-error-p r))
           (numberp (setq sta (bb:var->lisp sta)))
           (numberp (setq off (bb:var->lisp off))))
    (progn
      (setq r (vl-catch-all-apply 'vlax-invoke-method
                (list al 'PointLocation sta off 'e 'n))
            s0 (bb:try al 'StartingStation)
            s1 (bb:try al 'EndingStation))
      (cond
        ;; fora das estacas do alinhamento
        ((and (numberp s0) (numberp s1)
              (or (< sta (- s0 0.01)) (> sta (+ s1 0.01))))
         nil)
        ;; conferencia pelo ponto de volta
        ((and (not (vl-catch-all-error-p r))
              (numberp (setq e (bb:var->lisp e)))
              (numberp (setq n (bb:var->lisp n))))
         (if (< (bb:d2 (list e n) pt) 0.10) (list sta off)))
        ;; sem PointLocation: estacas do alinhamento conhecidas
        ((and (numberp s0) (numberp s1)) (list sta off))
        ;; sem nenhuma conferencia: recusa a resposta "vazia" 0 / 0
        ((not (and (equal sta 0.0 1e-9) (equal off 0.0 1e-9))) (list sta off))
      ))))

(defun bb:nome (obj en / s)
  (setq s (bb:try obj 'Name))
  (if (/= (type s) 'STR) (setq s (bb:gpv en "Name")))
  (if (= (type s) 'STR) s ""))

;;; Alinhamentos do desenho: ((nome-maiusculo . objeto) ...), lido 1 vez
(defun bb:alinhamentos (/ ss i en lst)
  (if (setq ss (ssget "_X" '((0 . "AECC_ALIGNMENT"))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq en  (ssname ss i)
              lst (cons (cons (strcase (bb:nome (vlax-ename->vla-object en) en))
                              (vlax-ename->vla-object en))
                        lst)
              i   (1+ i)))))
  lst)

;;; Alinhamento do Profile View, sem perguntar nada (nil se nao achar).
;;; 1) propriedade do perfil; 2) colecao ProfileViews de cada alinhamento
;;; (no Civil 3D 2021 a propriedade nao responde e o nome do perfil pode
;;; nao ter o do alinhamento, ex. "Perfil Longitudinal - BUEIRO 07");
;;; 3) pelo nome: o perfil "PERFIL BUEIRO BC 07" e do alinhamento
;;; "BUEIRO BC 07" (o nome mais longo contido no do perfil)
(defun bb:pv-al-auto (pv en / a e nm best h c)
  (foreach k '(Alignment ParentAlignment)
    (if (and (not a) (= (type (setq e (bb:try pv k))) 'VLA-OBJECT)) (setq a e)))
  (if (and (not a) (= (type (setq e (bb:gpv en "AlignmentId"))) 'ENAME))
    (setq a (vlax-ename->vla-object e)))
  (if (not *bb:als*) (setq *bb:als* (bb:alinhamentos)))
  (if (not a)
    (progn
      (setq h (vla-get-Handle pv))
      (foreach x *bb:als*
        (if (and (not a) (= (type (setq c (bb:try (cdr x) 'ProfileViews))) 'VLA-OBJECT))
          (vl-catch-all-apply
            '(lambda () (vlax-for v c (if (= (vla-get-Handle v) h) (setq a (cdr x))))))))))
  (if (not a)
    (progn
      (setq nm (strcase (bb:nome pv en)))
      (foreach x *bb:als*
        (if (and (/= (car x) "")
                 (vl-string-search (car x) nm)
                 (or (not best) (> (strlen (car x)) (strlen (car best)))))
          (setq best x)))
      (if best (setq a (cdr best)))))
  a)

(defun bb:pv-alinhamento (pv en / a e)
  (setq a (bb:pv-al-auto pv en))
  (if (not a)
    (progn
      (princ "\nAlinhamento deste perfil nao identificado automaticamente.")
      (if (setq e (entsel "\nSelecione o ALINHAMENTO do perfil: "))
        (setq a (vlax-ename->vla-object (car e))))))
  a)

;;; Insere a boca em corte. sta/zinv = ponta do cano; sg = +1/-1 = sentido
;;; das estacas que aponta para fora do bueiro.
;;; Estaca da origem da boca (face interna da testa) a partir da ponta do cano
(defun bb:perfil-s0 (prm sta sg)
  (cond ((= (strcase *BB:PERFIL-REF*) "PONTA")   (- sta (* sg (nth 7 prm))))
        ((= (strcase *BB:PERFIL-REF*) "INTERNA") sta)
        (T                                        (- sta (* sg (nth 1 prm))))))

;;; Insere o bloco BLK (desenhado em m, +X = para fora) no perfil na estaca
;;; s0 e cota z, com a escala horizontal/vertical do perfil.
(defun bb:perfil-ins (pv blk s0 z sg lay / p0 p1 p2 ref sx sy)
  (setq p0 (bb:pv-xy pv s0 z)
        p1 (bb:pv-xy pv (+ s0 1.0) z)
        p2 (bb:pv-xy pv s0 (+ z 1.0)))
  (if (and p0 p1 p2)
    (progn
      (setq sx (* sg (- (car p1) (car p0)))     ; escala horizontal (com espelho)
            sy (- (cadr p2) (cadr p0)))         ; escala vertical (exagero)
      (if (and (> (abs sx) 1e-9) (> (abs sy) 1e-9))
        (progn
          (setq ref (bb:inserir blk (list (car p0) (cadr p0) 0.0) 0.0 lay))
          (vla-put-XScaleFactor ref sx)
          (vla-put-YScaleFactor ref sy)
          (vla-Update ref)
          ref)))))

(defun bb:perfil-boca (pv prm sta zinv sg)
  (bb:perfil-ins pv (car prm) (bb:perfil-s0 prm sta sg) zinv sg *BB:LAYER-BOCA*))

;;; Dissipador DEB em corte, encaixado na ponta externa da boca de jusante,
;;; com o nome (ex.: "DEB 300-366") escrito acima dele.
(defun bb:perfil-dissip (pv prm deb sta zinv sg / s0 ref pt alt pe dx)
  (setq s0  (+ (bb:perfil-s0 prm sta sg) (* sg (nth 7 prm)))
        ref (bb:perfil-ins pv (bb:deb-corte deb) s0 zinv sg *BB:LAYER-DISSIP*))
  ;; nome abaixo do dissipador (fundo da laje = -0.20)
  (cond
    ((not ref) (princ "\n  (dissipador nao inserido no perfil)"))
    ((not (setq pt (bb:pv-xy pv (+ s0 (* sg (/ (nth 1 deb) 2.0))) (- zinv 0.20))))
     (princ "\n  (texto do dissipador: posicao no perfil nao encontrada)"))
    (T
     (setq alt *BB:TXT-ALT*
           ;; sentido "para fora" (fluxo) no desenho: do meio ao fim do DEB
           pe  (bb:pv-xy pv (+ s0 (* sg (nth 1 deb))) (- zinv 0.20))
           dx  (if (and pe (< (car pe) (car pt))) -1.0 1.0))
     (bb:texto (nth 3 deb)
               (list (+ (car pt) (* dx *BB:TXT-DESL-DEB*)) (- (cadr pt) (* 0.5 alt)) 0.0)
               alt 1 3 0.0)))
  ref)

;;; Profile View que contem o ponto (o menor, se houver mais de um)
(defun bb:pv-no-ponto (pt / ss i o a b mn mx best ba ar e)
  (if (setq ss (ssget "_X" '((0 . "AECC_PROFILE_VIEW"))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq o (vlax-ename->vla-object (ssname ss i)) i (1+ i))
        (if (and (bb:visivel o)
                 (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-GetBoundingBox (list o 'a 'b)))))
          (progn
            (setq mn (vlax-safearray->list a) mx (vlax-safearray->list b))
            (if (and (<= (car mn) (car pt) (car mx)) (<= (cadr mn) (cadr pt) (cadr mx)))
              (progn
                (setq ar (* (- (car mx) (car mn)) (- (cadr mx) (cadr mn))))
                (if (or (not ba) (< ar ba)) (setq best o ba ar)))))))))
  (if (and (not best)
           (setq e (entsel "\nProfile View nao identificado. Selecione o PROFILE VIEW: "))
           (= (cdr (assoc 0 (entget (car e)))) "AECC_PROFILE_VIEW"))
    (setq best (vlax-ename->vla-object (car e))))
  best)

;;; A pipe mostrada no perfil e outro objeto (parte do Profile View);
;;; tenta achar a pipe "de verdade" que ela representa.
(defun bb:pipe-de-parte (en / r e o)
  (foreach nm '("ModelPartId" "PartId" "NetworkPartId" "ModelPart")
    (if (and (not r)
             (= (type (setq e (bb:gpv en nm))) 'ENAME)
             (= (cdr (assoc 0 (entget e))) "AECC_PIPE"))
      (setq r e)))
  (setq o (vlax-ename->vla-object en))
  (foreach nm '(ModelPart Part NetworkPart PipeNetworkPart)
    (if (and (not r)
             (= (type (setq e (bb:try o nm))) 'VLA-OBJECT)
             (= (cdr (assoc 0 (entget (setq e (vlax-vla-object->ename e))))) "AECC_PIPE"))
      (setq r e)))
  r)

;;; Parede do cano c (m): 1) diametro externo da pipe; 2) WDES = valor
;;; tirado do desenho; 3) espessura usual. HH = diametro/altura interna.
(defun bb:parede-cano (c wdes hh / o en dout w)
  (setq o    (car c)
        en   (vlax-vla-object->ename o)
        dout (bb:num (list (bb:prop o 'OuterDiameterOrWidth) (bb:gpv en "OuterDiameterOrWidth"))))
  (if (and dout (> dout 20.0)) (setq dout (/ dout 1000.0)))
  (cond
    ((and dout (setq w (/ (- dout (nth 3 c)) 2.0)) (> w 0.0) (< w (* 0.5 hh))) w)
    ((and (> wdes 0.0) (< wdes (* 0.5 hh))) wdes)
    (T (bb:parede-padrao hh))))

;;; (estaca cota) de um ponto x,y do Profile View (nil se falhar)
(defun bb:pv-se (pv x y / sta el r)
  (setq r (vl-catch-all-apply 'vlax-invoke-method
            (list pv 'FindStationAndElevationAtXY x y 'sta 'el)))
  (if (and (not (vl-catch-all-error-p r))
           (numberp (setq sta (bb:var->lisp sta)))
           (numberp (setq el (bb:var->lisp el))))
    (list sta el)))

;;; Pipe desenhada no perfil (AECC_GRAPH_PROFILE_NETWORK_PART): pela caixa
;;; envolvente -> (estaca-ini estaca-fim cota-min cota-max), as cotas sendo
;;; as do desenho (fundo externo mais baixo / topo externo mais alto).
(defun bb:ge-caixa (pv ge / o a b mn mx q1 q2 q3)
  (setq o (vlax-ename->vla-object ge))
  (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-GetBoundingBox (list o 'a 'b))))
    (progn
      (setq mn (vlax-safearray->list a) mx (vlax-safearray->list b)
            q1 (bb:pv-se pv (car mn) (cadr mn))
            q2 (bb:pv-se pv (car mx) (cadr mn))
            q3 (bb:pv-se pv (car mn) (cadr mx)))
      (if (and q1 q2 q3)
        (list (min (car q1) (car q2)) (max (car q1) (car q2)) (cadr q1) (cadr q3))))))

;;; Bueiro desenhado na caixa CX (bb:ge-caixa): as pontas (em planta) caem
;;; nas estacas do desenho e, havendo mais de um ali (copias / outra rede),
;;; fica o de cota e diametro mais parecidos com o desenho.
(defun bb:grupo-por-caixa (al grupos cx / s0 s1 hd cands A B sA sB er zl zd D best be sc)
  (setq s0 (nth 0 cx) s1 (nth 1 cx)
        hd (- (nth 3 cx) (nth 2 cx)))                 ; altura desenhada (cano externo + desnivel)
  (foreach g grupos
    (setq A  (bb:media (mapcar 'cadr g))
          B  (bb:media (mapcar 'caddr g))
          sA (bb:al-sta al A)
          sB (bb:al-sta al B))
    (if (and sA sB)
      (progn
        (setq er (+ (abs (- (min (car sA) (car sB)) s0)) (abs (- (max (car sA) (car sB)) s1))))
        (if (< er (max 2.0 (* 0.2 (- s1 s0))))
          (progn
            (setq zl (min (caddr A) (caddr B))        ; eixo na ponta mais baixa
                  zd (abs (- (caddr A) (caddr B)))
                  D  (apply 'max (mapcar 'cadddr g))
                  ;; eixo desenhado na ponta baixa = fundo + metade do externo
                  sc (+ er
                        (* 2.0 (abs (- zl (+ (nth 2 cx) (/ (- hd zd) 2.0)))))
                        (* 2.0 (abs (- (+ D (* 2.0 (bb:parede-padrao D))) (- hd zd)))))
                  cands (cons g cands))
            (if (or (not be) (< sc be)) (setq best g be sc)))))))
  (if (> (length cands) 1)
    (princ (strcat "\n  ATENCAO: " (itoa (length cands))
                   " bueiros na mesma posicao (pipes duplicadas / outra rede?)."
                   " Usado o que bate com o desenho do perfil.")))
  best)

(defun bb:dist-seg (p a b / v w t2 l2)
  (setq v (bb:v- b a) w (bb:v- p a) l2 (bb:dot2 v v))
  (setq t2 (if (> l2 1e-12) (max 0.0 (min 1.0 (/ (bb:dot2 w v) l2))) 0.0))
  (bb:d2 p (bb:v+ a (bb:vs v t2))))

;;; Grupo (bueiro) cuja linha no perfil passa mais perto do ponto clicado
(defun bb:grupo-perto (pv al pt grupos / best bd A B sA sB pA pB pH dd tol)
  (foreach g grupos
    (setq A  (bb:media (mapcar 'cadr g))
          B  (bb:media (mapcar 'caddr g))
          sA (bb:al-sta al A)
          sB (bb:al-sta al B))
    (if (and sA sB
             (setq pA (bb:pv-xy pv (car sA) (caddr A)))
             (setq pB (bb:pv-xy pv (car sB) (caddr B)))
             (setq pH (bb:pv-xy pv (car sA) (+ (caddr A) (apply 'max (mapcar 'cadddr g))))))
      (progn
        (setq dd  (bb:dist-seg pt pA pB)
              tol (max 2.0 (* 1.5 (abs (- (cadr pH) (cadr pA))))))   ; ~altura do cano no perfil
        (if (and (< dd tol) (or (not bd) (< dd bd))) (setq best g bd dd)))))
  best)

;;; Cota do EIXO do cano c na ponta p. Base = cota lida em bb:ler-cano.
;;; StartPoint/EndPoint da API .NET so e usado se for coerente com ela
;;; (em alguns Civil 3D vem valor sem sentido).
(defun bb:z-eixo (c p / en a b q)
  (setq en (vlax-vla-object->ename (car c))
        a  (bb:pt (bb:gpv en "StartPoint"))
        b  (bb:pt (bb:gpv en "EndPoint")))
  (if (and a b)
    (setq q (if (< (bb:d2 a p) (bb:d2 b p)) a b)))
  (if (and q
           (< (bb:d2 q p) 0.05)
           (< (abs (- (caddr q) (caddr p))) (* 0.5 (nth 3 c))))
    (caddr q)
    (caddr p)))

;;; Cota da geratriz inferior (fundo interno) do bueiro na ponta k
;;; (1 = montante, 2 = jusante): media dos canos.
(defun bb:z-geratriz (canos k / zs)
  (foreach c canos
    (setq zs (cons (- (bb:z-eixo c (nth k c))
                      (/ (if (and (= (nth 4 c) "CC") (numberp (nth 5 c))) (nth 5 c) (nth 3 c)) 2.0))
                   zs)))
  (+ (/ (apply '+ zs) (float (length zs))) *BB:PERFIL-DZ*))

;;; Insere as bocas de um bueiro (grupo de canos) no perfil. T se inseriu.
(defun bb:perfil-grupo (pv al g / n res canos dz PM PJ D HC shp code mS jS)
  (setq n (length g) res (bb:orientar g) canos (car res) dz (cadr res))
  (cond
    ((> dz *BB:TOL-Z*))
    ((< dz (- *BB:TOL-Z*)) (setq canos (mapcar 'bb:inverter canos)))
    (T (setq canos nil)))
  (cond
    ((> n 3) (princ "\n  Mais de 3 canos paralelos (maximo = triplo).") nil)
    ((not canos) (princ "\n  Cotas iguais nas pontas: nao da para saber montante/jusante.") nil)
    (T
     (setq PM   (bb:media (mapcar 'cadr canos))
           PJ   (bb:media (mapcar 'caddr canos))
           D    (apply 'max (mapcar 'cadddr canos))
           shp  (if (member "CC" (mapcar '(lambda (c) (nth 4 c)) canos)) "CC" "TC")
           HC   (if (= shp "CC")
                  (apply 'max (cons 0.0 (vl-remove-if-not 'numberp
                                          (mapcar '(lambda (c) (nth 5 c)) canos)))))
           code (strcat "B" (nth (1- n) '("S" "D" "T")) shp)
           mS   (bb:al-sta al PM)
           jS   (bb:al-sta al PJ))
     (if (and HC (<= HC 0.0)) (setq HC nil))
     (setq *bb:canos-cota* canos         ; p/ gravar a altura de aterro nas pipes
           *bb:tag-key*    (bb:chave canos))
     (bb:cogo-bueiro canos)              ; COGO point no eixo
     (if (not (and mS jS))
       (progn (princ "\n  Nao achei a estaca das pontas do cano no alinhamento deste perfil.") nil)
       (bb:perfil-inserir pv al PM PJ code shp D HC (car mS) (car jS)
                          (bb:z-geratriz canos 1) (bb:z-geratriz canos 2)
                          (bb:parede-cano (car canos) 0.0 (if (and (= shp "CC") HC) HC D)))))))

;;; Insere boca de montante, boca de jusante e dissipador no perfil, dadas
;;; as estacas e as cotas da geratriz inferior nas duas pontas.
;;; Texto abaixo da boca no perfil (centro da boca, abaixo do dente)
(defun bb:perfil-rotulo-boca (pv prm sta zinv sg txt / s0 pt)
  (setq s0 (bb:perfil-s0 prm sta sg))
  (if (setq pt (bb:pv-xy pv (+ s0 (* sg (/ (nth 7 prm) 2.0)))
                            (- zinv (nth 4 prm) (nth 5 prm))))
    (bb:texto txt (list (car pt) (- (cadr pt) (* 0.5 *BB:TXT-ALT*) *BB:TXT-DESL-BOCA*) 0.0)
              *BB:TXT-ALT* 1 3 0.0)))

;;; Ponto (planta) onde o eixo da rodovia cruza o bueiro PA-PB: algum
;;; alinhamento (outro que nao AL) com as pontas do bueiro em lados opostos;
;;; preferencia para nomes com "EIXO" (ou *BB:EIXO-NOME*).
;;; Devolve (ponto-do-cruzamento alinhamento-do-eixo) ou nil.
;;; AL = alinhamento do bueiro (excluido); pode ser nil (planta): ai so
;;; valem alinhamentos com as pontas a mais de 0,5 m de cada lado.
(defun bb:eixo-cruza (al pa pb / ena best bp nm sA sB tt pri)
  (if (not *bb:als*) (setq *bb:als* (bb:alinhamentos)))
  (setq ena (if al (vlax-vla-object->ename al)))
  (foreach x *bb:als*
    (setq nm (car x))
    (if (and (not (equal (vlax-vla-object->ename (cdr x)) ena))
             (or (= *BB:EIXO-NOME* "") (wcmatch nm (strcase *BB:EIXO-NOME*)))
             (setq sA (bb:al-sta (cdr x) pa))
             (setq sB (bb:al-sta (cdr x) pb))
             (< (* (cadr sA) (cadr sB)) 0.0)
             (> (abs (cadr sA)) 0.5)
             (> (abs (cadr sB)) 0.5))
      (progn
        (setq pri (if (wcmatch nm "*EIXO*") 0 1)
              tt  (/ (cadr sA) (- (cadr sA) (cadr sB))))
        (if (or (not bp) (< pri bp))
          (setq bp pri
                best (list (list (+ (car pa) (* tt (- (car pb) (car pa))))
                                 (+ (cadr pa) (* tt (- (cadr pb) (cadr pa))))
                                 0.0)
                           (cdr x)))))))
  best)

;;; Superficie projetada (greide) no perfil: cota na estaca STA de um dos
;;; perfis do alinhamento ALG. Escolha:
;;;  1) *BB:GREIDE-NOME* (padrao wcmatch) no nome ou no estilo do perfil;
;;;  2) unico perfil com nome/estilo de projeto (PROJ, CORRED, PAV...) e
;;;     que nao seja de terreno (TN, TERRENO, NATURAL, EXIST...);
;;;  3) pergunta qual e a superficie projetada e lembra (pelo estilo, que
;;;     costuma ser o mesmo em todos os bueiros).
;;; -> (cota nome) ou nil
(setq *BB:GREIDE-NOME* "")                ; ex.: "*PROJETADA*" ("" = automatico)
(setq *bb:greide-padrao* nil)             ; escolha feita na pergunta (sessao)

;;; ((nome estilo cota) ...) dos perfis com cota valida na estaca
(defun bb:perfis-em (alg sta / profs nm st el lst)
  (if (= (type (setq profs (bb:try alg 'Profiles))) 'VLA-OBJECT)
    (vlax-for p profs
      (setq nm (strcase (vl-princ-to-string (bb:try p 'Name)))
            st (bb:try p 'Style)
            st (strcase (if (= (type st) 'VLA-OBJECT) (vl-princ-to-string (bb:try st 'Name)) ""))
            el (vl-catch-all-apply 'vlax-invoke-method (list p 'ElevationAt sta)))
      (if (vl-catch-all-error-p el)
        (setq el (vl-catch-all-apply 'vlax-get-property (list p 'ElevationAt sta))))
      (if (and (not (vl-catch-all-error-p el)) (numberp (setq el (bb:var->lisp el))))
        (setq lst (cons (list nm st el) lst)))))
  (reverse lst))

(defun bb:casa (x pat) (or (wcmatch (car x) pat) (wcmatch (cadr x) pat)))

;;; Escapa os caracteres especiais do wcmatch (nome usado como padrao)
(defun bb:wc-esc (s / r c)
  (setq r "")
  (foreach c (vl-string->list s)
    (setq r (strcat r (if (member c (vl-string->list "#@.*?~[]-,`")) "`" "") (chr c))))
  r)

(setq *bb:greide-forcar* nil)             ; T = pergunta mesmo havendo escolha lembrada
(setq *bb:greide-topo*   nil)             ; topo externo do cano no eixo (p/ a pergunta)
(setq *bb:pat-tn* "*TN*,*TERRENO*,*NATURAL*,*EXIST*,*EG*,*PRIMITIV*")

;;; So as letras do nome ("PERFIL BSTC-01 - PROJ (3)" -> "PERFILBSTCPROJ"):
;;; o numero do bueiro muda de um para outro, o resto do nome nao.
(defun bb:so-letras (s)
  (vl-list->string (vl-remove-if-not '(lambda (c) (and (>= c 65) (<= c 90)))
                                     (vl-string->list (strcase s)))))

(setq *bb:greide-nome-ant* nil)           ; nome do perfil escolhido na pergunta

(defun bb:greide (alg sta / lst pat proj i op x mt sm)
  (setq lst (bb:perfis-em alg sta)
        *bb:greide-diag* (apply 'strcat (mapcar '(lambda (x) (strcat " \"" (car x) "\"=" (rtos (caddr x) 2 3))) lst))
        pat (cond ((/= *BB:GREIDE-NOME* "") (strcase *BB:GREIDE-NOME*))
                  (*bb:greide-padrao*)))
  ;; candidatos pelo padrao lembrado (estilo ou nome), sem os de terreno
  (if (and pat (not *bb:greide-forcar*))
    (progn
      (setq mt (vl-remove-if-not '(lambda (x) (bb:casa x pat)) lst))
      (if (> (length mt) 1)
        (setq mt (vl-remove-if '(lambda (x) (bb:casa x *bb:pat-tn*)) mt)))))
  ;; ainda empatado: o que tem o nome "igual" ao escolhido antes (so letras)
  (if (and (/= (length mt) 1) *bb:greide-nome-ant* (not *bb:greide-forcar*))
    (setq sm (vl-remove-if-not
               '(lambda (x) (= (bb:so-letras (car x)) (bb:so-letras *bb:greide-nome-ant*)))
               (if mt mt lst))))
  (cond
    ((null lst) nil)
    ;; 1) padrao definido (configuracao ou resposta anterior) apontando UM perfil
    ((= (length mt) 1)
     (list (caddr (car mt)) (car (car mt))))
    ;; 1b) mesmo nome (tirando numeros) do perfil escolhido antes
    ((= (length sm) 1)
     (list (caddr (car sm)) (car (car sm))))
    ;; 2) unico perfil "de projeto"
    ((and (not *bb:greide-forcar*)
          (setq proj (vl-remove-if-not
                       '(lambda (x) (and (bb:casa x "*PROJ*,*CORRED*,*CORRID*,*PAV*,*GREIDE*,*FG*,*PG*,*TOP*")
                                         (not (bb:casa x *bb:pat-tn*))))
                       lst))
          (= (length proj) 1))
     (list (caddr (car proj)) (car (car proj))))
    ;; 3) pergunta (abre a janela de texto para a lista ficar visivel)
    (T (bb:greide-pergunta lst))))

;;; Pergunta qual perfil e o GREIDE, com a lista bem explicada:
;;; aterro que cada perfil daria (se o topo do cano for conhecido),
;;; marca do terreno natural e uma SUGESTAO (ENTER aceita a sugestao).
(defun bb:greide-pergunta (lst / topo i sug x tn ab pj op n)
  (setq topo *bb:greide-topo* n (length lst) i 0)
  ;; sugestao: 1o perfil de projeto, nao-terreno e acima do cano;
  ;; senao, 1o nao-terreno acima do cano
  (foreach x lst
    (setq i (1+ i))
    (if (and (not sug)
             (bb:casa x "*PROJ*,*CORRED*,*CORRID*,*PAV*,*GREIDE*,*FG*,*PG*,*TOP*")
             (not (bb:casa x *bb:pat-tn*))
             (or (not topo) (>= (caddr x) topo)))
      (setq sug i)))
  (setq i 0)
  (if (not sug)
    (foreach x lst
      (setq i (1+ i))
      (if (and (not sug) (not (bb:casa x *bb:pat-tn*)) (or (not topo) (>= (caddr x) topo)))
        (setq sug i))))
  ;; lista
  (textscr)
  (princ (strcat
    "\n"
    "\n  ================= ESCOLHA DO GREIDE ================="
    "\n  Para a cota de recobrimento e a ALTURA DE ATERRO no eixo,"
    "\n  diga qual destes perfis e o GREIDE (perfil de projeto da"
    "\n  rodovia, a linha de cima). NAO escolha o terreno natural."
    (if topo (strcat "\n  Topo externo do cano no eixo: " (rtos topo 2 3)) "")
    "\n"))
  (setq i 0)
  (foreach x lst
    (setq i  (1+ i)
          tn (bb:casa x *bb:pat-tn*)
          ab (and topo (< (caddr x) topo)))
    (princ (strcat "\n    " (itoa i) " = \"" (car x) "\""
                   (if (/= (cadr x) "") (strcat "  estilo \"" (cadr x) "\"") "")
                   "  cota " (rtos (caddr x) 2 3)
                   (if topo (strcat "  -> aterro " (rtos (- (caddr x) topo) 2 2) " m") "")
                   (cond ((= i sug) "   <== SUGERIDO")
                         (ab        "   (abaixo do cano: NAO e o greide)")
                         (tn        "   (terreno natural)")
                         (T "")))))
  (princ "\n    0 = nenhum (sem cota de recobrimento neste bueiro)")
  (princ "\n  =====================================================")
  (initget 4)                                   ; nao aceita negativo
  (setq op (getint (strcat "\n  Digite o NUMERO do greide [0 a " (itoa n) "]"
                           (if sug (strcat " <ENTER = " (itoa sug) ">") " <ENTER = 0>")
                           ": ")))
  (graphscr)
  (if (null op) (setq op (if sug sug 0)))
  (cond
    ((or (< op 1) (> op n))
     (princ "\n  Nenhum greide escolhido: este bueiro fica sem recobrimento/aterro.")
     nil)
    (T
     ;; lembra pelo ESTILO (costuma ser o mesmo em todos os bueiros) e pelo
     ;; nome sem numeros; se empatar com o terreno, pergunta de novo
     (setq x (nth (1- op) lst)
           *bb:greide-padrao*   (bb:wc-esc (if (/= (cadr x) "") (cadr x) (car x)))
           *bb:greide-nome-ant* (car x))
     (princ (strcat "\n  OK: greide = \"" (car x) "\". Os proximos bueiros usam o mesmo"
                    " perfil automaticamente (para escolher de novo: BBGREIDE)."))
     (list (caddr x) (car x)))))

;;; Nome real do estilo de cota que casa com o padrao PAT (nil se nao houver)
(defun bb:dimstyle-acha (pat / r nm)
  (if (and pat (/= pat ""))
    (if (tblsearch "DIMSTYLE" pat)
      (cdr (assoc 2 (tblsearch "DIMSTYLE" pat)))
      (progn
        (setq r (tblnext "DIMSTYLE" T))
        (while (and r (not nm))
          (if (wcmatch (strcase (cdr (assoc 2 r))) (strcase pat)) (setq nm (cdr (assoc 2 r))))
          (setq r (tblnext "DIMSTYLE")))
        nm))))

;;; Cota horizontal (dimensao) entre P1 e P2 com a linha na altura YL;
;;; HS = unidades do desenho por metro na horizontal do perfil
(defun bb:cota (p1 p2 yl hs)
  (bb:cota-rot p1 p2 (list (/ (+ (car p1) (car p2)) 2.0) yl) 0.0 hs *BB:COTA-ESTILO-PF*))

;;; Cota (dimensao rotacionada ROT) entre P1 e P2, linha passando por LOC;
;;; HS = unidades do desenho por metro na direcao medida (exagero);
;;; EST = padrao do estilo de cota
(defun bb:cota-rot (p1 p2 loc rot hs est / d)
  (setq d (vl-catch-all-apply 'vla-AddDimRotated
            (list (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object)))
                  (vlax-3d-point (list (car p1) (cadr p1) 0.0))
                  (vlax-3d-point (list (car p2) (cadr p2) 0.0))
                  (vlax-3d-point (list (car loc) (cadr loc) 0.0))
                  rot)))
  (if (not (vl-catch-all-error-p d)) (bb:cota-ajusta d hs est)))

;;; Cota alinhada (planta) entre P1 e P2, linha passando por LOC
(defun bb:cota-alin (p1 p2 loc est / d)
  (setq d (vl-catch-all-apply 'vla-AddDimAligned
            (list (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object)))
                  (vlax-3d-point (list (car p1) (cadr p1) 0.0))
                  (vlax-3d-point (list (car p2) (cadr p2) 0.0))
                  (vlax-3d-point (list (car loc) (cadr loc) 0.0)))))
  (if (not (vl-catch-all-error-p d)) (bb:cota-ajusta d 1.0 est)))

;;; Estilo, escala (metros reais), cor e layer de uma cota
(defun bb:cota-ajusta (d hs est / nm)
  ;; estilo da cota; sem ele, so o texto em Arial
  (if (setq nm (bb:dimstyle-acha est))
    (vl-catch-all-apply 'vla-put-StyleName (list d nm))
    (vl-catch-all-apply 'vla-put-TextStyle (list d (bb:estilo-txt))))
  ;; valor em metros reais (desfaz a escala/exagero do perfil e o fator do estilo)
  (if hs (vla-put-LinearScaleFactor d (/ 1.0 hs)))
  (if *BB:COR-TXT* (vla-put-Color d *BB:COR-TXT*))
  (vla-put-Layer d (bb:layer-txt))
  (bb:tag d))

;;; Cota do diametro (DIM) no perfil: vertical na ponta de montante, do
;;; fundo ao topo interno do cano, com a linha 1,0 para dentro do bueiro.
;;; SG = sentido das estacas que aponta para fora na montante.
(defun bb:perfil-cota-diam (pv sM zM hh sg / p1 p2 pin dx)
  (setq p1  (bb:pv-xy pv sM zM)
        p2  (bb:pv-xy pv sM (+ zM hh))
        pin (bb:pv-xy pv (- sM sg) zM))                 ; 1 m para dentro
  (if (and p1 p2 pin (> hh 0.0))
    (progn
      (setq dx (if (< (car pin) (car p1)) -1.0 1.0))
      (bb:cota-rot p1 p2 (list (+ (car p1) (* dx *BB:COTA-DESL*)) (cadr p1))
                   (* 0.5 pi) (/ (abs (- (cadr p2) (cadr p1))) hh) *BB:COTA-ESTILO-REC*))))

;;; Cota do diametro (DIM) em planta: atravessando o 1o cano logo depois
;;; da testa de montante. P = ponta do cano, DIR = fluxo, LARG = diametro.
(defun bb:planta-cota-diam (P dir larg / perp)
  (setq P    (list (car P) (cadr P) 0.0)
        perp (list (- (cadr dir)) (car dir) 0.0))
  (bb:cota-alin (bb:v+ P (bb:vs perp (/ larg 2.0)))
                (bb:v- P (bb:vs perp (/ larg 2.0)))
                (bb:v+ P (bb:vs dir *BB:COTA-DESL*))
                *BB:COTA-ESTILO-DPL*))

;;; ------------- MONTANTE + JUSANTE = L DA OBRA (inteiros) ---------------
;;; L da obra = comprimento 2D medio das pipes do bueiro
(defun bb:L-canos (canos)
  (if canos
    (/ (apply '+ (mapcar '(lambda (k) (cond ((bb:num (list (bb:prop (car k) 'Length2D)
                                                           (bb:gpv (vlax-vla-object->ename (car k)) "Length2D"))))
                                             ((bb:d2 (nth 1 k) (nth 2 k)))))
                         canos))
       (float (length canos)))))

;;; Distancias eixo->montante (M) e eixo->jusante (J) em metros INTEIROS
;;; que somem exatamente o L da obra arredondado. A unidade que sobra/falta
;;; vai para a distancia com a maior parte decimal (maior resto).
;;; Devolve (m j ajustou?) - ajustou? = T se ficou diferente do arredondamento simples.
(defun bb:repartir (m j L / lr mf jf k mi ji)
  (setq lr (fix (+ L 0.5)) mf (fix m) jf (fix j) k (- lr mf jf))
  (cond ((= k 0) (setq mi mf ji jf))
        ((= k 1) (if (>= (- m mf) (- j jf)) (setq mi (1+ mf) ji jf) (setq mi mf ji (1+ jf))))
        ((= k 2) (setq mi (1+ mf) ji (1+ jf)))
        (T (setq mi (fix (+ m 0.5)) ji (- lr mi))))
  (list mi ji (or (/= mi (fix (+ m 0.5))) (/= ji (fix (+ j 0.5))))))

;;; Aplica nas 2 cotas (DM e DJ) o texto inteiro ajustado, se precisar
;;; T = as cotas eixo->montante e eixo->jusante (planta e perfil) e a
;;; planilha sempre somam o L da obra (inteiros); nil = arredondamento simples
(setq *BB:COTA-SOMA-L* T)

(defun bb:cotas-soma-L (dm dj m j / r L)
  (if (and *BB:COTA-SOMA-L* dm dj (numberp (setq L (bb:L-canos *bb:canos-cota*))))
    (progn
      (setq r (bb:repartir m j L))
      (if (caddr r)
        (progn
          (vl-catch-all-apply 'vla-put-TextOverride (list dm (itoa (car r))))
          (vl-catch-all-apply 'vla-put-TextOverride (list dj (itoa (cadr r))))
          (princ (strcat "\n  cotas do eixo ajustadas para somar L=" (itoa (fix (+ L 0.5)))
                         ": " (itoa (car r)) " + " (itoa (cadr r)))))))))

;;; Cotas em planta: eixo da rodovia -> ponta de montante e -> ponta de
;;; jusante, ao longo do bueiro, com a linha afastada para o lado.
(defun bb:planta-cotas (PM PJ dir larg / xr x perp off dm dj)
  (if (setq xr (bb:eixo-cruza nil PM PJ))
    (progn
      (setq x    (car xr)
            perp (list (- (cadr dir)) (car dir) 0.0)
            off  (bb:vs perp (+ (/ larg 2.0) *BB:COTA-DESL-PL*)))
      (setq dm (bb:cota-alin x PM (bb:v+ (bb:media (list x PM)) off) *BB:COTA-ESTILO*)
            dj (bb:cota-alin x PJ (bb:v+ (bb:media (list x PJ)) off) *BB:COTA-ESTILO*))
      (bb:cotas-soma-L dm dj (bb:d2 x PM) (bb:d2 x PJ))
      (princ (strcat "\n  planta: cotas a partir do eixo " (rtos (bb:d2 x PM) 2 2)
                     " + " (rtos (bb:d2 x PJ) 2 2) " m")))
    (princ "\n  planta: (cotas: eixo da rodovia nao encontrado cruzando o bueiro)")))

;;; Documento do Civil 3D (COM). Testa os ProgIDs das versoes e lembra.
;;; O objeto do Civil 3D e criado UMA vez por sessao e reaproveitado
;;; (criar de novo a cada ponto acumula objetos COM e pode travar).
(setq *bb:civ-app* nil)
(defun bb:civ-doc (/ acad app d)
  (setq acad (vlax-get-acad-object)
        app  *bb:civ-app*)
  (if (not app)
    (foreach v (if *bb:civ-progid* (list *bb:civ-progid*)
                 '("13.9" "13.8" "13.7" "13.6" "13.5" "13.4" "13.3" "13.2" "13.1" "13.0"
                   "12.0" "11.0" "10.5" "10.4" "10.3"))
      (if (not app)
        (progn
          (setq app (vl-catch-all-apply 'vla-GetInterfaceObject
                      (list acad (strcat "AeccXUiLand.AeccApplication." v))))
          (if (vl-catch-all-error-p app)
            (setq app nil)
            (setq *bb:civ-progid* v *bb:civ-app* app))))))
  (if app (setq d (vl-catch-all-apply 'vlax-get-property (list app 'ActiveDocument))))
  (if (and d (vl-catch-all-error-p d))
    (setq *bb:civ-app* nil d nil))                ; objeto velho: recria na proxima
  d)

;;; Cria um COGO point em P (x y z) com a descricao DESC. Devolve o ponto ou nil.
;;; Layer dos COGO points: criada ANTES do ponto (pela COM, fora da
;;; criacao do ponto). Devolve o nome, ou nil se nao der (ai o ponto fica
;;; na layer corrente, como antes).
(defun bb:layer-cogo (/ r)
  (if (and *BB:LAYER-COGO* (/= *BB:LAYER-COGO* ""))
    (progn
      (if (not (tblsearch "LAYER" *BB:LAYER-COGO*))
        (vl-catch-all-apply 'vla-Add
          (list (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object))) *BB:LAYER-COGO*)))
      (if (tblsearch "LAYER" *BB:LAYER-COGO*) *BB:LAYER-COGO*))))

(defun bb:cogo-add (p desc / cd pts r lay)
  (setq lay (bb:layer-cogo))
  (if (and (setq cd (bb:civ-doc))
           (= (type (setq pts (bb:try cd 'Points))) 'VLA-OBJECT))
    (progn
      (setq r (vl-catch-all-apply 'vlax-invoke-method (list pts 'Add (vlax-3d-point p))))
      (if (not (vl-catch-all-error-p r))
        (progn
          (vl-catch-all-apply 'vlax-put-property (list r 'Elevation (caddr p)))
          (if desc (vl-catch-all-apply 'vlax-put-property (list r 'RawDescription desc)))
          r)))))

;;; Passa o COGO point PT para a layer *BB:LAYER-COGO*. Chamar DEPOIS da
;;; etiqueta (bb:tag): trocando a layer antes, a etiqueta nao gravava e o
;;; ponto deixava de ser substituido na execucao seguinte.
(defun bb:cogo-layer (pt / lay)
  (if (and pt (setq lay (bb:layer-cogo))
           (vl-catch-all-error-p (vl-catch-all-apply 'vlax-put-property (list pt 'Layer lay))))
    (princ (strcat "\n  (COGO point criado, mas nao foi possivel mudar para a layer " lay ")"))))

;;; Reserva: apaga COGO points SEM etiqueta com a descricao DESC a menos de
;;; *BB:COGO-TOL* do ponto P (x y) - os que ficaram sem etiqueta (feitos
;;; pela 5_18 antiga) e por isso nao eram substituidos. Devolve quantos.
(setq *BB:COGO-TOL* 0.50)
(defun bb:cogo-limpar-perto (p desc / ss i e o x y n)
  (setq n 0)
  (if (and desc (setq ss (ssget "_X" '((0 . "AECC_COGO_POINT")))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq e (ssname ss i) i (1+ i))
        (if (and (entget e)
                 (not (assoc -3 (entget e '("BOCAS_BUEIRO"))))
                 (setq o (vlax-ename->vla-object e))
                 (numberp (setq x (bb:try o 'Easting)))
                 (numberp (setq y (bb:try o 'Northing)))
                 (= (bb:try o 'RawDescription) desc)
                 (< (distance (list x y) (list (car p) (cadr p))) *BB:COGO-TOL*)
                 (not (vl-catch-all-error-p (vl-catch-all-apply 'entdel (list e)))))
          (setq n (1+ n))))))
  n)

;;; Idem para o BBLIMPA: COGO points SEM etiqueta com a descricao DESC a
;;; menos de 2 m (em planta) de algum cano do conjunto SSC. Devolve quantos.
(defun bb:cogo-limpar-canos (ssc desc / segs i o a b ss e x y n)
  (setq n 0 i 0)
  (repeat (sslength ssc)
    (setq o (vlax-ename->vla-object (ssname ssc i))
          i (1+ i)
          a (bb:obj->pt (bb:prop o 'StartPoint))
          b (bb:obj->pt (bb:prop o 'EndPoint)))
    (if (and a b) (setq segs (cons (list a b) segs))))
  (if (and desc segs (setq ss (ssget "_X" '((0 . "AECC_COGO_POINT")))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq e (ssname ss i) i (1+ i))
        (if (and (entget e)
                 (not (assoc -3 (entget e '("BOCAS_BUEIRO"))))
                 (setq o (vlax-ename->vla-object e))
                 (numberp (setq x (bb:try o 'Easting)))
                 (numberp (setq y (bb:try o 'Northing)))
                 (= (bb:try o 'RawDescription) desc)
                 (vl-some '(lambda (s) (<= (bb:dist-seg (list x y) (car s) (cadr s)) 2.0)) segs)
                 (not (vl-catch-all-error-p (vl-catch-all-apply 'entdel (list e)))))
          (setq n (1+ n))))))
  n)

;;; COGO point no cruzamento do eixo da rodovia com cada cano do bueiro,
;;; na cota da face *BB:COGO-FACE*. Uma vez por bueiro por execucao;
;;; apaga antes os pontos que a LISP tinha criado neste bueiro.
;;; Versao protegida: se o COGO point der erro (ex.: Access Violation do
;;; Civil 3D), avisa e SEGUE o comando (bocas, cotas, aterro continuam).
(defun bb:cogo-bueiro (canos / okey otip oond r)
  (setq okey *bb:tag-key* otip *bb:tag-tipo* oond *bb:tag-onde*
        r    (vl-catch-all-apply 'bb:cogo-bueiro-0 (list canos)))
  (setq *bb:tag-key* okey *bb:tag-tipo* otip *bb:tag-onde* oond)   ; restaura a etiqueta
  (if (vl-catch-all-error-p r)
    (princ (strcat "\n  AVISO: COGO point nao criado neste bueiro ("
                   (vl-catch-all-error-message r) "). O resto segue normal;"
                   " depois rode BBCOGO.")))
  (princ))

(defun bb:cogo-bueiro-0 (canos / hs k n c pa pb xr x L tt za zb zc hh z pt okey otip oond)
  (if (and *BB:COGO* canos)
    (progn
      (setq hs (bb:chave canos)
            k  (strcat "CG" (apply 'strcat hs)))
      (if (not (member k *bb:limpos*))
        (progn
          (setq *bb:limpos* (cons k *bb:limpos*)
                okey *bb:tag-key* otip *bb:tag-tipo* oond *bb:tag-onde*
                *bb:tag-key* hs *bb:tag-tipo* "C" *bb:tag-onde* "PL"
                n 0)
          (bb:limpar hs '("C") '("PL"))
          ;; UM ponto por bueiro (simples, duplo ou triplo): no cruzamento do
          ;; eixo da rodovia com a linha de centro do bueiro (media das pontas
          ;; dos canos = alinhamento do bueiro). Cota = media dos canos.
          ;; (os canos chegam todos orientados no mesmo sentido)
          (setq pa (bb:media (mapcar 'cadr canos))
                pb (bb:media (mapcar 'caddr canos)))
          (if (setq xr (bb:eixo-cruza nil pa pb))
            (progn
              (setq c  (car canos)
                    x  (car xr)
                    L  (bb:d2 pa pb)
                    tt (if (> L 1e-9) (/ (bb:d2 pa x) L) 0.0)
                    ;; cota do eixo (centro) dos canos nas pontas (media)
                    za (/ (apply '+ (mapcar '(lambda (k) (bb:z-eixo k (nth 1 k))) canos))
                          (float (length canos)))
                    zb (/ (apply '+ (mapcar '(lambda (k) (bb:z-eixo k (nth 2 k))) canos))
                          (float (length canos)))
                    zc (+ za (* tt (- zb za)))
                    hh (if (and (= (nth 4 c) "CC") (numberp (nth 5 c))) (nth 5 c) (nth 3 c))
                    z  (cond ((= *BB:COGO-FACE* "SUP") (+ zc (/ hh 2.0)))
                             ((= *BB:COGO-FACE* "EXT") (+ zc (/ hh 2.0) (bb:parede-cano c 0.0 hh)))
                             (T (- zc (/ hh 2.0)))))
              (if *BB:SUBSTITUIR* (bb:cogo-limpar-perto x *BB:COGO-DESC*))
              (if (setq pt (bb:cogo-add (list (car x) (cadr x) z) *BB:COGO-DESC*))
                (progn (bb:tag pt) (bb:cogo-layer pt) (setq n 1)))))
          (setq *bb:tag-key* okey *bb:tag-tipo* otip *bb:tag-onde* oond)
          (cond
            ((> n 0)
             (princ (strcat "\n  COGO point no eixo do bueiro (" *BB:COGO-FACE* ")"
                            (if (bb:layer-cogo) (strcat " - layer " (bb:layer-cogo)) ""))))
            ((not (bb:civ-doc))
             (princ "\n  AVISO: COGO point nao criado (nao achei o Civil 3D via COM)."))
            (T (princ "\n  (COGO point: eixo da rodovia nao cruza este bueiro)"))))))))

;;; Grava o recobrimento no eixo (m) na propriedade *BB:ATERRO-PROP* de
;;; cada cano do bueiro (*bb:canos-cota*), para a label da pipe mostrar.
;;; Grava o numero V na propriedade NM do cano OBJ e confere lendo de volta.
(defun bb:grava-num (obj nm v / en r)
  (setq en (vlax-vla-object->ename obj))
  (or
    ;; API .NET (setpropertyvalue) + conferencia
    (and (not (vl-catch-all-error-p
                (vl-catch-all-apply 'setpropertyvalue (list en nm v))))
         (numberp (setq r (bb:gpv en nm)))
         (equal r v 1e-4))
    ;; COM (ActiveX) + conferencia
    (and (not (vl-catch-all-error-p
                (vl-catch-all-apply 'vlax-put-property (list obj nm v))))
         (numberp (setq r (bb:try obj nm)))
         (equal r v 1e-4))))

(defun bb:aterro-grava (v / n ok nms)
  (if (and *BB:ATERRO-GRAVAR* *bb:canos-cota* (numberp v))
    (progn
      (setq v (atof (rtos v 2 *BB:ATERRO-PREC*)) n 0)
      (foreach c *bb:canos-cota*
        ;; usa o nome que ja funcionou; senao testa a lista
        (setq nms (if *bb:aterro-nome* (list *bb:aterro-nome*) *BB:ATERRO-PROP*)
              ok  nil)
        (foreach nm nms
          (if (and (not ok) (bb:grava-num (car c) nm v))
            (setq ok T *bb:aterro-nome* nm)))
        (if ok (setq n (1+ n))))
      (if (> n 0)
        (princ (strcat "\n  altura de aterro " (rtos v 2 3) " m gravada em " (itoa n) " de "
                       (itoa (length *bb:canos-cota*)) " pipe(s) (" *bb:aterro-nome* ")"))
        (princ (strcat "\n  AVISO: nao consegui gravar a altura de aterro na pipe."
                       " Rode BBDIAG num cano e me mande o trecho do dumpallproperties"
                       " com \"GradeLine\"."))))))

;;; ---------------- TIPO DE OBRA NAS LABELS (PLANTA E PERFIL)--------------
;;; Numero com N casas fixas (3.00), sem depender do DIMZIN
(defun bb:num-fixo (v n / dz s)
  (setq dz (getvar "DIMZIN"))
  (setvar "DIMZIN" 0)
  (setq s (rtos v 2 n))
  (setvar "DIMZIN" dz)
  s)

;;; Texto da obra: celular "BDCC 3.00x3.00m" | tubular "BTTC d=1.50m"
(defun bb:obra-txt (canos / tp)
  (setq tp (bb:tipo-obra canos))
  (if (= (substr (car tp) 3 1) "C")
    (strcat (car tp) " " (bb:num-fixo (cadr tp) *BB:OBRA-CASAS*)
            "x" (bb:num-fixo (caddr tp) *BB:OBRA-CASAS*) "m")
    (strcat (car tp) " d=" (bb:num-fixo (cadr tp) *BB:OBRA-CASAS*) "m")))

;;; Grava o texto da obra na Description de cada pipe do bueiro G
(defun bb:obra-grava (g / txt n)
  (setq txt (bb:obra-txt g) n 0)
  (foreach c g
    (vl-catch-all-apply 'vlax-put-property (list (car c) 'Description txt))
    (if (= (bb:try (car c) 'Description) txt) (setq n (1+ n))))
  (princ (strcat "\n  tipo de obra \"" txt "\" gravado em " (itoa n) " de "
                 (itoa (length g)) " pipe(s)"))
  n)

;;; Troca o diametro (com o %%C: / O: da frente) pelo campo da Description
;;; no texto S de um componente da label style. nil se nao tem diametro.
(defun bb:obra-subst (s / i j pre)
  (foreach fld '("<[Pipe Inner Diameter or Width(" "<[Pipe Outer Diameter or Width(")
    (if (and (not i) (setq i (vl-string-search fld s)))
      (setq j (vl-string-search "]>" s i))))
  (if (and i j)
    (progn
      (foreach p (list "%%C:" "%%c:" (strcat (chr 216) ":") "\\U+00D8:" "%%C" "%%c" (chr 216) "\\U+00D8")
        (if (and (not pre) (>= i (strlen p)) (= (substr s (1+ (- i (strlen p))) (strlen p)) p))
          (setq pre p)))
      (strcat (substr s 1 (- i (if pre (strlen pre) 0))) *BB:OBRA-CAMPO* (substr s (+ j 3))))))

;;; Pipe de uma label de pipe: a de planta tem Pipe; a de perfil tem a
;;; pipe desenhada no perfil (ProfileNetworkPart -> GetModelNetworkPart).
(defun bb:label-pipe (o / p pt)
  (setq p (bb:try o 'Pipe))
  (if (and (/= (type p) 'VLA-OBJECT)
           (= (type (setq pt (bb:try o 'ProfileNetworkPart))) 'VLA-OBJECT))
    (setq p (vl-catch-all-apply 'vlax-invoke-method (list pt 'GetModelNetworkPart))))
  (if (= (type p) 'VLA-OBJECT) p))

;;; Estilos das labels de PLANTA e PERFIL das pipes HS (handles): troca o
;;; diametro pelo campo da Description. Devolve as labels: lista de (label . estilo).
(defun bb:obra-estilos (hs / ss i e o p st nm vistos labs tc ct v novo nok)
  (if (setq ss (ssget "_X" '((0 . "AECC_PIPE_LABEL,AECC_PIPE_PROFILE_LABEL"))))
    (repeat (setq i (sslength ss))
      (setq e (ssname ss (setq i (1- i))) o (vlax-ename->vla-object e) p (bb:label-pipe o))
      (if (and (= (type p) 'VLA-OBJECT) (member (vla-get-Handle p) hs))
        (progn
          (setq st (bb:try o 'LabelStyle) nm (if (= (type st) 'VLA-OBJECT) (bb:try st 'Name)))
          (if nm (setq labs (cons (cons o st) labs)))
          (if (and nm (not (member nm vistos)))
            (progn
              (setq vistos (cons nm vistos) nok T)
              (if (= (type (setq tc (bb:try st 'TextComponents))) 'VLA-OBJECT)
                (vlax-for k tc
                  (setq ct (bb:try k 'Contents) v (if (= (type ct) 'VLA-OBJECT) (bb:try ct 'Value)))
                  (cond ((/= (type v) 'STR))
                        ((vl-string-search *BB:OBRA-CAMPO* v) (setq nok nil))   ; ja trocado
                        ((setq novo (bb:obra-subst v))
                         (vl-catch-all-apply 'vlax-put-property (list ct 'Value novo))
                         (if (= (bb:try ct 'Value) novo)
                           (progn
                             (setq nok nil)
                             (princ (strcat "\nEstilo de label \"" nm
                                            "\": diametro trocado pelo tipo de obra."))))))))
              (if nok
                (princ (strcat "\nAVISO: estilo de label \"" nm "\" sem o campo de diametro;"
                               " o tipo de obra nao entrou na label."))
                (bb:aterro-no-estilo st nm))))))))
  labs)

;;; Linha da altura de aterro (EGL) no estilo ST. Sem ela a label perde a
;;; altura de aterro quando o texto editado na label e descartado.
;;; Se faltar, poe no fim do componente que tem o tipo de obra.
(defun bb:aterro-no-estilo (st nm / ct v alvo tem outro)
  (vlax-for k (bb:try st 'TextComponents)
    (setq ct (bb:try k 'Contents) v (if (= (type ct) 'VLA-OBJECT) (bb:try ct 'Value)))
    (if (= (type v) 'STR)
      (cond ((vl-string-search "<[Energy Grade Line Up(" v) (setq tem T))
            ((vl-string-search "ALTURA DE ATERRO" (strcase v)) (setq outro T))
            ((vl-string-search *BB:OBRA-CAMPO* v) (setq alvo (cons ct v))))))
  (cond
    (tem)
    (outro
     (princ (strcat "\nAVISO: estilo de label \"" nm "\" tem \"Altura de Aterro\" sem o campo"
                    " Energy Grade Line Up: troque o campo no estilo para mostrar o aterro da LISP.")))
    (alvo
     (setq v (cdr alvo)
           v (if (= (substr v (strlen v)) "}")
               (strcat (substr v 1 (1- (strlen v))) *BB:ATERRO-LINHA* "}")
               (strcat v *BB:ATERRO-LINHA*)))
     (vl-catch-all-apply 'vlax-put-property (list (car alvo) 'Value v))
     (if (= (bb:try (car alvo) 'Value) v)
       (princ (strcat "\nEstilo de label \"" nm "\": linha Altura de Aterro incluida."))
       (princ (strcat "\nAVISO: nao consegui incluir a linha Altura de Aterro no estilo \"" nm "\"."))))))

;;; Devolve o texto do estilo a label O (estilo ST). Texto editado na
;;; propria label (Edit Label Text ou plugin AlturaAterroV4) passa por cima
;;; do estilo e nao tem como ser lido pela LISP; o Civil 3D descarta esse
;;; texto quando a label troca de estilo. Entao: troca para um estilo filho
;;; temporario, volta para ST e apaga o filho. T se voltou para ST.
(defun bb:label-reset (o st / ch tmp ok)
  (if (= (type (setq ch (bb:try st 'Children))) 'VLA-OBJECT)
    (progn
      (vl-catch-all-apply 'vlax-invoke-method (list ch 'Remove *BB:LABEL-TMP*))  ; sobra de erro
      (if (not (vl-catch-all-error-p
                 (setq tmp (vl-catch-all-apply 'vlax-invoke-method (list ch 'Add *BB:LABEL-TMP*)))))
        (progn
          (vl-catch-all-apply 'vlax-put-property (list o 'LabelStyle tmp))
          (vl-catch-all-apply 'vlax-put-property (list o 'LabelStyle st))
          (setq ok (= (bb:try (bb:try o 'LabelStyle) 'Name) (bb:try st 'Name)))
          (vl-catch-all-apply 'vlax-invoke-method (list ch 'Remove *BB:LABEL-TMP*))))))
  ok)
(setq *BB:LABEL-TMP* "BB_TMP_RESET")     ; nome do estilo filho temporario

;;; Tipo de obra de cada bueiro na Description das pipes + estilo da label
(defun bb:obra-grupos (grupos / hs labs e xd n)
  (foreach g grupos
    (bb:obra-grava g)
    (setq hs (append (mapcar '(lambda (c) (vla-get-Handle (car c))) g) hs)))
  (setq labs (bb:obra-estilos hs) n 0)
  ;; labels de planta e perfil dos bueiros voltam a seguir o estilo
  (if *BB:OBRA-LIMPA-LABEL*
    (progn
      (foreach x labs
        (if (bb:label-reset (car x) (cdr x)) (setq n (1+ n)))
        ;; vinculo do plugin AlturaAterroV4: sem ele o plugin nao grava de novo
        (setq e (vlax-vla-object->ename (car x)))
        (if (and (setq xd (cdr (assoc 360 (member '(102 . "{ACAD_XDICTIONARY") (entget e)))))
                 (dictsearch xd "ALTURA_ATERRO_V4"))
          (dictremove xd "ALTURA_ATERRO_V4")))
      (princ (strcat "\n" (itoa n) " de " (itoa (length labs))
                     " label(s) de planta e perfil dos bueiros seguindo o estilo (texto editado na label descartado).")))))

;;; So o tipo de obra nas labels de planta e perfil, sem mexer em mais nada
(defun c:BBOBRA (/ *error* doc dbg ss i c canos grupos)
  (defun *error* (msg)
    (setq *BB:DEBUG* dbg)
    (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg)))
    (princ))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)) dbg *BB:DEBUG*)
  (princ "\nSelecione os canos dos bueiros <ENTER = todos do desenho>: ")
  (if (not (setq ss (ssget '((0 . "AECC_PIPE")))))
    (setq ss (ssget "_X" '((0 . "AECC_PIPE")))))
  (if (not ss) (progn (princ "\nNenhum cano (pipe) no desenho.") (exit)))
  (setq *BB:DEBUG* nil i 0)
  (repeat (sslength ss)
    (if (setq c (bb:ler-cano (ssname ss i))) (setq canos (cons c canos)))
    (setq i (1+ i)))
  (setq *BB:DEBUG* dbg)
  (if (not canos) (progn (princ "\nNenhum cano legivel.") (exit)))
  (setq grupos (bb:agrupar (reverse canos)))
  (vla-StartUndoMark doc)
  (bb:obra-grupos grupos)
  (vla-EndUndoMark doc)
  (princ))

;;; Cotas no perfil: ponta de montante -> eixo da rodovia -> ponta de jusante
;;; e, no eixo, a cota vertical do greide do eixo ate o topo externo do cano
;;; (recobrimento). HH = diametro/altura interna, W = parede.
(defun bb:perfil-cotas (pv al pa pb sM sJ zM zJ hh w / xr x se ze p1 p2 p3 q pz yl gr pt pg dg1 dg2)
  (cond
    ((not (setq xr (bb:eixo-cruza al pa pb)))
     (princ "\n  (cotas: eixo da rodovia nao encontrado cruzando o bueiro)"))
    ((not (setq x (car xr) se (car (bb:al-sta al x))))
     (princ "\n  (cotas: cruzamento com o eixo fora do alinhamento do perfil)"))
    (T
     (setq ze (+ zM (* (- zJ zM) (/ (- se sM) (if (equal sJ sM 1e-9) 1.0 (- sJ sM)))))
           p1 (bb:pv-xy pv sM zM)
           p2 (bb:pv-xy pv se ze)
           p3 (bb:pv-xy pv sJ zJ)
           q  (bb:pv-xy pv (+ se 1.0) ze)
           pz (bb:pv-xy pv se (+ ze 1.0)))
     (if (and p1 p2 p3 q pz)
       (progn
         ;; horizontais: montante -> eixo -> jusante
         (setq yl (- (min (cadr p1) (cadr p3)) *BB:COTA-DESL*))
         (if (not *bb:so-aterro*)
           (bb:cotas-soma-L
             (bb:cota p1 p2 yl (abs (- (car q) (car p2))))
             (bb:cota p2 p3 yl (abs (- (car q) (car p2))))
             (abs (- se sM)) (abs (- sJ se))))
         (princ (strcat "\n  cotas a partir do eixo: " (rtos (abs (- se sM)) 2 2)
                        " + " (rtos (abs (- sJ se)) 2 2) " m"))
         ;; vertical: superficie projetada -> topo externo do cano (recobrimento).
         ;; Perfis do proprio bueiro (o que esta desenhado) na estaca do
         ;; eixo; se nao der, perfis do eixo da rodovia no cruzamento.
         (setq *bb:greide-topo* (+ ze hh w))   ; p/ a pergunta mostrar o aterro de cada perfil
         (setq gr (bb:greide al se) dg2 *bb:greide-diag*)
         (if (not gr)
           (setq gr (bb:greide (cadr xr) (car (bb:al-sta (cadr xr) x))) dg1 *bb:greide-diag*))
         ;; greide ABAIXO do topo do cano = quase sempre perfil errado (ex.:
         ;; terreno natural). Avisa e pergunta de novo qual e o projetado.
         (if (and gr (< (- (car gr) ze hh w) 0.0))
           (progn
             (princ (strcat "\n  AVISO: o perfil \"" (cadr gr) "\" (cota " (rtos (car gr) 2 3)
                            ") esta ABAIXO do topo do cano (" (rtos (+ ze hh w) 2 3)
                            "). Deve ser o terreno natural - escolha o greide:"))
             (setq *bb:greide-forcar* T
                   *bb:greide-padrao* nil
                   *bb:greide-nome-ant* nil)
             (setq gr (cond ((bb:greide al se))
                            ((bb:greide (cadr xr) (car (bb:al-sta (cadr xr) x))))
                            (T gr)))
             (setq *bb:greide-forcar* nil)))
         (setq *bb:greide-topo* nil)
         (if (and gr
                  (setq pt (bb:pv-xy pv se (+ ze hh w)))
                  (setq pg (bb:pv-xy pv se (car gr))))
           (progn
             (if (and (not *bb:so-aterro*)
                      ;; linha da cota a ESQUERDA do eixo
                      (not (bb:cota-rot pt pg (list (- (car pt) (* 2.0 *BB:COTA-DESL*)) (cadr pt))
                                        (* 0.5 pi) (abs (- (cadr pz) (cadr p2))) *BB:COTA-ESTILO-REC*)))
               (princ "\n  (AVISO: o AutoCAD nao criou a cota vertical)"))
             ;; mesmo valor da cota vertical -> propriedade da pipe (label)
             (bb:aterro-grava (- (car gr) ze hh w))
             (princ (strcat "\n  recobrimento no eixo: greide " (rtos (car gr) 2 3)
                            " (perfil \"" (cadr gr) "\") - topo externo "
                            (rtos (+ ze hh w) 2 3) " = " (rtos (- (car gr) ze hh w) 2 2) " m")))
           (princ (strcat "\n  (recobrimento: perfil de projeto nao encontrado."
                          "\n   perfis do eixo:" (vl-princ-to-string dg1)
                          "\n   perfis do bueiro:" (vl-princ-to-string dg2) ")"))))))))

;;; W = parede do cano (m)
(defun bb:perfil-inserir (pv al pa pb code shp D HC sM sJ zM zJ w / prm sg deb e0 e1 sa)
  (cond
    ((not (setq prm (bb:corte-param shp code D HC)))
     (princ (strcat "\n  Sem dados de corte para " code ".")) nil)
    (T
     (setq sg (if (< sM sJ) -1.0 1.0)
           *bb:tag-onde* "PF"
           *bb:tag-tipo* "B")
     ;; apaga o que a execucao anterior fez neste bueiro no perfil
     (bb:limpar-auto "PF")
     ;; altura de aterro na pipe SEM desenhar cotas: no BBATERRO e tambem
     ;; quando o comando nao vai desenhar as cotas (BBTD, rotulos off...).
     ;; Com bocas + rotulos, ela e gravada junto com a cota vertical abaixo.
     (if (or *bb:so-aterro* (not (and *bb:fazer-bocas* *BB:ROTULOS*)))
       (progn
         (setq sa *bb:so-aterro* *bb:so-aterro* T)
         (bb:perfil-cotas pv al pa pb sM sJ zM zJ (if (and (= shp "CC") HC) HC D) w)
         (setq *bb:so-aterro* sa)))
     (if (and *bb:fazer-bocas* (not *bb:so-aterro*))
       (progn
         (bb:corte-bloco prm)
         (bb:perfil-boca pv prm sM zM sg)
         (bb:perfil-boca pv prm sJ zJ (- sg))
         (if *BB:ROTULOS*
           (progn
             (bb:perfil-cota-diam pv sM zM (if (and (= shp "CC") HC) HC D) sg)
             (bb:perfil-rotulo-boca pv prm sM zM sg "MONTANTE")
             (bb:perfil-rotulo-boca pv prm sJ zJ (- sg) "JUSANTE")
             (bb:perfil-cotas pv al pa pb sM sJ zM zJ
                              (if (and (= shp "CC") HC) HC D) w)))))
     ;; dissipador DEB na jusante (tubular ate o limite de diametro)
     (setq *bb:tag-tipo* "D")
     (if (and *bb:fazer-dissip* (not *bb:so-aterro*) *BB:DISSIP-DNIT* (= shp "TC")
              (<= D (+ *BB:DIAM-LIMITE* 1e-6))
              (setq deb (bb:deb-param code D)))
       (if (bb:perfil-dissip pv prm deb sJ zJ (- sg))
         (princ (strcat "\n  dissipador " (car deb) " na jusante"))))
     (princ (strcat "\n  " code " D=" (rtos D 2 2) " -> " (car prm)
                    "\n  montante: est. " (rtos sM 2 2) "  geratriz inf. " (rtos zM 2 3)
                    "\n  jusante : est. " (rtos sJ 2 2) "  geratriz inf. " (rtos zJ 2 3)))
     (setq e0 (bb:try pv 'ElevationMin) e1 (bb:try pv 'ElevationMax))
     (if (and (numberp e0) (numberp e1)
              (or (< (min zM zJ) (- e0 1.0)) (> (max zM zJ) (+ e1 1.0))))
       (princ (strcat "\n  AVISO: cota fora do perfil (" (rtos e0 2 2) " a " (rtos e1 2 2)
                      "). Me envie estas linhas; ajuste *BB:PERFIL-DZ* se preciso.")))
     T)))

;;; Mesmo que bb:perfil-grupo, mas estacas e cotas tiradas da PIPE DESENHADA
;;; no perfil (objeto GE). Da pipe 3D usa so diametro, desnivel entre as
;;; pontas e qual ponta e a jusante.
(defun bb:perfil-grupo-pv (pv al g ge / n res canos dz cx D HC shp code hh zdif wall
                                     zM zJ sM sJ jS pk q zmod)
  (setq n (length g) res (bb:orientar g) canos (car res) dz (cadr res))
  (cond
    ((> dz *BB:TOL-Z*))
    ((< dz (- *BB:TOL-Z*)) (setq canos (mapcar 'bb:inverter canos)))
    (T (setq canos nil)))
  (cond
    ((> n 3) (princ "\n  Mais de 3 canos paralelos (maximo = triplo).") nil)
    ((not canos) (princ "\n  Cotas iguais nas pontas: nao da para saber montante/jusante.") nil)
    ((not (setq cx (bb:ge-caixa pv ge)))
     (princ "\n  Nao consegui ler a pipe desenhada no perfil.") nil)
    (T
     (setq D    (apply 'max (mapcar 'cadddr canos))
           shp  (if (member "CC" (mapcar '(lambda (c) (nth 4 c)) canos)) "CC" "TC")
           HC   (if (= shp "CC")
                  (apply 'max (cons 0.0 (vl-remove-if-not 'numberp
                                          (mapcar '(lambda (c) (nth 5 c)) canos)))))
           code (strcat "B" (nth (1- n) '("S" "D" "T")) shp))
     (if (and HC (<= HC 0.0)) (setq HC nil))
     (setq hh   (if (and (= shp "CC") HC) HC D)
           zdif (/ (abs dz) (float n))                      ; desnivel entre as pontas
           wall (bb:parede-cano (car canos) (/ (- (nth 3 cx) (nth 2 cx) zdif hh) 2.0) hh)
           zJ   (+ (nth 2 cx) wall *BB:PERFIL-DZ*)          ; jusante = ponta mais baixa
           zM   (+ zJ zdif))
     ;; qual estaca e a jusante: pela posicao da jusante no alinhamento,
     ;; ou perguntando
     (setq jS (bb:al-sta al (bb:media (mapcar 'caddr canos))))
     (if (not jS)
       (if (and (setq pk (getpoint "\n  Clique perto da JUSANTE no perfil: "))
                (setq q (bb:pv-se pv (car (trans pk 1 0)) (cadr (trans pk 1 0)))))
         (setq jS q)))
     (if (not jS)
       (progn (princ "\n  Jusante nao definida.") nil)
       (progn
         (if (< (abs (- (car jS) (nth 0 cx))) (abs (- (car jS) (nth 1 cx))))
           (setq sJ (nth 0 cx) sM (nth 1 cx))
           (setq sJ (nth 1 cx) sM (nth 0 cx)))
         (setq zmod (bb:z-geratriz canos 2)
               *bb:canos-cota* canos      ; p/ gravar a altura de aterro nas pipes
               *bb:tag-key*    (bb:chave canos))
         (bb:cogo-bueiro canos)          ; COGO point no eixo
         (princ (strcat "\n  (pela pipe desenhada; cota da pipe 3D na jusante = " (rtos zmod 2 3)
                        ", diferenca " (rtos (- zJ zmod) 2 3) " m)"))
         (bb:perfil-inserir pv al (bb:media (mapcar 'cadr canos)) (bb:media (mapcar 'caddr canos))
                            code shp D HC sM sJ zM zJ wall))))))

;;; Voce clica na pipe DENTRO do perfil; o programa acha o Profile View
;;; pelo ponto clicado, junta os canos paralelos (duplo/triplo) e insere
;;; as bocas no inicio e no fim do bueiro. Repete ate ENTER.
(defun c:BOCASPERFIL (/ *error* doc ssp i c canos grupos dbg en pu pt dd ss j tp pe ge cx pv al g ok)
  (defun *error* (msg)
    (setq *BB:DEBUG* dbg)
    (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg)))
    (princ))
  (bb:modo T T T T)
  (setq *bb:als* nil
        doc (vla-get-ActiveDocument (vlax-get-acad-object))
        dbg *BB:DEBUG*
        ok  0)
  (if (not (setq ssp (ssget "_X" '((0 . "AECC_PIPE")))))
    (progn (princ "\nNenhum cano (pipe) no desenho.") (exit)))
  ;; le e agrupa os canos do desenho (para achar os paralelos da pipe clicada)
  (setq *BB:DEBUG* nil i 0)
  (repeat (sslength ssp)
    (if (setq c (bb:ler-cano (ssname ssp i))) (setq canos (cons c canos)))
    (setq i (1+ i)))
  (setq *BB:DEBUG* dbg
        grupos (bb:agrupar (reverse canos)))
  (vla-StartUndoMark doc)
  (while (setq pu (getpoint "\nClique sobre a PIPE no perfil <ENTER = terminar>: "))
    (setq *bb:limpos* nil)               ; cada clique refaz (e limpa) o bueiro clicado
    ;; objetos em volta do clique (tamanho do pickbox); procura a pipe
    (setq pt (trans pu 1 0)
          dd (* (getvar "PICKBOX") (/ (getvar "VIEWSIZE") (cadr (getvar "SCREENSIZE"))))
          ss (ssget "_C" (list (- (car pu) dd) (- (cadr pu) dd))
                         (list (+ (car pu) dd) (+ (cadr pu) dd)))
          pe nil
          ge nil
          tp "nenhum"
          j  0)
    (if ss
      (repeat (sslength ss)
        (setq en (ssname ss j) j (1+ j))
        (if (and (not ge) (= (cdr (assoc 0 (entget en))) "AECC_GRAPH_PROFILE_NETWORK_PART"))
          (setq ge en))
        (if (not pe)
          (progn
            (setq tp (cdr (assoc 0 (entget en))))
            (setq pe (cond ((= tp "AECC_PIPE") en) ((bb:pipe-de-parte en))))))))
    (cond
      ((not (setq pv (bb:pv-no-ponto pt)))
       (princ "\nNenhum Profile View nesse ponto."))
      ((not (setq al (bb:pv-alinhamento pv (vlax-vla-object->ename pv))))
       (princ "\nPerfil sem alinhamento."))
      ((not (princ (strcat "\n  perfil \"" (bb:nome pv (vlax-vla-object->ename pv))
                           "\" | alinhamento \"" (bb:nome al (vlax-vla-object->ename al))
                           "\" | pipe clicada: " (if pe "sim" (strcat "nao (" tp ")")))))
       nil)                               ; so mostra; nunca para aqui
      ;; 0) pipe desenhada no perfil: estacas e cotas do proprio desenho
      ((and ge
            (setq cx (bb:ge-caixa pv ge))
            ;; ("and"/"or" do AutoLISP devolvem so T, nao o valor)
            (progn
              (setq g (if pe
                        (vl-some '(lambda (gr)
                                    (if (vl-some '(lambda (c) (equal (vlax-vla-object->ename (car c)) pe)) gr)
                                      gr))
                                 grupos)))
              (if (not g) (setq g (bb:grupo-por-caixa al grupos cx)))
              g))
       (if (bb:perfil-grupo-pv pv al g ge) (setq ok (1+ ok))))
      ;; 1) pipe identificada pelo objeto clicado
      ((and pe
            (setq g (vl-some '(lambda (gr)
                                (if (vl-some '(lambda (c) (equal (vlax-vla-object->ename (car c)) pe)) gr)
                                  gr))
                             grupos)))
       (if (bb:perfil-grupo pv al g) (setq ok (1+ ok))))
      ;; 2) pela posicao: o cano cuja linha no perfil passa mais perto do clique
      ((setq g (bb:grupo-perto pv al pt grupos))
       (if (bb:perfil-grupo pv al g) (setq ok (1+ ok))))
      (T
       (princ (strcat "\nNenhuma pipe encontrada nesse ponto (objeto clicado: " tp
                      "). Clique sobre a linha do cano.")))))
  (vla-EndUndoMark doc)
  (princ (strcat "\nConcluido: " (itoa ok) " bueiro(s) com bocas no perfil. (U desfaz)"))
  (princ))

;;; Modo automatico (antigo): acha os bueiros sobre o alinhamento de cada
;;; Profile View selecionado.
(defun c:BOCASPERFILAUTO (/ *error* doc ssv ssp i c canos grupos dbg pv en al st0 st1
                        n res dz PM PJ D HC shp code prm hh mS jS tol sg tot ok cand)
  (defun *error* (msg)
    (setq *BB:DEBUG* dbg)
    (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg)))
    (princ))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        dbg *BB:DEBUG*
        tot 0
        *bb:tag-key* nil)                ; modo antigo: nao etiqueta
  (princ "\nSelecione o(s) PROFILE VIEW(s): ")
  (if (not (setq ssv (ssget '((0 . "AECC_PROFILE_VIEW")))))
    (progn (princ "\nNenhum perfil selecionado.") (exit)))
  (if (not (setq ssp (ssget "_X" '((0 . "AECC_PIPE")))))
    (progn (princ "\nNenhum cano (pipe) no desenho.") (exit)))
  ;; le e agrupa todos os canos do desenho
  (setq *BB:DEBUG* nil i 0)
  (repeat (sslength ssp)
    (if (setq c (bb:ler-cano (ssname ssp i))) (setq canos (cons c canos)))
    (setq i (1+ i)))
  (setq *BB:DEBUG* dbg
        grupos (bb:agrupar (reverse canos)))
  (vla-StartUndoMark doc)
  (setq i 0)
  (repeat (sslength ssv)
    (setq en  (ssname ssv i)
          pv  (vlax-ename->vla-object en)
          al  (bb:pv-alinhamento pv en)
          st0 (bb:try pv 'StationStart)
          st1 (bb:try pv 'StationEnd)
          cand nil
          ok  0
          i   (1+ i))
    (if al
      (foreach g grupos
        (setq n (length g) res (bb:orientar g) canos (car res) dz (cadr res))
        (cond
          ((> n 3) (setq canos nil))
          ((> dz *BB:TOL-Z*))
          ((< dz (- *BB:TOL-Z*)) (setq canos (mapcar 'bb:inverter canos)))
          (T (setq canos nil)))
        (if canos
          (progn
            (setq PM  (bb:media (mapcar 'cadr canos))
                  PJ  (bb:media (mapcar 'caddr canos))
                  D   (apply 'max (mapcar 'cadddr canos))
                  shp (if (member "CC" (mapcar '(lambda (c) (nth 4 c)) canos)) "CC" "TC")
                  HC  (if (= shp "CC")
                        (apply 'max (cons 0.0 (vl-remove-if-not 'numberp
                                                (mapcar '(lambda (c) (nth 5 c)) canos)))))
                  code (strcat "B" (nth (1- n) '("S" "D" "T")) shp)
                  tol (+ *BB:PERFIL-TOL-OFF* (* n D))
                  mS  (bb:al-sta al PM)
                  jS  (bb:al-sta al PJ))
            (if (and HC (<= HC 0.0)) (setq HC nil))
            ;; candidato: (afastamento-max code D HC mS jS PM PJ prm shp)
            (if (and mS jS
                     (<= (abs (cadr mS)) tol) (<= (abs (cadr jS)) tol)
                     (or (not (and (numberp st0) (numberp st1)))
                         (and (>= (min (car mS) (car jS)) (- st0 1.0))
                              (<= (max (car mS) (car jS)) (+ st1 1.0))))
                     (setq prm (bb:corte-param shp code D HC)))
              (setq cand (cons (list (max (abs (cadr mS)) (abs (cadr jS)))
                                     code D HC mS jS PM PJ prm shp)
                               cand))))))
      (princ (strcat "\n  Perfil " (itoa i) ": sem alinhamento, ignorado.")))
    ;; o mais proximo do alinhamento primeiro; com *BB:PERFIL-UM* so ele
    (setq cand (vl-sort cand '(lambda (a b) (< (car a) (car b)))))
    (if (and *BB:PERFIL-UM* cand) (setq cand (list (car cand))))
    (foreach k cand
      (setq code (nth 1 k) D (nth 2 k) HC (nth 3 k) mS (nth 4 k) jS (nth 5 k)
            PM (nth 6 k) PJ (nth 7 k) prm (nth 8 k) shp (nth 9 k))
      (bb:corte-bloco prm)
      (setq hh (if (and (= shp "CC") HC) HC D)
            sg (if (< (car mS) (car jS)) -1.0 1.0))
      (bb:perfil-boca pv prm (car mS) (- (caddr PM) (/ hh 2.0)) sg)
      (bb:perfil-boca pv prm (car jS) (- (caddr PJ) (/ hh 2.0)) (- sg))
      (setq ok (1+ ok))
      (princ (strcat "\n  Perfil " (itoa i) ": " code " D=" (rtos D 2 2)
                     " | montante est. " (rtos (car mS) 2 2)
                     " | jusante est. " (rtos (car jS) 2 2)
                     " -> " (car prm))))
    (if (and al (= ok 0))
      (princ (strcat "\n  Perfil " (itoa i) ": nenhum bueiro sobre o alinhamento.")))
    (setq tot (+ tot ok)))
  (vla-EndUndoMark doc)
  (princ (strcat "\nConcluido: " (itoa tot) " bueiro(s) com bocas no perfil. (U desfaz)"))
  (princ))

(defun c:BBP () (c:BOCASPERFIL))


;;; ===================== PLANTA + PERFIL (BOCASTUDO) ===================
;;; O bueiro g esta ao longo deste alinhamento? As duas pontas perto do
;;; eixo, dentro das estacas do perfil, e a diferenca de estacas ~ o
;;; comprimento do bueiro (descarta alinhamentos que so cruzam o bueiro,
;;; como o eixo da rodovia).
(defun bb:perfil-combina (al st0 st1 g / n D A B L tol sA sB)
  (setq n   (length g)
        D   (apply 'max (mapcar 'cadddr g))
        A   (bb:media (mapcar 'cadr g))
        B   (bb:media (mapcar 'caddr g))
        L   (bb:d2 A B)
        tol (+ *BB:PERFIL-TOL-OFF* (* n D))
        sA  (bb:al-sta al A)
        sB  (bb:al-sta al B))
  (and sA sB
       (<= (abs (cadr sA)) tol)
       (<= (abs (cadr sB)) tol)
       (>= (abs (- (car sB) (car sA))) (* 0.8 L))
       (or (not (and (numberp st0) (numberp st1)))
           (and (>= (min (car sA) (car sB)) (- st0 1.0))
                (<= (max (car sA) (car sB)) (+ st1 1.0))))))

;;; Profile View visivel? (layer ligada e descongelada, objeto visivel)
(defun bb:visivel (obj / d)
  (setq d (tblsearch "LAYER" (vla-get-Layer obj)))
  (and d
       (zerop (logand 1 (cdr (assoc 70 d))))      ; nao congelada
       (>= (cdr (assoc 62 d)) 0)                  ; ligada
       (not (member (bb:prop obj 'Visible) (list 0 :vlax-false)))))

;;; O que os comandos inserem: bocas / dissipador, em planta / perfil
(defun bb:modo (bocas dissip planta perfil)
  (setq *bb:so-aterro*    nil            ; BBATERRO liga depois de chamar bb:modo
        *bb:tag-key*      nil
        *bb:limpos*       nil
        *bb:fazer-bocas*  bocas
        *bb:fazer-dissip* dissip
        *bb:fazer-planta* planta
        *bb:fazer-perfil* perfil))

;;; Bocas em planta (como BBU) e em corte nos Profile Views de cada bueiro
;;; (como BBP), tudo de uma vez - respeitando bb:modo.
(defun bb:tudo (/ *error* doc blk ss ssv i c canos grupos pvs pv al idx np ok okp dbg nv inv sem)
  (defun *error* (msg)
    (setq *BB:DEBUG* dbg)
    (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg "  (etapa: " (vl-princ-to-string *bb:etapa*) ")")))
    (princ))
  (princ (strcat "\n[BOCAS_BUEIRO - "
                 (cond (*bb:so-aterro* "so altura de aterro na label")
                       ((and *bb:fazer-bocas* *bb:fazer-dissip*) "bocas + dissipador")
                       (*bb:fazer-bocas* "so bocas")
                       (T "so dissipador"))
                 " em "
                 (cond ((and *bb:fazer-planta* *bb:fazer-perfil*) "planta + perfil")
                       (*bb:fazer-planta* "planta")
                       (T "perfil"))
                 "]"))
  (setq doc                    (vla-get-ActiveDocument (vlax-get-acad-object))
        dbg                    *BB:DEBUG*
        *bb:dissip-perguntado* nil
        *bb:dissip-nome*       nil
        *bb:rot-dissip-sessao* nil
        *bb:pintados*          nil
        ok                     0
        okp                    0)
  (if (not (setq blk (bb:achar-boca doc)))
    (progn (princ "\nBloco das bocas nao definido. Comando cancelado.") (exit)))
  (princ "\nSelecione os canos dos bueiros <ENTER = todos do desenho>: ")
  (if (not (setq ss (ssget '((0 . "AECC_PIPE")))))
    (setq ss (ssget "_X" '((0 . "AECC_PIPE")))))
  (if (not ss) (progn (princ "\nNenhum cano (pipe) no desenho.") (exit)))
  ;; canos -> bueiros
  (setq *bb:etapa* "leitura dos canos" *BB:DEBUG* nil i 0)
  (repeat (sslength ss)
    (if (setq c (bb:ler-cano (ssname ss i))) (setq canos (cons c canos)))
    (setq i (1+ i)))
  (setq *BB:DEBUG* dbg)
  (if (not canos) (progn (princ "\nNenhum cano legivel.") (exit)))
  (setq grupos (bb:agrupar (reverse canos)))
  ;; Profile Views do desenho: (pv alinhamento estaca-ini estaca-fim)
  (setq *bb:als* nil nv 0 inv 0 sem nil)
  (if (and *bb:fazer-perfil* (setq ssv (ssget "_X" '((0 . "AECC_PROFILE_VIEW")))))
    (progn
      (setq i 0 nv (sslength ssv))
      (repeat nv
        (setq pv (vlax-ename->vla-object (ssname ssv i)))
        (cond
          ((not (bb:visivel pv))
           (setq inv (1+ inv)))                   ; layer desligada/congelada: ignora
          ((setq al (bb:pv-al-auto pv (ssname ssv i)))
           (setq pvs (cons (list pv al (bb:try pv 'StationStart) (bb:try pv 'StationEnd)
                                 (bb:nome pv (ssname ssv i)))
                           pvs)))
          (T (setq sem (cons (bb:nome pv (ssname ssv i)) sem))))
        (setq i (1+ i)))))
  (princ (strcat "\n" (itoa (length canos)) " cano(s) -> " (itoa (length grupos))
                 " bueiro(s); " (itoa nv) " Profile View(s) (" (itoa inv)
                 " invisivel(is) ignorado(s)), " (itoa (length pvs))
                 " com alinhamento identificado; " (itoa (length *bb:als*))
                 " alinhamento(s) no desenho."))
  (if sem
    (princ (strcat "\nPerfis sem alinhamento identificado: "
                   (apply 'strcat (mapcar '(lambda (s) (strcat "\"" s "\" ")) sem)))))
  (vla-StartUndoMark doc)
  (setq idx 0)
  (foreach g grupos
    (setq idx (1+ idx))
    ;; planta
    (setq *bb:etapa* "planta")
    (if (and *bb:fazer-planta* (bb:processar g idx blk)) (setq ok (1+ ok)))
    ;; perfil
    (if *bb:fazer-perfil*
      (progn
        (setq *bb:etapa* "perfil" np 0)
        (foreach v pvs
          (if (bb:perfil-combina (nth 1 v) (nth 2 v) (nth 3 v) g)
            (progn
              (princ (strcat "\n  perfil \"" (nth 4 v) "\":"))
              (if (bb:perfil-grupo (nth 0 v) (nth 1 v) g) (setq np (1+ np))))))
        (if (> np 0)
          (setq okp (1+ okp))
          (princ (strcat "\nBueiro " (itoa idx) ": nenhum Profile View encontrado (use BBP nele)."))))))
  ;; so planta (BBX -> Planta): grava a altura de aterro mesmo assim
  (if (not *bb:fazer-perfil*)
    (progn (setq *bb:etapa* "altura de aterro") (bb:aterro-perfis grupos)))
  ;; tipo de obra nas labels de planta e perfil
  (setq *bb:etapa* "tipo de obra")
  (if *BB:OBRA-GRAVAR* (bb:obra-grupos grupos))
  (vla-EndUndoMark doc)
  (princ (strcat "\nConcluido: " (itoa ok) " de " (itoa (length grupos))
                 " bueiro(s) em planta e " (itoa okp) " no perfil. (U desfaz tudo)"))
  (princ))

(defun c:BOCASTUDO () (bb:modo T T T T) (bb:tudo))
(defun c:BBT ()  (c:BOCASTUDO))                       ; bocas + dissipador, planta + perfil
(defun c:BBTB () (bb:modo T nil T T) (bb:tudo))      ; so bocas, planta + perfil
(defun c:BBTD () (bb:modo nil T T T) (bb:tudo))      ; so dissipadores, planta + perfil

;;; So os COGO points no eixo (1 por bueiro), sem mexer em mais nada.
;;; Apaga e recria os pontos que a LISP ja tinha feito nesses bueiros.
(defun c:BBCOGO (/ *error* doc dbg ss i c canos grupos n)
  (defun *error* (msg)
    (setq *BB:DEBUG* dbg)
    (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg)))
    (princ))
  (bb:modo nil nil nil nil)               ; zera etiquetas/limpeza da execucao
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        dbg *BB:DEBUG*
        *bb:als* nil
        n 0)
  (if (not *BB:COGO*)
    (progn (princ "\n*BB:COGO* esta nil (COGO points desligados na configuracao).") (exit)))
  (princ "\nSelecione os canos dos bueiros <ENTER = todos do desenho>: ")
  (if (not (setq ss (ssget '((0 . "AECC_PIPE")))))
    (setq ss (ssget "_X" '((0 . "AECC_PIPE")))))
  (if (not ss) (progn (princ "\nNenhum cano (pipe) no desenho.") (exit)))
  (setq *BB:DEBUG* nil i 0)
  (repeat (sslength ss)
    (if (setq c (bb:ler-cano (ssname ss i))) (setq canos (cons c canos)))
    (setq i (1+ i)))
  (setq *BB:DEBUG* dbg)
  (if (not canos) (progn (princ "\nNenhum cano legivel.") (exit)))
  (setq grupos (bb:agrupar (reverse canos)))
  (vla-StartUndoMark doc)
  (foreach g grupos
    (setq n (1+ n))
    (princ (strcat "\nBueiro " (itoa n) ":"))
    (bb:cogo-bueiro (car (bb:orientar g))))   ; canos no mesmo sentido
  (vla-EndUndoMark doc)
  (princ (strcat "\nConcluido: " (itoa (length grupos)) " bueiro(s). (U desfaz)"))
  (princ))

;;; ===================== GRADE DO PERFIL (BBGRADE) ======================
;;; Para cada Profile View (um por um ou todos):
;;;  1) tira as bands (faixas de dados embaixo/em cima do perfil);
;;;  2) ajusta a faixa de cotas da grade ("user specified"):
;;;     - EMBAIXO: face externa INFERIOR do tubo no eixo da rodovia - 5 m
;;;     - EM CIMA: ponto mais alto dos perfis (greide) + 1 m
;;;     Sem bueiro/eixo no perfil: ponto mais baixo dos perfis - 1 m.
(setq *BB:GRADE-BANDS*     T)     ; T = tira as bands
(setq *BB:GRADE-FOLGA-BUE* 5.0)   ; m ABAIXO da face externa inferior do tubo no eixo
(setq *BB:GRADE-FOLGA-SUP* 1.0)   ; m acima do ponto mais alto dos perfis
(setq *BB:GRADE-FOLGA-INF* 1.0)   ; sem bueiro: m abaixo do ponto mais baixo dos perfis
(setq *BB:GRADE-ARRED*     1.0)   ; arredonda as cotas da grade para multiplos disto

(defun bb:arred-baixo (v m) (* m (fix (if (< v 0) (- (/ v m) 0.999999) (/ v m)))))
(defun bb:arred-cima  (v m) (- (bb:arred-baixo (- v) m)))

;;; Grava numero/inteiro na propriedade NM (API .NET, depois COM). T se gravou.
(defun bb:pv-grava (pv nm v / en)
  (setq en (vlax-vla-object->ename pv))
  (or (not (vl-catch-all-error-p (vl-catch-all-apply 'setpropertyvalue (list en nm v))))
      (not (vl-catch-all-error-p (vl-catch-all-apply 'vlax-put-property (list pv nm v))))))

;;; (zmin zmax) dos perfis do alinhamento AL entre as estacas S0 e S1
(defun bb:pv-faixa-perfis (al s0 s1 / profs n k sta el zmin zmax)
  (if (= (type (setq profs (bb:try al 'Profiles))) 'VLA-OBJECT)
    (vlax-for p profs
      (setq n 60 k 0)
      (repeat (1+ n)
        (setq sta (+ s0 (* (- s1 s0) (/ k (float n))))
              k   (1+ k)
              el  (vl-catch-all-apply 'vlax-invoke-method (list p 'ElevationAt sta)))
        (if (vl-catch-all-error-p el)
          (setq el (vl-catch-all-apply 'vlax-get-property (list p 'ElevationAt sta))))
        (if (and (not (vl-catch-all-error-p el)) (numberp (setq el (bb:var->lisp el))))
          (setq zmin (if zmin (min zmin el) el)
                zmax (if zmax (max zmax el) el))))))
  (if zmin (list zmin zmax)))

;;; Face externa INFERIOR do tubo no eixo da rodovia, do bueiro deste
;;; perfil (o mais baixo, se houver mais de um). Sem cruzamento com o eixo,
;;; usa a ponta mais baixa do bueiro. nil se nenhum bueiro estiver no perfil.
(defun bb:pv-fundo-bueiros (al s0 s1 grupos / z zi canos pa pb xr L tt za zb c hh)
  (foreach g grupos
    (if (bb:perfil-combina al s0 s1 g)
      (progn
        (setq canos (car (bb:orientar g))          ; todos no mesmo sentido
              pa (bb:media (mapcar 'cadr canos))
              pb (bb:media (mapcar 'caddr canos))
              c  (car canos)
              hh (if (and (= (nth 4 c) "CC") (numberp (nth 5 c))) (nth 5 c) (nth 3 c))
              ;; cota do centro dos canos nas pontas (media)
              za (/ (apply '+ (mapcar '(lambda (k) (bb:z-eixo k (nth 1 k))) canos)) (float (length canos)))
              zb (/ (apply '+ (mapcar '(lambda (k) (bb:z-eixo k (nth 2 k))) canos)) (float (length canos))))
        (if (setq xr (bb:eixo-cruza al pa pb))
          (setq L  (bb:d2 pa pb)
                tt (if (> L 1e-9) (/ (bb:d2 pa (car xr)) L) 0.0)
                zi (+ za (* tt (- zb za))))
          (setq zi (min za zb)))
        ;; centro - meio diametro - parede = face externa inferior
        (setq zi (- zi (/ hh 2.0) (bb:parede-cano c 0.0 hh))
              z  (if z (min z zi) zi)))))
  z)

;;; Tenta tirar as bands do Profile View pela API COM. T se conseguiu.
(defun bb:pv-tira-bands (pv / ok col n)
  (foreach nm '(Bands BottomBands TopBands BandItems BottomBandItems TopBandItems)
    (if (= (type (setq col (bb:try pv nm))) 'VLA-OBJECT)
      (cond
        ((not (vl-catch-all-error-p (vl-catch-all-apply 'vlax-invoke-method (list col 'Clear))))
         (setq ok T))
        ((not (vl-catch-all-error-p (vl-catch-all-apply 'vlax-invoke-method (list col 'RemoveAll))))
         (setq ok T))
        ((numberp (setq n (bb:try col 'Count)))
         (repeat n
           (if (not (vl-catch-all-error-p
                      (vl-catch-all-apply 'vlax-invoke-method (list col 'Remove 0))))
             (setq ok T)))))))
  ok)

;;; Ajusta um Profile View. Devolve (bands-ok grade-ok).
(defun bb:pv-ajusta (pv en grupos / al s0 s1 fx zb zmin zmax bok gok e0 e1 a)
  (setq al (bb:pv-al-auto pv en)
        s0 (bb:try pv 'StationStart)
        s1 (bb:try pv 'StationEnd)
        a  *BB:GRADE-ARRED*)
  ;; 1) bands
  (if *BB:GRADE-BANDS* (setq bok (bb:pv-tira-bands pv)))
  ;; 2) faixa de cotas
  (if (and al (numberp s0) (numberp s1)
           (setq fx (bb:pv-faixa-perfis al s0 s1)))
    (progn
      ;; embaixo: 5 m abaixo da face externa inferior do tubo no eixo
      ;; (sem bueiro no perfil: 1 m abaixo do perfil mais baixo)
      (setq zmax (+ (cadr fx) *BB:GRADE-FOLGA-SUP*)
            zmin (if (setq zb (bb:pv-fundo-bueiros al s0 s1 grupos))
                   (- zb *BB:GRADE-FOLGA-BUE*)
                   (- (car fx) *BB:GRADE-FOLGA-INF*)))
      (setq zmin (bb:arred-baixo zmin a)
            zmax (bb:arred-cima  zmax a))
      ;; modo "User specified" + cotas. O valor do modo muda conforme a
      ;; versao do Civil 3D: tenta 1, 0 e 2 e confere lendo de volta.
      ;; Min/Max gravados 2x para nao travar quando a faixa nova nao cruza
      ;; a antiga (min novo > max atual).
      (foreach md '(1 0 2)
        (if (not gok)
          (progn
            (foreach nm '("ElevationRangeMode" "ElevRangeMode") (bb:pv-grava pv nm md))
            (repeat 2
              (bb:pv-grava pv "ElevationMin" zmin)
              (bb:pv-grava pv "ElevationMax" zmax))
            (vl-catch-all-apply 'vla-Update (list pv))
            (setq e0  (cond ((numberp (bb:gpv en "ElevationMin")) (bb:gpv en "ElevationMin"))
                            ((bb:try pv 'ElevationMin)))
                  e1  (cond ((numberp (bb:gpv en "ElevationMax")) (bb:gpv en "ElevationMax"))
                            ((bb:try pv 'ElevationMax)))
                  gok (and (numberp e0) (numberp e1) (equal e0 zmin 0.01) (equal e1 zmax 0.01))))))
      (princ (strcat "\n  \"" (bb:nome pv en) "\": grade " (rtos zmin 2 2) " a " (rtos zmax 2 2)
                     (if gok
                       " OK"
                       (strcat " (NAO aplicou: ficou "
                               (if (numberp e0) (rtos e0 2 2) "?") " a "
                               (if (numberp e1) (rtos e1 2 2) "?")
                               ", modo " (vl-princ-to-string (bb:gpv en "ElevationRangeMode")) ")"))
                     (cond ((not *BB:GRADE-BANDS*) "")
                           (bok " | bands retiradas")
                           (T " | bands: nao consegui tirar")))))
    (princ (strcat "\n  \"" (bb:nome pv en) "\": sem alinhamento/perfis - ignorado.")))
  (list bok gok))

(defun c:BBGRADE (/ *error* doc dbg o p ss ssp i c canos grupos pv en r nb ng tot)
  (defun *error* (msg)
    (setq *BB:DEBUG* dbg)
    (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg)))
    (princ))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        dbg *BB:DEBUG* *bb:als* nil nb 0 ng 0)
  (initget "Selecionar Todos")
  (setq o (getkword "\nAjustar grade/bands de [Selecionar perfis/Todos os perfis] <Selecionar>: "))
  (if (= o "Todos")
    (setq ss (ssget "_X" '((0 . "AECC_PROFILE_VIEW"))))
    ;; um por um: clique em qualquer lugar DENTRO da grade de cada perfil
    (progn
      (setq ss (ssadd))
      (while (setq p (getpoint "\nClique DENTRO da grade de um Profile View <ENTER = terminar>: "))
        (if (setq pv (bb:pv-no-ponto (trans p 1 0)))
          (progn
            (ssadd (vlax-vla-object->ename pv) ss)
            (princ (strcat "  -> \"" (bb:nome pv (vlax-vla-object->ename pv)) "\" ("
                           (itoa (sslength ss)) " escolhido(s))")))
          (princ "  -> nenhum Profile View aqui.")))
      (if (= (sslength ss) 0) (setq ss nil))))
  (if (not ss) (progn (princ "\nNenhum Profile View.") (exit)))
  ;; bueiros (para a grade descer ate o fundo das bocas)
  (if (setq ssp (ssget "_X" '((0 . "AECC_PIPE"))))
    (progn
      (setq *BB:DEBUG* nil i 0)
      (repeat (sslength ssp)
        (if (setq c (bb:ler-cano (ssname ssp i))) (setq canos (cons c canos)))
        (setq i (1+ i)))
      (setq *BB:DEBUG* dbg
            grupos (if canos (bb:agrupar (reverse canos))))))
  (vla-StartUndoMark doc)
  (setq i 0 tot (sslength ss))
  (repeat tot
    (setq en (ssname ss i)
          pv (vlax-ename->vla-object en)
          i  (1+ i)
          r  (bb:pv-ajusta pv en grupos))
    (if (car r) (setq nb (1+ nb)))
    (if (cadr r) (setq ng (1+ ng))))
  (vla-EndUndoMark doc)
  (princ (strcat "\nConcluido: " (itoa tot) " perfil(is); grade ajustada em " (itoa ng)
                 (if *BB:GRADE-BANDS* (strcat "; bands retiradas em " (itoa nb)) "")
                 ". (U desfaz)"))
  (if (or (< ng tot) (and *BB:GRADE-BANDS* (< nb tot)))
    (princ "\nOnde falhou: rode BBPVDIAG num desses perfis e me mande o texto (F2)."))
  (princ))

;;; Diagnostico do Profile View (para ajustar o BBGRADE se falhar)
(defun c:BBPVDIAG (/ e o b p v)
  ;; clique em qualquer lugar DENTRO da grade (nao precisa acertar a linha)
  (if (and (setq p (getpoint "\nClique DENTRO da grade do Profile View: "))
           (setq o (bb:pv-no-ponto (trans p 1 0))))
    (progn
      (setq e (vlax-vla-object->ename o))
      (princ (strcat "\nTipo: " (cdr (assoc 0 (entget e))) "  |  " (bb:nome o e)))
      (princ "\n--- RESUMO (o que mais importa) ---")
      (foreach nm '("ElevationRangeMode" "ElevRangeMode" "ElevationMin" "ElevationMax"
                    "StationRangeMode" "StationStart" "StationEnd" "Bands" "BandSet")
        (setq v (vl-catch-all-apply 'getpropertyvalue (list e nm)))
        (princ (strcat "\n  " nm " = "
                       (if (vl-catch-all-error-p v) "(nao existe)" (vl-princ-to-string v)))))
      (princ "\n--- dumpallproperties ---")
      (vl-catch-all-apply 'dumpallproperties (list e))
      (princ "\n--- vlax-dump-object ---")
      (vl-catch-all-apply 'vlax-dump-object (list o T))
      (foreach nm '(Bands BottomBands TopBands BandItems)
        (if (= (type (setq b (bb:try o nm))) 'VLA-OBJECT)
          (progn
            (princ (strcat "\n--- " (vl-princ-to-string nm) " ---"))
            (vl-catch-all-apply 'vlax-dump-object (list b T)))))
      (textscr))
    (princ "\nNenhum Profile View nesse ponto."))
  (princ))

;;; ===================== PLANILHA (BBPLANILHA) ==========================
;;; Uma linha por bueiro, ordenada pela estaca do eixo:
;;;  alinhamento do bueiro | tipo | D | eixo | estaca no eixo (texto e m) |
;;;  cota montante | cota jusante (geratriz inferior interna) |
;;;  altura de aterro (a gravada na pipe pela LISP) | L (3 casas) |
;;;  montante e jusante a partir do eixo (sem casas)
;;; Grava .xlsx pelo Excel; sem Excel, grava .csv (abre no Excel).

;;; Estaca no formato do alinhamento (ex.: 13+511.120)
(defun bb:estaca-txt (al sta / r km m s)
  (setq r (vl-catch-all-apply 'vlax-invoke-method (list al 'GetStationStringWithEquations sta)))
  (if (and (not (vl-catch-all-error-p r)) (= (type (setq r (bb:var->lisp r))) 'STR) (/= r ""))
    r
    (progn                                    ; padrao km+metros
      (setq km (fix (/ sta 1000.0))
            m  (- sta (* km 1000.0))
            s  (rtos m 2 3))
      (while (< (strlen (substr s 1 (vl-string-search "." s))) 3) (setq s (strcat "0" s)))
      (strcat (itoa km) "+" s))))

;;; Altura de aterro gravada na pipe (nil se nao houver)
(defun bb:aterro-ler (obj / en v)
  (setq en (vlax-vla-object->ename obj))
  (foreach nm (if *bb:aterro-nome* (cons *bb:aterro-nome* *BB:ATERRO-PROP*) *BB:ATERRO-PROP*)
    (if (not (numberp v))
      (setq v (cond ((numberp (bb:gpv en nm)) (bb:gpv en nm)) ((bb:try obj nm))))))
  (if (numberp v) v))

;;; Alinhamento ao longo do bueiro G (o do perfil dele), exceto EIXO
(defun bb:al-do-bueiro (g eixo / r)
  (foreach x *bb:als*
    (if (and (not r)
             (not (and eixo (equal (vlax-vla-object->ename (cdr x)) (vlax-vla-object->ename eixo))))
             (bb:perfil-combina (cdr x) nil nil g))
      (setq r (cdr x))))
  r)

;;; Dados de um bueiro -> lista com os valores da linha (ou nil)
;;; Tipo de obra do bueiro (lista de canos): (codigo D hh)
;;; codigo = BSTC, BDCC... ; D = diametro/largura ; hh = altura interna
(defun bb:tipo-obra (canos / n c shp)
  (setq n   (length canos)
        c   (car canos)
        shp (if (member "CC" (mapcar '(lambda (k) (nth 4 k)) canos)) "CC" "TC"))
  (list (if (<= n 3) (strcat "B" (nth (1- n) '("S" "D" "T")) shp) (strcat (itoa n) " canos"))
        (apply 'max (mapcar 'cadddr canos))
        (if (and (= (nth 4 c) "CC") (numberp (nth 5 c))) (nth 5 c) (nth 3 c))))

(defun bb:linha-bueiro (g / res canos dz PM PJ c n D hh tp code xr x eixo sta al zm zj L at lado
                            est em tt zc zcg)
  (setq n (length g) res (bb:orientar g) canos (car res) dz (cadr res))
  (if (< dz (- *BB:TOL-Z*)) (setq canos (mapcar 'bb:inverter canos)))   ; inicio = montante
  (setq PM  (bb:media (mapcar 'cadr canos))
        PJ  (bb:media (mapcar 'caddr canos))
        c   (car canos)
        tp  (bb:tipo-obra canos)
        code (car tp)
        D   (cadr tp)
        hh  (caddr tp)
        ;; geratriz inferior interna (media dos canos)
        zm  (- (/ (apply '+ (mapcar '(lambda (k) (bb:z-eixo k (nth 1 k))) canos)) (float n)) (/ hh 2.0))
        zj  (- (/ (apply '+ (mapcar '(lambda (k) (bb:z-eixo k (nth 2 k))) canos)) (float n)) (/ hh 2.0))
        ;; L = comprimento 2D da pipe (media)
        L   (/ (apply '+ (mapcar '(lambda (k) (cond ((bb:num (list (bb:prop (car k) 'Length2D)
                                                                  (bb:gpv (vlax-vla-object->ename (car k)) "Length2D"))))
                                                    ((bb:d2 (nth 1 k) (nth 2 k)))))
                                 canos))
               (float n))
        at  (bb:aterro-ler (car c))
        xr  (bb:eixo-cruza nil PM PJ))
  (if xr (setq x (car xr) eixo (cadr xr) sta (car (bb:al-sta eixo x))
               ;; lado da montante em relacao ao eixo (sentido das estacas):
               ;; afastamento + = direita, - = esquerda
               lado (cadr (bb:al-sta eixo PM))))
  (setq al (bb:al-do-bueiro g eixo))
  ;; estaca de 20 m: inteiro + metros (2 casas; 19.999 -> proxima estaca)
  (if sta
    (progn
      (setq est (fix (/ (+ sta 1e-9) *BB:ESTACA-INT*))
            em  (atof (rtos (- sta (* est *BB:ESTACA-INT*)) 2 2)))
      (if (>= em (- *BB:ESTACA-INT* 0.001)) (setq est (1+ est) em 0.0))))
  ;; cota do COGO point no eixo (mesma conta do bb:cogo-bueiro)
  (if x
    (setq tt (if (> (bb:d2 PM PJ) 1e-9) (/ (bb:d2 PM x) (bb:d2 PM PJ)) 0.0)
          zc (+ zm (/ hh 2.0) (* tt (- zj zm)))                    ; centro no eixo
          zcg (cond ((= *BB:COGO-FACE* "SUP") (+ zc (/ hh 2.0)))
                    ((= *BB:COGO-FACE* "EXT") (+ zc (/ hh 2.0) (bb:parede-cano c 0.0 hh)))
                    (T (- zc (/ hh 2.0))))))
  (list
    (if al (bb:nome al (vlax-vla-object->ename al)) "(sem alinhamento)")   ; 0
    code                                                                   ; 1
    D                                                                      ; 2
    (if eixo (bb:nome eixo (vlax-vla-object->ename eixo)) "(eixo nao cruza)") ; 3
    est                                                                    ; 4 estaca
    (if sta "+" "")                                                        ; 5
    em                                                                     ; 6 metros
    sta                                                                    ; 7 estaca (m)
    zm zj                                                                  ; 8 9
    zcg                                                                    ; 10 cota COGO
    at                                                                     ; 11
    L                                                                      ; 12
    (if x (car  (bb:repartir (bb:d2 x PM) (bb:d2 x PJ) L)))               ; 13 montante
    (if x (cadr (bb:repartir (bb:d2 x PM) (bb:d2 x PJ) L)))               ; 14 jusante
    (cond ((not (numberp lado)) "")                                        ; 15 lado montante
          ((> lado 0.0) "D")
          (T "E"))
    (if sta (bb:esconsidade eixo sta PM PJ))                               ; 16 esconsidade
    (if (<= (abs dz) *BB:TOL-Z*) "fluxo indefinido (cotas iguais)" "")))   ; 17

;;; Ponto (x y) do alinhamento AL na estaca STA (afastamento 0)
(defun bb:al-pt (al sta / r e n)
  (setq r (vl-catch-all-apply 'vlax-invoke-method (list al 'PointLocation sta 0.0 'e 'n)))
  (if (and (not (vl-catch-all-error-p r))
           (numberp (setq e (bb:var->lisp e)))
           (numberp (setq n (bb:var->lisp n))))
    (list e n 0.0)))

;;; Esconsidade do bueiro (graus, valor absoluto): angulo entre o corpo do
;;; bueiro e a PERPENDICULAR ao eixo na estaca do cruzamento.
;;; 0 = bueiro perpendicular ao eixo. Arredondada de *BB:ESCONS-PASSO* em
;;; *BB:ESCONS-PASSO* graus (0, 5, 10, 15...).
(defun bb:esconsidade (eixo sta PM PJ / a b tg u ct ang)
  (if (and (setq a (bb:al-pt eixo (- sta 0.5)))
           (setq b (bb:al-pt eixo (+ sta 0.5)))
           (setq tg (bb:unit2 (bb:v- b a)))           ; direcao do eixo
           (setq u  (bb:unit2 (bb:v- PJ PM))))        ; direcao do bueiro
    (progn
      ;; angulo entre bueiro e eixo (0..90); esconsidade = 90 - isso
      (setq ct  (min 1.0 (abs (bb:dot2 u tg)))
            ang (- 90.0 (* (/ 180.0 pi) (atan (sqrt (max 0.0 (- 1.0 (* ct ct)))) ct))))
      (if *BB:ESCONS-PASSO*
        (* *BB:ESCONS-PASSO* (fix (+ (/ ang *BB:ESCONS-PASSO*) 0.5)))
        ang))))

(setq *BB:ESTACA-INT* 20.0)   ; intervalo da estaca (m)
(setq *bb:plan-cab* '("Alinhamento do bueiro" "Tipo" "D (m)" "Eixo"
                      "Estaca no eixo" "" ""
                      "Estaca (m)" "Cota montante" "Cota jusante" "Cota COGO no eixo"
                      "Altura de aterro (m)" "L (m)" "Montante (m)" "Jusante (m)"
                      "Lado montante (D/E)" "Esconsidade (graus)" "Obs"))
;;; casas decimais de cada coluna (nil = texto)
(setq *bb:plan-casas* '(nil nil 2 nil 0 nil 2 3 3 3 3 2 3 0 0 nil 0 nil))
;;; esconsidade arredondada de quantos em quantos graus (nil = valor exato)
(setq *BB:ESCONS-PASSO* 5)
(setq *bb:plan-col-sta*    7)   ; coluna da estaca em metros (ordenacao)
(setq *bb:plan-col-aterro* 11)  ; coluna da altura de aterro

;;; Valor arredondado (numero) ou texto
(defun bb:plan-val (v casas)
  (cond ((null v) "")
        ((and casas (numberp v)) (if (= casas 0) (fix (+ v (if (< v 0) -0.5 0.5))) (atof (rtos v 2 casas))))
        (T v)))

;;; Planilha pelo Excel (COM). T se salvou.
(defun bb:plan-excel (linhas arq / xl wb sh cells r k v col fmt rng ok)
  (setq xl (vl-catch-all-apply 'vlax-get-or-create-object (list "Excel.Application")))
  (if (and xl (not (vl-catch-all-error-p xl)))
    (progn
      (vlax-put-property xl 'DisplayAlerts :vlax-false)
      (setq wb    (vlax-invoke-method (vlax-get-property xl 'Workbooks) 'Add)
            sh    (vlax-get-property wb 'ActiveSheet)
            cells (vlax-get-property sh 'Cells))
      (vl-catch-all-apply 'vlax-put-property (list sh 'Name "Bueiros"))
      ;; formato das colunas (antes de escrever: estaca como texto)
      (setq k 0)
      (foreach casas *bb:plan-casas*
        (setq col (chr (+ 65 k))
              fmt (cond ((null casas) "@") ((= casas 0) "0") (T (strcat "0." (substr "000000" 1 casas))))
              rng (vlax-get-property sh 'Range (strcat col ":" col))
              k   (1+ k))
        (vl-catch-all-apply 'vlax-put-property (list rng 'NumberFormat fmt)))
      ;; cabecalho + linhas
      (setq r 1)
      (foreach lin (cons *bb:plan-cab* linhas)
        (setq k 0)
        (foreach v lin
          (if (/= v "")
            (vl-catch-all-apply 'vlax-put-property
              (list (vlax-variant-value (vlax-get-property cells 'Item r (1+ k))) 'Value2 v)))
          (setq k (1+ k)))
        (setq r (1+ r)))
      (setq rng (vlax-get-property sh 'Range "A1:R1"))
      (vl-catch-all-apply 'vlax-put-property (list (vlax-get-property rng 'Font) 'Bold :vlax-true))
      ;; "Estaca no eixo" sobre as 3 colunas (estaca | + | metros), centralizado
      (setq rng (vlax-get-property sh 'Range "E1:G1"))
      (vl-catch-all-apply 'vlax-invoke-method (list rng 'Merge))
      (vl-catch-all-apply 'vlax-put-property (list rng 'HorizontalAlignment -4108))
      (vl-catch-all-apply 'vlax-put-property
        (list (vlax-get-property sh 'Range "F:F") 'HorizontalAlignment -4108))
      (vl-catch-all-apply 'vlax-invoke-method
        (list (vlax-get-property (vlax-get-property sh 'UsedRange) 'Columns) 'AutoFit))
      (setq ok (not (vl-catch-all-error-p (vl-catch-all-apply 'vlax-invoke-method (list wb 'SaveAs arq 51)))))
      (vlax-put-property xl 'DisplayAlerts :vlax-true)
      (vlax-put-property xl 'Visible :vlax-true)          ; abre para voce ver
      (foreach o (list cells sh wb xl) (vl-catch-all-apply 'vlax-release-object (list o)))
      ok)))

;;; Planilha CSV (; e virgula decimal - Excel em portugues). T se salvou.
(defun bb:plan-csv (linhas arq / f k s)
  (if (setq f (open arq "w"))
    (progn
      (foreach lin (cons *bb:plan-cab* linhas)
        (setq k 0 s "")
        (foreach v lin
          (setq s (strcat s (if (> k 0) ";" "")
                          (cond ((= (type v) 'STR) v)
                                ((= (type v) 'INT) (itoa v))
                                ((numberp v) (vl-string-translate "." "," (rtos v 2 (nth k *bb:plan-casas*))))
                                (T "")))
                k (1+ k)))
        (write-line s f))
      (close f)
      T)))

(defun c:BBPLANILHA (/ *error* dbg ss i c canos grupos linhas arq dz ok)
  (defun *error* (msg)
    (setq *BB:DEBUG* dbg)
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg)))
    (princ))
  (setq dbg *BB:DEBUG* *bb:als* nil)
  (princ "\nSelecione os canos dos bueiros <ENTER = todos do desenho>: ")
  (if (not (setq ss (ssget '((0 . "AECC_PIPE")))))
    (setq ss (ssget "_X" '((0 . "AECC_PIPE")))))
  (if (not ss) (progn (princ "\nNenhum cano (pipe) no desenho.") (exit)))
  (setq *BB:DEBUG* nil i 0)
  (repeat (sslength ss)
    (if (setq c (bb:ler-cano (ssname ss i))) (setq canos (cons c canos)))
    (setq i (1+ i)))
  (setq *BB:DEBUG* dbg)
  (if (not canos) (progn (princ "\nNenhum cano legivel.") (exit)))
  (setq grupos (bb:agrupar (reverse canos)))
  (if (not *bb:als*) (setq *bb:als* (bb:alinhamentos)))
  ;; linhas, ordenadas pela estaca do eixo
  (foreach g grupos
    (if (setq c (bb:linha-bueiro g)) (setq linhas (cons c linhas))))
  (setq linhas (vl-sort linhas '(lambda (a b) (< (if (numberp (nth *bb:plan-col-sta* a)) (nth *bb:plan-col-sta* a) 1e99)
                                                 (if (numberp (nth *bb:plan-col-sta* b)) (nth *bb:plan-col-sta* b) 1e99))))
        linhas (mapcar '(lambda (lin) (mapcar 'bb:plan-val lin *bb:plan-casas*)) linhas))
  ;; onde salvar
  (setq arq (getfiled "Salvar planilha dos bueiros"
                      (strcat (getvar "DWGPREFIX") (vl-filename-base (getvar "DWGNAME")) "_BUEIROS.xlsx")
                      "xlsx" 1))
  (if (not arq) (progn (princ "\nCancelado.") (exit)))
  (cond
    ((setq ok (bb:plan-excel linhas arq))
     (princ (strcat "\nPlanilha salva: " arq)))
    ((bb:plan-csv linhas (setq arq (strcat (vl-filename-directory arq) "\\"
                                           (vl-filename-base arq) ".csv")))
     (princ (strcat "\nExcel nao disponivel; salvei em CSV (abre no Excel): " arq)))
    (T (princ (strcat "\nNao consegui salvar em " arq))))
  (princ (strcat "\n" (itoa (length linhas)) " bueiro(s) na planilha."
                 (if (vl-some '(lambda (l) (= (nth *bb:plan-col-aterro* l) "")) linhas)
                   "\n(Altura de aterro vazia = bueiro sem aterro gravado: rode BBATERRO antes.)"
                   "")))
  (princ))

;;; Esquece o perfil de greide escolhido (a proxima execucao pergunta de novo)
(defun c:BBGREIDE ()
  (setq *bb:greide-padrao* nil *bb:greide-nome-ant* nil)
  (princ (strcat "\nEscolha do greide apagada. O proximo comando pergunta de novo"
                 (if (/= *BB:GREIDE-NOME* "")
                   (strcat " (ATENCAO: *BB:GREIDE-NOME* = \"" *BB:GREIDE-NOME* "\" continua valendo).")
                   ".")))
  (princ))

;;; Apaga o que a LISP criou nos bueiros selecionados (sem refazer nada).
(defun c:BBLIMPA (/ doc o w tipos ondes ss i hs n)
  (initget "Tudo Bocas Dissipador Pontos")
  (setq o (getkword "\nApagar [Tudo/Bocas/Dissipador/Pontos cogo] <Tudo>: "))
  (initget "Planta pErfil Ambos")
  (setq w (getkword "\nOnde [Planta/pErfil/Ambos] <Ambos>: "))
  (setq tipos (cond ((= o "Bocas") '("B")) ((= o "Dissipador") '("D")) ((= o "Pontos") '("C"))
                    (T '("B" "D" "C")))
        ondes (cond ((= w "Planta") '("PL")) ((= w "pErfil") '("PF")) (T '("PL" "PF"))))
  (princ "\nSelecione os canos dos bueiros <ENTER = todos do desenho>: ")
  (if (not (setq ss (ssget '((0 . "AECC_PIPE")))))
    (setq ss (ssget "_X" '((0 . "AECC_PIPE")))))
  (if (not ss)
    (princ "\nNenhum cano (pipe) no desenho.")
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq hs (cons (vla-get-Handle (vlax-ename->vla-object (ssname ss i))) hs)
              i  (1+ i)))
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (vla-StartUndoMark doc)
      (setq n (bb:limpar hs tipos ondes))
      ;; COGO points sem etiqueta (feitos pela 5_18 antiga) sobre estes canos
      (if (and (member "C" tipos) (member "PL" ondes))
        (setq n (+ n (bb:cogo-limpar-canos ss *BB:COGO-DESC*))))
      (vla-EndUndoMark doc)
      (princ (strcat "\n" (itoa n) " objeto(s) apagado(s). (U desfaz)"
                     (if (= n 0)
                       "\n(Objetos feitos por versoes antigas da LISP nao tem etiqueta: apague-os a mao uma vez.)"
                       "")))))
  (princ))

;;; --------------------------------------------------------------------
;;; BBLIMPAANTIGO: apaga o que VERSOES ANTIGAS da LISP fizeram (sem
;;; etiqueta). Procura, perto dos bueiros selecionados:
;;;   - blocos: bocas (*BB:BLK-BOCA*), dissipador antigo (*BB:BLK-DISSIP*),
;;;     DEB_* (dissipador DNIT) e BB_CORTE* (bocas em corte no perfil)
;;;   - textos: MONTANTE, JUSANTE, DEB ...
;;;   - cotas: na layer *BB:LAYER-TXT* com os estilos de cota da LISP
;;; Planta: ate *BB:ANTIGO-RAIO* do eixo do bueiro.
;;; Perfil: na regiao do bueiro em cada Profile View dele.
;;; Mostra tudo destacado e so apaga se voce confirmar.
(setq *BB:ANTIGO-RAIO* 12.0)   ; planta: distancia maxima ao bueiro (m)
(setq *BB:ANTIGO-EST*  12.0)   ; perfil: estacas alem das pontas do bueiro (m)
(setq *BB:ANTIGO-ZINF*  5.0)   ; perfil: abaixo da cota mais baixa do cano (m)
(setq *BB:ANTIGO-ZSUP*  3.0)   ; perfil: acima do topo do cano (m)

;;; Sem etiqueta = feito por versao antiga (ou a mao)
(defun bb:sem-tag-p (e) (not (assoc -3 (entget e '("BOCAS_BUEIRO")))))

;;; Pontos de referencia de um objeto (insercao / defpoints da cota)
(defun bb:pts-ent (ed)
  (if (= (cdr (assoc 0 ed)) "DIMENSION")
    (vl-remove nil (list (cdr (assoc 13 ed)) (cdr (assoc 14 ed))))
    (list (cdr (assoc 10 ed)))))

;;; Candidatos: ((ename pontos) ...) - blocos, textos e cotas da LISP sem etiqueta
(defun bb:antigo-cands (/ pat ss i e ed lst sty lay)
  ;; bocas em planta das versoes antigas (bloco V3 do cadastro, BNAA/BNAR
  ;; do template) alem do bloco atual
  (setq pat (strcat "BB_CORTE*,DEB_*,BOCA_CADASTRO_PLANTA*,BOCA_DNIT_PLANTA*,BOCA_BNAA_PLANTA*,BOCA_BNAR_PLANTA*"
                    (if (and *BB:BLK-BOCA* (/= *BB:BLK-BOCA* "")) (strcat "," *BB:BLK-BOCA*) "")
                    (if (and *BB:BLK-DISSIP* (/= *BB:BLK-DISSIP* "")) (strcat "," *BB:BLK-DISSIP*) "")))
  ;; blocos (dinamicos aparecem como *U..: confere o nome efetivo)
  (if (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 (strcat pat ",`*U*")))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq e (ssname ss i) i (1+ i))
        (if (and (bb:sem-tag-p e)
                 (wcmatch (strcase (vla-get-EffectiveName (vlax-ename->vla-object e))) (strcase pat)))
          (setq lst (cons (list e (bb:pts-ent (entget e))) lst))))))
  ;; textos
  (if (setq ss (ssget "_X" '((0 . "TEXT") (1 . "MONTANTE,JUSANTE,DEB *"))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq e (ssname ss i) i (1+ i))
        (if (bb:sem-tag-p e) (setq lst (cons (list e (bb:pts-ent (entget e))) lst))))))
  ;; cotas: layer da LISP e estilos da LISP
  (setq sty (vl-remove nil (list (bb:dimstyle-acha *BB:COTA-ESTILO*)
                                 (bb:dimstyle-acha *BB:COTA-ESTILO-PF*)
                                 (bb:dimstyle-acha *BB:COTA-ESTILO-REC*)
                                 (bb:dimstyle-acha *BB:COTA-ESTILO-DPL*)))
        lay (if (and *BB:LAYER-TXT* (/= *BB:LAYER-TXT* "")) *BB:LAYER-TXT*))
  (if (and (or lay sty)
           (setq ss (ssget "_X" (if lay (list '(0 . "DIMENSION") (cons 8 lay)) '((0 . "DIMENSION"))))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq e (ssname ss i) i (1+ i) ed (entget e))
        (if (and (bb:sem-tag-p e)
                 (or (not sty) (member (cdr (assoc 3 ed)) sty)
                     (= (strcase (cdr (assoc 3 ed))) "STANDARD")))  ; sem estilo: ficou o corrente
          (setq lst (cons (list e (bb:pts-ent ed)) lst))))))
  lst)

;;; Regioes de busca de um bueiro G: ((SEG A B raio) (BOX x0 y0 x1 y1) ...)
(defun bb:antigo-regioes (g pvs / A B D regs sA sB s0 s1 z0 z1 e0 e1 ps xs ys)
  (setq A (bb:media (mapcar 'cadr g))
        B (bb:media (mapcar 'caddr g))
        D (apply 'max (mapcar 'cadddr g))
        regs (list (list 'SEG A B (+ *BB:ANTIGO-RAIO* (* (length g) D)))))
  (foreach v pvs
    (if (and (bb:perfil-combina (nth 1 v) (nth 2 v) (nth 3 v) g)
             (setq sA (bb:al-sta (nth 1 v) A))
             (setq sB (bb:al-sta (nth 1 v) B)))
      (progn
        (setq s0 (- (min (car sA) (car sB)) *BB:ANTIGO-EST*)
              s1 (+ (max (car sA) (car sB)) *BB:ANTIGO-EST*)
              z0 (- (min (caddr A) (caddr B)) D *BB:ANTIGO-ZINF*)
              z1 (+ (max (caddr A) (caddr B)) D *BB:ANTIGO-ZSUP*))
        ;; nao passa dos limites do Profile View (fora deles o Civil 3D da erro)
        (if (numberp (nth 2 v)) (setq s0 (max s0 (nth 2 v))))
        (if (numberp (nth 3 v)) (setq s1 (min s1 (nth 3 v))))
        (if (numberp (setq e0 (bb:try (car v) 'ElevationMin))) (setq z0 (max z0 e0)))
        (if (numberp (setq e1 (bb:try (car v) 'ElevationMax))) (setq z1 (min z1 e1)))
        (setq ps (vl-remove nil (list (bb:pv-xy (car v) s0 z0) (bb:pv-xy (car v) s1 z0)
                                      (bb:pv-xy (car v) s0 z1) (bb:pv-xy (car v) s1 z1))))
        (if (= (length ps) 4)
          (setq xs (mapcar 'car ps) ys (mapcar 'cadr ps)
                regs (cons (list 'BOX (apply 'min xs) (apply 'min ys) (apply 'max xs) (apply 'max ys))
                           regs))))))
  regs)

(defun bb:na-regiao (p r)
  (if (= (car r) 'SEG)
    (<= (bb:dist-seg p (nth 1 r) (nth 2 r)) (nth 3 r))
    (and (>= (car p) (nth 1 r)) (<= (car p) (nth 3 r))
         (>= (cadr p) (nth 2 r)) (<= (cadr p) (nth 4 r)))))

(defun c:BBLIMPAANTIGO (/ *error* doc dbg ss ssv i c canos grupos pvs pv al regs cands sel n k)
  (defun *error* (msg)
    (setq *BB:DEBUG* dbg)
    (vl-catch-all-apply 'sssetfirst (list nil nil))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg)))
    (princ))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        dbg *BB:DEBUG*)
  (princ "\nSelecione os canos dos bueiros feitos com a versao antiga <ENTER = todos do desenho>: ")
  (if (not (setq ss (ssget '((0 . "AECC_PIPE")))))
    (setq ss (ssget "_X" '((0 . "AECC_PIPE")))))
  (if (not ss) (progn (princ "\nNenhum cano (pipe) no desenho.") (exit)))
  ;; canos -> bueiros
  (setq *BB:DEBUG* nil i 0)
  (repeat (sslength ss)
    (if (setq c (bb:ler-cano (ssname ss i))) (setq canos (cons c canos)))
    (setq i (1+ i)))
  (setq *BB:DEBUG* dbg)
  (if (not canos) (progn (princ "\nNenhum cano legivel.") (exit)))
  (setq grupos (bb:agrupar (reverse canos)))
  ;; Profile Views visiveis com alinhamento
  (setq *bb:als* nil i 0)
  (if (setq ssv (ssget "_X" '((0 . "AECC_PROFILE_VIEW"))))
    (repeat (sslength ssv)
      (setq pv (vlax-ename->vla-object (ssname ssv i)))
      (if (and (bb:visivel pv) (setq al (bb:pv-al-auto pv (ssname ssv i))))
        (setq pvs (cons (list pv al (bb:try pv 'StationStart) (bb:try pv 'StationEnd)) pvs)))
      (setq i (1+ i))))
  ;; regioes de todos os bueiros
  (foreach g grupos (setq regs (append (bb:antigo-regioes g pvs) regs)))
  ;; candidatos dentro de alguma regiao
  (setq sel (ssadd) n 0)
  (foreach x (bb:antigo-cands)
    (if (vl-some '(lambda (p) (vl-some '(lambda (r) (bb:na-regiao p r)) regs)) (cadr x))
      (progn (ssadd (car x) sel) (setq n (1+ n)))))
  (princ (strcat "\n" (itoa (length grupos)) " bueiro(s), "
                 (itoa (- (length regs) (length grupos))) " trecho(s) de perfil; "
                 (itoa n) " objeto(s) antigo(s) encontrado(s)."))
  (if (> n 0)
    (progn
      (sssetfirst nil sel)                  ; destaca o que vai ser apagado
      (initget "Sim Nao")
      (setq k (getkword (strcat "\nApagar os " (itoa n) " objeto(s) destacado(s)? [Sim/Nao] <Nao>: ")))
      (sssetfirst nil nil)
      (if (= k "Sim")
        (progn
          (vla-StartUndoMark doc)
          (setq i 0)
          (repeat (sslength sel)
            (vl-catch-all-apply 'entdel (list (ssname sel i)))
            (setq i (1+ i)))
          (vla-EndUndoMark doc)
          (princ (strcat "\n" (itoa n) " objeto(s) apagado(s). (U desfaz)"
                         " Agora rode BBT - dai em diante a limpeza e automatica.")))
        (princ "\nNada apagado."))))
  (princ))

;;; Altura de aterro dos bueiros GRUPOS, sem desenhar nada: acha os
;;; Profile Views de cada bueiro e grava o recobrimento no eixo na pipe.
;;; Usado pelos comandos que nao passam pelo perfil (BBU, BBX planta).
(defun bb:aterro-perfis (grupos / ssv i pv al pvs sa n)
  (if *BB:ATERRO-GRAVAR*
    (progn
      (setq *bb:als* nil i 0 n 0)
      (if (setq ssv (ssget "_X" '((0 . "AECC_PROFILE_VIEW"))))
        (repeat (sslength ssv)
          (setq pv (vlax-ename->vla-object (ssname ssv i)))
          (if (and (bb:visivel pv) (setq al (bb:pv-al-auto pv (ssname ssv i))))
            (setq pvs (cons (list pv al (bb:try pv 'StationStart) (bb:try pv 'StationEnd)) pvs)))
          (setq i (1+ i))))
      (setq sa *bb:so-aterro* *bb:so-aterro* T)
      (foreach g grupos
        (foreach v pvs
          (if (and (bb:perfil-combina (nth 1 v) (nth 2 v) (nth 3 v) g)
                   (bb:perfil-grupo (nth 0 v) (nth 1 v) g))
            (setq n (1+ n)))))
      (setq *bb:so-aterro* sa)
      (princ (strcat "\nAltura de aterro: " (itoa n) " bueiro/perfil processado(s).")))))

;;; So recalcula a altura de aterro no eixo de cada bueiro e grava na
;;; pipe (*BB:ATERRO-PROP*), sem inserir bocas, dissipadores nem cotas.
;;; Rode de novo sempre que mudar o greide ou o bueiro.
(defun c:BBATERRO ()
  (bb:modo nil nil nil T)
  (setq *bb:so-aterro* T)
  (bb:tudo)
  (setq *bb:so-aterro* nil)
  (princ))

;;; Escolhe o que e onde inserir
(defun c:BBX (/ o w)
  (initget "Bocas Dissipador Tudo")
  (setq o (getkword "\nInserir [Bocas/Dissipador/Tudo] <Tudo>: "))
  (initget "Planta pErfil Ambos")
  (setq w (getkword "\nOnde [Planta/pErfil/Ambos] <Ambos>: "))
  (if (not o) (setq o "Tudo"))
  (if (not w) (setq w "Ambos"))
  (bb:modo (/= o "Dissipador") (/= o "Bocas") (/= w "pErfil") (/= w "Planta"))
  (bb:tudo))


;;; ======================= CALIBRACAO (BBCALIB) ========================
;;; Voce encaixa UM dissipador a mao numa boca de jusante (mover/girar/
;;; escalar ate ficar certo) e roda BBCALIB. O programa grava a posicao
;;; relativa dissipador x boca e repete exatamente esse encaixe em todos
;;; os bueiros, ajustando a escala pela largura de cada boca.
;;; A calibracao fica salva no Windows (vale para outros desenhos).
;;; BBCALIBLIMPA apaga a calibracao (volta a deteccao automatica).

(defun bb:rot2 (p a)
  (list (- (* (car p) (cos a)) (* (cadr p) (sin a)))
        (+ (* (car p) (sin a)) (* (cadr p) (cos a)))
        0.0)
)

;;; Face externa da boca: (ponto-medio-local largura), local = coordenadas
;;; da boca ja escaladas, sem a rotacao da referencia.
(defun bb:face-boca (refB offB / p u v ext s tm w)
  (setq u (list (cos (bb:rad offB)) (sin (bb:rad offB)))
        v (list (- (cadr u)) (car u)))
  (if (setq p (bb:pontas refB offB 1.0))
    (setq s (car p) tm (/ (+ (cadr p) (caddr p)) 2.0) w (- (caddr p) (cadr p)))
    (setq ext (bb:ext-local refB)
          s   (bb:ext-ao-longo ext offB 1.0)
          tm  0.0
          w   (bb:largura ext offB))
  )
  (list (list (+ (* s (car u)) (* tm (car v))) (+ (* s (cadr u)) (* tm (cadr v))) 0.0) w)
)

(defun bb:off-boca (refB)
  (if (numberp *BB:ROT-BOCA*) *BB:ROT-BOCA* (bb:auto-off (bb:ext-local refB)))
)

;;; Le a calibracao: (giro-relativo qx qy escala/largura escala) ou nil
(defun bb:calib-ler (/ s v)
  (if (and (setq s (getenv "BB_DISSIP_CALIB")) (/= s ""))
    (progn
      (setq v (vl-catch-all-apply 'read (list s)))
      (if (and (listp v) (= 5 (length v)) (vl-every 'numberp v)) v)
    )
  )
)

(defun bb:posicionar-calib (refD refB offB cal / f rotB MB esc rot q ptD)
  (setq f    (bb:face-boca refB offB)
        rotB (vla-get-Rotation refB)
        MB   (bb:v+ (vlax-get refB 'InsertionPoint) (bb:rot2 (car f) rotB))
        esc  (if *BB:DISSIP-ESCALAR* (* (nth 3 cal) (cadr f)) (nth 4 cal))
        rot  (+ rotB (nth 0 cal))
        q    (list (* esc (nth 1 cal)) (* esc (nth 2 cal)) 0.0)
        ptD  (bb:v- MB (bb:rot2 q rot)))
  (vla-put-Rotation refD 0.0)
  (bb:escalar refD esc)
  (vla-put-InsertionPoint refD (vlax-3d-point ptD))
  (vla-put-Rotation refD rot)
  (vla-Update refD)
  ptD
)

(defun c:BBCALIB (/ eB eD refB refD offB f rotB rotD MB escD insD q cal)
  (setq eB (entsel "\nSelecione a BOCA de jusante: "))
  (if eB (setq eD (entsel "\nSelecione o DISSIPADOR encaixado corretamente nela: ")))
  (cond
    ((not (and eB eD)) (princ "\nCancelado."))
    ((not (and (= "INSERT" (cdr (assoc 0 (entget (car eB)))))
               (= "INSERT" (cdr (assoc 0 (entget (car eD)))))))
     (princ "\nOs dois objetos precisam ser blocos."))
    (T
     (setq refB (vlax-ename->vla-object (car eB))
           refD (vlax-ename->vla-object (car eD))
           offB (bb:off-boca refB)
           f    (bb:face-boca refB offB)
           rotB (vla-get-Rotation refB)
           MB   (bb:v+ (vlax-get refB 'InsertionPoint) (bb:rot2 (car f) rotB))
           rotD (vla-get-Rotation refD)
           escD (abs (vla-get-XScaleFactor refD))
           insD (vlax-get refD 'InsertionPoint)
           q    (bb:vs (bb:rot2 (bb:v- MB insD) (- rotD)) (/ 1.0 escD))
           cal  (list (- rotD rotB) (car q) (cadr q) (/ escD (cadr f)) escD))
     (setenv "BB_DISSIP_CALIB" (vl-prin1-to-string cal))
     (princ (strcat "\nCalibracao gravada: giro relativo "
                    (angtos (- rotD rotB) 0 1) " graus, escala " (rtos escD 2 3)
                    ". Rode BBU nos outros bueiros."))
    )
  )
  (princ)
)

(defun c:BBCALIBLIMPA ()
  (setenv "BB_DISSIP_CALIB" "")
  (princ "\nCalibracao apagada. Dissipador volta ao modo automatico.")
  (princ)
)

;;; Diagnostico: mostra tudo o que o Civil 3D expoe de um cano.
;;; Rode BBDIAG, selecione 1 cano, aperte F2 e copie o texto.
(defun c:BBDIAG (/ e)
  (if (setq e (car (entsel "\nSelecione UM cano: ")))
    (progn
      (princ (strcat "\nTipo: " (cdr (assoc 0 (entget e)))))
      (princ "\n--- leitura do BOCAS_BUEIRO ---")
      (bb:ler-cano e)
      (princ "\n--- PointAtParam 0 / 1 (bruto) ---")
      (princ (vl-catch-all-apply 'vlax-get-property (list (vlax-ename->vla-object e) 'PointAtParam 0.0)))
      (princ (strcat "\nPAP 0 = " (vl-princ-to-string (bb:pap (vlax-ename->vla-object e) 0.0))))
      (princ (strcat "\nPAP 1 = " (vl-princ-to-string (bb:pap (vlax-ename->vla-object e) 1.0))))
      (princ (strcat "\nPosition = " (vl-princ-to-string (bb:obj->pt (bb:prop (vlax-ename->vla-object e) 'Position)))))
      (princ "\n--- dumpallproperties ---")
      (vl-catch-all-apply 'dumpallproperties (list e))
      (princ "\n--- vlax-dump-object ---")
      (vl-catch-all-apply 'vlax-dump-object (list (vlax-ename->vla-object e) T))
    )
  )
  (princ)
)

(princ (strcat "\nBOCAS_BUEIRO v14 carregado. Comandos: BBT (tudo), BBTB (so bocas), BBTD (so dissipadores),"
               " BBX (escolher), BBU (planta), BBP (perfil por clique), BBATERRO (aterro na label), BBLIMPA (apagar),"
               " BBLIMPAANTIGO (apagar o feito por versoes antigas), BBGREIDE (escolher o greide de novo),"
               " BBCOGO (so os COGO points no eixo), BBOBRA (tipo de obra na label), BBPLANILHA (planilha Excel), BBGRADE (bands e grade dos perfis),"
               " BBCALIB, BBCALIBLIMPA e BBDIAG."))
(princ)
