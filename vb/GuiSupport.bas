Attribute VB_Name = "GuiSupport"
Option Explicit

Public gFamily As Integer
Public gGamma As Double
Public gSerpentine As Integer
Public gOptionsAccepted As Boolean
Public gCustomChosen As Boolean
' 고정 값 사용 옵션 중 Local Dark / CLAHE 전용 값
Public gSigma As Double
Public gStrength As Double
Public gFloor As Double
Public gClip As Double
' 변환 작업(frmProgress)의 결과
Public gJobSuccess As Boolean
Public gJobCancelled As Boolean
Public gJobMessage As String

Public Function SelectOpenFile(ByVal owner As Long, ByVal filter As String, _
                               ByVal initialPath As String) As String
    Dim ofn As OPENFILENAME
    Dim hookProc As Long
    hookProc = GetDummyHookPointer()
    If hookProc = 0 Then Exit Function
    ofn.lStructSize = Len(ofn)
    ofn.hwndOwner = owner
    ofn.lpstrFilter = MakeDialogFilter(filter)
    ofn.nFilterIndex = 1
    ofn.lpstrFile = String$(1024, vbNullChar)
    ofn.nMaxFile = Len(ofn.lpstrFile)
    ofn.lpstrFileTitle = String$(260, vbNullChar)
    ofn.nMaxFileTitle = Len(ofn.lpstrFileTitle)
    ofn.lpstrInitialDir = ParentFolder(initialPath)
    ofn.lpstrTitle = "원본 이미지 선택"
    ofn.lpfnHook = hookProc
    ' OFN_EXPLORER를 지정하지 않고 훅을 켜 Win3.1 템플릿을 요청합니다.
    ofn.flags = OFN_ENABLEHOOK Or OFN_PATHMUSTEXIST Or OFN_FILEMUSTEXIST
    If GetOpenFileNameA(ofn) <> 0 Then SelectOpenFile = Left$(ofn.lpstrFile, InStr(ofn.lpstrFile, vbNullChar) - 1)
End Function

Public Function SelectSaveFile(ByVal owner As Long, ByVal filter As String, _
                               ByVal initialPath As String) As String
    Dim ofn As OPENFILENAME
    Dim hookProc As Long
    hookProc = GetDummyHookPointer()
    If hookProc = 0 Then Exit Function
    ofn.lStructSize = Len(ofn)
    ofn.hwndOwner = owner
    ofn.lpstrFilter = MakeDialogFilter(filter)
    ofn.nFilterIndex = 1
    ofn.lpstrFile = String$(1024, vbNullChar)
    If Len(initialPath) > 0 Then Mid$(ofn.lpstrFile, 1, Len(initialPath)) = initialPath
    ofn.nMaxFile = Len(ofn.lpstrFile)
    ofn.lpstrFileTitle = String$(260, vbNullChar)
    ofn.nMaxFileTitle = Len(ofn.lpstrFileTitle)
    ofn.lpstrInitialDir = ParentFolder(initialPath)
    ofn.lpstrTitle = "TIFF 저장 위치"
    ofn.lpstrDefExt = "TIF"
    ofn.lpfnHook = hookProc
    ' OFN_EXPLORER를 지정하지 않고 훅을 켜 Win3.1 템플릿을 요청합니다.
    ofn.flags = OFN_ENABLEHOOK Or OFN_PATHMUSTEXIST Or OFN_OVERWRITEPROMPT
    If GetSaveFileNameA(ofn) <> 0 Then SelectSaveFile = Left$(ofn.lpstrFile, InStr(ofn.lpstrFile, vbNullChar) - 1)
End Function

Private Function MakeDialogFilter(ByVal source As String) As String
    Dim result As String
    Dim i As Long
    For i = 1 To Len(source)
        If Mid$(source, i, 1) = "|" Then
            result = result & vbNullChar
        Else
            result = result & Mid$(source, i, 1)
        End If
    Next i
    MakeDialogFilter = result & vbNullChar & vbNullChar
End Function

Private Function ParentFolder(ByVal path As String) As String
    Dim i As Long
    For i = Len(path) To 1 Step -1
        If Mid$(path, i, 1) = "\" Or Mid$(path, i, 1) = "/" Then
            ParentFolder = Left$(path, i - 1)
            Exit Function
        End If
    Next i
End Function

' 소수는 지역 설정과 무관하게 '.'로 변환기에 전달합니다. (Str$는 항상 '.')
Private Function Num(ByVal v As Double) As String
    Num = Trim$(Str$(v))
End Function

' 옵션 창에서 정한 값을 C 변환기(fax_engine_test)의 명령행 인자로 만듭니다.
Public Function BuildOptionArgs() As String
    Dim s As String
    Select Case gFamily
        Case 1
            s = " --family local_dark"
        Case 2
            s = " --family clahe"
        Case Else
            s = " --family gamma"
    End Select
    s = s & " --gamma " & Num(gGamma)
    s = s & " --serpentine " & IIf(gSerpentine <> 0, "1", "0")
    If gFamily = 1 Then
        s = s & " --sigma " & Num(gSigma) & " --strength " & Num(gStrength) & _
                " --floor " & Num(gFloor)
    ElseIf gFamily = 2 Then
        s = s & " --clip " & Num(gClip)
    End If
    BuildOptionArgs = s
End Function

Public Function LastPosition(ByVal value As String, ByVal findText As String) As Long
    Dim i As Long
    For i = Len(value) To 1 Step -1
        If Mid$(value, i, Len(findText)) = findText Then
            LastPosition = i
            Exit Function
        End If
    Next i
End Function

' 한 페이지만 변환하면 지정 이름을 사용하고, 범위 변환은 페이지 번호를 파일명에 붙입니다.
Public Function PageOutputName(ByVal selected As String, ByVal pageNumber As Long, _
                               ByVal firstPage As Long, ByVal lastPage As Long) As String
    Dim p As Long
    Dim stem As String
    Dim ext As String
    If firstPage = lastPage Then
        PageOutputName = selected
    Else
        p = LastPosition(selected, ".")
        stem = Left$(selected, p - 1)
        ext = Mid$(selected, p)
        PageOutputName = stem & "_p" & Format$(pageNumber, "0000") & ext
    End If
End Function

