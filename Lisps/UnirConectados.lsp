;;; ==========================================================================
;;; UNIRCONECTADOS.LSP  (v2 - otimizada)
;;;
;;; Comandos:
;;;   UNIRCON     -> une, em uma única polilinha, cada elemento selecionado
;;;                  com todos os elementos conectados pelos vértices (em
;;;                  cadeia), até não haver mais nada conectado.
;;;   UNIRCONCFG  -> configura tolerância, filtro de camada e bifurcações.
;;;
;;; Otimizações da v2:
;;;   - Com "mesma camada = Sim" (padrão), só lê do desenho os elementos das
;;;     camadas dos objetos selecionados (filtro nativo do ssget).
;;;   - Índice espacial em grade (hash): cada busca de vizinho consulta só as
;;;     9 células ao redor do vértice, em vez de varrer o desenho inteiro.
;;;   - Comprimento só é calculado quando o elemento é suspeito de ser
;;;     micro-segmento.
;;;
;;; Tipos aceitos: LINE, ARC, LWPOLYLINE, POLYLINE 2D e 3D (abertas).
;;; Ignora: polilinhas fechadas, ajustadas (fit/spline), malhas e camadas
;;; travadas. O resultado é uma LWPOLYLINE 2D com a elevação do elemento
;;; selecionado (Z de polilinhas 3D é achatado).
;;; ==========================================================================

(vl-load-com)

;;; ---------------------------------------------------------------- padrões
(defun ucx:defaults ()
  (or *uc-tol*  (setq *uc-tol* 0.01))     ; 1 cm (desenho em metros)
  (or *uc-lay*  (setq *uc-lay* "Sim"))    ; só une elementos da mesma camada
  (or *uc-modo* (setq *uc-modo* "Parar")) ; comportamento em bifurcações
)

;;; ------------------------------------------------------------- utilitários
(defun ucx:2d (p) (list (car p) (cadr p)))

(defun ucx:near (a b tol)
  (and (<= (abs (- (car a) (car b))) tol)
       (<= (abs (- (cadr a) (cadr b))) tol)
       (<= (distance a b) tol)
  )
)

(defun ucx:unit (v / l)
  (setq l (distance '(0.0 0.0) v))
  (if (> l 1e-12)
    (list (/ (car v) l) (/ (cadr v) l))
    '(0.0 0.0)
  )
)

(defun ucx:dot (a b) (+ (* (car a) (car b)) (* (cadr a) (cadr b))))

(defun ucx:tan (e atStart flip / d)
  (setq d (vlax-curve-getFirstDeriv
            e
            (if atStart (vlax-curve-getStartParam e) (vlax-curve-getEndParam e))
          )
  )
  (if flip (setq d (mapcar '- d)))
  (ucx:unit (ucx:2d d))
)

;;; Escapa caracteres curinga para usar nome de camada em filtro de ssget
(defun ucx:esc (s / out i c)
  (setq out "" i 1)
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (if (member c '("#" "@" "." "*" "?" "~" "," "[" "]" "-" "`"))
      (setq c (strcat "`" c))
    )
    (setq out (strcat out c) i (1+ i))
  )
  out
)

;;; ------------------------------------------------- índice espacial (hash)
;;; Cada célula da grade vira um símbolo (UCG_ix_iy), cuja tabela interna do
;;; LISP é um hash nativo -> busca instantânea.
;;; Usa (escopo dinâmico): uc:cs uc:keys
(defun ucx:cell (v / c)
  (setq c (/ v uc:cs))
  (if (minusp c) (1- (fix c)) (fix c))
)

(defun ucx:key (ix iy)
  (read (strcat "UCG_" (itoa ix) "_" (itoa iy)))
)

(defun ucx:key-of (p) (ucx:key (ucx:cell (car p)) (ucx:cell (cadr p))))

(defun ucx:idx-add (k rec / b)
  (setq b (vl-symbol-value k))
  (if (null b) (setq uc:keys (cons k uc:keys)))
  (if (not (member rec b)) (set k (cons rec b)))
)

(defun ucx:idx-del (rec / k)
  (foreach k (list (ucx:key-of (nth 2 rec)) (ucx:key-of (nth 3 rec)))
    (set k (vl-remove rec (vl-symbol-value k)))
  )
)

(defun ucx:idx-clear ()
  (foreach k uc:keys (set k nil))
  (setq uc:keys nil)
)

;;; Registros cujas pontas estão nas 9 células em volta de p
(defun ucx:idx-near (p / ix iy dx dy out)
  (setq ix (ucx:cell (car p)) iy (ucx:cell (cadr p)))
  (foreach dx '(-1 0 1)
    (foreach dy '(-1 0 1)
      (foreach rec (vl-symbol-value (ucx:key (+ ix dx) (+ iy dy)))
        (if (not (member rec out)) (setq out (cons rec out)))
      )
    )
  )
  out
)

;;; ------------------------------------------- registro de candidato
;;; Retorna (ename CAMADA p1 p2 micro?) ou nil se não servir.
(defun ucx:make-rec (e ed tol / typ p1 p2 micro)
  (setq typ (cdr (assoc 0 ed)))
  (cond
    ((and (= typ "POLYLINE")
          (/= 0 (logand (cdr (assoc 70 ed)) (+ 2 4 16 64))))
     nil
    )
    ((and (wcmatch typ "*POLYLINE") (= 1 (logand 1 (cdr (assoc 70 ed))))) nil)
    (T
     (setq p1 (vlax-curve-getStartPoint e)
           p2 (vlax-curve-getEndPoint e)
     )
     (cond
       ((not (and p1 p2)) nil)
       (T
        (setq p1 (ucx:2d p1) p2 (ucx:2d p2) micro nil)
        (if (ucx:near p1 p2 tol)
          ;; pontas coincidem: ou é micro-segmento, ou é anel -> ignora anel
          (if (<= (vlax-curve-getDistAtParam e (vlax-curve-getEndParam e)) tol)
            (setq micro T)
            (setq p1 nil)
          )
        )
        (if p1 (list e (strcase (cdr (assoc 8 ed))) p1 p2 micro))
       )
     )
    )
  )
)

;;; --------------------------------------------------- vértices + bulges
(defun ucx:verts (e / ed typ obj nz n i pts b ang)
  (setq ed  (entget e)
        typ (cdr (assoc 0 ed))
        nz  (caddr (cond ((cdr (assoc 210 ed))) ('(0.0 0.0 1.0))))
  )
  (cond
    ((= typ "LINE")
     (list (list (ucx:2d (cdr (assoc 10 ed))) 0.0)
           (list (ucx:2d (cdr (assoc 11 ed))) 0.0)
     )
    )
    ((= typ "ARC")
     (setq obj (vlax-ename->vla-object e)
           ang (vla-get-TotalAngle obj)
           b   (/ (sin (/ ang 4.0)) (cos (/ ang 4.0)))
     )
     (if (minusp nz) (setq b (- b)))
     (list (list (ucx:2d (vlax-curve-getStartPoint e)) b)
           (list (ucx:2d (vlax-curve-getEndPoint e)) 0.0)
     )
    )
    (T
     (setq obj (vlax-ename->vla-object e)
           n   (fix (+ 0.5 (vlax-curve-getEndParam e)))
           i   0
     )
     (while (<= i n)
       (setq b (if (and (< i n) (vlax-method-applicable-p obj 'GetBulge))
                 (vla-GetBulge obj i)
                 0.0
               )
       )
       (if (minusp nz) (setq b (- b)))
       (setq pts (cons (list (ucx:2d (vlax-curve-getPointAtParam e i)) b) pts)
             i   (1+ i)
       )
     )
     (reverse pts)
    )
  )
)

(defun ucx:rev (vl / pts buls)
  (setq pts  (reverse (mapcar 'car vl))
        buls (reverse (cdr (reverse (mapcar 'cadr vl))))
        buls (append (mapcar '- (reverse buls)) '(0.0))
  )
  (mapcar 'list pts buls)
)

;;; ---------------------------------------------------------- extensão
;;; st = (rchain endPt lastEnt lastRev)   rchain = vértices em ordem inversa
;;; Usa (escopo dinâmico): uc:tol uc:sameLay uc:lay uc:modo uc:used uc:juncs
(defun ucx:extend (st / rchain endPt lastEnt lastRev startPt go cands micros
                        rec best bestDot dot tEnd seg)
  (setq rchain  (nth 0 st)
        endPt   (nth 1 st)
        lastEnt (nth 2 st)
        lastRev (nth 3 st)
        startPt (car (last rchain))
        go      T
  )
  (while go
    (setq cands nil micros nil best nil)
    (if (and (cdr uc:used) (ucx:near endPt startPt uc:tol))
      (setq go nil) ; anel fechado
      (progn
        (foreach rec (ucx:idx-near endPt)
          (if (or (not uc:sameLay) (= (nth 1 rec) uc:lay))
            (cond
              ((ucx:near endPt (nth 2 rec) uc:tol)
               (if (nth 4 rec)
                 (setq micros (cons rec micros))
                 (setq cands (cons (cons rec nil) cands))
               )
              )
              ((ucx:near endPt (nth 3 rec) uc:tol)
               (if (nth 4 rec)
                 (setq micros (cons rec micros))
                 (setq cands (cons (cons rec T) cands))
               )
              )
            )
          )
        )
        (foreach rec micros
          (ucx:idx-del rec)
          (setq uc:used (cons (car rec) uc:used))
        )
        (cond
          ((null cands) nil)
          ((null (cdr cands)) (setq best (car cands)))
          ((= uc:modo "Parar") (setq uc:juncs (cons endPt uc:juncs)))
          (T
           (setq tEnd    (if lastRev (ucx:tan lastEnt T T) (ucx:tan lastEnt nil nil))
                 bestDot -2.0
           )
           (foreach c cands
             (setq dot (ucx:dot tEnd
                                (if (cdr c)
                                  (ucx:tan (car (car c)) nil T)
                                  (ucx:tan (car (car c)) T nil)
                                )
                       )
             )
             (if (> dot bestDot) (setq bestDot dot best c))
           )
           (if (< bestDot 0.7)
             (setq best nil uc:juncs (cons endPt uc:juncs))
           )
          )
        )
        (if best
          (progn
            (setq rec (car best)
                  seg (ucx:verts (car rec))
            )
            (if (cdr best) (setq seg (ucx:rev seg)))
            (ucx:idx-del rec)
            (setq rchain  (append (reverse seg) (cdr rchain))
                  endPt   (car (car rchain))
                  lastEnt (car rec)
                  lastRev (cdr best)
                  uc:used (cons (car rec) uc:used)
            )
          )
          (setq go nil)
        )
      )
    )
  )
  (list rchain endPt lastEnt lastRev)
)

;;; ------------------------------------------------------------ marcador
(defun ucx:mark (p / s u)
  (setq s (/ (getvar "VIEWSIZE") 80.0)
        u (trans (list (car p) (cadr p) 0.0) 0 1)
  )
  (grdraw (list (- (car u) s) (- (cadr u) s)) (list (+ (car u) s) (+ (cadr u) s)) 1)
  (grdraw (list (- (car u) s) (+ (cadr u) s)) (list (+ (car u) s) (- (cadr u) s)) 1)
)

;;; ============================================================ CONFIGURAR
(defun c:UNIRCONCFG (/ v k)
  (ucx:defaults)
  (initget 6)
  (if (setq v (getdist (strcat "\nTolerância de conexão entre vértices <"
                               (rtos *uc-tol* 2 4) ">: ")))
    (setq *uc-tol* v)
  )
  (initget "Sim Nao")
  (if (setq k (getkword (strcat "\nUnir somente elementos da mesma camada? [Sim/Nao] <"
                                *uc-lay* ">: ")))
    (setq *uc-lay* k)
  )
  (initget "Parar Alinhada")
  (if (setq k (getkword (strcat "\nEm bifurcações (3+ elementos no vértice): [Parar/Alinhada] <"
                                *uc-modo* ">: ")))
    (setq *uc-modo* k)
  )
  (princ (strcat "\nTolerância=" (rtos *uc-tol* 2 4)
                 "  MesmaCamada=" *uc-lay*
                 "  Bifurcação=" *uc-modo*))
  (princ)
)

;;; ============================================================== UNIRCON
(defun c:UNIRCON (/ *error* doc filt ss space lay locked lays layFilt all i e ed
                    rec st chain closed props elev nChains nElem nFail nPool
                    uc:tol uc:cs uc:keys uc:sameLay uc:lay uc:modo uc:used uc:juncs)

  (defun *error* (msg)
    (ucx:idx-clear)
    (if doc (vla-EndUndoMark doc))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg))
    )
    (princ)
  )

  (ucx:defaults)
  (setq uc:tol     *uc-tol*
        uc:cs      (max (* 2.0 uc:tol) 0.5)   ; tamanho da célula da grade
        uc:sameLay (= *uc-lay* "Sim")
        uc:modo    *uc-modo*
        filt       '((0 . "LINE,ARC,LWPOLYLINE,POLYLINE"))
  )
  (princ (strcat "\n[Tolerância=" (rtos uc:tol 2 4)
                 " | MesmaCamada=" *uc-lay*
                 " | Bifurcação=" uc:modo "]  (altere com UNIRCONCFG)"))

  (if (setq ss (cond ((ssget "_I" filt)) ((ssget filt))))
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (vla-StartUndoMark doc)

      ;; camadas travadas
      (setq lay (tblnext "LAYER" T))
      (while lay
        (if (= 4 (logand 4 (cdr (assoc 70 lay))))
          (setq locked (cons (strcase (cdr (assoc 2 lay))) locked))
        )
        (setq lay (tblnext "LAYER"))
      )

      ;; espaço atual
      (setq space (if (or (= 1 (getvar "TILEMODE")) (> (getvar "CVPORT") 1))
                    "Model"
                    (getvar "CTAB")
                  )
      )

      ;; camadas das sementes (para restringir a leitura do desenho)
      (setq i 0)
      (repeat (sslength ss)
        (setq lay (cdr (assoc 8 (entget (ssname ss i)))) i (1+ i))
        (if (not (member lay lays)) (setq lays (cons lay lays)))
      )
      (setq layFilt
             (if uc:sameLay
               (list (cons 8 (apply 'strcat
                                    (cons (ucx:esc (car lays))
                                          (mapcar '(lambda (l) (strcat "," (ucx:esc l)))
                                                  (cdr lays))))))
             )
      )

      ;; monta o índice espacial
      (princ "\nIndexando elementos...")
      (setq nPool 0)
      (if (setq all (ssget "_X" (append filt (list (cons 410 space)) layFilt)))
        (repeat (setq i (sslength all))
          (setq e  (ssname all (setq i (1- i)))
                ed (entget e))
          (if (and (not (member (strcase (cdr (assoc 8 ed))) locked))
                   (setq rec (ucx:make-rec e ed uc:tol)))
            (progn
              (ucx:idx-add (ucx:key-of (nth 2 rec)) rec)
              (ucx:idx-add (ucx:key-of (nth 3 rec)) rec)
              (setq nPool (1+ nPool))
            )
          )
        )
      )
      (princ (strcat " " (itoa nPool) " elemento(s) candidatos."))

      (setq nChains 0 nElem 0 nFail 0)

      (repeat (setq i (sslength ss))
        (setq e (ssname ss (setq i (1- i))))
        ;; a semente ainda está livre no índice?
        (setq rec (if (vlax-curve-getStartPoint e)
                    (assoc e (vl-symbol-value
                               (ucx:key-of (ucx:2d (vlax-curve-getStartPoint e)))))
                  )
        )
        (if rec
          (progn
            (ucx:idx-del rec)
            (setq uc:lay  (nth 1 rec)
                  uc:used (list e)
            )
            ;; 1) ponta FINAL
            (setq st (ucx:extend (list (reverse (ucx:verts e)) (nth 3 rec) e nil)))
            ;; 2) ponta INICIAL
            (setq chain (ucx:rev (reverse (car st)))
                  st    (ucx:extend (list (reverse chain) (car (last chain)) e T))
                  ;; 3) volta ao sentido original
                  chain (ucx:rev (reverse (car st)))
            )

            (if (cdr uc:used)
              (progn
                (setq closed (and (> (length chain) 2)
                                  (ucx:near (car (car chain)) (car (last chain)) uc:tol)))
                (if closed (setq chain (reverse (cdr (reverse chain)))))

                (setq ed (entget e) props nil)
                (foreach g '(410 8 6 62 370 48 420 430 440)
                  (if (assoc g ed) (setq props (cons (assoc g ed) props)))
                )
                (setq elev (caddr (vlax-curve-getStartPoint e)))

                (if (entmake
                      (append
                        (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity"))
                        (reverse props)
                        (list '(100 . "AcDbPolyline")
                              (cons 90 (length chain))
                              (cons 70 (if closed 129 128))
                              (cons 38 elev)
                        )
                        (apply 'append
                               (mapcar '(lambda (v) (list (cons 10 (car v)) (cons 42 (cadr v))))
                                       chain))
                        (list '(210 0.0 0.0 1.0))
                      )
                    )
                  (progn
                    (foreach x uc:used (entdel x))
                    (setq nChains (1+ nChains)
                          nElem   (+ nElem (length uc:used)))
                  )
                  (setq nFail (1+ nFail))
                )
              )
            )
          )
        )
      )

      (ucx:idx-clear)
      (vla-EndUndoMark doc)

      (princ (strcat "\n" (itoa nElem) " elemento(s) unido(s) em "
                     (itoa nChains) " polilinha(s)."))
      (if (> nFail 0)
        (princ (strcat "\nAtenção: " (itoa nFail) " cadeia(s) não puderam ser criadas.")))
      (if uc:juncs
        (progn
          (foreach p uc:juncs (ucx:mark p))
          (princ (strcat "\n" (itoa (length uc:juncs))
                         " bifurcação(ões) - marcadas com X vermelho (somem no REGEN)."
                         " A união parou nesses pontos."))
        )
      )
    )
    (princ "\nNenhum elemento selecionado.")
  )
  (princ)
)

(princ "\nUnirConectados v2 carregado. Comandos: UNIRCON (unir) e UNIRCONCFG (configurar).")
(princ)
