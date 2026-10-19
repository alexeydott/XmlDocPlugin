unit TestDocReview;
interface
uses DUnitX.TestFramework;
type
 [TestFixture] TDocReviewTests=class
 public
  [Test] procedure QualifiedReceiversIgnoreTrivia;
  [Test] procedure UncertainGenericKeepsBothCandidates;
  [Test] procedure PlaceholderReadinessAndThresholds;
  [Test] procedure FreshValidationScope;
 end;
implementation
uses System.IOUtils,XmlDoc.ProjectIndex,System.SysUtils,System.Generics.Collections,XmlDoc.Parser,XmlDoc.Consts,XmlDoc.Expressions,
 XmlDoc.HelpGen.Diagnostics,XmlDoc.Model,XmlDoc.StubGen,XmlDoc.Documentation,XmlDoc.HelpGen.Types,XmlDoc.HelpGen.Coverage;
procedure TDocReviewTests.QualifiedReceiversIgnoreTrivia;
var P:TDocParser;Symbols:TArray<TCodeElementInfo>;Source,Query,Reason:string;Matches:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  P.ParseSource('unit UnitA; interface type TWorker<T>=class procedure Run(Value:AnsiString); end; implementation end.','UnitA.pas');Symbols:=P.GetAllElements;
  P.ParseSource('unit UnitB; interface type TWorker<T>=class procedure Run(Value:string); end; implementation end.','UnitB.pas');Symbols:=Symbols+P.GetAllElements;
  for var BeforeDot in ['', ' ', #9, #13#10, '{ comment > ) }', '(* comment . *)', '// comment'+#13#10] do
   for var AfterDot in ['', ' ', #9, #13#10, '{ comment }', '(* comment *)'] do begin
    Source:='unit Consumer; interface implementation procedure Test; begin UnitA.TWorker<Integer>'+BeforeDot+'.'+AfterDot+'Run(''text''); end; end.';
    P.ParseSource(Source,'Consumer.pas');Matches:=ResolveDocumentationExpression(P,Source,Pos('Run(',Source)+1,1,Symbols,Query,Reason);
    Assert.AreEqual<NativeInt>(1,Length(Matches),BeforeDot+'/'+AfterDot+': '+Reason);Assert.AreEqual('UnitA',Matches[0].UnitName);Assert.AreEqual('',Reason);
   end;
  for var Trivia in ['', ' ', #13#10, '{ comment }', '(* comment *)', '// comment'+#13#10] do begin
   Source:='unit Consumer; interface implementation procedure Test; begin GetWorker()'+Trivia+'.Run(''text''); end; end.';
   P.ParseSource(Source,'Consumer.pas');Matches:=ResolveDocumentationExpression(P,Source,Pos('Run(',Source)+1,1,Symbols,Query,Reason);
   Assert.AreEqual<NativeInt>(0,Length(Matches),'Unsupported receivers must never select a foreign method');Assert.IsTrue(Reason<>'');
  end;
 finally P.Free;end;
end;
procedure TDocReviewTests.UncertainGenericKeepsBothCandidates;
var P:TDocParser;Source,Query,Reason:string;Matches:TArray<TCodeElementInfo>;HasGeneric,HasConcrete:Boolean;
begin
 P:=TDocParser.Create;
 try
  Source:='unit Calls; interface type TWorker=class procedure Put<T>(Value:T); overload; procedure Put(Value:Int64); overload; end; implementation procedure Test(Obj:TWorker); begin Obj.Put(123); end; end.';
  P.ParseSource(Source,'Calls.pas');Matches:=ResolveDocumentationExpression(P,Source,Pos('Obj.Put',Source)+6,1,P.GetAllElements,Query,Reason);
  Assert.AreEqual<NativeInt>(2,Length(Matches));HasGeneric:=False;HasConcrete:=False;
  for var E in Matches do begin HasGeneric:=HasGeneric or (Length(E.GenericParams)>0);HasConcrete:=HasConcrete or SameText(E.Params[0].TypeName,'Int64');end;
  Assert.IsTrue(HasGeneric and HasConcrete);Assert.IsTrue(Reason<>'');
 finally P.Free;end;
end;
procedure TDocReviewTests.PlaceholderReadinessAndThresholds;
var E:TCodeElementInfo;M:TXmlDocModel;Units:TObjectList<TUnitDocInfo>;U:TUnitDocInfo;T:TTypeDocInfo;Coverage:TDocCoverageReport;Stats:TCoverageStats;
begin
 for var Marker in CDefaultPlaceholderMarkers.Split([#10]) do begin
  Assert.IsFalse(TDocumentation.Meaningful('  '+Marker+' description'),'Built-in marker '+Marker);
  Assert.IsFalse(TDocumentation.Meaningful('<summary>'+Marker+' description</summary>'),'XML marker '+Marker);
 end;
 Assert.IsFalse(TDocumentation.Meaningful('[draft].* description','TODO: ','[draft].*'));
 Assert.IsTrue(TDocumentation.Meaningful('A [draft].* example.','TODO: ','[draft].*'));
 Assert.IsTrue(TDocumentation.Meaningful('FIXME: complete','TODO: ',''),'Custom list can remove built-in markers');
 Assert.IsFalse(TDocumentation.Meaningful('TODO: unfinished','TODO: ',''),'Legacy TODO is always recognized');
 E:=Default(TCodeElementInfo);E.Kind:=dekClass;E.Name:='TWidget';E.UnitName:='Widgets';E.FullName:='TWidget';
 for var Prefix in ['TODO: ','FIXME: ','Описание: ','待补充：','[draft].* ',''] do begin
  M:=TDocStubGenerator.GenerateStub(E,Prefix,True);Units:=TObjectList<TUnitDocInfo>.Create(True);Coverage:=TDocCoverageReport.Create;
  try
   Assert.IsFalse(TDocumentation.Meaningful(M.Summary,Prefix));
   var Found:=False;for var Issue in TDocumentation.Analyze(E,M,nil,'',Prefix) do if Issue.Code='XD008' then Found:=True;
   Assert.IsTrue(Found,'Generated stub must stay unfinished for prefix '+Prefix);
   U:=TUnitDocInfo.Create;U.UnitName:='Widgets';U.UnitDoc.Summary:='Widget declarations.';U.UnitElement.Kind:=dekUnit;Units.Add(U);
   T:=TTypeDocInfo.Create;T.Name:='TWidget';T.Kind:=dekClass;T.CodeElement:=E;T.Doc.Assign(M);U.Types.Add(T);
   var Report:=TDocumentationReport.Create;var Baseline:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString+'.json');
   try Report.Analyze(Units,'',Prefix);Report.SaveBaseline(Baseline);
    Assert.IsTrue(TFile.ReadAllText(Baseline).Contains('Unfinished TODO documentation'),'Existing XD008 baseline identity must remain stable');
    Assert.AreEqual(0,Report.NewIssueCount(Baseline));
   finally Report.Free;if TFile.Exists(Baseline) then TFile.Delete(Baseline);end;
   Coverage.PlaceholderPrefix:=Prefix;Stats:=Coverage.Analyze(Units);
   try
    Assert.AreEqual(100.0,Stats.CoveragePercent,0.001);Assert.AreEqual(50.0,Stats.ReadyPercent,0.001);
    Assert.AreEqual('',TDocCoverageReport.ThresholdFailure(Stats,100,0));
    Assert.IsTrue(TDocCoverageReport.ThresholdFailure(Stats,100,100).Contains('Ready documentation'));
   finally Stats.ByKind.Free;Stats.ByUnit.Free;Stats.ByVisibility.Free;end;
   Coverage.PlaceholderPrefix:='OTHER: ';Coverage.PlaceholderMarkers:=Prefix;Stats:=Coverage.Analyze(Units);
   try Assert.AreEqual(50.0,Stats.ReadyPercent,0.001,'Recognized list is independent of generation prefix');
   finally Stats.ByKind.Free;Stats.ByUnit.Free;Stats.ByVisibility.Free;end;
   var CustomReport:=TDocumentationReport.Create;
   try CustomReport.Analyze(Units,'','OTHER: ',Prefix);var MarkerFound:=False;
    for var Issue in CustomReport.Issues do if Issue.Code='XD008' then MarkerFound:=True;
    Assert.IsTrue(MarkerFound,'Diagnostics must use the recognized list independently');
   finally CustomReport.Free;end;
  finally Coverage.Free;Units.Free;M.Free;end;
 end;
end;
procedure TDocReviewTests.FreshValidationScope;
var P:TDocParser;Index:TDocumentationIndex;Pass:TIndexValidation;Root,FileName,IncludeName,Source:string;Snapshot:TSourceSnapshot;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString);ForceDirectories(Root);P:=TDocParser.Create;Index:=TDocumentationIndex.Create;
 try
  FileName:=TPath.Combine(Root,'Caller.pas');IncludeName:=TPath.Combine(Root,'Features.inc');Source:='unit Caller; interface {$I Features.inc} implementation end.';
  TFile.WriteAllText(IncludeName,'type TOriginal=class end;');Index.Update(FileName,Source,P);
  Pass:=TIndexValidation.Create(nil);try Assert.IsTrue(Index.IsCurrent(FileName,Source,P,Pass));Assert.IsFalse(Index.IsCurrent(FileName,Source+' ',P,Pass));finally Pass.Free;end;
  TFile.WriteAllText(IncludeName,'type TChanged=class end;');
  Pass:=TIndexValidation.Create(nil);try Assert.IsFalse(Index.IsCurrent(FileName,Source,P,Pass),'A fresh publication check must not reuse an earlier dependency hash');finally Pass.Free;end;
  Snapshot.FileName:=IncludeName;Snapshot.Source:='type TOriginal=class end;';
  Pass:=TIndexValidation.Create([Snapshot]);try Assert.IsTrue(Index.IsCurrent(FileName,Source,P,Pass),'Live buffers must override the disk dependency');finally Pass.Free;end;
  P.Defines:=P.Defines+['CHANGED_CONTEXT'];
  Pass:=TIndexValidation.Create([Snapshot]);try Assert.IsFalse(Index.IsCurrent(FileName,Source,P,Pass),'Each pass must capture the current project context');finally Pass.Free;end;
 finally Index.Free;P.Free;TDirectory.Delete(Root,True);end;
end;
initialization
 TDUnitX.RegisterTestFixture(TDocReviewTests);
end.
