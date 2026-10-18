unit XmlDoc.SourceAccess;
interface
function CompilerSourceRoots:TArray<string>;
function IsCompilerSource(const FileName:string):Boolean;
function SourceReadOnlyReason(const FileName:string):string;
implementation
uses System.SysUtils,System.IOUtils,System.Win.Registry,System.Generics.Collections,Winapi.Windows;
var Roots:TArray<string>;Initialized:Boolean;
function CompilerSourceRoots:TArray<string>;
var List:TList<string>;Reg:TRegistry;Version,Root:string;
 procedure Add(const Value:string);
 var Path:string;
 begin if Value='' then Exit;Path:=IncludeTrailingPathDelimiter(TPath.GetFullPath(TPath.Combine(Value,'source')));if not List.Contains(Path) then List.Add(Path);end;
begin
 if not Initialized then begin
  List:=TList<string>.Create;Reg:=TRegistry.Create(KEY_READ);
  try
   Add(GetEnvironmentVariable('BDS'));
   for Root in ['Software\Embarcadero\BDS\'] do
    for Version in ['23.0','37.0'] do begin
     Reg.RootKey:=HKEY_CURRENT_USER;
     if Reg.OpenKeyReadOnly(Root+Version) then begin if Reg.ValueExists('RootDir') then Add(Reg.ReadString('RootDir'));Reg.CloseKey;end;
     Reg.RootKey:=HKEY_LOCAL_MACHINE;
     if Reg.OpenKeyReadOnly(Root+Version) then begin if Reg.ValueExists('RootDir') then Add(Reg.ReadString('RootDir'));Reg.CloseKey;end;
    end;
   Roots:=List.ToArray;Initialized:=True;
  finally Reg.Free;List.Free;end;
 end;
 Result:=Roots;
end;
function IsCompilerSource(const FileName:string):Boolean;
var Path,Root:string;
begin
 Result:=False;if FileName='' then Exit;Path:=TPath.GetFullPath(FileName);
 for Root in CompilerSourceRoots do if Path.StartsWith(Root,True) then Exit(True);
end;
function SourceReadOnlyReason(const FileName:string):string;
var Attributes:Integer;
begin
 Result:='';if FileName='' then Exit;
 if IsCompilerSource(FileName) then Exit('Read-only: RAD Studio system source');
 Attributes:=FileGetAttr(FileName);
 if (Attributes<>-1) and ((Attributes and (faReadOnly or faSysFile))<>0) then Result:='Read-only: protected file';
end;
end.
