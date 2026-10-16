Attribute VB_Name = "ListarAbasOndeEuClicar"
Sub ListarAbasOndeEuClicar()

    Dim ws As Worksheet
    Dim wsDestino As Worksheet
    Dim linhaAtual As Long
    Dim colunaAtual As Long

    ' Identifica a planilha de destino
    Set wsDestino = ActiveSheet

    ' Identifica a célula selecionada
    linhaAtual = ActiveCell.Row
    colunaAtual = ActiveCell.Column

    ' Percorre as planilhas da pasta de trabalho
    For Each ws In wsDestino.Parent.Worksheets

        ' Verifica se o nome começa com BC seguido de números
        If UCase(ws.Name) Like "BC[0-9]*" Then

            wsDestino.Cells(linhaAtual, colunaAtual).Value = ws.Name

            linhaAtual = linhaAtual + 1

        End If

    Next ws

End Sub
