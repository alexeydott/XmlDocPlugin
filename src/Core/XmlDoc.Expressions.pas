unit XmlDoc.Expressions;
interface
uses System.SysUtils,XmlDoc.Consts,XmlDoc.Parser;
function ResolveDocumentationExpression(Parser:TDocParser;const Source:string;Position,Line:Integer;
 const Symbols:TArray<TCodeElementInfo>;out Query,Reason:string):TArray<TCodeElementInfo>;
implementation
uses System.Math,System.Character,System.Generics.Collections,System.RegularExpressions;
function Identifier(C:Char):Boolean;
begin Result:=C.IsLetterOrDigit or (C='_') or (C='.');end;
function SimpleType(const Name:string):string;
begin
 Result:=LowerCase(Trim(Name));if Result.StartsWith('system.') then Delete(Result,1,7);
 if (Result='unicodestring') or (Result='widestring') then Result:='string';if Result='longint' then Result:='integer';
end;
function TypeMatches(const Owner,Name:string):Boolean;
begin Result:=SameText(Owner,Name) or LowerCase(Owner).EndsWith('.'+LowerCase(Name));end;
function ResolveDocumentationExpression(Parser:TDocParser;const Source:string;Position,Line:Integer;
 const Symbols:TArray<TCodeElementInfo>;out Query,Reason:string):TArray<TCodeElementInfo>;
var First,Last,OpenAt,Depth,Angle,BestScore:Integer;Owner,Member,Receiver:string;Args:TList<string>;Candidates,Best:TList<TCodeElementInfo>;HasCall,InString:Boolean;
 function ExpressionType(const Expression:string):string;
 var Text:string;
 begin
  Text:=Trim(Expression);Result:='';if Text='' then Exit;
  if TRegEx.IsMatch(Text,'^[+-]?(?:\d+|\$[0-9a-fA-F]+)$') then Exit('Integer');
  if TRegEx.IsMatch(Text,'^[+-]?\d+\.\d+(?:[Ee][+-]?\d+)?$') then Exit('Double');
  if (Text[1]=#39) and (Text[Length(Text)]=#39) then Exit('string');
  if SameText(Text,'True') or SameText(Text,'False') then Exit('Boolean');Result:=Parser.BindingType(Text,Line);
 end;
 function Owners(const TypeName:string):TArray<string>;
 var Pending,Seen:TList<string>;Current:string;
 begin
  Pending:=TList<string>.Create;Seen:=TList<string>.Create;
  try Pending.Add(TypeName);while (Pending.Count>0) and (Seen.Count<128) do begin
   Current:=Pending[0];Pending.Delete(0);if Seen.Contains(LowerCase(Current)) then Continue;Seen.Add(LowerCase(Current));
   for var E in Symbols do if (E.Kind in [dekClass,dekInterface,dekRecord]) and (TypeMatches(E.CanonicalName,Current) or TypeMatches(E.FullName,Current)) then begin
    if E.Ancestor<>'' then Pending.Add(E.Ancestor);for var Name in E.Implements do Pending.Add(Name);
   end;
  end;Result:=Seen.ToArray;
  finally Seen.Free;Pending.Free;end;
 end;
 function Score(const E:TCodeElementInfo):Integer;
 var Required,Cost:Integer;Actual,Expected:string;
 begin
  Result:=0;if not HasCall then Exit;Required:=0;for var P in E.Params do if not P.HasDefault and (P.DefaultValue='') then Inc(Required);
  if (Args.Count<Required) or (Args.Count>Length(E.Params)) then Exit(MaxInt);
  for var I:=0 to Args.Count-1 do begin
   Actual:=SimpleType(ExpressionType(Args[I]));Expected:=SimpleType(E.Params[I].TypeName);Cost:=0;
   if Actual='' then Cost:=10 else if Actual<>Expected then begin
    if (Actual='integer') and ((Expected='int64') or (Expected='nativeint')) then Cost:=1
    else if (Actual='integer') and (Expected='double') then Cost:=2
    else if (Actual='string') and (Expected='ansistring') then Cost:=1 else Exit(MaxInt);
   end;Inc(Result,Cost);
  end;
 end;
begin
 Result:=nil;Reason:='';Query:='';if not Assigned(Parser) or (Source='') then Exit;
 Position:=EnsureRange(Position,0,Length(Source));First:=Position;Last:=Position+1;
 while (First>0) and Identifier(Source[First]) do Dec(First);while (Last<=Length(Source)) and Identifier(Source[Last]) do Inc(Last);
 Query:=Copy(Source,First+1,Last-First-1);if Query='' then Exit;
 Owner:='';Member:=Query;var Dot:=LastDelimiter('.',Query);if Dot>0 then begin Owner:=Copy(Query,1,Dot-1);Member:=Copy(Query,Dot+1,MaxInt);end;
 Candidates:=TList<TCodeElementInfo>.Create;Best:=TList<TCodeElementInfo>.Create;Args:=TList<string>.Create;
 try
  Receiver:=Owner;if Owner<>'' then begin
   Receiver:=ExpressionType(Owner);if Receiver='' then for var E in Symbols do if (E.Kind in [dekClass,dekInterface,dekRecord,dekType]) and (TypeMatches(E.CanonicalName,Owner) or TypeMatches(E.FullName,Owner)) then begin Receiver:=E.FullName;Break;end;
   if Receiver='' then begin Reason:='The receiver type is unknown; choose a declaration explicitly.';Exit;end;
  end;
  var OwnerNames:=Owners(Receiver);
  for var E in Symbols do if SameText(E.Name,Member) then begin
   if Owner='' then Candidates.Add(E) else for var OwnerName in OwnerNames do if TypeMatches(E.QualifiedParent,OwnerName) then begin Candidates.Add(E);Break;end;
  end;
  OpenAt:=Last;while (OpenAt<=Length(Source)) and Source[OpenAt].IsWhiteSpace do Inc(OpenAt);
  HasCall:=(OpenAt<=Length(Source)) and (Source[OpenAt]='(');InString:=False;Depth:=0;Angle:=0;
  if HasCall then begin
   var Part:='';var I:=OpenAt+1;while I<=Length(Source) do begin var C:=Source[I];
    if C=#39 then begin Part:=Part+C;if InString and (I<Length(Source)) and (Source[I+1]=#39) then begin Part:=Part+#39;Inc(I,2);Continue;end;InString:=not InString;Inc(I);Continue;end;
    if not InString then begin
     if (C='{') or ((C='/') and (I<Length(Source)) and (Source[I+1]='/')) or ((C='(') and (I<Length(Source)) and (Source[I+1]='*')) then begin HasCall:=False;Reason:='Arguments contain comments; overloads are shown without guessing.';Break;end;
     if (C=')') and (Depth=0) and (Angle=0) then begin if (Trim(Part)<>'') or (Args.Count>0) then Args.Add(Trim(Part));Break;end;
     if CharInSet(C,['(','[']) then Inc(Depth) else if CharInSet(C,[')',']']) then Dec(Depth);
     if C='<' then Inc(Angle) else if C='>' then Dec(Angle);
     if (C=',') and (Depth=0) and (Angle=0) then begin Args.Add(Trim(Part));Part:='';Inc(I);Continue;end;
    end;Part:=Part+C;Inc(I);
   end;
   if I>Length(Source) then begin HasCall:=False;Reason:='The argument list is incomplete; overloads are shown without guessing.';end;
  end;
  BestScore:=MaxInt;for var E in Candidates do begin var Value:=Score(E);if Value=MaxInt then Continue;if Value<BestScore then begin Best.Clear;BestScore:=Value;end;if Value=BestScore then Best.Add(E);end;
  if (BestScore>=10) and (BestScore<MaxInt) then Reason:='Argument types are incomplete; verify the declaration before navigating.';
  if Best.Count>1 then Reason:='Several declarations match this context; choose an overload.';Result:=Best.ToArray;
 finally Args.Free;Best.Free;Candidates.Free;end;
end;
end.
