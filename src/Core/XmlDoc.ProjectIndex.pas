/// <summary>Incremental declaration indexing with source and dependency validation.</summary>
unit XmlDoc.ProjectIndex;
interface
uses System.SysUtils,System.Generics.Collections,XmlDoc.Consts,XmlDoc.Parser;
type
 /// <summary>Fresh dependency revisions shared by one synchronous publication check.
 /// Discard before yielding to the IDE or changing a parser's context.</summary>
 TIndexValidation=class
 private
  FRevisions,FSnapshots:TDictionary<string,string>;
  FContexts:TDictionary<TDocParser,string>;
 public
  constructor Create(const Snapshots:TArray<TSourceSnapshot>);
  destructor Destroy;override;
  function Revision(const FileName:string):string;
  function ContextKey(Parser:TDocParser):string;
 end;
 TIndexedModule=class
  Elements:TArray<TCodeElementInfo>;
  SourceKey,ContextKey:string;
  Dependencies:TDictionary<string,string>;
  constructor Create;
  destructor Destroy;override;
 end;
 TDocumentationIndex=class
 private
  FModules:TObjectDictionary<string,TIndexedModule>;
  FParsed,FReused:Integer;
  function Revision(const FileName:string;const Snapshots:TArray<TSourceSnapshot>):string;
 public
  constructor Create;
  destructor Destroy;override;
  function IsCurrent(const FileName,Source:string;Parser:TDocParser):Boolean;overload;
  function IsCurrent(const FileName,Source:string;Parser:TDocParser;Validation:TIndexValidation):Boolean;overload;
  function Update(const FileName,Source:string;Parser:TDocParser):TArray<TCodeElementInfo>;
  function Elements(const FileName:string):TArray<TCodeElementInfo>;
  procedure ResetStatistics;
  property Parsed:Integer read FParsed;
  property Reused:Integer read FReused;
 end;
implementation
uses System.Hash,System.IOUtils,XmlDoc.SourceText;
function ParserContextKey(Parser:TDocParser):string;
begin Result:=Parser.Platform+#0+string.Join(#0,Parser.Defines)+#1+string.Join(#0,Parser.SearchPaths)+#1+string.Join(#0,Parser.SourceFiles);end;
constructor TIndexValidation.Create(const Snapshots:TArray<TSourceSnapshot>);
begin
 inherited Create;FRevisions:=TDictionary<string,string>.Create;FSnapshots:=TDictionary<string,string>.Create;FContexts:=TDictionary<TDocParser,string>.Create;
 for var Snapshot in Snapshots do FSnapshots.AddOrSetValue(LowerCase(TPath.GetFullPath(Snapshot.FileName)),Snapshot.Source);
end;
destructor TIndexValidation.Destroy;
begin FContexts.Free;FSnapshots.Free;FRevisions.Free;inherited;end;
function TIndexValidation.Revision(const FileName:string):string;
var Key,Source:string;
begin
 Key:=LowerCase(TPath.GetFullPath(FileName));if FRevisions.TryGetValue(Key,Result) then Exit;
 if FSnapshots.TryGetValue(Key,Source) then Result:=THashSHA2.GetHashString(Source)
 else if TFile.Exists(FileName) then Result:=THashSHA2.GetHashString(ReadSourceFile(FileName)) else Result:='missing';
 FRevisions.Add(Key,Result);
end;
function TIndexValidation.ContextKey(Parser:TDocParser):string;
begin if not FContexts.TryGetValue(Parser,Result) then begin Result:=ParserContextKey(Parser);FContexts.Add(Parser,Result);end;end;
constructor TIndexedModule.Create;
begin inherited;Dependencies:=TDictionary<string,string>.Create;end;
destructor TIndexedModule.Destroy;
begin Dependencies.Free;inherited;end;
constructor TDocumentationIndex.Create;
begin inherited;FModules:=TObjectDictionary<string,TIndexedModule>.Create([doOwnsValues]);end;
destructor TDocumentationIndex.Destroy;
begin FModules.Free;inherited;end;
procedure TDocumentationIndex.ResetStatistics;
begin FParsed:=0;FReused:=0;end;
function TDocumentationIndex.Revision(const FileName:string;const Snapshots:TArray<TSourceSnapshot>):string;
begin
 for var Snapshot in Snapshots do if SameText(Snapshot.FileName,FileName) then Exit(THashSHA2.GetHashString(Snapshot.Source));
 if not TFile.Exists(FileName) then Exit('missing');Result:=THashSHA2.GetHashString(ReadSourceFile(FileName));
end;
function TDocumentationIndex.Elements(const FileName:string):TArray<TCodeElementInfo>;
var Module:TIndexedModule;
begin if not FModules.TryGetValue(LowerCase(TPath.GetFullPath(FileName)),Module) then raise Exception.Create('Module is not indexed: '+FileName);Result:=Copy(Module.Elements);end;
function TDocumentationIndex.IsCurrent(const FileName,Source:string;Parser:TDocParser):Boolean;
var Validation:TIndexValidation;
begin
 Validation:=TIndexValidation.Create(Parser.SourceSnapshots);
 try Result:=IsCurrent(FileName,Source,Parser,Validation);finally Validation.Free;end;
end;
function TDocumentationIndex.IsCurrent(const FileName,Source:string;Parser:TDocParser;Validation:TIndexValidation):Boolean;
var Module:TIndexedModule;
begin
 Result:=FModules.TryGetValue(LowerCase(TPath.GetFullPath(FileName)),Module);if not Result then Exit;
 Result:=(Module.SourceKey=THashSHA2.GetHashString(Source)) and (Module.ContextKey=Validation.ContextKey(Parser));
 if Result then for var Pair in Module.Dependencies do if Pair.Value<>Validation.Revision(Pair.Key) then Exit(False);
end;
function TDocumentationIndex.Update(const FileName,Source:string;Parser:TDocParser):TArray<TCodeElementInfo>;
var Module:TIndexedModule;Key,SourceKey,ContextKey:string;Valid:Boolean;
begin
 Key:=LowerCase(TPath.GetFullPath(FileName));SourceKey:=THashSHA2.GetHashString(Source);
 ContextKey:=ParserContextKey(Parser);
 Valid:=FModules.TryGetValue(Key,Module);
 if Valid then begin
  Valid:=(Module.SourceKey=SourceKey) and (Module.ContextKey=ContextKey);
  if Valid then for var Pair in Module.Dependencies do if Pair.Value<>Revision(Pair.Key,Parser.SourceSnapshots) then begin Valid:=False;Break;end;
 end;
 if Valid then begin Inc(FReused);Exit(Copy(Module.Elements));end;
 Parser.ParseSource(Source,FileName);Module:=TIndexedModule.Create;
 try
  Module.Elements:=Parser.GetAllElements;Module.SourceKey:=SourceKey;Module.ContextKey:=ContextKey;
  for var Dependency in Parser.DependencySnapshots do Module.Dependencies.AddOrSetValue(Dependency.FileName,THashSHA2.GetHashString(Dependency.Source));
  for var Probe in Parser.DependencyProbes do if not Module.Dependencies.ContainsKey(Probe) then Module.Dependencies.Add(Probe,'missing');
  // The dependency set includes transitive imported DECLARED sources and their includes.
  FModules.AddOrSetValue(Key,Module);Result:=Copy(Module.Elements);Module:=nil;Inc(FParsed);
 finally Module.Free;end;
end;
end.
