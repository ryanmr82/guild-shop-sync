; GuildShopSync Installer Script
; Inno Setup 6.x

#define MyAppName "GuildShopSync"
#define MyAppVersion "2.5"
#define MyAppPublisher "Thralls Book Club"
#define MyAppURL "https://tbcguild.duckdns.org/consumes"

[Setup]
AppId={{8F4E5A2B-1C3D-4E5F-A6B7-C8D9E0F1A2B3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=output
OutputBaseFilename=GuildShopSync-Setup-v{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
DisableProgramGroupPage=yes

; Auto-uninstall previous versions
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Main program files
Source: "source\SyncService.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "source\README.txt"; DestDir: "{app}"; Flags: ignoreversion

; Addon files - will be copied to WoW folder during install
Source: "source\GuildShopSync.lua"; DestDir: "{app}\Addon"; Flags: ignoreversion
Source: "source\GuildShopSync.toc"; DestDir: "{app}\Addon"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName} README"; Filename: "{app}\README.txt"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Registry]
; Store WoW path for the sync service
Root: HKCU; Subkey: "Software\{#MyAppName}"; ValueType: string; ValueName: "WoWPath"; ValueData: "{code:GetWoWPath}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey

[Run]
; Install the addon to WoW folder
Filename: "xcopy"; Parameters: """{app}\Addon\*"" ""{code:GetWoWPath}\Interface\AddOns\GuildShopSync\"" /E /I /Y"; Flags: runhidden waituntilterminated

; Create scheduled task for auto-sync (runs at user logon)
Filename: "schtasks"; Parameters: "/create /tn ""GuildShopSync"" /tr ""powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File '{app}\SyncService.ps1'"" /sc onlogon /rl limited /f"; Flags: runhidden waituntilterminated

; Set environment variable for sync service
Filename: "setx"; Parameters: "GUILDSHOPSYNC_WOWPATH ""{code:GetWoWPath}"""; Flags: runhidden waituntilterminated

; Start the sync service now
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\SyncService.ps1"""; Flags: runhidden nowait

[UninstallRun]
; Stop and remove scheduled task
Filename: "schtasks"; Parameters: "/delete /tn ""GuildShopSync"" /f"; Flags: runhidden waituntilterminated

; Kill any running sync process
Filename: "taskkill"; Parameters: "/f /im powershell.exe /fi ""WINDOWTITLE eq GuildShopSync*"""; Flags: runhidden

[UninstallDelete]
; Remove addon from WoW folder
Type: filesandordirs; Name: "{code:GetWoWPath}\Interface\AddOns\GuildShopSync"

[Code]
var
  WoWPathPage: TInputDirWizardPage;
  WoWPath: String;

function GetWoWPath(Param: String): String;
begin
  Result := WoWPath;
end;

function DetectWoWPath: String;
var
  TestPaths: array[0..4] of String;
  i: Integer;
begin
  Result := '';

  // Common TurtleWoW installation paths
  TestPaths[0] := 'C:\turtlewow';
  TestPaths[1] := 'D:\turtlewow';
  TestPaths[2] := 'C:\Games\turtlewow';
  TestPaths[3] := 'D:\Games\turtlewow';
  TestPaths[4] := ExpandConstant('{userdocs}') + '\turtlewow';

  for i := 0 to 4 do
  begin
    if DirExists(TestPaths[i]) and FileExists(TestPaths[i] + '\WoW.exe') then
    begin
      Result := TestPaths[i];
      Exit;
    end;
  end;
end;

function CheckPreviousInstall: Boolean;
var
  UninstallKey: String;
  UninstallString: String;
  ResultCode: Integer;
begin
  Result := True;
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{8F4E5A2B-1C3D-4E5F-A6B7-C8D9E0F1A2B3}_is1';

  if RegQueryStringValue(HKLM, UninstallKey, 'UninstallString', UninstallString) or
     RegQueryStringValue(HKCU, UninstallKey, 'UninstallString', UninstallString) then
  begin
    if MsgBox('A previous version of GuildShopSync is installed.' + #13#10 + #13#10 +
              'It will be automatically removed before installing the new version.' + #13#10 + #13#10 +
              'Continue?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      // Run the uninstaller silently
      UninstallString := RemoveQuotes(UninstallString);
      Exec(UninstallString, '/VERYSILENT /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Result := True;
    end
    else
      Result := False;
  end;
end;

procedure InitializeWizard;
begin
  // Detect WoW path
  WoWPath := DetectWoWPath;

  // Create custom page for WoW path selection
  WoWPathPage := CreateInputDirPage(wpSelectDir,
    'Select World of Warcraft Location',
    'Where is TurtleWoW installed?',
    'Select the folder where TurtleWoW is installed, then click Next.',
    False, '');
  WoWPathPage.Add('');

  if WoWPath <> '' then
    WoWPathPage.Values[0] := WoWPath
  else
    WoWPathPage.Values[0] := 'C:\turtlewow';
end;

function InitializeSetup: Boolean;
begin
  Result := CheckPreviousInstall;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if CurPageID = WoWPathPage.ID then
  begin
    WoWPath := WoWPathPage.Values[0];

    // Validate WoW path
    if not DirExists(WoWPath) then
    begin
      MsgBox('The selected folder does not exist.' + #13#10 + #13#10 +
             'Please select your TurtleWoW installation folder.', mbError, MB_OK);
      Result := False;
      Exit;
    end;

    if not FileExists(WoWPath + '\WoW.exe') then
    begin
      MsgBox('WoW.exe was not found in the selected folder.' + #13#10 + #13#10 +
             'Please select your TurtleWoW installation folder.', mbError, MB_OK);
      Result := False;
      Exit;
    end;

    // Create AddOns folder if it doesn't exist
    if not DirExists(WoWPath + '\Interface\AddOns') then
      ForceDirectories(WoWPath + '\Interface\AddOns');
  end;
end;
