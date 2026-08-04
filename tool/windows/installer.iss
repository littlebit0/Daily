; Build with: ISCC.exe /DMyAppVersion=3.0.1 tool\windows\installer.iss
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

[Setup]
AppId={{A27D9263-2AE6-4E06-B2C5-CFA9ADFE8B2F}
AppName=DailyCalendar
AppVersion={#MyAppVersion}
AppPublisher=littlebit0
DefaultDirName={autopf}\DailyCalendar
DefaultGroupName=DailyCalendar
UninstallDisplayIcon={app}\DailyCalendar.exe
OutputDir=..\..\dist
OutputBaseFilename=daily-windows-{#MyAppVersion}-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "바탕 화면에 바로가기 만들기"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: files; Name: "{app}\daily.exe"

[Icons]
Name: "{autoprograms}\DailyCalendar"; Filename: "{app}\DailyCalendar.exe"
Name: "{autodesktop}\DailyCalendar"; Filename: "{app}\DailyCalendar.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\DailyCalendar.exe"; Description: "DailyCalendar 실행"; Flags: nowait postinstall skipifsilent
