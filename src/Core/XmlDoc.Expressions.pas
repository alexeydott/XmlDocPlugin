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
function DeclarationTypeKey(const Name:string):string;
var Depth,Count:Integer;
begin
 Result:='';Depth:=0;Count:=0;
 for var C in Name do begin
  if C='<' then begin if Depth=0 then Count:=1;Inc(Depth);end
  else if C='>' then begin Dec(Depth);if Depth=0 then Result:=Result+'`'+IntToStr(Count);end
  else if (C=',') and (Depth=1) then Inc(Count)
  else if (Depth=0) and not C.IsWhiteSpace then Result:=Result+LowerCase(C);
 end;
end;
function ResolveDocumentationExpression(Parser:TDocParser;const Source:string;Position,Line:Integer;
 const Symbols:TArray<TCodeElementInfo>;out Query,Reason:string):TArray<TCodeElementInfo>;
var First,Last,OpenAt,Depth,Angle,BestScore:Integer;Owner,Member,Receiver:string;Args:TList<string>;Candidates,Best:TList<TCodeElementInfo>;HasCall,InString,UncertainOwners,UncertainCandidate:Boolean;Bindings:TDictionary<string,string>;
 function ExpressionType(const Expression:string):string;
 var Text:string;
 begin
  Text:=Trim(Expression);Result:='';if Text='' then Exit;
  if TRegEx.IsMatch(Text,'^[+-]?(?:\d+|\$[0-9a-fA-F]+)$') then Exit('Integer');
  if TRegEx.IsMatch(Text,'^[+-]?\d+\.\d+(?:[Ee][+-]?\d+)?$') then Exit('Double');
  if (Text[1]=#39) and (Text[Length(Text)]=#39) then Exit('string');
  if SameText(Text,'True') or SameText(Text,'False') then Exit('Boolean');Result:=Parser.BindingType(Text,Line);
 end;
 function TypeDeclarationName(const E:TCodeElementInfo):string;
 begin Result:=E.FullName;if Length(E.GenericParams)>0 then Result:=Result+'<'+string.Join(',',E.GenericParams)+'>';end;
 function TypeIdentity(const E:TCodeElementInfo):string;
 begin Result:=LowerCase(E.FileName)+#0+DeclarationTypeKey(E.UnitName+'.'+TypeDeclarationName(E));end;
 function FindType(const Name,UnitScope:string;out Found:TCodeElementInfo):Boolean;
 var Matches:TList<TCodeElementInfo>;
 begin
  Result:=False;Matches:=TList<TCodeElementInfo>.Create;
  try
   // Qualified references must retain their module and generic declaration identity.
   for var E in Symbols do if (E.Kind in [dekClass,dekInterface,dekRecord,dekType]) and (DeclarationTypeKey(E.UnitName+'.'+TypeDeclarationName(E))=DeclarationTypeKey(Name)) then Matches.Add(E);
   if Matches.Count=0 then for var E in Symbols do if (E.Kind in [dekClass,dekInterface,dekRecord,dekType]) and (DeclarationTypeKey(TypeDeclarationName(E))=DeclarationTypeKey(Name)) and SameText(E.UnitName,UnitScope) then Matches.Add(E);
   if Matches.Count=0 then for var E in Symbols do if (E.Kind in [dekClass,dekInterface,dekRecord,dekType]) and (DeclarationTypeKey(TypeDeclarationName(E))=DeclarationTypeKey(Name)) then Matches.Add(E);
   if Matches.Count=1 then begin Found:=Matches[0];Result:=True;end;
  finally Matches.Free;end;
 end;
 function Substitute(const Text,OwnerId:string):string;
 var I,Start:Integer;Token,Replacement:string;
 begin
  Result:='';I:=1;
  while I<=Length(Text) do begin
   if Text[I].IsLetter or (Text[I]='_') then begin
    Start:=I;Inc(I);while (I<=Length(Text)) and (Text[I].IsLetterOrDigit or (Text[I]='_')) do Inc(I);
    Token:=Copy(Text,Start,I-Start);if Bindings.TryGetValue(OwnerId+#0+LowerCase(Token),Replacement) then Result:=Result+Replacement else Result:=Result+Token;
   end else begin Result:=Result+Text[I];Inc(I);end;
  end;
 end;
 function Owners(const TypeName:string):TArray<string>;
 var Pending:TList<TPair<TCodeElementInfo,string>>;Seen:TList<string>;Current,Parent:TCodeElementInfo;Scope,Concrete,Id,Part:string;Parts:TList<string>;Nesting,Start:Integer;
 begin
  Pending:=TList<TPair<TCodeElementInfo,string>>.Create;Seen:=TList<string>.Create;Parts:=TList<string>.Create;
  try
   Scope:='';for var E in Parser.GetAllElements do if E.Kind=dekUnit then begin Scope:=E.UnitName;Break;end;
   if FindType(TypeName,Scope,Current) then Pending.Add(TPair<TCodeElementInfo,string>.Create(Current,TypeName));
   while (Pending.Count>0) and (Seen.Count<128) do begin
    Current:=Pending[0].Key;Concrete:=Pending[0].Value;Pending.Delete(0);Id:=TypeIdentity(Current);
    if Seen.Contains(Id) then begin UncertainOwners:=True;Continue;end;Seen.Add(Id);
    Parts.Clear;Nesting:=0;Part:='';Start:=0;
    for var I:=1 to Length(Concrete) do begin
     var C:=Concrete[I];
     if C='<' then begin Inc(Nesting);if Nesting=1 then begin Start:=I;Continue;end;end;
     if C='>' then begin Dec(Nesting);if Nesting=0 then begin Parts.Add(Trim(Part));Part:='';Continue;end;end;
     if (C=',') and (Nesting=1) then begin Parts.Add(Trim(Part));Part:='';Continue;end;
     if Nesting>0 then Part:=Part+C;
    end;
    if (Nesting<>0) or ((Start>0) and (Length(Current.GenericParams)<>Parts.Count)) then UncertainOwners:=True;
    for var I:=0 to Length(Current.GenericParams)-1 do begin
     if I<Parts.Count then Part:=Parts[I] else begin Part:=Current.GenericParams[I];UncertainOwners:=True;end;
     Bindings.AddOrSetValue(Id+#0+LowerCase(Current.GenericParams[I]),Part);
    end;
    if Current.Ancestor<>'' then begin Concrete:=Substitute(Current.Ancestor,Id);if FindType(Concrete,Current.UnitName,Parent) then Pending.Add(TPair<TCodeElementInfo,string>.Create(Parent,Concrete)) else UncertainOwners:=True;end;
    for var Name in Current.Implements do begin Concrete:=Substitute(Name,Id);if FindType(Concrete,Current.UnitName,Parent) then Pending.Add(TPair<TCodeElementInfo,string>.Create(Parent,Concrete)) else UncertainOwners:=True;end;
   end;Result:=Seen.ToArray;
  finally Parts.Free;Seen.Free;Pending.Free;end;
 end;
 function Score(const E:TCodeElementInfo):Integer;
 var Required,Cost:Integer;Actual,Expected:string;
 begin
  Result:=0;if not HasCall then Exit;Required:=0;for var P in E.Params do if not P.HasDefault and (P.DefaultValue='') then Inc(Required);
  if (Args.Count<Required) or (Args.Count>Length(E.Params)) then Exit(MaxInt);
  for var I:=0 to Args.Count-1 do begin
   Actual:=SimpleType(ExpressionType(Args[I]));Expected:=SimpleType(Substitute(E.Params[I].TypeName,LowerCase(E.FileName)+#0+DeclarationTypeKey(E.UnitName+'.'+E.QualifiedParent)));Cost:=0;
   if Actual='' then Cost:=10 else if Actual<>Expected then begin
    if (Actual='integer') and ((Expected='int64') or (Expected='nativeint')) then Cost:=1
    else if (Actual='integer') and (Expected='double') then Cost:=2
    else if (Actual='string') and (Expected='ansistring') then Cost:=1
    else begin
     var Unknown:=UncertainOwners;for var Name in E.GenericParams do if TRegEx.IsMatch(Expected,'(?i)(?<![\p{L}\p{N}_])'+TRegEx.Escape(Name)+'(?![\p{L}\p{N}_])') then Unknown:=True;
     if Unknown then Cost:=10 else Exit(MaxInt);
    end;
   end;Inc(Result,Cost);
  end;
 end;
begin
 Result:=nil;Reason:='';Query:='';if not Assigned(Parser) or (Source='') then Exit;
 Position:=EnsureRange(Position,0,Length(Source));First:=Position;Last:=Position+1;UncertainOwners:=False;UncertainCandidate:=False;
 while (First>0) and Identifier(Source[First]) do Dec(First);while (Last<=Length(Source)) and Identifier(Source[Last]) do Inc(Last);
 // Include complete constructed type receivers when scanning backwards.
 while (First>0) and (Source[First]='>') do begin
  Angle:=1;Dec(First);
  while (First>0) and (Angle>0) do begin if Source[First]='>' then Inc(Angle) else if Source[First]='<' then Dec(Angle);Dec(First);end;
  if Angle<>0 then begin Reason:='The receiver expression is incomplete; choose a declaration explicitly.';Exit;end;
  while (First>0) and Identifier(Source[First]) do Dec(First);
 end;
 Query:=Copy(Source,First+1,Last-First-1);if Query='' then Exit;
 if (First>0) and CharInSet(Source[First],[')',']','^','>']) then begin Reason:='The receiver expression is unsupported; choose a declaration explicitly.';Exit;end;
 Owner:='';Member:=Query;var Dot:=LastDelimiter('.',Query);if Dot>0 then begin Owner:=Copy(Query,1,Dot-1);Member:=Copy(Query,Dot+1,MaxInt);end;
 Candidates:=TList<TCodeElementInfo>.Create;Best:=TList<TCodeElementInfo>.Create;Args:=TList<string>.Create;Bindings:=TDictionary<string,string>.Create;
 try
  Receiver:=Owner;if Owner<>'' then begin
   Receiver:=ExpressionType(Owner);if Receiver='' then Receiver:=Owner;
   if Receiver='' then begin Reason:='The receiver type is unknown; choose a declaration explicitly.';Exit;end;
  end;
  var OwnerNames:=Owners(Receiver);if (Owner<>'') and (Length(OwnerNames)=0) then begin Reason:='The receiver type is unknown or ambiguous; choose a declaration explicitly.';Exit;end;
  for var E in Symbols do if SameText(E.Name,Member) then begin
   if Owner='' then Candidates.Add(E) else for var OwnerName in OwnerNames do if SameText(LowerCase(E.FileName)+#0+DeclarationTypeKey(E.UnitName+'.'+E.QualifiedParent),OwnerName) then begin Candidates.Add(E);Break;end;
  end;
  OpenAt:=Last;while (OpenAt<=Length(Source)) and Source[OpenAt].IsWhiteSpace do Inc(OpenAt);
  if (OpenAt<=Length(Source)) and (Source[OpenAt]='<') then Reason:='Explicit method type arguments are not resolved; choose a declaration explicitly.';
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
  BestScore:=MaxInt;for var E in Candidates do begin var Value:=Score(E);if Value=MaxInt then Continue;if Value>=10 then UncertainCandidate:=True;if Value<BestScore then begin Best.Clear;BestScore:=Value;end;if Value=BestScore then Best.Add(E);end;
  if UncertainCandidate then Reason:='Argument types are incomplete; verify the declaration before navigating.';
  if UncertainOwners then Reason:='Generic receiver information is incomplete; choose a declaration explicitly.';
  if Best.Count>1 then Reason:='Several declarations match this context; choose an overload.';Result:=Best.ToArray;
 finally Bindings.Free;Args.Free;Best.Free;Candidates.Free;end;
end;
end.
