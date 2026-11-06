[Setup]
; 프로그램 기본 정보 (.vbp 기준)
AppName=getfax
AppVersion=0.9.9
AppPublisher=Fax C Portable Engine
AppComments=복잡한 컬러와 무늬가 있는 문서를 최대한 보존하여 팩스용 이미지로 만듭니다.
DefaultDirName={autopf}\getfax
DefaultGroupName=getfax

; 고전 UI 스타일 강제 적용 (왼쪽 파란 배너 마법사)
WizardStyle=classic
Compression=lzma2
SolidCompression=yes
OutputDir=Output
OutputBaseFilename=getfax_Setup_v0.9.9

; [핵심] 64비트 OS에서는 64비트 모드로 동작하되, 설치 파일 자체는 32비트 OS에서도 켜지도록 설정
ArchitecturesAllowed=x86 x64
ArchitecturesInstallIn64BitMode=x64

; 한국어 단독 모드
LanguageDetectionMethod=none
ShowLanguageDialog=no

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Files]
; 1. VB5 런타임 및 공용 컨트롤 (OS 비트 무관하게 항상 확인 후 시스템 폴더 설치 및 레지스트리 등록)
Source: "MSVBVM50.DLL"; DestDir: "{sys}"; Flags: restartreplace sharedfile regserver 32bit
Source: "comctl32.ocx"; DestDir: "{sys}"; Flags: restartreplace sharedfile regserver 32bit

; 2. 64비트 전용 파일 및 디버그 심볼 (64비트 OS일 때만 복사)
Source: "getfax_x64.exe"; DestDir: "{app}"; Check: Is64BitInstallMode; Flags: ignoreversion
Source: "getfax_x64.pdb"; DestDir: "{app}"; Check: Is64BitInstallMode; Flags: ignoreversion
Source: "faxeng64.exe"; DestDir: "{app}"; Check: Is64BitInstallMode; Flags: ignoreversion

; 3. 32비트 전용 파일 및 디버그 심볼 (32비트 OS일 때만 복사)
Source: "getfax_x86.exe"; DestDir: "{app}"; Check: not Is64BitInstallMode; Flags: ignoreversion
Source: "getfax_x86.pdb"; DestDir: "{app}"; Check: not Is64BitInstallMode; Flags: ignoreversion
Source: "faxeng32.exe"; DestDir: "{app}"; Check: not Is64BitInstallMode; Flags: ignoreversion

[Registry]
; ==========================================
; [64비트 OS용 탐색기 레지스트리 등록]
; ==========================================
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertGUI"; ValueType: string; ValueName: ""; ValueData: "팩스 변환 설정 열기..."; Flags: uninsdeletekey; Check: Is64BitInstallMode
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertGUI"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\getfax_x64.exe"""; Check: Is64BitInstallMode
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertGUI\command"; ValueType: string; ValueName: ""; ValueData: """{app}\getfax_x64.exe"" ""%1"""; Check: Is64BitInstallMode

Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertAuto"; ValueType: string; ValueName: ""; ValueData: "여기에 팩스 TIFF로 자동 변환"; Flags: uninsdeletekey; Check: Is64BitInstallMode
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertAuto"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\getfax_x64.exe"""; Check: Is64BitInstallMode
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertAuto\command"; ValueType: string; ValueName: ""; ValueData: """{app}\faxeng64.exe"" ""%1"" ""%1"" apply 1"; Check: Is64BitInstallMode

; ==========================================
; [32비트 OS용 탐색기 레지스트리 등록]
; ==========================================
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertGUI"; ValueType: string; ValueName: ""; ValueData: "팩스 변환 설정 열기..."; Flags: uninsdeletekey; Check: not Is64BitInstallMode
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertGUI"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\getfax_x86.exe"""; Check: not Is64BitInstallMode
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertGUI\command"; ValueType: string; ValueName: ""; ValueData: """{app}\getfax_x86.exe"" ""%1"""; Check: not Is64BitInstallMode

Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertAuto"; ValueType: string; ValueName: ""; ValueData: "여기에 팩스 TIFF로 자동 변환"; Flags: uninsdeletekey; Check: not Is64BitInstallMode
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertAuto"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\getfax_x86.exe"""; Check: not Is64BitInstallMode
Root: HKCR; Subkey: "SystemFileAssociations\image\shell\FaxConvertAuto\command"; ValueType: string; ValueName: ""; ValueData: """{app}\faxeng32.exe"" ""%1"" ""%1"" apply 1"; Check: not Is64BitInstallMode

[Icons]
; 바탕화면/시작 메뉴 단축아이콘 (아키텍처별로 다르게 연결)
Name: "{group}\getfax"; Filename: "{app}\getfax_x64.exe"; Check: Is64BitInstallMode
Name: "{group}\getfax"; Filename: "{app}\getfax_x86.exe"; Check: not Is64BitInstallMode
Name: "{group}\프로그램 제거"; Filename: "{uninstallexe}"