VERSION 5.00
Begin VB.Form main 
   Caption         =   "getfax 0.9.9"
   ClientHeight    =   3435
   ClientLeft      =   60
   ClientTop       =   345
   ClientWidth     =   6150
   Icon            =   "Form1.frx":0000
   LinkTopic       =   "Form1"
   ScaleHeight     =   3435
   ScaleWidth      =   6150
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton aboutbox 
      Caption         =   "정보"
      Height          =   255
      Left            =   4920
      TabIndex        =   17
      Top             =   240
      Width           =   975
   End
   Begin VB.CommandButton cmdSetOptions 
      Caption         =   "값 설정"
      Enabled         =   0   'False
      Height          =   375
      Left            =   360
      TabIndex        =   16
      Top             =   3000
      Width           =   1575
   End
   Begin VB.CommandButton ExecuteButton 
      Caption         =   "변환 실행"
      Height          =   375
      Left            =   4080
      TabIndex        =   15
      Top             =   3000
      Width           =   1575
   End
   Begin VB.OptionButton OptionValueApply 
      Caption         =   "고정 값 사용"
      Height          =   255
      Index           =   2
      Left            =   4080
      TabIndex        =   10
      Top             =   2520
      Width           =   1815
   End
   Begin VB.OptionButton OptionValueFull 
      Caption         =   "전체 탐색"
      Height          =   255
      Index           =   1
      Left            =   2640
      TabIndex        =   9
      Top             =   2520
      Width           =   1215
   End
   Begin VB.OptionButton OptionvalueAdaptive 
      Caption         =   "자동 추천"
      Height          =   255
      Index           =   0
      Left            =   1200
      TabIndex        =   8
      Top             =   2520
      Width           =   1215
   End
   Begin VB.CheckBox IsFull 
      Caption         =   "전체"
      Enabled         =   0   'False
      Height          =   315
      Left            =   4680
      TabIndex        =   7
      Top             =   2040
      Width           =   975
   End
   Begin VB.ComboBox PageNumberTo 
      Height          =   315
      Left            =   3120
      TabIndex        =   6
      Text            =   "2"
      Top             =   2040
      Width           =   735
   End
   Begin VB.ComboBox PageNumberFrom 
      Height          =   315
      Left            =   1920
      TabIndex        =   5
      Text            =   "1"
      Top             =   2040
      Width           =   735
   End
   Begin VB.CommandButton BrowseOutputPath 
      Caption         =   "찾아보기"
      Height          =   255
      Left            =   4920
      TabIndex        =   4
      Top             =   1560
      Width           =   975
   End
   Begin VB.TextBox OutputPath 
      Height          =   285
      Left            =   360
      TabIndex        =   3
      Text            =   "Text2"
      Top             =   1560
      Width           =   4215
   End
   Begin VB.CommandButton BrowseInputPath 
      Caption         =   "찾아보기"
      Height          =   255
      Left            =   4920
      TabIndex        =   2
      Top             =   720
      Width           =   975
   End
   Begin VB.TextBox InputPath 
      Height          =   285
      Left            =   360
      TabIndex        =   1
      Text            =   "Text1"
      Top             =   720
      Width           =   4215
   End
   Begin VB.Label Label1 
      Caption         =   "성능:"
      Height          =   255
      Left            =   360
      TabIndex        =   14
      Top             =   2520
      Width           =   615
   End
   Begin VB.Label btw 
      Caption         =   "~"
      Height          =   135
      Left            =   2760
      TabIndex        =   13
      Top             =   2160
      Width           =   255
   End
   Begin VB.Label PageNumLabel 
      Caption         =   "페이지 번호:"
      Height          =   255
      Left            =   360
      TabIndex        =   12
      Top             =   2040
      Width           =   1335
   End
   Begin VB.Label output 
      AutoSize        =   -1  'True
      Caption         =   "저장 위치"
      Height          =   195
      Left            =   360
      TabIndex        =   11
      Top             =   1200
      Width           =   705
   End
   Begin VB.Label input 
      AutoSize        =   -1  'True
      Caption         =   "원본 파일"
      Height          =   195
      Left            =   360
      TabIndex        =   0
      Top             =   360
      Width           =   705
   End
End
Attribute VB_Name = "main"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit
' VB5는 Declare에서 사용하는 사용자 정의 형식을 먼저 선언해야 합니다.
' VB5는 32비트 프로세스이므로 핸들과 포인터는 Long으로 전달합니다.
Private Type GDIPlusStartupInput
    GdiplusVersion As Long
    DebugEventCallback As Long
    SuppressBackgroundThread As Long
    SuppressExternalCodecs As Long
End Type
Private Type GUID
    Data1 As Long
    Data2 As Integer
    Data3 As Integer
    Data4(0 To 7) As Byte
End Type

' GDI+는 TIFF 페이지 수 조회에만 사용합니다. 변환기 실행은 frmProgress가 맡습니다.
Private Declare Function GdiplusStartup Lib "gdiplus.dll" (ByRef token As Long, ByRef startupData As GDIPlusStartupInput, ByVal output As Long) As Long
Private Declare Function GdiplusShutdown Lib "gdiplus.dll" (ByVal token As Long) As Long
Private Declare Function GdipLoadImageFromFile Lib "gdiplus.dll" (ByVal fileName As Long, ByRef image As Long) As Long
Private Declare Function GdipImageGetFrameDimensionsCount Lib "gdiplus.dll" (ByVal image As Long, ByRef count As Long) As Long
Private Declare Function GdipImageGetFrameDimensionsList Lib "gdiplus.dll" (ByVal image As Long, ByRef dimensionIDs As GUID, ByVal count As Long) As Long
Private Declare Function GdipImageGetFrameCount Lib "gdiplus.dll" (ByVal image As Long, ByRef dimensionID As GUID, ByRef count As Long) As Long
Private Declare Function GdipDisposeImage Lib "gdiplus.dll" (ByVal image As Long) As Long

Private Const TIFF_PAGE_DIMENSION As Long = &H7462DC86
Private mPageCount As Long
Private mInputValid As Boolean
Private mOutputValid As Boolean
Private mUpdatingPages As Boolean
Private Sub aboutbox_Click()
' frmAbout을 모달 창으로 표시
    frmAbout.Show vbModal, Me
End Sub

' 폼 시작 시 경로, 페이지 선택, 실행 버튼의 초기 상태를 맞춥니다.
Private Sub Form_Load()
    Me.Caption = App.Title & " " & App.Major & "." & App.Minor & "." & App.Revision
    ' 64비트 Windows만 지원합니다.
    If Not Is64BitWindows() Then
        MsgBox "이 프로그램은 64비트 Windows에서만 실행할 수 있습니다." & vbCrLf & _
               "64비트 Windows를 설치한 환경에서 실행하세요.", _
               vbCritical, Me.Caption
        Unload Me
        Exit Sub
    End If

    InputPath.Text = ""
    OutputPath.Text = ""
    OptionvalueAdaptive(0).value = True

    PageNumberFrom.Clear
    PageNumberTo.Clear
    PageNumberFrom.AddItem "1"
    PageNumberTo.AddItem "1"
    PageNumberFrom.ListIndex = 0
    PageNumberTo.ListIndex = 0
    IsFull.value = 0
    gCustomChosen = False

    UpdateInputState
    UpdateOutputState
End Sub

' 입력 대화상자는 취소 시 기존 경로를 유지하고, 선택된 경로를 텍스트 상자에 반영합니다.
Private Sub BrowseInputPath_Click()
    Dim selectedPath As String
    selectedPath = SelectOpenFile(Me.hWnd, _
        "이미지 파일|*.tif;*.tiff;*.png;*.jpg;*.jpeg;*.bmp;*.pgm|모든 파일|*.*", _
        InputPath.Text)
    If Len(selectedPath) > 0 Then InputPath.Text = selectedPath
End Sub

Private Sub BrowseOutputPath_Click()
    Dim selectedPath As String
    selectedPath = SelectSaveFile(Me.hWnd, _
        "TIFF 이미지|*.tif;*.tiff|모든 파일|*.*", OutputPath.Text)
    If Len(selectedPath) > 0 Then OutputPath.Text = selectedPath
End Sub

Private Sub InputPath_Change()
    UpdateInputState
End Sub

Private Sub OutputPath_Change()
    UpdateOutputState
End Sub

' 전체 페이지 선택은 1부터 마지막 페이지까지로 고정하고 수동 범위 입력을 막습니다.
Private Sub IsFull_Click()
    mUpdatingPages = True
    If IsFull.value = 1 Then
        PageNumberFrom.ListIndex = 0
        PageNumberTo.ListIndex = PageNumberTo.ListCount - 1
    End If
    PageNumberFrom.Enabled = (IsFull.value = 0 And mPageCount > 1)
    PageNumberTo.Enabled = (IsFull.value = 0 And mPageCount > 1)
    mUpdatingPages = False
End Sub

Private Sub PageNumberFrom_Change()
    If mUpdatingPages Then Exit Sub
    ValidatePageSelection
End Sub

Private Sub PageNumberTo_Change()
    If mUpdatingPages Then Exit Sub
    ValidatePageSelection
End Sub

Private Sub OptionValueApply_Click(Index As Integer)
    If Not OptionValueApply(Index).value Then Exit Sub
    gOptionsAccepted = False
    appyCustomOptions.Show vbModal, Me
    If gOptionsAccepted Then
        gCustomChosen = True
    Else
        OptionvalueAdaptive(0).value = True
    End If
    UpdateOptionButton
End Sub
Private Sub OptionvalueAdaptive_Click(Index As Integer)
    UpdateOptionButton
End Sub
Private Sub OptionValueFull_Click(Index As Integer)
    UpdateOptionButton
End Sub
' 고정 값 사용 중에 값을 다시 고칠 수 있게 합니다. 취소하면 이전 값을 그대로 씁니다.
Private Sub cmdSetOptions_Click()
    gOptionsAccepted = False
    appyCustomOptions.Show vbModal, Me
    If gOptionsAccepted Then gCustomChosen = True
End Sub
Private Sub UpdateOptionButton()
    cmdSetOptions.Enabled = OptionValueApply(2).value
End Sub
' 변환은 모달 진행 창(frmProgress)이 수행합니다. 여기서는 입력 검사만 하고 결과를 안내합니다.
Private Sub ExecuteButton_Click()
    Dim mode As String
    Dim firstPage As Long
    Dim lastPage As Long
    UpdateInputState
    UpdateOutputState
    If Not mInputValid Then
        MsgBox "읽을 수 있는 지원 이미지 파일을 지정하세요.", vbExclamation, Me.Caption
        Exit Sub
    End If
    If Not mOutputValid Then
        MsgBox "저장할 TIFF 파일 경로를 확인하세요.", vbExclamation, Me.Caption
        Exit Sub
    End If
    If OptionValueFull(1).value Then
        mode = "full"
    ElseIf OptionValueApply(2).value Then
        mode = "apply"
    Else
        mode = "adaptive"
    End If
    ' 고정 값 사용인데 아직 값을 정하지 않았다면 옵션 창부터 엽니다.
    If mode = "apply" And Not gCustomChosen Then
        gOptionsAccepted = False
        appyCustomOptions.Show vbModal, Me
        If Not gOptionsAccepted Then Exit Sub
        gCustomChosen = True
    End If
    If IsFull.value = 1 Then
        firstPage = 1
        lastPage = mPageCount
    ElseIf mPageCount > 1 Then
        firstPage = CLng(PageNumberFrom.Text)
        lastPage = CLng(PageNumberTo.Text)
    Else
        firstPage = 1
        lastPage = 1
    End If
    If firstPage < 1 Or lastPage < firstPage Or lastPage > mPageCount Then
        MsgBox "페이지 범위를 확인하세요.", vbExclamation, Me.Caption
        Exit Sub
    End If
    If DestinationsExist(firstPage, lastPage) Then
        If MsgBox("같은 이름의 출력 파일이 있습니다. 덮어쓸까요?", _
                  vbQuestion Or vbYesNo Or vbDefaultButton2, Me.Caption) <> vbYes Then Exit Sub
    End If
    ExecuteButton.Enabled = False
    frmProgress.Setup InputPath.Text, OutputPath.Text, mode, firstPage, lastPage
    frmProgress.Show vbModal, Me
    UpdateExecuteState
    ' 모달 창이 닫힌 뒤에는 frmProgress를 다시 참조하지 않고 공용 결과 변수만 읽습니다.
    If gJobCancelled Then
        MsgBox gJobMessage, vbInformation, Me.Caption
    ElseIf Not gJobSuccess Then
        MsgBox gJobMessage & vbCrLf & "백엔드 파일이 없거나 입력 형식/페이지가 지원되지 않을 수 있습니다.", _
            vbExclamation, Me.Caption
    ElseIf firstPage = lastPage Then
        MsgBox "변환이 완료되었습니다." & vbCrLf & PageOutputName(OutputPath.Text, firstPage, firstPage, lastPage), _
            vbInformation, Me.Caption
    Else
        MsgBox "변환이 완료되었습니다. 페이지마다 별도의 TIFF 파일로 저장했습니다.", vbInformation, Me.Caption
    End If
End Sub
Private Sub UpdateInputState()
    Dim f As Integer
    Dim ext As String
    Dim p As Long
    Dim readable As Boolean
    On Error GoTo BadInput
    mInputValid = False
    mPageCount = 1
    If Len(Trim$(InputPath.Text)) = 0 Then GoTo Finish
    f = FreeFile
    Open InputPath.Text For Binary Access Read As #f
    Close #f
    readable = True
    p = LastPosition(InputPath.Text, ".")
    If p > 0 Then ext = LCase$(Mid$(InputPath.Text, p + 1))
    Select Case ext
        Case "tif", "tiff", "png", "jpg", "jpeg", "bmp", "pgm"
            mInputValid = readable
        Case Else
            GoTo Finish
    End Select
    If ext = "tif" Or ext = "tiff" Then mPageCount = GetTiffPageCount(InputPath.Text)
Finish:
    ConfigurePageLists
    UpdateExecuteState
    Exit Sub
BadInput:
    On Error Resume Next
    Close #f
    mInputValid = False
    mPageCount = 1
    ConfigurePageLists
    UpdateExecuteState
End Sub

Private Function GetTiffPageCount(ByVal fileName As String) As Long
    Dim startup As GDIPlusStartupInput
    Dim token As Long
    Dim image As Long
    Dim nDims As Long
    Dim nPages As Long
    Dim dimension As GUID
    Dim rc As Long
    On Error GoTo Done
    GetTiffPageCount = 1
    startup.GdiplusVersion = 1
    If GdiplusStartup(token, startup, 0) <> 0 Then GoTo Done
    If GdipLoadImageFromFile(StrPtr(fileName), image) <> 0 Then GoTo Shutdown
    If GdipImageGetFrameDimensionsCount(image, nDims) = 0 And nDims > 0 Then
        If GdipImageGetFrameDimensionsList(image, dimension, 1) = 0 Then
            If dimension.Data1 = TIFF_PAGE_DIMENSION Then
                If GdipImageGetFrameCount(image, dimension, nPages) = 0 Then
                    If nPages > 0 Then GetTiffPageCount = nPages
                End If
            End If
        End If
    End If
    GdipDisposeImage image
Shutdown:
    GdiplusShutdown token
Done:
End Function

' 입력 TIFF가 바뀔 때 페이지 목록을 다시 만들고 기존 범위가 유효하면 보존합니다.
Private Sub ConfigurePageLists()
    Dim oldFrom As Long
    Dim oldTo As Long
    Dim i As Long
    Dim fromPage As Long
    Dim toPage As Long
    mUpdatingPages = True
    oldFrom = Val(PageNumberFrom.Text)
    oldTo = Val(PageNumberTo.Text)
    If mPageCount < 1 Then mPageCount = 1
    PageNumberFrom.Clear
    PageNumberTo.Clear
    For i = 1 To mPageCount
        PageNumberFrom.AddItem CStr(i)
        PageNumberTo.AddItem CStr(i)
    Next i
    fromPage = oldFrom
    If fromPage < 1 Or fromPage > mPageCount Then fromPage = 1
    toPage = oldTo
    If toPage < 1 Or toPage > mPageCount Then toPage = mPageCount
    PageNumberFrom.ListIndex = fromPage - 1
    PageNumberTo.ListIndex = toPage - 1
    PageNumberFrom.Enabled = (IsFull.value = 0 And mPageCount > 1)
    PageNumberTo.Enabled = (IsFull.value = 0 And mPageCount > 1)
    IsFull.Enabled = (mPageCount > 1)
    If mPageCount = 1 Then IsFull.value = 0
    mUpdatingPages = False
End Sub

Private Sub ValidatePageSelection()
    Dim a As Long
    Dim b As Long
    If mPageCount < 1 Then Exit Sub
    If Not IsNumeric(PageNumberFrom.Text) Or Not IsNumeric(PageNumberTo.Text) Then Exit Sub
    a = CLng(Val(PageNumberFrom.Text))
    b = CLng(Val(PageNumberTo.Text))
    If a < 1 Or a > mPageCount Or b < 1 Or b > mPageCount Then Exit Sub
    If a > b Then
        mUpdatingPages = True
        If PageNumberFrom.Name = "PageNumberFrom" Then
            PageNumberTo.ListIndex = a - 1
        End If
        mUpdatingPages = False
    End If
End Sub

Private Sub UpdateOutputState()
    Dim folder As String
    Dim p As Long
    Dim ext As String
    Dim slash As Long
    mOutputValid = False
    If Len(Trim$(OutputPath.Text)) = 0 Then GoTo Finish
    p = LastPosition(OutputPath.Text, ".")
    If p = 0 Then GoTo Finish
    ext = LCase$(Mid$(OutputPath.Text, p + 1))
    If ext <> "tif" And ext <> "tiff" Then GoTo Finish
    slash = LastPosition(OutputPath.Text, "\")
    If slash = 0 Then
        folder = App.path
    ElseIf slash = 3 And Mid$(OutputPath.Text, 2, 1) = ":" Then
        folder = Left$(OutputPath.Text, 3)
    Else
        folder = Left$(OutputPath.Text, slash - 1)
    End If
    If Len(Dir$(folder, vbDirectory)) > 0 Then mOutputValid = True
Finish:
    UpdateExecuteState
End Sub

Private Sub UpdateExecuteState()
    ExecuteButton.Enabled = (mInputValid And mOutputValid)
End Sub

Private Function DestinationsExist(ByVal firstPage As Long, ByVal lastPage As Long) As Boolean
    Dim i As Long
    For i = firstPage To lastPage
        If Len(Dir$(PageOutputName(OutputPath.Text, i, firstPage, lastPage))) > 0 Then
            DestinationsExist = True
            Exit Function
        End If
    Next i
End Function

' 32비트 VB5 프로그램에서 64비트 Windows 여부를 판별합니다.
' Win9x 및 32비트 Windows에서는 False를 반환합니다.
Private Function Is64BitWindows() As Boolean
    Dim arch As String
    Dim wow64Arch As String

    arch = UCase$(Environ$("PROCESSOR_ARCHITECTURE"))
    wow64Arch = UCase$(Environ$("PROCESSOR_ARCHITEW6432"))

    Select Case wow64Arch
        Case "AMD64", "IA64", "ARM64"
            Is64BitWindows = True
            Exit Function
    End Select

    Select Case arch
        Case "AMD64", "IA64", "ARM64"
            Is64BitWindows = True
        Case Else
            Is64BitWindows = False
    End Select
End Function
