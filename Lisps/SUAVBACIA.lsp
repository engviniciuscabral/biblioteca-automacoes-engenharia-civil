;;; ==========================================================================
;;;  SUAVBACIA.LSP
;;;  Suaviza contornos de bacias "em escada" (polilinhas geradas a partir de
;;;  raster / MDT), reduzindo vertices e mantendo as divisas compartilhadas
;;;  entre bacias vizinhas perfeitamente coincidentes.
;;;
;;;  Comando: SUAVBACIA
;;;
;;;  Etapas aplicadas a cada trecho entre "nos" (vertices fixos):
;;;    1. Pontos medios dos segmentos  -> elimina o degrau do raster
;;;    2. Douglas-Peucker (tolerancia) -> elimina vertices excedentes
;;;    3. Chaikin (n iteracoes)        -> arredonda o tracado
;;;
;;;  Vertices que NAO se movem:
;;;    - encontros de 3 ou mais bacias / pontas de linhas abertas
;;;    - quinas que nao sao de 90 graus (geometria desenhada, nao raster)
;;;    - extremidades de segmentos longos (> FATOR x celula) ou com arco
;;;
;;;  Requer AutoCAD / Civil 3D para Windows (usa Scripting.Dictionary).
;;; ==========================================================================
(vl-load-com)

;;; ---- parametros internos (podem ser ajustados) ---------------------------
(setq *sb-fator-degrau* 12.0) ; segmento > fator x celula = geometria real (fixa)
(setq *sb-prec* 3)            ; casas decimais p/ reconhecer vertices coincidentes
(if (not *sb-ftol*) (setq *sb-ftol* 1.0))       ; tolerancia = ftol x celula
(if (not *sb-nch*)  (setq *sb-nch* 2))          ; iteracoes de arredondamento
(if (not *sb-modo*) (setq *sb-modo* "Copiar"))  ; Copiar / Substituir
(setq *sb-layer* "BACIAS_SUAVIZADAS")

;;; ---- utilidades de lista -------------------------------------------------
(defun sb:butlast (l) (reverse (cdr (reverse l))))
(defun sb:take (l n / r) (repeat n (setq r (cons (car l) r) l (cdr l))) (reverse r))
(defun sb:drop (l n) (repeat n (setq l (cdr l))) l)

;;; ---- utilidades geometricas ----------------------------------------------
(defun sb:xy (v) (list (car v) (cadr v)))
(defun sb:key (v) (strcat (rtos (car v) 2 *sb-prec*) "," (rtos (cadr v) 2 *sb-prec*)))
(defun sb:mid (a b) (list (/ (+ (car a) (car b)) 2.0) (/ (+ (cadr a) (cadr b)) 2.0)))
(defun sb:lerp (a b tt)
  (list (+ (* (- 1.0 tt) (car a)) (* tt (car b)))
        (+ (* (- 1.0 tt) (cadr a)) (* tt (cadr b)))))

;; distancia de p ao segmento a-b
(defun sb:dseg (p a b / dx dy l2 tt)
  (setq dx (- (car b) (car a))
        dy (- (cadr b) (cadr a))
        l2 (+ (* dx dx) (* dy dy)))
  (if (< l2 1e-12)
    (distance p a)
    (progn
      (setq tt (/ (+ (* (- (car p) (car a)) dx) (* (- (cadr p) (cadr a)) dy)) l2)
            tt (max 0.0 (min 1.0 tt)))
      (distance p (list (+ (car a) (* tt dx)) (+ (cadr a) (* tt dy)))))))

;; desempate deterministico (garante o mesmo resultado nos dois sentidos)
(defun sb:menor (p q)
  (or (< (car p) (- (car q) 1e-9))
      (and (< (abs (- (car p) (car q))) 1e-9) (< (cadr p) (cadr q)))))

;;; ---- dicionario de vizinhanca (topologia) --------------------------------
(defun sb:true-p (x)
  (if (= (type x) 'variant) (setq x (vlax-variant-value x)))
  (or (eq x :vlax-true) (eq x T) (equal x -1)))

(defun sb:item (dict k / s)
  (setq s (vlax-get-property dict 'Item k))
  (if (= (type s) 'variant) (vlax-variant-value s) s))

(defun sb:adiciona (dict k nk / s)
  (if (sb:true-p (vlax-invoke-method dict 'Exists k))
    (progn
      (setq s (sb:item dict k))
      (if (not (vl-string-search (strcat ";" nk ";") s))
        (vlax-put-property dict 'Item k (strcat s nk ";"))))
    (vlax-invoke-method dict 'Add k (strcat ";" nk ";"))))

;; grau = numero de vizinhos distintos do vertice no conjunto selecionado
(defun sb:grau (dict k / s n i)
  (setq s (sb:item dict k) n 0 i 0)
  (while (setq i (vl-string-search ";" s i)) (setq n (1+ n) i (1+ i)))
  (1- n))

;; listas (anteriores proximos) de cada vertice
(defun sb:vizinhos (vs closed)
  (if closed
    (list (cons (last vs) (sb:butlast vs)) (append (cdr vs) (list (car vs))))
    (list (cons nil (sb:butlast vs)) (append (cdr vs) (list nil)))))

;;; ---- leitura da polilinha ------------------------------------------------
;; vertices como (x y bulge)
(defun sb:vertices (ed / out pt)
  (foreach g ed
    (cond ((= (car g) 10) (setq pt (cdr g)))
          ((= (car g) 42) (setq out (cons (list (car pt) (cadr pt) (cdr g)) out)))))
  (reverse out))

;; remove vertices repetidos consecutivos e o de fechamento
(defun sb:limpa (vs closed / out)
  (foreach v vs
    (if (or (null out) (/= (sb:key v) (sb:key (car out))))
      (setq out (cons v out))))
  (setq out (reverse out))
  (if (and closed (> (length out) 1) (= (sb:key (car out)) (sb:key (last out))))
    (setq out (sb:butlast out)))
  out)

;;; ---- classificacao: vertice fixo ("duro") ou suavizavel -------------------
(defun sb:duro-p (p v q dict lmax / a b c l1 l2 cs)
  (cond
    ((or (null p) (null q)) T)                                  ; ponta de linha aberta
    ((/= (sb:grau dict (sb:key v)) 2) T)                        ; encontro de bacias
    ((or (> (abs (caddr p)) 1e-9) (> (abs (caddr v)) 1e-9)) T)  ; trecho em arco
    (T
     (setq a (sb:xy p) b (sb:xy v) c (sb:xy q)
           l1 (distance a b) l2 (distance b c))
     (if (or (> l1 lmax) (> l2 lmax) (< l1 1e-9) (< l2 1e-9))
       T                                                        ; segmento longo
       (progn
         (setq cs (/ (+ (* (- (car b) (car a)) (- (car c) (car b)))
                        (* (- (cadr b) (cadr a)) (- (cadr c) (cadr b))))
                     (* l1 l2)))
         ;; suavizavel se a quina for ~90 graus (degrau) ou ~reta
         (not (or (< (abs cs) 0.26) (> cs 0.966))))))))

;;; ---- algoritmos de suavizacao --------------------------------------------
;; pontos medios, mantendo as extremidades
(defun sb:mids-open (pts / res)
  (setq res (list (car pts)))
  (mapcar '(lambda (a b) (setq res (cons (sb:mid a b) res))) pts (cdr pts))
  (reverse (cons (last pts) res)))

(defun sb:mids-closed (pts)
  (mapcar 'sb:mid pts (append (cdr pts) (list (car pts)))))

;; Douglas-Peucker iterativo (sem recursao)
(defun sb:dp (pts tol / stack seg a b dmax k i d best res left right)
  (setq stack (list pts))
  (while stack
    (setq seg (car stack) stack (cdr stack))
    (if (<= (length seg) 2)
      (setq res (cons (car seg) res))
      (progn
        (setq a (car seg) b (last seg) dmax -1.0 k nil best nil i 0)
        (foreach p (cdr seg)
          (setq i (1+ i) d (sb:dseg p a b))
          (cond ((> d (+ dmax 1e-7)) (setq dmax d k i best p))
                ((and (> d (- dmax 1e-7)) (sb:menor p best))
                 (setq dmax (max d dmax) k i best p))))
        (if (> dmax tol)
          (progn
            (setq left nil right seg)
            (repeat k (setq left (cons (car right) left) right (cdr right)))
            (setq left (reverse (cons (car right) left)))
            (setq stack (cons left (cons right stack))))
          (setq res (cons a res))))))
  (reverse (cons (last pts) res)))

;; Chaikin com extremidades fixas
(defun sb:chaikin-open (pts / res n i)
  (setq n (1- (length pts)) i 0 res (list (car pts)))
  (mapcar '(lambda (a b)
             (if (> i 0) (setq res (cons (sb:lerp a b 0.25) res)))
             (if (< i (1- n)) (setq res (cons (sb:lerp a b 0.75) res)))
             (setq i (1+ i)))
          pts (cdr pts))
  (reverse (cons (last pts) res)))

;; Chaikin para anel fechado
(defun sb:chaikin-closed (pts / res)
  (mapcar '(lambda (a b)
             (setq res (cons (sb:lerp a b 0.75) (cons (sb:lerp a b 0.25) res))))
          pts (append (cdr pts) (list (car pts))))
  (reverse res))

;; trecho entre dois vertices fixos -> lista de (x y bulge) sem o ultimo ponto
(defun sb:cadeia-out (c tol nch / pts)
  (if (= (length c) 2)
    (list (cdr (car c)))                        ; trecho direto: mantem original
    (progn
      (setq pts (sb:dp (sb:mids-open (mapcar '(lambda (r) (list (cadr r) (caddr r))) c)) tol))
      (if (> (length pts) 2) (repeat nch (setq pts (sb:chaikin-open pts))))
      (mapcar '(lambda (p) (list (car p) (cadr p) 0.0)) (sb:butlast pts)))))

;;; ---- processa uma polilinha ----------------------------------------------
(defun sb:processa (vs closed dict lmax tol nch / nb flags recs k chain res out)
  (setq nb    (sb:vizinhos vs closed)
        flags (mapcar '(lambda (p v q) (sb:duro-p p v q dict lmax)) (car nb) vs (cadr nb)))
  (if (and closed (not (member T flags)))
    ;; bacia isolada, sem nenhum vertice fixo
    (progn
      (setq out (sb:mids-closed (mapcar 'sb:xy vs))
            out (sb:butlast (sb:dp (append out (list (car out))) tol)))
      (if (< (length out) 3) (setq out (sb:mids-closed (mapcar 'sb:xy vs))))
      (repeat nch (setq out (sb:chaikin-closed out)))
      (mapcar '(lambda (p) (list (car p) (cadr p) 0.0)) out))
    (progn
      (setq recs (mapcar 'cons flags vs))       ; (fixo x y bulge)
      (if closed
        (setq k    (vl-position T flags)
              recs (append (sb:drop recs k) (sb:take recs k))
              recs (append recs (list (car recs)))))
      (setq chain (list (car recs)))
      (foreach r (cdr recs)
        (setq chain (cons r chain))
        (if (car r)
          (progn
            (foreach v (sb:cadeia-out (reverse chain) tol nch) (setq res (cons v res)))
            (setq chain (list r)))))
      (if (not closed) (setq res (cons (cdr (car chain)) res)))
      (reverse res))))

;;; ---- criacao da nova polilinha -------------------------------------------
(defun sb:cria (ed vs lay / head fim)
  (while (and ed (/= 10 (caar ed)))
    (if (not (member (caar ed) '(-1 5 102 330 360)))
      (setq head (cons (car ed) head)))
    (setq ed (cdr ed)))
  (setq head (reverse head)
        head (subst (cons 90 (length vs)) (assoc 90 head) head))
  (if lay (setq head (subst (cons 8 lay) (assoc 8 head) head)))
  (if (entmake
        (append head
                (apply 'append
                       (mapcar '(lambda (v) (list (list 10 (car v) (cadr v)) (cons 42 (caddr v)))) vs))
                (if (setq fim (assoc 210 ed)) (list fim))))
    (entlast)))

(defun sb:cria-layer (lay)
  (if (not (tblsearch "LAYER" lay))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbLayerTableRecord")
                   (cons 2 lay) '(70 . 0) '(62 . 3) '(6 . "Continuous")))))

;;; ==========================================================================
;;;  COMANDO
;;; ==========================================================================
(defun c:SUAVBACIA (/ *error* doc ss i e ed closed vs polys dict k nb lens idx cel x
                      tol nch modo lmax nova ent cnt nv0 nv1 at0 at1)
  (defun *error* (msg)
    (if dict (vl-catch-all-apply 'vlax-release-object (list dict)))
    (if doc (vla-EndUndoMark doc))
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*"))
      (princ (strcat "\nErro: " msg)))
    (princ))

  (prompt "\nSelecione as polilinhas das bacias (inclua TODAS as vizinhas e divisorias):")
  (if (not (setq ss (ssget '((0 . "LWPOLYLINE")))))
    (progn (princ "\nNada selecionado.") (exit)))

  ;; leitura
  (repeat (setq i (sslength ss))
    (setq e      (ssname ss (setq i (1- i)))
          ed     (entget e)
          closed (= 1 (logand 1 (cdr (assoc 70 ed))))
          vs     (sb:limpa (sb:vertices ed) closed))
    (if (>= (length vs) (if closed 3 2))
      (setq polys (cons (list e closed vs) polys))))
  (if (null polys) (progn (princ "\nNenhuma polilinha valida.") (exit)))

  ;; topologia: vizinhos de cada vertice
  (setq dict (vlax-create-object "Scripting.Dictionary"))
  (foreach pl polys
    (setq vs (caddr pl) nb (sb:vizinhos vs (cadr pl)))
    (mapcar '(lambda (p v q)
               (setq k (sb:key v))
               (sb:adiciona dict k (if p (sb:key p) "END"))
               (sb:adiciona dict k (if q (sb:key q) "END")))
            (car nb) vs (cadr nb)))

  ;; tamanho de celula: quartil inferior dos comprimentos de segmento
  (foreach pl polys
    (mapcar '(lambda (a b)
               (if (< (abs (caddr a)) 1e-9)
                 (setq lens (cons (distance (sb:xy a) (sb:xy b)) lens))))
            (caddr pl) (cdr (caddr pl))))
  (if lens
    (setq idx (vl-sort-i lens '<)
          cel (nth (nth (fix (* 0.25 (length idx))) idx) lens))
    (setq cel 1.0))

  ;; parametros
  (initget 6)
  (if (setq x (getdist (strcat "\nTamanho da celula (degrau) do raster <" (rtos cel 2 3) ">: ")))
    (setq cel x))
  (initget 6)
  (if (setq tol (getdist (strcat "\nTolerancia de simplificacao <" (rtos (* *sb-ftol* cel) 2 3) ">: ")))
    (setq *sb-ftol* (/ tol cel))
    (setq tol (* *sb-ftol* cel)))
  (initget 4)
  (if (setq nch (getint (strcat "\nIteracoes de arredondamento, 0 = nenhuma <" (itoa *sb-nch*) ">: ")))
    (setq *sb-nch* nch)
    (setq nch *sb-nch*))
  (initget "Copiar Substituir")
  (if (setq modo (getkword (strcat "\nResultado [Copiar/Substituir] <" *sb-modo* ">: ")))
    (setq *sb-modo* modo)
    (setq modo *sb-modo*))

  ;; processamento
  (setq doc  (vla-get-ActiveDocument (vlax-get-acad-object))
        lmax (* *sb-fator-degrau* cel)
        cnt 0 nv0 0 nv1 0 at0 0.0 at1 0.0)
  (vla-StartUndoMark doc)
  (if (= modo "Copiar") (sb:cria-layer *sb-layer*))
  (foreach pl polys
    (setq e (car pl) closed (cadr pl) vs (caddr pl)
          nova (sb:processa vs closed dict lmax tol nch))
    (if (and (>= (length nova) (if closed 3 2))
             (setq ent (sb:cria (entget e) nova (if (= modo "Copiar") *sb-layer*))))
      (progn
        (setq cnt (1+ cnt)
              nv0 (+ nv0 (length vs))
              nv1 (+ nv1 (length nova)))
        (if closed
          (setq at0 (+ at0 (vlax-curve-getArea e))
                at1 (+ at1 (vlax-curve-getArea ent))))
        (if (= modo "Substituir") (entdel e)))))
  (vla-EndUndoMark doc)
  (vlax-release-object dict)
  (setq dict nil)

  ;; relatorio
  (princ (strcat "\n" (itoa cnt) " polilinha(s) suavizada(s). Vertices: "
                 (itoa nv0) " -> " (itoa nv1)))
  (if (> at0 0.0)
    (princ (strcat "\nVariacao da area total das bacias fechadas: "
                   (rtos (* 100.0 (/ (- at1 at0) at0)) 2 2) " %")))
  (if (= modo "Copiar") (princ (strcat "\nResultado no layer " *sb-layer* ".")))
  (princ))

(princ "\nSUAVBACIA carregado. Digite SUAVBACIA para executar.")
(princ)