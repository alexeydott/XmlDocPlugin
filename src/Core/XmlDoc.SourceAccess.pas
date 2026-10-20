/// <summary>Read-only and protected-source checks for documentation editing.</summary>
unit XmlDoc.SourceAccess;
interface
/// <summary>Maps a supported Delphi compiler version to its BDS registry version.</summary>
function RADVersionForCompiler(Version:Extended):string;
/// <summary>Finds RTL sources for the running IDE or the compiler used to build this tool.</summary>
function CurrentRADRoot:string;
function CompilerSourceRoots:TArray<string>;
function IsCompilerSource(const FileName:string):Boolean;
function SourceReadOnlyReason(const FileName:string):string;
implementation
uses System.SysUtils,System.IOUtils,System.Win.Registry,System.Generics.Collections,Winapi.Windows;
var Roots:TArray<string>;Initialized:Boolean;
function RADVersionForCompiler(Version:Extended):string;
begin
 if Version>=37 then Result:='37.0'
 else if Version>=36 then Result:='23.0'
 else if Version>=35 then Result:='22.0'
 else Result:='';
end;
function CurrentRADRoot:string;
const Hives:array[0..1] of HKEY=(HKEY_CURRENT_USER,HKEY_LOCAL_MACHINE);
var Reg:TRegistry;Version,Key,Path:string;Hive:HKEY;
begin
 Result:='';
 if SameText(ExtractFileName(ParamStr(0)),'bds.exe') then begin
  Path:=ExtractFileDir(ExtractFileDir(ParamStr(0)));
  if TDirectory.Exists(TPath.Combine(Path,'source')) then Exit(Path);
 end;
 Version:=RADVersionForCompiler(CompilerVersion);if Version='' then Exit;
 Key:='Software\Embarcadero\BDS\'+Version;
 for Hive in Hives do begin
  Reg:=TRegistry.Create(KEY_READ or KEY_WOW64_32KEY);
  try
   Reg.RootKey:=Hive;
   if Reg.OpenKeyReadOnly(Key) and Reg.ValueExists('RootDir') then begin
    Path:=Reg.ReadString('RootDir');if TDirectory.Exists(TPath.Combine(Path,'source')) then Exit(Path);
   end;
  finally Reg.Free;end;
 end;
end;

function CompilerSourceRoots:TArray<string>;
var List:TList<string>;Reg:TRegistry;Version,Root:string;
 procedure Add(const Value:string);
 var Path:string;
 begin if Value='' then Exit;Path:=IncludeTrailingPathDelimiter(TPath.GetFullPath(TPath.Combine(Value,'source')));if not List.Contains(Path) then List.Add(Path);end;
begin
 if not Initialized then begin
  List:=TList<string>.Create;Reg:=TRegistry.Create(KEY_READ);
  try
   Add(CurrentRADRoot);Add(GetEnvironmentVariable('BDS'));
   for Root in ['Software\Embarcadero\BDS\'] do
    for Version in ['22.0','23.0','37.0'] do begin
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
