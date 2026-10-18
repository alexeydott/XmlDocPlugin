unit TestDocImprovements;
interface
uses DUnitX.TestFramework;
type [TestFixture] TImprovementsTests=class
public
 [Test] procedure ScannerTargetPlatform;
 [Test] procedure ShortcutConflicts;
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
uses System.SysUtils,System.JSON,XmlDoc.Model,XmlDoc.Parser,XmlDoc.CodeGen,XmlDoc.Consts,XmlDoc.Documentation,XmlDoc.ProjectContext,XmlDoc.HelpGen.Scanner,System.IOUtils,XmlDoc.SourceText,XmlDoc.XmlFragments,XmlDoc.Markup,XmlDoc.HelpGen.Types,XmlDoc.HelpGen.Inheritance,XmlDoc.HelpGen.CrossRef,System.Generics.Collections,XmlDoc.HelpGen.Diagnostics,XmlDoc.HelpGen.Resources,XmlDoc.ShortcutValidation,Vcl.ActnList,Vcl.Menus;
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
procedure TImprovementsTests.ShortcutConflicts;
var Actions:TActionList;Action:TAction;Conflicts:TArray<string>;
begin
 Actions:=TActionList.Create(nil);
 try Action:=TAction.Create(Actions);Action.ActionList:=Actions;Action.Name:='ForeignAction';Action.Caption:='Existing IDE command';Action.ShortCut:=TextToShortCut('Ctrl+Alt+Q');
  Conflicts:=DocumentationShortcutConflicts([Action.ShortCut,Action.ShortCut,0],['Quick doc','Inspector','Disabled'],Actions);Assert.AreEqual<NativeInt>(3,Length(Conflicts));
  Action.Name:='XmlDocOwnAction';Conflicts:=DocumentationShortcutConflicts([Action.ShortCut,0],['Quick doc','Disabled'],Actions);Assert.AreEqual<NativeInt>(0,Length(Conflicts));
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
