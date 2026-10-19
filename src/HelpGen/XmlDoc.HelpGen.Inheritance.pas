unit XmlDoc.HelpGen.Inheritance;
interface
uses System.SysUtils,System.Generics.Collections,XmlDoc.HelpGen.Types;
type
 TInheritanceResolver=class
 private
  FOnCheck:TProc;
  FTypes:TDictionary<string,TTypeDocInfo>;
  FVisiting,FDone:TDictionary<TTypeDocInfo,Boolean>;
  function FindType(const Name,Context:string):TTypeDocInfo;
  procedure Resolve(Typ:TTypeDocInfo);
 public
  property OnCheck:TProc read FOnCheck write FOnCheck;
  constructor Create;
  destructor Destroy;override;
  procedure Apply(Units:TObjectList<TUnitDocInfo>);
 end;
implementation
uses System.RegularExpressions,XmlDoc.Consts,XmlDoc.Model,XmlDoc.XmlFragments;
constructor TInheritanceResolver.Create;
begin inherited;FTypes:=TDictionary<string,TTypeDocInfo>.Create;FVisiting:=TDictionary<TTypeDocInfo,Boolean>.Create;FDone:=TDictionary<TTypeDocInfo,Boolean>.Create;end;
destructor TInheritanceResolver.Destroy;
begin FDone.Free;FVisiting.Free;FTypes.Free;inherited;end;
function BareType(const Name:string):string;
var P:Integer;
begin Result:=Name;P:=Pos('<',Result);if P>0 then Result:=Copy(Result,1,P-1);end;
function GenericArguments(const Name:string):TArray<string>;
var Start,I,Depth:Integer;Part:string;Items:TList<string>;
begin
 Result:=nil;Start:=Pos('<',Name);if Start=0 then Exit;Items:=TList<string>.Create;
 try Depth:=0;Part:='';
  for I:=Start+1 to Length(Name) do begin
   if (Name[I]='>') and (Depth=0) then begin Items.Add(Trim(Part));Break;end;
   if (Name[I]=',') and (Depth=0) then begin Items.Add(Trim(Part));Part:='';Continue;end;
   if CharInSet(Name[I],['<','(','[']) then Inc(Depth) else if CharInSet(Name[I],['>',')',']']) then Dec(Depth);
   Part:=Part+Name[I];
  end;Result:=Items.ToArray;
 finally Items.Free;end;
end;
function TInheritanceResolver.FindType(const Name,Context:string):TTypeDocInfo;
var Pair:TPair<string,TTypeDocInfo>;Key:string;
begin
 Key:=LowerCase(BareType(Name))+'`'+IntToStr(Length(GenericArguments(Name)));if FTypes.TryGetValue(Key,Result) then Exit;
 if (Context<>'') and FTypes.TryGetValue(LowerCase(Context)+'.'+Key,Result) then Exit;
 Result:=nil;
 for Pair in FTypes do if Pair.Key.EndsWith('.'+Key) then begin if Assigned(Result) and (Result<>Pair.Value) then Exit(nil);Result:=Pair.Value;end;
end;
function SubstituteGenerics(const Text:string;const Names,Args:TArray<string>):string;
var Matches:TMatchCollection;I,J:Integer;M:TMatch;
begin
 Result:=Text;Matches:=TRegEx.Matches(Text,'[\p{L}_][\p{L}\p{N}_]*');
 for I:=Matches.Count-1 downto 0 do begin M:=Matches[I];
  for J:=0 to High(Names) do if (J<Length(Args)) and SameText(M.Value,Names[J]) then begin
   Result:=Copy(Result,1,M.Index-1)+Args[J]+Copy(Result,M.Index+M.Length,MaxInt);Break;
  end;
 end;
end;
procedure TInheritanceResolver.Resolve(Typ:TTypeDocInfo);
var Bases:TList<TTypeDocInfo>;Base:TTypeDocInfo;Member,Source,Matched:TElementDocInfo;
 Name,Explicit,Xml,Ancestor:string;Sources:TList<TElementDocInfo>;CopyModel:TXmlDocModel;I,Count:Integer;Match:TMatch;Mappings:TArray<string>;
 function Compatible(A,B:TElementDocInfo;Parent:TTypeDocInfo;const Constructed:string):Boolean;
 var J,K:Integer;L,R:string;Args:TArray<string>;Start:Integer;
 begin
  Result:=False;if not SameText(A.Name,B.Name) or (A.Kind<>B.Kind) then Exit;
  if Length(A.CodeElement.Params)<>Length(B.CodeElement.Params) then Exit;
  if (Parent.Kind<>dekInterface) and (A.Kind=dekMethod) and (A.CodeElement.Name<>'') and
   (Explicit='') and (A.CodeElement.IsReintroduce or not SameText(A.CodeElement.MethodBinding,'override')) then Exit;
  Args:=GenericArguments(Constructed);
  L:=A.CodeElement.ReturnType;R:=B.CodeElement.ReturnType;
  R:=SubstituteGenerics(R,Parent.CodeElement.GenericParams,Args);
  if not SameText(L,R) then Exit;
  for J:=0 to High(A.CodeElement.Params) do begin
   L:=A.CodeElement.Params[J].TypeName;R:=B.CodeElement.Params[J].TypeName;
   R:=SubstituteGenerics(R,Parent.CodeElement.GenericParams,Args);
   if not SameText(L,R) or (A.CodeElement.Params[J].IsVar<>B.CodeElement.Params[J].IsVar) or (A.CodeElement.Params[J].IsOut<>B.CodeElement.Params[J].IsOut) or (A.CodeElement.Params[J].IsConst<>B.CodeElement.Params[J].IsConst) then Exit;
  end;
  Result:=Length(A.CodeElement.GenericParams)=Length(B.CodeElement.GenericParams);
 end;
 procedure FindSources(Parent:TTypeDocInfo;const Constructed:string;Visited:TList<string>);
 var Candidate:TElementDocInfo;Found:Boolean;ParentName,VisitKey,NextName:string;AncestorType:TTypeDocInfo;Args:TArray<string>;
 begin
  if Assigned(FOnCheck) then FOnCheck();
  VisitKey:=Parent.FullName+'|'+Constructed;if Visited.Contains(VisitKey) then Exit;Visited.Add(VisitKey);Found:=False;
  for Candidate in Parent.Members do begin
   if Assigned(FOnCheck) then FOnCheck();
   if Compatible(Member,Candidate,Parent,Constructed) then begin
   Found:=True;
   if ((Explicit='') or SameText(Explicit,Candidate.CodeElement.SymbolId) or SameText(Explicit,Candidate.FullName) or SameText(Explicit,Parent.Name)) and not Candidate.Doc.IsEmpty and not Sources.Contains(Candidate) then Sources.Add(Candidate);
  end;
  end;
  if not Found then for ParentName in TArray<string>.Create(Parent.Ancestor)+Parent.Implements do if ParentName<>'' then begin
   AncestorType:=FindType(ParentName,Parent.CodeElement.UnitName);if Assigned(AncestorType) then begin
    NextName:=ParentName;Args:=GenericArguments(Constructed);
    NextName:=SubstituteGenerics(NextName,Parent.CodeElement.GenericParams,Args);
    FindSources(AncestorType,NextName,Visited);
   end;
  end;
 end;
begin
 if Assigned(FOnCheck) then FOnCheck();
 if FDone.ContainsKey(Typ) then Exit;
 if FVisiting.ContainsKey(Typ) then raise Exception.Create('Documentation inheritance cycle: '+Typ.FullName);
 FVisiting.Add(Typ,True);Bases:=TList<TTypeDocInfo>.Create;Sources:=TList<TElementDocInfo>.Create;
 try
  for Name in TArray<string>.Create(Typ.Ancestor)+Typ.Implements do if Name<>'' then begin
   Base:=FindType(Name,Typ.CodeElement.UnitName);if Assigned(Base) and not Bases.Contains(Base) then begin Resolve(Base);Bases.Add(Base);end;
  end;
  Explicit:='';Match:=TRegEx.Match(Typ.Doc.ToXml,'(?i)<inheritdoc\b[^>]*\bcref=["'']([^"'']+)["'']');if Match.Success then Explicit:=Match.Groups[1].Value;
  var TypeSources:=TList<TTypeDocInfo>.Create;
  try
   for Base in Bases do if not Base.Doc.IsEmpty and ((Explicit='') or SameText(Explicit,Base.Name) or SameText(Explicit,Base.FullName)) then TypeSources.Add(Base);
   if TypeSources.Count=1 then begin
    CopyModel:=TXmlDocModel.Create;
    try CopyModel.Assign(TypeSources[0].Doc);
     for var J:=CopyModel.TypeParams.Count-1 downto 0 do begin
      var Keep:=False;for var G in Typ.CodeElement.GenericParams do if SameText(G,CopyModel.TypeParams[J].Name) then Keep:=True;
      if not Keep then CopyModel.TypeParams.Delete(J);
     end;
     Typ.Doc.MergeMissing(CopyModel,TypeSources[0].FullName);
    finally CopyModel.Free;end;
   end else if TypeSources.Count>1 then Typ.Doc.InheritedFrom:='Ambiguous inheritance: choose a source with inheritdoc cref';
  finally TypeSources.Free;end;
  for Member in Typ.Members do begin
   if Assigned(FOnCheck) then FOnCheck();
   Sources.Clear;Explicit:='';Match:=TRegEx.Match(Member.Doc.ToXml,'(?i)<inheritdoc\b[^>]*\bcref=["'']([^"'']+)["'']');
   if Match.Success then Explicit:=Match.Groups[1].Value;
   var Visited:=TList<string>.Create;
   try for Name in TArray<string>.Create(Typ.Ancestor)+Typ.Implements do begin
    Base:=FindType(Name,Typ.CodeElement.UnitName);if Assigned(Base) then FindSources(Base,Name,Visited);
   end;finally Visited.Free;end;
   if Sources.Count=1 then begin
    Source:=Sources[0];CopyModel:=TXmlDocModel.Create;
    try
     Xml:=Source.Doc.ToXml;
     SetLength(Mappings,Length(Source.CodeElement.Params));
     for I:=0 to High(Mappings) do Mappings[I]:=Source.CodeElement.Params[I].Name+'='+Member.CodeElement.Params[I].Name;
     if Length(Mappings)>0 then Xml:=RenameDocNames(Xml,Mappings);
     CopyModel.LoadFromXml(Xml);Member.Doc.MergeMissing(CopyModel,Source.FullName);
    finally CopyModel.Free;end;
   end else if Sources.Count>1 then Member.Doc.InheritedFrom:='Ambiguous inheritance: choose a source with inheritdoc cref';
  end;
  for Base in Typ.NestedTypes do Resolve(Base);
  FDone.Add(Typ,True);
 finally Sources.Free;Bases.Free;FVisiting.Remove(Typ);end;
end;
procedure TInheritanceResolver.Apply(Units:TObjectList<TUnitDocInfo>);
var U:TUnitDocInfo;T:TTypeDocInfo;
 procedure AddType(Typ:TTypeDocInfo);
 var Nested:TTypeDocInfo;
 begin FTypes.AddOrSetValue(LowerCase(Typ.FullName)+'`'+IntToStr(Length(Typ.CodeElement.GenericParams)),Typ);for Nested in Typ.NestedTypes do AddType(Nested);end;
begin
 FTypes.Clear;FDone.Clear;FVisiting.Clear;
 for U in Units do for T in U.Types do AddType(T);
 for U in Units do for T in U.Types do Resolve(T);
end;
end.
