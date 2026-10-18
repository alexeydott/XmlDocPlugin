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
var Value,Part:string;Match:TMatch;Parts:TArray<string>;All:Boolean;
begin
 Value:=Trim(Expand(Text));if Value='' then Exit(True);
 Parts:=TRegEx.Split(Value,'(?i)\s+or\s+');
 if Length(Parts)>1 then begin for Part in Parts do if Condition(Part) then Exit(True);Exit(False);end;
 Parts:=TRegEx.Split(Value,'(?i)\s+and\s+');
 if Length(Parts)>1 then begin for Part in Parts do if not Condition(Part) then Exit(False);Exit(True);end;
 if Value.StartsWith('(') and Value.EndsWith(')') then Exit(Condition(Copy(Value,2,Length(Value)-2)));
 Match:=TRegEx.Match(Value,'^\s*''([^'']*)''\s*(==|!=)\s*''([^'']*)''\s*$');
 if Match.Success then begin Result:=SameText(Match.Groups[1].Value,Match.Groups[3].Value);if Match.Groups[2].Value='!=' then Result:=not Result;Exit;end;
 Match:=TRegEx.Match(Value,'(?i)^(!?)Exists\(''([^'']*)''\)$');
 if Match.Success then begin Result:=TFile.Exists(TPath.Combine(FDirectory,Match.Groups[2].Value));if Match.Groups[1].Value='!' then Result:=not Result;Exit;end;
 if SameText(Value,'true') then Exit(True);if SameText(Value,'false') then Exit(False);
 raise Exception.Create('Unsupported project condition: '+Text);
end;
function TProjectContext.Paths(const Value:string):TArray<string>;
var Part,Path:string;List:TList<string>;
begin List:=TList<string>.Create;try for Part in Expand(Value).Split([';']) do if Trim(Part)<>'' then begin
 Path:=Trim(Part);if not TPath.IsPathRooted(Path) then Path:=TPath.Combine(FDirectory,Path);
 Path:=TPath.GetFullPath(Path);if not List.Contains(Path) then List.Add(Path);end;Result:=List.ToArray;
 finally List.Free;end;end;
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
     if not TPath.IsPathRooted(Path) then Path:=TPath.Combine(FDirectory,Path);Path:=TPath.GetFullPath(Path);
     if not TFile.Exists(Path) then raise Exception.Create('Missing project source: '+Path);
     if not Files.Contains(Path) then Files.Add(Path);
    end;
   end;
  end;
  MainSource:=ExpandProperty('MainSource');if not TPath.IsPathRooted(MainSource) then MainSource:=TPath.Combine(FDirectory,MainSource);
  SearchPaths:=Paths(ExpandProperty('DCC_UnitSearchPath'));IncludePaths:=Paths(ExpandProperty('DCC_IncludePath'));
  Value:=ExpandProperty('DCC_Define');Defines:=Value.Split([';'],TStringSplitOptions.ExcludeEmpty);SourceFiles:=Files.ToArray;
 finally Files.Free;end;
end;
destructor TProjectContext.Destroy;
begin FProperties.Free;inherited;end;
end.
