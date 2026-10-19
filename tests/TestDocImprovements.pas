unit TestDocImprovements;
interface
uses DUnitX.TestFramework;
type [TestFixture] TImprovementsTests=class
public
 [Test] procedure LanguagePacks;
 [Test] procedure SearchPathUnitReferences;
 [Test] procedure ErrorMemoTheme;
 [Test] procedure ModuleSourceAliases;
 [Test] procedure IncrementalIndex;
 [Test] procedure ExpressionTypes;
 [Test] procedure GenericExpressionBindings;
 [Test] procedure ReviewDraftAndDependencies;
 [Test] procedure ImportedUnitShadowing;
 [Test] procedure ReusedModuleLiveDependency;
 [Test] procedure ActiveWorkerCancellation;
 [Test] procedure CancelledParserInvalidatesIndex;
 [Test] procedure QualifiedExpressionIdentity;
 [Test] procedure ReviewRemainingCases;
 [Test] procedure ReviewGenericFuzz;
 [Test] procedure ReviewMetadata;
 [Test] procedure ReviewContextAndResources;
 [Test] procedure ReviewBatchAndInheritance;
 [Test] procedure ReviewRenameCollision;
 [Test] procedure ReviewMultipleCodeBlocks;
 [Test] procedure ScannerTargetPlatform;
 [Test] procedure ShortcutConflicts;
 [Test] procedure SystemSourceParsing;
 [Test] procedure SourceProtection;
 [Test] procedure PublicApiBaseline;
 [Test] procedure ImageResources;
 [Test] procedure LinkedExampleValidation;
 [Test] procedure MixedParagraphsAndCodeMetadata;
 [Test] procedure RenameChainIsSimultaneous;
 [Test] procedure SourceEncodingAndRanges;
 [Test] procedure InheritanceOverlaysAndDetectsCycles;
 [Test] procedure InlineReferencesInNestedTypes;
 [Test] procedure MarkdownCodeFence;
 [Test] procedure UnknownXmlRoundTrip;
 [Test] procedure ProjectContextFixture;
 [Test] procedure GroupedProjectConditions;
 [Test] procedure ProjectConditionFuzz;
 [Test] procedure UnsavedImportSnapshot;
 [Test] procedure UnknownAttributesSurviveEditing;
 [Test] procedure EditedSummaryPreservesExtensions;
 [Test] procedure InvalidXmlIsNotEmpty;
 [Test] procedure MultilineExampleIsAComment;
 [Test] procedure OverloadsHaveDistinctIdentity;
 [Test] procedure DeclarationAndImplementationIdentity;
 [Test] procedure SynchronizeSignature;
 [Test] procedure ExplicitRenameUpdatesReferences;
 [Test] procedure Diagnostics;
 [Test] procedure EntityDeclarationsRejected;
 [Test] procedure DeterministicXmlFuzz;
end;
implementation
uses XmlDoc.Plugin.Utils,Vcl.Forms,Vcl.Graphics,Winapi.Windows,Winapi.Messages,System.SyncObjs,System.Diagnostics,System.Classes,XmlDoc.I18n,Vcl.StdCtrls,XmlDoc.Expressions,XmlDoc.ProjectIndex,XmlDoc.HelpGen.BatchParser,XmlDoc.SourceAccess,System.SysUtils,System.JSON,XmlDoc.Model,XmlDoc.Parser,XmlDoc.CodeGen,XmlDoc.Consts,XmlDoc.Documentation,XmlDoc.ProjectContext,XmlDoc.HelpGen.Scanner,System.IOUtils,XmlDoc.SourceText,XmlDoc.XmlFragments,XmlDoc.Markup,XmlDoc.HelpGen.Types,XmlDoc.HelpGen.Inheritance,XmlDoc.HelpGen.CrossRef,System.Generics.Collections,XmlDoc.HelpGen.Diagnostics,XmlDoc.HelpGen.Resources,XmlDoc.ShortcutValidation,Vcl.ActnList,Vcl.Menus;
procedure TImprovementsTests.SearchPathUnitReferences;
var Root,ProjectFile,UnitFile,Xml:string;Context:TProjectContext;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString);ForceDirectories(TPath.Combine(Root,'src'));
 try
  ProjectFile:=TPath.Combine(Root,'Tool.dproj');UnitFile:=TPath.Combine(Root,'src','Gtfs.Tools.BuildStatic.pas');TFile.WriteAllText(UnitFile,'unit Gtfs.Tools.BuildStatic; interface implementation end.');
  Xml:='<Project><ItemGroup><DCCReference Include="Gtfs.Tools.BuildStatic.pas"/><DCCReference Include="src\Gtfs.Tools.BuildStatic.pas"/></ItemGroup><PropertyGroup><MainSource>Tool.dpr</MainSource><DCC_UnitSearchPath>$(MSBuildProjectDirectory)\src</DCC_UnitSearchPath></PropertyGroup></Project>';
  TFile.WriteAllText(ProjectFile,Xml);Context:=TProjectContext.Create(ProjectFile);
  try Assert.AreEqual<NativeInt>(1,Length(Context.SourceFiles));Assert.AreEqual(UnitFile,Context.SourceFiles[0]);finally Context.Free;end;
  TFile.WriteAllText(ProjectFile,Xml.Replace('Include="Gtfs.Tools.BuildStatic.pas"','Include="missing\Gtfs.Tools.BuildStatic.pas"'));
  Assert.WillRaise(procedure begin var Missing:=TProjectContext.Create(ProjectFile);Missing.Free;end,Exception,'Explicit missing paths must not silently bind another source');
 finally TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.ModuleSourceAliases;
var Root,UnitFile,ProjectFile:string;Context:TProjectContext;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString);ForceDirectories(TPath.Combine(Root,'src'));
 try
  UnitFile:=TPath.Combine(Root,'src','Gtfs.Tools.BuildStatic.pas');ProjectFile:=TPath.Combine(Root,'Tool.dproj');
  TFile.WriteAllText(UnitFile,'unit Gtfs.Tools.BuildStatic; interface implementation end.');
  TFile.WriteAllText(ProjectFile,'<Project><PropertyGroup><DCC_UnitSearchPath>src</DCC_UnitSearchPath></PropertyGroup><ItemGroup><DCCReference Include="Gtfs.Tools.BuildStatic.pas"/></ItemGroup></Project>');
  Context:=TProjectContext.Create(ProjectFile);
  try
   Assert.AreEqual(UnitFile,Context.ResolveModuleSource(TPath.Combine(Root,'Gtfs.Tools.BuildStatic.pas')),'Resolve the absolute alias reported by OTA');
   Assert.AreEqual(UnitFile,Context.ResolveModuleSource('Gtfs.Tools.BuildStatic.pas'));
   Assert.AreEqual(UnitFile,Context.ResolveModuleSource(UnitFile));
   var Missing:=TPath.Combine(Root,'missing','Gtfs.Tools.BuildStatic.pas');Assert.AreEqual(Missing,Context.ResolveModuleSource(Missing),'Never repair an unrelated explicit path');
   var Unsaved:=TPath.Combine(Root,'Unsaved.pas');Assert.AreEqual(Unsaved,Context.ResolveModuleSource(Unsaved),'A module backed only by an editor snapshot keeps its identity');
   for var I:=0 to 199 do begin
    var Alias:='Gtfs.Tools.BuildStatic.pas';if Odd(I) then Alias:=Alias.ToUpper;
    if (I mod 3)=0 then Alias:=TPath.Combine(Root,'.',Alias) else if (I mod 3)=1 then Alias:=TPath.Combine(Root,Alias);
    Assert.AreEqual(UnitFile,Context.ResolveModuleSource(Alias));
   end;
   var Other:=TPath.Combine(Root,'other','Gtfs.Tools.BuildStatic.pas');ForceDirectories(ExtractFilePath(Other));TFile.WriteAllText(Other,'unit Other; interface implementation end.');
   Context.SourceFiles:=[UnitFile,Other];
   Assert.WillRaise(procedure begin Context.ResolveModuleSource(TPath.Combine(Root,'Gtfs.Tools.BuildStatic.pas'));end,Exception,'Ambiguous project aliases must fail');
   Assert.AreEqual(Other,Context.ResolveModuleSource(Other),'Existing explicit files retain their meaning');
  finally Context.Free;end;
 finally TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.ErrorMemoTheme;
var Form:TForm;Memo:TMemo;
begin
 Form:=TForm.CreateNew(nil);
 try
  Memo:=TMemo.Create(Form);Memo.Parent:=Form;Memo.SetBounds(0,0,180,300);Memo.WordWrap:=True;Memo.ScrollBars:=ssVertical;
  for var Background in [TColor(clWhite),TColor($002F2E2C),TColor($00808080)] do begin
   ApplyDocumentationErrorTheme(Memo,Background);Assert.AreEqual(Background,Memo.Color);
   if Background=TColor($002F2E2C) then Assert.AreEqual('dark',DocumentationThemeName(Background)) else Assert.AreEqual('light',DocumentationThemeName(Background));
   if Background=TColor($002F2E2C) then Assert.AreEqual(TColor(clWhite),Memo.Font.Color) else Assert.AreEqual(TColor(clBlack),Memo.Font.Color);
  end;
  Memo.Text:='Missing project source: '+StringOfChar('x',600)+'\Unit.pas';
  Assert.IsTrue(SendMessage(Memo.Handle,EM_GETLINECOUNT,0,0)>1,'A long filename must wrap in a narrow error panel');Assert.IsTrue(string(Memo.Text).Contains(StringOfChar('x',600)),'Wrapping must not change the copyable error text');
 finally Form.Free;end;
end;
procedure TImprovementsTests.LanguagePacks;
var I:TI18n;Owner:TComponent;LabelControl:TLabel;Edit:TEdit;
begin
 I:=TI18n.Create;Owner:=TComponent.Create(nil);
 try
  I.SetLocalesDir(TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString));
  Assert.AreEqual('ru',TI18n.NormalizeLanguage('ru-RU'));Assert.AreEqual('zh',TI18n.NormalizeLanguage('zh_Hans'));Assert.AreEqual('en',TI18n.NormalizeLanguage('unknown'));
  LabelControl:=TLabel.Create(Owner);LabelControl.Caption:='Summary';LabelControl.Hint:='Recover drafts';Edit:=TEdit.Create(Owner);Edit.Text:='Summary';
  I.SetLanguage('ru-RU');Assert.AreEqual('Описание',I.T('inspector.summary'));I.TranslateComponent(Owner);Assert.AreEqual('Описание',LabelControl.Caption);Assert.AreEqual('Summary',Edit.Text);
  I.SetLanguage('zh-CN');I.TranslateComponent(Owner);Assert.AreEqual('摘要',LabelControl.Caption);Assert.AreEqual('恢复草稿',LabelControl.Hint);Assert.AreEqual('Summary',Edit.Text);
  var Plural:=TLabel.Create(Owner);Plural.Caption:='Parameters';I.TranslateComponent(Owner);Assert.AreEqual('参数',Plural.Caption);
  I.SetLanguage('en');I.TranslateComponent(Owner);Assert.AreEqual('Parameters',Plural.Caption);Assert.AreEqual('Summary',LabelControl.Caption);Assert.AreEqual('Recover drafts',LabelControl.Hint);
  I.SetLanguage('ru');Assert.AreEqual('Найдено исходных файлов: 3.',Format(I.T('Found %d source files.'),[3]));Assert.AreEqual('Версия',I.T('Version'));Assert.AreEqual('Анализ покрытия...',I.T('Analyzing coverage...'));
   I.SetLanguage('zh');Assert.AreEqual('找到 3 个源文件。',Format(I.T('Found %d source files.'),[3]));Assert.AreEqual('版本',I.T('Version'));
   I.SetLanguage('ru');Assert.AreEqual('Документация создана: 5 страниц',I.T('helpgen.complete',[5]));Assert.AreEqual('Missing key',I.T('Missing key'));Assert.AreEqual('Текущий проект (Test.dproj)',I.T('Current Project (Test.dproj)'));
  for var Round:=0 to 999 do begin if Odd(Round) then I.SetLanguage('zh') else I.SetLanguage('ru');I.TranslateComponent(Owner);Assert.AreEqual('Summary',Edit.Text);end;
 finally Owner.Free;I.Free;end;
end;
procedure TImprovementsTests.QualifiedExpressionIdentity;
var P,A,B:TDocParser;Source,Query,Reason:string;All,Matches:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;A:=TDocParser.Create;B:=TDocParser.Create;
 try
  A.ParseSource('unit UnitA; interface type TWorker=class procedure Run(Value:AnsiString); end; implementation end.','UnitA.pas');
  B.ParseSource('unit UnitB; interface type TWorker=class procedure Run(Value:string); end; implementation end.','UnitB.pas');
  Source:='unit Caller; interface implementation begin UnitA.TWorker.Run('+QuotedStr('text')+'); end.';
  P.ParseSource(Source,'Caller.pas');All:=A.GetAllElements+B.GetAllElements;
  Matches:=ResolveDocumentationExpression(P,Source,Pos('UnitA.TWorker.Run',Source)+15,1,All,Query,Reason);
  Assert.AreEqual<NativeInt>(1,Length(Matches),Reason);Assert.AreEqual('UnitA',Matches[0].UnitName);Assert.AreEqual('UnitA.pas',Matches[0].FileName);
  A.ParseSource('unit UnitA; interface type TWorker<T>=class procedure Run(Value:AnsiString); end; TWorker<T,U>=class procedure Run(Value:string); end; implementation end.','UnitA.pas');
  Source:='unit Caller; interface'+sLineBreak+'implementation'+sLineBreak+'procedure Test(Obj:UnitA.TWorker<Integer>);'+sLineBreak+'begin'+sLineBreak+'Obj.Run('+QuotedStr('text')+');'+sLineBreak+'end; end.';
  P.ParseSource(Source,'Caller.pas');All:=A.GetAllElements+B.GetAllElements;
  Assert.AreEqual('UnitA.TWorker<Integer>',P.BindingType('Obj',5));
  Matches:=ResolveDocumentationExpression(P,Source,Pos('Obj.Run',Source)+6,5,All,Query,Reason);
  Assert.AreEqual<NativeInt>(1,Length(Matches),'Constructed generic receiver: '+Reason);Assert.AreEqual('UnitA',Matches[0].UnitName);Assert.AreEqual('TWorker<T>',Matches[0].QualifiedParent);
  var Direct:='unit Caller; interface implementation begin UnitA.TWorker<Integer>.Run('+QuotedStr('text')+'); end.';
  P.ParseSource(Direct,'Caller.pas');Matches:=ResolveDocumentationExpression(P,Direct,Pos('.Run',Direct)+3,1,All,Query,Reason);
  Assert.AreEqual<NativeInt>(1,Length(Matches),'Direct generic: '+Reason);Assert.AreEqual('UnitA',Matches[0].UnitName);
  var Seed:Cardinal:=$195AB;
  for var Round:=1 to 200 do begin
   Seed:=Seed*1664525+1013904223;var Argument:='Integer';
   for var Depth:=0 to Integer(Seed mod 4) do Argument:='TMap<string,'+Argument+'>';
   var Changed:=Source.Replace('UnitA.TWorker<Integer>','UnitA.TWorker<'+Argument+'>');P.ParseSource(Changed,'Caller.pas');
   Assert.AreEqual('UnitA.TWorker<'+Argument+'>',P.BindingType('Obj',5));
   Matches:=ResolveDocumentationExpression(P,Changed,Pos('Obj.Run',Changed)+6,5,All,Query,Reason);
   Assert.AreEqual<NativeInt>(1,Length(Matches),Reason);Assert.AreEqual('UnitA.pas',Matches[0].FileName);
   Direct:='unit Caller; interface implementation begin UnitA.TWorker<'+Argument+'>.Run('+QuotedStr('text')+'); end.';
   P.ParseSource(Direct,'Caller.pas');Matches:=ResolveDocumentationExpression(P,Direct,Pos('.Run',Direct)+3,1,All,Query,Reason);
   Assert.AreEqual<NativeInt>(1,Length(Matches),'Nested direct receiver: '+Reason);Assert.AreEqual('UnitA.pas',Matches[0].FileName);
  end;


 finally B.Free;A.Free;P.Free;end;
end;
procedure TImprovementsTests.ReviewDraftAndDependencies;
var P:TDocParser;Index:TDocumentationIndex;Root,Shared,FileName,Source:string;
 function HasType(const Name:string):Boolean;
 begin Result:=False;for var E in Index.Update(FileName,Source,P) do if E.Name=Name then Exit(True);end;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString);Shared:=TPath.Combine(Root,'shared');ForceDirectories(Shared);
 P:=TDocParser.Create;Index:=TDocumentationIndex.Create;
 try
  FileName:=TPath.Combine(Root,'Main.pas');Source:='unit Main; interface (*$I defs.inc*) {$IFDEF SHARED} type TShared=class end; {$ENDIF} {$IFDEF CHANGED} type TChanged=class end; {$ENDIF} {$IFDEF LOCAL} type TLocal=class end; {$ENDIF} implementation end.';P.SearchPaths:=[Shared];
  TFile.WriteAllText(TPath.Combine(Shared,'defs.inc'),'{$DEFINE SHARED}');
  Assert.IsTrue(HasType('TShared'),'Initial include type');Assert.IsTrue(P.IsUpToDate(Source),'Fresh include cache');
  TFile.WriteAllText(TPath.Combine(Shared,'defs.inc'),'{$DEFINE CHANGED}');
  Assert.IsFalse(P.IsUpToDate(Source),'Changed include cache');Assert.IsTrue(HasType('TChanged'),'Changed include type');
  TFile.WriteAllText(TPath.Combine(Root,'defs.inc'),'{$DEFINE LOCAL}');
  Assert.IsFalse(Index.IsCurrent(FileName,Source,P),'Shadow index');Assert.IsFalse(P.IsUpToDate(Source),'Shadow parser');Assert.IsTrue(HasType('TLocal'),'Shadow type');
 finally Index.Free;P.Free;TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.ImportedUnitShadowing;
var P:TDocParser;Index:TDocumentationIndex;Root,Priority,Shared,FileName,Source:string;
 function HasType(const Name:string):Boolean;
 begin Result:=False;for var E in Index.Update(FileName,Source,P) do if E.Name=Name then Exit(True);end;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString);Priority:=TPath.Combine(Root,'priority');Shared:=TPath.Combine(Root,'shared');ForceDirectories(Priority);ForceDirectories(Shared);
 P:=TDocParser.Create;Index:=TDocumentationIndex.Create;
 try
  FileName:=TPath.Combine(Root,'Caller.pas');Source:='unit Caller; interface uses Dep; {$IF DECLARED(TKnown)} type TPresent=class end; {$ELSE} type TAbsent=class end; {$ENDIF} implementation end.';
  P.SearchPaths:=[Priority,Shared];TFile.WriteAllText(TPath.Combine(Shared,'Dep.pas'),'unit Dep; interface type TKnown=class end; implementation end.');
  Assert.IsTrue(HasType('TPresent'));Assert.IsTrue(P.IsUpToDate(Source));
  TFile.WriteAllText(TPath.Combine(Priority,'Dep.pas'),'unit Dep; interface implementation end.');
  Assert.IsFalse(P.IsUpToDate(Source));Assert.IsFalse(Index.IsCurrent(FileName,Source,P));Assert.IsTrue(HasType('TAbsent'));
  TFile.Delete(TPath.Combine(Priority,'Dep.pas'));Assert.IsFalse(P.IsUpToDate(Source));Assert.IsFalse(Index.IsCurrent(FileName,Source,P));Assert.IsTrue(HasType('TPresent'));
 finally Index.Free;P.Free;TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.ReusedModuleLiveDependency;
var P,Fresh:TDocParser;Index:TDocumentationIndex;Root,FileName,IncludeName,Source:string;Snapshot:TSourceSnapshot;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString);ForceDirectories(Root);P:=TDocParser.Create;Fresh:=TDocParser.Create;Index:=TDocumentationIndex.Create;
 try
  FileName:=TPath.Combine(Root,'Caller.pas');IncludeName:=TPath.Combine(Root,'Features.inc');Source:='unit Caller; interface {$I Features.inc} implementation end.';
  TFile.WriteAllText(IncludeName,'type TOriginal=class end;');Index.Update(FileName,Source,P);Index.ResetStatistics;Index.Update(FileName,Source,Fresh);
  Assert.AreEqual(1,Index.Reused);Assert.AreEqual<NativeInt>(0,Length(Fresh.DependencySnapshots));Assert.IsTrue(Index.IsCurrent(FileName,Source,Fresh));
  Snapshot.FileName:=IncludeName;Snapshot.Source:='type TChanged=class end;';Fresh.SourceSnapshots:=[Snapshot];Assert.IsFalse(Index.IsCurrent(FileName,Source,Fresh),'A reused module must validate its indexed dependencies against new open buffers');
 finally Index.Free;Fresh.Free;P.Free;TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.GenericExpressionBindings;
var P:TDocParser;Source,Query,Reason:string;Matches:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  for var Argument in ['Integer','string'] do begin
   var Value:='123';if Argument='string' then Value:=QuotedStr('text');
   Source:='unit GenericCalls; interface type TBase<T>=class procedure Put(Value:T); end; TBox<U>=class(TBase<U>) end;'+sLineBreak+'implementation'+sLineBreak+'procedure Test(Obj:TBox<'+Argument+'>);'+sLineBreak+'begin'+sLineBreak+'Obj.Put('+Value+');'+sLineBreak+'end; end.';
   P.ParseSource(Source,'GenericCalls.pas');Matches:=ResolveDocumentationExpression(P,Source,Pos('Obj.Put',Source)+6,5,P.GetAllElements,Query,Reason);
   Assert.AreEqual<NativeInt>(1,Length(Matches),Argument+': '+Reason);Assert.AreEqual('',Reason);Assert.AreEqual('TBase<T>',Matches[0].QualifiedParent);
  end;
  Source:='unit GenericCalls; interface type TWorker=class procedure Put<T>(Value:T); overload; procedure Put(Value:Int64); overload; end;'+sLineBreak+'implementation'+sLineBreak+'procedure Test(Obj:TWorker);'+sLineBreak+'begin'+sLineBreak+'Obj.Put(123);'+sLineBreak+'end; end.';
  P.ParseSource(Source,'GenericCalls.pas');Matches:=ResolveDocumentationExpression(P,Source,Pos('Obj.Put',Source)+6,5,P.GetAllElements,Query,Reason);Assert.IsTrue(Length(Matches)>0);Assert.IsTrue(Reason<>'','An unresolved generic overload must prevent a false unique result');

 finally P.Free;end;
end;
procedure TImprovementsTests.ActiveWorkerCancellation;
var Started,ContinueWork:TEvent;Worker:TThread;Cancelled,Checks,Observed:Integer;Source,Root,FileName,Failure:string;Clock:TStopwatch;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString);ForceDirectories(Root);FileName:=TPath.Combine(Root,'Worker.pas');
 var Text:=TStringBuilder.Create;
 try Text.Append('unit Worker; interface type TBase=class procedure Run; end;');for var I:=1 to 10000 do Text.Append(' TChild').Append(I).Append('=class(TBase) procedure Run; override; end;');Text.Append(' implementation end.');Source:=Text.ToString;finally Text.Free;end;
 TFile.WriteAllText(FileName,Source);
 try
  for var Stage:=0 to 1 do begin
   Started:=TEvent.Create(nil,True,False,'');ContinueWork:=TEvent.Create(nil,True,False,'');Cancelled:=0;Checks:=0;Observed:=0;Failure:='';
   Worker:=TThread.CreateAnonymousThread(procedure
    var Parser:TDocParser;Batch:TBatchParser;Check:TProc;
    begin
     Check:=procedure begin Inc(Checks);if ((Stage=0) and (Checks=8)) or ((Stage=1) and (Checks=2)) then begin Started.SetEvent;if ContinueWork.WaitFor(5000)<>wrSignaled then raise Exception.Create('Cancellation barrier timed out');end;if TInterlocked.CompareExchange(Cancelled,0,0)<>0 then Abort;end;
     Parser:=TDocParser.Create;Batch:=TBatchParser.Create;
     try try
      if Stage=0 then begin Parser.OnCheck:=Check;Parser.ParseSource(Source,FileName);end
      else begin Batch.ParseAll([FileName]);var Resolver:=TInheritanceResolver.Create;try Resolver.OnCheck:=Check;Resolver.Apply(Batch.Units);finally Resolver.Free;end;end;
     except on E:EAbort do TInterlocked.Exchange(Observed,1);on E:Exception do Failure:=E.Message;end;
     finally Batch.Free;Parser.Free;end;
    end);
   Worker.FreeOnTerminate:=False;Worker.Start;
   try
    Assert.AreEqual(wrSignaled,Started.WaitFor(15000),'Worker must be inside '+IntToStr(Stage)+' before cancellation');
    Clock:=TStopwatch.StartNew;TInterlocked.Exchange(Cancelled,1);ContinueWork.SetEvent;Worker.WaitFor;Clock.Stop;
    Assert.AreEqual('',Failure);Assert.AreEqual(1,Observed,'Active worker did not observe cancellation');Assert.IsTrue(Clock.ElapsedMilliseconds<2000,'Worker shutdown exceeded 2 seconds: '+Clock.ElapsedMilliseconds.ToString);
    System.Writeln(Format('Active worker stage %d cancellation/shutdown ms: %.3f',[Stage,Clock.Elapsed.TotalMilliseconds]));
   finally TInterlocked.Exchange(Cancelled,1);ContinueWork.SetEvent;Worker.WaitFor;Worker.Free;ContinueWork.Free;Started.Free;end;
  end;
 finally TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.CancelledParserInvalidatesIndex;
var P:TDocParser;Source:string;
begin
 P:=TDocParser.Create;
 try
  Source:='unit Cancelled; interface type TFirst=class end; TSecond=class end; implementation end.';
  P.OnCheck:=procedure begin if Assigned(P.RootNode) then Abort;end;
  Assert.WillRaise(procedure begin P.ParseSource(Source,'Cancelled.pas');end,EAbort);
  Assert.IsFalse(P.IsUpToDate(Source),'Cancellation while indexing must not cache a partial index');
  P.OnCheck:=nil;P.ParseSource(Source,'Cancelled.pas');var Found:=False;for var Element in P.GetAllElements do if Element.Name='TSecond' then Found:=True;Assert.IsTrue(Found,'Parser could not recover after cancellation');
 finally P.Free;end;
end;
procedure TImprovementsTests.ExpressionTypes;
var P:TDocParser;Source,Query,Reason:string;Elements,Matches:TArray<TCodeElementInfo>;
begin
 P:=TDocParser.Create;
 try
  Source:='unit Expressions; interface type TWorker=class procedure Run(Value:Integer); overload; procedure Run(Value:string); overload; end;'+sLineBreak+
   'implementation'+sLineBreak+'procedure Test(SomeObject:TWorker);'+sLineBreak+'var Local:Integer;'+sLineBreak+'begin'+sLineBreak+' SomeObject.Run(Local);'+sLineBreak+'end; end.';
  P.ParseSource(Source,'Expressions.pas');Elements:=P.GetAllElements;
  Assert.AreEqual('TWorker',P.BindingType('SomeObject',6));Assert.AreEqual('Integer',P.BindingType('Local',6));
  Matches:=ResolveDocumentationExpression(P,Source,Pos('SomeObject.Run(Local)',Source)+12,6,Elements,Query,Reason);
  Assert.AreEqual('SomeObject.Run',Query);Assert.AreEqual<NativeInt>(1,Length(Matches),Reason);Assert.AreEqual('Integer',Matches[0].Params[0].TypeName);
  for var I:=0 to Length(Source) do begin Matches:=ResolveDocumentationExpression(P,Source,I,6,Elements,Query,Reason);end;
  for var Argument in ['$AB','42',#39+'text'+#39,'Missing','42 {comment, ignored}'] do begin
   var Changed:=Source.Replace('SomeObject.Run(Local)','SomeObject.Run('+Argument+')');P.ParseSource(Changed,'Expressions.pas');
   Matches:=ResolveDocumentationExpression(P,Changed,Pos('SomeObject.Run(',Changed)+12,6,P.GetAllElements,Query,Reason);
   if Argument='Missing' then Assert.IsTrue(Reason<>'') else if Pos('comment',Argument)>0 then Assert.IsTrue(Reason<>'') else begin Assert.AreEqual<NativeInt>(1,Length(Matches),Argument);if Argument[1]=#39 then Assert.AreEqual('string',Matches[0].Params[0].TypeName) else Assert.AreEqual('Integer',Matches[0].Params[0].TypeName);end;
  end;
  Source:='unit Expressions; interface type TBase=class procedure Run(Value:Integer=1); end; TWorker=class(TBase) end;'+sLineBreak+
   'implementation'+sLineBreak+'procedure Test(SomeObject:TWorker);'+sLineBreak+'begin'+sLineBreak+' SomeObject.Run();'+sLineBreak+'end; end.';
  P.ParseSource(Source,'Expressions.pas');Matches:=ResolveDocumentationExpression(P,Source,Pos('SomeObject.Run()',Source)+12,5,P.GetAllElements,Query,Reason);
  Assert.AreEqual<NativeInt>(1,Length(Matches),'Inherited optional overload: '+Reason);
  var Seed:Cardinal:=$516ABC;
  for var Round:=0 to 1999 do begin Seed:=Seed*1664525+1013904223;Matches:=ResolveDocumentationExpression(P,Source,Integer(Seed mod (Length(Source)+40))-20,5,P.GetAllElements,Query,Reason);end;
 finally P.Free;end;
end;
procedure TImprovementsTests.IncrementalIndex;
var Root,FileName,IncludeFile,Source:string;P:TDocParser;Index:TDocumentationIndex;E:TArray<TCodeElementInfo>;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(Root);FileName:=TPath.Combine(Root,'Indexed.pas');IncludeFile:=TPath.Combine(Root,'types.inc');P:=TDocParser.Create;Index:=TDocumentationIndex.Create;
 try
  Source:='unit Indexed; interface {$I types.inc} {$IFDEF SECOND} type TSecond=class end; {$ELSE} type TFirst=class end; {$ENDIF} implementation end.';TFile.WriteAllText(IncludeFile,'{$UNDEF SECOND}');
  E:=Index.Update(FileName,Source,P);Assert.AreEqual(1,Index.Parsed);E:=Index.Update(FileName,Source,P);Assert.AreEqual(1,Index.Reused);
  TFile.WriteAllText(IncludeFile,'{$DEFINE SECOND}');E:=Index.Update(FileName,Source,P);Assert.AreEqual(2,Index.Parsed);
  var Found:=False;var Names:='';for var Item in E do begin Names:=Names+'|'+Item.Name;if Item.Name='TSecond' then Found:=True;end;Assert.IsTrue(Found,'closed include must invalidate indexed module: '+Names);
  P.Defines:=TArray<string>.Create('CHANGED');E:=Index.Update(FileName,Source,P);Assert.AreEqual(3,Index.Parsed);
  var OtherFile:=TPath.Combine(Root,'Other.pas');var OtherSource:='unit Other; interface type TOther=class end; implementation end.';E:=Index.Update(OtherFile,OtherSource,P);
  for var Round:=0 to 99 do begin
   // Mutate only valid include directives; the unrelated module must be reused.
   TFile.WriteAllText(IncludeFile,'{$DEFINE SECOND} {revision '+IntToStr(Round)+'}');Index.ResetStatistics;E:=Index.Update(FileName,Source,P);E:=Index.Update(OtherFile,OtherSource,P);
   Assert.AreEqual(1,Index.Parsed);Assert.AreEqual(1,Index.Reused);
  end;
  var ParentFile:=TPath.Combine(Root,'Parent.pas');TFile.WriteAllText(ParentFile,'unit Parent; interface type TKnown=class end; implementation end.');P.SourceFiles:=[ParentFile];
  Source:='unit Indexed; interface uses Parent; {$IF DECLARED(TKnown)} type TPresent=class end; {$ELSE} type TAbsent=class end; {$ENDIF} implementation end.';
  E:=Index.Update(FileName,Source,P);Assert.IsTrue(Index.IsCurrent(FileName,Source,P));
  TFile.WriteAllText(ParentFile,'unit Parent; interface implementation end.');Assert.IsFalse(Index.IsCurrent(FileName,Source,P));E:=Index.Update(FileName,Source,P);
  var Absent:=False;for var Item in E do if Item.Name='TAbsent' then Absent:=True;Assert.IsTrue(Absent,'Imported declaration changed without invalidation');
  var Snapshot:TSourceSnapshot;Snapshot.FileName:=ParentFile;Snapshot.Source:='unit Parent; interface type TKnown=class end; implementation end.';P.SourceSnapshots:=[Snapshot];
  Assert.IsFalse(Index.IsCurrent(FileName,Source,P));E:=Index.Update(FileName,Source,P);var Present:=False;for var Item in E do if Item.Name='TPresent' then Present:=True;Assert.IsTrue(Present,'Unsaved imported source did not invalidate dependency');
 finally Index.Free;P.Free;TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.ReviewRemainingCases;
var Root,FileName,Baseline,Source:string;P:TBatchParser;Parser:TDocParser;Report:TDocumentationReport;M:TXmlDocModel;E:TCodeElementInfo;Kinds:TList<string>;Child:TTypeDocInfo;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(Root);FileName:=TPath.Combine(Root,'Cases.pas');Baseline:=TPath.Combine(Root,'baseline.json');
 P:=TBatchParser.Create;Parser:=TDocParser.Create;Report:=TDocumentationReport.Create;M:=TXmlDocModel.Create;Kinds:=TList<string>.Create;
 try
  Source:='unit Cases; interface'+sLineBreak+'{'+sLineBreak+'implementation'+sLineBreak+'}'+sLineBreak+
   'type TVisible=class public procedure Run; end;'+sLineBreak+'implementation procedure TVisible.Run; begin end; end.';
  TFile.WriteAllText(FileName,Source);P.ParseAll([FileName]);Assert.AreEqual<NativeInt>(1,P.Units[0].Types.Count);
  Parser.ParseSource(Source,FileName);for E in Parser.GetAllElements do if E.Name='Run' then Kinds.Add(E.SourceSection);
  Assert.AreEqual<NativeInt>(2,Kinds.Count);Assert.AreEqual('interface',Kinds[0]);Assert.AreEqual('implementation',Kinds[1]);
  Report.Analyze(P.Units);Report.SaveBaseline(Baseline);
  TFile.WriteAllText(FileName,Source.Replace('class public','class private'));P.ParseAll([FileName]);Report.Analyze(P.Units);Report.NewIssueCount(Baseline);
  var Removed:=False;for var Issue in Report.Issues do if Issue.Code='XD011' then Removed:=True;Assert.IsTrue(Removed,'public to private must change the API');
  M.LoadFromXml('<summary>Before</summary><example><para>Prepare</para><code>Run;</code><para>After</para></example>');M.Summary:='Changed';Source:=M.ToXml;
  Assert.IsTrue(Pos('Run;',Source)<Pos('After',Source));
  TFile.WriteAllText(FileName,'unit Cases; interface type'+sLineBreak+
   'TBase<T>=class public'+sLineBreak+'/// <summary>One argument</summary>'+sLineBreak+'procedure Run(Value:T); virtual; end;'+sLineBreak+
   'TBase<Тип,U>=class public'+sLineBreak+'/// <summary>Two arguments</summary>'+sLineBreak+'procedure Run(Value:Тип); virtual; end;'+sLineBreak+
   'TChild<U>=class(TBase<U,Integer>) public procedure Run(Value:U); override; end;'+sLineBreak+'TOne=class(TBase<Integer>) public procedure Run(Value:Integer); override; end; implementation end.');
  P.ParseAll([FileName]);Source:='';for var Orphan in P.Units[0].StandaloneMethods do Source:=Source+Orphan.CodeElement.QualifiedParent+'|';for Child in P.Units[0].Types do begin
   if Child.Name='TChild' then begin Assert.IsTrue(Child.Members.Count>0,'TChild members absent: '+Source);end;
   if Child.Name='TChild' then Assert.AreEqual('Two arguments',Child.Members[0].Doc.Summary);
   if Child.Name='TOne' then Assert.AreEqual('One argument',Child.Members[0].Doc.Summary);
  end;
 finally Kinds.Free;M.Free;Report.Free;Parser.Free;P.Free;TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.ReviewContextAndResources;
var Root,FileName,UnitPath:string;Scanner:TProjectScanner;Opt:TScanOptions;Files:TArray<string>;C:TProjectContext;P:TDocParser;Source:string;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(Root);Scanner:=TProjectScanner.Create;P:=TDocParser.Create;
 try
  FileName:=TPath.Combine(Root,'App.dproj');
  TFile.WriteAllText(FileName,'<Project><PropertyGroup><AppName>DebugApp</AppName><MainSource>$(AppName).dpr</MainSource></PropertyGroup><PropertyGroup Condition="''$(Config)''==''Release''"><AppName>ReleaseApp</AppName><MainSource>$(AppName).dpr</MainSource><DCC_Define>RELEASE</DCC_Define></PropertyGroup></Project>');
  TFile.WriteAllText(TPath.Combine(Root,'DebugApp.dpr'),'program DebugApp; uses DebugUnit in ''DebugUnit.pas''; begin end.');
  TFile.WriteAllText(TPath.Combine(Root,'ReleaseApp.dpr'),'program ReleaseApp; uses ReleaseUnit in ''ReleaseUnit.pas''; begin end.');
  TFile.WriteAllText(TPath.Combine(Root,'DebugUnit.pas'),'unit DebugUnit; interface implementation end.');TFile.WriteAllText(TPath.Combine(Root,'ReleaseUnit.pas'),'unit ReleaseUnit; interface implementation end.');
  Opt:=Default(TScanOptions);Opt.Source:=ssProjectFile;Opt.ProjectPath:=FileName;Opt.Configuration:='Release';Files:=Scanner.Scan(Opt);
  Assert.AreEqual<NativeInt>(1,Length(Files));Assert.IsTrue(Files[0].EndsWith('ReleaseUnit.pas'));
  Source:='unit Switch; interface {$IFDEF RELEASE}type TRelease=class end;{$ELSE}type TDebug=class end;{$ENDIF} implementation end.';
  C:=TProjectContext.Create(FileName,'Debug','Win32');try P.Defines:=C.Defines;P.ParseSource(Source);Assert.AreEqual('TDebug',P.GetAllElements[1].Name);finally C.Free;end;
  C:=TProjectContext.Create(FileName,'Release','Win64');try P.Defines:=C.Defines;P.Platform:=C.Platform;Assert.IsFalse(P.IsUpToDate(Source));P.ParseSource(Source);Assert.AreEqual('TRelease',P.GetAllElements[1].Name);finally C.Free;end;
  UnitPath:=TPath.Combine(Root,'Units');TDirectory.CreateDirectory(UnitPath);UnitPath:=TPath.Combine(UnitPath,'Nested.pas');TDirectory.CreateDirectory(TPath.Combine(Root,'Resources'));
  TFile.WriteAllText(TPath.Combine(Root,'Resources','sample.png'),'fixture');
  Assert.AreEqual(TPath.GetFullPath(TPath.Combine(Root,'Resources','sample.png')),ResolveDocumentationResource('Resources/sample.png',UnitPath));
  Assert.WillRaise(procedure begin ResolveDocumentationResource('../escape',UnitPath);end,Exception);
 finally P.Free;Scanner.Free;TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.ReviewBatchAndInheritance;
var Root,FileName,Xml:string;P:TBatchParser;U:TUnitDocInfo;Typ:TTypeDocInfo;Member:TElementDocInfo;Found:Integer;R:TDocumentationReport;Json:TJSONObject;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(Root);FileName:=TPath.Combine(Root,'Review.pas');P:=TBatchParser.Create;R:=TDocumentationReport.Create;
 try
  TFile.WriteAllText(FileName,'unit Review; interface'+sLineBreak+'type TMode=(One,Two);'+sLineBreak+
   '/// <summary>Base type description</summary>'+sLineBreak+'TBase<T>=class'+sLineBreak+'private procedure Secret;'+sLineBreak+'public'+sLineBreak+
   '/// <summary>Base Run</summary>'+sLineBreak+'function Run(Value:T):T; virtual;'+sLineBreak+
   '/// <summary>Base Hidden</summary>'+sLineBreak+'procedure Hidden;'+sLineBreak+'end;'+sLineBreak+
   'TParent<U>=class(TBase<U>) end;'+sLineBreak+'TChild=class(TParent<Integer>)'+sLineBreak+'public function Run(Value:Integer):Integer; override; procedure Hidden; reintroduce; end;'+sLineBreak+
   'implementation end.');
  P.ParseAll([FileName]);U:=P.Units[0];Found:=0;
  for Typ in U.Types do begin
   if Typ.Name='TMode' then begin Assert.AreEqual(dekType,Typ.Kind);Inc(Found);end;
   if Typ.Name='TChild' then begin
    Assert.AreEqual('Base type description',Typ.Doc.Summary);
    for Member in Typ.Members do begin
     if Member.Name='Run' then begin Assert.AreEqual('Base Run',Member.Doc.Summary);Inc(Found);end;
     if Member.Name='Hidden' then begin Assert.AreEqual('',Member.Doc.Summary);Inc(Found);end;
    end;
   end;
  end;
  Assert.AreEqual<Integer>(3,Found);R.Analyze(P.Units);R.SaveBaseline(TPath.Combine(Root,'baseline.json'));Xml:=TFile.ReadAllText(TPath.Combine(Root,'baseline.json'));
  Json:=TJSONObject.ParseJSONValue(Xml) as TJSONObject;
  try for var Item in Json.GetValue<TJSONArray>('publicSymbols') do Assert.IsFalse((Item as TJSONObject).GetValue<string>('name','').EndsWith('.Secret'));finally Json.Free;end;
 finally R.Free;P.Free;TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.ReviewGenericFuzz;
var P:TDocParser;Seed:Cardinal;I:Integer;A,B:string;Ids:TArray<string>;
begin
 P:=TDocParser.Create;Seed:=$513ABC;
 try
  for I:=0 to 399 do begin
   Seed:=Seed*1664525+1013904223;A:='TList<Integer>';B:='TList<string>';
   for var Depth:=0 to Integer(Seed mod 5) do begin A:='TMap<string,'+A+'>';B:='TMap<string,'+B+'>';end;
   P.ParseSource('unit Fuzz; interface procedure Run(A: '+A+'); overload; procedure Run(A: '+B+'); overload; implementation end.');
   Ids:=nil;for var E in P.GetAllElements do if E.Name='Run' then begin
    Ids:=Ids+[E.SymbolId];Assert.IsTrue((E.Params[0].TypeName=A) or (E.Params[0].TypeName=B));
   end;
   Assert.AreEqual<NativeInt>(2,Length(Ids));Assert.AreNotEqual(Ids[0],Ids[1]);
  end;
 finally P.Free;end;
end;
procedure TImprovementsTests.ReviewMetadata;
var P:TDocParser;Elements:TArray<TCodeElementInfo>;E:TCodeElementInfo;First,Second,Decl,Impl:string;Found:Integer;
begin
 P:=TDocParser.Create;
 try
  P.ParseSource('unit Metadata; interface type TBase<T>=class end; TMode=(one,two);'+sLineBreak+
   'TBox<T>=class(TBase<T>) private procedure Hidden; public procedure Run(A:TList<Integer>); overload;'+sLineBreak+
   'procedure Run(A:TList<string>); overload; function GetItem(Index:Integer):TList<T>; property Items[Index:Integer]:TList<T> read GetItem; end;'+sLineBreak+
   'implementation procedure TBox<T>.Run(A:TList<Integer>); begin end; end.');
  Elements:=P.GetAllElements;Found:=0;
  for E in Elements do begin
   if E.Name='Hidden' then begin Assert.AreEqual('private',E.Visibility);Inc(Found);end;
   if E.Name='TBox' then begin Assert.AreEqual('TBase<T>',E.Ancestor);Inc(Found);end;
   if E.Name='Items' then begin Assert.AreEqual('TList<T>',E.ReturnType);Assert.AreEqual<NativeInt>(1,Length(E.Params));Assert.AreEqual('Integer',E.Params[0].TypeName);Inc(Found);end;
   if E.Name='Run' then begin
    Assert.AreEqual('TBox<T>',E.QualifiedParent);
    if E.Params[0].TypeName='TList<Integer>' then begin if Decl='' then begin Decl:=E.SymbolId;First:=E.SymbolId;end else Impl:=E.SymbolId;end;
    if E.Params[0].TypeName='TList<string>' then Second:=E.SymbolId;
   end;
  end;
  Assert.AreEqual<Integer>(3,Found);Assert.IsTrue(First<>'');Assert.IsTrue(Second<>'');Assert.AreNotEqual(First,Second);Assert.AreEqual(Decl,Impl);
 finally P.Free;end;
end;
procedure TImprovementsTests.ReviewRenameCollision;
var M:TXmlDocModel;E:TCodeElementInfo;P:TParamInfo;Before:string;
begin
 M:=TXmlDocModel.Create;E:=Default(TCodeElementInfo);P:=Default(TParamInfo);P.Name:='Current';E.Params:=[P];
 try M.LoadFromXml('<param name="Old">Old text</param><param name="Current">Current text</param>');Before:=M.ToXml;
  Assert.WillRaise(procedure begin TDocumentation.Synchronize(E,M,['Old=Current']);end,Exception);Assert.AreEqual(Before,M.ToXml);
  M.LoadFromXml('<param name="Current">One</param><param name="Current">Two</param>');TDocumentation.Synchronize(E,M,[]);Assert.AreEqual<Integer>(2,M.Params.Count);
 finally M.Free;end;
end;
procedure TImprovementsTests.ReviewMultipleCodeBlocks;
var M:TXmlDocModel;Ex:TExampleDoc;Xml:string;
begin
 M:=TXmlDocModel.Create;
 try M.LoadFromXml('<example title="Before">Start<code>One;</code>Between<code>Two;</code>End</example>');
  Ex:=M.Examples[0];Ex.Description:=Ex.Description.Replace('Between','Changed');M.Examples[0]:=Ex;Xml:=M.ToXml;
  Assert.IsTrue(Xml.Contains('<code>One;</code>'));Assert.IsTrue(Xml.Contains('<code>Two;</code>'));Assert.IsTrue(Pos('Changed',Xml)>Pos('One;',Xml));Assert.IsTrue(Pos('Changed',Xml)<Pos('Two;',Xml));
 finally M.Free;end;
end;
procedure TImprovementsTests.ScannerTargetPlatform;
var Root:string;Options:TScanOptions;Scanner:TProjectScanner;Files:TArray<string>;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(Root);Scanner:=TProjectScanner.Create;
 try
  TFile.WriteAllText(TPath.Combine(Root,'Target.dpr'),'program Target; uses {$IFDEF WIN64}U64 in ''U64.pas''{$ELSE}U32 in ''U32.pas''{$ENDIF}; begin end.');
  TFile.WriteAllText(TPath.Combine(Root,'U32.pas'),'unit U32; interface implementation end.');TFile.WriteAllText(TPath.Combine(Root,'U64.pas'),'unit U64; interface implementation end.');
  Options:=Default(TScanOptions);Options.Source:=ssProjectFile;Options.ProjectPath:=TPath.Combine(Root,'Target.dpr');Options.Platform:='Win32';
  Files:=Scanner.Scan(Options);Assert.AreEqual<NativeInt>(1,Length(Files));Assert.IsTrue(Files[0].EndsWith('U32.pas'));
  Options.Platform:='Win64';Files:=Scanner.Scan(Options);Assert.AreEqual<NativeInt>(1,Length(Files));Assert.IsTrue(Files[0].EndsWith('U64.pas'));
 finally Scanner.Free;TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.SystemSourceParsing;
var P:TDocParser;Root,FileName,Platform,Source:string;Count:Integer;
begin
 Count:=0;
 for Root in CompilerSourceRoots do begin
  FileName:=TPath.Combine(Root,'rtl\sys\System.pas');if not TFile.Exists(FileName) then Continue;
  Inc(Count);Source:=XmlDoc.SourceText.ReadSourceFile(FileName);
  for Platform in ['Win32','Win64'] do begin
   P:=TDocParser.Create;
   try P.Platform:=Platform;P.ParseSource(Source,FileName);Assert.IsNotNull(P.RootNode);
    Assert.IsTrue(Length(P.GetAllElements)>1000);Assert.AreEqual(Source,P.SourceText,'Compiler condition normalization must not change the original source');
   finally P.Free;end;
  end;
 end;
 Assert.IsTrue(Count>0,'RAD Studio System.pas fixture is required');
end;
procedure TImprovementsTests.SourceProtection;
var Dir,FileName,Root:string;
begin
 Dir:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(Dir);FileName:=TPath.Combine(Dir,'System.pas');
 try
  TFile.WriteAllText(FileName,'unit System; interface implementation end.');
  Assert.IsFalse(IsCompilerSource(FileName),'A user file named System.pas is not an RTL file');Assert.AreEqual('',SourceReadOnlyReason(FileName));
  FileSetAttr(FileName,faReadOnly);Assert.IsTrue(SourceReadOnlyReason(FileName)<>'');
  FileSetAttr(FileName,0);Assert.AreEqual('',SourceReadOnlyReason(FileName));
  FileSetAttr(FileName,faSysFile);Assert.IsTrue(SourceReadOnlyReason(FileName)<>'');FileSetAttr(FileName,0);
  for Root in CompilerSourceRoots do begin
   Assert.IsTrue(IsCompilerSource(TPath.Combine(Root,'rtl\sys\System.pas')));
   Assert.IsTrue(SourceReadOnlyReason(TPath.Combine(Root,'vcl\Vcl.Forms.pas'))<>'');
   Assert.IsFalse(IsCompilerSource(ExcludeTrailingPathDelimiter(Root)+'-user\Unit1.pas'),'Protection must respect path boundaries');
  end;
 finally FileSetAttr(FileName,0);TDirectory.Delete(Dir,True);end;
end;
procedure TImprovementsTests.ShortcutConflicts;
var Actions:TActionList;Action,Proxy,Foreign:TAction;Conflicts:TArray<string>;Root,DocMenu,Item:TMenuItem;
begin
 Actions:=TActionList.Create(nil);
 try Action:=TAction.Create(Actions);Action.ActionList:=Actions;Action.Name:='ForeignAction';Action.Caption:='Existing IDE command';Action.ShortCut:=TextToShortCut('Ctrl+Alt+Q');
  Conflicts:=DocumentationShortcutConflicts([Action.ShortCut,Action.ShortCut,0],['Quick doc','Inspector','Disabled'],Actions);Assert.AreEqual<NativeInt>(3,Length(Conflicts));
  Action.Name:='XmlDocOwnAction';Conflicts:=DocumentationShortcutConflicts([Action.ShortCut,0],['Quick doc','Disabled'],Actions);Assert.AreEqual<NativeInt>(0,Length(Conflicts));
  Root:=TMenuItem.Create(nil);
  try
   DocMenu:=TMenuItem.Create(Root);DocMenu.Name:='XmlDocDocumentMenu';Root.Add(DocMenu);
   Proxy:=TAction.Create(Actions);Proxy.Caption:='&Generate Help...';Proxy.ShortCut:=TextToShortCut('Ctrl+Shift+H');Proxy.ActionList:=Actions;
   Item:=TMenuItem.Create(Root);Item.Action:=Proxy;DocMenu.Add(Item);
   Conflicts:=DocumentationShortcutConflicts([Proxy.ShortCut],['Generate help'],Actions,Root);
   Assert.AreEqual<NativeInt>(0,Length(Conflicts),'IDE wrapper for our menu is not a foreign command');
   Foreign:=TAction.Create(Actions);Foreign.Caption:=Proxy.Caption;Foreign.ShortCut:=Proxy.ShortCut;Foreign.ActionList:=Actions;
   Conflicts:=DocumentationShortcutConflicts([Proxy.ShortCut],['Generate help'],Actions,Root);
   Assert.AreEqual<NativeInt>(1,Length(Conflicts),'Identical foreign caption must not be excluded');
   Conflicts:=DocumentationShortcutConflicts([Proxy.ShortCut],['Generate help'],Actions,Root,[Proxy.ShortCut]);
   Assert.AreEqual<NativeInt>(0,Length(Conflicts),'Existing assignments must not block unrelated settings');
   Conflicts:=DocumentationShortcutConflicts([Proxy.ShortCut],['Generate help'],Actions,Root,[0]);
   Assert.AreEqual<NativeInt>(1,Length(Conflicts),'New conflicting assignment must be rejected');
   Conflicts:=DocumentationShortcutConflicts([Proxy.ShortCut,Proxy.ShortCut],['Help','Coverage'],Actions,Root,[Proxy.ShortCut,0]);
   Assert.AreEqual<NativeInt>(2,Length(Conflicts),'New internal duplicate and foreign conflict must both be reported');
   Conflicts:=DocumentationShortcutConflicts([0],['Generate help'],Actions,Root,[Proxy.ShortCut]);
   Assert.AreEqual<NativeInt>(0,Length(Conflicts),'Clearing a shortcut must be allowed');
  finally Root.Free;end;
 finally Actions.Free;end;
end;
procedure TImprovementsTests.PublicApiBaseline;
var Units:TObjectList<TUnitDocInfo>;U:TUnitDocInfo;E:TElementDocInfo;Report:TDocumentationReport;FileName:string;
begin
 Units:=TObjectList<TUnitDocInfo>.Create;Report:=TDocumentationReport.Create;FileName:=TPath.GetTempFileName;
 try
  U:=TUnitDocInfo.Create;Units.Add(U);U.UnitName:='Test';U.UnitElement.SymbolId:='test:unit:test';U.UnitDoc.Summary:='Unit';
  E:=TElementDocInfo.Create;U.StandaloneMethods.Add(E);E.CodeElement.SymbolId:='test:method:run(integer)';E.CodeElement.Kind:=dekMethod;E.CodeElement.CanonicalName:='Test.Run';E.CodeElement.Visibility:='public';E.Doc.Summary:='Runs';
  Report.Analyze(Units);Report.SaveBaseline(FileName);Assert.AreEqual<Integer>(0,Report.NewIssueCount(FileName));
  E.CodeElement.SymbolId:='test:method:run(string)';Report.Analyze(Units);Assert.AreEqual<Integer>(1,Report.NewIssueCount(FileName));Assert.AreEqual('XD011',Report.Issues[0].Code);
  Assert.AreEqual<Integer>(1,Report.NewIssueCount(FileName));
 finally TFile.Delete(FileName);Report.Free;Units.Free;end;
end;
procedure TImprovementsTests.ImageResources;
var Root,Output,Name:string;Units:TObjectList<TUnitDocInfo>;
begin
 Root:=TPath.Combine(GetCurrentDir,'tests\e2e\DocumentationWorkbench');Output:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);Units:=TObjectList<TUnitDocInfo>.Create;
 try
  Name:=CopyDocumentationImage('Resources/sample.png','',Root,Output,'assets',Units);
  Assert.IsTrue(TFile.Exists(TPath.Combine(Output,'assets\'+Name)));
  Assert.AreEqual(Name,CopyDocumentationImage('Resources/sample.png','',Root,Output,'assets',Units));
  Assert.WillRaise(procedure begin CopyDocumentationImage('../secret.png','',Root,Output,'assets',Units);end,Exception);
  Assert.WillRaise(procedure begin CopyDocumentationImage('missing.png','',Root,Output,'assets',Units);end,Exception);
 finally Units.Free;if TDirectory.Exists(Output) then TDirectory.Delete(Output,True);end;
end;
procedure TImprovementsTests.LinkedExampleValidation;
var E:TCodeElementInfo;M:TXmlDocModel;Issues:TArray<TDocIssue>;Found:Boolean;
begin
 E:=Default(TCodeElementInfo);E.FileName:=TPath.Combine(GetCurrentDir,'tests\e2e\DocumentationWorkbench\Units\Workbench.Sample.pas');
 M:=TXmlDocModel.Create;
 try
  M.LoadFromXml('<summary>Example</summary><example source="Missing.pas"/>');Issues:=TDocumentation.Analyze(E,M,[]);Found:=False;
  for var Issue in Issues do if Issue.Code='XD013' then Found:=True;Assert.IsTrue(Found);
  M.LoadFromXml('<summary>Image</summary><remarks><image src="Resources/sample.png"/></remarks>');Issues:=TDocumentation.Analyze(E,M,[]);
  for var Issue in Issues do Assert.AreNotEqual('XD013',Issue.Code);
 finally M.Free;end;
end;
procedure TImprovementsTests.MixedParagraphsAndCodeMetadata;
var M:TXmlDocModel;E:TExampleDoc;
begin
 M:=TXmlDocModel.Create;
 try
  M.LoadFromXml('<summary>Before<para>Middle</para>After</summary><example title="Old"><code>First</code>Between<code>Second</code></example>');
  Assert.IsTrue(M.Summary.Contains('Before'));Assert.IsTrue(M.Summary.Contains('After'));
  E:=M.Examples[0];E.Title:='New';M.Examples[0]:=E;
  Assert.IsTrue(M.ToXml.Contains('<code>First</code>Between<code>Second</code>'));
  Assert.IsTrue(M.ToXml.Contains('title="New"'));
  M.LoadFromXml('<example><para>Before</para><code language="pascal" custom="keep">OldCode;</code></example>');
  E:=M.Examples[0];E.Description:='<para>After</para>';E.Code:='NewCode;';M.Examples[0]:=E;
  Assert.IsTrue(M.ToXml.Contains('language="pascal"'));Assert.IsTrue(M.ToXml.Contains('custom="keep"'));Assert.IsTrue(M.ToXml.Contains('NewCode;'));

 finally M.Free;end;
end;
procedure TImprovementsTests.RenameChainIsSimultaneous;
var X:string;
begin
 X:=RenameDocNames('<param name="A" custom="yes">One</param><param name="B">Two</param><summary><paramref name="A"/><paramref name="B"/></summary>',['A=B','B=C']);
 Assert.IsTrue(X.Contains('name="B" custom="yes"'));Assert.IsTrue(X.Contains('<param name="C">Two'));
 Assert.IsTrue(X.Contains('<paramref name="B"'));Assert.IsFalse(X.Contains('name="A"'));
end;
procedure TImprovementsTests.SourceEncodingAndRanges;
var Bytes:TBytes;S:string;
begin
 S:='Пример & Unicode';Bytes:=TEncoding.UTF8.GetBytes(S);Assert.AreEqual(S,DecodeSource(Bytes,0,Length(Bytes)));
 Bytes:=TEncoding.Unicode.GetPreamble+TEncoding.Unicode.GetBytes(S);Assert.AreEqual(S,DecodeSource(Bytes,0,Length(Bytes)));
 Bytes:=TEncoding.UTF8.GetPreamble+TBytes.Create($FF);Assert.WillRaise(procedure begin DecodeSource(Bytes,0,Length(Bytes));end,EEncodingError);
 Assert.WillRaise(procedure begin DecodeSource(Bytes,-1,2);end,EArgumentOutOfRangeException);
 Assert.WillRaise(procedure begin DecodeSource(Bytes,0,MaxInt);end,EArgumentOutOfRangeException);
end;
procedure TImprovementsTests.InheritanceOverlaysAndDetectsCycles;
var Units:TObjectList<TUnitDocInfo>;U:TUnitDocInfo;Base,Child:TTypeDocInfo;A,B:TElementDocInfo;R:TInheritanceResolver;
begin
 Units:=TObjectList<TUnitDocInfo>.Create;R:=TInheritanceResolver.Create;
 try
  U:=TUnitDocInfo.Create;Units.Add(U);U.UnitName:='Test';
  Base:=TTypeDocInfo.Create;U.Types.Add(Base);Base.Name:='TBase';Base.FullName:='Test.TBase';Base.CodeElement.UnitName:='Test';
  Child:=TTypeDocInfo.Create;U.Types.Add(Child);Child.Name:='TChild';Child.FullName:='Test.TChild';Child.CodeElement.UnitName:='Test';Child.Ancestor:='TBase';
  A:=TElementDocInfo.Create;Base.Members.Add(A);A.Name:='Run';A.Kind:=dekMethod;A.FullName:='Test.TBase.Run';SetLength(A.CodeElement.Params,1);A.CodeElement.Params[0].Name:='Old';A.CodeElement.Params[0].TypeName:='Integer';A.Doc.LoadFromXml('<summary>Inherited</summary><remarks>Base</remarks><param name="Old">Input</param>');
  B:=TElementDocInfo.Create;Child.Members.Add(B);B.Name:='Run';B.Kind:=dekMethod;SetLength(B.CodeElement.Params,1);B.CodeElement.Params[0].Name:='New';B.CodeElement.Params[0].TypeName:='Integer';B.Doc.LoadFromXml('<remarks>Local</remarks>');
  R.Apply(Units);Assert.AreEqual('Inherited',B.Doc.Summary);Assert.AreEqual('Local',B.Doc.Remarks);Assert.AreEqual('New',B.Doc.Params[0].Name);Assert.AreEqual(A.FullName,B.Doc.InheritedFrom);
  Base.Ancestor:='TChild';Assert.WillRaise(procedure begin R.Apply(Units);end,Exception);
 finally R.Free;Units.Free;end;
end;
procedure TImprovementsTests.InlineReferencesInNestedTypes;
var Units:TObjectList<TUnitDocInfo>;U:TUnitDocInfo;T,N:TTypeDocInfo;Index:TDictionary<string,TElementDocInfo>;R:TCrossRefResolver;
begin
 Units:=TObjectList<TUnitDocInfo>.Create;Index:=TDictionary<string,TElementDocInfo>.Create;R:=TCrossRefResolver.Create(Index);
 try
  U:=TUnitDocInfo.Create;Units.Add(U);U.UnitName:='Test';U.FilePath:='Test.pas';U.UnitElement.LineNumber:=1;U.UnitDoc.LoadFromXml('<summary><see cref="MissingUnit"/></summary>');
  T:=TTypeDocInfo.Create;U.Types.Add(T);N:=TTypeDocInfo.Create;T.NestedTypes.Add(N);N.FullName:='Test.Outer.Inner';N.CodeElement.CommentStartLine:=10;N.Doc.LoadFromXml('<remarks><para><see cref="MissingNested"/></para></remarks>');
  R.ResolveAllRefs(Units);Assert.AreEqual<Integer>(2,R.Unresolved.Count);Assert.AreEqual<Integer>(10,R.Unresolved[1].Line);Assert.AreEqual('MissingNested',R.Unresolved[1].Cref);
 finally R.Free;Index.Free;Units.Free;end;
end;
procedure TImprovementsTests.MarkdownCodeFence;
var S:string;
begin
 S:=MarkupMarkdown('<para><b>Bold</b><br/>Break</para><code>A &lt; B; // ```</code>');
 Assert.IsTrue(S.Contains('**Bold**'));Assert.IsTrue(S.Contains('````pascal'));Assert.IsTrue(S.Contains('A < B; // ```'));Assert.IsFalse(S.Contains('<pre>'));
end;
function EvaluateProjectCondition(const Expression:string):Boolean;
var Root,FileName,Escaped:string;C:TProjectContext;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(Root);
 try
  TDirectory.CreateDirectory(TPath.Combine(Root,'and or (x)'));
  FileName:=TPath.Combine(Root,'Conditions.dproj');
  Escaped:=Expression.Replace('&','&amp;').Replace('"','&quot;').Replace('<','&lt;');
  TFile.WriteAllText(FileName,'<Project><PropertyGroup><MainSource>Conditions.dpr</MainSource></PropertyGroup>'+
   '<PropertyGroup Condition="'+Escaped+'"><DCC_Define>MATCHED</DCC_Define></PropertyGroup></Project>');
  C:=TProjectContext.Create(FileName,'Debug','Win64');
  try Result:=Length(C.Defines)>0;finally C.Free;end;
 finally TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.GroupedProjectConditions;
begin
 Assert.IsFalse(EvaluateProjectCondition('(''$(Platform)''==''Win32'' and ''true''==''true'') or ''''!='''''));
 Assert.IsTrue(EvaluateProjectCondition('(''$(Platform)''==''Win64'' and ''true''==''true'') or ''''!='''''));
 Assert.IsTrue(EvaluateProjectCondition('true or false and false'));
 Assert.IsFalse(EvaluateProjectCondition('(true or false) and false'));
 Assert.IsTrue(EvaluateProjectCondition('(''sand or (and)''==''sand or (and)'') AND (!false OR false)'));
 Assert.IsTrue(EvaluateProjectCondition('Exists(''and or (x)'') and !Exists(''missing'')'));
 Assert.IsFalse(EvaluateProjectCondition('Exists('''')'));
 Assert.IsTrue(EvaluateProjectCondition('"A"=="a" and "left"!="right"'));
 Assert.WillRaise(procedure begin EvaluateProjectCondition('(true or false');end,Exception);
 Assert.WillRaise(procedure begin EvaluateProjectCondition('false and Unsupported()');end,Exception);
 Assert.WillRaise(procedure begin EvaluateProjectCondition('true or Unsupported()');end,Exception);
 Assert.WillRaise(procedure begin EvaluateProjectCondition('(''a''==''a'') trailing');end,Exception);
end;
procedure TImprovementsTests.ProjectConditionFuzz;
var Seed:Cardinal;Expression:string;Expected:Boolean;I:Integer;
 function MakeExpression(Depth:Integer;out Value:Boolean):string;
 var Left,Right:string;L,R:Boolean;Choice:Cardinal;
 begin
  Seed:=Seed*1664525+1013904223;Choice:=Seed;
  if Depth=0 then begin
   Value:=(Choice and 1)=0;
   if Value then Result:='''x and (or)''==''x and (or)''' else Result:='''$(Platform)''==''Win32''';
   Exit;
  end;
  Left:=MakeExpression(Depth-1,L);Right:=MakeExpression(Depth-1,R);
  if (Choice and 2)=0 then begin Result:='('+Left+' AnD '+Right+')';Value:=L and R;end
  else begin Result:='('+Left+' oR '+Right+')';Value:=L or R;end;
  if (Choice and 4)<>0 then begin Result:='!('+Result+')';Value:=not Value;end;
 end;
begin
 Seed:=$C01D17;
 for I:=1 to 256 do begin
  Expression:=MakeExpression(I mod 5,Expected);
  Assert.AreEqual(Expected,EvaluateProjectCondition(Expression),'Condition seed '+UIntToStr(Seed)+': '+Expression);
 end;
end;
procedure TImprovementsTests.ProjectContextFixture;
var Root:string;C:TProjectContext;Scanner:TProjectScanner;Options:TScanOptions;
begin
 Root:=TPath.Combine(GetCurrentDir,'tests\e2e\DocumentationWorkbench');
 C:=TProjectContext.Create(TPath.Combine(Root,'XmlDocE2E.dproj'),'Debug','Win64');
 Scanner:=TProjectScanner.Create;
 try Assert.AreEqual('Win64',C.Platform);Assert.AreEqual<NativeInt>(4,Length(C.SourceFiles));Assert.IsTrue(Length(C.SearchPaths)>0);
  Assert.IsTrue(C.SearchPaths[0].EndsWith('Units'));Assert.IsTrue(Length(C.Defines)>0);
  Options:=Default(TScanOptions);Options.Source:=ssProjectFile;Options.ProjectPath:=C.ProjectFile;
  Assert.AreEqual<NativeInt>(4,Length(Scanner.Scan(Options)));
 finally Scanner.Free;C.Free;end;
end;
procedure TImprovementsTests.UnsavedImportSnapshot;
var Root,FileName:string;P:TDocParser;Snapshot:TSourceSnapshot;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(Root);
 P:=TDocParser.Create;
 try FileName:=TPath.Combine(Root,'Parent.pas');TFile.WriteAllText(FileName,'unit Parent; interface implementation end.');
  Snapshot.FileName:=FileName;Snapshot.Source:='unit Parent; interface type TUnsaved=class end; implementation end.';
  P.SourceSnapshots:=[Snapshot];P.ParseSource('unit D; interface uses Parent; {$IF NOT DECLARED(TUnsaved)} invalid syntax {$ENDIF} implementation end.',TPath.Combine(Root,'D.pas'));
  Assert.IsNotNull(P.RootNode);
 finally P.Free;TDirectory.Delete(Root,True);end;
end;
procedure TImprovementsTests.UnknownAttributesSurviveEditing;
var M:TXmlDocModel;
begin M:=TXmlDocModel.Create;try M.LoadFromXml('<summary vendor="keep">Before</summary><seealso cref="Other"><b>Rich label</b></seealso>');M.Summary:='After';
 Assert.IsTrue(M.SeeAlso[0].Description.Contains('<b>Rich label</b>'));
 Assert.IsTrue(M.ToXml.Contains('vendor="keep"'));Assert.IsTrue(M.ToXml.Contains('After'));finally M.Free;end;end;
procedure TImprovementsTests.UnknownXmlRoundTrip;
const X='<summary>A <b>bold</b><br/> <i>word</i><custom a="1">extension</custom></summary>'+ #13#10 + '<custom-root flag="yes"><child/></custom-root>';
var M:TXmlDocModel;J:string;
begin M:=TXmlDocModel.Create;try M.LoadFromXml(X);Assert.AreEqual('',M.ParseError);Assert.AreEqual(X,M.ToXml);
 J:=M.ToJson;M.FromJson(J);Assert.AreEqual(X,M.ToXml);finally M.Free;end;end;
procedure TImprovementsTests.EditedSummaryPreservesExtensions;
var M:TXmlDocModel;
begin M:=TXmlDocModel.Create;try
 M.LoadFromXml('<summary>Old</summary><remarks><list type="bullet"><item>Keep</item></list></remarks><custom flag="yes"/>');
 M.Summary:='New';Assert.IsTrue(M.ToXml.Contains('<custom'));Assert.IsTrue(M.ToXml.Contains('<list'));Assert.IsTrue(M.ToXml.Contains('New'));
 finally M.Free;end;end;
procedure TImprovementsTests.InvalidXmlIsNotEmpty;
var M:TXmlDocModel;
begin M:=TXmlDocModel.Create;try M.LoadFromXml('<summary>broken');Assert.IsFalse(M.IsEmpty);Assert.AreNotEqual('',M.ParseError);Assert.AreEqual('<summary>broken',M.ToXml);finally M.Free;end;end;
procedure TImprovementsTests.MultilineExampleIsAComment;
var M:TXmlDocModel;E:TExampleDoc;Line,S:string;
begin M:=TXmlDocModel.Create;try E:=Default(TExampleDoc);E.Title:='Example & <test>';E.Code:='if A < B then'+#13#10+'  WriteLn(''a & b'');'+#13#10+#13#10+'Done;';M.Examples.Add(E);
 S:=TDocCodeGenerator.ModelToCommentBlock(M);for Line in S.Split([#13#10]) do if Line<>'' then Assert.IsTrue(Line.StartsWith('  /// ') or (Line='  ///'));
 Assert.IsTrue(S.Contains('&lt;'));Assert.IsTrue(S.Contains('&amp;'));finally M.Free;end;end;
procedure TImprovementsTests.OverloadsHaveDistinctIdentity;
var P:TDocParser;E:TCodeElementInfo;First,Second:string;
begin P:=TDocParser.Create;try P.ParseSource('unit D; interface type TDemo=class procedure Run(A:Integer); overload; procedure Run(A:string); overload; end; implementation end.');
 for E in P.GetAllElements do if E.Name='Run' then if First='' then First:=E.SymbolId else Second:=E.SymbolId;
 Assert.AreNotEqual('',First);Assert.AreNotEqual('',Second);Assert.AreNotEqual(First,Second);finally P.Free;end;end;
procedure TImprovementsTests.DeclarationAndImplementationIdentity;
var P:TDocParser;E:TCodeElementInfo;First,Second:string;
begin P:=TDocParser.Create;try P.ParseSource('unit D; interface type TDemo=class procedure Run(A:Integer); end; implementation procedure TDemo.Run(A:Integer); begin end; end.');
 for E in P.GetAllElements do if E.Name='Run' then if First='' then First:=E.SymbolId else Second:=E.SymbolId;
 Assert.AreNotEqual('',First);Assert.AreEqual(First,Second);finally P.Free;end;end;
procedure TImprovementsTests.SynchronizeSignature;
var M:TXmlDocModel;E:TCodeElementInfo;
begin M:=TXmlDocModel.Create;try E:=Default(TCodeElementInfo);SetLength(E.Params,2);E.Params[0].Name:='B';E.Params[1].Name:='C';
 M.LoadFromXml('<summary>Keep</summary><param name="A">Unmapped</param><param name="B">Known</param><custom/>');
 TDocumentation.Synchronize(E,M,[]);Assert.AreEqual('B',M.Params[0].Name);Assert.AreEqual('Known',M.Params[0].Description);Assert.AreEqual('C',M.Params[1].Name);Assert.AreEqual('A',M.Params[2].Name);Assert.IsTrue(M.ToXml.Contains('<custom'));
 finally M.Free;end;end;
procedure TImprovementsTests.ExplicitRenameUpdatesReferences;
var M:TXmlDocModel;E:TCodeElementInfo;
begin M:=TXmlDocModel.Create;try E:=Default(TCodeElementInfo);SetLength(E.Params,1);E.Params[0].Name:='NewName';
 M.LoadFromXml('<summary>See <paramref name="OldName"/></summary><param name="OldName">Keep</param>');
 TDocumentation.Synchronize(E,M,['OldName=NewName']);Assert.AreEqual('NewName',M.Params[0].Name);Assert.IsFalse(M.ToXml.Contains('OldName'));
 finally M.Free;end;end;
procedure TImprovementsTests.Diagnostics;
var M:TXmlDocModel;E:TCodeElementInfo;Issues:TArray<TDocIssue>;I:TDocIssue;Codes:string;
begin M:=TXmlDocModel.Create;try E:=Default(TCodeElementInfo);E.Kind:=dekMethod;SetLength(E.Params,1);E.Params[0].Name:='Current';
 M.LoadFromXml('<summary>TODO <paramref name="Missing"/></summary><param name="Old">x</param><param name="Old">y</param><value>Wrong</value>');
 Issues:=TDocumentation.Analyze(E,M,[]);for I in Issues do Codes:=Codes+I.Code+';';
 Assert.IsTrue(Codes.Contains('XD002'));Assert.IsTrue(Codes.Contains('XD003'));Assert.IsTrue(Codes.Contains('XD004'));Assert.IsTrue(Codes.Contains('XD005'));Assert.IsTrue(Codes.Contains('XD008'));Assert.IsTrue(Codes.Contains('XD009'));
 finally M.Free;end;end;
procedure TImprovementsTests.EntityDeclarationsRejected;
var M:TXmlDocModel;
begin M:=TXmlDocModel.Create;try M.LoadFromXml('<!DOCTYPE doc [<!ENTITY x SYSTEM "file:///secret">]><summary>&x;</summary>');Assert.AreNotEqual('',M.ParseError);Assert.IsFalse(M.IsEmpty);finally M.Free;end;end;
procedure TImprovementsTests.DeterministicXmlFuzz;
var M:TXmlDocModel;I:Integer;Seed:Cardinal;X,J:string;
begin
 M:=TXmlDocModel.Create;Seed:=$58A17;
 try for I:=1 to 2000 do begin
  Seed:=Seed*1664525+1013904223;
  X:='<summary id="'+IntToStr(I)+'">Text &amp; &lt; <b>'+IntToHex(Seed,8)+'</b><paramref name="A"/><extra n="'+IntToStr(Seed mod 23)+'"/></summary><unknown data="preserve"/>';
  if Seed mod 7=0 then X:=Copy(X,1,Length(X)-Integer(Seed mod 13)-1);
  M.LoadFromXml(X);Assert.AreEqual(X,M.ToXml,'No-edit fuzz seed '+IntToStr(Seed));
  J:=M.ToJson;M.FromJson(J);Assert.AreEqual(X,M.ToXml,'JSON fuzz seed '+IntToStr(Seed));
 end;finally M.Free;end;
end;
initialization TDUnitX.RegisterTestFixture(TImprovementsTests);
end.
