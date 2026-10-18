unit XmlDoc.SourceText;
interface
uses System.SysUtils;
function DecodeSource(const Bytes:TBytes;Offset,Count:Integer):string;
function ReadSourceFile(const FileName:string):string;
function DocumentationResourceRoot(const FileName:string;const ProjectDir:string=''):string;
function ResolveDocumentationResource(const Source,FileName:string;const ProjectDir:string=''):string;
implementation
uses System.Classes,System.IOUtils;
function DocumentationResourceRoot(const FileName,ProjectDir:string):string;
var Root,Parent:string;
begin
 if ProjectDir<>'' then Exit(TPath.GetFullPath(ProjectDir));
 Root:=ExtractFilePath(TPath.GetFullPath(FileName));Result:=Root;
 while TDirectory.Exists(Root) do begin
  if TFile.Exists(TPath.Combine(Root,'.xmldocplugin.json')) or (Length(TDirectory.GetFiles(Root,'*.dproj',TSearchOption.soTopDirectoryOnly))>0) then Exit(Root);
  Parent:=ExtractFileDir(ExcludeTrailingPathDelimiter(Root));if SameText(Parent,ExcludeTrailingPathDelimiter(Root)) then Break;Root:=Parent;
 end;
end;
function ResolveDocumentationResource(const Source,FileName,ProjectDir:string):string;
begin
 if (Trim(Source)='') or TPath.IsPathRooted(Source) or Source.Contains(':') then raise Exception.Create('Resource must use a relative project path: '+Source);
 for var Part in Source.Replace('\','/').Split(['/']) do if Part='..' then raise Exception.Create('Resource cannot leave the project: '+Source);
 Result:=TPath.GetFullPath(TPath.Combine(DocumentationResourceRoot(FileName,ProjectDir),Source.Replace('/',PathDelim)));
end;
function DecodeSource(const Bytes:TBytes;Offset,Count:Integer):string;
var Utf8:TUTF8Encoding;ExplicitUtf8:Boolean;
begin
 if (Offset<0) or (Count<0) or (Offset>Length(Bytes)) or (Count>Length(Bytes)-Offset) then raise EArgumentOutOfRangeException.Create('Invalid source byte range');
 if Count=0 then Exit('');ExplicitUtf8:=False;
 if (Count>=3) and (Bytes[Offset]=$EF) and (Bytes[Offset+1]=$BB) and (Bytes[Offset+2]=$BF) then begin ExplicitUtf8:=True;Inc(Offset,3);Dec(Count,3);end
 else if (Count>=2) and (Bytes[Offset]=$FF) and (Bytes[Offset+1]=$FE) then Exit(TEncoding.Unicode.GetString(Bytes,Offset+2,Count-2))
 else if (Count>=2) and (Bytes[Offset]=$FE) and (Bytes[Offset+1]=$FF) then Exit(TEncoding.BigEndianUnicode.GetString(Bytes,Offset+2,Count-2));
 Utf8:=TUTF8Encoding.Create(False);
 try
  try Result:=Utf8.GetString(Bytes,Offset,Count);
  except on E:EEncodingError do begin
   if ExplicitUtf8 or (TEncoding.Default.CodePage=65001) then raise;
   Result:=TEncoding.Default.GetString(Bytes,Offset,Count);
  end;end;
 finally Utf8.Free;end;
end;
function ReadSourceFile(const FileName:string):string;
var Bytes:TBytes;
begin Bytes:=TFile.ReadAllBytes(FileName);Result:=DecodeSource(Bytes,0,Length(Bytes));end;
end.
