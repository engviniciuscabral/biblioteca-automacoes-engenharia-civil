(defun c:CONT_COMP (/ ss i ent obj comprimento excel wb ws linha nome)
  (vl-load-com)

  ;; Seleção
  (setq ss (ssget '((0 . "LWPOLYLINE,POLYLINE"))))

  (if (not ss)
    (progn
      (princ "\nNenhuma polilinha selecionada.")
      (exit)
    )
  )

  ;; Excel
  (setq excel (vlax-get-or-create-object "Excel.Application"))
  (vlax-put-property excel 'Visible :vlax-true)

  ;; CORREÇÃO AQUI
  (setq wb (vlax-invoke (vlax-get-property excel 'Workbooks) 'Add))
  (setq ws (vlax-get-property wb 'ActiveSheet))

  ;; Cabeçalho
  (vlax-put-property (vlax-get-property ws 'Range "A1") 'Value2 "Nome")
  (vlax-put-property (vlax-get-property ws 'Range "B1") 'Value2 "Comprimento")

  (setq linha 2)
  (setq i 0)

  ;; Loop
  (while (< i (sslength ss))
    (setq ent (ssname ss i))
    (setq obj (vlax-ename->vla-object ent))

    (setq comprimento
      (vlax-curve-getDistAtParam obj (vlax-curve-getEndParam obj))
    )

    (setq nome (strcat "C-" (itoa (+ i 1))))

    (vlax-put-property (vlax-get-property ws 'Range (strcat "A" (itoa linha))) 'Value2 nome)
    (vlax-put-property (vlax-get-property ws 'Range (strcat "B" (itoa linha))) 'Value2 comprimento)

    (setq linha (1+ linha))
    (setq i (1+ i))
  )

  ;; Ajuste de colunas
  (vlax-invoke (vlax-get-property ws 'Columns "A:B") 'AutoFit)

  (princ "\nExportação concluída com sucesso!")
  (princ)
)