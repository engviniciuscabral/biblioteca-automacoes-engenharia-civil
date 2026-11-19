(defun getAreaSafe (obj)
  (vl-catch-all-apply
    '(lambda () (vlax-get-property obj 'Area))
  )
)

(defun getWorksheetByName (wb nomeAba / sheets qtd i ws achou)
  (setq sheets (vlax-get-property wb 'Worksheets))
  (setq qtd (vlax-get-property sheets 'Count))
  (setq i 1 achou nil)

  (while (and (<= i qtd) (not achou))
    (setq ws (vlax-get-property sheets 'Item i))
    (if (= (strcase (vlax-get-property ws 'Name)) (strcase nomeAba))
      (setq achou ws)
    )
    (setq i (1+ i))
  )
  achou
)

(defun excelCellValue (ws cel / v)
  (setq v
    (vlax-get-property
      (vlax-get-property ws 'Range cel)
      'Value2
    )
  )
  (if (= (type v) 'VARIANT)
    (vlax-variant-value v)
    v
  )
)

(defun valorParaTexto (v)
  (cond
    ((null v) "")
    ((= (type v) 'VARIANT) (valorParaTexto (vlax-variant-value v)))
    ((= (type v) 'STR) v)
    ((numberp v) (rtos v 2 0))
    (T (vl-princ-to-string v))
  )
)

(defun somenteNumerosInicio (txt / i ch saida continuar)
  (setq i 1 saida "" continuar T)

  (while (and (<= i (strlen txt)) continuar)
    (setq ch (substr txt i 1))

    (cond
      ((= ch " ")
       (if (= saida "")
         nil
         (setq continuar nil)
       )
      )

      ((and (>= ch "0") (<= ch "9"))
       (setq saida (strcat saida ch))
      )

      (T
       (setq continuar nil)
      )
    )

    (setq i (1+ i))
  )

  saida
)

(defun getCTDFromLayer (layerName / nome pos resto nums)
  ;; Pega somente os números logo após "CTD"
  ;; Ex.: CTD01 -> 1 | CTD 08 -> 8 | CTD10 -> 10

  (setq nome (strcase layerName))
  (setq pos (vl-string-search "CTD" nome))

  (if pos
    (progn
      (setq resto (substr nome (+ pos 4)))
      (setq nums (somenteNumerosInicio resto))

      (if (/= nums "")
        (itoa (atoi nums))
        nil
      )
    )
    nil
  )
)

(defun formatAreaBR (valor / txt pos int dec result count ch)
  (setq txt (rtos valor 2 2))

  (if (vl-string-search "," txt)
    (setq pos (vl-string-search "," txt))
    (setq pos (vl-string-search "." txt))
  )

  (if pos
    (progn
      (setq int (substr txt 1 pos))
      (setq dec (substr txt (+ pos 2)))
    )
    (progn
      (setq int txt)
      (setq dec "00")
    )
  )

  (while (< (strlen dec) 2)
    (setq dec (strcat dec "0"))
  )

  (setq result "")
  (setq count 0)

  (while (> (strlen int) 0)
    (setq ch (substr int (strlen int) 1))
    (setq result (strcat ch result))
    (setq int (substr int 1 (1- (strlen int))))
    (setq count (1+ count))

    (if (and (> (strlen int) 0) (= (rem count 3) 0))
      (setq result (strcat "." result))
    )
  )

  (strcat result "," dec)
)

(defun getBoundingBoxCenter (obj / minPt maxPt p1 p2)
  (vla-getboundingbox obj 'minPt 'maxPt)
  (setq p1 (vlax-safearray->list minPt))
  (setq p2 (vlax-safearray->list maxPt))

  (list
    (/ (+ (car p1) (car p2)) 2.0)
    (/ (+ (cadr p1) (cadr p2)) 2.0)
    0.0
  )
)

(defun normalizarCTD (v / txt nums)
  (cond
    ((null v) "")
    ((= (type v) 'VARIANT)
     (normalizarCTD (vlax-variant-value v))
    )
    ((numberp v)
     (itoa (fix v))
    )
    ((= (type v) 'STR)
     (setq txt (vl-string-trim " " v))
     (setq nums (somenteNumerosInicio txt))
     (if (/= nums "")
       (itoa (atoi nums))
       ""
     )
    )
    (T "")
  )
)

(defun buscarLinhaCTD (ws ctd / used rows total linha valor achou)
  (setq used (vlax-get-property ws 'UsedRange))
  (setq rows (vlax-get-property used 'Rows))
  (setq total (vlax-get-property rows 'Count))

  (setq linha 1)
  (setq achou nil)

  (while (and (<= linha total) (not achou))
    (setq valor (excelCellValue ws (strcat "F" (itoa linha))))

    (if (= (normalizarCTD valor) ctd)
      (setq achou linha)
    )

    (setq linha (1+ linha))
  )

  achou
)

(defun criarMText (pt texto altura layerName rotacao / doc ms mt largura)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq ms (vla-get-ModelSpace doc))
  (setq largura (* altura 80.0))

  (setq mt
    (vla-AddMText
      ms
      (vlax-3d-point pt)
      largura
      texto
    )
  )

  (vla-put-Height mt altura)
  (vla-put-Layer mt layerName)
  (vla-put-Color mt 7)
  (vla-put-AttachmentPoint mt 5)
  (vla-put-InsertionPoint mt (vlax-3d-point pt))
  (vla-put-Rotation mt rotacao)

  mt
)

(defun dist2d (p1 p2)
  (distance
    (list (car p1) (cadr p1) 0.0)
    (list (car p2) (cadr p2) 0.0)
  )
)

(defun anguloMaiorSegmentoPolyline (ent / dados pontos maiorDist maiorAng p1 p2)
  (setq dados (entget ent))
  (setq pontos '())

  (foreach item dados
    (if (= (car item) 10)
      (setq pontos (append pontos (list (cdr item))))
    )
  )

  (setq maiorDist 0.0)
  (setq maiorAng 0.0)

  (while (> (length pontos) 1)
    (setq p1 (car pontos))
    (setq p2 (cadr pontos))

    (if (> (dist2d p1 p2) maiorDist)
      (progn
        (setq maiorDist (dist2d p1 p2))
        (setq maiorAng (angle p1 p2))
      )
    )

    (setq pontos (cdr pontos))
  )

  maiorAng
)

(defun anguloHachura (ent / antes depois ang)
  (setq antes (entlast))

  (command "_.HATCHGENERATEBOUNDARY" ent "")

  (setq depois (entlast))

  (if (and depois (/= antes depois))
    (progn
      (setq ang (anguloMaiorSegmentoPolyline depois))
      (entdel depois)
      ang
    )
    0.0
  )
)

(defun c:ROTULA_CTD
  (/ arquivo nomeAba excel wb ws doc layers lay layerName
     ctd linha fonte proprietario imovel ss i ent obj area pt texto altura
     fatorArea contador contLayers contLinhas contHachuras)

  (vl-load-com)

  (setq fatorArea 1.0)

  (setq contador 0)
  (setq contLayers 0)
  (setq contLinhas 0)
  (setq contHachuras 0)

  (setq altura (getreal "\nInforme a altura do texto: "))
  (if (not altura)
    (setq altura 2.5)
  )

  (setq arquivo
    (getfiled
      "Selecione o arquivo Excel"
      (getvar "DWGPREFIX")
      "xlsx;xlsm;xls"
      0
    )
  )

  (if (not arquivo)
    (progn
      (princ "\nNenhum arquivo Excel selecionado.")
      (exit)
    )
  )

  (setq nomeAba (getstring T "\nDigite o nome da aba: "))

  (if (= nomeAba "")
    (progn
      (princ "\nNome da aba não informado.")
      (exit)
    )
  )

  (setq excel (vlax-get-or-create-object "Excel.Application"))
  (vlax-put-property excel 'Visible :vlax-true)

  (setq wb
    (vlax-invoke
      (vlax-get-property excel 'Workbooks)
      'Open
      arquivo
    )
  )

  (setq ws (getWorksheetByName wb nomeAba))

  (if (not ws)
    (progn
      (princ "\nAba não encontrada.")
      (exit)
    )
  )

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq layers (vla-get-Layers doc))

  (vlax-for lay layers

    (setq layerName (vla-get-Name lay))
    (setq ctd (getCTDFromLayer layerName))

    (if ctd
      (progn
        (setq contLayers (1+ contLayers))

        (setq linha (buscarLinhaCTD ws ctd))

        (if linha
          (progn
            (setq contLinhas (1+ contLinhas))

            ;; Coluna A = fonte
            ;; Coluna B = proprietário
            ;; Coluna D = imóvel
            ;; Coluna F = CTD
            (setq fonte        (valorParaTexto (excelCellValue ws (strcat "A" (itoa linha)))))
            (setq proprietario (valorParaTexto (excelCellValue ws (strcat "B" (itoa linha)))))
            (setq imovel       (valorParaTexto (excelCellValue ws (strcat "D" (itoa linha)))))

            (setq ss
              (ssget "_X"
                (list
                  '(0 . "HATCH")
                  (cons 8 layerName)
                )
              )
            )

            (if ss
              (progn
                (setq i 0)

                (while (< i (sslength ss))
                  (setq contHachuras (1+ contHachuras))

                  (setq ent (ssname ss i))
                  (setq obj (vlax-ename->vla-object ent))
                  (setq area (getAreaSafe obj))

                  (if (not (vl-catch-all-error-p area))
                    (progn
                      (setq area (* area fatorArea))
                      (setq pt (getBoundingBoxCenter obj))

                      (setq texto
                        (strcat
                          "CTD " ctd
                          " - A=" (formatAreaBR area) " m²"
                          " - " fonte
                          "\\P"
                          imovel
                          "\\P"
                          proprietario
                        )
                      )

                      (criarMText pt texto altura layerName (anguloHachura ent))

                      (setq contador (1+ contador))
                    )
                  )

                  (setq i (1+ i))
                )
              )
            )
          )
        )
      )
    )
  )

  (princ
    (strcat
      "\nLayers CTD encontradas: " (itoa contLayers)
      "\nCTDs encontrados no Excel: " (itoa contLinhas)
      "\nHachuras encontradas: " (itoa contHachuras)
      "\nTextos gerados: " (itoa contador)
    )
  )

  (princ)
)
