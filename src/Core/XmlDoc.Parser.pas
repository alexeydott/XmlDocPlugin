/// <summary>DelphiAST integration, project-aware conditional parsing and declaration lookup.</summary>
unit XmlDoc.Parser;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Hash,
  SimpleParser.Lexer,
  DelphiAST,
  DelphiAST.Classes,
  DelphiAST.Consts,
  XmlDoc.Consts;

type
  TDocParseDiagnostic = record
    FileName,RequestedFile,Stage,ExceptionClass,Message,Excerpt,Stack,Context:string;
    Line,Column:Integer;
    class function FromException(E:Exception;const FileName,Stage:string):TDocParseDiagnostic;static;
    function DetailText:string;
  end;
  /// <summary>Parses Delphi source and locates documentable declarations at a source line.</summary>
  TDocParser = class
  private
    FBuilder: TPasSyntaxTreeBuilder;
    FCachedHash: string;
    FCachedSource: string;
    FFlatIndex: TList<TSyntaxNode>;
    FLastCommentStart: Integer;
    FRootNode: TSyntaxNode;
    FSourceLines: TArray<string>;
    FOnResolveDeclaration: TResolveDeclarationEvent;
    FSourceFileName,FPlatform:string;
    FSearchPaths,FSourceFiles,FDefines,FDependencyFiles,FDependencyProbes:TArray<string>;
    FSnapshots,FDependencySnapshots:TArray<TSourceSnapshot>;
    FHasDeclared:Boolean;
    FOnCheck:TProc;
    FLastDiagnostic:TDocParseDiagnostic;
    FFailedSnapshot:Boolean;
    function DependenciesCurrent:Boolean;
    procedure ParseSourceInternal(const ASource,AFileName:string);
    procedure SetPlatform(const Value:string);
    procedure SetSnapshots(const Value:TArray<TSourceSnapshot>);
    procedure SetDefines(const Value:TArray<string>);
    procedure SetSearchPaths(const Value:TArray<string>);
    procedure SetSourceFiles(const Value:TArray<string>);
    procedure SetResolveDeclaration(const Value: TResolveDeclarationEvent);

    function BuildParentPath(ANode: TSyntaxNode): string;
    procedure BuildFlatIndex;
    procedure CollectDocTargets(ANode: TSyntaxNode);
    function ExtractDocComment(ANode: TSyntaxNode): string;
    function ExtractGenericParams(ANode: TSyntaxNode): TArray<string>;
    function ExtractParams(AMethodNode: TSyntaxNode): TArray<TParamInfo>;
    function ExtractReturnType(AMethodNode: TSyntaxNode): string;
    function FindNearestDocTarget(ALine: Integer): TSyntaxNode;
    function FindNextElementAtOrBelow(ALine: Integer): TSyntaxNode;
    function HashSource(const ASource: string): string;
    function IsDocTargetNode(ANode: TSyntaxNode): Boolean;
    function NodeToElementInfo(ANode: TSyntaxNode): TCodeElementInfo;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Builds the syntax tree for the supplied source and project context.</summary>
    /// <param name="ASource">Complete source text to parse.</param>
    procedure ParseSource(const ASource: string; const AFileName:string = '');
    function FailedSnapshotIsCurrent(const Source,FileName:string):Boolean;
    procedure RetryParsing;
    property LastDiagnostic:TDocParseDiagnostic read FLastDiagnostic;

    /// <summary>Finds the declaration at the supplied source line.</summary>
    /// <param name="ALine">One-based cursor line number.</param>
    /// <returns>Declaration metadata; Name is empty when no declaration is found.</returns>
    function GetElementAtLine(ALine: Integer): TCodeElementInfo;

    /// <summary>Returns all documentable declarations in the parsed source.</summary>
    /// <returns>Parsed declaration metadata.</returns>
    function GetAllElements: TArray<TCodeElementInfo>;
    /// <summary>Resolves an explicitly selected method to its exact implementation range.</summary>
    function MethodSource(const Target:TCodeElementInfo;out Code,Reason:string):Boolean;

    /// <summary>Checks whether the supplied source matches the parsed snapshot.</summary>
    /// <param name="ASource">Source text to compare.</param>
    /// <returns>True if the source has not changed.</returns>
    function IsUpToDate(const ASource: string): Boolean;

    /// <summary>Root of the parsed syntax tree.</summary>
    /// <summary>Returns known visibility, or False when external scope information is unavailable.</summary>
    property OnResolveDeclaration: TResolveDeclarationEvent read FOnResolveDeclaration write SetResolveDeclaration;
    property OnCheck:TProc read FOnCheck write FOnCheck;
    property SourceFileName:string read FSourceFileName;
    property Platform:string read FPlatform write SetPlatform;
    property SourceSnapshots:TArray<TSourceSnapshot> read FSnapshots write SetSnapshots;
    property Defines:TArray<string> read FDefines write SetDefines;
    property SearchPaths:TArray<string> read FSearchPaths write SetSearchPaths;
    property SourceFiles:TArray<string> read FSourceFiles write SetSourceFiles;
    function BindingType(const Name:string;Line:Integer):string;
    /// <summary>Finds the nearest lexical bindings before considering implicit Self.</summary>
    function LocalDeclarations(const Name:string;Line:Integer):TArray<TCodeElementInfo>;
    property DependencySnapshots:TArray<TSourceSnapshot> read FDependencySnapshots;
    property DependencyFiles:TArray<string> read FDependencyFiles;
    property DependencyProbes:TArray<string> read FDependencyProbes;
    property RootNode: TSyntaxNode read FRootNode;

    /// <summary>Most recently parsed source snapshot.</summary>
    property SourceText: string read FCachedSource;
  end;

implementation

uses XmlDoc.SourceAccess,System.IOUtils,System.Win.Registry,Winapi.Windows,SimpleParser.Lexer.Types,System.RegularExpressions,XmlDoc.SourceText;

{$I XmlDoc.SystemDeclarations.inc}

function Target64(const Platform:string):Boolean;
begin
 if SameText(Platform,'Win64') then Exit(True);if SameText(Platform,'Win32') then Exit(False);
{$IFDEF CPU64} Result:=True; {$ELSE} Result:=False; {$ENDIF}
end;
function SystemNames(const Platform:string):string;
begin
{$IF CompilerVersion >= 37}
 if Target64(Platform) then Result:=CRad13Win64Globals else Result:=CRad13Win32Globals;
{$ELSE}
 if Target64(Platform) then Result:=CRad12Win64Globals else Result:=CRad12Win32Globals;
{$IFEND}
end;
function SystemClasses(const Platform:string):string;
begin
{$IF CompilerVersion >= 37}
 if Target64(Platform) then Result:=CRad13Win64Classes else Result:=CRad13Win32Classes;
{$ELSE}
 if Target64(Platform) then Result:=CRad12Win64Classes else Result:=CRad12Win32Classes;
{$IFEND}
end;
function SystemMembers(const Platform:string):string;
begin
{$IF CompilerVersion >= 37}
 if Target64(Platform) then Result:=CRad13Win64Members else Result:=CRad13Win32Members;
{$ELSE}
 if Target64(Platform) then Result:=CRad12Win64Members else Result:=CRad12Win32Members;
{$IFEND}
end;

type
  TDeclarationSession = class;
  TScopeAwareBuilder = class(TPasSyntaxTreeBuilder)
  private
    FExternalResolver: TResolveDeclarationEvent;
    FDeclarationScope:TSyntaxNode;
    FSession:TDeclarationSession;
    FModuleRoot:TSyntaxNode;
    FSourceFile:string;
    FTokenCount:Integer;
    procedure UnitFile; override;
    function ResolveDeclaration(Sender:TmwBasePasLex; const Identifier:string;
      out Declared:Boolean):Boolean;
  protected
    procedure NextToken; override;
    procedure VarSection; override;
    procedure TypeArgs; override;
  public
    constructor Create; override;
  end;

  TDeclarationSession = class
  private
    FLoaded:TObjectDictionary<string,TSyntaxNode>;
    FLoading:TDictionary<string,Boolean>;
    FLocated:TDictionary<string,string>;
    FReadFiles:TDictionary<string,string>;
    FProbes:TList<string>;
    FPaths,FFiles,FDefines:TArray<string>;
    FSnapshots:TDictionary<string,string>;
    FRTLRoot,FPlatform:string;
    FRTLArrayLength:Integer;
    FOnCheck:TProc;
    procedure ConfigureTarget(Builder:TPasSyntaxTreeBuilder);
    function NativeRTLSize(const Match:TMatch):string;
    function RTLConditional(const Match:TMatch):string;
    function PrepareSource(const Source,FileName:string):string;
    function LocateUnit(const Name,ExplicitPath,FromFile:string):string;
    function LoadUnit(const Name,ExplicitPath,FromFile:string;out FileName:string):TSyntaxNode;
    function FindSymbol(Root:TSyntaxNode;const FileName,Name:string;
      out Symbol,SymbolRoot:TSyntaxNode;out SymbolFile:string):Boolean;
    function MemberExists(TypeNode,Root,AccessType:TSyntaxNode;
      const FileName,AccessFile,Name:string;Visited:TList<TSyntaxNode>):Boolean;
    function OwnerType(Builder:TScopeAwareBuilder):TSyntaxNode;
    function Resolve(Builder:TScopeAwareBuilder;const Name:string;out Declared:Boolean):Boolean;
  public
    constructor Create(const Paths,Files,Defines:TArray<string>;const Snapshots:TArray<TSourceSnapshot>;const Platform:string);
    destructor Destroy;override;
  end;
  TResolutionIncludes=class(TInterfacedObject,IIncludeHandler)
  private
    FSession:TDeclarationSession;
    FBaseFile:string;
    FParents:TDictionary<string,string>;
  public
    constructor Create(Session:TDeclarationSession;const FileName:string);
    destructor Destroy;override;
    function GetIncludeFileContent(const ParentFileName,IncludeName:string;
      out Content,FileName:string):Boolean;
  end;

procedure TScopeAwareBuilder.NextToken;
begin
 Inc(FTokenCount);
 if (FTokenCount and 255=0) and Assigned(FSession) and Assigned(FSession.FOnCheck) then FSession.FOnCheck();
 inherited;
end;
procedure TScopeAwareBuilder.TypeArgs;
var Parent,TypeNode,Args:TSyntaxNode;
begin
 inherited;
 // DelphiAST's parameter-list normalization clones only ntType. Keep the
 // generic arguments inside that node before the normalization discards siblings.
 Parent:=FStack.Peek;

 if (Parent.Typ=ntType) and Assigned(Parent.ParentNode) and (Parent.ParentNode.Typ=ntType) then begin
  Args:=Parent.FindNode(ntTypeArgs);
  if Assigned(Args) then Parent.ParentNode.AddChild(Parent.ExtractChild(Args));
 end else if Parent.Typ=ntParameters then begin
  TypeNode:=Parent.FindNode(ntType);Args:=Parent.FindNode(ntTypeArgs);
  if Assigned(TypeNode) and Assigned(Args) then TypeNode.AddChild(Parent.ExtractChild(Args));
 end;
end;
procedure TScopeAwareBuilder.UnitFile;
begin
  FModuleRoot:=FStack.Peek;
  inherited;
end;

constructor TScopeAwareBuilder.Create;
begin
  inherited;
  Lexer.Lexer.OnResolveDeclaration := ResolveDeclaration;
end;

procedure TScopeAwareBuilder.VarSection;
var Saved:TSyntaxNode;
begin
  Saved:=FDeclarationScope;
  FDeclarationScope:=FStack.Peek;
  try inherited;finally FDeclarationScope:=Saved;end;
end;

function DeclarationName(Node:TSyntaxNode):string;
var N:TSyntaxNode;
begin
  Result:=Node.GetAttribute(anName);
  if Result='' then begin
    N:=Node.FindNode(ntName);
    if Assigned(N) then Result:=N.GetAttribute(anName);
  end;
end;

function FindDeclaration(Scope:TSyntaxNode; const Name:string):TSyntaxNode;
var Child,EnumType,EnumValue:TSyntaxNode;
begin
  Result:=nil;
  if not Assigned(Scope) then Exit;
  for Child in Scope.ChildNodes do begin
    if Child.Typ in [ntTypeDecl,ntMethod,ntField,ntVariable,ntConstant,ntParameter,ntProperty,ntTypeParam] then begin
      if SameText(DeclarationName(Child),Name) then Exit(Child);
      if Child.Typ=ntTypeDecl then begin
        EnumType:=Child.FindNode(ntType);
        if Assigned(EnumType) and (EnumType.GetAttribute(anType)='enum') and
          (EnumType.GetAttribute(anVisibility)<>'scoped') then
          for EnumValue in EnumType.ChildNodes do
            if (EnumValue.Typ=ntIdentifier) and SameText(DeclarationName(EnumValue),Name) then Exit(EnumValue);
      end;
      Continue;
    end;
    if (Child.Typ=ntName) and (Scope.Typ in [ntVariables,ntFields,ntParameter]) and
      SameText(DeclarationName(Child),Name) then Exit(Child);
    if Child.Typ in [ntType,ntAnonymousMethod,ntAnonymousMethodType,ntStatements,
      ntFor,ntWhile,ntRepeat,ntTry,ntIf,ntCase,ntExceptionHandler,ntWith] then Continue;
    Result:=FindDeclaration(Child,Name);
    if Assigned(Result) then Exit;
  end;
end;

function TScopeAwareBuilder.ResolveDeclaration(Sender:TmwBasePasLex;
  const Identifier:string; out Declared:Boolean):Boolean;
var Scope,Root,Found,TypeNode:TSyntaxNode; Parts:TArray<string>;
  I:Integer; Name,Known:string; UsedDeclarationScope:Boolean;
begin
  Declared:=False; Result:=False;
  Parts:=Identifier.Split(['.']);
  if Length(Parts)=0 then Exit;
  Root:=nil;
  if FStack.Count>0 then begin
    Scope:=FStack.Peek; Root:=Scope;
    while Assigned(Root.ParentNode) do Root:=Root.ParentNode;
    I:=0;
    if (Length(Parts)>1) and SameText(Parts[0],Root.GetAttribute(anName)) then I:=1;
    UsedDeclarationScope:=False;
    while Assigned(Scope) do begin
      Found:=FindDeclaration(Scope,Parts[I]);
      if Assigned(Found) then begin
        Inc(I);
        while (I<Length(Parts)) and Assigned(Found) do begin
          TypeNode:=Found.FindNode(ntType);
          if Assigned(TypeNode) then Found:=FindDeclaration(TypeNode,Parts[I])
          else Found:=FindDeclaration(Found,Parts[I]);
          Inc(I);
        end;
        if Assigned(Found) then begin Declared:=True;Exit(True);end;
        Break;
      end;
      Scope:=Scope.ParentNode;
      if not Assigned(Scope) and not UsedDeclarationScope then begin
        Scope:=FDeclarationScope;UsedDeclarationScope:=True;
      end;
    end;
  end;
  Name:=UpperCase(Identifier);
  if Assigned(FSession) then Known:=SystemNames(FSession.FPlatform) else Known:=SystemNames('');
  if Pos('|'+Name+'|',Known)>0 then begin Declared:=True;Exit(True);end;
  if Assigned(FExternalResolver) and FExternalResolver(Sender,Identifier,Declared) then Exit(True);
  if Assigned(FSession) then Result:=FSession.Resolve(Self,Identifier,Declared);

end;

function PathKey(const FileName:string):string;
begin Result:=LowerCase(TPath.GetFullPath(FileName));end;

constructor TDeclarationSession.Create(const Paths,Files,Defines:TArray<string>;const Snapshots:TArray<TSourceSnapshot>;const Platform:string);
var Snapshot:TSourceSnapshot;
begin
  inherited Create;
  FPlatform:=Platform;
  FPaths:=Copy(Paths);FFiles:=Copy(Files);FDefines:=Copy(Defines);
  FLoaded:=TObjectDictionary<string,TSyntaxNode>.Create([doOwnsValues]);
  FLoading:=TDictionary<string,Boolean>.Create;
  FProbes:=TList<string>.Create;FLocated:=TDictionary<string,string>.Create;FReadFiles:=TDictionary<string,string>.Create;
  FSnapshots:=TDictionary<string,string>.Create;
  for Snapshot in Snapshots do FSnapshots.AddOrSetValue(PathKey(Snapshot.FileName),Snapshot.Source);
  var Root:=CurrentRADRoot;if Root<>'' then FRTLRoot:=TPath.Combine(Root,'source');
end;

procedure TDeclarationSession.ConfigureTarget(Builder:TPasSyntaxTreeBuilder);
var Define:string;
begin
 if FPlatform='' then Exit;
 if not SameText(FPlatform,'Win32') and not SameText(FPlatform,'Win64') then raise Exception.Create('Unsupported documentation platform: '+FPlatform);
 for Define in ['WIN32','WIN64','CPU32BITS','CPU64BITS','CPU386','CPUX86','CPUX64'] do Builder.Lexer.Lexer.RemoveDefine(Define);
 if Target64(FPlatform) then begin Builder.Lexer.Lexer.AddDefine('WIN64');Builder.Lexer.Lexer.AddDefine('CPUX64');Builder.Lexer.Lexer.AddDefine('CPU64BITS');end
 else begin Builder.Lexer.Lexer.AddDefine('WIN32');Builder.Lexer.Lexer.AddDefine('CPU386');Builder.Lexer.Lexer.AddDefine('CPUX86');Builder.Lexer.Lexer.AddDefine('CPU32BITS');end;
end;

destructor TDeclarationSession.Destroy;
begin FProbes.Free;FReadFiles.Free;FSnapshots.Free;FLocated.Free;FLoading.Free;FLoaded.Free;inherited;end;

function TDeclarationSession.LocateUnit(const Name,ExplicitPath,FromFile:string):string;
var Candidate,Dir,FileName,Scope:string;Matches:TArray<string>;
begin
  Result:='';
  Dir:=ExtractFilePath(FromFile);
  if ExplicitPath<>'' then begin
    Candidate:=ExplicitPath;
    if not TPath.IsPathRooted(Candidate) then Candidate:=TPath.Combine(Dir,Candidate);
    FProbes.Add(TPath.GetFullPath(Candidate));
    if TFile.Exists(Candidate) then Exit(TPath.GetFullPath(Candidate));
    raise Exception.CreateFmt('Cannot resolve DECLARED: unit %s specifies missing source %s',[Name,Candidate]);
  end;
  FileName:=Name+'.pas';
  if Dir<>'' then begin
    Candidate:=TPath.Combine(Dir,FileName);
    FProbes.Add(TPath.GetFullPath(Candidate));
    if TFile.Exists(Candidate) then Exit(TPath.GetFullPath(Candidate));
  end;
  for Candidate in FFiles do
    if SameText(TPath.GetFileName(Candidate),FileName) and TFile.Exists(Candidate) then begin
      if (Result<>'') and not SameText(Result,TPath.GetFullPath(Candidate)) then
        raise Exception.CreateFmt('Cannot resolve DECLARED: ambiguous project unit %s',[Name]);
      Result:=TPath.GetFullPath(Candidate);
    end;
  if Result<>'' then Exit;
  for Dir in FPaths do begin
    Candidate:=TPath.Combine(Dir,FileName);
    FProbes.Add(TPath.GetFullPath(Candidate));
    if TFile.Exists(Candidate) then Exit(TPath.GetFullPath(Candidate));
  end;
  if (FRTLRoot<>'') and TDirectory.Exists(FRTLRoot) then begin
    Matches:=TDirectory.GetFiles(FRTLRoot,FileName,TSearchOption.soAllDirectories);
    if Length(Matches)=1 then Exit(Matches[0]);
    if Length(Matches)>1 then raise Exception.CreateFmt('Cannot resolve DECLARED: ambiguous RTL unit %s',[Name]);
    if Pos('.',Name)=0 then
      for Scope in ['System','Winapi','Vcl','Data','Xml','FMX'] do begin
        Matches:=TDirectory.GetFiles(FRTLRoot,Scope+'.'+FileName,TSearchOption.soAllDirectories);
        if Length(Matches)=1 then Exit(Matches[0]);
      end;
  end;
  raise Exception.CreateFmt('Cannot resolve DECLARED: source for imported unit %s is unavailable (from %s)',[Name,FromFile]);
end;

constructor TResolutionIncludes.Create(Session:TDeclarationSession;const FileName:string);
begin inherited Create;FSession:=Session;FBaseFile:=FileName;FParents:=TDictionary<string,string>.Create;end;
destructor TResolutionIncludes.Destroy;
begin FParents.Free;inherited;end;
function TResolutionIncludes.GetIncludeFileContent(const ParentFileName,IncludeName:string;
  out Content,FileName:string):Boolean;
var Parent,Current,Dir:string;Count:Integer;
begin
  Parent:=ParentFileName;if Parent='' then Parent:=FBaseFile;
  if TPath.IsPathRooted(IncludeName) then FileName:=IncludeName
  else FileName:=TPath.Combine(ExtractFilePath(Parent),IncludeName);
  FSession.FProbes.Add(TPath.GetFullPath(FileName));
  if not TFile.Exists(FileName) then
    for Dir in FSession.FPaths do begin
      FileName:=TPath.Combine(Dir,IncludeName);FSession.FProbes.Add(TPath.GetFullPath(FileName));if TFile.Exists(FileName) then Break;
    end;
  if not TFile.Exists(FileName) then raise Exception.CreateFmt('Cannot load include %s from %s',[IncludeName,Parent]);
  FileName:=TPath.GetFullPath(FileName);Current:=Parent;Count:=0;
  while Current<>'' do begin
    if SameText(TPath.GetFullPath(Current),FileName) then raise Exception.CreateFmt('Cyclic include: %s',[FileName]);
    Inc(Count);if Count>64 then raise Exception.Create('Include nesting exceeds 64 files');
    if not FParents.TryGetValue(PathKey(Current),Current) then Break;
  end;
  if Parent<>'' then FParents.AddOrSetValue(PathKey(FileName),Parent);
  if not FSession.FSnapshots.TryGetValue(PathKey(FileName),Content) then Content:=ReadSourceFile(FileName);FSession.FReadFiles.AddOrSetValue(FileName,Content);Content:=FSession.PrepareSource(Content,FileName);Result:=True;
end;

function TDeclarationSession.NativeRTLSize(const Match:TMatch):string;
var Name:string;Value:Integer;
begin
 Name:=UpperCase(Match.Groups[1].Value);Value:=-1;
 if Name='EXTENDED' then begin if Target64(FPlatform) then Value:=8 else Value:=10;end
 else if Name='LONGWORD' then Value:=SizeOf(LongWord)
 else if Name='POINTER' then begin if Target64(FPlatform) then Value:=8 else Value:=4;end
 else if Name='INTEGER' then Value:=SizeOf(Integer)
 else if Name='NATIVEINT' then begin if Target64(FPlatform) then Value:=8 else Value:=4;end
 else if Name='LONGINT' then Value:=4
 else if Name='TEXTENDED80REC' then Value:=10
 else if Name='CHAR' then Value:=SizeOf(Char);
 if Value<0 then Result:=Match.Value else Result:=IntToStr(Value);
end;

function TDeclarationSession.RTLConditional(const Match:TMatch):string;
begin
 Result:=TRegEx.Replace(Match.Value,'(?i)\bSizeOf\s*\(\s*(Extended|LongWord|Pointer|Integer|NativeInt|LongInt|TExtended80Rec|Char)\s*\)',NativeRTLSize);
 if FRTLArrayLength>=0 then Result:=TRegEx.Replace(Result,'(?i)\bLength\s*\(\s*RegisteredTypeInfoTable\s*\)',IntToStr(FRTLArrayLength));
end;

function TDeclarationSession.PrepareSource(const Source,FileName:string):string;
var Bounds:TMatch;
begin
 Result:=Source;
 if IsCompilerSource(FileName) then begin
  FRTLArrayLength:=-1;Bounds:=TRegEx.Match(Source,'(?i)\bRegisteredTypeInfoTable\s*:\s*array\s*\[\s*(\d+)\s*\.\.\s*(\d+)\s*\]');
  if Bounds.Success then FRTLArrayLength:=StrToInt(Bounds.Groups[2].Value)-StrToInt(Bounds.Groups[1].Value)+1;
  Result:=TRegEx.Replace(Result,'(?is)\{\$\s*(?:IF|ELSEIF)\b[^}]*\}|\(\*\$\s*(?:IF|ELSEIF)\b.*?\*\)',RTLConditional);
 end;
end;
function TDeclarationSession.LoadUnit(const Name,ExplicitPath,FromFile:string;out FileName:string):TSyntaxNode;
var Key,LookupKey,Source,Define:string;Builder:TScopeAwareBuilder;Stream:TStringStream;
begin
  LookupKey:=LowerCase(FromFile+'|'+Name+'|'+ExplicitPath);
  if not FLocated.TryGetValue(LookupKey,FileName) then begin
    FileName:=LocateUnit(Name,ExplicitPath,FromFile);
    FLocated.Add(LookupKey,FileName);
  end;
  Key:=PathKey(FileName);
  if FLoaded.TryGetValue(Key,Result) then Exit;
  if FLoading.ContainsKey(Key) then raise Exception.CreateFmt('Circular interface dependency while resolving DECLARED: %s',[FileName]);
  if FLoading.Count>=64 then raise Exception.Create('Declaration dependency nesting exceeds 64 units');
  FLoading.Add(Key,True);
  Builder:=TScopeAwareBuilder.Create;Stream:=nil;
  try
    Builder.FSession:=Self;Builder.FSourceFile:=FileName;
    Builder.InterfaceOnly:=True;Builder.InitDefinesDefinedByCompiler;ConfigureTarget(Builder);
    for Define in FDefines do Builder.Lexer.Lexer.AddDefine(Define);
    Builder.Lexer.Lexer.IncludeHandler:=TResolutionIncludes.Create(Self,FileName);
    if not FSnapshots.TryGetValue(PathKey(FileName),Source) then Source:=ReadSourceFile(FileName);
    FReadFiles.AddOrSetValue(FileName,Source);
    // RTL uses target-native built-in sizes in conditionals. Keep unsupported
    // expressions intact so the lexer reports them instead of guessing a branch.
    Source:=PrepareSource(Source,FileName);
    Stream:=TStringStream.Create(Source,TEncoding.UTF8);
    try Result:=Builder.Run(Stream);
    except on E:Exception do raise Exception.CreateFmt('Cannot resolve DECLARED in %s: %s',[FileName,E.Message]);end;
    FLoaded.Add(Key,Result);
  finally Stream.Free;Builder.Free;FLoading.Remove(Key);end;
end;

procedure ImportedUnits(Root:TSyntaxNode;List:TList<TSyntaxNode>);
var Child,Item:TSyntaxNode;
begin
  if not Assigned(Root) then Exit;
  for Child in Root.ChildNodes do
    if Child.Typ=ntUses then begin
      for Item in Child.ChildNodes do if Item.Typ=ntUnit then List.Add(Item);
    end else if Child.Typ in [ntInterface,ntImplementation] then ImportedUnits(Child,List);
end;

function QualifiedDeclaration(Root:TSyntaxNode;const Name:string):TSyntaxNode;
var Parts:TArray<string>;I:Integer;Scope:TSyntaxNode;LocalName:string;
begin
  Result:=nil;if not Assigned(Root) then Exit;
  LocalName:=Name;
  if (Root.GetAttribute(anName)<>'') and LocalName.StartsWith(Root.GetAttribute(anName)+'.',True) then
    Delete(LocalName,1,Length(Root.GetAttribute(anName))+1);
  Parts:=LocalName.Split(['.']);Scope:=Root;
  for I:=0 to High(Parts) do begin
    Result:=FindDeclaration(Scope,Parts[I]);if not Assigned(Result) then Exit;
    if I<High(Parts) then begin Scope:=Result.FindNode(ntType);if not Assigned(Scope) then Exit(nil);end;
  end;
end;

function TDeclarationSession.FindSymbol(Root:TSyntaxNode;const FileName,Name:string;
  out Symbol,SymbolRoot:TSyntaxNode;out SymbolFile:string):Boolean;
var Units:TList<TSyntaxNode>;I:Integer;ImportRoot:TSyntaxNode;ImportFile,UnitName,LocalName:string;
begin
  Symbol:=nil;SymbolRoot:=Root;SymbolFile:=FileName;
  if Assigned(Root) then Symbol:=QualifiedDeclaration(Root,Name);
  if Assigned(Symbol) then Exit(True);
  Units:=TList<TSyntaxNode>.Create;
  try
    ImportedUnits(Root,Units);
    for I:=Units.Count-1 downto 0 do begin
      UnitName:=Units[I].GetAttribute(anName);
      if SameText(UnitName,'System') then Continue;
      LocalName:=Name;
      if Pos('.',Name)>0 then begin
        if not Name.StartsWith(UnitName+'.',True) then Continue;
        Delete(LocalName,1,Length(UnitName)+1);
      end;
      ImportRoot:=LoadUnit(UnitName,Units[I].GetAttribute(anPath),FileName,ImportFile);
      Symbol:=QualifiedDeclaration(ImportRoot.FindNode(ntInterface),LocalName);
      if Assigned(Symbol) then begin SymbolRoot:=ImportRoot;SymbolFile:=ImportFile;Exit(True);end;
    end;
  finally Units.Free;end;
  Result:=False;
end;

function TypeBody(Node:TSyntaxNode):TSyntaxNode;
begin
  Result:=Node;
  if Assigned(Node) and (Node.Typ=ntTypeDecl) then Result:=Node.FindNode(ntType);
end;

function MemberVisible(Member,Owner,AccessType:TSyntaxNode;const OwnerFile,AccessFile:string):Boolean;
var Scope:TSyntaxNode;
begin
  Scope:=Member.ParentNode;Result:=True;
  while Assigned(Scope) and (Scope<>Owner) do begin
    if Scope.Typ=ntStrictPrivate then Exit(Owner=AccessType);
    if Scope.Typ=ntPrivate then Exit(SameText(OwnerFile,AccessFile));
    Scope:=Scope.ParentNode;
  end;
end;

function TDeclarationSession.MemberExists(TypeNode,Root,AccessType:TSyntaxNode;
  const FileName,AccessFile,Name:string;Visited:TList<TSyntaxNode>):Boolean;
var Body,Member,Child,BaseDecl,BaseRoot:TSyntaxNode;BaseFile:string;
  function FromBase(const Base:string):Boolean;
  var Canonical:string;
  begin
    Canonical:=Base;
    if Canonical.StartsWith('System.',True) then Delete(Canonical,1,7);
    if not Base.StartsWith('System.',True) and FindSymbol(Root,FileName,Base,BaseDecl,BaseRoot,BaseFile) then
      Exit(MemberExists(BaseDecl,BaseRoot,AccessType,BaseFile,AccessFile,Name,Visited));
    if Pos('|'+UpperCase(Canonical)+'|',SystemClasses(FPlatform))>0 then
      Exit(Pos('|'+UpperCase(Canonical)+'.'+UpperCase(Name)+'|',SystemMembers(FPlatform))>0);
    raise Exception.CreateFmt('Cannot resolve DECLARED: ancestor %s is unavailable in %s',[Base,FileName]);
  end;
begin
  if Visited.Contains(TypeNode) then raise Exception.Create('Cyclic ancestor chain while resolving DECLARED');
  if Visited.Count>=64 then raise Exception.Create('Ancestor chain exceeds 64 types');
  Visited.Add(TypeNode);
  try
    Body:=TypeBody(TypeNode);if not Assigned(Body) then raise Exception.Create('Incomplete ancestor declaration');
    Member:=FindDeclaration(Body,Name);
    if Assigned(Member) then Exit(MemberVisible(Member,Body,TypeBody(AccessType),FileName,AccessFile));
    if Body.GetAttribute(anName)<>'' then Exit(FromBase(Body.GetAttribute(anName)));
    if Body.GetAttribute(anType)='class' then begin
      for Child in Body.ChildNodes do if (Child.Typ=ntType) and (Child.GetAttribute(anName)<>'') then
        Exit(FromBase(Child.GetAttribute(anName)));
      Exit(FromBase('System.TObject'));
    end;
    Result:=False;
  finally Visited.Delete(Visited.Count-1);end;
end;

function TDeclarationSession.OwnerType(Builder:TScopeAwareBuilder):TSyntaxNode;
var Scope,Root,Symbol,OwnerRoot,N:TSyntaxNode;Name,OwnerFile:string;Dot:Integer;UsedSaved:Boolean;
begin
  Result:=nil;Root:=Builder.FModuleRoot;
  if Builder.FStack.Count=0 then Exit;
  Scope:=Builder.FStack.Peek;UsedSaved:=False;
  while Assigned(Scope) do begin
    if (Scope.Typ=ntType) and (Scope.GetAttribute(anType)='class') then Exit(Scope);
    if Scope.Typ=ntMethod then begin
      N:=Scope.FindNode(ntName);Name:='';if Assigned(N) then Name:=N.GetAttribute(anName);
      Dot:=LastDelimiter('.',Name);
      if Dot>0 then begin
        Name:=Copy(Name,1,Dot-1);
        if FindSymbol(Root,Builder.FSourceFile,Name,Symbol,OwnerRoot,OwnerFile) then Exit(Symbol);
      end;
    end;
    Scope:=Scope.ParentNode;
    if not Assigned(Scope) and not UsedSaved then begin Scope:=Builder.FDeclarationScope;UsedSaved:=True;end;
  end;
end;

function TDeclarationSession.Resolve(Builder:TScopeAwareBuilder;const Name:string;out Declared:Boolean):Boolean;
var Owner,Symbol,SymbolRoot:TSyntaxNode;SymbolFile:string;Visited:TList<TSyntaxNode>;
begin
  Owner:=OwnerType(Builder);
  if Assigned(Owner) then begin
    Visited:=TList<TSyntaxNode>.Create;
    try Declared:=MemberExists(Owner,Builder.FModuleRoot,Owner,Builder.FSourceFile,Builder.FSourceFile,Name,Visited);
    finally Visited.Free;end;
    if Declared then Exit(True);
  end;
  Declared:=FindSymbol(Builder.FModuleRoot,Builder.FSourceFile,Name,Symbol,SymbolRoot,SymbolFile);
  Result:=True;
end;

procedure TDocParser.SetPlatform(const Value:string);
begin if FPlatform=Value then Exit;FPlatform:=Value;FCachedHash:='';FFailedSnapshot:=False;end;

procedure TDocParser.SetSnapshots(const Value:TArray<TSourceSnapshot>);
var I:Integer;Equal:Boolean;
begin Equal:=Length(Value)=Length(FSnapshots);if Equal then for I:=0 to High(Value) do if (Value[I].FileName<>FSnapshots[I].FileName) or (Value[I].Source<>FSnapshots[I].Source) then begin Equal:=False;Break;end;if Equal then Exit;FSnapshots:=Copy(Value);FCachedHash:='';FFailedSnapshot:=False;end;

procedure TDocParser.SetDefines(const Value:TArray<string>);
begin if string.Join(#0,FDefines)=string.Join(#0,Value) then Exit;FDefines:=Copy(Value);FCachedHash:='';FFailedSnapshot:=False;end;

procedure TDocParser.SetSearchPaths(const Value:TArray<string>);
begin if string.Join(#0,FSearchPaths)=string.Join(#0,Value) then Exit;FSearchPaths:=Copy(Value);FCachedHash:='';FFailedSnapshot:=False;end;
procedure TDocParser.SetSourceFiles(const Value:TArray<string>);
begin if string.Join(#0,FSourceFiles)=string.Join(#0,Value) then Exit;FSourceFiles:=Copy(Value);FCachedHash:='';FFailedSnapshot:=False;end;

procedure TDocParser.SetResolveDeclaration(const Value:TResolveDeclarationEvent);
begin
  FOnResolveDeclaration:=Value;
  FCachedHash:='';FFailedSnapshot:=False;
end;

{ TDocParser }

constructor TDocParser.Create;
begin
  inherited Create;

  FFlatIndex := TList<TSyntaxNode>.Create;
end;

destructor TDocParser.Destroy;
begin
  FFlatIndex.Free;
  FRootNode.Free;

  inherited;
end;

procedure TDocParser.BuildFlatIndex;
begin
  FFlatIndex.Clear;
  if not Assigned(FRootNode) then
    Exit;

  CollectDocTargets(FRootNode);

  // Line 기준 정렬
  FFlatIndex.Sort(TComparer<TSyntaxNode>.Construct(
    function(const ALeft, ARight: TSyntaxNode): Integer
    begin
      Result := ALeft.Line - ARight.Line;
      if Result=0 then Result:=ALeft.Col-ARight.Col;
    end
  ));
end;

function SyntaxTypeName(Node:TSyntaxNode):string;
var Child,Args:TSyntaxNode;Parts:TArray<string>;
begin
 Result:='';if not Assigned(Node) then Exit;
 Result:=Node.GetAttribute(anName);Args:=Node.FindNode(ntTypeArgs);
 if not Assigned(Args) and Assigned(Node.ParentNode) and (Node.ParentNode.FindNode(ntType)=Node) then Args:=Node.ParentNode.FindNode(ntTypeArgs);
 if Assigned(Args) then begin
  Parts:=nil;for Child in Args.ChildNodes do Parts:=Parts+[SyntaxTypeName(Child)];
  if Length(Parts)>0 then Result:=Result+'<'+string.Join(',',Parts)+'>';
 end;
 if Result='' then begin
  var Kind:=Node.GetAttribute(anType);
  Child:=Node.FindNode(ntType);
  if Kind='array' then Result:='array of '+SyntaxTypeName(Child)
  else if Kind='pointer' then Result:='^'+SyntaxTypeName(Child)
  else if Assigned(Child) then Result:=SyntaxTypeName(Child)
  else Result:=Kind;
 end;
end;
function SyntaxVisibility(Node:TSyntaxNode):string;
begin
 Result:='';Node:=Node.ParentNode;
 while Assigned(Node) do begin
  case Node.Typ of
   ntPrivate,ntStrictPrivate:Exit('private');
   ntProtected,ntStrictProtected:Exit('protected');
   ntPublic:Exit('public');ntPublished:Exit('published');ntAutomated:Exit('published');
  end;
  if (Node.Typ=ntType) and (Node.GetAttribute(anType)<>'') then Exit('public');
  Node:=Node.ParentNode;
 end;
end;

function TDocParser.BuildParentPath(ANode: TSyntaxNode): string;
var
  LCurrent: TSyntaxNode;
  LName: string;
begin
  Result := '';
  LCurrent := ANode.ParentNode;
  while Assigned(LCurrent) do
  begin
    if LCurrent.Typ=ntMethod then begin
      LName:=NodeToElementInfo(LCurrent).FullName;
      if Result='' then Result:=LName else Result:=LName+'.'+Result;
      Exit;
    end;
    if LCurrent.Typ = ntTypeDecl then
    begin
      LName := LCurrent.GetAttribute(anName);
      var Generics:=ExtractGenericParams(LCurrent);if Length(Generics)>0 then LName:=LName+'<'+string.Join(',',Generics)+'>';
      if LName <> '' then
      begin
        if Result = '' then
          Result := LName
        else
          Result := LName + '.' + Result;
      end;
    end;
    LCurrent := LCurrent.ParentNode;
  end;
end;

procedure TDocParser.CollectDocTargets(ANode: TSyntaxNode);
var
  I: Integer;
  LChild: TSyntaxNode;
begin
  if Assigned(FOnCheck) then FOnCheck();
  if (ANode.FileName<>'') and not SameText(ANode.FileName,FSourceFileName) then Exit;
  if IsDocTargetNode(ANode) then
    FFlatIndex.Add(ANode);

  for I := 0 to Length(ANode.ChildNodes) - 1 do
  begin
    LChild := ANode.ChildNodes[I];
    CollectDocTargets(LChild);
  end;
end;

function TDocParser.ExtractDocComment(ANode: TSyntaxNode): string;
var
  LTargetLine: Integer;
  LComments: TStringList;
  I: Integer;
  LLine: string;
begin
  Result := '';
  FLastCommentStart := -1;
  LTargetLine := ANode.Line;

  if Length(FSourceLines) = 0 then
    Exit;

  LComments := TStringList.Create;
  try
    // 코드 요소 바로 윗줄부터 역순 탐색 (0-based index)
    for I := LTargetLine - 2 downto 0 do
    begin
      LLine := FSourceLines[I].TrimLeft;
      if LLine.EndsWith(#13) then SetLength(LLine,Length(LLine)-1);
      if LLine.StartsWith('///') then begin
        LLine:=Copy(LLine,4,MaxInt);if LLine.StartsWith(' ') then Delete(LLine,1,1);
        LComments.Insert(0,LLine);
      end
      else
        Break;
    end;

    if LComments.Count > 0 then
    begin
      FLastCommentStart := LTargetLine - LComments.Count;  // 1-based
      Result := Copy(LComments.Text,1,Length(LComments.Text)-Length(LComments.LineBreak));
    end;
  finally
    LComments.Free;
  end;
end;

function TDocParser.ExtractGenericParams(ANode: TSyntaxNode): TArray<string>;
var
  LTypeParams: TSyntaxNode;
  I: Integer;
  LChild: TSyntaxNode;
  LName: string;
  LList: TList<string>;
begin
  LTypeParams := ANode.FindNode(ntTypeParams);
  if not Assigned(LTypeParams) and (ANode.Typ = ntMethod) then
  begin
    LChild := ANode.FindNode(ntName);
    if Assigned(LChild) and (Length(LChild.ChildNodes) > 0) and
       (LChild.ChildNodes[High(LChild.ChildNodes)].Typ = ntTypeParams) then
      LTypeParams := LChild.ChildNodes[High(LChild.ChildNodes)];
  end;
  if not Assigned(LTypeParams) then
  begin
    Result := nil;
    Exit;
  end;

  LList := TList<string>.Create;
  try
    for I := 0 to Length(LTypeParams.ChildNodes) - 1 do
    begin
      LChild := LTypeParams.ChildNodes[I];
      if LChild.Typ = ntTypeParam then
      begin
        LName := LChild.GetAttribute(anName);
        if LName = '' then
        begin
          LChild := LChild.FindNode(ntType);
          if Assigned(LChild) then LName := LChild.GetAttribute(anName);
        end;
        if LName <> '' then
          LList.Add(LName);
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TDocParser.ExtractParams(AMethodNode: TSyntaxNode): TArray<TParamInfo>;
var
  LParamsNode: TSyntaxNode;
  LNameNode: TSyntaxNode;
  LTypeNode: TSyntaxNode;
  LExprNode: TSyntaxNode;
  I: Integer;
  LChild: TSyntaxNode;
  LParam: TParamInfo;
  LList: TList<TParamInfo>;
  LKind: string;
begin
  LParamsNode := AMethodNode.FindNode(ntParameters);
  if not Assigned(LParamsNode) then
  begin
    Result := nil;
    Exit;
  end;

  LList := TList<TParamInfo>.Create;
  try
    for I := 0 to Length(LParamsNode.ChildNodes) - 1 do
    begin
      LChild := LParamsNode.ChildNodes[I];
      if LChild.Typ = ntParameter then
      begin
        LParam := Default(TParamInfo);

        // 파라미터 이름: ntName 자식 노드(TValuedSyntaxNode)에서 추출
        LNameNode := LChild.FindNode(ntName);
        if Assigned(LNameNode) and (LNameNode is TValuedSyntaxNode) then
          LParam.Name := TValuedSyntaxNode(LNameNode).Value
        else if Assigned(LNameNode) then
          LParam.Name := LNameNode.GetAttribute(anName);

        // 타입: ntType 자식 노드에서 추출
        LTypeNode := LChild.FindNode(ntType);
        if Assigned(LTypeNode) then
          LParam.TypeName := SyntaxTypeName(LTypeNode);

        LExprNode:=LChild.FindNode(ntExpression);LParam.HasDefault:=Assigned(LExprNode);

        // const/var/out
        LKind := LowerCase(LChild.GetAttribute(anKind));
        LParam.IsConst := LKind = 'const';
        LParam.IsVar := LKind = 'var';
        LParam.IsOut := LKind = 'out';

        LList.Add(LParam);
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TDocParser.ExtractReturnType(AMethodNode: TSyntaxNode): string;
var
  LRetNode: TSyntaxNode;
  LTypeNode: TSyntaxNode;
begin
  Result := '';
  LRetNode := AMethodNode.FindNode(ntReturnType);
  if not Assigned(LRetNode) then
    Exit;

  // ntReturnType의 자식 ntType에서 타입 이름 추출
  LTypeNode := LRetNode.FindNode(ntType);
  if Assigned(LTypeNode) then
    Result := SyntaxTypeName(LTypeNode)
  else
    Result := LRetNode.GetAttribute(anName);
end;

function TDocParser.FindNearestDocTarget(ALine: Integer): TSyntaxNode;
var
  LLow, LHigh, LMid: Integer;
  LNode: TSyntaxNode;
  LNextNode: TSyntaxNode;
begin
  Result := nil;
  if FFlatIndex.Count = 0 then
    Exit;

  // 이진 탐색: ALine 이하인 가장 가까운 노드
  LLow := 0;
  LHigh := FFlatIndex.Count - 1;

  // ALine이 첫 노드보다 앞이면 첫 노드 범위 확인
  if ALine < FFlatIndex[0].Line then
  begin
    // 주석 영역 체크: 첫 노드 위의 /// 주석 범위에 커서가 있을 수 있음
    LNode := FFlatIndex[0];
    ExtractDocComment(LNode);
    if (FLastCommentStart > 0) and (ALine >= FLastCommentStart) then
      Result := LNode;
    Exit;
  end;

  while LLow <= LHigh do
  begin
    LMid := (LLow + LHigh) div 2;
    if FFlatIndex[LMid].Line <= ALine then
      LLow := LMid + 1
    else
      LHigh := LMid - 1;
  end;

  // LHigh가 ALine 이하인 마지막 인덱스
  if LHigh >= 0 then
  begin
    LNode := FFlatIndex[LHigh];

    // 정확히 일치
    if ALine = LNode.Line then
    begin
      Result := LNode;
      Exit;
    end;

    // 다음 노드의 주석 범위에 포함되는지 체크
    if LHigh + 1 < FFlatIndex.Count then
    begin
      LNextNode := FFlatIndex[LHigh + 1];
      ExtractDocComment(LNextNode);
      if (FLastCommentStart > 0) and (ALine >= FLastCommentStart) then
      begin
        Result := LNextNode;
        Exit;
      end;
    end;

    // 현재 노드의 주석 범위에 포함되는지 체크
    ExtractDocComment(LNode);
    if (FLastCommentStart > 0) and (ALine >= FLastCommentStart) and (ALine < LNode.Line) then
    begin
      Result := LNode;
      Exit;
    end;

    // ntMethod의 본문 내부 (begin..end 사이) → 해당 메서드 반환
    if (LNode is TCompoundSyntaxNode) and
       (LNode.Typ = ntMethod) and
       (ALine <= TCompoundSyntaxNode(LNode).EndLine) then
    begin
      Result := LNode;
      Exit;
    end;

    // 두 요소 사이의 공백 영역: nil 반환 → GetElementAtLine에서 다음 요소 탐색
  end;
end;

function TDocParser.GetAllElements: TArray<TCodeElementInfo>;
var
  I: Integer;
begin
  SetLength(Result, FFlatIndex.Count);
  for I := 0 to FFlatIndex.Count - 1 do begin
    if Assigned(FOnCheck) then FOnCheck();
    Result[I] := NodeToElementInfo(FFlatIndex[I]);
  end;
end;

function TDocParser.MethodSource(const Target:TCodeElementInfo;out Code,Reason:string):Boolean;
var Selected,Match,Body,Parent:TSyntaxNode;Info:TCodeElementInfo;Count,SelectedCount,StartPos,EndPos:Integer;
 function Offset(Line,Col:Integer):Integer;
 var I,L:Integer;
 begin
  Result:=1;L:=1;I:=1;
  while (I<=Length(FCachedSource)) and (L<Line) do begin
   if FCachedSource[I]=#10 then begin Inc(L);Result:=I+1;end;Inc(I);
  end;
  if L<>Line then Exit(0);Inc(Result,Col-1);
  if (Col<1) or (Result>Length(FCachedSource)+1) then Result:=0;
 end;
 function IsBody(N:TSyntaxNode):Boolean;
 begin Result:=Assigned(N.FindNode(ntStatements));end;
begin
 Result:=False;Code:='';Reason:='Method implementation is unavailable';
 if Target.Kind<>dekMethod then begin Reason:='Select a method';Exit;end;
 Selected:=nil;Match:=nil;Count:=0;SelectedCount:=0;
 for var N in FFlatIndex do if N.Typ=ntMethod then begin
  Info:=NodeToElementInfo(N);
  if SameText(Info.SymbolId,Target.SymbolId) and (Info.LineNumber=Target.LineNumber) and SameText(Info.SourceSection,Target.SourceSection) then begin Selected:=N;Inc(SelectedCount);end;
 end;
 if (SelectedCount<>1) or not Assigned(Selected) then begin Reason:='Selected declaration has changed';Exit;end;
 if IsBody(Selected) then Match:=Selected else
  for var N in FFlatIndex do if (N.Typ=ntMethod) and IsBody(N) then begin
   Info:=NodeToElementInfo(N);Parent:=N.ParentNode;
   while Assigned(Parent) and (Parent.Typ<>ntMethod) do Parent:=Parent.ParentNode;
   if not Assigned(Parent) and SameText(Info.SymbolId,Target.SymbolId) then begin Match:=N;Inc(Count);end;
  end;
 if Count>1 then begin Reason:='Method implementation is ambiguous';Exit;end;
 if not Assigned(Match) then Exit;
 Body:=Match.FindNode(ntStatements);
 if not (Body is TCompoundSyntaxNode) then Exit;
 if ((Match.FileName<>'') and not SameText(Match.FileName,FSourceFileName)) or
    ((Body.FileName<>'') and not SameText(Body.FileName,FSourceFileName)) then begin
  Reason:='Implementation is in an include file; open that source explicitly';Exit;
 end;
 StartPos:=Offset(Match.Line,Match.Col);
 EndPos:=Offset(TCompoundSyntaxNode(Body).EndLine,TCompoundSyntaxNode(Body).EndCol);
 if (StartPos<1) or (EndPos<=StartPos) then begin Reason:='Invalid implementation source range';Exit;end;
 if (EndPos<=Length(FCachedSource)) and (FCachedSource[EndPos]=';') then Inc(EndPos);
 Code:=Copy(FCachedSource,StartPos,EndPos-StartPos).TrimRight;
 if not Code.EndsWith(';') then begin Code:='';Reason:='Incomplete implementation source range';Exit;end;
 Reason:='';Result:=True;
end;

function TDocParser.FindNextElementAtOrBelow(ALine: Integer): TSyntaxNode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FFlatIndex.Count - 1 do
  begin
    if FFlatIndex[I].Line >= ALine then
    begin
      Result := FFlatIndex[I];
      Exit;
    end;
  end;
end;

function TDocParser.GetElementAtLine(ALine: Integer): TCodeElementInfo;
var
  LNode: TSyntaxNode;
  LNextNode: TSyntaxNode;
begin
  Result := Default(TCodeElementInfo);
  Result.CommentStartLine := -1;
  Result.CommentEndLine := -1;

  LNode := FindNearestDocTarget(ALine);

  if Assigned(LNode) then
  begin
    // 커서가 노드 선언행에 정확히 위치
    if ALine = LNode.Line then
    begin
      Result := NodeToElementInfo(LNode);
      Exit;
    end;

    // 노드의 주석 범위 내 (/// 주석 블록 안)
    ExtractDocComment(LNode);
    if (FLastCommentStart > 0) and (ALine >= FLastCommentStart) and (ALine < LNode.Line) then
    begin
      Result := NodeToElementInfo(LNode);
      Exit;
    end;

    // ntMethod 본문 내부 (implementation의 begin..end 사이)
    // ntTypeDecl(class/record/interface)은 제외: 내부 빈 줄에서는 다음 멤버를 찾아야 함
    if (LNode is TCompoundSyntaxNode) and
       (LNode.Typ = ntMethod) and
       (ALine <= TCompoundSyntaxNode(LNode).EndLine) then
    begin
      Result := NodeToElementInfo(LNode);
      Exit;
    end;

    // 위 조건에 해당하지 않으면 → 아래쪽 요소 탐색
    LNextNode := FindNextElementAtOrBelow(ALine);
    if Assigned(LNextNode) then
      LNode := LNextNode;
  end
  else
  begin
    LNode := FindNextElementAtOrBelow(ALine);
  end;

  if Assigned(LNode) then
    Result := NodeToElementInfo(LNode);
end;

class function TDocParseDiagnostic.FromException(E:Exception;const FileName,Stage:string):TDocParseDiagnostic;
begin
 Result:=Default(TDocParseDiagnostic);Result.RequestedFile:=FileName;Result.FileName:=FileName;
 Result.Stage:=Stage;Result.ExceptionClass:=E.ClassName;Result.Message:=E.Message;Result.Stack:=E.StackTrace;
 if E is EParserException then begin
  if EParserException(E).FileName<>'' then Result.FileName:=EParserException(E).FileName;
  Result.Line:=EParserException(E).Line;Result.Column:=EParserException(E).Col;
 end;
end;

function TDocParseDiagnostic.DetailText:string;
begin
 Result:='Cannot parse '+RequestedFile+sLineBreak+'File: '+FileName+sLineBreak;
 if Line>0 then Result:=Result+'Line: '+IntToStr(Line)+'; Column: '+IntToStr(Column)+sLineBreak
 else Result:=Result+'Location: unavailable'+sLineBreak;
 Result:=Result+'Stage: '+Stage+sLineBreak+'Exception: '+ExceptionClass+sLineBreak+'Reason: '+Message;
 if Context<>'' then Result:=Result+sLineBreak+Context;
 if Excerpt<>'' then Result:=Result+sLineBreak+sLineBreak+Excerpt;
 if Stack<>'' then Result:=Result+sLineBreak+sLineBreak+'Stack trace:'+sLineBreak+Stack
 else Result:=Result+sLineBreak+'Stack trace: unavailable';
end;

function TDocParser.HashSource(const ASource: string): string;
begin
  Result := THashMD5.GetHashString(ASource);
end;

function TDocParser.IsDocTargetNode(ANode: TSyntaxNode): Boolean;
var
  LTypeNode: TSyntaxNode;
  LTypeAttr: string;
begin
  case ANode.Typ of
    ntUnit:
      Result := (ANode = FRootNode) and (ANode.GetAttribute(anName) <> '');
    ntMethod,
    ntProperty,
    ntField,
    ntConstant:
      Result := True;
    ntTypeDecl:
    begin
      LTypeNode := ANode.FindNode(ntType);
      if Assigned(LTypeNode) then
      begin
        LTypeAttr := LTypeNode.GetAttribute(anType);
        Result := SameText(LTypeAttr, 'class') or
                  SameText(LTypeAttr, 'record') or
                  SameText(LTypeAttr, 'interface') or
                  SameText(LTypeAttr, 'dispinterface') or
                  SameText(LTypeAttr, 'enum');
      end
      else
        Result := True;
    end;
  else
    Result := False;
  end;
end;

function TDocParser.IsUpToDate(const ASource: string): Boolean;
begin
  Result := not Assigned(FOnResolveDeclaration) and Assigned(FRootNode) and
    (FCachedHash <> '') and (FCachedSource = ASource);
  if not Result then Exit;
  Result:=DependenciesCurrent;
end;

function TDocParser.DependenciesCurrent:Boolean;
begin
  Result:=True;
  // Include lookup order is part of the cache: a previously missing local file
  // can shadow an unchanged include selected from the search path.
  for var Probe in FDependencyProbes do begin
    var WasRead:=False;
    for var Dependency in FDependencySnapshots do if SameText(Probe,Dependency.FileName) then begin WasRead:=True;Break;end;
    if not WasRead and TFile.Exists(Probe) then Exit(False);
  end;
  for var Dependency in FDependencySnapshots do begin
    var Current:='';var Found:=False;
    for var Snapshot in FSnapshots do if SameText(Snapshot.FileName,Dependency.FileName) then begin Current:=Snapshot.Source;Found:=True;Break;end;
    if not Found then begin if not TFile.Exists(Dependency.FileName) then Exit(False);Current:=ReadSourceFile(Dependency.FileName);end;
    if Current<>Dependency.Source then Exit(False);
  end;
end;

function TDocParser.FailedSnapshotIsCurrent(const Source,FileName:string):Boolean;
begin
 Result:=FFailedSnapshot and not Assigned(FOnResolveDeclaration) and SameText(FileName,FSourceFileName) and
   (Source=FCachedSource) and DependenciesCurrent;
end;

procedure TDocParser.RetryParsing;
begin FFailedSnapshot:=False;FCachedHash:='';end;

function TDocParser.NodeToElementInfo(ANode: TSyntaxNode): TCodeElementInfo;
var
  LTypeNode: TSyntaxNode;
  LTypeAttr: string;
  I, Depth, ScopeEnd: Integer;
begin
  Result := Default(TCodeElementInfo);
  Result.LineNumber := ANode.Line;
  LTypeNode:=ANode;Result.SourceSection:='interface';
  while Assigned(LTypeNode) do begin
    if LTypeNode.Typ=ntImplementation then begin Result.SourceSection:='implementation';Break;end;
    LTypeNode:=LTypeNode.ParentNode;
  end;
  Result.CommentStartLine := -1;
  Result.CommentEndLine := -1;

  case ANode.Typ of
    ntUnit:
    begin
      Result.Kind := dekUnit;
      Result.Name := ANode.GetAttribute(anName);
    end;
    ntMethod:
    begin
      Result.Kind := dekMethod;
      Result.Name := ANode.GetAttribute(anName);
      LTypeNode := ANode.FindNode(ntName);
      if Assigned(LTypeNode) and (LTypeNode.GetAttribute(anName) <> '') then
        Result.Name := LTypeNode.GetAttribute(anName);
      Depth := 0; ScopeEnd := 0;
      for I := 1 to Length(Result.Name) do
        case Result.Name[I] of
          '<': Inc(Depth);
          '>': Dec(Depth);
          '.': if Depth = 0 then ScopeEnd := I;
        end;
      if ScopeEnd > 0 then
      begin
        Result.QualifiedParent := Copy(Result.Name, 1, ScopeEnd - 1);
        Result.Name := Copy(Result.Name, ScopeEnd + 1, MaxInt);
      end;
      I := Pos('<', Result.Name);
      if I > 0 then Result.Name := Copy(Result.Name, 1, I - 1);
      Result.MethodKind := ANode.GetAttribute(anKind);
      Result.MethodBinding:=ANode.GetAttribute(anMethodBinding);Result.IsReintroduce:=SameText(ANode.GetAttribute(anReintroduce),'true');
      Result.IsOverload:=SameText(ANode.GetAttribute(anOverload),'true');
      Result.Params := ExtractParams(ANode);
      Result.ReturnType := ExtractReturnType(ANode);
      Result.GenericParams := ExtractGenericParams(ANode);
      Result.Visibility := SyntaxVisibility(ANode);
    end;

    ntProperty:
    begin
      Result.Kind := dekProperty;
      Result.Name := ANode.GetAttribute(anName);
      Result.Params:=ExtractParams(ANode);Result.ReturnType:=SyntaxTypeName(ANode.FindNode(ntType));
      Result.Visibility := SyntaxVisibility(ANode);
    end;

    ntTypeDecl:
    begin
      Result.Name := ANode.GetAttribute(anName);
      LTypeNode := ANode.FindNode(ntType);
      if Assigned(LTypeNode) then
      begin
        LTypeAttr := LTypeNode.GetAttribute(anType);
        if SameText(LTypeAttr, 'class') then
          Result.Kind := dekClass
        else if SameText(LTypeAttr, 'record') then
          Result.Kind := dekRecord
        else if SameText(LTypeAttr, 'interface') or SameText(LTypeAttr, 'dispinterface') then
          Result.Kind := dekInterface
        else if SameText(LTypeAttr, 'enum') then
          Result.Kind := dekType
        else
          Result.Kind := dekType;
      end
      else
        Result.Kind := dekType;

      Result.GenericParams := ExtractGenericParams(ANode);
    end;

    ntConstant:
    begin
      Result.Kind := dekConstant;
      Result.Name := ANode.GetAttribute(anName);
      if Result.Name = '' then
      begin
        LTypeNode := ANode.FindNode(ntName);
        if LTypeNode is TValuedSyntaxNode then
          Result.Name := TValuedSyntaxNode(LTypeNode).Value
        else if Assigned(LTypeNode) then
          Result.Name := LTypeNode.GetAttribute(anName);
      end;
    end;

    ntField:
    begin
      Result.Kind := dekField;
      Result.Name := ANode.GetAttribute(anName);
      if Result.Name = '' then
      begin
        LTypeNode := ANode.FindNode(ntName);
        if LTypeNode is TValuedSyntaxNode then
          Result.Name := TValuedSyntaxNode(LTypeNode).Value
        else if Assigned(LTypeNode) then Result.Name := LTypeNode.GetAttribute(anName);
      end;
      Result.Visibility := SyntaxVisibility(ANode);
    end;
  end;

  if Result.Visibility='' then Result.Visibility:=SyntaxVisibility(ANode);
  if Result.Kind=dekField then Result.ReturnType:=SyntaxTypeName(ANode.FindNode(ntType));
  // 부모 경로
  if Result.QualifiedParent = '' then
    Result.QualifiedParent := BuildParentPath(ANode);
  if Result.QualifiedParent <> '' then
    Result.FullName := Result.QualifiedParent + '.' + Result.Name
  else
    Result.FullName := Result.Name;

  Result.FileName:=FSourceFileName;
  Result.Signature:=Result.FullName;
  if Length(Result.GenericParams)>0 then Result.Signature:=Result.Signature+'`'+IntToStr(Length(Result.GenericParams));
  if Result.Kind in [dekMethod,dekProperty] then begin
    Result.Signature:=Result.Signature+'(';
    for I:=0 to High(Result.Params) do begin
      if I>0 then Result.Signature:=Result.Signature+';';
      if Result.Params[I].IsVar then Result.Signature:=Result.Signature+'var '
      else if Result.Params[I].IsOut then Result.Signature:=Result.Signature+'out '
      else if Result.Params[I].IsConst then Result.Signature:=Result.Signature+'const ';
      Result.Signature:=Result.Signature+Result.Params[I].TypeName;
    end;
    Result.Signature:=Result.Signature+'):'+Result.ReturnType;
  end;
  if Result.Kind=dekField then Result.Signature:=Result.Signature+':'+Result.ReturnType;
  Result.UnitName:=FRootNode.GetAttribute(anName);
  if Result.Kind=dekUnit then Result.CanonicalName:=Result.UnitName
  else Result.CanonicalName:=Result.UnitName+'.'+Result.FullName;
  Result.SymbolId:=LowerCase(FRootNode.GetAttribute(anName)+':'+Result.Kind.ToString+':'+Result.Signature);
  // The enclosing overload is part of a local declaration's identity.
  var LexicalOwner:=ANode.ParentNode;
  while Assigned(LexicalOwner) do begin
    if LexicalOwner.Typ=ntMethod then begin
      Result.SymbolId:=Result.SymbolId+'@scope:'+LowerCase(LexicalOwner.GetAttribute(anName))+'`'+IntToStr(Length(ExtractGenericParams(LexicalOwner)));
      for var Parameter in ExtractParams(LexicalOwner) do
        Result.SymbolId:=Result.SymbolId+';'+LowerCase(Parameter.TypeName)+BoolToStr(Parameter.IsVar)+BoolToStr(Parameter.IsOut)+BoolToStr(Parameter.IsConst);
    end;
    LexicalOwner:=LexicalOwner.ParentNode;
  end;
  if Result.Kind in [dekClass,dekInterface,dekRecord] then begin
    LTypeNode:=ANode.FindNode(ntType);
    if Assigned(LTypeNode) then
      for I:=0 to High(LTypeNode.ChildNodes) do
        if (LTypeNode.ChildNodes[I].Typ=ntType) and (LTypeNode.ChildNodes[I].GetAttribute(anName)<>'') then begin
          if Result.Ancestor='' then Result.Ancestor:=SyntaxTypeName(LTypeNode.ChildNodes[I])
          else Result.Implements:=Result.Implements+[SyntaxTypeName(LTypeNode.ChildNodes[I])];
        end;
  end;

  // 들여쓰기
  Result.IndentLevel := ANode.Col - 1;

  // EndLine (TCompoundSyntaxNode인 경우)
  if ANode is TCompoundSyntaxNode then
    Result.EndLineNumber := TCompoundSyntaxNode(ANode).EndLine
  else
    Result.EndLineNumber := ANode.Line;

  // 기존 주석 추출
  Result.ExistingDocXml := ExtractDocComment(ANode);
  if Result.ExistingDocXml <> '' then
  begin
    Result.CommentStartLine := FLastCommentStart;
    Result.CommentEndLine := ANode.Line - 1;
  end;
end;

function TDocParser.LocalDeclarations(const Name:string;Line:Integer):TArray<TCodeElementInfo>;
var Scope,Declaration:TSyntaxNode;
 procedure FindScope(Node:TSyntaxNode);
 begin
  if not Assigned(Node) or (Node.Line>Line) then Exit;
  if (Node is TCompoundSyntaxNode) and (TCompoundSyntaxNode(Node).EndLine<Line) then Exit;
  if Node.Typ=ntMethod then Scope:=Node;
  for var Child in Node.ChildNodes do FindScope(Child);
 end;
begin
 Result:=nil;Scope:=nil;FindScope(FRootNode);
 while Assigned(Scope) do begin
  if Scope.Typ=ntMethod then begin
   Declaration:=FindDeclaration(Scope,Name);
   if Assigned(Declaration) then begin
    if (Declaration.Typ=ntMethod) and Assigned(Declaration.ParentNode) then begin
     for var Child in Declaration.ParentNode.ChildNodes do
      if (Child.Typ=ntMethod) and SameText(DeclarationName(Child),Name) then Result:=Result+[NodeToElementInfo(Child)];
    end else Result:=TArray<TCodeElementInfo>.Create(NodeToElementInfo(Declaration));
    Exit;
   end;
  end;
  Scope:=Scope.ParentNode;
 end;
end;

function TDocParser.BindingType(const Name:string;Line:Integer):string;
var Scope,Declaration,N:TSyntaxNode;BestLine:Integer;
 function ContainsLine(Node:TSyntaxNode):Boolean;
 begin Result:=(Node.Line<=Line) and (not (Node is TCompoundSyntaxNode) or (TCompoundSyntaxNode(Node).EndLine>=Line));end;
 procedure FindScope(Node:TSyntaxNode);
 begin
  if not Assigned(Node) or not ContainsLine(Node) then Exit;
  if Node.Typ=ntMethod then Scope:=Node;
  for var Child in Node.ChildNodes do FindScope(Child);
 end;
 procedure InlineBindings(Node:TSyntaxNode);
 begin
  if (Node.Typ=ntMethod) and (Node<>Scope) then Exit;
  if not ContainsLine(Node) then Exit;
  if (Node.Typ=ntVariable) and SameText(DeclarationName(Node),Name) and (Node.Line>=BestLine) then begin Declaration:=Node;BestLine:=Node.Line;end;
  for var Child in Node.ChildNodes do InlineBindings(Child);
 end;
begin
 Result:='';Scope:=FRootNode;FindScope(FRootNode);
 if SameText(Name,'Self') and Assigned(Scope) and (Scope.Typ=ntMethod) then Exit(NodeToElementInfo(Scope).QualifiedParent);
 Declaration:=FindDeclaration(Scope,Name);BestLine:=0;InlineBindings(Scope);
 while not Assigned(Declaration) and Assigned(Scope) do begin Scope:=Scope.ParentNode;Declaration:=FindDeclaration(Scope,Name);end;
 if not Assigned(Declaration) then Exit;
 if Declaration.Typ=ntTypeDecl then Exit(DeclarationName(Declaration));
 N:=Declaration.FindNode(ntType);if not Assigned(N) and (Declaration.Typ in [ntName,ntVariable]) and Assigned(Declaration.ParentNode) then N:=Declaration.ParentNode.FindNode(ntType);
 Result:=SyntaxTypeName(N);
end;

procedure TDocParser.ParseSource(const ASource: string;const AFileName:string);
var Text:string;Lines:TArray<string>;First,Last:Integer;
begin
 FFailedSnapshot:=False;FLastDiagnostic:=Default(TDocParseDiagnostic);
 try ParseSourceInternal(ASource,AFileName);
 except
  on E:EAbort do raise;
  on E:Exception do begin
   if FLastDiagnostic.Message='' then FLastDiagnostic:=TDocParseDiagnostic.FromException(E,AFileName,'Source preparation or AST indexing');
   FLastDiagnostic.Context:='Compiler version: '+FloatToStr(CompilerVersion)+sLineBreak+'Platform: '+FPlatform+sLineBreak+'Defines: '+string.Join(';',FDefines)+sLineBreak+'Search paths: '+string.Join(';',FSearchPaths);
   Text:=ASource;
   if not SameText(FLastDiagnostic.FileName,AFileName) then begin
    Text:='';for var Dependency in FDependencySnapshots do if SameText(Dependency.FileName,FLastDiagnostic.FileName) then Text:=Dependency.Source;
    for var Snapshot in FSnapshots do if SameText(Snapshot.FileName,FLastDiagnostic.FileName) then Text:=Snapshot.Source;
   end;
   Lines:=Text.Replace(#13#10,#10).Replace(#13,#10).Split([#10]);
   if (FLastDiagnostic.Line>0) and (FLastDiagnostic.Line<=Length(Lines)) then begin
    First:=FLastDiagnostic.Line-2;if First<1 then First:=1;Last:=FLastDiagnostic.Line+2;if Last>Length(Lines) then Last:=Length(Lines);
    for var I:=First to Last do begin FLastDiagnostic.Excerpt:=FLastDiagnostic.Excerpt+Format('%d | %s',[I,Lines[I-1]])+sLineBreak;
     if (I=FLastDiagnostic.Line) and (FLastDiagnostic.Column>0) and (FLastDiagnostic.Column<=Length(Lines[I-1])+1) then FLastDiagnostic.Excerpt:=FLastDiagnostic.Excerpt+StringOfChar(' ',Length(IntToStr(I))+3+FLastDiagnostic.Column-1)+'^'+sLineBreak;
    end;
   end;
   FFailedSnapshot:=True;
   // Preserve the exception type and coordinates, but do not lose diagnostics
   // in callers that can only display Exception.Message (CLI and IDE actions).
   E.Message:=FLastDiagnostic.DetailText;
   raise;
  end;
 end;
end;

procedure TDocParser.ParseSourceInternal(const ASource: string;const AFileName:string);
var
  LStream: TStringStream;
  LHash,Define: string;
  Session:TDeclarationSession;
begin
  if not SameText(FSourceFileName,AFileName) then FCachedHash:='';
  FSourceFileName:=AFileName;
  FHasDeclared:=(Pos('DECLARED',UpperCase(ASource))>0) or
    TRegEx.IsMatch(ASource,'(?i)(?:\{|\(\*)\$\s*(?:I|INCLUDE)\s');
  if IsUpToDate(ASource) then
    Exit;
  LHash := HashSource(ASource);

  // 이전 AST 해제
  FreeAndNil(FRootNode);
  FFlatIndex.Clear;

  FCachedSource := ASource;
  FCachedHash := LHash;
  FDependencyFiles:=nil;FDependencyProbes:=nil;FDependencySnapshots:=nil;
  FSourceLines := ASource.Split([#10]);

  // 줄 끝의 #13 제거
  // Split([#10])은 #13#10에서 #13을 남김
  // 별도 정리 불필요: Trim으로 처리됨 (ExtractDocComment에서)

  Session:=TDeclarationSession.Create(FSearchPaths,FSourceFiles,FDefines,FSnapshots,FPlatform);
  Session.FOnCheck:=FOnCheck;
  LStream := nil;
  try
    if Assigned(FOnCheck) then FOnCheck();
    LStream := TStringStream.Create(Session.PrepareSource(ASource,AFileName), TEncoding.UTF8);
    FBuilder := TScopeAwareBuilder.Create;
    TScopeAwareBuilder(FBuilder).FExternalResolver := FOnResolveDeclaration;
    TScopeAwareBuilder(FBuilder).FSession:=Session;
    TScopeAwareBuilder(FBuilder).FSourceFile:=AFileName;
    FBuilder.InitDefinesDefinedByCompiler;Session.ConfigureTarget(FBuilder);
    for Define in FDefines do FBuilder.Lexer.Lexer.AddDefine(Define);
    FBuilder.Lexer.Lexer.IncludeHandler:=TResolutionIncludes.Create(Session,AFileName);
    try
      try
        FRootNode := FBuilder.Run(LStream);
      except on E:Exception do begin
        // 파싱 실패 시 이전 캐시 무효화
        FCachedHash := '';
        FRootNode := nil;
        if not (E is EAbort) then begin
         FLastDiagnostic:=TDocParseDiagnostic.FromException(E,AFileName,'AST parsing');
         if FLastDiagnostic.Line<=0 then begin FLastDiagnostic.Line:=FBuilder.Lexer.PosXY.Y;FLastDiagnostic.Column:=FBuilder.Lexer.PosXY.X;end;
         if (not (E is EParserException) or (EParserException(E).FileName='')) and (FBuilder.Lexer.FileName<>'') then FLastDiagnostic.FileName:=FBuilder.Lexer.FileName;
        end;
        raise;
      end;
      end;
    finally
      FBuilder.Free;
      FBuilder := nil;
    end;
  finally
    LStream.Free;
    FDependencyProbes:=Session.FProbes.ToArray;FDependencyFiles:=Session.FReadFiles.Keys.ToArray;SetLength(FDependencySnapshots,Length(FDependencyFiles));
    for var DependencyIndex:=0 to High(FDependencyFiles) do begin FDependencySnapshots[DependencyIndex].FileName:=FDependencyFiles[DependencyIndex];FDependencySnapshots[DependencyIndex].Source:=Session.FReadFiles[FDependencyFiles[DependencyIndex]];end;
    Session.Free;
  end;

  try
    if Assigned(FRootNode) then BuildFlatIndex;
  except
    FCachedHash:='';FFlatIndex.Clear;FreeAndNil(FRootNode);raise;
  end;
end;

end.
