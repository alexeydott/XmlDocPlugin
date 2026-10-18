unit XmlDoc.SourceText;
interface
uses System.SysUtils;
function DecodeSource(const Bytes:TBytes;Offset,Count:Integer):string;
function ReadSourceFile(const FileName:string):string;
implementation
uses System.Classes,System.IOUtils;
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
