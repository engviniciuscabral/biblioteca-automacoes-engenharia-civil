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
;;;    abaixo do COGO point, ja na escala/exagero da vista, com as espessuras
;;;    das tabelas (celular: d/a/b por secao L e aterro h; tubular: quadro de
;;;    dimensoes D/A/B/e), e a legenda:
;;;       Estaca / Descricao / Obra projetada / L / Cota montante / Inclinacao
;;; 4) Coloca os pontos criados no grupo de pontos *bp:grupo*.
;;; =====================================================================

(vl-load-com)

;; ----------------------------- CONFIGURACAO -----------------------------
(setq *bp:estaca*     20.0)          ; metros por estaca
(setq *bp:txth*        2.0)          ; altura do texto da legenda (unid. desenho)
(setq *bp:txtgap*      4.0)          ; distancia do fundo da obra ao topo da legenda
(setq *bp:ref-cota*   "TOPO")        ; "TOPO"  = topo da parede INTERNA no COGO point (obra abaixo)
                                     ; "FUNDO" = fundo da parede interna (soleira/geratriz inf.) no COGO point
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
(defun bp:read-cadastro (f quiet / lines hdr dl fl ie id io ic ii il ib ia iat est frac en p r)
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
                 iat (bp:col hdr '("ATERRO*"))
                 ib  (bp:col hdr '("COD*BUEIRO*"))
                 ia  (bp:col hdr '("COD*BACIA*")))
           ;; padroes caso algum titulo nao seja encontrado
           (if (null ie) (setq ie 2))  (if (null id) (setq id 5))
           (if (null io) (setq io 7))  (if (null ic) (setq ic 16))
           (if (null ii) (setq ii 15)) (if (null il) (setq il 19))
           (if (null ib) (setq ib 1))  (if (null ia) (setq ia 0))
           (if (null iat) (setq iat 21)))))
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
                             (cons "L"      (bp:num-br (nth il fl)))
                             (cons "ATERRO" (bp:num-br (nth iat fl))))
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

;; ----------------------------- TABELAS ----------------------------------
;; Bueiros celulares (BSCC/BDCC/BTCC) - por secao L (cm) e faixa de aterro h (cm):
;; faixas: 0-100, 100-250, 250-500, 500-750, 750-1000, 1000-1250, 1250-1500
;; cada faixa: ((d a b)SIMPLES (d a b)DUPLO (d a b)TRIPLO)  [cm]
;;   d = espessura de paredes e lajes, a = misula externa, b = misula na parede interna
;;   A = n*L + (n+1)*d ; B = H + 2d ; C (lastro) = A + 30
(setq *bp:tab-cel*
  '((150 ((15 10 0) (15 10 30) (15 10 30)) ((15 10 0) (15 10 30) (15 10 30))
         ((15 10 0) (15 10 30) (15 10 30)) ((15 10 0) (15 10 30) (15 10 30))
         ((20 15 0) (15 10 30) (15 10 30)) ((20 15 0) (20 15 45) (20 15 45))
         ((20 15 0) (20 15 45) (20 15 45)))
    (200 ((15 10 0) (15 10 30) (15 10 30)) ((15 10 0) (15 10 30) (15 10 30))
         ((20 15 0) (15 10 30) (15 10 30)) ((20 15 0) (20 15 45) (20 15 45))
         ((25 15 0) (20 15 45) (20 15 45)) ((25 15 0) (25 15 45) (25 15 45))
         ((25 15 0) (25 15 45) (25 15 45)))
    (250 ((20 15 0) (15 15 45) (15 15 45)) ((20 15 0) (15 15 45) (15 15 45))
         ((20 15 0) (20 15 45) (20 15 45)) ((25 15 0) (20 15 45) (20 15 45))
         ((25 15 0) (25 15 45) (25 15 45)) ((30 25 0) (25 15 45) (25 15 45))
         ((35 25 0) (25 15 45) (25 15 45)))
    (300 ((25 15 0) (20 15 45) (20 15 45)) ((25 15 0) (20 15 45) (20 15 45))
         ((30 25 0) (25 15 45) (25 15 45)) ((30 25 0) (25 15 45) (25 15 45))
         ((35 25 0) (30 25 75) (30 25 75)) ((35 25 0) (30 25 75) (30 25 75))
         ((40 30 0) (30 25 75) (30 25 75)))))

;; Bueiros tubulares (BSTC/BDTC/BTTC) - quadro de dimensoes (cm): (D A B e)
;;   e = parede do tubo, B = espaco entre tubos, A = altura do berco
;;   C = D + 2e + 20 ; E = C + (D+2e) + B ; F = E + (D+2e) + B
(setq *bp:tab-tub*
  '((40 25 20 6) (60 30 20 8) (80 35 20 10) (100 40 25 12) (120 45 30 13) (150 50 30 14)))

(defun bp:faixa (hat / h)
  (setq h (if hat (* 100.0 hat) 0.0))
  (cond ((<= h 100.0) 0) ((<= h 250.0) 1) ((<= h 500.0) 2) ((<= h 750.0) 3)
        ((<= h 1000.0) 4) ((<= h 1250.0) 5) (t 6)))

;; retorna (d a b) em metros
(defun bp:cel-dims (L n hat / tab)
  (setq tab (cdr (assoc (fix (+ (* L 100.0) 0.5)) *bp:tab-cel*)))
  (if tab
    (mapcar '(lambda (x) (/ x 100.0)) (nth (min (1- n) 2) (nth (bp:faixa hat) tab)))
    (progn
      (princ (strcat "\nAviso: celula L=" (bp:fmt L 2)
                     " m fora das tabelas (1,5/2,0/2,5/3,0); usando d=0,20 a=0,15 b=0,45."))
      '(0.20 0.15 0.45))))

;; retorna (A B e) em metros
(defun bp:tub-dims (D / dc best)
  (setq dc (* D 100.0))
  (foreach x *bp:tab-tub*
    (if (or (null best) (< (abs (- (car x) dc)) (abs (- (car best) dc)))) (setq best x)))
  (if (> (abs (- (car best) dc)) 0.5)
    (princ (strcat "\nAviso: diametro " (bp:fmt D 2) " m fora do quadro; usando dimensoes do D="
                   (itoa (car best)) " cm.")))
  (mapcar '(lambda (x) (/ x 100.0)) (cdr best)))

;; ----------------------------- DESENHO DAS OBRAS ------------------------
(defun bp:rect (x y w h)
  (bp:pline (list (list x y) (list (+ x w) y) (list (+ x w) (+ y h)) (list x (+ y h)))
            *bp:layer* T))

;; bueiro celular: n celulas L x H (m), paredes/lajes de espessura d. retorna o Y mais baixo
(defun bp:draw-cel (x0 y0 hs vs n L H hat / esp wext hext ytop ybot xl i)
  (setq esp  (car (bp:cel-dims L n hat))                 ; d
        wext (+ (* n L) (* (1+ n) esp))                  ; A
        hext (+ H (* 2.0 esp))                           ; B
        ytop (if (= (strcase *bp:ref-cota*) "FUNDO") (+ y0 (* (+ H esp) vs)) (+ y0 (* esp vs)))
        ybot (- ytop (* hext vs))
        xl   (- x0 (* 0.5 wext hs)))
  (bp:rect xl ybot (* wext hs) (* hext vs))              ; parede externa
  (setq i 0)
  (repeat n                                              ; paredes internas (celulas)
    (bp:rect (+ xl (* (+ esp (* i (+ L esp))) hs)) (+ ybot (* esp vs)) (* L hs) (* H vs))
    (setq i (1+ i)))
  ybot)

;; bueiro tubular: n tubos de diametro D (m), parede de espessura e. retorna o Y mais baixo
(defun bp:draw-tub (x0 y0 hs vs n D / dm esp ew dext wt ytop xl i cx)
  (setq dm   (bp:tub-dims D) esp (cadr dm) ew (caddr dm) ; B = espaco entre tubos, e
        dext (+ D (* 2.0 ew))
        wt   (+ (* n dext) (* (1- n) esp))
        ytop (if (= (strcase *bp:ref-cota*) "FUNDO") (+ y0 (* (+ D ew) vs)) (+ y0 (* ew vs)))
        xl   (- x0 (* 0.5 wt hs)) i 0)
  (repeat n
    (setq cx (+ xl (* (+ (* 0.5 dext) (* i (+ dext esp))) hs)))
    (bp:lens cx ytop (* dext vs) (* dext hs) *bp:layer*)                      ; parede externa
    (bp:lens cx (- ytop (* ew vs)) (* D vs) (* D hs) *bp:layer*)              ; parede interna
    (setq i (1+ i)))
  (- ytop (* dext vs)))

;; m ou cm -> m
(defun bp:m (x) (if (and x (> x 10.0)) (/ x 100.0) x))

;; x0,y0 = estaca/cota (COGO point) na vista ; hs,vs = unid. desenho por metro (H e V)
;; hat = aterro acima da geratriz superior (m), define a faixa das tabelas
;; retorna o Y mais baixo desenhado (para posicionar a legenda)
(defun bp:draw-obra (x0 y0 hs vs obra hat / tp nums r)
  (setq tp (bp:obra-tipo obra) nums (mapcar 'bp:m (bp:nums-in (if obra obra ""))))
  (cond
    ((and (eq (car tp) 'CEL) nums)
     (bp:draw-cel x0 y0 hs vs (cadr tp) (car nums)
                  (if (cadr nums) (cadr nums) (car nums)) hat))
    ((and (eq (car tp) 'TUB) nums)
     (bp:draw-tub x0 y0 hs vs (cadr tp) (car nums)))
    ;; outros (ponte etc.): marcador em cruz
    (t
     (setq r (* 0.5 *bp:txth*))
     (bp:pline (list (list (- x0 r) y0) (list (+ x0 r) y0)) *bp:layer* nil)
     (bp:pline (list (list x0 (- y0 r)) (list x0 (+ y0 r))) *bp:layer* nil)
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
           (setq ybot (bp:draw-obra (car pvxy) (cadr pvxy) hs vs
                                    (if rec (bp:get "OBRA" rec) "")
                                    (if rec (bp:get "ATERRO" rec))))
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