VERSION 5.00
Object = "{6B7E6392-850A-101B-AFC0-4210102A8DA7}#1.3#0"; "COMCTL32.OCX"
Begin VB.Form frmProgress 
   BorderStyle     =   3  'Fixed Dialog
   Caption         =   "변환 중"
   ClientHeight    =   2700
   ClientLeft      =   45
   ClientTop       =   330
   ClientWidth     =   5400
   ControlBox      =   0   'False
   Icon            =   "Form3x86.frx":0000
   LinkTopic       =   "Form3"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   2700
   ScaleWidth      =   5400
   ShowInTaskbar   =   0   'False
   StartUpPosition =   1  'CenterOwner
   Begin ComctlLib.ProgressBar prgBar 
      Height          =   375
      Left            =   240
      TabIndex        =   5
      Top             =   960
      Width           =   4935
      _ExtentX        =   8705
      _ExtentY        =   661
      _Version        =   327682
      Appearance      =   1
      Max             =   1000
   End
   Begin VB.CommandButton cmdCancel 
      Cancel          =   -1  'True
      Caption         =   "취소"
      Height          =   375
      Left            =   3840
      TabIndex        =   0
      Top             =   2160
      Width           =   1320
   End
   Begin VB.Label lblTime 
      Caption         =   "경과 00:00   남은 시간 계산 중"
      Height          =   255
      Left            =   240
      TabIndex        =   4
      Top             =   1680
      Width           =   4920
   End
   Begin VB.Label lblPercent 
      Alignment       =   2  'Center
      Caption         =   "0%"
      Height          =   255
      Left            =   240
      TabIndex        =   3
      Top             =   1350
      Width           =   4920
   End
   Begin VB.Label lblDetail 
      Caption         =   "이미지 준비 중"
      Height          =   255
      Left            =   240
      TabIndex        =   2
      Top             =   600
      Width           =   4920
   End
   Begin VB.Label lblPage 
      Caption         =   "페이지"
      Height          =   255
      Left            =   240
      TabIndex        =   1
      Top             =   240
      Width           =   4920
   End
End
Attribute VB_Name = "frmProgress"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit
' 변환 작업을 이 모달 창이 직접 수행합니다.
' 페이지마다 변환기(fax_engine_test)를 별도 프로세스로 실행하고, 변환기가 --progress 파일에
' 덮어쓰는 "후보 수 / 계획 수 / 예상 총수" 한 줄을 읽어 진행 막대와 남은 시간을 갱신합니다.
' 취소하면 변환기 프로세스를 즉시 종료하고 임시 파일을 지웁니다.
' VB5는 Declare에서 쓰는 사용자 정의 형식을 먼저 선언해야 합니다.
Private Type STARTUPINFO
    cb As Long
    lpReserved As String
    lpDesktop As String
    lpTitle As String
    dwX As Long
    dwY As Long
    dwXSize As Long
    dwYSize As Long
    dwXCountChars As Long
    dwYCountChars As Long
    dwFillAttribute As Long
    dwFlags As Long
    wShowWindow As Integer
    cbReserved2 As Integer
    lpReserved2 As Long
    hStdInput As Long
    hStdOutput As Long
    hStdError As Long
End Type
Private Type PROCESS_INFORMATION
    hProcess As Long
    hThread As Long
    dwProcessId As Long
    dwThreadId As Long
End Type
Private Declare Function CreateProcessA Lib "kernel32" (ByVal appName As String, ByVal commandLine As String, ByVal processAttributes As Long, ByVal threadAttributes As Long, ByVal inheritHandles As Long, ByVal creationFlags As Long, ByVal environment As Long, ByVal currentDirectory As String, ByRef si As STARTUPINFO, ByRef pi As PROCESS_INFORMATION) As Long
Private Declare Function WaitForSingleObject Lib "kernel32" (ByVal handle As Long, ByVal milliseconds As Long) As Long
Private Declare Function GetExitCodeProcess Lib "kernel32" (ByVal handle As Long, ByRef exitCode As Long) As Long
Private Declare Function TerminateProcess Lib "kernel32" (ByVal handle As Long, ByVal exitCode As Long) As Long
Private Declare Function CloseHandle Lib "kernel32" (ByVal handle As Long) As Long
Private Declare Function GetTempPathA Lib "kernel32" (ByVal bufferLength As Long, ByVal buffer As String) As Long
Private Declare Function GetTickCount Lib "kernel32" () As Long
Private Declare Function MoveFileExA Lib "kernel32" (ByVal existingName As String, ByVal newName As String, ByVal flags As Long) As Long
Private Const WAIT_TIMEOUT As Long = &H102&
Private Const MOVEFILE_REPLACE_EXISTING As Long = 1
Private Const MOVEFILE_COPY_ALLOWED As Long = 2
Private Const CREATE_NO_WINDOW As Long = &H8000000
Private Const STARTF_USESHOWWINDOW As Long = 1
Private Const PROGRESS_RECORD As Long = 34   ' 변환기가 쓰는 고정 길이 한 줄(CRLF 포함)
Private Const RUN_OK As Long = 0
Private Const RUN_FAILED As Long = 1
Private Const RUN_CANCELLED As Long = 2

Private mSource As String
Private mOutput As String
Private mMode As String
Private mFirstPage As Long
Private mLastPage As Long
Private mOptionArgs As String
Private mStarted As Boolean
Private mRunning As Boolean
Private mCancel As Boolean
Private mStartTick As Long
Private mPagesDone As Long
Private mPageFraction As Double
Private mOverall As Double
Private mLastTimeUpdate As Long
Private mFailText As String

' 변환할 내용을 정하고, 호출한 쪽에서 Show vbModal로 띄웁니다.
Public Sub Setup(ByVal sourceFile As String, ByVal outputFile As String, _
                 ByVal mode As String, ByVal firstPage As Long, ByVal lastPage As Long)
    mSource = sourceFile
    mOutput = outputFile
    mMode = mode
    mFirstPage = firstPage
    mLastPage = lastPage
    mOptionArgs = ""
    If mode = "apply" Then mOptionArgs = BuildOptionArgs()
End Sub

Private Sub Form_Load()
    mStarted = False
    mRunning = False
    mCancel = False
    gJobSuccess = False
    gJobCancelled = False
    gJobMessage = ""
    lblPage.Caption = ""
    lblDetail.Caption = "이미지 준비 중"
    lblTime.Caption = "경과 00:00   남은 시간 계산 중"
    DrawBar 0
End Sub

' 창이 처음 화면에 나타난 뒤 작업을 시작합니다. (모달 창이므로 호출한 쪽은 그동안 대기)
Private Sub Form_Activate()
    If mStarted Then Exit Sub
    mStarted = True
    RunJob
    Unload Me
End Sub

Private Sub cmdCancel_Click()
    RequestCancel
End Sub

Private Sub Form_QueryUnload(Cancel As Integer, UnloadMode As Integer)
    ' 작업 중에는 창을 닫는 대신 취소로 처리합니다.
    If mRunning Then
        Cancel = 1
        RequestCancel
    End If
End Sub

Private Sub RequestCancel()
    mCancel = True
    cmdCancel.Enabled = False
    cmdCancel.Caption = "취소 중"
End Sub

Private Sub RunJob()
    Dim pageIndex As Long
    Dim total As Long
    Dim prefix As String
    Dim dest As String
    Dim generated As String
    Dim result As Long
    Dim saved As Long
    total = mLastPage - mFirstPage + 1
    mStartTick = GetTickCount()
    mLastTimeUpdate = 0
    mRunning = True
    For pageIndex = mFirstPage To mLastPage
        mPagesDone = pageIndex - mFirstPage
        mPageFraction = 0
        lblPage.Caption = "페이지 " & CStr(mPagesDone + 1) & " / " & CStr(total) & _
                          "  (원본 " & CStr(pageIndex) & "쪽)"
        lblDetail.Caption = "이미지 준비 중"
        UpdateBar total
        prefix = MakeTempPrefix(pageIndex)
        dest = PageOutputName(mOutput, pageIndex, mFirstPage, mLastPage)
        result = RunBackend(prefix, pageIndex - 1, total)
        If result = RUN_OK Then
            generated = prefix & "_best_g3.tif"
            If MoveFileExA(generated, dest, MOVEFILE_REPLACE_EXISTING Or MOVEFILE_COPY_ALLOWED) = 0 Then
                result = RUN_FAILED
                mFailText = "페이지 " & CStr(pageIndex) & " 결과를 저장하지 못했습니다: " & dest
            Else
                saved = saved + 1
            End If
        End If
        DeleteBackendTemps prefix
        If result <> RUN_OK Then Exit For
    Next pageIndex
    mRunning = False
    If result = RUN_CANCELLED Then
        gJobCancelled = True
        gJobMessage = "변환을 취소했습니다."
        If saved > 0 Then gJobMessage = gJobMessage & vbCrLf & "취소 전까지 " & CStr(saved) & "쪽은 저장되었습니다."
    ElseIf result = RUN_FAILED Then
        gJobMessage = mFailText
    Else
        gJobSuccess = True
    End If
End Sub

' 변환기를 한 번 실행하고 끝날 때까지 진행 상태를 갱신합니다.
Private Function RunBackend(ByVal outputPrefix As String, ByVal pageIndex As Long, _
                            ByVal totalPages As Long) As Long
    Dim exe As String
    Dim cmd As String
    Dim progressFile As String
    Dim si As STARTUPINFO
    Dim pi As PROCESS_INFORMATION
    Dim exitCode As Long
    Dim waitResult As Long
    RunBackend = RUN_FAILED
    exe = App.path & "\faxeng32.exe"
    Rem If Len(Dir$(exe)) = 0 Then exe = App.path & "\..\build\msvc_c89\fax_engine_test.exe"
    Rem 배포용에는 필요없습니다. exe = AbsolutePath(exe)
    If Len(Dir$(exe)) = 0 Then
        mFailText = "백엔드 실행 파일을 찾을 수 없습니다. 프로그램을 다시 설치해보세요." & vbCrLf & "경로: " & exe
        Exit Function
    End If
    progressFile = outputPrefix & "_progress.txt"
    cmd = QuoteArg(exe) & " " & QuoteArg(mSource) & " " & QuoteArg(outputPrefix) & " " & _
          mMode & " " & CStr(pageIndex) & " --progress " & QuoteArg(progressFile) & mOptionArgs
    si.cb = Len(si)
    si.dwFlags = STARTF_USESHOWWINDOW
    si.wShowWindow = 0
    If CreateProcessA(exe, cmd, 0, 0, 0, CREATE_NO_WINDOW, 0, App.path, si, pi) = 0 Then
        mFailText = "백엔드 프로세스를 시작할 수 없습니다." & vbCrLf & "API 실패 코드: " & CStr(Err.LastDllError)
        Exit Function
    End If
    CloseHandle pi.hThread
    Do
        waitResult = WaitForSingleObject(pi.hProcess, 100)
        If waitResult <> WAIT_TIMEOUT Then Exit Do
        ReadProgress progressFile
        UpdateBar totalPages
        DoEvents
        If mCancel Then
            TerminateProcess pi.hProcess, 1
            WaitForSingleObject pi.hProcess, 3000
            CloseHandle pi.hProcess
            RunBackend = RUN_CANCELLED
            Exit Function
        End If
    Loop
    If mCancel Then
        CloseHandle pi.hProcess
        RunBackend = RUN_CANCELLED
        Exit Function
    End If
    If GetExitCodeProcess(pi.hProcess, exitCode) <> 0 Then
        If exitCode = 0 Then
            RunBackend = RUN_OK
        Else
            mFailText = "페이지 " & CStr(pageIndex + 1) & " 변환 실패: " & ExitCodeText(exitCode)
        End If
    Else
        mFailText = "백엔드의 종료 코드를 읽지 못했습니다."
    End If
    CloseHandle pi.hProcess
End Function

Private Function ExitCodeText(ByVal code As Long) As String
    Select Case code
        Case 2
            ExitCodeText = "옵션 또는 값이 올바르지 않습니다. (종료 코드 2)"
        Case 3
            ExitCodeText = "입력 이미지를 읽지 못했습니다. 형식이나 페이지 번호를 확인하세요. (종료 코드 3)"
        Case 4
            ExitCodeText = "메모리가 부족합니다. (종료 코드 4)"
        Case 5, 7, 8, 10
            ExitCodeText = "임시 출력 파일을 만들 수 없습니다. (종료 코드 " & CStr(code) & ")"
        Case 6
            ExitCodeText = "변환 엔진 오류입니다. (종료 코드 6)"
        Case 9
            ExitCodeText = "G3 TIFF 인코딩 오류입니다. (종료 코드 9)"
        Case Else
            ExitCodeText = "알 수 없는 오류입니다. (종료 코드 " & CStr(code) & ")"
    End Select
End Function

' 변환기가 제자리에서 덮어쓰는 "EEEEEEEEEE PPPPPPPPPP TTTTTTTTTT" 한 줄을 읽습니다.
Private Sub ReadProgress(ByVal path As String)
    Dim f As Integer
    Dim buf As String
    Dim evaluated As Double
    Dim estimated As Double
    Dim frac As Double
    On Error Resume Next
    f = FreeFile
    Open path For Binary Access Read Shared As #f
    If Err.Number <> 0 Then
        Err.Clear
        Exit Sub
    End If
    If LOF(f) >= PROGRESS_RECORD Then
        buf = Space$(PROGRESS_RECORD)
        Get #f, 1, buf
        evaluated = Val(Mid$(buf, 1, 10))
        estimated = Val(Mid$(buf, 23, 10))
    End If
    Close #f
    On Error GoTo 0
    If estimated < 1 Then Exit Sub
    frac = evaluated / estimated
    If frac > 0.99 Then frac = 0.99
    ' 적응형 탐색은 정제 단계가 추가되면 예상 총수가 늘어나므로, 막대가 뒤로 가지 않게 합니다.
    If frac > mPageFraction Then mPageFraction = frac
    lblDetail.Caption = "후보 탐색 " & CStr(evaluated) & " / 약 " & CStr(estimated)
End Sub

Private Sub UpdateBar(ByVal totalPages As Long)
    Dim elapsed As Long
    Dim remaining As Double
    Dim tickNow As Long
    mOverall = (mPagesDone + mPageFraction) / totalPages
    If mOverall > 1 Then mOverall = 1
    DrawBar mOverall
    tickNow = GetTickCount()
    On Error Resume Next
    elapsed = tickNow - mStartTick
    If Err.Number <> 0 Then
        Err.Clear
        elapsed = 0
    End If
    On Error GoTo 0
    ' 시간 표시는 0.5초 이상 간격으로만 바꿔 숫자가 떨리지 않게 합니다.
    If elapsed - mLastTimeUpdate < 500 And mLastTimeUpdate > 0 Then Exit Sub
    mLastTimeUpdate = elapsed
    If mOverall >= 0.02 And elapsed >= 1500 Then
        remaining = (elapsed / 1000#) * (1# - mOverall) / mOverall
        lblTime.Caption = "경과 " & FormatSeconds(elapsed / 1000#) & _
                          "   남은 시간 약 " & FormatSeconds(remaining)
    Else
        lblTime.Caption = "경과 " & FormatSeconds(elapsed / 1000#) & "   남은 시간 계산 중"
    End If
End Sub

Private Sub DrawBar(ByVal frac As Double)
    Dim value As Long

    If frac < 0 Then frac = 0
    If frac > 1 Then frac = 1

    value = CLng(frac * 1000)

    If value < prgBar.Min Then value = prgBar.Min
    If value > prgBar.Max Then value = prgBar.Max

    prgBar.value = value
    lblPercent.Caption = CStr(Int(frac * 100)) & "%"
End Sub

Private Function FormatSeconds(ByVal seconds As Double) As String
    Dim n As Long
    n = CLng(seconds)
    If n < 0 Then n = 0
    FormatSeconds = Format$(n \ 60, "00") & ":" & Format$(n Mod 60, "00")
End Function

Private Function MakeTempPrefix(ByVal pageNumber As Long) As String
    Dim buffer As String
    Dim n As Long
    buffer = String$(260, vbNullChar)
    n = GetTempPathA(Len(buffer), buffer)
    If n > 0 Then
        buffer = Left$(buffer, n)
    Else
        buffer = App.path & "\"
    End If
    MakeTempPrefix = buffer & "faxgui_" & Hex$(GetTickCount()) & "_" & CStr(pageNumber)
End Function

' 변환기의 중간 CSV/PGM/JSON/진행 파일 등 임시 산출물을 지웁니다.
Private Sub DeleteBackendTemps(ByVal prefix As String)
    On Error Resume Next
    Kill prefix & "_best_g3.tif"
    Kill prefix & "_best.pgm"
    Kill prefix & "_best_params.json"
    Kill prefix & "_metrics.csv"
    Kill prefix & "_progress.txt"
End Sub

Private Function QuoteArg(ByVal value As String) As String
    QuoteArg = Chr$(34) & value & Chr$(34)
End Function

Private Function AbsolutePath(ByVal path As String) As String
    If InStr(path, ":") > 0 Or Left$(path, 2) = "\\" Then
        AbsolutePath = path
    ElseIf Left$(path, 1) = "\" Then
        AbsolutePath = Left$(App.path, 2) & path
    Else
        AbsolutePath = App.path & "\" & path
    End If
End Function

