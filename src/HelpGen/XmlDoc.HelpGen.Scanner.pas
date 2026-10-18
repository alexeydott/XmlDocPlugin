unit XmlDoc.HelpGen.Scanner;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.Masks;

type
  /// <summary>스캔 소스 유형</summary>
  TScanSource = (
    ssProjectFile,
    ssDirectory,
    ssFileList
  );

  /// <summary>프로젝트 스캔 옵션</summary>
  TScanOptions = record
    Source: TScanSource;
    ProjectPath: string;
    FileList: TArray<string>;
    ExcludePatterns: TArray<string>;
    SearchPaths: TArray<string>;
    Defines:TArray<string>;
    Configuration,Platform:string;
    IncludePrivate: Boolean;
    InterfaceOnly: Boolean;
  end;

  /// <summary>프로젝트 파일을 스캔하여 문서화 대상 .pas 파일 목록을 수집합니다.</summary>
  TProjectScanner = class
  private
    FSearchPaths,FDefines:TArray<string>;
    FPlatform,FMainSource:string;
    function IsExcluded(const AFilePath: string; const APatterns: TArray<string>): Boolean;
    function ParseProjectUses(const AProjectPath: string): TArray<string>;
    function ResolveUnitPath(const AUnitName, AProjectDir: string;
      const ASearchPaths: TArray<string>): string;
    function ScanDirectory(const ADirPath: string): TArray<string>;

  public
    /// <summary>옵션에 따라 .pas 파일 목록을 수집합니다.</summary>
    /// <param name="AOptions">스캔 옵션</param>
    /// <returns>절대 경로의 .pas 파일 배열</returns>
    function Scan(const AOptions: TScanOptions): TArray<string>;
    property Platform:string read FPlatform;
    property SearchPaths:TArray<string> read FSearchPaths;
    property Defines:TArray<string> read FDefines;
  end;

implementation

uses XmlDoc.ProjectContext,SimpleParser.Lexer,SimpleParser.Lexer.Types,XmlDoc.SourceText;

function IsLetterOrDigit(ACh: Char): Boolean;
begin
  Result := CharInSet(ACh, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

{ TProjectScanner }

function TProjectScanner.IsExcluded(const AFilePath: string;
  const APatterns: TArray<string>): Boolean;
var
  LFileName: string;
  I: Integer;
begin
  Result := False;
  LFileName := ExtractFileName(AFilePath);

  for I := 0 to Length(APatterns) - 1 do
  begin
    if MatchesMask(LFileName, APatterns[I]) then
    begin
      Result := True;
      Exit;
    end;

    // 경로 패턴도 체크
    if MatchesMask(AFilePath, APatterns[I]) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TProjectScanner.ParseProjectUses(const AProjectPath:string):TArray<string>;
var Lex:TmwPasLex;List:TList<string>;SourcePath,Dir,Name,Path,Define:string;
 procedure Next;
 begin repeat Lex.Next;until not Lex.IsJunk or (Lex.TokenID=ptNull);end;
begin
 SourcePath:=AProjectPath;if SameText(ExtractFileExt(SourcePath),'.dproj') then SourcePath:=FMainSource;
 if (SourcePath='') or not TFile.Exists(SourcePath) then Exit(nil);Dir:=ExtractFilePath(SourcePath);Lex:=TmwPasLex.Create;List:=TList<string>.Create;
 try
  Lex.InitDefinesDefinedByCompiler;
  if FPlatform<>'' then begin
   if not SameText(FPlatform,'Win32') and not SameText(FPlatform,'Win64') then raise Exception.Create('Unsupported documentation platform: '+FPlatform);
   for Define in ['WIN32','WIN64','CPU32BITS','CPU64BITS','CPU386','CPUX86','CPUX64'] do Lex.RemoveDefine(Define);
   if SameText(FPlatform,'Win64') then begin Lex.AddDefine('WIN64');Lex.AddDefine('CPUX64');Lex.AddDefine('CPU64BITS');end
   else begin Lex.AddDefine('WIN32');Lex.AddDefine('CPU386');Lex.AddDefine('CPUX86');Lex.AddDefine('CPU32BITS');end;
  end;
  for Define in FDefines do Lex.AddDefine(Define);
  Lex.Origin:=ReadSourceFile(SourcePath);
  while Lex.TokenID<>ptNull do begin
   if (Lex.TokenID=ptUses) or (Lex.ExID=ptContains) then begin
    Next;
    while not (Lex.TokenID in [ptSemiColon,ptNull]) do begin
     Name:='';
     while (Lex.TokenID in [ptIdentifier,ptPoint]) do begin Name:=Name+Lex.Token;Next;end;
     if Name='' then raise Exception.Create('Invalid project unit reference in '+SourcePath);
     if Lex.TokenID=ptIn then begin
      Next;if Lex.TokenID<>ptStringConst then raise Exception.Create('Expected project unit source path');
      Path:=Copy(Lex.Token,2,Length(Lex.Token)-2);
      if not TPath.IsPathRooted(Path) then Path:=TPath.Combine(Dir,Path);Path:=TPath.GetFullPath(Path);
      if not TFile.Exists(Path) then raise Exception.Create('Missing project source: '+Path);Next;
     end else Path:=ResolveUnitPath(Name,Dir,FSearchPaths);
     if (Path<>'') and not List.Contains(Path) then List.Add(Path);
     if Lex.TokenID=ptComma then Next else if Lex.TokenID<>ptSemiColon then raise Exception.Create('Invalid project uses list');
    end;
   end;
   Next;
  end;
  Result:=List.ToArray;
 finally List.Free;Lex.Free;end;
end;

function TProjectScanner.ResolveUnitPath(const AUnitName, AProjectDir: string;
  const ASearchPaths: TArray<string>): string;
var
  LPasFile: string;
  I: Integer;
  LPath: string;
begin
  Result := '';
  LPasFile := AUnitName + '.pas';

  // 1. 프로젝트 디렉토리에서 검색
  LPath := TPath.Combine(AProjectDir, LPasFile);
  if TFile.Exists(LPath) then
  begin
    Result := TPath.GetFullPath(LPath);
    Exit;
  end;

  // 2. 검색 경로에서 검색
  for I := 0 to Length(ASearchPaths) - 1 do
  begin
    LPath := TPath.Combine(ASearchPaths[I], LPasFile);
    if TFile.Exists(LPath) then
    begin
      Result := TPath.GetFullPath(LPath);
      Exit;
    end;
  end;
end;

function TProjectScanner.ScanDirectory(const ADirPath: string): TArray<string>;
var
  LFiles: TArray<string>;
begin
  if not TDirectory.Exists(ADirPath) then
  begin
    Result := nil;
    Exit;
  end;

  LFiles := TDirectory.GetFiles(ADirPath, '*.pas', TSearchOption.soAllDirectories);
  Result := LFiles;
end;

function TProjectScanner.Scan(const AOptions: TScanOptions): TArray<string>;
var
  LRawFiles: TArray<string>;
  LFiltered: TList<string>;
  I: Integer;
  LFilePath: string;
  Context:TProjectContext;
  Manifest:TArray<string>;
begin
  FMainSource:=AOptions.ProjectPath;
  FPlatform:=AOptions.Platform;
  FSearchPaths:=Copy(AOptions.SearchPaths);FDefines:=Copy(AOptions.Defines);
  if (AOptions.Source=ssProjectFile) and SameText(ExtractFileExt(AOptions.ProjectPath),'.dproj') then begin
    Context:=TProjectContext.Create(AOptions.ProjectPath,AOptions.Configuration,AOptions.Platform);
    try FMainSource:=Context.MainSource;FPlatform:=Context.Platform;FSearchPaths:=Context.SearchPaths+Context.IncludePaths+FSearchPaths;FDefines:=Context.Defines+FDefines;Manifest:=Context.SourceFiles;
    finally Context.Free;end;
  end;
  case AOptions.Source of
  ssProjectFile:
    begin
      LRawFiles := ParseProjectUses(AOptions.ProjectPath);

      // 추가 검색 경로로 미해결 유닛 재시도
      if Length(AOptions.SearchPaths) > 0 then
      begin
        LFiltered := TList<string>.Create;
        try
          for I := 0 to Length(LRawFiles) - 1 do
            LFiltered.Add(LRawFiles[I]);

          // 프로젝트 디렉토리에서 사용자 지정 검색 경로 추가 탐색
          LRawFiles := LFiltered.ToArray;
        finally
          LFiltered.Free;
        end;
      end;
    end;
  ssDirectory:
    LRawFiles := ScanDirectory(AOptions.ProjectPath);
  ssFileList:
    LRawFiles := AOptions.FileList;
  else
    LRawFiles := nil;
  end;

  LRawFiles:=LRawFiles+Manifest;
  // 제외 패턴 필터링
  LFiltered := TList<string>.Create;
    try
      for I := 0 to Length(LRawFiles) - 1 do
      begin
        LFilePath := LRawFiles[I];
        if not LFiltered.Contains(LFilePath) and not IsExcluded(LFilePath, AOptions.ExcludePatterns) then
          LFiltered.Add(LFilePath);
      end;
      Result := LFiltered.ToArray;
    finally
      LFiltered.Free;
    end;
end;

end.
