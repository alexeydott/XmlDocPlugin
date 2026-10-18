unit XmlDoc.Plugin.DeclarationContext;
interface
uses XmlDoc.Parser;
procedure ConfigureDeclarationContext(Parser:TDocParser);
implementation
uses System.SysUtils,System.IOUtils,System.Generics.Collections,ToolsAPI;
procedure ConfigureDeclarationContext(Parser:TDocParser);
var Project:IOTAProject;Files,Paths:TList<string>;I:Integer;FileName,Path,Search:string;
begin
 Files:=TList<string>.Create;Paths:=TList<string>.Create;
 try
  Project:=GetActiveProject;
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
