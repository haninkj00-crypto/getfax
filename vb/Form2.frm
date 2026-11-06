VERSION 5.00
Begin VB.Form appyCustomOptions 
   BorderStyle     =   3  'Fixed Dialog
   Caption         =   "속성값 지정"
   ClientHeight    =   4500
   ClientLeft      =   45
   ClientTop       =   330
   ClientWidth     =   4680
   Icon            =   "Form2.frx":0000
   LinkTopic       =   "Form2"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   4500
   ScaleWidth      =   4680
   ShowInTaskbar   =   0   'False
   StartUpPosition =   1  'CenterOwner
   Begin VB.TextBox clipValue 
      Height          =   285
      Left            =   2040
      TabIndex        =   9
      Text            =   "0.75"
      ToolTipText     =   "CLAHE의 대비 제한값입니다. 클수록 대비가 강해집니다. (0.1 ~ 10, 예: 0.75)"
      Top             =   2520
      Visible         =   0   'False
      Width           =   1575
   End
   Begin VB.TextBox floorValue 
      Height          =   285
      Left            =   2040
      TabIndex        =   7
      Text            =   "0"
      ToolTipText     =   "국소 어두움 계산에서 무시할 최소 차이입니다. (0 ~ 1, 예: 0)"
      Top             =   3360
      Visible         =   0   'False
      Width           =   1575
   End
   Begin VB.TextBox strengthValue 
      Height          =   285
      Left            =   2040
      TabIndex        =   5
      Text            =   "0.425"
      ToolTipText     =   "주변보다 어두운 부분을 얼마나 더 진하게 할지 정합니다. (0 ~ 2, 예: 0.425)"
      Top             =   2940
      Visible         =   0   'False
      Width           =   1575
   End
   Begin VB.TextBox sigmaValue 
      Height          =   285
      Left            =   2040
      TabIndex        =   3
      Text            =   "7"
      ToolTipText     =   "주변 밝기를 구할 때 흐림 반경(픽셀)입니다. (0.5 ~ 85, 예: 7)"
      Top             =   2520
      Visible         =   0   'False
      Width           =   1575
   End
   Begin VB.CommandButton CancelButton 
      Cancel          =   -1  'True
      Caption         =   "취소"
      Height          =   375
      Left            =   1440
      TabIndex        =   11
      Top             =   3960
      Width           =   1335
   End
   Begin VB.CommandButton ConfirmButton 
      Caption         =   "확인"
      Default         =   -1  'True
      Height          =   375
      Left            =   3000
      TabIndex        =   10
      Top             =   3960
      Width           =   1335
   End
   Begin VB.CheckBox isSerpentine 
      Height          =   255
      Left            =   2040
      TabIndex        =   2
      ToolTipText     =   "왕복 스캔(지그재그)을 통해 오차 확산 패턴이 생기는 것을 방지합니다."
      Top             =   2040
      Width           =   855
   End
   Begin VB.TextBox gammaValue 
      Height          =   285
      Left            =   2040
      TabIndex        =   1
      Text            =   "0.85"
      ToolTipText     =   "전체적인 이미지의 중간 밝기를 조절하는 값입니다. (0.1 ~ 5, 예: 0.85)"
      Top             =   1560
      Width           =   1575
   End
   Begin VB.ComboBox familyValue 
      Height          =   315
      Left            =   2040
      Style           =   2  'Dropdown List
      TabIndex        =   0
      ToolTipText     =   "전처리 알고리즘 방식입니다."
      Top             =   1080
      Width           =   1935
   End
   Begin VB.Label lblClip 
      Caption         =   "대비 제한(clip)"
      Height          =   255
      Left            =   240
      TabIndex        =   15
      Top             =   2520
      Visible         =   0   'False
      Width           =   1695
   End
   Begin VB.Label lblFloor 
      Caption         =   "최소 차이(floor)"
      Height          =   255
      Left            =   240
      TabIndex        =   14
      Top             =   3360
      Visible         =   0   'False
      Width           =   1695
   End
   Begin VB.Label lblStrength 
      Caption         =   "강도"
      Height          =   255
      Left            =   240
      TabIndex        =   13
      Top             =   2940
      Visible         =   0   'False
      Width           =   1695
   End
   Begin VB.Label lblSigma 
      Caption         =   "흐림 반경"
      Height          =   255
      Left            =   240
      TabIndex        =   12
      Top             =   2520
      Visible         =   0   'False
      Width           =   1695
   End
   Begin VB.Label instruction 
      Caption         =   $"Form2.frx":0442
      Height          =   735
      Left            =   120
      TabIndex        =   8
      Top             =   120
      Width           =   4455
   End
   Begin VB.Label Label2 
      Caption         =   "지그재그로 스캔"
      Height          =   255
      Left            =   240
      TabIndex        =   6
      Top             =   2040
      Width           =   1575
   End
   Begin VB.Label Label1 
      Caption         =   "감마"
      Height          =   255
      Left            =   240
      TabIndex        =   4
      Top             =   1560
      Width           =   1575
   End
   Begin VB.Label familyLable 
      Caption         =   "알고리즘"
      Height          =   255
      Left            =   240
      TabIndex        =   16
      Top             =   1080
      Width           =   1575
   End
End
Attribute VB_Name = "appyCustomOptions"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private Sub Form_Load()
    gOptionsAccepted = False
    familyValue.Clear
    familyValue.AddItem "감마 보정"
    familyValue.AddItem "Local Dark"
    familyValue.AddItem "CLAHE"
    If gFamily < 0 Or gFamily > 2 Then gFamily = 0
    If gGamma <= 0 Then gGamma = 0.85
    If gSigma <= 0 Then gSigma = 7
    If gStrength <= 0 Then gStrength = 0.425
    If gClip <= 0 Then gClip = 0.75
    ' 처음 열 때는 오차 확산 무늬를 막는 왕복 스캔을 기본으로 켭니다.
    If Not gCustomChosen Then gSerpentine = 1
    gammaValue.Text = CStr(gGamma)
    sigmaValue.Text = CStr(gSigma)
    strengthValue.Text = CStr(gStrength)
    floorValue.Text = CStr(gFloor)
    clipValue.Text = CStr(gClip)
    isSerpentine.value = IIf(gSerpentine <> 0, 1, 0)
    familyValue.ListIndex = gFamily
    UpdateFamilyRows
End Sub

' 선택한 알고리즘에 해당하는 입력칸만 보여 줍니다.
Private Sub UpdateFamilyRows()
    Dim isLocal As Boolean
    Dim isClahe As Boolean
    isLocal = (familyValue.ListIndex = 1)
    isClahe = (familyValue.ListIndex = 2)
    lblSigma.Visible = isLocal
    sigmaValue.Visible = isLocal
    lblStrength.Visible = isLocal
    strengthValue.Visible = isLocal
    lblFloor.Visible = isLocal
    floorValue.Visible = isLocal
    lblClip.Visible = isClahe
    clipValue.Visible = isClahe
End Sub

Private Sub familyValue_Click()
    UpdateFamilyRows
End Sub

' 숫자 입력과 범위를 검사합니다. 실패하면 해당 칸으로 이동합니다.
Private Function ReadRange(box As TextBox, ByVal lo As Double, ByVal hi As Double, _
                           ByVal what As String, ByRef result As Double) As Boolean
    If Not IsNumeric(box.Text) Then
        MsgBox what & "은(는) 숫자로 입력하세요.", vbExclamation, Me.Caption
        box.SetFocus
        Exit Function
    End If
    result = CDbl(box.Text)
    If result < lo Or result > hi Then
        MsgBox what & "은(는) " & CStr(lo) & "에서 " & CStr(hi) & " 사이여야 합니다.", _
               vbExclamation, Me.Caption
        box.SetFocus
        Exit Function
    End If
    ReadRange = True
End Function

Private Sub ConfirmButton_Click()
    Dim vGamma As Double
    Dim vSigma As Double
    Dim vStrength As Double
    Dim vFloor As Double
    Dim vClip As Double
    If familyValue.ListIndex < 0 Then
        MsgBox "알고리즘을 선택하세요.", vbExclamation, Me.Caption
        Exit Sub
    End If
    If Not ReadRange(gammaValue, 0.1, 5#, "감마", vGamma) Then Exit Sub
    If familyValue.ListIndex = 1 Then
        If Not ReadRange(sigmaValue, 0.5, 85#, "흐림 반경", vSigma) Then Exit Sub
        If Not ReadRange(strengthValue, 0#, 2#, "강도", vStrength) Then Exit Sub
        If Not ReadRange(floorValue, 0#, 1#, "최소 차이", vFloor) Then Exit Sub
        gSigma = vSigma
        gStrength = vStrength
        gFloor = vFloor
    ElseIf familyValue.ListIndex = 2 Then
        If Not ReadRange(clipValue, 0.1, 10#, "대비 제한", vClip) Then Exit Sub
        gClip = vClip
    End If
    gFamily = familyValue.ListIndex
    gGamma = vGamma
    gSerpentine = IIf(isSerpentine.value = 1, 1, 0)
    gOptionsAccepted = True
    Unload Me
End Sub

Private Sub CancelButton_Click()
    gOptionsAccepted = False
    Unload Me
End Sub

Private Sub Form_QueryUnload(Cancel As Integer, UnloadMode As Integer)
    If UnloadMode = 0 Then gOptionsAccepted = False
End Sub

