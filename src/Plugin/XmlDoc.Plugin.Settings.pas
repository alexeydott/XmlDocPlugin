/// <summary>Global registry preferences and per-project JSON generation defaults.</summary>
unit XmlDoc.Plugin.Settings;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Win.Registry,
  Winapi.Windows,
  Vcl.Menus,
  XmlDoc.Logger, XmlDoc.Documentation, XmlDoc.Plugin.HelpInsight;

type
  TIndentStyle = (isSpaces, isTabs);

  /// <summary>Editor preferences; legacy fields remain for registry compatibility.</summary>
  TEditorSettings = record
    /// <summary>Legacy registry value; the Inspector opens through its menu command.</summary>
    AutoShowOnCursor: Boolean;
    CollapseEmptySections: Boolean;
    DebounceMs: Integer;
    FontSize: Integer;
    SaveDebounceMs: Integer;
    ShowSignatureHeader: Boolean;
    /// <summary>Fallback for standalone editor hosts; IDE views follow the IDE theme.</summary>
    Theme: string;
  end;

  /// <summary>Legacy formatting preferences retained for registry compatibility; not applied to writes.</summary>
  TCodeGenSettings = record
    BlankLineAfter: Boolean;
    BlankLineBefore: Boolean;
    IndentSize: Integer;
    IndentStyle: TIndentStyle;
    OmitEmptyTags: Boolean;
    /// <summary>Legacy formatting preference; not applied to source writes.</summary>
    TagOrder: TArray<string>;
  end;

  /// <summary>Automatic stub generation and placeholder options.</summary>
  TStubSettings = record
    AutoGenerate: Boolean;
    /// <summary>Whether generated TODO descriptions are included; signature names and known hints remain.</summary>
    IncludePlaceholders: Boolean;
    /// <summary>Prefix used for generated placeholder descriptions.</summary>
    PlaceholderPrefix: string;
    /// <summary>One unfinished-documentation marker per line, independent of the generated prefix.</summary>
    PlaceholderMarkers: string;
  end;

  /// <summary>Keyboard shortcuts for plugin commands.</summary>
  TShortcutSettings = record
    CoverageReport: TShortCut;
    GenerateHelp: TShortCut;
    GenerateStub: TShortCut;
    NextUndocumented: TShortCut;
    PreviousUndocumented: TShortCut;
    ToggleInspector: TShortCut;
  end;

  /// <summary>UI language and logging options, plus legacy update preferences.</summary>
  TGeneralSettings = record
    /// <summary>Legacy registry value; automatic update checking is not enabled.</summary>
    CheckUpdates: Boolean;
    /// <summary>Default HTML and CHM output theme; a nonempty project HTMLTheme overrides it.</summary>
    DocumentationTheme: string;
    Language: string;
    LogLevel: TLogLevel;
    /// <summary>Log destination; an empty string selects the default user log path.</summary>
    LogPath: string;
  end;

  /// <summary>Global preferences persisted in the current user's registry.</summary>
  TGlobalSettings = record
    HelpInsight: THelpInsightSettings;
    CodeGen: TCodeGenSettings;
    Editor: TEditorSettings;
    General: TGeneralSettings;
    Shortcuts: TShortcutSettings;
    Stub: TStubSettings;
  end;

  /// <summary>Project documentation generation defaults.</summary>
  THelpGenSettings = record
    /// <summary>Minimum required generation coverage; zero disables the threshold.</summary>
    CoverageMinPercent: Integer;
    /// <summary>Minimum percentage of fully ready documentation; zero disables the quality gate.</summary>
    ReadyMinPercent: Integer;
    /// <summary>Initially selected IDE output formats: html, chm, md, json, hmxp, mkdocs, docusaurus or vitepress.</summary>
    DefaultFormats: TArray<string>;
    ExcludePatterns: TArray<string>;
    /// <summary>Project HTML and CHM theme override; empty inherits the global documentation theme.</summary>
    HTMLTheme: string;
    IncludePrivate: Boolean;
    InterfaceOnly: Boolean;
    OutputDir: string;
    Title: string;
  end;

  /// <summary>Project preferences loaded from .xmldocplugin.json.</summary>
  TProjectSettings = record
    HelpGen: THelpGenSettings;
  end;

  /// <summary>Loads and saves global registry preferences and per-project JSON defaults.</summary>
  TPluginSettings = class
  strict private
    class var FInstance: TPluginSettings;
  private
    FRegistryRoot: string;
    FGlobal: TGlobalSettings;
    FProject: TProjectSettings;
    FProjectDir: string;

    procedure LoadFromRegistry;
    procedure LoadProjectDefaults;
    procedure LoadProjectSettings(const AProjectDir: string);
    procedure SaveToRegistry;

  public
    /// <summary>Loads preferences from the supplied current-user registry root.</summary>
    constructor Create(const ARegistryRoot: string = 'Software\XmlDocPlugin');

    class function Instance: TPluginSettings;
    class procedure ReleaseInstance;

    /// <summary>Resets global and project preferences to their defaults.</summary>
    procedure LoadDefaults;

    /// <summary>Loads global preferences and applies runtime logging options.</summary>
    procedure Load;

    /// <summary>Saves global preferences and applies runtime logging options.</summary>
    procedure Save;

    /// <summary>Loads preferences for the selected project, resetting previous project defaults.</summary>
    /// <param name="AProjectDir">Project root directory.</param>
    procedure LoadProject(const AProjectDir: string);

    /// <summary>Saves project preferences while preserving unrelated configuration keys.</summary>
    procedure SaveProject;
    /// <summary>Returns the project theme override, global documentation theme, or default, in that order.</summary>
    function DocumentationTheme: string;

    property Global: TGlobalSettings read FGlobal write FGlobal;
    property Project: TProjectSettings read FProject write FProject;
    property ProjectDir: string read FProjectDir;
  end;

implementation

const
  CProjectFileName = '.xmldocplugin.json';

{ TPluginSettings }

constructor TPluginSettings.Create(const ARegistryRoot: string);
begin
  inherited Create;
  FRegistryRoot := ARegistryRoot;
  LoadDefaults;
  Load;
end;

class function TPluginSettings.Instance: TPluginSettings;
begin
  if not Assigned(FInstance) then
    FInstance := TPluginSettings.Create;
  Result := FInstance;
end;

class procedure TPluginSettings.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TPluginSettings.LoadDefaults;
begin
  FGlobal.HelpInsight := THelpInsightSettings.Defaults;
  // Editor
  FGlobal.Editor.AutoShowOnCursor := True;
  FGlobal.Editor.DebounceMs := 300;
  FGlobal.Editor.SaveDebounceMs := 500;
  FGlobal.Editor.FontSize := 13;
  FGlobal.Editor.Theme := 'light';
  FGlobal.Editor.CollapseEmptySections := True;
  FGlobal.Editor.ShowSignatureHeader := True;

  // CodeGen
  FGlobal.CodeGen.IndentStyle := isSpaces;
  FGlobal.CodeGen.IndentSize := 2;
  FGlobal.CodeGen.BlankLineBefore := True;
  FGlobal.CodeGen.BlankLineAfter := False;
  FGlobal.CodeGen.OmitEmptyTags := True;
  FGlobal.CodeGen.TagOrder := TArray<string>.Create(
    'summary', 'remarks', 'param', 'typeparam', 'returns',
    'value', 'exception', 'example', 'seealso', 'permission'
  );

  // Stub
  FGlobal.Stub.AutoGenerate := False;
  FGlobal.Stub.IncludePlaceholders := True;
  FGlobal.Stub.PlaceholderPrefix := 'TODO: ';
  FGlobal.Stub.PlaceholderMarkers := CDefaultPlaceholderMarkers;

  // Shortcuts
  FGlobal.Shortcuts.ToggleInspector := Vcl.Menus.ShortCut(Ord('D'), [ssCtrl, ssShift]);
  FGlobal.Shortcuts.GenerateStub := Vcl.Menus.ShortCut(Ord('G'), [ssCtrl, ssShift]);
  FGlobal.Shortcuts.GenerateHelp := Vcl.Menus.ShortCut(Ord('H'), [ssCtrl, ssShift]);
  FGlobal.Shortcuts.CoverageReport := Vcl.Menus.ShortCut(Ord('R'), [ssCtrl, ssShift]);
  FGlobal.Shortcuts.NextUndocumented := Vcl.Menus.ShortCut(Ord('N'), [ssCtrl, ssAlt]);
  FGlobal.Shortcuts.PreviousUndocumented := Vcl.Menus.ShortCut(Ord('P'), [ssCtrl, ssAlt]);

  // General
  FGlobal.General.Language := 'auto';
  FGlobal.General.DocumentationTheme := 'default';
  FGlobal.General.CheckUpdates := True;
  FGlobal.General.LogLevel := llInfo;
  FGlobal.General.LogPath := '';

  LoadProjectDefaults;
end;

procedure TPluginSettings.Load;
begin
  LoadFromRegistry;
  TLogger.Instance.Configure(FGlobal.General.LogLevel, FGlobal.General.LogPath);
end;

procedure TPluginSettings.Save;
begin
  SaveToRegistry;
  TLogger.Instance.Configure(FGlobal.General.LogLevel, FGlobal.General.LogPath);
end;

procedure TPluginSettings.LoadFromRegistry;
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKey(FRegistryRoot + '\HelpInsight', False) then
    begin
      if LReg.ValueExists('Enabled') then FGlobal.HelpInsight.Enabled := LReg.ReadBool('Enabled');
      if LReg.ValueExists('Extended') then FGlobal.HelpInsight.Extended := LReg.ReadBool('Extended');
      if LReg.ValueExists('Width') then FGlobal.HelpInsight.Width := LReg.ReadInteger('Width');
      if LReg.ValueExists('FontSize') then FGlobal.HelpInsight.FontSize := LReg.ReadInteger('FontSize');
      if LReg.ValueExists('LineHeight') then FGlobal.HelpInsight.LineHeight := LReg.ReadInteger('LineHeight');
      if LReg.ValueExists('ParameterWidth') then FGlobal.HelpInsight.ParameterWidth := LReg.ReadInteger('ParameterWidth');
      if LReg.ValueExists('WrapSignature') then FGlobal.HelpInsight.WrapSignature := LReg.ReadBool('WrapSignature');
      if LReg.ValueExists('CompactParameters') then FGlobal.HelpInsight.CompactParameters := LReg.ReadBool('CompactParameters');
      LReg.CloseKey;
    end;
    if LReg.OpenKey(FRegistryRoot + '\Editor', False) then
    begin

    if LReg.ValueExists('DebounceMs') then
      FGlobal.Editor.DebounceMs := LReg.ReadInteger('DebounceMs');
    if LReg.ValueExists('FontSize') then
      FGlobal.Editor.FontSize := LReg.ReadInteger('FontSize');
    if LReg.ValueExists('Theme') then
      FGlobal.Editor.Theme := LReg.ReadString('Theme');
    if LReg.ValueExists('AutoShowOnCursor') then
      FGlobal.Editor.AutoShowOnCursor := LReg.ReadBool('AutoShowOnCursor');
    if LReg.ValueExists('CollapseEmptySections') then
      FGlobal.Editor.CollapseEmptySections := LReg.ReadBool('CollapseEmptySections');
    if LReg.ValueExists('ShowSignatureHeader') then
      FGlobal.Editor.ShowSignatureHeader := LReg.ReadBool('ShowSignatureHeader');
    if LReg.ValueExists('SaveDebounceMs') then
      FGlobal.Editor.SaveDebounceMs := LReg.ReadInteger('SaveDebounceMs');

    LReg.CloseKey;
    end;

    if LReg.OpenKey(FRegistryRoot + '\CodeGen', False) then
    begin
      if LReg.ValueExists('IndentStyle') then
        FGlobal.CodeGen.IndentStyle := TIndentStyle(LReg.ReadInteger('IndentStyle'));
      if LReg.ValueExists('IndentSize') then
        FGlobal.CodeGen.IndentSize := LReg.ReadInteger('IndentSize');
      if LReg.ValueExists('BlankLineBefore') then
        FGlobal.CodeGen.BlankLineBefore := LReg.ReadBool('BlankLineBefore');
      if LReg.ValueExists('BlankLineAfter') then
        FGlobal.CodeGen.BlankLineAfter := LReg.ReadBool('BlankLineAfter');
      if LReg.ValueExists('OmitEmptyTags') then
        FGlobal.CodeGen.OmitEmptyTags := LReg.ReadBool('OmitEmptyTags');
      LReg.CloseKey;
    end;

    if LReg.OpenKey(FRegistryRoot + '\Stub', False) then
    begin
      if LReg.ValueExists('AutoGenerate') then
        FGlobal.Stub.AutoGenerate := LReg.ReadBool('AutoGenerate');
      if LReg.ValueExists('IncludePlaceholders') then
        FGlobal.Stub.IncludePlaceholders := LReg.ReadBool('IncludePlaceholders');
      if LReg.ValueExists('PlaceholderMarkers') then
        FGlobal.Stub.PlaceholderMarkers := LReg.ReadString('PlaceholderMarkers');
      if LReg.ValueExists('PlaceholderPrefix') then
        FGlobal.Stub.PlaceholderPrefix := LReg.ReadString('PlaceholderPrefix');
      LReg.CloseKey;
    end;

    if LReg.OpenKey(FRegistryRoot + '\Shortcuts', False) then
    begin
      if LReg.ValueExists('ToggleInspector') then
        FGlobal.Shortcuts.ToggleInspector := LReg.ReadInteger('ToggleInspector');
      if LReg.ValueExists('GenerateStub') then
        FGlobal.Shortcuts.GenerateStub := LReg.ReadInteger('GenerateStub');
      if LReg.ValueExists('GenerateHelp') then
        FGlobal.Shortcuts.GenerateHelp := LReg.ReadInteger('GenerateHelp');
      if LReg.ValueExists('CoverageReport') then
        FGlobal.Shortcuts.CoverageReport := LReg.ReadInteger('CoverageReport');
      if LReg.ValueExists('NextUndocumented') then
        FGlobal.Shortcuts.NextUndocumented := LReg.ReadInteger('NextUndocumented');
      if LReg.ValueExists('PreviousUndocumented') then
        FGlobal.Shortcuts.PreviousUndocumented := LReg.ReadInteger('PreviousUndocumented');
      LReg.CloseKey;
    end;

    if LReg.OpenKey(FRegistryRoot + '\General', False) then
    begin
      if LReg.ValueExists('DocumentationTheme') then
        FGlobal.General.DocumentationTheme := LReg.ReadString('DocumentationTheme');
      if LReg.ValueExists('Language') then
        FGlobal.General.Language := LReg.ReadString('Language');
      if LReg.ValueExists('CheckUpdates') then
        FGlobal.General.CheckUpdates := LReg.ReadBool('CheckUpdates');
      if LReg.ValueExists('LogLevel') then
        FGlobal.General.LogLevel := TLogLevel(LReg.ReadInteger('LogLevel'));
      if LReg.ValueExists('LogPath') then
        FGlobal.General.LogPath := LReg.ReadString('LogPath');
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;
end;

procedure TPluginSettings.SaveToRegistry;
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_WRITE);
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKey(FRegistryRoot + '\HelpInsight', True) then
    begin
      LReg.WriteBool('Enabled', FGlobal.HelpInsight.Enabled);
      LReg.WriteBool('Extended', FGlobal.HelpInsight.Extended);
      LReg.WriteInteger('Width', FGlobal.HelpInsight.Width);
      LReg.WriteInteger('FontSize', FGlobal.HelpInsight.FontSize);
      LReg.WriteInteger('LineHeight', FGlobal.HelpInsight.LineHeight);
      LReg.WriteInteger('ParameterWidth', FGlobal.HelpInsight.ParameterWidth);
      LReg.WriteBool('WrapSignature', FGlobal.HelpInsight.WrapSignature);
      LReg.WriteBool('CompactParameters', FGlobal.HelpInsight.CompactParameters);
      LReg.CloseKey;
    end;

    if LReg.OpenKey(FRegistryRoot + '\Editor', True) then
    begin
      LReg.WriteInteger('DebounceMs', FGlobal.Editor.DebounceMs);
      LReg.WriteInteger('FontSize', FGlobal.Editor.FontSize);
      LReg.WriteString('Theme', FGlobal.Editor.Theme);
      LReg.WriteBool('AutoShowOnCursor', FGlobal.Editor.AutoShowOnCursor);
      LReg.WriteBool('CollapseEmptySections', FGlobal.Editor.CollapseEmptySections);
      LReg.WriteBool('ShowSignatureHeader', FGlobal.Editor.ShowSignatureHeader);
      LReg.WriteInteger('SaveDebounceMs', FGlobal.Editor.SaveDebounceMs);
      LReg.CloseKey;
    end;

    if LReg.OpenKey(FRegistryRoot + '\CodeGen', True) then
    begin
      LReg.WriteInteger('IndentStyle', Ord(FGlobal.CodeGen.IndentStyle));
      LReg.WriteInteger('IndentSize', FGlobal.CodeGen.IndentSize);
      LReg.WriteBool('BlankLineBefore', FGlobal.CodeGen.BlankLineBefore);
      LReg.WriteBool('BlankLineAfter', FGlobal.CodeGen.BlankLineAfter);
      LReg.WriteBool('OmitEmptyTags', FGlobal.CodeGen.OmitEmptyTags);
      LReg.CloseKey;
    end;

    if LReg.OpenKey(FRegistryRoot + '\Stub', True) then
    begin
      LReg.WriteBool('AutoGenerate', FGlobal.Stub.AutoGenerate);
      LReg.WriteBool('IncludePlaceholders', FGlobal.Stub.IncludePlaceholders);
      LReg.WriteString('PlaceholderPrefix', FGlobal.Stub.PlaceholderPrefix);
      LReg.WriteString('PlaceholderMarkers', FGlobal.Stub.PlaceholderMarkers);
      LReg.CloseKey;
    end;

    if LReg.OpenKey(FRegistryRoot + '\Shortcuts', True) then
    begin
      LReg.WriteInteger('ToggleInspector', FGlobal.Shortcuts.ToggleInspector);
      LReg.WriteInteger('GenerateStub', FGlobal.Shortcuts.GenerateStub);
      LReg.WriteInteger('GenerateHelp', FGlobal.Shortcuts.GenerateHelp);
      LReg.WriteInteger('CoverageReport', FGlobal.Shortcuts.CoverageReport);
      LReg.WriteInteger('NextUndocumented', FGlobal.Shortcuts.NextUndocumented);
      LReg.WriteInteger('PreviousUndocumented', FGlobal.Shortcuts.PreviousUndocumented);
      LReg.CloseKey;
    end;

    if LReg.OpenKey(FRegistryRoot + '\General', True) then
    begin
      LReg.WriteString('DocumentationTheme', FGlobal.General.DocumentationTheme);
      LReg.WriteString('Language', FGlobal.General.Language);
      LReg.WriteBool('CheckUpdates', FGlobal.General.CheckUpdates);
      LReg.WriteInteger('LogLevel', Ord(FGlobal.General.LogLevel));
      LReg.WriteString('LogPath', FGlobal.General.LogPath);
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;
end;

function TPluginSettings.DocumentationTheme: string;
begin
  Result := Trim(FProject.HelpGen.HTMLTheme);
  if Result = '' then Result := Trim(FGlobal.General.DocumentationTheme);
  if Result = '' then Result := 'default';
end;

procedure TPluginSettings.LoadProjectDefaults;
begin
  // Project defaults
  FProject.HelpGen.DefaultFormats := TArray<string>.Create('html', 'md');
  FProject.HelpGen.OutputDir := 'docs';
  FProject.HelpGen.Title := '';
  FProject.HelpGen.ExcludePatterns := nil;
  FProject.HelpGen.IncludePrivate := False;
  FProject.HelpGen.InterfaceOnly := True;
  FProject.HelpGen.HTMLTheme := '';
  FProject.HelpGen.CoverageMinPercent := 0;
  FProject.HelpGen.ReadyMinPercent := 0;
end;

procedure TPluginSettings.LoadProject(const AProjectDir: string);
begin
  LoadProjectDefaults;
  FProjectDir := AProjectDir;
  LoadProjectSettings(AProjectDir);
end;

procedure TPluginSettings.LoadProjectSettings(const AProjectDir: string);
var
  LPath: string;
  LJson: string;
  LObj: TJSONObject;
  LHelpGen: TJSONObject;
  LArr: TJSONArray;
  I: Integer;
begin
  LPath := TPath.Combine(AProjectDir, CProjectFileName);
  if not TFile.Exists(LPath) then
    Exit;

  try
    LJson := TFile.ReadAllText(LPath, TEncoding.UTF8);
    LObj := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
    if not Assigned(LObj) then
      Exit;

    try
      LHelpGen := LObj.GetValue<TJSONObject>('helpGen');
      if Assigned(LHelpGen) then
      begin
        if LHelpGen.TryGetValue<string>('outputDir', LPath) then
          FProject.HelpGen.OutputDir := LPath;
        if LHelpGen.TryGetValue<string>('title', LPath) then
          FProject.HelpGen.Title := LPath;
        if LHelpGen.TryGetValue<string>('htmlTheme', LPath) then
          FProject.HelpGen.HTMLTheme := LPath;
        if LHelpGen.TryGetValue<Boolean>('includePrivate', FProject.HelpGen.IncludePrivate) then;
        if LHelpGen.TryGetValue<Boolean>('interfaceOnly', FProject.HelpGen.InterfaceOnly) then;
        if LHelpGen.TryGetValue<Integer>('readyMinPercent', FProject.HelpGen.ReadyMinPercent) then;
        if LHelpGen.TryGetValue<Integer>('coverageMinPercent', FProject.HelpGen.CoverageMinPercent) then;

        LArr := LHelpGen.GetValue<TJSONArray>('defaultFormats');
        if Assigned(LArr) then
        begin
          SetLength(FProject.HelpGen.DefaultFormats, LArr.Count);
          for I := 0 to LArr.Count - 1 do
            FProject.HelpGen.DefaultFormats[I] := LArr.Items[I].Value;
        end;

        LArr := LHelpGen.GetValue<TJSONArray>('excludePatterns');
        if Assigned(LArr) then
        begin
          SetLength(FProject.HelpGen.ExcludePatterns, LArr.Count);
          for I := 0 to LArr.Count - 1 do
            FProject.HelpGen.ExcludePatterns[I] := LArr.Items[I].Value;
        end;
      end;
    finally
      LObj.Free;
    end;
  except
    on E: Exception do
      TLogger.Instance.Warn('Failed to load project settings: ' + E.Message,
        'TPluginSettings.LoadProjectSettings');
  end;
end;

procedure TPluginSettings.SaveProject;
var
  LObj: TJSONObject;
  LHelpGen: TJSONObject;
  LArr: TJSONArray;
  LPath: string;
  I: Integer;
begin
  if FProjectDir = '' then
    Exit;

  LPath := TPath.Combine(FProjectDir, CProjectFileName);
  LObj:=nil;if TFile.Exists(LPath) then LObj:=TJSONObject.ParseJSONValue(TFile.ReadAllText(LPath,TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LObj) then LObj:=TJSONObject.Create;
  try
    LObj.RemovePair('$schema').Free;LObj.RemovePair('version').Free;LObj.RemovePair('helpGen').Free;
    LObj.AddPair('$schema', 'https://xmldocplugin.dev/schema/v1/project-settings.json');
    LObj.AddPair('version', TJSONNumber.Create(1));

    LHelpGen := TJSONObject.Create;
    LHelpGen.AddPair('outputDir', FProject.HelpGen.OutputDir);
    LHelpGen.AddPair('title', FProject.HelpGen.Title);
    LHelpGen.AddPair('htmlTheme', FProject.HelpGen.HTMLTheme);
    LHelpGen.AddPair('includePrivate', TJSONBool.Create(FProject.HelpGen.IncludePrivate));
    LHelpGen.AddPair('interfaceOnly', TJSONBool.Create(FProject.HelpGen.InterfaceOnly));
    LHelpGen.AddPair('readyMinPercent', TJSONNumber.Create(FProject.HelpGen.ReadyMinPercent));
    LHelpGen.AddPair('coverageMinPercent', TJSONNumber.Create(FProject.HelpGen.CoverageMinPercent));

    LArr := TJSONArray.Create;
    for I := 0 to Length(FProject.HelpGen.DefaultFormats) - 1 do
      LArr.Add(FProject.HelpGen.DefaultFormats[I]);
    LHelpGen.AddPair('defaultFormats', LArr);

    if Length(FProject.HelpGen.ExcludePatterns) > 0 then
    begin
      LArr := TJSONArray.Create;
      for I := 0 to Length(FProject.HelpGen.ExcludePatterns) - 1 do
        LArr.Add(FProject.HelpGen.ExcludePatterns[I]);
      LHelpGen.AddPair('excludePatterns', LArr);
    end;

    LObj.AddPair('helpGen', LHelpGen);

    LPath := TPath.Combine(FProjectDir, CProjectFileName);
    TFile.WriteAllText(LPath, LObj.Format(2), TEncoding.UTF8);
  finally
    LObj.Free;
  end;
end;

initialization

finalization
  TPluginSettings.ReleaseInstance;

end.
