(defun getAreaSafe (obj)
  (vl-catch-all-apply
    '(lambda ()
       (vlax-get-property obj 'Area)
     )
  )
)

(defun isClosedPolyline (obj)
  (if (vlax-property-available-p obj 'Closed)
    (= (vlax-get-property obj 'Closed) :vlax-true)
    nil
  )
)

(defun c:CONT_AREA (/ ss i ent obj area excel wb ws linha nome tipo)
  (vl-load-com)

  ;; Seleção: polilinhas e hachuras
  (setq ss (ssget '((0 . "LWPOLYLINE,POLYLINE,HATCH"))))

  (if (not ss)
    (progn
      (princ "\nNenhum polígono fechado ou hachura selecionado.")
      (exit)
    )
  )

  ;; Excel
  (setq excel (vlax-get-or-create-object "Excel.Application"))
  (vlax-put-property excel 'Visible :vlax-true)

  (setq wb (vlax-invoke (vlax-get-property excel 'Workbooks) 'Add))
  (setq ws (vlax-get-property wb 'ActiveSheet))

  ;; Cabeçalho
  (vlax-put-property (vlax-get-property ws 'Range "A1") 'Value2 "Elemento")
  (vlax-put-property (vlax-get-property ws 'Range "B1") 'Value2 "Tipo")
  (vlax-put-property (vlax-get-property ws 'Range "C1") 'Value2 "Área")

  (setq linha 2)
  (setq i 0)

  ;; Loop
  (while (< i (sslength ss))
    (setq ent (ssname ss i))
    (setq obj (vlax-ename->vla-object ent))
    (setq tipo (vla-get-ObjectName obj))

    (cond
      ;; Hachura
      ((= tipo "AcDbHatch")
       (setq area (getAreaSafe obj))
      )

      ;; Polilinha fechada
      ((and
         (or
           (= tipo "AcDbPolyline")
           (= tipo "AcDb2dPolyline")
         )
         (isClosedPolyline obj)
       )
       (setq area (getAreaSafe obj))
      )

      ;; Polilinha aberta ou inválida
      (T
       (setq area "Inválido")
      )
    )

    ;; Tratamento de erro
    (if (vl-catch-all-error-p area)
      (setq area "Inválido")
    )

    (setq nome (strcat "E-" (itoa (+ i 1))))

    ;; Escreve no Excel
    (vlax-put-property (vlax-get-property ws 'Range (strcat "A" (itoa linha))) 'Value2 nome)
    (vlax-put-property (vlax-get-property ws 'Range (strcat "B" (itoa linha))) 'Value2 tipo)
    (vlax-put-property (vlax-get-property ws 'Range (strcat "C" (itoa linha))) 'Value2 area)

    (setq linha (1+ linha))
    (setq i (1+ i))
  )

  ;; Ajuste colunas
  (vlax-invoke (vlax-get-property ws 'Columns "A:C") 'AutoFit)

  (princ "\nExportação de áreas concluída!")
  (princ)
)