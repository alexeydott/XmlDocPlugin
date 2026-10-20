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
initialization
 TDUnitX.RegisterTestFixture(TDocQuickScopeTests);
end.
