[Setup]
AppId={{SABUFLIX-APP-ID-12345}
AppName=Sabuflix
AppVersion=1.0.0
AppPublisher=Sabuflix
AppPublisherURL=https://github.com/tyyyrvid-a11y/SabuflixRenew
DefaultDirName={autopf}\Sabuflix
DisableProgramGroupPage=yes
OutputBaseFilename=Sabuflix-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Sabuflix"; Filename: "{app}\sabuflix.exe"
Name: "{autodesktop}\Sabuflix"; Filename: "{app}\sabuflix.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\sabuflix.exe"; Description: "{cm:LaunchProgram,Sabuflix}"; Flags: nowait postinstall skipifsilent
