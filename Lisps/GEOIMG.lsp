(vl-load-com)

(defun c:GEOIMG
  (/ *error*
     acad doc ms
     imgFile pgwFile fp
     A D B E C F
     imgObj ent ed
     imgSize nx ny
     insX insY
     uvec vvec)

  ;; ============================================================
  ;; TRATAMENTO DE ERRO
  ;; ============================================================

  (defun *error* (msg)
    (if fp (close fp))

    (if
      (and msg
           (/= msg "Function cancelled")
           (/= msg "quit / exit abort"))
      (princ (strcat "\nErro GEOIMG: " msg))
    )

    (princ)
  )

  ;; ============================================================
  ;; INICIO
  ;; ============================================================

  (princ "\n")
  (princ "\n==========================================")
  (princ "\n GEOIMG - Imagem georreferenciada")
  (princ "\n==========================================")

  ;; ------------------------------------------------------------
  ;; SELECIONAR PNG
  ;; ------------------------------------------------------------

  (setq imgFile
    (getfiled
      "Selecione a imagem PNG"
      ""
      "png"
      0
    )
  )

  (if imgFile
    (progn

      ;; --------------------------------------------------------
      ;; ENCONTRAR PGW
      ;; --------------------------------------------------------

      (setq pgwFile
        (strcat
          (vl-filename-directory imgFile)
          "\\"
          (vl-filename-base imgFile)
          ".pgw"
        )
      )

      (if (not (findfile pgwFile))

        (alert
          (strcat
            "Arquivo PGW nao encontrado.\n\n"
            "Esperado:\n"
            pgwFile
          )
        )

        (progn

          ;; ====================================================
          ;; LER PGW
          ;; ====================================================

          (setq fp (open pgwFile "r"))

          (setq A (atof (read-line fp)))
          (setq D (atof (read-line fp)))
          (setq B (atof (read-line fp)))
          (setq E (atof (read-line fp)))
          (setq C (atof (read-line fp)))
          (setq F (atof (read-line fp)))

          (close fp)
          (setq fp nil)

          ;; ====================================================
          ;; ACESSAR MODEL SPACE
          ;; ====================================================

          (setq acad (vlax-get-acad-object))
          (setq doc  (vla-get-ActiveDocument acad))
          (setq ms   (vla-get-ModelSpace doc))

          ;; ====================================================
          ;; CRIAR RASTER
          ;;
          ;; Posicao e escala aqui sao temporarias.
          ;; Depois alteraremos diretamente os dados DXF.
          ;; ====================================================

          (setq imgObj
            (vla-AddRaster
              ms
              imgFile
              (vlax-3d-point '(0.0 0.0 0.0))
              1.0
              0.0
            )
          )

          ;; Converter objeto ActiveX para entidade AutoCAD

          (setq ent
            (vlax-vla-object->ename imgObj)
          )

          (setq ed
            (entget ent)
          )

          ;; ====================================================
          ;; OBTER DIMENSOES EM PIXELS
          ;;
          ;; Grupo DXF 13 = largura e altura em pixels
          ;; ====================================================

          (setq imgSize
            (cdr (assoc 13 ed))
          )

          (setq nx (car imgSize))
          (setq ny (cadr imgSize))

          ;; ====================================================
          ;; CALCULAR CANTO INFERIOR ESQUERDO
          ;;
          ;; PGW:
          ;;
          ;; C,F = centro do pixel superior esquerdo
          ;;
          ;; Formula geral, inclusive para PGW com rotacao.
          ;; ====================================================

          (setq insX
            (+
              C
              (* -0.5 A)
              (* (- ny 0.5) B)
            )
          )

          (setq insY
            (+
              F
              (* -0.5 D)
              (* (- ny 0.5) E)
            )
          )

          ;; ====================================================
          ;; VETORES DE UM PIXEL
          ;;
          ;; Grupo 11 = vetor de um pixel horizontal
          ;; Grupo 12 = vetor de um pixel vertical
          ;;
          ;; O eixo vertical da IMAGE cresce para cima.
          ;; ====================================================

          (setq uvec
            (list A D 0.0)
          )

          (setq vvec
            (list (- B) (- E) 0.0)
          )

          ;; ====================================================
          ;; ALTERAR DIRETAMENTE A ENTIDADE IMAGE
          ;; ====================================================

          ;; Ponto inferior esquerdo

          (setq ed
            (subst
              (cons 10
                (list insX insY 0.0)
              )
              (assoc 10 ed)
              ed
            )
          )

          ;; Vetor horizontal por pixel

          (setq ed
            (subst
              (cons 11 uvec)
              (assoc 11 ed)
              ed
            )
          )

          ;; Vetor vertical por pixel

          (setq ed
            (subst
              (cons 12 vvec)
              (assoc 12 ed)
              ed
            )
          )

          ;; Aplicar modificacoes

          (entmod ed)
          (entupd ent)

          ;; Regenerar

          (vla-Regen doc 1)

          ;; ====================================================
          ;; RELATORIO
          ;; ====================================================

          (princ "\n")
          (princ "\n------------------------------------------")
          (princ "\n GEOIMG - RESULTADO")
          (princ "\n------------------------------------------")

          (princ
            (strcat
              "\nPixels: "
              (rtos nx 2 0)
              " x "
              (rtos ny 2 0)
            )
          )

          (princ
            (strcat
              "\nResolucao X: "
              (rtos A 2 6)
            )
          )

          (princ
            (strcat
              "\nResolucao Y: "
              (rtos (abs E) 2 6)
            )
          )

          (princ
            (strcat
              "\n\nInsertion X: "
              (rtos insX 2 4)
            )
          )

          (princ
            (strcat
              "\nInsertion Y: "
              (rtos insY 2 4)
            )
          )

          (princ
            (strcat
              "\n\nLargura: "
              (rtos (* nx (abs A)) 2 3)
            )
          )

          (princ
            (strcat
              "\nAltura: "
              (rtos (* ny (abs E)) 2 3)
            )
          )

          ;; Selecionar imagem criada

          (sssetfirst nil (ssadd ent))

          (princ "\n")
          (princ "\nImagem georreferenciada inserida.")
          (princ "\n==========================================")
        )
      )
    )
  )

  (princ)
)

(princ "\nGEOIMG carregado. Digite GEOIMG para executar.")
(princ)