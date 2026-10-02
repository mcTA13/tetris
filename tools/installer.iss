; Windows 用インストーラー（Inno Setup 6）。tools\export.ps1 から呼ばれる。
; 管理者権限なしで %LOCALAPPDATA%\Programs\Tetris に入れる（ゲームからのアップデートで確認画面を出さないため）。
; 記録と設定は %APPDATA%\Godot\app_userdata\Tetris にあるので、入れ直しても消えない。

#ifndef AppVersion
  #define AppVersion "0.0"
#endif

[Setup]
AppId={{43DA596D-606C-4B56-B881-E4E076A89D6C}
AppName=Tetris
AppVersion={#AppVersion}
AppVerName=Tetris v{#AppVersion}
AppPublisher=mcTA13
AppPublisherURL=https://github.com/mcTA13/tetris
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\Tetris
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SourceDir=..\build
OutputDir=..\dist
OutputBaseFilename=Tetris-Setup-v{#AppVersion}
SetupIconFile=..\assets\icon\icon.ico
UninstallDisplayIcon={app}\Tetris.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; アップデートで上書きするとき、動いているゲーム（と CPU の思考エンジン）を閉じる
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "ja"; MessagesFile: "compiler:Languages\Japanese.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{autoprograms}\Tetris"; Filename: "{app}\Tetris.exe"
Name: "{autodesktop}\Tetris"; Filename: "{app}\Tetris.exe"; Tasks: desktopicon

[Run]
; ふつうに入れたときは、最後の画面で「起動する」を選べる
Filename: "{app}\Tetris.exe"; Description: "{cm:LaunchProgram,Tetris}"; Flags: nowait postinstall skipifsilent
; ゲームからのアップデート（確認なしで実行）のときは、終わったらそのまま起動し直す
Filename: "{app}\Tetris.exe"; Flags: nowait; Check: WizardSilent
