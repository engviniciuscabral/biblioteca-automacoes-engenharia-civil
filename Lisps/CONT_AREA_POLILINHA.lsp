(defun getAreaSafe (obj)
  (vl-catch-all-apply
    '(lambda ()
       (vlax-get-property obj 'Area)
     )
  )
)

(defun c:CONT_AREA (/ ss i ent obj area excel wb ws linha nome tipo)
  (vl-load-com)

  ;; Seleção de objetos
  (setq ss (ssget))

  (if (not ss)
    (progn
      (princ "\nNenhum objeto selecionado.")
      (exit)
    )
  )

  ;; Inicia Excel
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

  ;; Percorre seleção
  (while (< i (sslength ss))

    (setq ent (ssname ss i))
    (setq obj (vlax-ename->vla-object ent))
    (setq tipo (vla-get-ObjectName obj))

    ;; Tenta obter a área
    (setq area (getAreaSafe obj))

    ;; Se não possuir área, marca como inválido
    (if (vl-catch-all-error-p area)
      (setq area "Inválido")
    )

    ;; Nome sequencial
    (setq nome (strcat "E-" (itoa (1+ i))))

    ;; Escreve no Excel
    (vlax-put-property
      (vlax-get-property ws 'Range (strcat "A" (itoa linha)))
      'Value2
      nome
    )

    (vlax-put-property
      (vlax-get-property ws 'Range (strcat "B" (itoa linha)))
      'Value2
      tipo
    )

    (vlax-put-property
      (vlax-get-property ws 'Range (strcat "C" (itoa linha)))
      'Value2
      area
    )

    (setq linha (1+ linha))
    (setq i (1+ i))
  )

  ;; Ajusta largura das colunas
  (vlax-invoke
    (vlax-get-property ws 'Columns "A:C")
    'AutoFit
  )

  (princ "\nExportação de áreas concluída!")
  (princ)
)