#ifndef StageDir
  #error StageDir must point to the binary payload built by build-installer.ps1
#endif
#ifndef OutputDir
  #define OutputDir ".\output"
#endif
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{C91E1B1C-1B43-4B75-AC3E-D7DC79CCB435}
AppName=XmlDoc Plugin
AppVersion={#AppVersion}
VersionInfoVersion={#AppVersion}
VersionInfoProductVersion={#AppVersion}
AppPublisher=alexeydott
AppPublisherURL=https://github.com/alexeydott/XmlDocPlugin
DefaultDirName={localappdata}\Programs\XmlDocPlugin
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
MinVersion=10.0
ArchitecturesAllowed=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=XmlDocPlugin-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\LICENSE
CloseApplications=no
RestartApplications=no
UninstallDisplayName=XmlDoc Plugin
SetupLogging=yes

[Types]
Name: full; Description: "All installed supported IDEs"
Name: custom; Description: "Custom installation"; Flags: iscustom

[Components]
Name: rad12x86; Description: "RAD Studio 12 - 32-bit IDE"; Types: full; Check: TargetAvailable(0)
Name: rad13x86; Description: "RAD Studio 13 - 32-bit IDE"; Types: full; Check: TargetAvailable(1)
Name: rad13x64; Description: "RAD Studio 13 - 64-bit IDE"; Types: full; Check: TargetAvailable(2)

[Files]
Source: "{#StageDir}\bin\XmlDocGen.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "{#StageDir}\rad12-x86\*"; DestDir: "{app}\rad12-x86"; Components: rad12x86; Flags: ignoreversion
Source: "{#StageDir}\rad13-x86\*"; DestDir: "{app}\rad13-x86"; Components: rad13x86; Flags: ignoreversion
Source: "{#StageDir}\rad13-x64\*"; DestDir: "{app}\rad13-x64"; Components: rad13x64; Flags: ignoreversion
Source: "{#StageDir}\MicrosoftEdgeWebview2Setup.exe"; Flags: dontcopy
Source: "{#StageDir}\manifest.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Code]
type
  TTarget = record
    Component, Directory, Version, BinaryName, Exe, RegistryNode: String;
  end;
var
  Targets: array[0..2] of TTarget;

procedure SetupTargets;
var I: Integer;
begin
  Targets[0].Component := 'rad12x86'; Targets[0].Directory := 'rad12-x86';
  Targets[1].Component := 'rad13x86'; Targets[1].Directory := 'rad13-x86';
  Targets[2].Component := 'rad13x64'; Targets[2].Directory := 'rad13-x64';
  for I := 0 to 2 do begin
    if I = 0 then begin Targets[I].Version := '23.0'; Targets[I].BinaryName := 'XmlDocPlugin290.bpl'; end
    else begin Targets[I].Version := '37.0'; Targets[I].BinaryName := 'XmlDocPlugin370.bpl'; end;
    Targets[I].RegistryNode := 'Software\Embarcadero\BDS\' + Targets[I].Version + '\Known Packages';
    if I = 2 then Targets[I].RegistryNode := Targets[I].RegistryNode + ' x64';
  end;
end;

function TargetAvailable(Index: Integer): Boolean;
begin
  Result := (Targets[Index].Exe <> '') and FileExists(Targets[Index].Exe);
  if (Index = 2) and not IsWin64 then Result := False;
end;

function IDEIsRunning: Boolean;
var Locator, Service, Processes: Variant;
begin
  { Fail closed if process enumeration is unavailable. Never terminate an IDE. }
  Locator := CreateOleObject('WbemScripting.SWbemLocator');
  Service := Locator.ConnectServer('', 'root\CIMV2');
  Processes := Service.ExecQuery('SELECT ProcessId FROM Win32_Process WHERE Name = ''bds.exe''');
  Result := Processes.Count > 0;
end;

function WebViewInstalled: Boolean;
var Version: String;
    Key: String;
begin
  Key := 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
  Result := False;
  if RegQueryStringValue(HKCU32, Key, 'pv', Version) then
    Result := (Version <> '') and (Version <> '0.0.0.0');
  if not Result and RegQueryStringValue(HKLM32, Key, 'pv', Version) then
    Result := (Version <> '') and (Version <> '0.0.0.0');
  if IsWin64 and not Result and RegQueryStringValue(HKCU64, Key, 'pv', Version) then
    Result := (Version <> '') and (Version <> '0.0.0.0');
  if IsWin64 and not Result and RegQueryStringValue(HKLM64, Key, 'pv', Version) then
    Result := (Version <> '') and (Version <> '0.0.0.0');
end;

function InitializeSetup: Boolean;
var I, Found, Code: Integer; Root, Key, BinDir: String;
begin
  Result := False;
  SetupTargets;
  Found := 0;
  for I := 0 to 2 do begin
    Key := 'Software\Embarcadero\BDS\' + Targets[I].Version;
    Root := '';
    if not RegQueryStringValue(HKCU32, Key, 'RootDir', Root) then
      if not RegQueryStringValue(HKLM32, Key, 'RootDir', Root) then
        if IsWin64 then RegQueryStringValue(HKLM64, Key, 'RootDir', Root);
    if Root <> '' then begin
      BinDir := 'bin';
      if I = 2 then BinDir := 'bin64';
      Targets[I].Exe := AddBackslash(Root) + BinDir + '\bds.exe';
      if TargetAvailable(I) then Inc(Found);
    end;
  end;
  if Found = 0 then begin
    SuppressibleMsgBox('RAD Studio 12 or 13 was not found. Its bds.exe must exist on this computer.', mbError, MB_OK, IDOK);
    Exit;
  end;
  try
    if IDEIsRunning then begin
      SuppressibleMsgBox('Close all RAD Studio instances before installing XmlDoc Plugin.', mbError, MB_OK, IDOK);
      Exit;
    end;
  except
    SuppressibleMsgBox('Cannot verify whether RAD Studio is running. Installation has been cancelled.', mbError, MB_OK, IDOK);
    Exit;
  end;
  if not WebViewInstalled then begin
    if WizardSilent then begin
      if ExpandConstant('{param:INSTALLWEBVIEW2|0}') <> '1' then begin
        Log('WebView2 Runtime is missing. Silent installation requires /INSTALLWEBVIEW2=1.');
        Exit;
      end;
    end else
      if MsgBox('Microsoft Edge WebView2 Runtime is required. Install it now? An Internet connection is required. If you decline, Setup will exit.', mbConfirmation, MB_YESNO or MB_DEFBUTTON2) <> IDYES then Exit;
    ExtractTemporaryFile('MicrosoftEdgeWebview2Setup.exe');
    if not Exec(ExpandConstant('{tmp}\MicrosoftEdgeWebview2Setup.exe'), '/silent /install', '', SW_HIDE, ewWaitUntilTerminated, Code) then begin
      SuppressibleMsgBox('Unable to start the WebView2 installer.', mbError, MB_OK, IDOK); Exit;
    end;
    if not WebViewInstalled then begin
      SuppressibleMsgBox('WebView2 Runtime installation did not complete. XmlDoc Plugin has not been installed. Please install WebView2 Runtime and run Setup again.', mbError, MB_OK, IDOK); Exit;
    end;
  end;
  Result := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var I, Count: Integer;
begin
  Result := '';
  try
    if IDEIsRunning then begin Result := 'Close all RAD Studio instances before continuing.'; Exit; end;
  except Result := 'Cannot verify whether RAD Studio is running.'; Exit; end;
  if not WebViewInstalled then begin Result := 'WebView2 Runtime is no longer available.'; Exit; end;
  Count := 0;
  for I := 0 to 2 do
    if WizardIsComponentSelected(Targets[I].Component) then begin
      Inc(Count);
      if not TargetAvailable(I) then begin Result := 'The selected IDE bds.exe no longer exists.'; Exit; end;
    end;
  if Count = 0 then Result := 'Select at least one installed IDE.';
end;

function InstalledFile(Index: Integer): String;
begin
  Result := ExpandConstant('{app}\') + Targets[Index].Directory + '\' + Targets[Index].BinaryName;
end;

function BackupKey(Index: Integer): String;
begin
  Result := 'Software\XmlDocPlugin\Installer\' + Targets[Index].Directory;
end;

procedure RegisterTarget(Index: Integer);
var Names: TArrayOfString; I, Count: Integer; Data, Key, Saved, DisabledNode: String;
begin
  Key := BackupKey(Index);
  Count := 0;
  RegQueryStringValue(HKCU, Key, 'Saved', Saved);
  RegGetValueNames(HKCU, Targets[Index].RegistryNode, Names);
  for I := 0 to GetArrayLength(Names) - 1 do
    if CompareText(ExtractFileName(Names[I]), Targets[Index].BinaryName) = 0 then begin
      if (Saved <> '1') and (CompareText(Names[I], InstalledFile(Index)) <> 0) then begin
        RegQueryStringValue(HKCU, Targets[Index].RegistryNode, Names[I], Data);
        RegWriteStringValue(HKCU, Key, 'Name' + IntToStr(Count), Names[I]);
        RegWriteStringValue(HKCU, Key, 'Data' + IntToStr(Count), Data);
        Inc(Count);
      end;
      RegDeleteValue(HKCU, Targets[Index].RegistryNode, Names[I]);
    end;
  if Saved <> '1' then begin
    RegWriteDWordValue(HKCU, Key, 'Count', Count);
    RegWriteStringValue(HKCU, Key, 'Saved', '1');
  end;
  if not RegWriteStringValue(HKCU, Targets[Index].RegistryNode, InstalledFile(Index), 'XmlDoc Plugin - XML Documentation WYSIWYG Editor') then
    RaiseException('Unable to register XmlDoc Plugin in RAD Studio.');
  RegWriteStringValue(HKCU, Key, 'Installed', InstalledFile(Index));
  DisabledNode := Targets[Index].RegistryNode;
  StringChangeEx(DisabledNode, 'Known Packages', 'Disabled Packages', True);
  RegDeleteValue(HKCU, DisabledNode, InstalledFile(Index));
end;

procedure CurStepChanged(CurStep: TSetupStep);
var I: Integer;
begin
  if CurStep = ssPostInstall then
    for I := 0 to 2 do
      if WizardIsComponentSelected(Targets[I].Component) then RegisterTarget(I);
end;

function InitializeUninstall: Boolean;
begin
  SetupTargets;
  Result := False;
  try Result := not IDEIsRunning; except end;
  if not Result then SuppressibleMsgBox('Close all RAD Studio instances before uninstalling XmlDoc Plugin.', mbError, MB_OK, IDOK);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var I, J: Integer; Count: Cardinal; Key, Name, Data, Installed: String;
begin
  if CurUninstallStep <> usUninstall then Exit;
  for I := 0 to 2 do begin
    Key := BackupKey(I);
    if not RegQueryStringValue(HKCU, Key, 'Installed', Installed) then Continue;
    if CompareText(Installed, InstalledFile(I)) <> 0 then Continue;
    if RegValueExists(HKCU, Targets[I].RegistryNode, Installed) then begin
      RegDeleteValue(HKCU, Targets[I].RegistryNode, Installed);
      Count := 0;
      RegQueryDWordValue(HKCU, Key, 'Count', Count);
      for J := 0 to Integer(Count) - 1 do
        if RegQueryStringValue(HKCU, Key, 'Name' + IntToStr(J), Name) and
          RegQueryStringValue(HKCU, Key, 'Data' + IntToStr(J), Data) then
          RegWriteStringValue(HKCU, Targets[I].RegistryNode, Name, Data);
    end;
    RegDeleteKeyIncludingSubkeys(HKCU, Key);
  end;
end;
