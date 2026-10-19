/// <summary>CHM project generation, short-path staging and HTML Help compiler validation.</summary>
unit XmlDoc.HelpGen.Renderer.CHM;

interface
uses System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  XmlDoc.HelpGen.Types, XmlDoc.HelpGen.CrossRef, XmlDoc.HelpGen.Renderer;
type
  ECHMBuildError = class(Exception);
  TCHMDocRenderer = class(TInterfacedObject, IDocRenderer)
  private
    FCompilerPath: string;
    FOptions: TRenderOptions;
    FUnits: TObjectList<TUnitDocInfo>;
    procedure CompileCHM(const ProjectPath: string);
    procedure GenerateProject;
    procedure ExportProject(const Destination: string);
  public
    constructor Create(const ACompilerPath: string = '');
    procedure Render(const AUnits: TObjectList<TUnitDocInfo>;
      const AResolver: TCrossRefResolver; const AOptions: TRenderOptions);
  end;
implementation
uses Winapi.Windows, System.Win.Registry, System.RegularExpressions,
  XmlDoc.HelpGen.Renderer.HTML, XmlDoc.HelpGen.Navigation;

constructor TCHMDocRenderer.Create(const ACompilerPath: string);
begin inherited Create; FCompilerPath := ACompilerPath; end;

function Esc(const S: string): string;
var C: Char;
begin
  Result := '';
  for C in S do
    case C of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
    else
      if Ord(C) > 127 then Result := Result + '&#' + IntToStr(Ord(C)) + ';'
      else Result := Result + C;
    end;
end;

procedure CheckPath(const Path: string);
begin
  // HHC 4.74 still uses MAX_PATH, regardless of Windows long-path settings.
  if Length(TPath.GetFullPath(Path)) >= MAX_PATH then
    raise ECHMBuildError.CreateFmt('HTML Help requires paths shorter than %d characters: %s', [MAX_PATH, Path]);
end;

procedure TCHMDocRenderer.GenerateProject;
var Root: TDocNavNode; Files: TArray<string>; FileName, Rel, Base: string;
    HHP, HHC, HHK: TStringBuilder;
  procedure Toc(Node: TDocNavNode);
  var Child: TDocNavNode; Target: string;
  begin
    HHC.AppendLine('<li><object type="text/sitemap">');
    HHC.AppendLine('<param name="Name" value="' + Esc(Copy(Node.Caption, 1, 240)) + '">');
    if Node.Target <> '' then begin
      Target := '_chm_html/' + Node.Target;
      HHC.AppendLine('<param name="Local" value="' + Esc(Target) + '">');
      HHK.AppendLine('<li><object type="text/sitemap"><param name="Name" value="' + Esc(Copy(Node.Caption, 1, 240)) + '"><param name="Local" value="' + Esc(Target) + '"></object></li>');
    end;
    HHC.AppendLine('</object>');
    if Node.Children.Count > 0 then begin
      HHC.AppendLine('<ul>');
      for Child in Node.Children do Toc(Child);
      HHC.AppendLine('</ul>');
    end;
    HHC.AppendLine('</li>');
  end;
begin
  Base := FOptions.ProjectName;
  Root := BuildNavigation(FUnits, FOptions.Title, '.html', True, FOptions.NumericFileNames);
  HHP := TStringBuilder.Create; HHC := TStringBuilder.Create; HHK := TStringBuilder.Create;
  try
    HHP.AppendLine('[OPTIONS]');
    HHP.AppendLine('Compatibility=1.1 or later');
    HHP.AppendLine('Compiled file=' + Base + '.chm');
    HHP.AppendLine('Contents file=' + Base + '.hhc');
    HHP.AppendLine('Index file=' + Base + '.hhk');
    HHP.AppendLine('Default topic=_chm_html\index.html');
    HHP.AppendLine('Display compile progress=No');
    HHP.AppendLine('Full-text search=Yes');
    HHP.AppendLine('Language=0x0409 English (United States)');
    HHP.AppendLine('Title=' + StringReplace(StringReplace(FOptions.Title, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]));
    HHP.AppendLine;
    HHP.AppendLine('[FILES]');
    Files := TDirectory.GetFiles(TPath.Combine(FOptions.OutputDir, '_chm_html'), '*', TSearchOption.soAllDirectories);
    TArray.Sort<string>(Files);
    for FileName in Files do begin
      CheckPath(FileName);
      Rel := ExtractRelativePath(IncludeTrailingPathDelimiter(FOptions.OutputDir), FileName);
      HHP.AppendLine(Rel);
    end;
    HHC.AppendLine('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN"><html><body><ul>');
    HHK.AppendLine('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN"><html><body><ul>');
    Toc(Root);
    HHC.AppendLine('</ul></body></html>'); HHK.AppendLine('</ul></body></html>');
    TFile.WriteAllText(TPath.Combine(FOptions.OutputDir, Base + '.hhp'), HHP.ToString, TEncoding.ANSI);
    TFile.WriteAllText(TPath.Combine(FOptions.OutputDir, Base + '.hhc'), HHC.ToString, TEncoding.ANSI);
    TFile.WriteAllText(TPath.Combine(FOptions.OutputDir, Base + '.hhk'), HHK.ToString, TEncoding.ANSI);
  finally Root.Free; HHP.Free; HHC.Free; HHK.Free; end;
end;

procedure TCHMDocRenderer.CompileCHM(const ProjectPath: string);
var Reg: TRegistry; Compiler, Command, LogPath, LogText, Output: string;
    SI: TStartupInfo; PI: TProcessInformation; SA: TSecurityAttributes;
    LogHandle, InputHandle: THandle; ExitCode, WaitResult: Cardinal;
begin
  Compiler := FCompilerPath;
  if Compiler = '' then begin
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly('Software\Microsoft\HTML Help Workshop') and Reg.ValueExists('InstallDir') then
      Compiler := TPath.Combine(Reg.ReadString('InstallDir'), 'hhc.exe');
  finally Reg.Free; end;
  if not TFile.Exists(Compiler) then Compiler := 'C:\Program Files (x86)\HTML Help Workshop\hhc.exe';
  end;
  if not TFile.Exists(Compiler) then
    raise ECHMBuildError.Create('HTML Help compiler hhc.exe was not found. Install Microsoft HTML Help Workshop.');
  CheckPath(ProjectPath);
  LogPath := TPath.Combine(FOptions.OutputDir, 'chm-compiler.log');
  SA := Default(TSecurityAttributes); SA.nLength := SizeOf(SA); SA.bInheritHandle := True;
  LogHandle := CreateFile(PChar(LogPath), GENERIC_WRITE, FILE_SHARE_READ, @SA, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if LogHandle = INVALID_HANDLE_VALUE then RaiseLastOSError;
  InputHandle := INVALID_HANDLE_VALUE;
  try
    InputHandle := CreateFile('NUL', GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, @SA, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if InputHandle = INVALID_HANDLE_VALUE then RaiseLastOSError;
    SI := Default(TStartupInfo); SI.cb := SizeOf(SI);
    SI.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES; SI.wShowWindow := SW_HIDE;
    SI.hStdOutput := LogHandle; SI.hStdError := LogHandle; SI.hStdInput := InputHandle;
    Command := '"' + Compiler + '" "' + ProjectPath + '"'; UniqueString(Command);
    if not CreateProcess(PChar(Compiler), PChar(Command), nil, nil, True, CREATE_NO_WINDOW,
      nil, PChar(FOptions.OutputDir), SI, PI) then RaiseLastOSError;
    try
      WaitResult := WaitForSingleObject(PI.hProcess, 60000);
      if WaitResult = WAIT_TIMEOUT then begin
        TerminateProcess(PI.hProcess, ERROR_TIMEOUT); WaitForSingleObject(PI.hProcess, 5000);
        raise ECHMBuildError.Create('HTML Help compiler timed out after 60 seconds.');
      end;
      if WaitResult <> WAIT_OBJECT_0 then RaiseLastOSError;
      if not GetExitCodeProcess(PI.hProcess, ExitCode) then RaiseLastOSError;
    finally CloseHandle(PI.hProcess); CloseHandle(PI.hThread); end;
  finally if InputHandle <> INVALID_HANDLE_VALUE then CloseHandle(InputHandle); CloseHandle(LogHandle); end;
  LogText := TFile.ReadAllText(LogPath);
  Output := TPath.Combine(FOptions.OutputDir, FOptions.ProjectName + '.chm');
  // HHC's unusual success code is 1. A partial CHM can exist even after failure.
  if (ExitCode <> 1) or not TFile.Exists(Output) or
     TRegEx.IsMatch(LogText, 'HHC\d+:\s*Error', [roIgnoreCase]) then
    raise ECHMBuildError.CreateFmt('HTML Help compilation failed (exit %d). See chm-compiler.log.', [ExitCode]);
end;

procedure TCHMDocRenderer.ExportProject(const Destination: string);
var FileName, Rel, Target: string; Files: TArray<string>;
begin
  Files := TDirectory.GetFiles(FOptions.OutputDir, '*', TSearchOption.soAllDirectories);
  for FileName in Files do
    CheckPath(TPath.Combine(Destination, ExtractRelativePath(IncludeTrailingPathDelimiter(FOptions.OutputDir), FileName)));
  for FileName in Files do begin
    Rel := ExtractRelativePath(IncludeTrailingPathDelimiter(FOptions.OutputDir), FileName);
    Target := TPath.Combine(Destination, Rel); CheckPath(Target);
    TDirectory.CreateDirectory(ExtractFilePath(Target)); TFile.Copy(FileName, Target, True);
  end;
end;

procedure TCHMDocRenderer.Render(const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver; const AOptions: TRenderOptions);
var Destination, Work, Base, Failure: string; Renderer: IDocRenderer;
    Options: TRenderOptions; B: TBytes;
begin
  FUnits := AUnits; FOptions := AOptions;
  Base := TPath.GetFileName(AOptions.ProjectName);
  if Base = '' then Base := 'Documentation';
  Destination := TPath.GetFullPath(AOptions.OutputDir);
  CheckPath(TPath.Combine(Destination, Base + '.chm'));
  Work := TPath.Combine(TPath.GetTempPath, 'xdc-' + StringReplace(TPath.GetRandomFileName, '.', '', [rfReplaceAll]));
  CheckPath(TPath.Combine(Work, StringOfChar('t', 80)));
  TDirectory.CreateDirectory(Work);
  try
    FOptions.ProjectName := Base; FOptions.OutputDir := Work;
    CheckPath(TPath.Combine(Work, Base + '.hhp'));
    Options := FOptions; Options.OutputDir := TPath.Combine(Work, '_chm_html');
    Options.IncludeSearchIndex := False;
    Renderer := THTMLDocRenderer.Create(True); Renderer.Render(AUnits, AResolver, Options); Renderer := nil;
    GenerateProject;
    Failure := '';
    try
      CompileCHM(TPath.Combine(Work, Base + '.hhp'));
      B := TFile.ReadAllBytes(TPath.Combine(Work, Base + '.chm'));
      if (Length(B) < 4) or (B[0] <> Ord('I')) or (B[1] <> Ord('T')) or
        (B[2] <> Ord('S')) or (B[3] <> Ord('F')) then raise ECHMBuildError.Create('Invalid compiled CHM header.');
    except on E: Exception do begin
      Failure := E.Message;
      if TFile.Exists(TPath.Combine(Work, Base + '.chm')) then TFile.Delete(TPath.Combine(Work, Base + '.chm'));
    end; end;
    ExportProject(Destination);
    if Failure <> '' then raise ECHMBuildError.Create(Failure + ' Project and diagnostics: ' + Destination);
  finally
    Renderer := nil;
    TDirectory.Delete(Work, True);
  end;
end;
end.
