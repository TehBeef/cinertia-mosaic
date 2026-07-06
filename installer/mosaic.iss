; Inno Setup script for Mosaic.
; Build with: ISCC.exe mosaic.iss  (after staging the deploy\ folder)

#define MyAppName "Mosaic"
#define MyAppVersion "0.2.0"
#define MyAppPublisher "Cinertia Systems"
#define MyAppExeName "Mosaic.exe"

[Setup]
AppId={{7E1B7C52-9E64-4B7A-B1B7-2D5C0A4A11D1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=Mosaic-Setup-{#MyAppVersion}
SetupIconFile=..\resources\mosaic.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; Everything staged by scripts\stage-deploy.ps1 — app exe, Qt runtime,
; QML modules, and the NDI runtime DLL (bundled in the app folder per
; the NDI SDK license, never the system path).
Source: "..\deploy\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

