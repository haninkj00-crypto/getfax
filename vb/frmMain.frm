VERSION 5.00
Object = "{F9043C88-F6F2-101A-A3C9-08002B2F49FB}#1.2#0"; "COMDLG32.OCX"
Begin VB.Form frmMain 
   Caption         =   "get_fax"
   ClientHeight    =   3195
   ClientLeft      =   60
   ClientTop       =   630
   ClientWidth     =   4680
   LinkTopic       =   "Form1"
   ScaleHeight     =   3195
   ScaleWidth      =   4680
   StartUpPosition =   3  'Windows Default
   Begin MSComDlg.CommonDialog dlgCommonDialog 
      Left            =   1740
      Top             =   1350
      _ExtentX        =   847
      _ExtentY        =   847
      _Version        =   393216
   End
   Begin VB.Menu mnuFile 
      Caption         =   "1000"
      Begin VB.Menu mnuFileNew 
         Caption         =   "1001"
         Shortcut        =   ^N
      End
      Begin VB.Menu mnuFileOpen 
         Caption         =   "1002"
         Shortcut        =   ^O
      End
      Begin VB.Menu mnuFileClose 
         Caption         =   "1003"
      End
      Begin VB.Menu mnuFileBar1 
         Caption         =   "-"
      End
      Begin VB.Menu mnuFileSave 
         Caption         =   "1004"
         Shortcut        =   ^S
      End
      Begin VB.Menu mnuFileSaveAs 
         Caption         =   "1005"
      End
      Begin VB.Menu mnuFileSaveAll 
         Caption         =   "1006"
      End
      Begin VB.Menu mnuFileBar2 
         Caption         =   "-"
      End
      Begin VB.Menu mnuFileProperties 
         Caption         =   "1007"
      End
      Begin VB.Menu mnuFileBar3 
         Caption         =   "-"
      End
      Begin VB.Menu mnuFilePageSetup 
         Caption         =   "1008"
      End
      Begin VB.Menu mnuFilePrintPreview 
         Caption         =   "1009"
      End
      Begin VB.Menu mnuFilePrint 
         Caption         =   "1010"
         Shortcut        =   ^P
      End
      Begin VB.Menu mnuFileBar4 
         Caption         =   "-"
      End
      Begin VB.Menu mnuFileSend 
         Caption         =   "1011"
      End
      Begin VB.Menu mnuFileBar5 
         Caption         =   "-"
      End
      Begin VB.Menu mnuFileMRU 
         Caption         =   ""
         Index           =   0
         Visible         =   0   'False
      End
      Begin VB.Menu mnuFileMRU 
         Caption         =   ""
         Index           =   1
         Visible         =   0   'False
      End
      Begin VB.Menu mnuFileMRU 
         Caption         =   ""
         Index           =   2
         Visible         =   0   'False
      End
      Begin VB.Menu mnuFileMRU 
         Caption         =   ""
         Index           =   3
         Visible         =   0   'False
      End
      Begin VB.Menu mnuFileBar6 
         Caption         =   "-"
         Visible         =   0   'False
      End
      Begin VB.Menu mnuFileExit 
         Caption         =   "1012"
      End
   End
   Begin VB.Menu mnuEdit 
      Caption         =   "1013"
      Begin VB.Menu mnuEditUndo 
         Caption         =   "1014"
         Shortcut        =   ^Z
      End
      Begin VB.Menu mnuEditBar1 
         Caption         =   "-"
      End
      Begin VB.Menu mnuEditCut 
         Caption         =   "1015"
         Shortcut        =   ^X
      End
      Begin VB.Menu mnuEditCopy 
         Caption         =   "1016"
         Shortcut        =   ^C
      End
      Begin VB.Menu mnuEditPaste 
         Caption         =   "1017"
         Shortcut        =   ^V
      End
      Begin VB.Menu mnuEditPasteSpecial 
         Caption         =   "1018"
      End
   End
   Begin VB.Menu mnuView 
      Caption         =   "1019"
      Begin VB.Menu mnuViewToolbar 
         Caption         =   "1020"
         Checked         =   -1  'True
      End
      Begin VB.Menu mnuViewStatusBar 
         Caption         =   "1021"
         Checked         =   -1  'True
      End
      Begin VB.Menu mnuViewBar2 
         Caption         =   "-"
      End
      Begin VB.Menu mnuViewRefresh 
         Caption         =   "1022"
      End
      Begin VB.Menu mnuViewOptions 
         Caption         =   "1023"
      End
   End
   Begin VB.Menu mnuHelp 
      Caption         =   "1024"
      Begin VB.Menu mnuHelpContents 
         Caption         =   "1025"
      End
      Begin VB.Menu mnuHelpSearch 
         Caption         =   "1026"
      End
      Begin VB.Menu mnuHelpBar1 
         Caption         =   "-"
      End
      Begin VB.Menu mnuHelpAbout 
         Caption         =   "1027"
      End
   End
End
Attribute VB_Name = "frmMain"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private Sub mnuHelpContents_Click()
    Dim nRet As Integer
    If Len(App.HelpFile) = 0 Then
        MsgBox "Unable to display Help Contents. There is no Help associated with this project.", vbInformation, Me.Caption
    Else
        On Error Resume Next
        nRet = OSWinHelp(Me.hwnd, App.HelpFile, 3, 0)
        If Err Then MsgBox Err.Description
    End If
End Sub

Private Sub mnuHelpSearch_Click()
    Dim nRet As Integer
    If Len(App.HelpFile) = 0 Then
        MsgBox "Unable to display Help Contents. There is no Help associated with this project.", vbInformation, Me.Caption
    Else
        On Error Resume Next
        nRet = OSWinHelp(Me.hwnd, App.HelpFile, 261, 0)
        If Err Then MsgBox Err.Description
    End If
End Sub

Private Sub mnuViewRefresh_Click()
    MsgBox "Refresh Code goes here!"
End Sub
Private Sub mnuEditCopy_Click()
    MsgBox "Copy Code goes here!"
End Sub
Private Sub mnuEditCut_Click()
    MsgBox "Cut Code goes here!"
End Sub
Private Sub mnuEditPaste_Click()
    MsgBox "Paste Code goes here!"
End Sub
Private Sub mnuEditPasteSpecial_Click()
    MsgBox "Paste Special Code goes here!"
End Sub
Private Sub mnuEditUndo_Click()
    MsgBox "Undo Code goes here!"
End Sub
Private Sub mnuFileOpen_Click()
    Dim sFile As String
    With dlgCommonDialog
        .Filter = "All Files (*.*)|*.*"
        .ShowOpen
        If Len(.filename) = 0 Then Exit Sub
        sFile = .filename
    End With
End Sub
Private Sub mnuFileClose_Click()
    MsgBox "Close Code goes here!"
End Sub
Private Sub mnuFileSave_Click()
    MsgBox "Save Code goes here!"
End Sub
Private Sub mnuFileSaveAs_Click()
    dlgCommonDialog.ShowSave
End Sub
Private Sub mnuFileSaveAll_Click()
    MsgBox "Save All Code goes here!"
End Sub
Private Sub mnuFileProperties_Click()
    MsgBox "Properties Code goes here!"
End Sub
Private Sub mnuFilePageSetup_Click()
    dlgCommonDialog.ShowPrinter
End Sub
Private Sub mnuFilePrintPreview_Click()
    MsgBox "Print Preview Code goes here!"
End Sub
Private Sub mnuFilePrint_Click()
    MsgBox "Print Code goes here!"
End Sub
Private Sub mnuFileSend_Click()
    MsgBox "Send Code goes here!"
End Sub
Private Sub mnuFileMRU_Click(Index As Integer)
    MsgBox "MRU Code goes here!"
End Sub
Private Sub mnuFileExit_Click()
    Unload Me
End Sub
Private Sub mnuFileNew_Click()
    MsgBox "New File Code goes here!"
End Sub