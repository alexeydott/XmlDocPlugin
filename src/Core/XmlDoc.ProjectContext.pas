unit XmlDoc.ProjectContext;
interface
uses System.SysUtils,System.Generics.Collections;
type
 TProjectContext=class
 private
  FProperties:TDictionary<string,string>;
  FDirectory:string;
  function ExpandProperty(const Name:string):string;
  function Condition(const Text:string):Boolean;
  function Paths(const Value:string):TArray<string>;
  function ResolveSource(const Reference:string):string;
 public
  ProjectFile,Configuration,Platform,MainSource:string;
  SearchPaths,IncludePaths,Defines,SourceFiles:TArray<string>;
  constructor Create(const FileName:string;const Config:string='Debug';const Target:string='Win32');
  destructor Destroy;override;
  function Expand(const Text:string):string;
 end;
implementation
uses System.IOUtils,System.RegularExpressions,System.Generics.Defaults,Xml.XMLDoc,Xml.XMLIntf;
function TProjectContext.ExpandProperty(const Name:string):string;
begin if not FProperties.TryGetValue(Name,Result) then Result:=GetEnvironmentVariable(Name);end;
function TProjectContext.Expand(const Text:string):string;
var Match:TMatch;I:Integer;
begin
 Result:=Text;
 for I:=1 to 32 do begin
  Match:=TRegEx.Match(Result,'\$\(([^)]+)\)');if not Match.Success then Exit;
  Result:=Copy(Result,1,Match.Index-1)+ExpandProperty(Match.Groups[1].Value)+Copy(Result,Match.Index+Match.Length,MaxInt);
 end;
 raise Exception.Create('Recursive project property: '+Text);
end;
function TProjectContext.Condition(const Text:string):Boolean;
var Value:string;Pos:Integer;
 procedure Fail;
 begin raise Exception.Create('Unsupported project condition: '+Text);end;
 procedure SkipSpace;
 begin while (Pos<=Length(Value)) and CharInSet(Value[Pos],[#9,#10,#13,' ']) do Inc(Pos);end;
 function Take(const Token:string):Boolean;
 begin SkipSpace;Result:=SameText(Copy(Value,Pos,Length(Token)),Token);if Result then Inc(Pos,Length(Token));end;
 function Keyword(const Token:string):Boolean;
 var Last:Integer;
 begin
  SkipSpace;Last:=Pos+Length(Token);
  Result:=SameText(Copy(Value,Pos,Length(Token)),Token) and
   ((Last>Length(Value)) or not CharInSet(Value[Last],['a'..'z','A'..'Z','0'..'9','_']));
  if Result then Pos:=Last;
 end;
 function ReadValue:string;
 var First:Integer;Quote:Char;
 begin
  SkipSpace;if Pos>Length(Value) then Fail;
  Quote:=Value[Pos];
  if CharInSet(Quote,['''','"']) then begin
   Inc(Pos);First:=Pos;while (Pos<=Length(Value)) and (Value[Pos]<>Quote) do Inc(Pos);
   if Pos>Length(Value) then Fail;Result:=Copy(Value,First,Pos-First);Inc(Pos);
  end else begin
   First:=Pos;while (Pos<=Length(Value)) and not CharInSet(Value[Pos],[#9,#10,#13,' ','(',')','=','!','<','>']) do Inc(Pos);
   if Pos=First then Fail;Result:=Copy(Value,First,Pos-First);
  end;
 end;
 function ParseOr:Boolean;forward;
 function Primary:Boolean;
 var Left,Right,Path:string;Different:Boolean;
 begin
  SkipSpace;
  if Take('!') then Exit(not Primary);
  if Take('(') then begin Result:=ParseOr;if not Take(')') then Fail;Exit;end;
  if Keyword('Exists') then begin
   if not Take('(') then Fail;Path:=ReadValue;if not Take(')') then Fail;
   if Path='' then Exit(False);
   if not TPath.IsPathRooted(Path) then Path:=TPath.Combine(FDirectory,Path);
   Exit(TFile.Exists(Path) or TDirectory.Exists(Path));
  end;
  Left:=ReadValue;
  Different:=Take('!=');
  if Different or Take('==') then begin Right:=ReadValue;Result:=SameText(Left,Right);if Different then Result:=not Result;Exit;end;
  if SameText(Left,'true') then Exit(True);
  if SameText(Left,'false') then Exit(False);
  Fail;Result:=False;
 end;
 function ParseAnd:Boolean;
 var Right:Boolean;
 begin Result:=Primary;while Keyword('and') do begin Right:=Primary;Result:=Result and Right;end;end;
 function ParseOr:Boolean;
 var Right:Boolean;
 begin Result:=ParseAnd;while Keyword('or') do begin Right:=ParseAnd;Result:=Result or Right;end;end;
begin
 Value:=Trim(Expand(Text));if Value='' then Exit(True);
 Pos:=1;Result:=ParseOr;SkipSpace;if Pos<=Length(Value) then Fail;
end;
function TProjectContext.Paths(const Value:string):TArray<string>;
var Part,Path:string;List:TList<string>;
begin List:=TList<string>.Create;try for Part in Expand(Value).Split([';']) do if Trim(Part)<>'' then begin
 Path:=Trim(Part);if not TPath.IsPathRooted(Path) then Path:=TPath.Combine(FDirectory,Path);
 Path:=TPath.GetFullPath(Path);if not List.Contains(Path) then List.Add(Path);end;Result:=List.ToArray;
 finally List.Free;end;end;
function TProjectContext.ResolveSource(const Reference:string):string;
begin
 Result:=Reference;if not TPath.IsPathRooted(Result) then Result:=TPath.Combine(FDirectory,Result);Result:=TPath.GetFullPath(Result);
 if TFile.Exists(Result) then Exit;
 // Bare unit references are resolved using the evaluated compiler search path.
 // Explicit relative or absolute paths retain their original meaning.
 if not TPath.IsPathRooted(Reference) and (ExtractFilePath(Reference)='') then
  for var Directory in SearchPaths do begin
   var Candidate:=TPath.GetFullPath(TPath.Combine(Directory,Reference));if TFile.Exists(Candidate) then Exit(Candidate);
  end;
 raise Exception.Create('Missing project source: '+Result);
end;
constructor TProjectContext.Create(const FileName,Config,Target:string);
var Doc:IXMLDocument;Group,Node:IXMLNode;I,J:Integer;Name,Value,Path:string;Files:TList<string>;
begin
 inherited Create;FProperties:=TDictionary<string,string>.Create(TIStringComparer.Ordinal);
 ProjectFile:=TPath.GetFullPath(FileName);FDirectory:=ExtractFilePath(ProjectFile);Configuration:=Config;Platform:=Target;
 if Configuration='' then Configuration:='Debug';if Platform='' then Platform:='Win32';
 FProperties.Add('Config',Configuration);FProperties.Add('Platform',Platform);
 FProperties.Add('MSBuildProjectDirectory',ExcludeTrailingPathDelimiter(FDirectory));FProperties.Add('MSBuildProjectName',TPath.GetFileNameWithoutExtension(FileName));
 FProperties.Add('BDS',GetEnvironmentVariable('BDS'));
 if not SameText(ExtractFileExt(FileName),'.dproj') then begin MainSource:=ProjectFile;Exit;end;
 Doc:=LoadXMLDocument(ProjectFile);Files:=TList<string>.Create;
 try
  for I:=0 to Doc.DocumentElement.ChildNodes.Count-1 do begin Group:=Doc.DocumentElement.ChildNodes[I];if Group.NodeType<>ntElement then Continue;
   if Group.HasAttribute('Condition') and not Condition(Group.Attributes['Condition']) then Continue;
   if Group.NodeName='MainSource' then FProperties.AddOrSetValue('MainSource',Expand(Group.Text));
   if Group.NodeName='PropertyGroup' then for J:=0 to Group.ChildNodes.Count-1 do begin
    Node:=Group.ChildNodes[J];if Node.NodeType<>ntElement then Continue;
    if Node.HasAttribute('Condition') and not Condition(Node.Attributes['Condition']) then Continue;
    Name:=Node.NodeName;if SameText(Name,'Config') or SameText(Name,'Platform') then Continue;
    FProperties.AddOrSetValue(Name,Expand(Node.Text));
   end;
   if Group.NodeName='ItemGroup' then for J:=0 to Group.ChildNodes.Count-1 do begin
    Node:=Group.ChildNodes[J];if (Node.NodeName<>'DCCReference') or not Node.HasAttribute('Include') then Continue;
    if Node.HasAttribute('Condition') and not Condition(Node.Attributes['Condition']) then Continue;
    Path:=Expand(Node.Attributes['Include']);if SameText(ExtractFileExt(Path),'.pas') then begin
     if not Files.Contains(Path) then Files.Add(Path);
    end;
   end;
  end;
  MainSource:=ExpandProperty('MainSource');if not TPath.IsPathRooted(MainSource) then MainSource:=TPath.Combine(FDirectory,MainSource);
  SearchPaths:=Paths(ExpandProperty('DCC_UnitSearchPath'));IncludePaths:=Paths(ExpandProperty('DCC_IncludePath'));
  Value:=ExpandProperty('DCC_Define');Defines:=Value.Split([';'],TStringSplitOptions.ExcludeEmpty);
  var Resolved:=TList<string>.Create;
  try for var Reference in Files do begin Path:=ResolveSource(Reference);if not Resolved.Contains(Path) then Resolved.Add(Path);end;SourceFiles:=Resolved.ToArray;finally Resolved.Free;end;
 finally Files.Free;end;
end;
destructor TProjectContext.Destroy;
begin FProperties.Free;inherited;end;
end.
