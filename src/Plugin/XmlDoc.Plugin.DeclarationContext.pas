unit XmlDoc.Plugin.DeclarationContext;
interface
uses XmlDoc.Parser,XmlDoc.ProjectContext,ToolsAPI;
function ActiveDocumentationContext(Project:IOTAProject=nil):TProjectContext;
procedure ConfigureDeclarationContext(Parser:TDocParser;Project:IOTAProject=nil);
implementation
uses System.SysUtils,System.IOUtils,System.Generics.Collections,XmlDoc.Plugin.EditSession,XmlDoc.Plugin.Settings;
function ActiveDocumentationContext(Project:IOTAProject):TProjectContext;
var Configs:IOTAProjectOptionsConfigurations;Config,Platform:string;
begin
 Result:=nil;if not Assigned(Project) then Project:=GetActiveProject;if not Assigned(Project) then Exit;
 Config:='Debug';Platform:='Win32';
 if Supports(Project.ProjectOptions,IOTAProjectOptionsConfigurations,Configs) and Assigned(Configs.ActiveConfiguration) then begin
  Config:=Configs.ActiveConfiguration.Name;Platform:=Configs.ActiveConfiguration.Platform;
 end;
 Result:=TProjectContext.Create(Project.FileName,Config,Platform);
 if Project=GetActiveProject then TPluginSettings.Instance.LoadProject(ExtractFilePath(Project.FileName));
end;
procedure ConfigureDeclarationContext(Parser:TDocParser;Project:IOTAProject);
var Context:TProjectContext;Files,Paths:TList<string>;I:Integer;FileName,Path,Search:string;
begin
 Files:=TList<string>.Create;Paths:=TList<string>.Create;
 try
  Parser.SourceSnapshots:=CurrentSourceSnapshots;
  if not Assigned(Project) then Project:=GetActiveProject;
  Context:=ActiveDocumentationContext(Project);
  try
   if Assigned(Context) then begin Parser.Platform:=Context.Platform;Parser.Defines:=Context.Defines;
    Paths.AddRange(Context.SearchPaths);Paths.AddRange(Context.IncludePaths);Files.AddRange(Context.SourceFiles);end;
  finally Context.Free;end;
  if Assigned(Project) then begin
   Paths.Add(ExtractFilePath(Project.FileName));
   for I:=0 to Project.GetModuleCount-1 do begin
    FileName:=Project.GetModule(I).FileName;
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
 finally Paths.Free;Files.Free;end;
end;
end.
