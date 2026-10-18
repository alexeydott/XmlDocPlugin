unit TestDocImprovements;
interface
uses DUnitX.TestFramework;
type [TestFixture] TImprovementsTests=class
public
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
uses XmlDoc.HelpGen.BatchParser,XmlDoc.SourceAccess,System.SysUtils,System.JSON,XmlDoc.Model,XmlDoc.Parser,XmlDoc.CodeGen,XmlDoc.Consts,XmlDoc.Documentation,XmlDoc.ProjectContext,XmlDoc.HelpGen.Scanner,System.IOUtils,XmlDoc.SourceText,XmlDoc.XmlFragments,XmlDoc.Markup,XmlDoc.HelpGen.Types,XmlDoc.HelpGen.Inheritance,XmlDoc.HelpGen.CrossRef,System.Generics.Collections,XmlDoc.HelpGen.Diagnostics,XmlDoc.HelpGen.Resources,XmlDoc.ShortcutValidation,Vcl.ActnList,Vcl.Menus;
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
