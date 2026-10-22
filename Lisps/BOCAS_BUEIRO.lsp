;;; =====================================================================
;;;  BOCAS_BUEIRO.LSP  -  Insercao automatica de bocas de bueiro (Civil 3D)
;;; ---------------------------------------------------------------------
;;;  Comando : BOCASBUEIRO   (atalho: BBU)
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
  obj
)

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
    ((and (numberp h) (> (abs (- h d)) 0.01)) "CC")
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

;;; Agrupa canos paralelos e proximos (cada grupo = um bueiro)
(defun bb:agrupar (canos / grupos r g rest u1 u2 lim)
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


;;; ======================= PROCESSA UM BUEIRO ==========================
(defun bb:processar (g idx blk / n txt res canos dz pk PM PJ D HC shp dir code
                                 refM refJ stM refD blkD dist ptD dis extB offB extD offD escD cal)
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
                (princ (strcat txt "AVISO - diametro " (rtos D 2 2)
                               " m nao padronizado; usado o estado mais proximo."))
              )
              ;; ---------- dissipador (tubular e D <= / < limite) ----------
              (setq dis "nao")
              (if (and (= shp "TC")
                       (if *BB:DISSIP-ATE-LIMITE*
                         (<= D (+ *BB:DIAM-LIMITE* 1e-6))
                         (<  D (- *BB:DIAM-LIMITE* 1e-6))))
                (if (setq blkD (bb:get-dissip))
                  (progn
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
                  (setq dis "nao (bloco indisponivel)")
                )
              )
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
  (princ "\n[BOCAS_BUEIRO v11]")
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
  (if (> falhas 0)    (princ (strcat "\n" (itoa falhas) " cano(s) sem propriedades legiveis foram ignorados."))
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
  (vla-EndUndoMark doc)
  (princ (strcat "\nConcluido: " (itoa ok) " de " (itoa (length grupos))
                 " bueiro(s) com bocas inseridas. (U desfaz tudo)"))
  (princ)
)

(defun c:BBU () (c:BOCASBUEIRO))


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

(princ "\nBOCAS_BUEIRO v11 carregado. Comandos: BOCASBUEIRO (ou BBU), BBCALIB, BBCALIBLIMPA e BBDIAG.")
(princ)