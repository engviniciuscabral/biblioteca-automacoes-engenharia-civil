;;; =====================================================================
;;;  NOMEAR_PELO_ALINHAMENTO.LSP  -  Renomeia Pipes, Perfis e Profile Views
;;;                                  com o nome exato do alinhamento (Civil 3D)
;;; ---------------------------------------------------------------------
;;;  Comando : NOMEARALINHAMENTO   (atalho: NAL)
;;;
;;;  O que faz:
;;;   1. Pergunta o que renomear: Todos / Pipes / Perfis / Vistas.
;;;   2. Selecione os objetos (janela, crossing...) ou ENTER = desenho todo.
;;;   3. PIPES: cada cano e associado ao alinhamento em que ele esta
;;;      (meio do cano com menor afastamento do eixo e cano paralelo ao
;;;      alinhamento). Nome do cano = nome do alinhamento.
;;;      Bueiro duplo/triplo (varios canos no mesmo alinhamento): o mais
;;;      proximo do eixo fica com o nome exato e os outros com " (2)", " (3)"
;;;      (o Civil 3D nao aceita nomes repetidos na mesma rede).
;;;   4. PERFIS (Profile) e VISTAS (Profile View): o alinhamento e lido da
;;;      colecao do proprio alinhamento; se nao der, pelo nome; se nao der,
;;;      o comando pede para clicar no alinhamento.
;;;   5. Tudo fica em uma unica marca de UNDO: digite U para desfazer.
;;;
;;;  Carregar: APPLOAD -> NOMEAR_PELO_ALINHAMENTO.lsp -> digitar NAL
;;; =====================================================================

(vl-load-com)

;;; ------------------------- CONFIGURACAO ------------------------------
(setq *NA:TOL-OFF* 10.0)   ; afastamento maximo (m) do meio do cano ao eixo
(setq *NA:TOL-ANG* 20.0)   ; desvio maximo (graus) entre cano e alinhamento
(setq *NA:PREFIXO-VISTA* "") ; ex.: "PERFIL " -> vista "PERFIL BUEIRO BC 07"
;;; ---------------------------------------------------------------------


;;; ========================= UTILITARIOS ===============================
(defun na:var->lisp (v / l)
  (cond
    ((= (type v) 'VARIANT) (na:var->lisp (vlax-variant-value v)))
    ((= (type v) 'SAFEARRAY)
     (setq l (vl-catch-all-apply 'vlax-safearray->list (list v)))
     (if (vl-catch-all-error-p l) nil (mapcar 'na:var->lisp l)))
    (T v)))

;;; Le uma propriedade de qualquer objeto COM (nil se nao existir)
(defun na:try (o name / r)
  (setq r (vl-catch-all-apply 'vlax-get-property (list o name)))
  (if (vl-catch-all-error-p r)
    (setq r (vl-catch-all-apply 'vlax-get (list o name))))
  (if (vl-catch-all-error-p r) nil (na:var->lisp r)))

;;; Le propriedade .NET pelo getpropertyvalue (nil se nao existir)
(defun na:gpv (en name / r)
  (setq r (vl-catch-all-apply 'getpropertyvalue (list en name)))
  (if (vl-catch-all-error-p r) nil (na:var->lisp r)))

(defun na:d2 (a b) (distance (list (car a) (cadr a)) (list (car b) (cadr b))))

(defun na:pt (p)
  (cond
    ((and (listp p) (>= (length p) 2) (numberp (car p)) (numberp (cadr p)))
     (list (car p) (cadr p)))))

(defun na:nome (obj / s)
  (setq s (na:try obj 'Name))
  (if (/= (type s) 'STR)
    (setq s (na:gpv (vlax-vla-object->ename obj) "Name")))
  (if (= (type s) 'STR) s ""))

(defun na:handle (obj / h)
  (setq h (na:try obj 'Handle))
  (if (= (type h) 'STR) h ""))

(defun na:sel (tipo ss / i lst en)
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq en (ssname ss i) i (1+ i))
        (if (= (cdr (assoc 0 (entget en))) tipo)
          (setq lst (cons (vlax-ename->vla-object en) lst)))))
    (if (setq ss (ssget "_X" (list (cons 0 tipo))))
      (setq lst (na:sel tipo ss))))
  lst)

;;; Itens de uma colecao COM do alinhamento (Profiles, ProfileViews)
(defun na:colecao (al prop / c lst)
  (setq c (vl-catch-all-apply 'vlax-get-property (list al prop)))
  (if (and (not (vl-catch-all-error-p c)) (= (type c) 'VLA-OBJECT))
    (vl-catch-all-apply '(lambda () (vlax-for o c (setq lst (cons o lst))))))
  (reverse lst))

;;; (estaca afastamento) do ponto no alinhamento, conferido pelo ponto de
;;; volta (fora do alinhamento o Civil 3D devolve 0/0 sem erro)
(defun na:al-sta (al pt / sta off r e n s0 s1)
  (setq r (vl-catch-all-apply 'vlax-invoke-method
            (list al 'StationOffset (car pt) (cadr pt) 'sta 'off)))
  (if (and (not (vl-catch-all-error-p r))
           (numberp (setq sta (na:var->lisp sta)))
           (numberp (setq off (na:var->lisp off))))
    (progn
      (setq r  (vl-catch-all-apply 'vlax-invoke-method
                 (list al 'PointLocation sta off 'e 'n))
            s0 (na:try al 'StartingStation)
            s1 (na:try al 'EndingStation))
      (cond
        ((and (numberp s0) (numberp s1)
              (or (< sta (- s0 0.01)) (> sta (+ s1 0.01))))
         nil)
        ((and (not (vl-catch-all-error-p r))
              (numberp (setq e (na:var->lisp e)))
              (numberp (setq n (na:var->lisp n))))
         (if (< (na:d2 (list e n) pt) 0.10) (list sta off)))
        ((and (numberp s0) (numberp s1)) (list sta off))
        ((not (and (equal sta 0.0 1e-9) (equal off 0.0 1e-9))) (list sta off))))))

;;; Ponto do cano no parametro t (metodo PointAtParam do Civil 3D)
(defun na:pap (obj tt / r)
  (setq r (vl-catch-all-apply 'vlax-get-property (list obj 'PointAtParam tt)))
  (if (not (vl-catch-all-error-p r)) (na:var->lisp r)))

;;; Pontas (x y) do cano: PointAtParam, COM, .NET ou vlax-curve
;;; (no Civil 3D 2021 StartPoint/EndPoint podem vir 0,0 -> PointAtParam 1o)
(defun na:pontas-cano (obj / en a b L2 L3)
  (setq en (vlax-vla-object->ename obj)
        L2 (na:try obj 'Length2D)
        L3 (na:try obj 'Length3D))
  (if (not (numberp L2)) (setq L2 nil))
  (foreach c (list
               ;; parametro normalizado 0..1 ou por comprimento 0..L
               (list (na:pap obj 0.0) (na:pap obj 1.0))
               (if (numberp L3) (list (na:pap obj 0.0) (na:pap obj L3)) (list nil nil))
               (list (na:try obj 'StartPoint) (na:try obj 'EndPoint))
               (list (na:gpv en "StartPoint") (na:gpv en "EndPoint"))
               (list (vl-catch-all-apply 'vlax-curve-getStartPoint (list obj))
                     (vl-catch-all-apply 'vlax-curve-getEndPoint (list obj))))
    (if (not a)
      (progn
        ;; ponto do Civil 3D como objeto (X Y Z)
        (setq a (car c) b (cadr c))
        (if (= (type a) 'VLA-OBJECT) (setq a (list (na:try a 'X) (na:try a 'Y))))
        (if (= (type b) 'VLA-OBJECT) (setq b (list (na:try b 'X) (na:try b 'Y))))
        (setq a (na:pt a) b (na:pt b))
        ;; aceita so se o comprimento bater com o Length2D (5%)
        (if (not (and a b (> (na:d2 a b) 0.01)
                      (or (not L2) (< (abs (- (na:d2 a b) L2)) (max 0.05 (* 0.05 L2))))))
          (setq a nil b nil)))))
  (if a (list a b)))

;;; Renomeia OBJ para ALVO; se o nome ja existir usa ALVO (2), (3)...
;;; Devolve o nome final ou nil
(defun na:renomear (obj alvo / atual k nm ok)
  (setq atual (na:nome obj))
  (if (= (strcase atual) (strcase alvo))
    atual
    (progn
      (setq k 1)
      (while (and (not ok) (<= k 50))
        (setq nm (if (= k 1) alvo (strcat alvo " (" (itoa k) ")")))
        (if (= (strcase atual) (strcase nm))
          (setq ok nm)
          (progn
            (vl-catch-all-apply 'vlax-put-property (list obj 'Name nm))
            (if (/= (na:nome obj) nm)
              (vl-catch-all-apply 'setpropertyvalue
                (list (vlax-vla-object->ename obj) "Name" nm)))
            (if (= (na:nome obj) nm) (setq ok nm))))
        (setq k (1+ k)))
      ok)))

(defun na:log (tipo antes depois)
  (princ (strcat "\n  " tipo ": \"" antes "\"  ->  "
                 (if depois (strcat "\"" depois "\"") "*** NAO RENOMEADO ***"))))


;;; ============================ PIPES ==================================
;;; Melhor alinhamento do cano: (alinhamento |afastamento|) ou nil
(defun na:al-do-cano (obj als / pp m L sm s1 s2 best bo cosmin dsta)
  (setq cosmin (cos (* pi (/ *NA:TOL-ANG* 180.0))))
  (if (setq pp (na:pontas-cano obj))
    (progn
      (setq m (mapcar '(lambda (a b) (/ (+ a b) 2.0)) (car pp) (cadr pp))
            L (na:d2 (car pp) (cadr pp)))
      (foreach al als
        (if (and (setq sm (na:al-sta al m))
                 (<= (abs (cadr sm)) *NA:TOL-OFF*))
          (progn
            ;; paralelismo: avanco de estaca ~ comprimento do cano
            (setq s1 (na:al-sta al (car pp))
                  s2 (na:al-sta al (cadr pp))
                  dsta (if (and s1 s2) (abs (- (car s2) (car s1)))))
            (if (and (or (not dsta) (>= dsta (* cosmin L)))
                     (or (not bo) (< (abs (cadr sm)) bo)))
              (setq best al bo (abs (cadr sm)))))))))
  (if best (list best bo)))

(defun na:pipes (ss als / canos r lst nome)
  (setq canos (na:sel "AECC_PIPE" ss))
  (princ (strcat "\n\n--- PIPES (" (itoa (length canos)) ") ---"))
  (foreach c canos
    (if (setq r (na:al-do-cano c als))
      (setq lst (cons (list c (na:nome (car r)) (cadr r)) lst))
      (princ (strcat "\n  Pipe \"" (na:nome c) "\": nenhum alinhamento encontrado (mantido)."))))
  ;; o mais proximo do eixo primeiro -> recebe o nome exato
  (setq lst (vl-sort lst '(lambda (a b) (< (caddr a) (caddr b)))))
  (foreach x lst
    (setq nome (na:nome (car x)))
    (na:log "Pipe" nome (na:renomear (car x) (cadr x)))))


;;; =================== PERFIS E PROFILE VIEWS ==========================
;;; Alinhamento pelo nome do objeto (o nome de alinhamento mais longo
;;; contido nele, ex.: "PERFIL BUEIRO BC 07" -> "BUEIRO BC 07")
(defun na:al-pelo-nome (obj als / nm best)
  (setq nm (strcase (na:nome obj)))
  (foreach al als
    (if (and (/= (na:nome al) "")
             (vl-string-search (strcase (na:nome al)) nm)
             (or (not best) (> (strlen (na:nome al)) (strlen (na:nome best)))))
      (setq best al)))
  best)

;;; Alinhamento do perfil / vista: mapa da colecao, propriedade, nome, clique
(defun na:al-de (obj mapa als tipo / a e)
  (setq a (cdr (assoc (na:handle obj) mapa)))
  (if (not a)
    (foreach k '(Alignment ParentAlignment)
      (if (and (not a) (= (type (setq e (na:try obj k))) 'VLA-OBJECT)) (setq a e))))
  (if (and (not a)
           (= (type (setq e (na:gpv (vlax-vla-object->ename obj) "AlignmentId"))) 'ENAME))
    (setq a (vlax-ename->vla-object e)))
  (if (not a) (setq a (na:al-pelo-nome obj als)))
  (if (not a)
    (progn
      (princ (strcat "\n  " tipo " \"" (na:nome obj) "\": alinhamento nao identificado."))
      (if (and (setq e (entsel (strcat "\n  Clique no ALINHAMENTO de \"" (na:nome obj)
                                       "\" (ENTER = pular): ")))
               (= (cdr (assoc 0 (entget (car e)))) "AECC_ALIGNMENT"))
        (setq a (vlax-ename->vla-object (car e))))))
  a)

(defun na:perfis (ss als mapa tipo dxf prefixo / objs lst a nome)
  (setq objs (na:sel dxf ss))
  (princ (strcat "\n\n--- " (strcase tipo) " (" (itoa (length objs)) ") ---"))
  (foreach o objs
    (if (setq a (na:al-de o mapa als tipo))
      (setq lst (cons (cons o (strcat prefixo (na:nome a))) lst))
      (princ (strcat "\n  " tipo " \"" (na:nome o) "\": mantido."))))
  (foreach x (reverse lst)
    (setq nome (na:nome (car x)))
    (na:log tipo nome (na:renomear (car x) (cdr x)))))


;;; ============================ COMANDO ================================
(defun c:NOMEARALINHAMENTO (/ *error* doc op ss als mapaP mapaV)
  (defun *error* (msg)
    (if doc (vla-EndUndoMark doc))
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*"))
      (princ (strcat "\nErro: " msg)))
    (princ))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (initget "Todos Pipes Perfis Vistas")
  (setq op (getkword "\nRenomear [Todos/Pipes/Perfis/Vistas] <Todos>: "))
  (if (not op) (setq op "Todos"))
  (princ "\nSelecione os objetos ou ENTER = desenho todo: ")
  (setq ss (ssget '((0 . "AECC_PIPE,AECC_PROFILE,AECC_PROFILE_VIEW"))))
  (setq als (na:sel "AECC_ALIGNMENT" nil))
  (if (not als)
    (princ "\nNenhum alinhamento no desenho.")
    (progn
      (vla-StartUndoMark doc)
      ;; mapa handle -> alinhamento, pelas colecoes de cada alinhamento
      (foreach al als
        (foreach p (na:colecao al 'Profiles)
          (setq mapaP (cons (cons (na:handle p) al) mapaP)))
        (foreach v (na:colecao al 'ProfileViews)
          (setq mapaV (cons (cons (na:handle v) al) mapaV))))
      (if (member op '("Todos" "Pipes"))
        (na:pipes ss als))
      (if (member op '("Todos" "Perfis"))
        (na:perfis ss als mapaP "Perfil" "AECC_PROFILE" ""))
      (if (member op '("Todos" "Vistas"))
        (na:perfis ss als mapaV "Vista" "AECC_PROFILE_VIEW" *NA:PREFIXO-VISTA*))
      (vla-EndUndoMark doc)
      (princ "\n\nConcluido. Digite U para desfazer tudo.")))
  (princ))

(defun c:NAL () (c:NOMEARALINHAMENTO))

(princ "\nNOMEAR_PELO_ALINHAMENTO carregado. Comando: NAL")
(princ)
