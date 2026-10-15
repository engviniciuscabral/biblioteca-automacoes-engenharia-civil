;; TEXTO_BACIA.lsp
;; Cria chamadas (MLEADER) de identificacao das bacias buscando dados no CSV
;; exportado da planilha. A ponta da chamada fica dentro da bacia e o texto
;; pode ser arrastado pelo grip para organizar a apresentacao.
;;
;; comentario teste
;; Modelo do texto gerado:
;;   Estaca 25+11,03
;;   Sem talvegue permanente - BC01
;;   Area: 3,62 km2
;;   Comp Talv: 2,47 km
;;   i bacia: 11,25 %
;;
;; Uso:
;; 1. No Excel, salve a aba como CSV separado por ponto e virgula
;;    (de preferencia com "BACIA" no nome e na mesma pasta do DWG).
;; 2. No AutoCAD/Civil 3D, APPLOAD neste arquivo.
;; 3. Rode TEXTO_BACIAS_TODAS: le todas as layers que comecam com BC,
;;    acha a polyline da bacia em cada uma e cria todas as chamadas.
;;    Rodando de novo (ex.: apos mudar a planilha), as chamadas que ja
;;    existem so tem o texto atualizado - a posicao que voce arrumou fica.
;;
;; Comandos:
;;   TEXTO_BACIAS_TODAS       -> cria/atualiza as chamadas de todas as layers BC
;;   TEXTO_BACIA              -> uma bacia por vez (seleciona e clica onde vai o texto)
;;   TEXTO_BACIA_CSV          -> abre a janela para escolher o CSV manualmente
;;   TEXTO_BACIA_RECARREGAR   -> esquece o CSV carregado (use apos alterar a planilha)

(vl-load-com)

;; ---------- CONFIGURACAO (ajuste aqui se precisar) ----------
(setq *bb:altura*       60.0)           ; altura do texto
(setq *bb:layer*        "TEXTO BACIAS") ; layer das chamadas
(setq *bb:cor*          7)              ; cor do texto (7 = branco, 1 = vermelho)
(setq *bb:cor-chamada*  7)              ; cor da linha de chamada (7 = branco/preto)
(setq *bb:estilo*       "ARIAL")        ; estilo de texto (se existir no DWG)
(setq *bb:afastamento*  8.0)            ; distancia inicial do texto (x altura do texto)
;; -------------------------------------------------------------

(setq *bb:app* "TEXTO_BACIA")
(setq *bb:csv-path* nil)
(setq *bb:rows* nil)

;; ---------- utilidades de texto ----------

(defun bb:trim (s)
  (if s (vl-string-trim " \t\r\n\"" s) "")
)

(defun bb:replace-all (s old new / p)
  (while (setq p (vl-string-search old s))
    (setq s (strcat (substr s 1 p) new (substr s (+ p (strlen old) 1))))
  )
  s
)

(defun bb:strip-bom (s)
  (while (and (> (strlen s) 0) (member (ascii s) '(65279 239 187 191)))
    (setq s (substr s 2))
  )
  s
)

(defun bb:norm (s / r)
  (setq r (strcase (bb:trim (if s s ""))))
  (foreach ch '(" " "." "," ";" ":" "/" "\\" "-" "_" "(" ")" "[" "]" "\t")
    (setq r (bb:replace-all r ch ""))
  )
  r
)

;; Chave de comparacao do codigo: "BC 01", "BC01", "bc-1" -> "BC1"
(defun bb:code-key (s / n i pre num)
  (setq n (bb:norm s) i 1 pre "")
  (while (and (<= i (strlen n)) (not (wcmatch (substr n i 1) "#")))
    (setq pre (strcat pre (substr n i 1)))
    (setq i (1+ i))
  )
  (setq num (substr n i))
  (if (and (> (strlen num) 0) (wcmatch num "#*") (not (wcmatch num "*[~0-9]*")))
    (strcat pre (itoa (atoi num)))
    n
  )
)

(defun bb:hex2 (n / d)
  (setq d "0123456789ABCDEF")
  (strcat (substr d (1+ (/ n 16)) 1) (substr d (1+ (rem n 16)) 1))
)

;; Converte acentos (Latin-1) em codigos \U+00XX do MTEXT,
;; para nao depender da codificacao do CSV (ANSI/UTF-8).
(defun bb:mtext-safe (s / i ch c out)
  (setq i 1 out "")
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (setq c (ascii ch))
    (setq out
      (strcat out
        (if (and (> c 159) (< c 256))
          (strcat "\\U+00" (bb:hex2 c))
          ch
        )
      )
    )
    (setq i (1+ i))
  )
  out
)

;; escapa caracteres coringa para usar nome de layer no ssget
(defun bb:wc-escape (s / i ch out)
  (setq i 1 out "")
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (setq out (strcat out (if (vl-string-search ch "#@.*?~[]`,") (strcat "`" ch) ch)))
    (setq i (1+ i))
  )
  out
)

;; ---------- leitura do CSV ----------

(defun bb:split-csv (line sep / i ch inq cur out next)
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

(defun bb:detect-sep (line)
  (if (> (length (bb:split-csv line ";")) (length (bb:split-csv line ",")))
    ";"
    ","
  )
)

(defun bb:contains-all (s parts / ok)
  (setq ok T)
  (foreach p parts
    (if (not (vl-string-search p s)) (setq ok nil))
  )
  ok
)

;; indice (base 0) da primeira coluna cujo cabecalho contem todas as partes
(defun bb:find-col (headers parts / i idx)
  (setq i 0)
  (foreach h headers
    (if (and (not idx) (bb:contains-all h parts)) (setq idx i))
    (setq i (1+ i))
  )
  idx
)

(defun bb:col-or (idx default)
  (if idx idx default)
)

;; Mapeia as colunas pelo cabecalho (sem depender de acentos).
;; Se nao achar, usa a posicao padrao da planilha.
(defun bb:map-cols (headers)
  (list
    (cons "COD"   (bb:col-or (bb:find-col headers '("CODBACIA")) 0))
    (cons "EST"   (bb:col-or (bb:find-col headers '("ESTACA")) 2))
    (cons "AREA"  (bb:col-or (bb:find-col headers '("REA" "KM")) 6))
    (cons "COMP"  (bb:col-or (bb:find-col headers '("COMPRIMENTO" "TALVEG")) 7))
    (cons "DECL"  (bb:col-or (bb:find-col headers '("EFETIVA" "BACIA")) 9))
    (cons "CURSO" (bb:find-col headers '("CURSOD")))
  )
)

;; Cada linha lida vira (mapa-de-colunas . lista-de-campos).
;; Se o CSV tiver mais de uma tabela (Existente / Projetado), cada
;; novo cabecalho "COD. BACIA" atualiza o mapa de colunas.
(defun bb:read-csv (path / fh line sep hsep fields nfields cols rows)
  (setq fh (open path "r"))
  (if fh
    (progn
      (while (setq line (read-line fh))
        (setq line (bb:strip-bom line))
        (setq sep (if hsep hsep (bb:detect-sep line)))
        (setq fields (bb:split-csv line sep))
        (setq nfields (mapcar 'bb:norm fields))
        (cond
          ((member "CODBACIA" nfields)
           (setq cols (bb:map-cols nfields))
           (setq hsep sep)
          )
          ((and cols (wcmatch (car nfields) "BC*"))
           (setq rows (cons (cons cols (mapcar 'bb:trim fields)) rows))
          )
        )
      )
      (close fh)
      (reverse rows)
    )
  )
)

(defun bb:find-project-csv (/ folder files chosen)
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

(defun bb:csv-path (/ project-csv)
  (cond
    ((and *bb:csv-path* (findfile *bb:csv-path*)) *bb:csv-path*)
    ((setq project-csv (bb:find-project-csv)) (setq *bb:csv-path* project-csv))
    (T
     (setq *bb:csv-path*
       (getfiled "Selecione o CSV das bacias" (getvar "DWGPREFIX") "csv" 0)
     )
    )
  )
)

(defun bb:load-rows (/ csv)
  (if (and *bb:rows* *bb:csv-path* (findfile *bb:csv-path*))
    *bb:rows*
    (progn
      (setq csv (bb:csv-path))
      (if csv
        (progn
          (princ (strcat "\nLendo CSV: " csv))
          (setq *bb:rows* (bb:read-csv csv))
          (princ (strcat "\nBacias carregadas: " (itoa (length *bb:rows*))))
          (if (not *bb:rows*) (setq *bb:csv-path* nil))
        )
      )
      *bb:rows*
    )
  )
)

;; ---------- acesso aos valores ----------

(defun bb:field (row idx / fields v)
  (setq fields (cdr row))
  (if (and idx (>= idx 0) (< idx (length fields)))
    (setq v (bb:trim (nth idx fields)))
  )
  (if (or (not v) (equal v "") (= (substr v 1 1) "#"))
    "-"
    v
  )
)

(defun bb:val (row key)
  (bb:field row (cdr (assoc key (car row))))
)

;; retorna a ULTIMA linha com o codigo (prioriza a tabela "Projetado")
(defun bb:find-row (rows codigo / key found)
  (setq key (bb:code-key codigo))
  (foreach r rows
    (if (equal (bb:code-key (bb:val r "COD")) key)
      (setq found r)
    )
  )
  found
)

;; ---------- formatacao ----------

(defun bb:number-text (value decimals / raw out old-dimzin)
  (if (or (not value) (equal value "-"))
    "-"
    (progn
      (setq raw (bb:replace-all (bb:replace-all value "," ".") "%" ""))
      (setq raw (bb:trim raw))
      (if (distof raw 2)
        (progn
          (setq old-dimzin (getvar "DIMZIN"))
          (setvar "DIMZIN" 0)
          (setq out (rtos (distof raw 2) 2 decimals))
          (setvar "DIMZIN" old-dimzin)
          (bb:replace-all out "." ",")
        )
        value
      )
    )
  )
)

(defun bb:fmt-estaca (row / i e s d)
  (setq i (cdr (assoc "EST" (car row))))
  (setq e (bb:field row i))
  (setq s (bb:field row (+ i 1)))
  (setq d (bb:field row (+ i 2)))
  (cond
    ((equal d "-") e)
    ((equal s "-") (strcat e "+" (bb:number-text d 2)))
    (T (strcat e s (bb:number-text d 2)))
  )
)

(defun bb:compose-mtext (row / cod curso area comp decl)
  (setq cod   (bb:mtext-safe (bb:val row "COD")))
  (setq curso (bb:mtext-safe (bb:val row "CURSO")))
  (setq area  (bb:number-text (bb:val row "AREA") 2))
  (setq comp  (bb:number-text (bb:val row "COMP") 2))
  (setq decl  (bb:number-text (bb:val row "DECL") 2))
  (strcat
    "Estaca " (bb:fmt-estaca row) "\\P"
    (if (equal curso "-") cod (strcat curso " - " cod)) "\\P"
    "\\U+00C1rea: " area " km\\U+00B2\\P"
    "Comp Talv: " comp " km\\P"
    "i bacia: " decl " %"
  )
)

;; ---------- geometria da bacia ----------

(defun bb:closed-p (e)
  (or (vlax-curve-isClosed e)
      (equal (vlax-curve-getStartPoint e) (vlax-curve-getEndPoint e) 1e-6))
)

(defun bb:curve-length (e)
  (vlax-curve-getDistAtParam e (vlax-curve-getEndParam e))
)

;; Escolhe a entidade da bacia na layer: a polyline FECHADA de maior area;
;; se nao houver fechada, a curva mais longa (ex.: talvegue).
(defun bb:basin-entity (layer / ss i e v best-c best-cv best-o best-ov)
  (setq ss (ssget "_X"
             (list '(0 . "LWPOLYLINE,POLYLINE,SPLINE,CIRCLE,ELLIPSE,ARC,LINE")
                   (cons 8 (bb:wc-escape layer))
                   '(410 . "Model"))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq e (ssname ss i))
        (if (not (vl-catch-all-error-p (vl-catch-all-apply 'bb:curve-length (list e))))
          (if (bb:closed-p e)
            (progn
              (setq v (vl-catch-all-apply 'vlax-curve-getArea (list e)))
              (if (vl-catch-all-error-p v) (setq v 0.0))
              (if (or (not best-c) (> v best-cv)) (setq best-c e best-cv v))
            )
            (progn
              (setq v (bb:curve-length e))
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

(defun bb:curve-points (e n / L i p pts)
  (setq L (bb:curve-length e) i 0)
  (while (< i n)
    (setq p (vlax-curve-getPointAtDist e (* L (/ (float i) n))))
    (if p (setq pts (cons p pts)))
    (setq i (1+ i))
  )
  (reverse pts)
)

(defun bb:edges (pts)
  (mapcar 'list pts (append (cdr pts) (list (car pts))))
)

(defun bb:centroid (pts / a cx cy cr p q n)
  (setq a 0.0 cx 0.0 cy 0.0)
  (foreach ed (bb:edges pts)
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

(defun bb:inside-p (pt pts / in x y p q)
  (setq x (car pt) y (cadr pt))
  (foreach ed (bb:edges pts)
    (setq p (car ed) q (cadr ed))
    (if (and (/= (> (cadr p) y) (> (cadr q) y))
             (< x (+ (car p) (/ (* (- (car q) (car p)) (- y (cadr p))) (- (cadr q) (cadr p))))))
      (setq in (not in))
    )
  )
  in
)

;; ponto interno pela linha horizontal que passa no centroide (bacia concava)
(defun bb:scan-mid (y pts / xs p q best bw w)
  (foreach ed (bb:edges pts)
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

;; ponto onde a chamada aponta: dentro da bacia (ou meio do talvegue se aberto)
(defun bb:anchor-point (e / pts c m)
  (if (bb:closed-p e)
    (progn
      (setq pts (bb:curve-points e 150))
      (setq c (bb:centroid pts))
      (cond
        ((bb:inside-p c pts) c)
        ((setq m (bb:scan-mid (cadr c) pts)) m)
        (T (car pts))
      )
    )
    (vlax-curve-getPointAtDist e (/ (bb:curve-length e) 2.0))
  )
)

;; ---------- chamada (MLEADER) ----------

(defun bb:ensure-layer (doc name / layers layer)
  (setq layers (vla-get-Layers doc))
  (setq layer (vl-catch-all-apply 'vla-Item (list layers name)))
  (if (vl-catch-all-error-p layer)
    (progn
      (setq layer (vla-Add layers name))
      (vl-catch-all-apply 'vla-put-Color (list layer *bb:cor*))
    )
  )
  name
)

(defun bb:put (obj prop val)
  (vl-catch-all-apply 'vlax-put-property (list obj prop val))
)

(defun bb:put-aci (obj prop idx / c)
  (setq c (vl-catch-all-apply 'vlax-get-property (list obj prop)))
  (if (not (vl-catch-all-error-p c))
    (progn
      (vl-catch-all-apply 'vla-put-ColorIndex (list c idx))
      (bb:put obj prop c)
    )
  )
)

(defun bb:set-xdata (obj cod)
  (if (not (tblsearch "APPID" *bb:app*)) (regapp *bb:app*))
  (vl-catch-all-apply 'vla-SetXData
    (list obj
      (vlax-make-variant
        (vlax-safearray-fill (vlax-make-safearray vlax-vbInteger '(0 . 1)) '(1001 1000)))
      (vlax-make-variant
        (vlax-safearray-fill (vlax-make-safearray vlax-vbVariant '(0 . 1)) (list *bb:app* cod)))
    )
  )
)

(defun bb:make-leader (doc ms p-arrow p-text txt cod / arr ml)
  (bb:ensure-layer doc *bb:layer*)
  (setq arr (vlax-make-safearray vlax-vbDouble '(0 . 5)))
  (vlax-safearray-fill arr
    (list (car p-arrow) (cadr p-arrow) 0.0 (car p-text) (cadr p-text) 0.0))
  (setq ml (vla-AddMLeader ms (vlax-make-variant arr) 0))
  (bb:put ml 'ContentType 2)                 ; MTEXT
  (bb:put ml 'Layer *bb:layer*)
  (bb:put ml 'ScaleFactor 1.0)
  (bb:put ml 'TextString txt)
  (bb:put ml 'TextStyleName *bb:estilo*)
  (bb:put ml 'TextHeight *bb:altura*)
  (bb:put ml 'TextJustify 1)                 ; alinhado a esquerda
  (bb:put ml 'TextLeftAttachmentType 4)      ; chamada no meio do texto
  (bb:put ml 'TextRightAttachmentType 4)
  (bb:put ml 'ArrowheadType 19)              ; sem seta (linha simples)
  (bb:put ml 'EnableLanding :vlax-true)
  (bb:put ml 'EnableDogleg :vlax-true)
  (bb:put ml 'DoglegLength (* 1.5 *bb:altura*))
  (bb:put ml 'LandingGap (* 0.3 *bb:altura*))
  (bb:put-aci ml 'TextColor *bb:cor*)
  (bb:put-aci ml 'LeaderLineColor *bb:cor-chamada*)
  (bb:set-xdata ml cod)
  ml
)

;; chamadas ja criadas por esta LISP: lista de (chave-do-codigo . ename)
(defun bb:existing-labels (/ ss i e xd cod out)
  (setq ss (ssget "_X" (list '(0 . "MULTILEADER") (list -3 (list *bb:app*)))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq e (ssname ss i))
        (setq xd (cadr (assoc -3 (entget e (list *bb:app*)))))
        (setq cod (cdr (assoc 1000 (cdr xd))))
        (if cod (setq out (cons (cons (bb:code-key cod) e) out)))
        (setq i (1+ i))
      )
    )
  )
  out
)

;; layers do desenho que comecam com BC + numero (ignora xref)
(defun bb:bc-layers (/ rec name out)
  (setq rec (tblnext "LAYER" T))
  (while rec
    (setq name (cdr (assoc 2 rec)))
    (if (and (wcmatch (bb:norm name) "BC#*") (not (vl-string-search "|" name)))
      (setq out (cons name out))
    )
    (setq rec (tblnext "LAYER"))
  )
  (vl-sort out '<)
)

(defun bb:join (lst / out)
  (setq out "")
  (foreach s lst (setq out (if (equal out "") s (strcat out ", " s))))
  out
)

;; ---------- comandos ----------

(defun c:TEXTO_BACIAS_TODAS (/ rows doc ms existing layers row key olds e anchor off ptxt
                               ncri nupd sem-csv sem-geom usados sem-layer)
  (setq rows (bb:load-rows))
  (if (not rows)
    (princ "\nNenhuma bacia carregada. Coloque o CSV na pasta do desenho ou selecione manualmente.")
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (setq ms (vla-get-ModelSpace doc))
      (vla-StartUndoMark doc)
      (setq existing (bb:existing-labels))
      (setq layers (bb:bc-layers))
      (setq ncri 0 nupd 0 off (* *bb:afastamento* *bb:altura*))
      (foreach lay layers
        (setq row (bb:find-row rows lay))
        (cond
          ((not row) (setq sem-csv (cons lay sem-csv)))
          (T
           (setq key (bb:code-key lay))
           (setq usados (cons key usados))
           (setq olds (vl-remove-if-not '(lambda (x) (equal (car x) key)) existing))
           (if olds
             ;; ja existe: so atualiza o texto, mantendo a posicao
             (foreach o olds
               (setq e (vlax-ename->vla-object (cdr o)))
               (bb:put e 'TextString (bb:compose-mtext row))
               (bb:put e 'TextHeight *bb:altura*)
               (bb:put e 'DoglegLength (* 1.5 *bb:altura*))
               (bb:put e 'LandingGap (* 0.3 *bb:altura*))
               (bb:put-aci e 'TextColor *bb:cor*)
               (setq nupd (1+ nupd))
             )
             (if (setq e (bb:basin-entity lay))
               (progn
                 (setq anchor (bb:anchor-point e))
                 (setq ptxt (list (+ (car anchor) off) (+ (cadr anchor) off) 0.0))
                 (bb:make-leader doc ms anchor ptxt (bb:compose-mtext row) (bb:val row "COD"))
                 (setq ncri (1+ ncri))
               )
               (setq sem-geom (cons lay sem-geom))
             )
           )
          )
        )
      )
      (foreach r rows
        (if (not (member (bb:code-key (bb:val r "COD")) usados))
          (setq sem-layer (cons (bb:val r "COD") sem-layer))
        )
      )
      (vla-EndUndoMark doc)
      (princ (strcat "\nLayers BC encontradas: " (itoa (length layers))
                     " | Chamadas criadas: " (itoa ncri)
                     " | Atualizadas: " (itoa nupd)))
      (if sem-csv   (princ (strcat "\nLayers sem dados no CSV: " (bb:join (reverse sem-csv)))))
      (if sem-geom  (princ (strcat "\nLayers sem polyline no Model: " (bb:join (reverse sem-geom)))))
      (if sem-layer (princ (strcat "\nBacias do CSV sem layer no desenho: " (bb:join (reverse sem-layer)))))
      (princ "\nArraste o texto pelo grip para organizar; a linha de chamada acompanha.")
    )
  )
  (princ)
)

(defun c:TEXTO_BACIA (/ rows doc ms sel ent layer codigo row anchor ptxt)
  (setq rows (bb:load-rows))
  (if (not rows)
    (princ "\nNenhuma bacia carregada. Coloque o CSV na pasta do desenho ou selecione manualmente.")
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (setq ms (vla-get-ModelSpace doc))
      (princ "\nPressione Enter sem selecionar para terminar.")
      (while (setq sel (entsel "\nSelecione a polyline da bacia: "))
        (setq ent (car sel))
        (setq layer (cdr (assoc 8 (entget ent))))
        (setq codigo (getstring T (strcat "\nCodigo da bacia <" layer ">: ")))
        (if (equal (bb:trim codigo) "") (setq codigo layer))
        (setq row (bb:find-row rows codigo))
        (cond
          ((not row)
           (princ (strcat "\nNao encontrei a bacia '" codigo "' no CSV.")))
          ((vl-catch-all-error-p (setq anchor (vl-catch-all-apply 'bb:anchor-point (list ent))))
           (princ "\nObjeto selecionado nao e uma curva/polyline."))
          ((setq ptxt (getpoint (trans anchor 0 1) "\nPosicao do texto: "))
           (bb:make-leader doc ms anchor (trans ptxt 1 0) (bb:compose-mtext row) (bb:val row "COD"))
           (princ "\nChamada criada."))
        )
      )
    )
  )
  (princ)
)

(defun c:TEXTO_BACIA_RECARREGAR ()
  (setq *bb:csv-path* nil)
  (setq *bb:rows* nil)
  (princ "\nBase CSV das bacias esquecida. Rode TEXTO_BACIAS_TODAS para carregar novamente.")
  (princ)
)

;; Abre a janela para escolher o CSV manualmente (ignora a busca automatica)
(defun c:TEXTO_BACIA_CSV (/ csv)
  (setq csv (getfiled "Selecione o CSV das bacias" (getvar "DWGPREFIX") "csv" 0))
  (if csv
    (progn
      (setq *bb:csv-path* csv)
      (setq *bb:rows* nil)
      (bb:load-rows)
    )
    (princ "\nNenhum arquivo selecionado.")
  )
  (princ)
)

(princ "\nComandos carregados: TEXTO_BACIAS_TODAS, TEXTO_BACIA, TEXTO_BACIA_CSV, TEXTO_BACIA_RECARREGAR")
(princ)
