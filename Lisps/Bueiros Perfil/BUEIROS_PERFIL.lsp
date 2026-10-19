;;; =====================================================================
;;; BUEIROS_PERFIL.lsp  -  Civil 3D
;;; Comando: BUEIROPERFIL
;;;
;;; 1) Le o CSV do CADASTRO das obras (separador ";", decimal ",")
;;; 2) Le (opcional) o COGOpoints.csv (PNEZD, separador ",")
;;;    - Cada ponto e projetado no eixo: calcula a estaca (StationOffset),
;;;      pega a posicao no eixo com offset 0 e cria um COGO point ali
;;;      com a elevacao do arquivo (ou a cota montante do cadastro).
;;;    - O ponto e associado a obra do cadastro de estaca mais proxima
;;;      (tolerancia *bp:tol*).
;;;    - Se o COGOpoints for cancelado, usa estaca + cota montante do cadastro.
;;; 3) Desenha na vista de perfil a obra (BSCC/BDCC/BTCC, BSTC/BDTC/BTTC)
;;;    com fundo na cota, ja na escala/exagero da vista, e a legenda:
;;;       Estaca / Descricao / Obra projetada / L / Cota montante / Inclinacao
;;; 4) Coloca os pontos criados no grupo de pontos *bp:grupo*.
;;; =====================================================================

(vl-load-com)

;; ----------------------------- CONFIGURACAO -----------------------------
(setq *bp:estaca*     20.0)          ; metros por estaca
(setq *bp:txth*        2.0)          ; altura do texto da legenda (unid. desenho)
(setq *bp:txtgap*      4.0)          ; distancia do fundo da obra ao topo da legenda
(setq *bp:tub-gap*     0.0)          ; espaco entre tubos (fracao do diametro; 0 = encostados)
(setq *bp:tol*        30.0)          ; tolerancia (m) p/ associar ponto COGO <-> cadastro
(setq *bp:cogo-ordem* "PNEZD")       ; "PNEZD" ou "PENZD"
(setq *bp:grupo*      "OAC - EIXO")  ; grupo de pontos para os pontos criados
(setq *bp:layer*      "OBRAS PROJETADAS") ; layer de TUDO que a rotina cria (pontos, obras, legendas)
(setq *bp:cor-layer*  5)             ; cor da layer, se ela for criada (5 = azul)
(setq *bp:projetar*   T)             ; T = projetar automaticamente os COGO points na vista de perfil
(setq *bp:lay-obra*   *bp:layer*)
(setq *bp:lay-leg*    *bp:layer*)

;; ----------------------------- UTILITARIOS ------------------------------
(defun bp:get (k r) (cdr (assoc k r)))

(defun bp:var (v)
  (if (= (type v) 'VARIANT) (vlax-variant-value v) v))

(defun bp:split (s d / p r)
  (while (setq p (vl-string-search d s))
    (setq r (cons (substr s 1 p) r)
          s (substr s (+ p 1 (strlen d)))))
  (reverse (cons s r)))

(defun bp:join (l d / s)
  (setq s (car l))
  (foreach x (cdr l) (setq s (strcat s d x)))
  (if s s ""))

(defun bp:trim (s) (if s (vl-string-trim " \t\"" s) ""))

;; le arquivo texto via ADODB.Stream (ANSI/UTF-8, funciona com o CSV aberto no Excel)
(defun bp:adodb-read (f cs / st txt)
  (setq st (vl-catch-all-apply 'vlax-create-object (list "ADODB.Stream")))
  (if (and st (not (vl-catch-all-error-p st)))
    (progn
      (setq txt (vl-catch-all-apply
                  '(lambda ()
                     (vlax-put-property st 'Type 2)
                     (vlax-put-property st 'Charset cs)
                     (vlax-invoke-method st 'Open)
                     (vlax-invoke-method st 'LoadFromFile f)
                     (vlax-invoke-method st 'ReadText -1))))
      (vl-catch-all-apply 'vlax-invoke-method (list st 'Close))
      (vlax-release-object st)
      (if (= (type txt) 'STR) txt))))

(defun bp:readlines (f / txt h l r)
  (setq txt (bp:adodb-read f "windows-1252"))
  ;; arquivo salvo como UTF-8 com BOM
  (if (and txt (= (substr txt 1 3) (strcat (chr 239) (chr 187) (chr 191))))
    (setq txt (bp:adodb-read f "utf-8")))
  (if txt
    (setq r (mapcar '(lambda (x) (vl-string-trim "\r" x))
                    (bp:split (vl-string-translate "\r" "\n" txt) "\n")))
    ;; alternativa: leitura nativa
    (if (setq h (open f "r"))
      (progn (while (setq l (read-line h)) (setq r (cons l r))) (close h)
             (setq r (reverse r)))))
  (vl-remove "" r))

;; split com suporte a campos entre aspas ("631,97")
(defun bp:csvsplit (s d / i c q cur r)
  (setq i 1 cur "")
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (cond ((= c "\"") (setq q (not q)))
          ((and (= c d) (not q)) (setq r (cons cur r) cur ""))
          (t (setq cur (strcat cur c))))
    (setq i (1+ i)))
  (reverse (cons cur r)))

;; "631,97" / "0,50%" / "18" -> real (ou nil)
(defun bp:num-br (s)
  (if (and s (/= (setq s (vl-string-trim " %mM" (vl-string-translate "," "." s))) ""))
    (distof s 2)))

(defun bp:txt-p (s) (and s (/= s "") (not (distof s 2))))

(defun bp:fmt (x dec / dz s)
  (setq dz (getvar "DIMZIN"))
  (setvar "DIMZIN" 0)
  (setq s (rtos x 2 dec))
  (setvar "DIMZIN" dz)
  (vl-string-translate "." "," s))

;; sem zeros a direita: 0,50 -> 0,5 ; 18,00 -> 18
(defun bp:fmt-trim (x dec / s)
  (setq s (bp:fmt x dec))
  (if (vl-string-search "," s)
    (setq s (vl-string-right-trim "," (vl-string-right-trim "0" s))))
  s)

(defun bp:estaca-str (sta / e)
  (setq e (fix (/ (+ sta 1e-6) *bp:estaca*)))
  (strcat (itoa e) "+" (bp:fmt (- sta (* e *bp:estaca*)) 2)))

(defun bp:col (hdr pats / i r)
  (setq i 0)
  (foreach h hdr
    (if (and (null r)
             (vl-some '(lambda (p) (wcmatch (strcase (bp:trim h)) p)) pats))
      (setq r i))
    (setq i (1+ i)))
  r)

;; extrai numeros de um texto: "BTCC 3,0 x 3,0 m" -> (3.0 3.0)
(defun bp:nums-in (s / i c cur r v)
  (setq s (vl-string-translate "," "." s) cur "" i 1)
  (while (<= i (1+ (strlen s)))
    (setq c (if (<= i (strlen s)) (substr s i 1) " "))
    (if (or (wcmatch c "#") (and (= c ".") (/= cur "")))
      (setq cur (strcat cur c))
      (progn
        (if (and (/= cur "") (setq v (distof (vl-string-right-trim "." cur) 2)))
          (setq r (cons v r)))
        (setq cur "")))
    (setq i (1+ i)))
  (reverse r))

(defun bp:layer (n c)
  (if (not (tblsearch "LAYER" n))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord") (cons 2 n) '(70 . 0)
                   (cons 62 c) '(6 . "Continuous")))))

(defun bp:pline (pts lay closed)
  (entmake (append (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 lay)
                         '(100 . "AcDbPolyline") (cons 90 (length pts))
                         (cons 70 (if closed 1 0)) '(43 . 0.0))
                   (mapcar '(lambda (p) (cons 10 p)) pts))))

(defun bp:mtext (pt txt lay / l)
  (setq l (list '(0 . "MTEXT") '(100 . "AcDbEntity") (cons 8 lay) '(100 . "AcDbMText")
                (cons 10 (list (car pt) (cadr pt) 0.0)) (cons 40 *bp:txth*)
                '(41 . 0.0) '(71 . 2) '(72 . 1)))
  (while (> (strlen txt) 250)
    (setq l (append l (list (cons 3 (substr txt 1 250)))) txt (substr txt 251)))
  (entmake (append l (list (cons 1 txt) (cons 7 (getvar "TEXTSTYLE")) '(50 . 0.0)))))

;; ----------------------------- CIVIL 3D COM -----------------------------
(defun bp:civdoc (/ acad key rel p1 vers app)
  (setq acad (vlax-get-acad-object)
        key  (vl-catch-all-apply 'vlax-product-key))
  (if (= (type key) 'STR)
    (setq rel (vl-catch-all-apply 'vl-registry-read
                (list (strcat "HKEY_LOCAL_MACHINE\\" key) "Release"))))
  (if (and (= (type rel) 'STR)
           (setq p1 (vl-string-search "." rel))
           (vl-string-search "." rel (1+ p1)))
    (setq vers (list (substr rel 1 (vl-string-search "." rel (1+ p1))))))
  (setq vers (append vers '("14.1" "14.0" "13.9" "13.8" "13.7" "13.6" "13.5" "13.4"
                            "13.3" "13.2" "13.1" "13.0" "12.0" "11.0")))
  (foreach v vers
    (if (null app)
      (progn
        (setq app (vl-catch-all-apply 'vla-GetInterfaceObject
                    (list acad (strcat "AeccXUiLand.AeccApplication." v))))
        (if (vl-catch-all-error-p app) (setq app nil)))))
  (if app (vlax-get app 'ActiveDocument)))

(defun bp:sel-pv (/ s o r)
  (setq *bp:pvpick* nil)
  (while (and (null r) (setq s (entsel "\nSelecione a vista de perfil (profile view): ")))
    (setq o (vlax-ename->vla-object (car s)))
    (if (vlax-method-applicable-p o 'FindXYAtStationAndElevation)
      (setq r o *bp:pvpick* s)
      (princ "\nO objeto selecionado nao e uma vista de perfil.")))
  r)

(defun bp:get-align (pv / a s o)
  (foreach p '(Alignment ParentAlignment)
    (if (and (null a) (vlax-property-available-p pv p))
      (progn
        (setq a (vl-catch-all-apply 'vlax-get-property (list pv p)))
        (if (or (vl-catch-all-error-p a)
                (not (vlax-method-applicable-p a 'PointLocation)))
          (setq a nil)))))
  (while (and (null a) (setq s (entsel "\nSelecione o alinhamento (eixo): ")))
    (setq o (vlax-ename->vla-object (car s)))
    (if (vlax-method-applicable-p o 'PointLocation)
      (setq a o)
      (princ "\nO objeto nao e um alinhamento.")))
  a)

;; estaca/offset de um ponto (E,N) em relacao ao eixo
(defun bp:sta-off (al e n / sta off r)
  (setq r (vl-catch-all-apply 'vlax-invoke-method (list al 'StationOffset e n 'sta 'off)))
  (if (or (vl-catch-all-error-p r) (null sta)) nil (list (bp:var sta) (bp:var off))))

;; (E N) no eixo para uma estaca/offset
(defun bp:pt-on-align (al sta off / e n r)
  (setq r (vl-catch-all-apply 'vlax-invoke-method (list al 'PointLocation sta off 'e 'n)))
  (if (or (vl-catch-all-error-p r) (null e)) nil (list (bp:var e) (bp:var n))))

;; (X Y) na vista de perfil
(defun bp:pv-xy (pv sta elev / x y r)
  (setq r (vl-catch-all-apply 'vlax-invoke-method
            (list pv 'FindXYAtStationAndElevation sta elev 'x 'y)))
  (if (or (vl-catch-all-error-p r) (null x)) nil (list (bp:var x) (bp:var y))))

(defun bp:in-pv (pv sta / a b)
  (setq a (vl-catch-all-apply 'vlax-get (list pv 'StationStart))
        b (vl-catch-all-apply 'vlax-get (list pv 'StationEnd)))
  (if (and (numberp a) (numberp b))
    (and (>= sta (- a 1e-6)) (<= sta (+ b 1e-6)))
    T))

(defun bp:add-point (civ e n z desc nome / p)
  (setq p (vl-catch-all-apply 'vlax-invoke-method
            (list (vlax-get civ 'Points) 'Add (vlax-3d-point e n z))))
  (if (vl-catch-all-error-p p)
    nil
    (progn
      (if (and desc (/= desc ""))
        (vl-catch-all-apply 'vlax-put-property (list p 'RawDescription desc)))
      (if (and nome (/= nome ""))
        (vl-catch-all-apply 'vlax-put-property (list p 'Name nome)))
      (vl-catch-all-apply 'vlax-put-property (list p 'Layer *bp:layer*))
      p)))

;; projeta os pontos (selection set) na vista de perfil com o comando nativo do Civil 3D
(defun bp:projetar (ss pick / r e0 e)
  (setq e0 (entlast))
  (setq r (vl-catch-all-apply
            '(lambda ()
               (command "_.PROJECTOBJECTSTOPROF" ss "" pick)
               ;; o Civil 3D abre a janela de estilos da projecao: aguarda o OK
               (while (> (getvar "CMDACTIVE") 0) (command pause)))))
  ;; leva as projecoes criadas para a layer da rotina
  (setq e (if e0 (entnext e0) (entnext)))
  (while e
    (vl-catch-all-apply 'vla-put-Layer (list (vlax-ename->vla-object e) *bp:layer*))
    (setq e (entnext e)))
  (if (vl-catch-all-error-p r)
    (princ (strcat "\nAviso: nao foi possivel projetar os pontos automaticamente ("
                   (vl-catch-all-error-message r)
                   "). Use PROJECTOBJECTSTOPROF com o grupo \"" *bp:grupo* "\"."))
    (princ (strcat "\n" (itoa (sslength ss)) " COGO point(s) projetado(s) na vista de perfil."))))

(defun bp:add-to-group (civ nums / pgs pg qb old s)
  (setq pgs (vlax-get civ 'PointGroups)
        pg  (vl-catch-all-apply 'vlax-invoke-method (list pgs 'Item *bp:grupo*)))
  (if (vl-catch-all-error-p pg)
    (setq pg (vlax-invoke-method pgs 'Add *bp:grupo*)))
  (setq qb  (vlax-get pg 'QueryBuilder)
        old (vlax-get qb 'IncludeNumbers)
        s   (bp:join (mapcar 'itoa nums) ","))
  (vlax-put qb 'IncludeNumbers (if (and old (/= old "")) (strcat old "," s) s))
  (vl-catch-all-apply 'vlax-invoke-method (list pg 'Update)))

;; ----------------------------- LEITURA CSV ------------------------------
(defun bp:read-cadastro (f quiet / lines hdr dl fl ie id io ic ii il ib ia est frac en p r)
  (setq lines (bp:readlines f))
  (foreach l lines
    (cond
      ((null hdr)
       (if (and (vl-string-search "ESTACA" (strcase l))
                (vl-string-search "COTA MONTANTE" (strcase l)))
         (progn
           (setq dl  (if (vl-string-search ";" l) ";" ",")
                 hdr (mapcar 'bp:trim (bp:csvsplit l dl))
                 ie  (bp:col hdr '("ESTACA"))
                 id  (bp:col hdr '("DESCRI*"))
                 io  (bp:col hdr '("OBRA PROJETADA"))
                 ic  (bp:col hdr '("COTA MONTANTE"))
                 ii  (bp:col hdr '("DECLIV*" "INCLINA*"))
                 il  (bp:col hdr '("L PROJETADO*"))
                 ib  (bp:col hdr '("COD*BUEIRO*"))
                 ia  (bp:col hdr '("COD*BACIA*")))
           ;; padroes caso algum titulo nao seja encontrado
           (if (null ie) (setq ie 2))  (if (null id) (setq id 5))
           (if (null io) (setq io 7))  (if (null ic) (setq ic 16))
           (if (null ii) (setq ii 15)) (if (null il) (setq il 19))
           (if (null ib) (setq ib 1))  (if (null ia) (setq ia 0)))))
      (t
       (setq fl (mapcar 'bp:trim (bp:csvsplit l dl))
             est (nth ie fl)
             frac 0.0)
       (cond
         ((and est (setq p (vl-string-search "+" est)))
          (setq frac (bp:num-br (substr est (+ p 2))) est (substr est 1 p)))
         ((= (nth (1+ ie) fl) "+")
          (setq frac (bp:num-br (nth (+ ie 2) fl)))))
       (if (null frac) (setq frac 0.0))
       (if (and est (setq en (bp:num-br est)))
         (setq r (cons (list (cons "BACIA"  (bp:trim (nth ia fl)))
                             (cons "BUEIRO" (bp:trim (nth ib fl)))
                             (cons "EST"    (itoa (fix en)))
                             (cons "FRAC"   frac)
                             (cons "STA"    (+ (* (fix en) *bp:estaca*) frac))
                             (cons "DESC"   (bp:trim (nth id fl)))
                             (cons "OBRA"   (bp:trim (nth io fl)))
                             (cons "COTA"   (bp:num-br (nth ic fl)))
                             (cons "INC"    (bp:num-br (nth ii fl)))
                             (cons "L"      (bp:num-br (nth il fl))))
                       r))))))
  ;; diagnostico
  (if (and (null r) (not quiet))
    (progn
      (princ (strcat "\n[diagnostico] Linhas lidas: " (itoa (length lines))
                     " | Cabecalho (ESTACA + COTA MONTANTE) encontrado: " (if hdr "sim" "NAO")))
      (if (car lines) (princ (strcat "\n[diagnostico] 1a linha: " (substr (car lines) 1 80))))
      (if (cadr lines) (princ (strcat "\n[diagnostico] 2a linha: " (substr (cadr lines) 1 80))))
      (if (caddr lines) (princ (strcat "\n[diagnostico] 3a linha: " (substr (caddr lines) 1 80))))))
  (reverse r))

;; pede o cadastro; se o usuario escolher o arquivo de pontos COGO por engano,
;; usa-o como COGOpoints e pede o cadastro de novo.
;; retorna (registros arquivoCogo arquivoCadastro) ou nil
(defun bp:pick-files (/ f1 f2 recs fcogo)
  (princ "\n>> Passo 1: selecione o CSV do CADASTRO das obras (o que tem ESTACA, COTA MONTANTE...).")
  (if (setq f1 (getfiled "Passo 1 - CSV do CADASTRO das obras" (getvar "DWGPREFIX") "csv" 0))
    (cond
      ((setq recs (bp:read-cadastro f1 T))
       (list recs nil f1))
      ((bp:read-cogo f1)
       (princ "\nEsse arquivo e de pontos COGO (PNEZD), nao o cadastro - ele sera usado como COGOpoints.")
       (princ "\n>> Agora selecione o CSV do CADASTRO das obras.")
       (setq fcogo f1)
       (if (and (setq f2 (getfiled "Passo 1 - agora o CSV do CADASTRO das obras"
                                   (strcat (vl-filename-directory f1) "\\") "csv" 0))
                (setq recs (bp:read-cadastro f2 nil)))
         (list recs fcogo f2)))
      (t (bp:read-cadastro f1 nil) nil))))

;; retorna lista de (P N E Z D)
(defun bp:read-cogo (f / d fl in ie n e z r)
  (if (= (strcase *bp:cogo-ordem*) "PENZD") (setq ie 1 in 2) (setq in 1 ie 2))
  (foreach l (bp:readlines f)
    (setq d  (if (vl-string-search ";" l) ";" ",")
          fl (mapcar 'bp:trim (bp:csvsplit l d)))
    (if (and (>= (length fl) 4)
             (setq n (bp:num-br (nth in fl)))
             (setq e (bp:num-br (nth ie fl)))
             (setq z (bp:num-br (nth 3 fl))))
      (setq r (cons (list (nth 0 fl) n e z (if (nth 4 fl) (nth 4 fl) "")) r))))
  (reverse r))

(defun bp:nearest (sta recs / best bd d)
  (foreach r recs
    (setq d (abs (- sta (bp:get "STA" r))))
    (if (and (<= d *bp:tol*) (or (null bd) (< d bd)))
      (setq best r bd d)))
  best)

;; ----------------------------- DESENHO ----------------------------------
(defun bp:obra-tipo (s / u)
  (setq u (strcase (if s s "")))
  (cond
    ((wcmatch u "*BSCC*") '(CEL 1)) ((wcmatch u "*BDCC*") '(CEL 2))
    ((wcmatch u "*BTCC*") '(CEL 3)) ((wcmatch u "*BQCC*") '(CEL 4))
    ((wcmatch u "*BSTC*") '(TUB 1)) ((wcmatch u "*BDTC*") '(TUB 2))
    ((wcmatch u "*BTTC*") '(TUB 3))))

;; "elipse" do tubo no perfil: polilinha fechada de 2 vertices (topo e base)
;; com 2 arcos (bulge). cx = eixo do tubo, ytop = topo, alt = altura, larg = largura
(defun bp:lens (cx ytop alt larg lay / b)
  (setq b (/ larg alt))   ; bulge = 2*flecha/corda = (larg/2*2)/alt
  (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 lay)
                 '(100 . "AcDbPolyline") '(90 . 2) '(70 . 1) '(43 . 0.0) '(38 . 0.0)
                 (list 10 cx ytop) '(40 . 0.0) '(41 . 0.0) (cons 42 b)
                 (list 10 cx (- ytop alt)) '(40 . 0.0) '(41 . 0.0) (cons 42 b))))

;; x0,y0 = estaca/cota (COGO point) na vista ; hs,vs = unid. desenho por metro (H e V)
;; a obra e desenhada ABAIXO do ponto (topo da obra no ponto).
;; retorna o Y mais baixo desenhado (para posicionar a legenda)
(defun bp:draw-obra (x0 y0 hs vs obra / tp nums n w h d tw xl i a yb r)
  (setq tp (bp:obra-tipo obra) nums (bp:nums-in (if obra obra "")))
  (cond
    ;; bueiro celular: n celulas W x H
    ((and (eq (car tp) 'CEL) nums)
     (setq n (cadr tp) w (car nums) h (if (cadr nums) (cadr nums) w)
           tw (* n w) xl (- x0 (* 0.5 tw hs)) yb (- y0 (* h vs)) i 0)
     (repeat n
       (setq a (+ xl (* i w hs)))
       (bp:pline (list (list a yb) (list (+ a (* w hs)) yb)
                       (list (+ a (* w hs)) y0) (list a y0))
                 *bp:lay-obra* T)
       (setq i (1+ i)))
     yb)
    ;; bueiro tubular: n tubos de diametro D (lente de 2 arcos, no exagero vertical)
    ((and (eq (car tp) 'TUB) nums)
     (setq n (cadr tp) d (car nums)
           tw (+ (* n d) (* (1- n) *bp:tub-gap* d))
           xl (- x0 (* 0.5 tw hs)) yb (- y0 (* d vs)) i 0)
     (repeat n
       (bp:lens (+ xl (* (+ (* i d (+ 1.0 *bp:tub-gap*)) (* 0.5 d)) hs))
                y0 (* d vs) (* d hs) *bp:lay-obra*)
       (setq i (1+ i)))
     yb)
    ;; outros (ponte etc.): marcador em cruz
    (t
     (setq r (* 0.5 *bp:txth*))
     (bp:pline (list (list (- x0 r) y0) (list (+ x0 r) y0)) *bp:lay-obra* nil)
     (bp:pline (list (list x0 (- y0 r)) (list x0 (+ y0 r))) *bp:lay-obra* nil)
     (- y0 r))))

(defun bp:label (rec sta elev desc / l v)
  (setq l (list (strcat "Estaca: "
                        (if rec (strcat (bp:get "EST" rec) "+" (bp:fmt (bp:get "FRAC" rec) 2))
                                (bp:estaca-str sta)))))
  (if (and desc (/= desc "")) (setq l (cons desc l)))
  (if (and rec (/= (bp:get "OBRA" rec) ""))
    (setq l (cons (strcat "Obra projetada: " (bp:get "OBRA" rec)) l)))
  (if (and rec (setq v (bp:get "L" rec)))
    (setq l (cons (strcat "L: " (bp:fmt-trim v 2) "m") l)))
  (if (and rec (setq v (bp:get "COTA" rec)))
    (setq l (cons (strcat "Cota montante: " (bp:fmt v 3)) l))
    (setq l (cons (strcat "Cota: " (bp:fmt elev 3)) l)))
  (if (and rec (setq v (bp:get "INC" rec)))
    (setq l (cons (strcat "Inclina\\U+00E7\\U+00E3o: "
                          (if (vl-string-search "," (setq v (bp:fmt-trim v 3)))
                            v (strcat v ",0"))
                          "%")
                  l)))
  (bp:join (reverse l) "\\P"))

;; ----------------------------- COMANDO ----------------------------------
(defun c:BUEIROPERFIL (/ *error* acdoc oldcmd civ pv al fcad fcogo recs cogos fonte soassoc
                         items so2 sta elev rec desc xy p nums pvxy pvxy2 hs vs
                         cnt nperf fora nskip r ybot ssp)
  (defun *error* (m)
    (if oldcmd (setvar "CMDECHO" oldcmd))
    (if acdoc (vla-EndUndoMark acdoc))
    (if (not (wcmatch (strcase m) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " m)))
    (princ))
  (setq acdoc (vla-get-ActiveDocument (vlax-get-acad-object))
        oldcmd (getvar "CMDECHO")
        cnt 0 nperf 0)
  (vla-StartUndoMark acdoc)
  (setvar "CMDECHO" 0)
  (cond
    ((not (setq civ (bp:civdoc)))
     (princ "\nNao foi possivel acessar a API COM do Civil 3D."))
    ((not (setq pv (bp:sel-pv)))
     (princ "\nNenhuma vista de perfil selecionada."))
    ((not (setq al (bp:get-align pv)))
     (princ "\nAlinhamento nao definido."))
    ((not (setq recs (bp:pick-files)))
     (princ "\nNenhuma obra valida encontrada no cadastro."))
    (t
     (setq fcogo (cadr recs) fcad (caddr recs) recs (car recs))
     (princ (strcat "\n" (itoa (length recs)) " obra(s) lida(s) do cadastro. Eixo: "
                    (vl-princ-to-string (vlax-get al 'Name))))
     (if (null fcogo)
       (progn
         (princ "\n>> Passo 2: selecione o COGOpoints.csv (PNEZD) ou Cancelar para usar apenas o cadastro.")
         (setq fcogo (getfiled "Passo 2 - COGOpoints.csv (PNEZD)  -  Cancelar = usar apenas o cadastro"
                               (strcat (vl-filename-directory fcad) "\\") "csv" 0))))
     (if fcogo (setq cogos (bp:read-cogo fcogo)))
     (if (and fcogo (null cogos))
       (princ "\nAviso: nenhum ponto valido no COGOpoints; usando apenas o cadastro."))
     ;; ---------- monta a lista de itens: (estaca elevacao registro descCogo) ----------
     (if cogos
       (progn
         (initget "Cogo Montante")
         (setq fonte (getkword "\nElevacao do ponto/obra [Cogo/Montante] <Cogo>: "))
         (if (null fonte) (setq fonte "Cogo"))
         (initget "Sim Nao")
         (setq soassoc (getkword "\nProcessar apenas pontos associados a uma obra do cadastro? [Sim/Nao] <Sim>: "))
         (if (null soassoc) (setq soassoc "Sim"))
         (foreach c cogos
           (if (setq so2 (bp:sta-off al (nth 2 c) (nth 1 c)))
             (progn
               (setq sta (car so2) rec (bp:nearest sta recs))
               (if (or rec (= soassoc "Nao"))
                 (setq items (cons (list sta
                                         (if (and (= fonte "Montante") rec (bp:get "COTA" rec))
                                           (bp:get "COTA" rec)
                                           (nth 3 c))
                                         rec
                                         (nth 4 c))
                                   items))
                 (setq nskip (cons (strcat "P" (nth 0 c) " (" (bp:estaca-str sta) ")") nskip))))
             (setq nskip (cons (strcat "P" (nth 0 c) " (fora do eixo)") nskip)))))
       (foreach rc recs
         (if (bp:get "COTA" rc)
           (setq items (cons (list (bp:get "STA" rc) (bp:get "COTA" rc) rc nil) items)))))
     (setq items (reverse items))
     ;; ---------- processa ----------
     (bp:layer *bp:layer* *bp:cor-layer*)
     (setq ssp (ssadd))
     (foreach it items
       (setq sta  (nth 0 it) elev (nth 1 it) rec (nth 2 it)
             desc (cond ((and rec (/= (bp:get "DESC" rec) "")) (bp:get "DESC" rec))
                        ((bp:txt-p (nth 3 it)) (nth 3 it))
                        (t "")))
       ;; COGO point no eixo (offset 0) com a elevacao
       (if (setq xy (bp:pt-on-align al sta 0.0))
         (if (setq p (bp:add-point civ (car xy) (cadr xy) elev
                                   (if rec (strcat (bp:get "BACIA" rec) " - " desc) desc)
                                   (if rec (bp:get "BUEIRO" rec))))
           (setq nums (cons (vlax-get p 'Number) nums) cnt (1+ cnt)
                 ssp  (ssadd (vlax-vla-object->ename p) ssp))))
       ;; desenho na vista de perfil
       (setq pvxy  (bp:pv-xy pv sta elev)
             pvxy2 (cond ((bp:pv-xy pv (+ sta 1.0) (+ elev 1.0)))
                         ((bp:pv-xy pv (- sta 1.0) (- elev 1.0)))))
       (if (and pvxy pvxy2 (bp:in-pv pv sta))
         (progn
           (setq hs (abs (- (car pvxy2) (car pvxy)))
                 vs (abs (- (cadr pvxy2) (cadr pvxy))))
           (setq ybot (bp:draw-obra (car pvxy) (cadr pvxy) hs vs (if rec (bp:get "OBRA" rec) "")))
           (bp:mtext (list (car pvxy) (- ybot *bp:txtgap*))
                     (bp:label rec sta elev desc) *bp:lay-leg*)
           (setq nperf (1+ nperf)))
         (setq fora (cons (bp:estaca-str sta) fora))))
     ;; grupo de pontos
     (if nums
       (if (vl-catch-all-error-p
             (setq r (vl-catch-all-apply 'bp:add-to-group (list civ (reverse nums)))))
         (princ (strcat "\nAviso: nao foi possivel atualizar o grupo de pontos: "
                        (vl-catch-all-error-message r)))))
     ;; projecao automatica dos COGO points na vista de perfil
     (if (and *bp:projetar* (> (sslength ssp) 0) *bp:pvpick*)
       (bp:projetar ssp *bp:pvpick*))
     ;; relatorio
     (princ (strcat "\n" (itoa cnt) " COGO point(s) criado(s) no eixo; "
                    (itoa nperf) " obra(s) desenhada(s) no perfil."))
     (if fora (princ (strcat "\nFora do trecho da vista de perfil: " (bp:join (reverse fora) ", "))))
     (if nskip (princ (strcat "\nPontos COGO sem obra correspondente (ignorados): "
                              (bp:join (reverse nskip) ", "))))))
  (setvar "CMDECHO" oldcmd)
  (vla-EndUndoMark acdoc)
  (princ))

(princ "\nBUEIROS_PERFIL carregado. Comando: BUEIROPERFIL")
(princ)
