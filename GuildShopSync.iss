; GuildShopSync Installer Script
; Inno Setup 6.x

#define MyAppName "GuildShopSync"
#define MyAppVersion "2.9"
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
Source: "source\SetupTask.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "source\KillSyncService.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "source\README.txt"; DestDir: "{app}"; Flags: ignoreversion

; Addon files - will be copied to WoW folder during install
Source: "source\GuildShopSync.lua"; DestDir: "{app}\Addon"; Flags: ignoreversion
Source: "source\GuildShopSync.toc"; DestDir: "{app}\Addon"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName} README"; Filename: "{app}\README.txt"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Registry]
; Store WoW path for the sync service (PRIMARY method - used by v2.6+)
Root: HKCU; Subkey: "Software\{#MyAppName}"; ValueType: string; ValueName: "WoWPath"; ValueData: "{code:GetWoWPath}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey

[Run]
; Kill any existing sync processes before we start
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\KillSyncService.ps1"""; Flags: runhidden waituntilterminated; StatusMsg: "Stopping any running sync processes..."

; Install the addon to WoW folder
Filename: "xcopy"; Parameters: """{app}\Addon\*"" ""{code:GetWoWPath}\Interface\AddOns\GuildShopSync\"" /E /I /Y"; Flags: runhidden waituntilterminated; StatusMsg: "Installing addon to WoW folder..."

; Create scheduled task using SetupTask.ps1 (v2.8: uses Register-ScheduledTask for full settings control)
; Runs under admin elevation from installer - sets battery, restart, time limit, etc.
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\SetupTask.ps1"" -ServicePath ""{app}\SyncService.ps1"""; Flags: runhidden waituntilterminated; StatusMsg: "Creating auto-start task with correct settings..."

; Start the sync service now
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\SyncService.ps1"""; Flags: runhidden nowait postinstall; StatusMsg: "Starting sync service..."

[UninstallRun]
; Stop and remove scheduled task
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Unregister-ScheduledTask -TaskName 'GuildShopSync' -Confirm:$false -ErrorAction SilentlyContinue"""; Flags: runhidden waituntilterminated

; Kill any running sync process
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\KillSyncService.ps1"""; Flags: runhidden waituntilterminated

; Remove old environment variable if exists (cleanup from v2.5)
Filename: "cmd"; Parameters: "/c REG delete ""HKCU\Environment"" /v GUILDSHOPSYNC_WOWPATH /f"; Flags: runhidden

[UninstallDelete]
; Remove addon from WoW folder
Type: filesandordirs; Name: "{code:GetWoWPath}\Interface\AddOns\GuildShopSync"

; Remove error log folder
Type: filesandordirs; Name: "{localappdata}\GuildShopSync"

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
  TestPaths: array[0..6] of String;
  i: Integer;
  RegPath: String;
begin
  Result := '';

  // First check if we have a previous install with saved path
  if RegQueryStringValue(HKCU, 'Software\GuildShopSync', 'WoWPath', RegPath) then
  begin
    if DirExists(RegPath) and FileExists(RegPath + '\WoW.exe') then
    begin
      Result := RegPath;
      Exit;
    end;
  end;

  // Common TurtleWoW installation paths
  TestPaths[0] := 'C:\turtlewow';
  TestPaths[1] := 'D:\turtlewow';
  TestPaths[2] := 'C:\Games\turtlewow';
  TestPaths[3] := 'D:\Games\turtlewow';
  TestPaths[4] := ExpandConstant('{userdocs}') + '\turtlewow';
  TestPaths[5] := 'C:\Program Files\turtlewow';
  TestPaths[6] := 'C:\Program Files (x86)\turtlewow';

  for i := 0 to 6 do
  begin
    if DirExists(TestPaths[i]) and FileExists(TestPaths[i] + '\WoW.exe') then
    begin
      Result := TestPaths[i];
      Exit;
    end;
  end;
end;

procedure CleanupOldInstallation;
var
  ResultCode: Integer;
  OldStartupVbs: String;
begin
  // Kill any running PowerShell processes that might be our sync service
  Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -Command "Get-WmiObject Win32_Process -Filter ""Name=''powershell.exe''"" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match ''SyncService'' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; Start-Sleep -Seconds 1"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // Remove old scheduled task if exists
  Exec('schtasks', '/delete /tn "GuildShopSync" /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // Clean up old environment variable from v2.5 and earlier
  Exec('cmd', '/c REG delete "HKCU\Environment" /v GUILDSHOPSYNC_WOWPATH /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // Remove old VBS startup scripts that might exist from manual installations
  OldStartupVbs := ExpandConstant('{userstartup}') + '\GuildShopSync.vbs';
  if FileExists(OldStartupVbs) then
    DeleteFile(OldStartupVbs);
end;

function CheckPreviousInstall: Boolean;
var
  UninstallKey: String;
  UninstallString: String;
  ResultCode: Integer;
  PrevVersion: String;
begin
  Result := True;
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{8F4E5A2B-1C3D-4E5F-A6B7-C8D9E0F1A2B3}_is1';

  // Check for previous installer-based installation
  if RegQueryStringValue(HKLM, UninstallKey, 'UninstallString', UninstallString) or
     RegQueryStringValue(HKCU, UninstallKey, 'UninstallString', UninstallString) then
  begin
    // Get previous version
    RegQueryStringValue(HKCU, 'Software\GuildShopSync', 'Version', PrevVersion);

    if MsgBox('A previous version of GuildShopSync (' + PrevVersion + ') is installed.' + #13#10 + #13#10 +
              'It will be automatically removed before installing version {#MyAppVersion}.' + #13#10 + #13#10 +
              'Continue?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      // Run the uninstaller silently
      UninstallString := RemoveQuotes(UninstallString);
      Exec(UninstallString, '/VERYSILENT /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Result := True;
    end
    else
      Result := False;
  end
  else
  begin
    // No previous installer found, but still clean up any manual installations
    CleanupOldInstallation;
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

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';
  // Kill running SyncService BEFORE files are overwritten so mutex is released
  Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -Command "Get-WmiObject Win32_Process -Filter ""Name=''powershell.exe''"" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match ''SyncService'' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; Start-Sleep -Seconds 2"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;
