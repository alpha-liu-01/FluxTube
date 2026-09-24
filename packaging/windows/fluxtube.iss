; Per-user installer for the Windows x64 release folder.
; SourceDir is the repo root. OutputDir and SetupIconFile are relative to that.
;   ISCC.exe /DAppVersion=0.9.3+14 /DVersionInfo=0.9.3.14 packaging\windows\fluxtube.iss
#ifndef AppVersion
#define AppVersion "0.9.3+14"
#endif
#ifndef VersionInfo
#define VersionInfo "0.9.3.14"
#endif

[Setup]
AppId={{8C4E2A71-6B19-4F0D-9C55-2E7A1D4B8F30}
AppName=FluxTube
AppVersion={#AppVersion}
AppPublisher=FluxTube
DefaultDirName={localappdata}\Programs\FluxTube
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SourceDir=..\..
OutputDir=dist
OutputBaseFilename=fluxtube-{#AppVersion}-windows-x64
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\fluxtube.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
VersionInfoVersion={#VersionInfo}
VersionInfoProductVersion={#VersionInfo}
DisableProgramGroupPage=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\FluxTube"; Filename: "{app}\fluxtube.exe"
