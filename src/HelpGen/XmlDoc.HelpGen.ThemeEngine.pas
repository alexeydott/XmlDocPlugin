/// <summary>Built-in and custom CSS themes for generated HTML documentation.</summary>
unit XmlDoc.HelpGen.ThemeEngine;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.Generics.Defaults;

type
  /// <summary>Built-in documentation theme names.</summary>
  TBuiltInTheme = (btDefault, btDark, btHighContrast, btMinimal);

  /// <summary>Theme CSS and metadata.</summary>
  TThemeInfo = record
    CSS: string;
    Description: string;
    Name: string;
  end;

  /// <summary>Provides built-in and custom CSS themes for generated HTML documentation.</summary>
  TThemeEngine = class
  strict private
    class var FInstance: TThemeEngine;
  private
    FCustomThemesDir: string;
    FThemes: TDictionary<string, TThemeInfo>;

    procedure LoadBuiltInThemes;
    procedure LoadCustomThemes;

  public
    constructor Create;
    destructor Destroy; override;

    class function Instance: TThemeEngine;
    class procedure ReleaseInstance;

    /// <summary>Returns theme CSS; empty or unknown names fall back to default. Names ignore case and surrounding whitespace.</summary>
    /// <param name="AThemeName">Theme name.</param>
    /// <returns>CSS text.</returns>
    function GetCSS(const AThemeName: string): string; overload;
    /// <summary>Returns CSS for a built-in theme without string-name conversion by the caller.</summary>
    function GetCSS(ATheme: TBuiltInTheme): string; overload;
    /// <summary>Returns the stable configuration name of a built-in theme.</summary>
    class function ThemeName(ATheme: TBuiltInTheme): string; static;

    /// <summary>Lists available themes.</summary>
    /// <returns>Available theme names.</returns>
    function GetAvailableThemes: TArray<string>;

    /// <summary>Reloads custom CSS from a directory, discarding the previous custom catalog and restoring built-ins first.</summary>
    /// <param name="ADir">Directory path.</param>
    procedure SetCustomThemesDir(const ADir: string);
    /// <summary>Creates a new UTF-8 CSS theme from an existing palette, rejects invalid or duplicate names, and reloads the catalog.</summary>
    function CreateCustomTheme(const AName, ABaseTheme: string): string;
    /// <summary>Reloads built-in and custom themes from disk.</summary>
    procedure Reload;
    property CustomThemesDir: string read FCustomThemesDir;
  end;

implementation

{ TThemeEngine }

constructor TThemeEngine.Create;
begin
  inherited Create;
  FThemes := TDictionary<string, TThemeInfo>.Create;
  FCustomThemesDir := TPath.Combine(
    TPath.Combine(GetEnvironmentVariable('APPDATA'), 'XmlDocPlugin'), 'themes');
  Reload;
end;

destructor TThemeEngine.Destroy;
begin
  FThemes.Free;
  inherited;
end;

class function TThemeEngine.Instance: TThemeEngine;
begin
  if not Assigned(FInstance) then
    FInstance := TThemeEngine.Create;
  Result := FInstance;
end;

class procedure TThemeEngine.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

function TThemeEngine.GetCSS(const AThemeName: string): string;
var
  LInfo: TThemeInfo;
begin
  if FThemes.TryGetValue(LowerCase(Trim(AThemeName)), LInfo) then
    Result := LInfo.CSS
  else if FThemes.TryGetValue('default', LInfo) then
    Result := LInfo.CSS
  else
    Result := '';
end;

class function TThemeEngine.ThemeName(ATheme: TBuiltInTheme): string;
const
  Names: array[TBuiltInTheme] of string = ('default', 'dark', 'high-contrast', 'minimal');
begin
  Result := Names[ATheme];
end;

function TThemeEngine.GetCSS(ATheme: TBuiltInTheme): string;
begin
  Result := GetCSS(ThemeName(ATheme));
end;

function TThemeEngine.GetAvailableThemes: TArray<string>;
var
  LKey: string;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    for LKey in FThemes.Keys do
      LList.Add(LKey);
    LList.Sort;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TThemeEngine.SetCustomThemesDir(const ADir: string);
begin
  FCustomThemesDir := ADir;
  Reload;
end;

procedure TThemeEngine.Reload;
begin
  FThemes.Clear;
  LoadBuiltInThemes;
  LoadCustomThemes;
end;

function TThemeEngine.CreateCustomTheme(const AName, ABaseTheme: string): string;
var
  Name, FileName, CSS: string;
begin
  Name := LowerCase(Trim(AName));
  if (Name = '') or (Name = '.') or (Name = '..') or Name.EndsWith('.') then
    raise EArgumentException.Create('Enter a valid theme name without a file extension.');
  for var C in TPath.GetInvalidFileNameChars do
    if Pos(C, Name) > 0 then
      raise EArgumentException.Create('Theme names cannot contain path separators or invalid filename characters.');
  for var Theme := Low(TBuiltInTheme) to High(TBuiltInTheme) do
    if Name = ThemeName(Theme) then
      raise EArgumentException.Create('Choose a new name; built-in themes cannot be replaced by this command.');
  FileName := TPath.Combine(FCustomThemesDir, Name + '.css');
  if TFile.Exists(FileName) then
    raise EArgumentException.Create('A theme with this name already exists.');
  CSS := GetCSS(btDefault) + sLineBreak + GetCSS(ABaseTheme);
  ForceDirectories(FCustomThemesDir);
  TFile.WriteAllText(FileName, CSS, TEncoding.UTF8);
  Reload;
  Result := FileName;
end;

procedure TThemeEngine.LoadBuiltInThemes;
var
  LInfo: TThemeInfo;
begin
  // Default (밝은 테마)
  LInfo.Name := 'default';
  LInfo.Description := 'Default light theme';
  LInfo.CSS :=
    ':root {' + sLineBreak +
    '  --bg-primary: #ffffff;' + sLineBreak +
    '  --bg-secondary: #f8f9fa;' + sLineBreak +
    '  --bg-nav: #f5f5f5;' + sLineBreak +
    '  --text-primary: #212529;' + sLineBreak +
    '  --text-secondary: #6c757d;' + sLineBreak +
    '  --text-link: #0d6efd;' + sLineBreak +
    '  --border-color: #dee2e6;' + sLineBreak +
    '  --code-bg: #f4f4f4;' + sLineBreak +
    '  --code-text: #d63384;' + sLineBreak +
    '  --heading-color: #1a1a2e;' + sLineBreak +
    '  --table-stripe: #f8f9fa;' + sLineBreak +
    '  --nav-hover: #e9ecef;' + sLineBreak +
    '  --nav-active: #0d6efd;' + sLineBreak +
    '  --nav-active-bg: #e7f1ff;' + sLineBreak +
    '}' + sLineBreak +
    'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }';
  FThemes.AddOrSetValue('default', LInfo);

  // Dark (어두운 테마)
  LInfo.Name := 'dark';
  LInfo.Description := 'Dark theme for comfortable reading';
  LInfo.CSS :=
    ':root {' + sLineBreak +
    '  --bg-primary: #1e1e2e;' + sLineBreak +
    '  --bg-secondary: #2a2a3e;' + sLineBreak +
    '  --bg-nav: #181825;' + sLineBreak +
    '  --text-primary: #cdd6f4;' + sLineBreak +
    '  --text-secondary: #a6adc8;' + sLineBreak +
    '  --text-link: #89b4fa;' + sLineBreak +
    '  --border-color: #45475a;' + sLineBreak +
    '  --code-bg: #313244;' + sLineBreak +
    '  --code-text: #f38ba8;' + sLineBreak +
    '  --heading-color: #cba6f7;' + sLineBreak +
    '  --table-stripe: #2a2a3e;' + sLineBreak +
    '  --nav-hover: #313244;' + sLineBreak +
    '  --nav-active: #89b4fa;' + sLineBreak +
    '  --nav-active-bg: #1e1e2e;' + sLineBreak +
    '}' + sLineBreak +
    'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; ' +
    'background-color: var(--bg-primary); color: var(--text-primary); }';
  FThemes.AddOrSetValue('dark', LInfo);

  // High Contrast (고대비)
  LInfo.Name := 'high-contrast';
  LInfo.Description := 'High contrast for accessibility';
  LInfo.CSS :=
    ':root {' + sLineBreak +
    '  --bg-primary: #000000;' + sLineBreak +
    '  --bg-secondary: #1a1a1a;' + sLineBreak +
    '  --bg-nav: #0a0a0a;' + sLineBreak +
    '  --text-primary: #ffffff;' + sLineBreak +
    '  --text-secondary: #e0e0e0;' + sLineBreak +
    '  --text-link: #ffff00;' + sLineBreak +
    '  --border-color: #ffffff;' + sLineBreak +
    '  --code-bg: #1a1a1a;' + sLineBreak +
    '  --code-text: #00ff00;' + sLineBreak +
    '  --heading-color: #ffffff;' + sLineBreak +
    '  --table-stripe: #1a1a1a;' + sLineBreak +
    '  --nav-hover: #333333;' + sLineBreak +
    '  --nav-active: #ffff00;' + sLineBreak +
    '  --nav-active-bg: #333333;' + sLineBreak +
    '}' + sLineBreak +
    'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; ' +
    'background-color: #000; color: #fff; }' + sLineBreak +
    'a { text-decoration: underline; }';
  FThemes.AddOrSetValue('high-contrast', LInfo);

  // Minimal (미니멀)
  LInfo.Name := 'minimal';
  LInfo.Description := 'Clean minimal theme';
  LInfo.CSS :=
    ':root {' + sLineBreak +
    '  --bg-primary: #fafafa;' + sLineBreak +
    '  --bg-secondary: #f0f0f0;' + sLineBreak +
    '  --bg-nav: #fafafa;' + sLineBreak +
    '  --text-primary: #333333;' + sLineBreak +
    '  --text-secondary: #888888;' + sLineBreak +
    '  --text-link: #555555;' + sLineBreak +
    '  --border-color: #e0e0e0;' + sLineBreak +
    '  --code-bg: #f0f0f0;' + sLineBreak +
    '  --code-text: #333333;' + sLineBreak +
    '  --heading-color: #111111;' + sLineBreak +
    '  --table-stripe: #f5f5f5;' + sLineBreak +
    '  --nav-hover: #eeeeee;' + sLineBreak +
    '  --nav-active: #333333;' + sLineBreak +
    '  --nav-active-bg: #f0f0f0;' + sLineBreak +
    '}' + sLineBreak +
    'body { font-family: "Georgia", "Times New Roman", serif; ' +
    'max-width: 1200px; margin: 0 auto; }';
  FThemes.AddOrSetValue('minimal', LInfo);
end;

procedure TThemeEngine.LoadCustomThemes;
var
  LFiles: TArray<string>;
  LFile: string;
  LInfo: TThemeInfo;
  LName: string;
begin
  if not TDirectory.Exists(FCustomThemesDir) then
    Exit;

  LFiles := TDirectory.GetFiles(FCustomThemesDir, '*.css');
  TArray.Sort<string>(LFiles);
  for LFile in LFiles do
  begin
    try
      LName := LowerCase(TPath.GetFileNameWithoutExtension(LFile));
      LInfo.Name := LName;
      LInfo.Description := 'Custom theme: ' + LName;
      LInfo.CSS := TFile.ReadAllText(LFile, TEncoding.UTF8);
      FThemes.AddOrSetValue(LName, LInfo);
    except
      // 커스텀 테마 로드 실패 시 무시
    end;
  end;
end;

initialization

finalization
  TThemeEngine.ReleaseInstance;

end.
