program SettingsSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.IOUtils, System.Win.Registry, Winapi.Windows,
  XmlDoc.Plugin.Settings in '..\src\Plugin\XmlDoc.Plugin.Settings.pas',
  XmlDoc.Logger in '..\src\Core\XmlDoc.Logger.pas';

var
  Original, Writer, Reader: TPluginSettings;
  Changed: TGlobalSettings;
  Log: TLogger;
  TempDir, FirstPath, SecondPath, RegistryRoot: string;
  Registry: TRegistry;
begin
  TempDir := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  FirstPath := TPath.Combine(TempDir, 'first.log');
  SecondPath := TPath.Combine(TempDir, 'second.log');
  Log := TLogger.Create;
  try
    Log.Configure(llWarn, FirstPath);
    Log.Info('FILTERED');
    Log.Warn('FIRST');
    Log.Configure(llDebug, SecondPath);
    Log.Debug('SECOND');
    Log.Free; Log := nil;
    if TFile.ReadAllText(FirstPath).Contains('FILTERED') or
       not TFile.ReadAllText(FirstPath).Contains('FIRST') or
       not TFile.ReadAllText(SecondPath).Contains('SECOND') then
      raise Exception.Create('Log threshold or destination reconfiguration failed');
    Writeln('PASS: logging creates missing files, filters entries and switches destination');
  finally
    Log.Free;
    if TFile.Exists(FirstPath) then TFile.Delete(FirstPath);
    if TFile.Exists(SecondPath) then TFile.Delete(SecondPath);
    if TDirectory.Exists(TempDir) then TDirectory.Delete(TempDir);
  end;
  Original := TPluginSettings.Create;
  RegistryRoot := 'Software\XmlDocPlugin\Tests\' + TPath.GetRandomFileName;
  Registry := TRegistry.Create(KEY_ALL_ACCESS);
  Registry.RootKey := HKEY_CURRENT_USER;
  Writer := TPluginSettings.Create(RegistryRoot);
  try
    Changed := Writer.Global;
    Changed.Editor.Theme := 'dark';
    Changed.Editor.FontSize := 17;
    Changed.Editor.DebounceMs := 123;
    Changed.Editor.SaveDebounceMs := 456;
    Changed.Editor.ShowSignatureHeader := False;
    Changed.CodeGen.IndentSize := 4;
    Changed.Stub.PlaceholderPrefix := 'SMOKE: ';
    Changed.Shortcuts.ToggleInspector := 12345;
    Changed.General.Language := 'en';
    Changed.General.LogLevel := llError;
    Writer.Global := Changed;
    Writer.Save;
    Reader := TPluginSettings.Create(RegistryRoot);
    try
      if (Reader.Global.Editor.Theme <> 'dark') or
         (Reader.Global.Editor.FontSize <> 17) or
         (Reader.Global.Editor.DebounceMs <> 123) or
         (Reader.Global.Editor.SaveDebounceMs <> 456) or
         Reader.Global.Editor.ShowSignatureHeader or
         (Reader.Global.CodeGen.IndentSize <> 4) or
         (Reader.Global.Stub.PlaceholderPrefix <> 'SMOKE: ') or
         (Reader.Global.Shortcuts.ToggleInspector <> 12345) or
         (Reader.Global.General.Language <> 'en') or
         (TLogger.Instance.Level <> llError) then
        raise Exception.Create('Settings were not loaded by a fresh settings instance');
      Writeln('PASS: editor, code generation, stub, shortcut, and general settings survive recreation');
    finally
      Reader.Free;
    end;
    if not Registry.DeleteKey(RegistryRoot + '\Editor') then
      raise Exception.Create('Unable to prepare missing Editor regression case');
    Reader := TPluginSettings.Create(RegistryRoot);
    try
      if (Reader.Global.Stub.PlaceholderPrefix <> 'SMOKE: ') or
         (Reader.Global.Shortcuts.ToggleInspector <> 12345) or
         (Reader.Global.General.Language <> 'en') or
         (TLogger.Instance.Level <> llError) then
        raise Exception.Create('Missing Editor key prevented loading independent settings');
      Writeln('PASS: independent settings load without an Editor registry key');
    finally Reader.Free; end;
  finally
    TLogger.Instance.Configure(Original.Global.General.LogLevel, Original.Global.General.LogPath);
    Original.Free;
    Registry.DeleteKey(RegistryRoot);
    Registry.Free;
    Writer.Free;
  end;
end.
