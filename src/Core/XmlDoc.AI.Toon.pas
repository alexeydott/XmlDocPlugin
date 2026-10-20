/// <summary>Lossless TOON encoding of the string, object and array shapes used by AI method context.</summary>
unit XmlDoc.AI.Toon;
interface
uses System.JSON;
function AIToon(Value:TJSONValue):string;
implementation
uses System.SysUtils,System.Classes,System.RegularExpressions;
function Quoted(const Text:string):string;
var B:TStringBuilder;I:Integer;C:Char;
begin
 B:=TStringBuilder.Create;
 try
  B.Append('"');I:=1;
  while I<=Length(Text) do begin
   C:=Text[I];
   case C of
    '"':B.Append('\"');'\':B.Append('\\');#10:B.Append('\n');#13:B.Append('\r');#9:B.Append('\t');
   else
    if Ord(C)<32 then B.Append('\u'+LowerCase(IntToHex(Ord(C),4)))
    else if (Ord(C)>=$D800) and (Ord(C)<=$DBFF) then begin
     if (I=Length(Text)) or (Ord(Text[I+1])<$DC00) or (Ord(Text[I+1])>$DFFF) then raise EArgumentException.Create('Invalid Unicode in AI context');
     B.Append(C);Inc(I);B.Append(Text[I]);
    end else if (Ord(C)>=$DC00) and (Ord(C)<=$DFFF) then raise EArgumentException.Create('Invalid Unicode in AI context')
    else B.Append(C);
   end;Inc(I);
  end;B.Append('"');Result:=B.ToString;
 finally B.Free;end;
end;
function Key(const Text:string):string;
begin if TRegEx.IsMatch(Text,'^[A-Za-z_][A-Za-z0-9_.]*$') then Result:=Text else Result:=Quoted(Text);end;
function Scalar(Value:TJSONValue):string;
var S:string;Quote,Unicode:Boolean;
begin
 if not (Value is TJSONString) or (Value is TJSONNumber) then Exit(Value.ToJSON);
 S:=Value.Value;Quote:=(S='') or (S='true') or (S='false') or (S='null') or
  TRegEx.IsMatch(S,'^[+-]?[0-9]+(?:\.[0-9]+)?(?:e[+-]?[0-9]+)?$',[roIgnoreCase]);
 if S<>'' then Quote:=Quote or CharInSet(S[1],[' ','-',#9,'#']) or CharInSet(S[Length(S)],[' ',#9]);
 Unicode:=False;for var C in S do begin
  Quote:=Quote or (Ord(C)<32) or CharInSet(C,[':', '"','\','[',']','{','}',',']);
  Unicode:=Unicode or ((Ord(C)>=$D800) and (Ord(C)<=$DFFF));
 end;
 if Unicode and not Quote then Quoted(S); // Validate scalar pairs without unnecessarily quoting emoji.
 if Quote then Result:=Quoted(S) else Result:=S;
end;
function AIToon(Value:TJSONValue):string;
var Lines:TStringList;
 procedure Emit(V:TJSONValue;const Name:string;Depth:Integer);
 var Prefix,Header,Row:string;A:TJSONArray;O,First:TJSONObject;Tabular,Primitive:Boolean;Start:Integer;
 begin
  if Depth>64 then raise EArgumentException.Create('AI context is too deeply nested');
  Prefix:=StringOfChar(' ',Depth*2);Header:=Name;
  if V is TJSONObject then begin
   O:=TJSONObject(V);if Name<>'' then begin Lines.Add(Prefix+Name+':');Inc(Depth);end;
   for var Pair in O do Emit(Pair.JsonValue,Key(Pair.JsonString.Value),Depth);Exit;
  end;
  if not (V is TJSONArray) then begin if Name<>'' then Header:=Name+': ';Lines.Add(Prefix+Header+Scalar(V));Exit;end;
  A:=TJSONArray(V);if A.Count=0 then begin if Name<>'' then Header:=Name+': ';Lines.Add(Prefix+Header+'[]');Exit;end;
  Primitive:=True;Tabular:=A[0] is TJSONObject;First:=nil;if Tabular then begin First:=TJSONObject(A[0]);Tabular:=First.Count>0;end;
  for var Item in A do begin
   Primitive:=Primitive and not ((Item is TJSONObject) or (Item is TJSONArray));
   if not (Item is TJSONObject) then Tabular:=False
   else if Assigned(First) then begin
    O:=TJSONObject(Item);if O.Count<>First.Count then Tabular:=False;
    for var Pair in First do if not Assigned(O.GetValue(Pair.JsonString.Value)) or
     (O.GetValue(Pair.JsonString.Value) is TJSONObject) or (O.GetValue(Pair.JsonString.Value) is TJSONArray) then Tabular:=False;
   end;
  end;
  Header:=Header+'['+IntToStr(A.Count)+']';
  if Primitive then begin
   Row:='';for var Item in A do begin if Row<>'' then Row:=Row+',';Row:=Row+Scalar(Item);end;
   Lines.Add(Prefix+Header+': '+Row);Exit;
  end;
  if Tabular then begin
   Row:='';for var Pair in First do begin if Row<>'' then Row:=Row+',';Row:=Row+Key(Pair.JsonString.Value);end;
   Lines.Add(Prefix+Header+'{'+Row+'}:');
   for var Item in A do begin
    Row:='';for var Pair in First do begin if Row<>'' then Row:=Row+',';Row:=Row+Scalar(TJSONObject(Item).GetValue(Pair.JsonString.Value));end;
    Lines.Add(Prefix+'  '+Row);
   end;Exit;
  end;
  Lines.Add(Prefix+Header+':');
  for var Item in A do begin
   if Item is TJSONObject then begin
    O:=TJSONObject(Item);if O.Count=0 then Lines.Add(Prefix+'  -')
    else begin Start:=Lines.Count;for var Pair in O do Emit(Pair.JsonValue,Key(Pair.JsonString.Value),Depth+2);Lines[Start]:=Prefix+'  - '+Lines[Start].TrimLeft;end;
   end
   else if Item is TJSONArray then begin
    if TJSONArray(Item).Count=0 then Lines.Add(Prefix+'  - [0]:')
    else begin Start:=Lines.Count;Emit(Item,'',Depth+1);Lines[Start]:=Prefix+'  - '+Lines[Start].TrimLeft;end;
   end
   else Lines.Add(Prefix+'  - '+Scalar(Item));
  end;
 end;
begin
 if not Assigned(Value) then raise EArgumentNilException.Create('Value');
 Lines:=TStringList.Create;
 try Emit(Value,'',0);Result:=string.Join(#10,Lines.ToStringArray);finally Lines.Free;end;
end;
end.
