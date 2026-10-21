unit TestDocQuickScope;
interface
uses DUnitX.TestFramework;
type
 [TestFixture] TDocQuickScopeTests=class
 public
  [Test] procedure ImplicitSelfPrecedesOverloadRanking;
  [Test] procedure UnknownScopeKeepsForeignCandidates;
  [Test] procedure ComparisonOperatorsAreNotGenerics;
  [Test] procedure GenericReceiversRetainTrivia;
  [Test] procedure NestedProcedureShadowsImplicitSelf;
  [Test] procedure NumericLiteralOverloads;
  [Test] procedure SelfPrefersOverridingDeclaration;
  [Test] procedure NumericBoundariesAndFuzz;
  [Test] procedure DistinctStringOverloads;
  [Test] procedure InlineVariableShadowsWithinBlock;
  [Test] procedure AnonymousScopesAndConstants;
 end;
implementation
uses System.SysUtils,System.Generics.Collections,XmlDoc.Parser,XmlDoc.Consts,XmlDoc.Expressions,XmlDoc.ProjectIndex;
procedure TDocQuickScopeTests.ImplicitSelfPrecedesOverloadRanking;
var P:TDocParser;Source,Query,Reason:string;Found:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  Source:='unit Calls;'+sLineBreak+'interface'+sLineBreak+
   'type TLocalWorker=class procedure Run(Value:AnsiString); procedure Caller; end;'+sLineBreak+
   'TOtherWorker=class procedure Run(Value:string); end;'+sLineBreak+
   'implementation'+sLineBreak+'procedure TLocalWorker.Caller;'+sLineBreak+'begin'+sLineBreak+
   'Run(''text'');'+sLineBreak+'end;'+sLineBreak+'end.';
  P.ParseSource(Source,'Calls.pas');
  Found:=ResolveDocumentationExpression(P,Source,Pos('Run(''text'')',Source)+1,8,P.GetAllElements,Query,Reason);
  Assert.AreEqual<NativeInt>(1,Length(Found),Reason);
  Assert.AreEqual('TLocalWorker',Found[0].QualifiedParent);
  Assert.AreEqual('AnsiString',Found[0].Params[0].TypeName);
  Assert.AreEqual('',Reason);
 finally P.Free;end;
end;
procedure TDocQuickScopeTests.UnknownScopeKeepsForeignCandidates;
var P:TDocParser;Source,Query,Reason:string;Found:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  Source:='unit Calls; interface type TLocalWorker=class procedure Run(Value:AnsiString); end; '+
   'TOtherWorker=class procedure Run(Value:string); end; implementation procedure Test; begin Run(''text''); end; end.';
  P.ParseSource(Source,'Calls.pas');Found:=ResolveDocumentationExpression(P,Source,Pos('Run(''text'')',Source)+1,1,P.GetAllElements,Query,Reason);
  Assert.AreEqual<NativeInt>(2,Length(Found));Assert.IsTrue(Reason<>'');
 finally P.Free;end;
end;
procedure TDocQuickScopeTests.ComparisonOperatorsAreNotGenerics;
var P:TDocParser;Source,Query,Reason:string;Found:TArray<TCodeElementInfo>;Seed:Cardinal;
begin
 P:=TDocParser.Create;
 try
  Seed:=717;
  for var Round:=0 to 249 do begin
   Seed:=Seed*1664525+1013904223;
   var Operators:TArray<string>:=['<','<=','<>','>','>='];
   var Trivia:TArray<string>:= [' ',#9,'{ generic-looking <T> }','(* > *)',#13#10];
   Source:='unit Calls; interface type TWorker=class Count:Integer; end; implementation '+
    'procedure Test(Obj:TWorker;Limit:Integer); begin if Obj.Count'+Trivia[Seed mod 5]+Operators[Round mod 5]+' Limit then Exit; end; end.';
   P.ParseSource(Source,'Calls.pas');Found:=ResolveDocumentationExpression(P,Source,Pos('Obj.Count',Source)+6,1,P.GetAllElements,Query,Reason);
   Assert.AreEqual<NativeInt>(1,Length(Found),Source+': '+Reason);Assert.AreEqual('Count',Found[0].Name);Assert.AreEqual('',Reason);
  end;
 finally P.Free;end;
end;
procedure TDocQuickScopeTests.GenericReceiversRetainTrivia;
var P:TDocParser;Source,Query,Reason:string;Found,Symbols:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  P.ParseSource('unit Types; interface type TWorker<T>=class procedure Run(Value:AnsiString); end; implementation end.','Types.pas');Symbols:=P.GetAllElements;
  for var Trivia in [' ',#13#10,'{ < > }','(* > *)','// <'+#13#10] do begin
   Source:='unit Calls; interface implementation procedure Test; begin Types.TWorker'+Trivia+'<Integer>'+Trivia+'.Run(''text''); end; end.';
   P.ParseSource(Source,'Calls.pas');Found:=ResolveDocumentationExpression(P,Source,Pos('.Run',Source)+3,1,Symbols,Query,Reason);
   Assert.AreEqual<NativeInt>(1,Length(Found),Reason);Assert.AreEqual('Types',Found[0].UnitName);Assert.AreEqual('',Reason);
  end;
 finally P.Free;end;
end;
procedure TDocQuickScopeTests.NestedProcedureShadowsImplicitSelf;
var P:TDocParser;Source,Query,Reason:string;Found,Symbols:TArray<TCodeElementInfo>;Index:TDocumentationIndex;Catalog:TDictionary<string,TCodeElementInfo>;
begin
 P:=TDocParser.Create;Index:=TDocumentationIndex.Create;Catalog:=TDictionary<string,TCodeElementInfo>.Create;
 try
  Source:='unit Calls;'+sLineBreak+'interface'+sLineBreak+
   'type TWorker=class procedure Run(Value:Integer); procedure Caller; end; procedure Run(Value:string);'+sLineBreak+
   'implementation'+sLineBreak+'procedure TWorker.Run(Value:Integer); begin end; procedure Run(Value:string); begin end;'+sLineBreak+
   'procedure TWorker.Caller;'+sLineBreak+'procedure Run(Value:string); begin end;'+sLineBreak+
   'begin'+sLineBreak+'Run(''local'');'+sLineBreak+'Self.Run(1);'+sLineBreak+'end;'+sLineBreak+'end.';
  for var E in Index.Update('Calls.pas',Source,P) do if not Catalog.ContainsKey(E.FileName+#0+E.SymbolId) then Catalog.Add(E.FileName+#0+E.SymbolId,E);
  Symbols:=Catalog.Values.ToArray;
  Found:=ResolveDocumentationExpression(P,Source,Pos('Run(''local'')',Source)+1,9,Symbols,Query,Reason);
  Assert.AreEqual<NativeInt>(1,Length(Found),Reason);Assert.AreEqual('string',Found[0].Params[0].TypeName);Assert.AreEqual('TWorker.Caller',Found[0].QualifiedParent);for var E in Symbols do if (E.Name='Run') and (E.QualifiedParent='') then Assert.AreNotEqual(E.SymbolId,Found[0].SymbolId);
  Found:=ResolveDocumentationExpression(P,Source,Pos('Self.Run(1)',Source)+6,10,Symbols,Query,Reason);
  Assert.IsTrue(Length(Found)>0,Reason);for var E in Found do Assert.AreEqual('TWorker',E.QualifiedParent);
  Source:=Source.Replace('type TWorker=class','type TLocalProc=reference to procedure(Value:Integer); TWorker=class').Replace('procedure TWorker.Caller;'+sLineBreak+'procedure Run(Value:string); begin end;','procedure TWorker.Caller;'+sLineBreak+'var Run:TLocalProc;').Replace('Run(''local'');','Run(1);');
  P.ParseSource(Source,'Calls.pas');
  Found:=ResolveDocumentationExpression(P,Source,Pos('Run(1);',Source)+1,9,Symbols,Query,Reason);
  Assert.AreEqual<NativeInt>(0,Length(Found));Assert.IsTrue(Reason<>'');
 finally Catalog.Free;Index.Free;P.Free;end;
end;
procedure TDocQuickScopeTests.NumericLiteralOverloads;
var P:TDocParser;Source,Query,Reason,Expected:string;Found:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  for var Literal in ['1','+1','-1','$10','1.5','1e3','2147483648','-2147483649'] do begin
   if Literal.Contains('.') or Literal.Contains('e') then Expected:='Double'
   else if Literal.Contains('214748364') then Expected:='Int64' else Expected:='Integer';
   Source:='unit Calls;'+sLineBreak+'interface'+sLineBreak+
    'type TWorker=class procedure Run(Value:Integer);overload; procedure Run(Value:Int64);overload; procedure Run(Value:Double);overload; procedure Run(Value:string);overload; procedure Caller;end;'+sLineBreak+
    'implementation'+sLineBreak+'procedure TWorker.Caller;'+sLineBreak+'begin'+sLineBreak+'Self.Run('+Literal+');'+sLineBreak+'end;end.';
   P.ParseSource(Source,'Calls.pas');Found:=ResolveDocumentationExpression(P,Source,Pos('Self.Run(',Source)+6,7,P.GetAllElements,Query,Reason);
   Assert.AreEqual<NativeInt>(1,Length(Found),Literal+': '+Reason);Assert.AreEqual(Expected,Found[0].Params[0].TypeName,Literal);Assert.AreEqual('',Reason,Literal);
  end;
 finally P.Free;end;
end;
procedure TDocQuickScopeTests.SelfPrefersOverridingDeclaration;
var P:TDocParser;Source,Query,Reason:string;Found:TArray<TCodeElementInfo>;Index:TDocumentationIndex;Catalog:TDictionary<string,TCodeElementInfo>;
begin
 P:=TDocParser.Create;Index:=TDocumentationIndex.Create;Catalog:=TDictionary<string,TCodeElementInfo>.Create;
 try
  Source:='unit Calls;'+sLineBreak+'interface'+sLineBreak+
   'type IOperation=interface procedure Run(Value:Integer);end; TBase=class(TInterfacedObject) procedure Run(Value:Integer);virtual;end;'+sLineBreak+
   'TWorker=class(TBase,IOperation) procedure Run(Value:Integer);overload;override; procedure Run(Value:string);overload; procedure Caller;end;'+sLineBreak+
   'implementation'+sLineBreak+'procedure TWorker.Caller;'+sLineBreak+'begin'+sLineBreak+'Self.Run(1);'+sLineBreak+'end;end.';
  for var E in Index.Update('Calls.pas',Source,P) do if not Catalog.ContainsKey(E.FileName+#0+E.SymbolId) then Catalog.Add(E.FileName+#0+E.SymbolId,E);
  Found:=ResolveDocumentationExpression(P,Source,Pos('Self.Run(',Source)+6,8,Catalog.Values.ToArray,Query,Reason);
  Assert.AreEqual<NativeInt>(1,Length(Found),Reason);Assert.AreEqual('TWorker',Found[0].QualifiedParent);Assert.AreEqual('Integer',Found[0].Params[0].TypeName);Assert.AreEqual('',Reason);
 finally Catalog.Free;Index.Free;P.Free;end;
end;
procedure TDocQuickScopeTests.NumericBoundariesAndFuzz;
var P:TDocParser;Source,Literal,Expected,Query,Reason:string;Found:TArray<TCodeElementInfo>;Seed:Cardinal;
begin
 P:=TDocParser.Create;
 try
  Seed:=917;
  for var Round:=0 to 263 do begin
   Expected:='Integer';
   case Round of
    0:Literal:='2147483647';
    1:begin Literal:='2147483648';Expected:='Cardinal';end;
    2:begin Literal:='$FFFFFFFF';Expected:='Cardinal';end;
    3:begin Literal:='4294967296';Expected:='Int64';end;
    4:begin Literal:='9223372036854775807';Expected:='Int64';end;
    5:begin Literal:='$8000000000000000';Expected:='UInt64';end;
    6:begin Literal:='18446744073709551615';Expected:='UInt64';end;
    7:Literal:='-2147483648';
    8:begin Literal:='-2147483649';Expected:='Int64';end;
    9:begin Literal:='-9223372036854775808';Expected:='Int64';end;
    10:begin Literal:='1E+3';Expected:='Double';end;
    11:begin Literal:='-2e-3';Expected:='Double';end;
    12:begin Literal:='18446744073709551616';Expected:='';end;
    13:begin Literal:='1+2';Expected:='';end;
    else begin Seed:=Seed*1664525+1013904223;Literal:=IntToStr(Seed mod 100000);if Odd(Round) then Literal:='$'+IntToHex(Seed mod 100000,1);if Round mod 3=0 then Literal:='-'+Literal;end;
   end;
   Source:='unit Calls;'+sLineBreak+'interface'+sLineBreak+
    'type TWorker=class procedure Run(Value:Integer);overload;procedure Run(Value:Cardinal);overload;procedure Run(Value:Int64);overload;procedure Run(Value:UInt64);overload;procedure Run(Value:Double);overload;procedure Caller;end;'+sLineBreak+
    'implementation'+sLineBreak+'procedure TWorker.Caller;'+sLineBreak+'begin'+sLineBreak+'Self.Run('+Literal+');'+sLineBreak+'end;end.';
   P.ParseSource(Source,'Calls.pas');Found:=ResolveDocumentationExpression(P,Source,Pos('Self.Run(',Source)+6,7,P.GetAllElements,Query,Reason);
   if Expected='' then Assert.IsTrue(Reason<>'',Literal+' must not produce a false unique result')
   else begin Assert.AreEqual<NativeInt>(1,Length(Found),Literal+': '+Reason);Assert.AreEqual(Expected,Found[0].Params[0].TypeName,Literal);Assert.AreEqual('',Reason,Literal);end;
  end;
 finally P.Free;end;
end;
procedure TDocQuickScopeTests.DistinctStringOverloads;
var P:TDocParser;Source,Query,Reason,Expected:string;Found:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  for var ArgumentType in ['UnicodeString','WideString'] do begin
   Source:='unit Calls;'+sLineBreak+'interface'+sLineBreak+
    'type TBase=class procedure Run(Value:UnicodeString);overload;end;'+sLineBreak+
    'TWorker=class(TBase) procedure Run(Value:WideString);overload;procedure Caller(Value:'+ArgumentType+');end;'+sLineBreak+
    'implementation'+sLineBreak+'procedure TWorker.Caller(Value:'+ArgumentType+');'+sLineBreak+'begin'+sLineBreak+'Self.Run(Value);'+sLineBreak+'end;end.';
   P.ParseSource(Source,'Calls.pas');Found:=ResolveDocumentationExpression(P,Source,Pos('Self.Run(Value)',Source)+6,8,P.GetAllElements,Query,Reason);
   Assert.AreEqual<NativeInt>(1,Length(Found),Reason);if ArgumentType='UnicodeString' then Expected:='TBase' else Expected:='TWorker';
   Assert.AreEqual(Expected,Found[0].QualifiedParent);Assert.AreEqual(ArgumentType,Found[0].Params[0].TypeName);Assert.AreEqual('',Reason);
  end;
 finally P.Free;end;
end;
procedure TDocQuickScopeTests.InlineVariableShadowsWithinBlock;
var P:TDocParser;Source,Query,Reason,Call:string;Found:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  for var Scenario:=0 to 3 do begin
   Source:='unit Calls;'+sLineBreak+'interface'+sLineBreak+'type TLocalProc=reference to procedure(Value:Integer); TWorker=class procedure Run(Value:Integer);procedure Caller;end;'+sLineBreak+'implementation'+sLineBreak+'procedure TWorker.Caller;'+sLineBreak+'begin'+sLineBreak;
   if Scenario=0 then Source:=Source+'Run(1); // target'+sLineBreak;
   if Scenario=2 then Source:=Source+'begin'+sLineBreak;
   Source:=Source+'var Run:TLocalProc := procedure(Value:Integer) begin end;'+sLineBreak;
   if Scenario=2 then Source:=Source+'end;'+sLineBreak;
   if Scenario<>0 then begin if Scenario=3 then Call:='Self.Run(1)' else Call:='Run(1)';Source:=Source+Call+'; // target'+sLineBreak;end;
   Source:=Source+'end;end.';P.ParseSource(Source,'Calls.pas');var At:=Pos('// target',Source);var Line:=1;for var I:=1 to At do if Source[I]=#10 then Inc(Line);
   var Start:=At;while (Start>1) and (Source[Start-1]<>#10) do Dec(Start);Found:=ResolveDocumentationExpression(P,Source,Start+1,Line,P.GetAllElements,Query,Reason);
   if Scenario=1 then begin Assert.AreEqual<NativeInt>(0,Length(Found));Assert.IsTrue(Reason<>'');end
   else begin Assert.AreEqual<NativeInt>(1,Length(Found),IntToStr(Scenario)+Reason);Assert.AreEqual('TWorker',Found[0].QualifiedParent);Assert.AreEqual('',Reason);end;
  end;
 finally P.Free;end;
end;
procedure TDocQuickScopeTests.AnonymousScopesAndConstants;
var P:TDocParser;Source,Query,Reason,Body:string;Found:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  for var Round:=0 to 179 do begin
   var Scenario:=Round mod 9;
   Body:='Callback := procedure'+sLineBreak+'var Run:Integer;'+sLineBreak+'begin Run:=0; end;'+sLineBreak+'Run(1); // target';
   if Scenario=1 then Body:='Callback := procedure'+sLineBreak+'var Run:Integer;'+sLineBreak+'begin'+sLineBreak+' Run(1); // target'+sLineBreak+'end;';
   if Scenario=2 then Body:='Other := procedure(Run:Integer)'+sLineBreak+'begin'+sLineBreak+' Run(1); // target'+sLineBreak+'end;';
   if Scenario=3 then Body:='var Run:TAction;'+sLineBreak+'Callback := procedure'+sLineBreak+'begin'+sLineBreak+' Run(1); // target'+sLineBreak+'end;';
   if Scenario=4 then Body:='Callback := procedure'+sLineBreak+'var Run:Integer;'+sLineBreak+'begin'+sLineBreak+' Self.Run(1); // target'+sLineBreak+'end;';
   if Scenario=5 then Body:='const Run=42;'+sLineBreak+'Run(1); // target';
   if Scenario=6 then Body:='begin'+sLineBreak+' const Run=42;'+sLineBreak+'end;'+sLineBreak+'Run(1); // target';
   if Scenario=7 then Body:='Run(1); // target'+sLineBreak+'const Run=42;';
   if Scenario=8 then Body:='Other := procedure(Run:Integer) begin end;'+sLineBreak+'Run(1); // target';
   Body:=StringOfChar(' ',Round mod 5)+'{ scope Пример '+IntToStr(Round)+' }'+sLineBreak+Body.Replace(#10,#10+StringOfChar(' ',Round mod 5));
   if Odd(Round) then Body:=Body.Replace('Run','rUn');
   Source:='unit Calls;'+sLineBreak+'interface'+sLineBreak+'type TAction=reference to procedure; TIntAction=reference to procedure(Run:Integer); TWorker=class procedure Run(Value:Integer);procedure Caller;end;'+sLineBreak+'implementation'+sLineBreak+'procedure TWorker.Caller;'+sLineBreak+'var Callback:TAction;Other:TIntAction;'+sLineBreak+'begin'+sLineBreak+Body+sLineBreak+'end;end.';
   if Round mod 3=0 then Source:=Source.Replace(#13#10,#10);
   P.ParseSource(Source,'Calls.pas');var At:=Pos('// target',Source);var Line:=1;for var I:=1 to At do if Source[I]=#10 then Inc(Line);var Start:=At;while (Start>1) and (Source[Start-1]<>#10) do Dec(Start);
   var CallOffset:=LowerCase(Copy(Source,Start,At-Start)).IndexOf('run(');
   Assert.IsTrue(CallOffset>=0,IntToStr(Round));
   Found:=ResolveDocumentationExpression(P,Source,Start+CallOffset+1,Line,P.GetAllElements,Query,Reason);
   if Scenario in [1,2] then Assert.AreEqual('Integer',P.BindingType('Run',Line,At-Start),IntToStr(Round));
   if Scenario=3 then Assert.AreEqual('TAction',P.BindingType('Run',Line,At-Start),IntToStr(Round));
   if Scenario in [0,4,6,7,8] then begin Assert.AreEqual<NativeInt>(1,Length(Found),IntToStr(Scenario)+': '+Reason);Assert.AreEqual('TWorker',Found[0].QualifiedParent);Assert.AreEqual('',Reason);end
   else begin Assert.AreEqual<NativeInt>(0,Length(Found),IntToStr(Scenario));Assert.IsTrue(Reason<>'',IntToStr(Round));end;
  end;
 finally P.Free;end;
end;
initialization
 TDUnitX.RegisterTestFixture(TDocQuickScopeTests);
end.
