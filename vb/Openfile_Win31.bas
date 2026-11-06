Attribute VB_Name = "Dialog_SelectFilePath_Win31"
' 윈도우 3.1 방식 파일 열기 대화 상자

Option Explicit

' 플래그 정의
Public Const OFN_ENABLEHOOK As Long = &H20
Public Const OFN_PATHMUSTEXIST As Long = &H800
Public Const OFN_FILEMUSTEXIST As Long = &H1000
Public Const OFN_OVERWRITEPROMPT As Long = &H2

' OPENFILENAMEA 구조체 (구형 Win31 스타일용)
Public Type OPENFILENAME
    lStructSize       As Long
    hwndOwner         As Long
    hInstance         As Long
    lpstrFilter       As String
    lpstrCustomFilter As String
    nMaxCustFilter    As Long
    nFilterIndex      As Long
    lpstrFile         As String
    nMaxFile          As Long
    lpstrFileTitle    As String
    nMaxFileTitle     As Long
    lpstrInitialDir   As String
    lpstrTitle        As String
    flags             As Long
    nFileOffset       As Integer
    nFileExtension    As Integer
    lpstrDefExt       As String
    lCustData         As Long
    lpfnHook          As Long
    lpTemplateName    As String
End Type

' API 선언
Public Declare Function GetOpenFileNameA Lib "comdlg32.dll" (pOpenfilename As OPENFILENAME) As Long
Public Declare Function GetSaveFileNameA Lib "comdlg32.dll" (pOpenfilename As OPENFILENAME) As Long
Private Const GWL_WNDPROC As Long = -4

Private Declare Function CreateWindowExA Lib "user32.dll" (ByVal dwExStyle As Long, ByVal lpClassName As String, ByVal lpWindowName As String, ByVal dwStyle As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, ByVal hWndParent As Long, ByVal hMenu As Long, ByVal hInstance As Long, ByVal lpParam As Long) As Long
Private Declare Function SetWindowLongA Lib "user32.dll" (ByVal hWnd As Long, ByVal nIndex As Long, ByVal newLong As Long) As Long
Private Declare Function GetWindowLongA Lib "user32.dll" (ByVal hWnd As Long, ByVal nIndex As Long) As Long
Private Declare Function DestroyWindow Lib "user32.dll" (ByVal hWnd As Long) As Long

' 더미 훅 프로시저 (반드시 표준 모듈에 있어야 AddressOf 전달 가능)
Public Function DummyHookProc(ByVal hdlg As Long, ByVal uiMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
    ' 기본 처리를 위해 0 반환 (파이썬의 dummy_hook과 동일)
    DummyHookProc = 0
End Function
Public Function GetDummyHookPointer() As Long
    Dim hWndTemp As Long
    Dim oldProc As Long
    Dim hookProc As Long

    ' VB5 AddressOf는 API 호출 인자로만 넘길 수 있으므로,
    ' 임시 숨김 창의 WndProc 슬롯을 이용해 콜백 포인터 값을 얻습니다.
    hWndTemp = CreateWindowExA(0, "STATIC", vbNullString, 0, _
                               0, 0, 0, 0, 0, 0, App.hInstance, 0)
    If hWndTemp = 0 Then Exit Function

    oldProc = SetWindowLongA(hWndTemp, GWL_WNDPROC, AddressOf DummyHookProc)
    If oldProc <> 0 Then
        hookProc = GetWindowLongA(hWndTemp, GWL_WNDPROC)
        SetWindowLongA hWndTemp, GWL_WNDPROC, oldProc
        GetDummyHookPointer = hookProc
    End If
    DestroyWindow hWndTemp
End Function