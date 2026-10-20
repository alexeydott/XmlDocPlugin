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
 end;
implementation
uses System.SysUtils,XmlDoc.Parser,XmlDoc.Consts,XmlDoc.Expressions;
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
initialization
 TDUnitX.RegisterTestFixture(TDocQuickScopeTests);
end.
