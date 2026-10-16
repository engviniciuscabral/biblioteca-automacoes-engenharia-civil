;; BACIAS_QUADRO.lsp
;; 1) Cria uma MULTILEADER para cada bacia: ponta dentro da bacia e o numero
;;    numa bolinha (sem mascara), lendo as layers que comecam com BC (BC01 -> "01").
;;    A bolinha e movimentavel pelo grip; a linha acompanha.
;; 2) Gera um QUADRO RESUMO (tabela do AutoCAD) com os dados do CSV da planilha.
;;
;; Uso:
;; 1. No Excel, salve a aba como CSV separado por ponto e virgula
;;    (com "BACIA" no nome e na mesma pasta do DWG, ou escolha com BACIAS_CSV).
;; 2. APPLOAD neste arquivo.
;; 3. Rode BACIAS_QUADRO: numera todas as bacias e pede o ponto da tabela.
;;
;; Comandos:
;;   BACIAS_QUADRO       -> numera as bacias + cria/atualiza a tabela
;;   BACIAS_NUMERAR      -> so a numeracao
;;   BACIAS_TABELA       -> so a tabela
;;   BACIAS_CSV          -> escolher o CSV manualmente
;;   BACIAS_RECARREGAR   -> esquece o CSV carregado (use apos alterar a planilha)
;;
;; Rodando de novo:
;; - Numeros que ja existem NAO sao movidos (so tamanho/cor sao atualizados).
;; - A tabela antiga e substituida pela nova no MESMO lugar.
;;
;;   BACIAS_APAGAR_BLOCOS -> apaga os blocos BACIA_NUM_xx da versao anterior

(vl-load-com)

;; ================= CONFIGURACAO =================
;; Numeracao
(setq *bq:altura-num*   60.0)            ; altura do numero
(setq *bq:raio-fator*   1.4)             ; raio da bolinha = fator x altura
(setq *bq:layer-num*    "NUMERO BACIAS") ; layer das multileaders
(setq *bq:cor-num*      6)               ; 6 = magenta (linha e bolinha)
(setq *bq:afast-num*    4.0)             ; distancia inicial da bolinha (x altura)
(setq *bq:seta*         3)               ; ponta: 3 = ponto, 19 = nenhuma, 0 = seta
(setq *bq:tam-seta*     0.5)             ; tamanho da ponta (x altura)
(setq *bq:tag-block*    "BACIA_TAG")     ; bloco da bolinha usado pela multileader

;; Tabela
(setq *bq:altura-tab*   60.0)            ; altura do texto da tabela
(setq *bq:altura-tit*   75.0)            ; altura do titulo
(setq *bq:layer-tab*    "TABELA BACIAS")
(setq *bq:cor-tab*      7)               ; 7 = branco
(setq *bq:estilo*       "ARIAL")         ; estilo de texto (se existir no DWG)
(setq *bq:titulo*       "QUADRO RESUMO DAS BACIAS HIDROGR\\U+00C1FICAS")

;; Colunas da tabela: (titulo chave casas-decimais)
;; casas = nil -> texto como esta no CSV
;; Chaves disponiveis: NUM COD EST CURSO AREA COMP DESN DECL TC CCN METODO Q15 Q25 Q50 Q100
(setq *bq:colunas*
  '(("N\\U+00BA"                  "NUM"   nil)
    ("Estaca"                     "EST"   nil)
    ("Curso d'\\U+00E1gua"        "CURSO" nil)
    ("\\U+00C1rea (km\\U+00B2)"   "AREA"  2)
    ("Comp. Talv. (km)"           "COMP"  2)
    ("Desn\\U+00EDvel (m)"        "DESN"  2)
    ("i bacia (%)"                "DECL"  2)
    ("Tc (h)"                     "TC"    2)
    ;; descomente para incluir:
    ;; ("M\\U+00E9todo"            "METODO" nil)
    ;; ("C / CN"                   "CCN"   2)
    ;; ("Q25 (m\\U+00B3/s)"        "Q25"   2)
    ;; ("Q50 (m\\U+00B3/s)"        "Q50"   2)
   )
)
;; ================================================

(setq *bq:app* "BACIAS_QUADRO")
(setq *bq:csv-path* nil)
(setq *bq:rows* nil)

;; ---------- utilidades de texto ----------

(defun bq:trim (s)
  (if s (vl-string-trim " \t\r\n\"" s) "")
)

(defun bq:replace-all (s old new / p)
  (while (setq p (vl-string-search old s))
    (setq s (strcat (substr s 1 p) new (substr s (+ p (strlen old) 1))))
  )
  s
)

(defun bq:strip-bom (s)
  (while (and (> (strlen s) 0) (member (ascii s) '(65279 239 187 191)))
    (setq s (substr s 2))
  )
  s
)

(defun bq:norm (s / r)
  (setq r (strcase (bq:trim (if s s ""))))
  (foreach ch '(" " "." "," ";" ":" "/" "\\" "-" "_" "(" ")" "[" "]" "\t")
    (setq r (bq:replace-all r ch ""))
  )
  r
)

;; posicao do primeiro digito (1-based) ou nil
(defun bq:first-digit (s / i pos)
  (setq i 1)
  (while (and (not pos) (<= i (strlen s)))
    (if (wcmatch (substr s i 1) "#") (setq pos i))
    (setq i (1+ i))
  )
  pos
)

;; "BC 01", "BC01", "bc-1" -> "BC1"
(defun bq:code-key (s / n p num)
  (setq n (bq:norm s))
  (setq p (bq:first-digit n))
  (if p
    (progn
      (setq num (substr n p))
      (if (wcmatch num "*[~0-9]*")
        n
        (strcat (substr n 1 (1- p)) (itoa (atoi num)))
      )
    )
    n
  )
)

;; "BC01" -> "01"
(defun bq:num-text (s / n p)
  (setq n (bq:norm s))
  (setq p (bq:first-digit n))
  (if p (substr n p) n)
)

(defun bq:hex2 (n / d)
  (setq d "0123456789ABCDEF")
  (strcat (substr d (1+ (/ n 16)) 1) (substr d (1+ (rem n 16)) 1))
)

;; acentos -> \U+00XX (independe da codificacao do CSV)
(defun bq:mtext-safe (s / i ch c out)
  (setq i 1 out "")
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (setq c (ascii ch))
    (setq out (strcat out (if (and (> c 159) (< c 256)) (strcat "\\U+00" (bq:hex2 c)) ch)))
    (setq i (1+ i))
  )
  out
)

;; comprimento visivel (conta \U+XXXX como 1 caractere)
(defun bq:vis-len (s / i n)
  (setq i 1 n 0)
  (while (<= i (strlen s))
    (if (= (substr s i 3) "\\U+")
      (setq i (+ i 7))
      (setq i (1+ i))
    )
    (setq n (1+ n))
  )
  n
)

(defun bq:wc-escape (s / i ch out)
  (setq i 1 out "")
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (setq out (strcat out (if (vl-string-search ch "#@.*?~[]`,") (strcat "`" ch) ch)))
    (setq i (1+ i))
  )
  out
)

;; ---------- leitura do CSV ----------

(defun bq:split-csv (line sep / i ch inq cur out next)
  (setq i 1 inq nil cur "" out '())
  (while (<= i (strlen line))
    (setq ch (substr line i 1))
    (cond
      ((= ch "\"")
       (setq next (if (< i (strlen line)) (substr line (+ i 1) 1) ""))
       (if (and inq (= next "\""))
         (progn (setq cur (strcat cur "\"")) (setq i (+ i 1)))
         (setq inq (not inq))
       )
      )
      ((and (= ch sep) (not inq))
       (setq out (cons cur out))
       (setq cur "")
      )
      (T (setq cur (strcat cur ch)))
    )
    (setq i (+ i 1))
  )
  (reverse (cons cur out))
)

(defun bq:detect-sep (line)
  (if (> (length (bq:split-csv line ";")) (length (bq:split-csv line ",")))
    ";"
    ","
  )
)

(defun bq:contains-all (s parts / ok)
  (setq ok T)
  (foreach p parts
    (if (not (vl-string-search p s)) (setq ok nil))
  )
  ok
)

(defun bq:find-col (headers parts / i idx)
  (setq i 0)
  (foreach h headers
    (if (and (not idx) (bq:contains-all h parts)) (setq idx i))
    (setq i (1+ i))
  )
  idx
)

(defun bq:find-col-eq (headers name / i idx)
  (setq i 0)
  (foreach h headers
    (if (and (not idx) (equal h name)) (setq idx i))
    (setq i (1+ i))
  )
  idx
)

(defun bq:col-or (idx default)
  (if idx idx default)
)

;; mapeia colunas pelo cabecalho (sem depender de acentos); padrao = posicao da planilha
(defun bq:map-cols (h)
  (list
    (cons "COD"    (bq:col-or (bq:find-col h '("CODBACIA")) 0))
    (cons "EST"    (bq:col-or (bq:find-col h '("ESTACA")) 2))
    (cons "AREA"   (bq:col-or (bq:find-col h '("REA" "KM")) 6))
    (cons "COMP"   (bq:col-or (bq:find-col h '("COMPRIMENTO" "TALVEG")) 7))
    (cons "DESN"   (bq:col-or (bq:find-col h '("DESN")) 8))
    (cons "DECL"   (bq:col-or (bq:find-col h '("EFETIVA" "BACIA")) 9))
    (cons "TC"     (bq:col-or (bq:find-col-eq h "TCH") 10))
    (cons "CCN"    (bq:col-or (bq:find-col-eq h "CCN") 11))
    (cons "METODO" (bq:col-or (bq:find-col h '("TODO")) 12))
    (cons "Q15"    (bq:col-or (bq:find-col h '("QM" "15ANOS")) 17))
    (cons "Q25"    (bq:col-or (bq:find-col h '("QM" "25ANOS")) 18))
    (cons "Q50"    (bq:col-or (bq:find-col h '("QM" "50ANOS")) 19))
    (cons "Q100"   (bq:col-or (bq:find-col h '("QM" "100ANOS")) 20))
    (cons "CURSO"  (bq:find-col h '("CURSOD")))
  )
)

;; linhas = (mapa-de-colunas . campos); cada cabecalho "COD. BACIA" atualiza o mapa
(defun bq:read-csv (path / fh line sep hsep fields nfields cols rows)
  (setq fh (open path "r"))
  (if fh
    (progn
      (while (setq line (read-line fh))
        (setq line (bq:strip-bom line))
        (setq sep (if hsep hsep (bq:detect-sep line)))
        (setq fields (bq:split-csv line sep))
        (setq nfields (mapcar 'bq:norm fields))
        (cond
          ((member "CODBACIA" nfields)
           (setq cols (bq:map-cols nfields))
           (setq hsep sep))
          ((and cols (wcmatch (car nfields) "BC*"))
           (setq rows (cons (cons cols (mapcar 'bq:trim fields)) rows)))
        )
      )
      (close fh)
      (reverse rows)
    )
  )
)

(defun bq:find-project-csv (/ folder files chosen)
  (setq folder (getvar "DWGPREFIX"))
  (if (and folder (not (equal folder "")))
    (progn
      (setq files (vl-directory-files folder "*.csv" 1))
      (foreach f files
        (if (and (not chosen) (vl-string-search "BACIA" (strcase f)))
          (setq chosen f)
        )
      )
      (if chosen (strcat folder chosen))
    )
  )
)

(defun bq:csv-path (/ project-csv)
  (cond
    ((and *bq:csv-path* (findfile *bq:csv-path*)) *bq:csv-path*)
    ((setq project-csv (bq:find-project-csv)) (setq *bq:csv-path* project-csv))
    (T (setq *bq:csv-path* (getfiled "Selecione o CSV das bacias" (getvar "DWGPREFIX") "csv" 0)))
  )
)

(defun bq:load-rows (/ csv)
  (if (and *bq:rows* *bq:csv-path* (findfile *bq:csv-path*))
    *bq:rows*
    (progn
      (setq csv (bq:csv-path))
      (if csv
        (progn
          (princ (strcat "\nLendo CSV: " csv))
          (setq *bq:rows* (bq:read-csv csv))
          (princ (strcat "\nBacias carregadas: " (itoa (length *bq:rows*))))
          (if (not *bq:rows*) (setq *bq:csv-path* nil))
        )
      )
      *bq:rows*
    )
  )
)

;; ---------- valores ----------

(defun bq:field (row idx / fields v)
  (setq fields (cdr row))
  (if (and idx (>= idx 0) (< idx (length fields)))
    (setq v (bq:trim (nth idx fields)))
  )
  (if (or (not v) (equal v "") (= (substr v 1 1) "#")) "-" v)
)

(defun bq:val (row key)
  (bq:field row (cdr (assoc key (car row))))
)

(defun bq:find-row (rows codigo / key found)
  (setq key (bq:code-key codigo))
  (foreach r rows
    (if (equal (bq:code-key (bq:val r "COD")) key) (setq found r))
  )
  found
)

(defun bq:number-text (value decimals / raw out old-dimzin)
  (if (or (not value) (equal value "-"))
    "-"
    (progn
      (setq raw (bq:trim (bq:replace-all (bq:replace-all value "," ".") "%" "")))
      (if (distof raw 2)
        (progn
          (setq old-dimzin (getvar "DIMZIN"))
          (setvar "DIMZIN" 0)
          (setq out (rtos (distof raw 2) 2 decimals))
          (setvar "DIMZIN" old-dimzin)
          (bq:replace-all out "." ",")
        )
        value
      )
    )
  )
)

(defun bq:fmt-estaca (row / i e s d)
  (setq i (cdr (assoc "EST" (car row))))
  (setq e (bq:field row i))
  (setq s (bq:field row (+ i 1)))
  (setq d (bq:field row (+ i 2)))
  (cond
    ((equal d "-") e)
    ((equal s "-") (strcat e "+" (bq:number-text d 2)))
    (T (strcat e s (bq:number-text d 2)))
  )
)

(defun bq:cell-value (row key dec)
  (cond
    ((= key "NUM") (bq:num-text (bq:val row "COD")))
    ((= key "EST") (bq:fmt-estaca row))
    (dec (bq:number-text (bq:val row key) dec))
    (T (bq:mtext-safe (bq:val row key)))
  )
)

;; ---------- geometria da bacia ----------

(defun bq:curve-length (e)
  (vlax-curve-getDistAtParam e (vlax-curve-getEndParam e))
)

(defun bq:closed-p (e)
  (or (vlax-curve-isClosed e)
      (equal (vlax-curve-getStartPoint e) (vlax-curve-getEndPoint e) 1e-6))
)

;; polyline fechada de maior area na layer; se nao houver, a curva mais longa
(defun bq:basin-entity (layer / ss i e v best-c best-cv best-o best-ov)
  (setq ss (ssget "_X"
             (list '(0 . "LWPOLYLINE,POLYLINE,SPLINE,CIRCLE,ELLIPSE,ARC,LINE")
                   (cons 8 (bq:wc-escape layer))
                   '(410 . "Model"))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq e (ssname ss i))
        (if (not (vl-catch-all-error-p (vl-catch-all-apply 'bq:curve-length (list e))))
          (if (bq:closed-p e)
            (progn
              (setq v (vl-catch-all-apply 'vlax-curve-getArea (list e)))
              (if (vl-catch-all-error-p v) (setq v 0.0))
              (if (or (not best-c) (> v best-cv)) (setq best-c e best-cv v))
            )
            (progn
              (setq v (bq:curve-length e))
              (if (or (not best-o) (> v best-ov)) (setq best-o e best-ov v))
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )
  (if best-c best-c best-o)
)

(defun bq:curve-points (e n / L i p pts)
  (setq L (bq:curve-length e) i 0)
  (while (< i n)
    (setq p (vlax-curve-getPointAtDist e (* L (/ (float i) n))))
    (if p (setq pts (cons p pts)))
    (setq i (1+ i))
  )
  (reverse pts)
)

(defun bq:edges (pts)
  (mapcar 'list pts (append (cdr pts) (list (car pts))))
)

(defun bq:centroid (pts / a cx cy cr p q n)
  (setq a 0.0 cx 0.0 cy 0.0)
  (foreach ed (bq:edges pts)
    (setq p (car ed) q (cadr ed))
    (setq cr (- (* (car p) (cadr q)) (* (car q) (cadr p))))
    (setq a  (+ a cr))
    (setq cx (+ cx (* (+ (car p) (car q)) cr)))
    (setq cy (+ cy (* (+ (cadr p) (cadr q)) cr)))
  )
  (if (> (abs a) 1e-9)
    (list (/ cx (* 3.0 a)) (/ cy (* 3.0 a)) 0.0)
    (progn
      (setq n (float (length pts)))
      (list (/ (apply '+ (mapcar 'car pts)) n) (/ (apply '+ (mapcar 'cadr pts)) n) 0.0)
    )
  )
)

(defun bq:inside-p (pt pts / in x y p q)
  (setq x (car pt) y (cadr pt))
  (foreach ed (bq:edges pts)
    (setq p (car ed) q (cadr ed))
    (if (and (/= (> (cadr p) y) (> (cadr q) y))
             (< x (+ (car p) (/ (* (- (car q) (car p)) (- y (cadr p))) (- (cadr q) (cadr p))))))
      (setq in (not in))
    )
  )
  in
)

(defun bq:scan-mid (y pts / xs p q best bw w)
  (foreach ed (bq:edges pts)
    (setq p (car ed) q (cadr ed))
    (if (/= (> (cadr p) y) (> (cadr q) y))
      (setq xs (cons (+ (car p) (/ (* (- (car q) (car p)) (- y (cadr p))) (- (cadr q) (cadr p)))) xs))
    )
  )
  (setq xs (vl-sort xs '<))
  (while (and xs (cdr xs))
    (setq w (- (cadr xs) (car xs)))
    (if (or (not bw) (> w bw)) (setq bw w best (/ (+ (car xs) (cadr xs)) 2.0)))
    (setq xs (cddr xs))
  )
  (if best (list best y 0.0))
)

;; ponto dentro da bacia (ou meio do talvegue se a curva for aberta)
(defun bq:anchor-point (e / pts c m)
  (if (bq:closed-p e)
    (progn
      (setq pts (bq:curve-points e 150))
      (setq c (bq:centroid pts))
      (cond
        ((bq:inside-p c pts) c)
        ((setq m (bq:scan-mid (cadr c) pts)) m)
        (T (car pts))
      )
    )
    (vlax-curve-getPointAtDist e (/ (bq:curve-length e) 2.0))
  )
)

;; ---------- desenho ----------

(defun bq:doc () (vla-get-ActiveDocument (vlax-get-acad-object)))

(defun bq:ensure-layer (doc name color / layers layer)
  (setq layers (vla-get-Layers doc))
  (setq layer (vl-catch-all-apply 'vla-Item (list layers name)))
  (if (vl-catch-all-error-p layer)
    (progn
      (setq layer (vla-Add layers name))
      (vl-catch-all-apply 'vla-put-Color (list layer color))
    )
  )
  name
)

(defun bq:put (obj prop val)
  (vl-catch-all-apply 'vlax-put-property (list obj prop val))
)

(defun bq:layers-bc (/ rec name out)
  (setq rec (tblnext "LAYER" T))
  (while rec
    (setq name (cdr (assoc 2 rec)))
    (if (and (wcmatch (bq:norm name) "BC#*") (not (vl-string-search "|" name)))
      (setq out (cons name out))
    )
    (setq rec (tblnext "LAYER"))
  )
  (vl-sort out '<)
)

(defun bq:join (lst / out)
  (setq out "")
  (foreach s lst (setq out (if (equal out "") s (strcat out ", " s))))
  out
)

(defun bq:put-aci (obj prop idx / c)
  (setq c (vl-catch-all-apply 'vlax-get-property (list obj prop)))
  (if (not (vl-catch-all-error-p c))
    (progn
      (vl-catch-all-apply 'vla-put-ColorIndex (list c idx))
      (bq:put obj prop c)
    )
  )
)

(defun bq:set-xdata (obj val)
  (if (not (tblsearch "APPID" *bq:app*)) (regapp *bq:app*))
  (vl-catch-all-apply 'vla-SetXData
    (list obj
      (vlax-make-variant (vlax-safearray-fill (vlax-make-safearray vlax-vbInteger '(0 . 1)) '(1001 1000)))
      (vlax-make-variant (vlax-safearray-fill (vlax-make-safearray vlax-vbVariant '(0 . 1)) (list *bq:app* val)))
    )
  )
)

;; Bloco da bolinha usado pelas multileaders: circulo + atributo NUM (sem mascara).
;; Se ja existe, so ajusta raio/altura (nao recria, para nao quebrar as chamadas).
(defun bq:tag-block (doc / blks blk org h c att)
  (setq blks (vla-get-Blocks doc))
  (setq org (vlax-3d-point '(0.0 0.0 0.0)))
  (setq h *bq:altura-num*)
  (setq blk (vl-catch-all-apply 'vla-Item (list blks *bq:tag-block*)))
  (if (vl-catch-all-error-p blk)
    (progn
      (setq blk (vla-Add blks org *bq:tag-block*))
      (setq c (vla-AddCircle blk org (* *bq:raio-fator* h)))
      (bq:put c 'Layer "0")
      (bq:put c 'Color 0)                                  ; PorBloco
      (setq att (vla-AddAttribute blk h 0 "Numero" org "NUM" "00"))
      (bq:put att 'Layer "0")
      (bq:put att 'Color 0)
      (bq:put att 'StyleName *bq:estilo*)
      (bq:put att 'Alignment acAlignmentMiddleCenter)
      (bq:put att 'TextAlignmentPoint org)
    )
    (vlax-for o blk
      (cond
        ((= (vla-get-ObjectName o) "AcDbCircle") (bq:put o 'Radius (* *bq:raio-fator* h)))
        ((= (vla-get-ObjectName o) "AcDbAttributeDefinition") (bq:put o 'Height h))
      )
    )
  )
  blk
)

(defun bq:tag-att (blk / att)
  (vlax-for o blk
    (if (= (vla-get-ObjectName o) "AcDbAttributeDefinition") (setq att o))
  )
  att
)

(defun bq:set-att (ml att val)
  (if (vlax-method-applicable-p ml 'SetBlockAttributeValue32)
    (vl-catch-all-apply 'vla-SetBlockAttributeValue32 (list ml (vla-get-ObjectID32 att) val))
    (vl-catch-all-apply 'vla-SetBlockAttributeValue (list ml (vla-get-ObjectID att) val))
  )
)

(defun bq:style-num-leader (ml)
  (bq:put ml 'Layer *bq:layer-num*)
  (bq:put ml 'ArrowheadType *bq:seta*)
  (bq:put ml 'ArrowheadSize (* *bq:tam-seta* *bq:altura-num*))
  (bq:put ml 'EnableDogleg :vlax-false)
  (bq:put ml 'BlockConnectionType 0)        ; liga na borda da bolinha
  (bq:put ml 'BlockScale 1.0)
  (bq:put-aci ml 'LeaderLineColor *bq:cor-num*)
  (bq:put-aci ml 'BlockColor *bq:cor-num*)
)

;; multileader: ponta dentro da bacia, bolinha com o numero afastada
(defun bq:num-leader (ms att p-arrow p-tag num cod / arr ml)
  (setq arr (vlax-make-safearray vlax-vbDouble '(0 . 5)))
  (vlax-safearray-fill arr
    (list (car p-arrow) (cadr p-arrow) 0.0 (car p-tag) (cadr p-tag) 0.0))
  (setq ml (vla-AddMLeader ms (vlax-make-variant arr) 0))
  (bq:put ml 'ScaleFactor 1.0)
  (bq:put ml 'ContentType 1)                 ; conteudo = bloco
  (bq:put ml 'ContentBlockName *bq:tag-block*)
  (bq:style-num-leader ml)
  (bq:set-att ml att num)
  (bq:set-xdata ml cod)
  ml
)

;; multileaders de numero ja criadas: lista de (chave . ename)
(defun bq:existing-num (/ ss i e xd v out)
  (setq ss (ssget "_X" (list '(0 . "MULTILEADER") (list -3 (list *bq:app*)))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq e (ssname ss i))
        (setq xd (cadr (assoc -3 (entget e (list *bq:app*)))))
        (setq v (cdr (assoc 1000 (cdr xd))))
        (if v (setq out (cons (cons (bq:code-key v) e) out)))
        (setq i (1+ i))
      )
    )
  )
  out
)

(defun bq:numerar (doc / ms blk att existing layers num key old e pt off ncri nexi sem-geom)
  (setq ms (vla-get-ModelSpace doc))
  (bq:ensure-layer doc *bq:layer-num* *bq:cor-num*)
  (setq blk (bq:tag-block doc))
  (setq att (bq:tag-att blk))
  (setq existing (bq:existing-num))
  (setq layers (bq:layers-bc) ncri 0 nexi 0)
  (setq off (* *bq:afast-num* *bq:altura-num*))
  (foreach lay layers
    (setq num (bq:num-text lay))
    (setq key (bq:code-key lay))
    (cond
      ((setq old (assoc key existing))
       ;; ja existe: mantem a posicao, so atualiza aparencia
       (bq:style-num-leader (vlax-ename->vla-object (cdr old)))
       (setq nexi (1+ nexi)))
      ((setq e (bq:basin-entity lay))
       (setq pt (bq:anchor-point e))
       (bq:num-leader ms att pt (list (+ (car pt) off) (+ (cadr pt) off) 0.0) num lay)
       (setq ncri (1+ ncri)))
      (T (setq sem-geom (cons lay sem-geom)))
    )
  )
  (princ (strcat "\nLayers BC: " (itoa (length layers))
                 " | Numeros criados: " (itoa ncri)
                 " | Ja existentes (mantidos): " (itoa nexi)))
  (if sem-geom (princ (strcat "\nLayers sem polyline no Model: " (bq:join (reverse sem-geom)))))
  (princ "\nArraste a bolinha pelo grip para organizar; a linha acompanha.")
)

;; ---------- tabela ----------

(defun bq:cell (tb r c txt h)
  (vl-catch-all-apply 'vla-SetText (list tb r c txt))
  (vl-catch-all-apply 'vla-SetCellTextHeight (list tb r c h))
  (vl-catch-all-apply 'vla-SetCellAlignment (list tb r c 5))  ; meio-centro
  (vl-catch-all-apply 'vla-SetCellTextStyle (list tb r c *bq:estilo*))
)

(defun bq:tabela (doc rows / ms ss old ins ncols nrows tb h ht r c col widths w len data)
  (setq ms (vla-get-ModelSpace doc))
  (setq h *bq:altura-tab* ht *bq:altura-tit*)
  ;; tabela anterior: reaproveita o ponto e apaga
  (setq ss (ssget "_X" (list '(0 . "ACAD_TABLE") (list -3 (list *bq:app*)))))
  (if ss
    (progn
      (setq old (vlax-ename->vla-object (ssname ss 0)))
      (setq ins (vlax-safearray->list (vlax-variant-value (vla-get-InsertionPoint old))))
      (setq c 0)
      (while (< c (sslength ss)) (vla-Delete (vlax-ename->vla-object (ssname ss c))) (setq c (1+ c)))
    )
    (if (setq ins (getpoint "\nPonto de insercao da tabela (canto superior esquerdo): "))
      (setq ins (trans ins 1 0))
    )
  )
  (if ins
    (progn
      (bq:ensure-layer doc *bq:layer-tab* *bq:cor-tab*)
      ;; valores de cada linha
      (foreach row rows
        (setq data (cons (mapcar '(lambda (col) (bq:cell-value row (cadr col) (caddr col))) *bq:colunas*) data))
      )
      (setq data (reverse data))
      ;; largura das colunas pelo maior texto
      (setq c 0)
      (foreach col *bq:colunas*
        (setq len (bq:vis-len (car col)))
        (foreach d data (setq len (max len (bq:vis-len (nth c d)))))
        (setq widths (cons (+ (* len h 0.75) (* 2.0 h)) widths))
        (setq c (1+ c))
      )
      (setq widths (reverse widths))
      (setq ncols (length *bq:colunas*) nrows (+ 2 (length data)))
      (setq tb (vla-AddTable ms (vlax-3d-point ins) nrows ncols (* 2.0 h) (* 10.0 h)))
      (bq:put tb 'RegenerateTableSuppressed :vlax-true)
      (bq:put tb 'Layer *bq:layer-tab*)
      (bq:put tb 'VertCellMargin (* 0.4 h))
      (bq:put tb 'HorzCellMargin (* 0.5 h))
      (vl-catch-all-apply 'vla-MergeCells (list tb 0 0 0 (1- ncols)))
      ;; larguras e alturas
      (setq c 0)
      (foreach w widths (vl-catch-all-apply 'vla-SetColumnWidth (list tb c w)) (setq c (1+ c)))
      (setq r 0)
      (while (< r nrows)
        (vl-catch-all-apply 'vla-SetRowHeight (list tb r (* (if (= r 0) 2.0 1.8) (if (= r 0) ht h))))
        (setq r (1+ r))
      )
      ;; titulo e cabecalho
      (bq:cell tb 0 0 *bq:titulo* ht)
      (setq c 0)
      (foreach col *bq:colunas* (bq:cell tb 1 c (car col) h) (setq c (1+ c)))
      ;; dados
      (setq r 2)
      (foreach d data
        (setq c 0)
        (foreach v d (bq:cell tb r c v h) (setq c (1+ c)))
        (setq r (1+ r))
      )
      (bq:put tb 'RegenerateTableSuppressed :vlax-false)
      (bq:set-xdata tb "QUADRO")
      (princ (strcat "\nTabela criada com " (itoa (length data)) " bacias."))
      tb
    )
  )
)

;; ---------- comandos ----------

(defun c:BACIAS_QUADRO (/ rows doc)
  (setq rows (bq:load-rows))
  (if (not rows)
    (princ "\nNenhuma bacia carregada. Use BACIAS_CSV para escolher o arquivo.")
    (progn
      (setq doc (bq:doc))
      (vla-StartUndoMark doc)
      (bq:numerar doc)
      (bq:tabela doc rows)
      (vla-EndUndoMark doc)
      (vla-Regen doc acAllViewports)
    )
  )
  (princ)
)

(defun c:BACIAS_NUMERAR (/ doc)
  (setq doc (bq:doc))
  (vla-StartUndoMark doc)
  (bq:numerar doc)
  (vla-EndUndoMark doc)
  (vla-Regen doc acAllViewports)
  (princ)
)

(defun c:BACIAS_TABELA (/ rows doc)
  (setq rows (bq:load-rows))
  (if (not rows)
    (princ "\nNenhuma bacia carregada. Use BACIAS_CSV para escolher o arquivo.")
    (progn
      (setq doc (bq:doc))
      (vla-StartUndoMark doc)
      (bq:tabela doc rows)
      (vla-EndUndoMark doc)
    )
  )
  (princ)
)

(defun c:BACIAS_CSV (/ csv)
  (setq csv (getfiled "Selecione o CSV das bacias" (getvar "DWGPREFIX") "csv" 0))
  (if csv
    (progn
      (setq *bq:csv-path* csv *bq:rows* nil)
      (bq:load-rows)
    )
    (princ "\nNenhum arquivo selecionado.")
  )
  (princ)
)

(defun c:BACIAS_RECARREGAR ()
  (setq *bq:csv-path* nil *bq:rows* nil)
  (princ "\nBase CSV esquecida. Rode BACIAS_QUADRO ou BACIAS_TABELA para ler de novo.")
  (princ)
)

;; apaga os numeros em bloco da versao anterior (BACIA_NUM_01, 02...)
(defun c:BACIAS_APAGAR_BLOCOS (/ ss i)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "BACIA_NUM_*"))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss)) (entdel (ssname ss i)) (setq i (1+ i)))
      (princ (strcat "\nBlocos apagados: " (itoa (sslength ss)) ". Use PURGE para limpar as definicoes."))
    )
    (princ "\nNenhum bloco BACIA_NUM_ encontrado.")
  )
  (princ)
)

(princ "\nComandos: BACIAS_QUADRO, BACIAS_NUMERAR, BACIAS_TABELA, BACIAS_CSV, BACIAS_RECARREGAR, BACIAS_APAGAR_BLOCOS")
(princ)
