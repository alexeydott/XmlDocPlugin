/// <summary>Project-aware declaration context for IDE documentation commands.</summary>
unit XmlDoc.Plugin.DeclarationContext;
interface
uses XmlDoc.Parser,XmlDoc.Consts,XmlDoc.ProjectContext,ToolsAPI;
function DocumentationProjectForFile(const FileName:string;const ProjectFile:string=''):IOTAProject;
function ActiveDocumentationContext(Project:IOTAProject=nil):TProjectContext;
procedure ConfigureDeclarationContext(Parser:TDocParser;Project:IOTAProject=nil;const SourceFileName:string='');
procedure ConfigureCapturedDeclarationContext(Parser:TDocParser;Project:IOTAProject;const SourceFileName:string;const Snapshots:TArray<TSourceSnapshot>);
implementation
uses System.SysUtils,System.IOUtils,System.Generics.Collections,XmlDoc.Plugin.EditSession,XmlDoc.Plugin.Settings;
function DocumentationProjectForFile(const FileName:string;const ProjectFile:string):IOTAProject;
var Group:IOTAProjectGroup;
begin
 Result:=nil;Group:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;
 if ProjectFile<>'' then begin
  if Assigned(Group) then for var I:=0 to Group.ProjectCount-1 do if SameText(Group.Projects[I].FileName,ProjectFile) then Exit(Group.Projects[I]);
  raise Exception.Create('Project context is unavailable: '+ProjectFile);
 end;
 if Assigned(Group) and (FileName<>'') then Result:=Group.FindProject(FileName);
 if not Assigned(Result) then Result:=GetActiveProject;
end;
function ActiveDocumentationContext(Project:IOTAProject):TProjectContext;
var Configs:IOTAProjectOptionsConfigurations;Config,Platform:string;
begin
 Result:=nil;if not Assigned(Project) then Project:=GetActiveProject;if not Assigned(Project) then Exit;
 Config:='Debug';Platform:='Win32';
 if Supports(Project.ProjectOptions,IOTAProjectOptionsConfigurations,Configs) and Assigned(Configs.ActiveConfiguration) then begin
  Config:=Configs.ActiveConfiguration.Name;Platform:=Configs.ActivePlatformName;
 end;
 Result:=TProjectContext.Create(Project.FileName,Config,Platform);
 if Project=GetActiveProject then TPluginSettings.Instance.LoadProject(ExtractFilePath(Project.FileName));
end;
procedure ConfigureDeclarationContext(Parser:TDocParser;Project:IOTAProject;const SourceFileName:string);
begin ConfigureCapturedDeclarationContext(Parser,Project,SourceFileName,CurrentSourceSnapshots);end;
procedure ConfigureCapturedDeclarationContext(Parser:TDocParser;Project:IOTAProject;const SourceFileName:string;const Snapshots:TArray<TSourceSnapshot>);
var Context:TProjectContext;Files,Paths:TList<string>;I:Integer;FileName,Path,Search:string;
begin
 Files:=TList<string>.Create;Paths:=TList<string>.Create;
 try
  Parser.SourceSnapshots:=Snapshots;
  if not Assigned(Project) then begin if SourceFileName<>'' then Project:=DocumentationProjectForFile(SourceFileName) else Project:=DocumentationProjectForFile(Parser.SourceFileName);end;
  Context:=ActiveDocumentationContext(Project);
  try
   if not Assigned(Context) then begin Parser.Platform:='';Parser.Defines:=nil;end;
   if Assigned(Context) then begin Parser.Platform:=Context.Platform;Parser.Defines:=Context.Defines;
    Paths.AddRange(Context.SearchPaths);Paths.AddRange(Context.IncludePaths);Files.AddRange(Context.SourceFiles);end;
  if Assigned(Project) then begin
   Paths.Add(ExtractFilePath(Project.FileName));
   for I:=0 to Project.GetModuleCount-1 do begin
    FileName:=Project.GetModule(I).FileName;
    if Assigned(Context) and SameText(ExtractFileExt(FileName),'.pas') then FileName:=Context.ResolveModuleSource(FileName);
    if SameText(ExtractFileExt(FileName),'.pas') then begin
     Files.Add(FileName);
     Path:=ExtractFilePath(FileName);
     if not Paths.Contains(Path) then Paths.Add(Path);
    end;
   end;
   Search:=Project.ProjectOptions.Values['UnitSearchPath'];
   for Path in Search.Split([';']) do
    if (Trim(Path)<>'') and not Path.Contains('$(') then begin
     if TPath.IsPathRooted(Path) then FileName:=Path
     else FileName:=TPath.Combine(ExtractFilePath(Project.FileName),Path);
     if TDirectory.Exists(FileName) and not Paths.Contains(FileName) then Paths.Add(FileName);
    end;
  end;
  Parser.SourceFiles:=Files.ToArray;
  Parser.SearchPaths:=Paths.ToArray;
  finally Context.Free;end;
 finally Paths.Free;Files.Free;end;
end;
end.
