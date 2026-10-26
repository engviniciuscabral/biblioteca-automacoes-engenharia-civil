;;; =====================================================================
;;;  BOCAS_BUEIRO.LSP  -  Insercao automatica de bocas de bueiro (Civil 3D)
;;; ---------------------------------------------------------------------
;;;  Comando : BOCASTUDO     (atalho: BBT)  - planta + perfil de todos
;;;            BOCASBUEIRO   (atalho: BBU)  - bocas em planta
;;;            BOCASPERFIL   (atalho: BBP)  - bocas em corte no Profile View
;;;                                           (clique na pipe dentro do perfil)
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

;;; (nome comprimento largura) em metros, ou nil se nao houver DEB
(defun bb:deb-param (code d / best)
  (foreach r *bb:deb*
    (if (and (= (car r) code) (<= (abs (- (cadr r) d)) 0.05)) (setq best r)))
  (if best
    (list (strcat "DEB_" code (itoa (fix (+ 0.5 (* 100.0 (cadr best))))))
          (* 0.01 (caddr best))
          (* 0.01 (cadddr best)))))

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
                                 deb mB)
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
                (princ (strcat txt "AVISO - o bloco \"" blk "\" nao tem estado para "
                               code " " (rtos D 2 2) " m; usado \"" (car stM) "\"."
                               "\n   Se o bloco for antigo, carregue o TEMPLATE_BOCAS e rode"
                               " BOCASCADDIN para recriar com todos os tamanhos."))
              )
              ;; ---------- dissipador (tubular e D <= / < limite) ----------
              (setq dis "nao")
              (if (and (= shp "TC")
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
                   (setq dis (strcat "sim (" (car deb) ")")))
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
      (list (strcat "BB_CORTE_" (car best) (itoa (fix (+ 0.5 (* 100.0 (cadr best))))))
            (nth 0 v)
            (if (= shp "TC") (+ (nth 0 v) (nth 1 v)) (nth 6 v))
            (nth 2 v) (nth 3 v) (nth 4 v) (nth 5 v) (nth 6 v)))))

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
(defun bb:corte-bloco (prm / blk b xa h e n p mm wd)
  (if (not (tblsearch "BLOCK" (car prm)))
    (progn
      (setq b (nth 1 prm) xa (nth 2 prm) h (nth 3 prm) e (nth 4 prm)
            n (nth 5 prm) p (nth 6 prm) mm (nth 7 prm) wd (* 0.01 *BB:CORTE-DENTE*)
            blk (vla-Add (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object)))
                         (vlax-3d-point '(0.0 0.0 0.0)) (car prm)))
      (bb:addpl blk (list (list 0.0 0.0) (list b 0.0) (list b h) (list 0.0 h)) T)       ; testa
      (bb:addpl blk (list (list b h) (list xa p) (list xa 0.0)) nil)                     ; ala
      (bb:addpl blk (list (list 0.0 0.0) (list mm 0.0) (list mm (- e)) (list 0.0 (- e))) T) ; soleira
      (bb:addpl blk (list (list (- mm wd) (- e)) (list mm (- e))                         ; dente
                          (list mm (- (+ e n))) (list (- mm wd) (- (+ e n)))) T)))
  (car prm))

;;; Ponto (x y) do Profile View para estaca e cota (nil se falhar)
(defun bb:pv-xy (pv sta el / x y r)
  (setq r (vl-catch-all-apply 'vlax-invoke-method
            (list pv 'FindXYAtStationAndElevation sta el 'x 'y)))
  (if (and (not (vl-catch-all-error-p r))
           (numberp (setq x (bb:var->lisp x)))
           (numberp (setq y (bb:var->lisp y))))
    (list x y)))

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
;;; 1) propriedade do perfil; 2) pelo nome: o perfil "PERFIL BUEIRO BC 07"
;;; e do alinhamento "BUEIRO BC 07" (o nome mais longo contido no do perfil)
(defun bb:pv-al-auto (pv en / a e nm best)
  (foreach k '(Alignment ParentAlignment)
    (if (and (not a) (= (type (setq e (bb:try pv k))) 'VLA-OBJECT)) (setq a e)))
  (if (and (not a) (= (type (setq e (bb:gpv en "AlignmentId"))) 'ENAME))
    (setq a (vlax-ename->vla-object e)))
  (if (not a)
    (progn
      (if (not *bb:als*) (setq *bb:als* (bb:alinhamentos)))
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

;;; Dissipador DEB em corte, encaixado na ponta externa da boca de jusante
(defun bb:perfil-dissip (pv prm deb sta zinv sg)
  (bb:perfil-ins pv (bb:deb-corte deb)
                 (+ (bb:perfil-s0 prm sta sg) (* sg (nth 7 prm)))
                 zinv sg *BB:LAYER-DISSIP*))

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

;;; Bueiro cujas pontas (em planta) caem nas estacas s0..s1 do alinhamento
(defun bb:grupo-por-estaca (al grupos s0 s1 / best be sA sB er)
  (foreach g grupos
    (setq sA (bb:al-sta al (bb:media (mapcar 'cadr g)))
          sB (bb:al-sta al (bb:media (mapcar 'caddr g))))
    (if (and sA sB)
      (progn
        (setq er (+ (abs (- (min (car sA) (car sB)) s0)) (abs (- (max (car sA) (car sB)) s1))))
        (if (and (< er (max 2.0 (* 0.2 (- s1 s0)))) (or (not be) (< er be)))
          (setq best g be er)))))
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
     (if (not (and mS jS))
       (progn (princ "\n  Nao achei a estaca das pontas do cano no alinhamento deste perfil.") nil)
       (bb:perfil-inserir pv code shp D HC (car mS) (car jS)
                          (bb:z-geratriz canos 1) (bb:z-geratriz canos 2))))))

;;; Insere boca de montante, boca de jusante e dissipador no perfil, dadas
;;; as estacas e as cotas da geratriz inferior nas duas pontas.
(defun bb:perfil-inserir (pv code shp D HC sM sJ zM zJ / prm sg deb e0 e1)
  (cond
    ((not (setq prm (bb:corte-param shp code D HC)))
     (princ (strcat "\n  Sem dados de corte para " code ".")) nil)
    (T
     (bb:corte-bloco prm)
     (setq sg (if (< sM sJ) -1.0 1.0))
     (bb:perfil-boca pv prm sM zM sg)
     (bb:perfil-boca pv prm sJ zJ (- sg))
     ;; dissipador DEB na jusante (tubular ate o limite de diametro)
     (if (and *BB:DISSIP-DNIT* (= shp "TC")
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
           ;; altura desenhada = diam. externo + desnivel -> parede
           wall (max 0.0 (/ (- (nth 3 cx) (nth 2 cx) zdif hh) 2.0))
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
         (setq zmod (bb:z-geratriz canos 2))
         (princ (strcat "\n  (pela pipe desenhada; cota da pipe 3D na jusante = " (rtos zmod 2 3)
                        ", diferenca " (rtos (- zJ zmod) 2 3) " m)"))
         (bb:perfil-inserir pv code shp D HC sM sJ zM zJ))))))

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
            (setq g (or (and pe
                             (vl-some '(lambda (gr)
                                         (if (vl-some '(lambda (c) (equal (vlax-vla-object->ename (car c)) pe)) gr)
                                           gr))
                                      grupos))
                        (bb:grupo-por-estaca al grupos (nth 0 cx) (nth 1 cx)))))
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
        tot 0)
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

;;; Bocas em planta (como BBU) e em corte nos Profile Views de cada bueiro
;;; (como BBP), tudo de uma vez.
(defun c:BOCASTUDO (/ *error* doc blk ss ssv i c canos grupos pvs pv al idx np ok okp dbg nv inv sem)
  (defun *error* (msg)
    (setq *BB:DEBUG* dbg)
    (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg "  (etapa: " (vl-princ-to-string *bb:etapa*) ")")))
    (princ))
  (princ "\n[BOCAS_BUEIRO - planta + perfil]")
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
  (if (setq ssv (ssget "_X" '((0 . "AECC_PROFILE_VIEW"))))
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
    (if (bb:processar g idx blk) (setq ok (1+ ok)))
    ;; perfil
    (setq *bb:etapa* "perfil" np 0)
    (foreach v pvs
      (if (bb:perfil-combina (nth 1 v) (nth 2 v) (nth 3 v) g)
        (progn
          (princ (strcat "\n  perfil \"" (nth 4 v) "\":"))
          (if (bb:perfil-grupo (nth 0 v) (nth 1 v) g) (setq np (1+ np))))))
    (if (> np 0)
      (setq okp (1+ okp))
      (princ (strcat "\nBueiro " (itoa idx) ": nenhum Profile View encontrado (use BBP nele)."))))
  (vla-EndUndoMark doc)
  (princ (strcat "\nConcluido: " (itoa ok) " de " (itoa (length grupos))
                 " bueiro(s) em planta e " (itoa okp) " no perfil. (U desfaz tudo)"))
  (princ))

(defun c:BBT () (c:BOCASTUDO))


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

(princ "\nBOCAS_BUEIRO v13 carregado. Comandos: BOCASTUDO (BBT = planta + perfil), BOCASBUEIRO (BBU), BOCASPERFIL (BBP), BBCALIB, BBCALIBLIMPA e BBDIAG.")
(princ)
