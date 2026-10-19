/// <summary>Validated copying of documentation images and example source resources.</summary>
unit XmlDoc.HelpGen.Resources;
interface
uses System.SysUtils,System.Generics.Collections,XmlDoc.HelpGen.Types;
function CopyDocumentationImage(const Source,UnitName,ProjectDir,OutputDir,Folder:string;Units:TObjectList<TUnitDocInfo>):string;
function CopyDocumentationSource(const Source,UnitName,ProjectDir,OutputDir,Folder:string;Units:TObjectList<TUnitDocInfo>):string;
implementation
uses XmlDoc.SourceText,System.IOUtils,System.Classes,System.Hash,System.StrUtils;
function CopyResource(const Source,UnitName,ProjectDir,OutputDir,Folder:string;Units:TObjectList<TUnitDocInfo>;Image:Boolean):string;
var Root,FileName,Extension,Name,Target:string;U:TUnitDocInfo;Stream:TFileStream;
begin
 if (Trim(Source)='') or TPath.IsPathRooted(Source) or Source.Contains(':') then raise Exception.Create('Documentation image must use a relative project path: '+Source);
 for var Part in Source.Replace('\','/').Split(['/']) do if Part='..' then raise Exception.Create('Documentation image cannot leave the project: '+Source);
 Root:='';for U in Units do if SameText(U.UnitName,UnitName) then begin Root:=U.FilePath;Break;end;
 if (Root='') and (ProjectDir='') then raise Exception.Create('No source context for documentation resource '+Source);
 FileName:=ResolveDocumentationResource(Source,Root,ProjectDir);
 if not TFile.Exists(FileName) then raise Exception.Create('Documentation image does not exist: '+FileName);
 Extension:=LowerCase(ExtractFileExt(FileName));
 if Image and not MatchText(Extension,['.png','.jpg','.jpeg','.gif','.bmp','.webp','.ico']) then raise Exception.Create('Unsupported documentation image type: '+Extension);
 if not Image and not MatchText(Extension,['.pas','.dpr','.inc','.txt']) then raise Exception.Create('Unsupported example source type: '+Extension);
 Stream:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
 try Name:='image_'+Copy(THashSHA2.GetHashString(Stream),1,24)+Extension;finally Stream.Free;end;
 Target:=TPath.Combine(TPath.Combine(OutputDir,Folder),Name);ForceDirectories(ExtractFilePath(Target));TFile.Copy(FileName,Target,True);
 Result:=Name;
end;
function CopyDocumentationImage(const Source,UnitName,ProjectDir,OutputDir,Folder:string;Units:TObjectList<TUnitDocInfo>):string;
begin Result:=CopyResource(Source,UnitName,ProjectDir,OutputDir,Folder,Units,True);end;
function CopyDocumentationSource(const Source,UnitName,ProjectDir,OutputDir,Folder:string;Units:TObjectList<TUnitDocInfo>):string;
begin Result:=CopyResource(Source,UnitName,ProjectDir,OutputDir,Folder,Units,False);end;
end.
