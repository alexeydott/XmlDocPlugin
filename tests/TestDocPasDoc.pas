unit TestDocPasDoc;
interface
uses DUnitX.TestFramework,XmlDoc.Consts;
type
 [TestFixture] TTestPasDoc=class
 private
  Dir:string;E:TCodeElementInfo;
  procedure Put(const Name,Text:string);
 public
  [Setup] procedure Setup;
  [TearDown] procedure TearDown;
  [Test] procedure IncludesAndCode;
  [Test] procedure IncludesInvalidateSnapshots;
  [Test] procedure MissingAndCyclicIncludes;
  [Test] procedure StructuredListsAndTables;
  [Test] procedure MetadataMacrosAndSections;
  [Test] procedure RawTextAndHTML;
  [Test] procedure NamedSectionsAndContinuation;
  [Test] procedure OwnerMembersAndExclusion;
  [Test] procedure MalformedAndFuzz;
  [Test] procedure ExportedTablesAndLinks;
 end;
implementation
uses System.SysUtils,System.IOUtils,XmlDoc.PasDoc,XmlDoc.Parser,XmlDoc.Model,XmlDoc.Markup,System.Generics.Collections,XmlDoc.HelpGen.BatchParser,XmlDoc.HelpGen.Types,XmlDoc.HelpGen.Renderer,XmlDoc.HelpGen.Renderer.HMXP;
procedure TTestPasDoc.Setup;
begin
 Dir:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString);TDirectory.CreateDirectory(Dir);
 E:=Default(TCodeElementInfo);E.Kind:=dekMethod;E.Name:='Run';E.FullName:='TWorker.Run';
 E.QualifiedParent:='TWorker';E.Ancestor:='TBase';E.UnitName:='Sample';E.FileName:=TPath.Combine(Dir,'Sample.pas');
 SetLength(E.Params,1);E.Params[0].Name:='Value';
end;
procedure TTestPasDoc.TearDown;
begin TDirectory.Delete(Dir,True);end;
procedure TTestPasDoc.Put(const Name,Text:string);
begin TFile.WriteAllText(TPath.Combine(Dir,Name),Text,TEncoding.UTF8);end;
procedure TTestPasDoc.IncludesAndCode;
var X:string;M:TXmlDocModel;
begin
 Put('outer.txt','@include(inner.txt)'+#10+'@param(value Параметр)');
 Put('inner.txt','@abstract(Описание @bold(метода))');
 Put('first.pas','begin @keep < 2; end;');Put('second.pas','// example');
 X:=ImportLegacyComment('@include(outer.txt)'+#10+'@includeCode(first.pas second.pas)',E);
 M:=TXmlDocModel.Create;
 try
  M.LoadFromXml(X);Assert.AreEqual('',M.ParseError);Assert.AreEqual('Описание <b>метода</b>',M.Summary);
  Assert.AreEqual('Параметр',M.Params[0].Description);
  Assert.IsTrue(M.Remarks.Replace(#13,'').Contains('<code>begin @keep &lt; 2; end;'+#10+'// example</code>'),M.Remarks);
 finally M.Free;end;
end;
procedure TTestPasDoc.IncludesInvalidateSnapshots;
var P:TDocParser;S:string;
begin
 P:=TDocParser.Create;
 try
  Put('included.txt','@abstract(First)');
  S:='unit Sample;'+#10+'interface'+#10+'// @include(included.txt)'+#10+'procedure Run;'+#10+'implementation end.';
  P.ParseSource(S,E.FileName);Assert.IsTrue(P.GetElementAtLine(4).ExistingDocXml.Contains('First'));
  Assert.IsTrue(P.IsUpToDate(S));Put('included.txt','@abstract(Second)');Assert.IsFalse(P.IsUpToDate(S));
  P.ParseSource(S,E.FileName);Assert.IsTrue(P.GetElementAtLine(4).ExistingDocXml.Contains('Second'));
  TFile.Delete(TPath.Combine(Dir,'included.txt'));Assert.IsFalse(P.IsUpToDate(S));
 finally P.Free;end;
end;
procedure TTestPasDoc.MissingAndCyclicIncludes;
var P:TDocParser;S:string;
begin
 Assert.WillRaise(procedure begin ImportLegacyComment('@include(missing.txt)',E);end,EFileNotFoundException);
 Put('a.txt','@include(b.txt)');Put('b.txt','@include(a.txt)');
 Assert.WillRaise(procedure begin ImportLegacyComment('@include(a.txt)',E);end,EConvertError);
 P:=TDocParser.Create;
 try
  S:='unit Sample;'+#10+'interface'+#10+'// @include(later.txt)'+#10+'procedure Run;'+#10+'implementation end.';
  P.ParseSource(S,E.FileName);
  Assert.WillRaise(procedure begin P.GetElementAtLine(4);end,EFileNotFoundException);
  Put('later.txt','Recovered');Assert.IsFalse(P.IsUpToDate(S));P.ParseSource(S,E.FileName);
  Assert.IsTrue(P.GetElementAtLine(4).ExistingDocXml.Contains('Recovered'));
 finally P.Free;end;
end;
procedure TTestPasDoc.StructuredListsAndTables;
var X,H,MD:string;M:TXmlDocModel;
begin
 X:=ImportLegacyComment('@abstract(Test)'+#10+
 '@definitionList(@itemLabel(Term) @item(Definition)) '+
 '@orderedList(@itemSpacing(Compact) @item(One) @itemSetNumber(10) @item(Ten)) '+
 '@table(@rowHead(@cell(Name) @cell(Value) @cell(Extra)) @row(@cell(A) @cell(B) @cell(C)))',E);
 M:=TXmlDocModel.Create;
 try
  M.LoadFromXml(X);Assert.AreEqual('',M.ParseError);
  Assert.IsTrue(M.Remarks.Contains('<term>Term</term><description>Definition</description>'));
  H:=MarkupHTML(M.Remarks);MD:=MarkupMarkdown(M.Remarks);
  Assert.IsTrue(H.Contains('value="10"'));Assert.IsTrue(MD.Contains('10. Ten'));
  Assert.IsTrue(H.Contains('<th>Name</th>'));Assert.IsTrue(MD.Contains('| Name | Value | Extra |'));
 finally M.Free;end;
end;
procedure TTestPasDoc.MetadataMacrosAndSections;
var X,H:string;M:TXmlDocModel;
begin
 X:=ImportLegacyComment('@abstract(@name @className @inheritedClass @inherited)'+#10+
 '@author(Author) @created(2020) @lastmod(2026) @cvs($Date: today $) @deprecated(Use new method)'+#10+
 '@tableOfContents @section(intro Introduction) @anchor(target) '+
 '@url(https://example.com Open) @noAutoLink(TWorker) @noAutoLinkHere @image(test.png) @note(Note) @warning(Warning)',E);
 M:=TXmlDocModel.Create;
 try
  M.LoadFromXml(X);Assert.AreEqual('',M.ParseError);
  Assert.AreEqual('Run TWorker TBase TBase.Run',M.Summary);
  H:=MarkupHTML(M.Remarks);Assert.IsTrue(H.Contains('href="#intro"'));
  Assert.IsTrue(H.Contains('id="target"'));Assert.IsTrue(H.Contains('href="https://example.com"'));
  Assert.IsTrue(H.Contains('Author'));Assert.IsTrue(H.Contains('Use new method'));
 finally M.Free;end;
end;
procedure TTestPasDoc.RawTextAndHTML;
var X:string;M:TXmlDocModel;
begin
 X:=ImportLegacyComment('@abstract(@@ @( @) @- @nil @true @false)'+#10+
 '@longCode(@bold(unchanged) < 2) @preformatted(@name) @latex(\alpha < \beta) '+
 '@html(<p><strong>Bold</strong><br>Text<script>bad()</script></p>)',E);
 M:=TXmlDocModel.Create;
 try
  M.LoadFromXml(X);Assert.AreEqual('',M.ParseError);
  Assert.IsTrue(M.Summary.Contains('@ ( ) - <c>nil</c>'));
  Assert.IsTrue(M.Remarks.Contains('<code>@bold(unchanged) &lt; 2</code>'));
  Assert.IsTrue(M.Remarks.Contains('<code>@name</code>'));
  Assert.IsTrue(M.Remarks.Contains('<para><b>Bold</b><br/>Text</para>'));
  Assert.IsFalse(M.Remarks.Contains('bad()'));
 finally M.Free;end;
end;
procedure TTestPasDoc.NamedSectionsAndContinuation;
var X:string;M:TXmlDocModel;
begin
 X:=ImportLegacyComment('@abstract First \'+#10+' second'+#10+
 '@param(value'+#9+'Text) @param(Unknown ignored) @return(Returned) @raises(EFailure Failed) @seeAlso(TWorker Other)',E);
 M:=TXmlDocModel.Create;
 try
  M.LoadFromXml(X);Assert.AreEqual('',M.ParseError);Assert.AreEqual('First   second',M.Summary);
  Assert.AreEqual<Integer>(1,M.Params.Count);Assert.AreEqual('Value',M.Params[0].Name);
  Assert.AreEqual('Text',M.Params[0].Description);Assert.AreEqual('Returned',M.Returns);
  Assert.AreEqual<Integer>(1,M.Exceptions.Count);Assert.AreEqual<Integer>(1,M.SeeAlso.Count);
  Put('Sample.txt','# Sample.TWorker.Run'+#10+'@include(description.txt)');Put('description.txt','External description');
  M.LoadFromXml(ImportLegacyComment('',E));Assert.AreEqual('External description',M.Summary);
  M.LoadFromXml(ImportLegacyComment('Local description',E));Assert.AreEqual('Local description',M.Summary);
  Assert.IsTrue(M.Remarks.Contains('External description'));
 finally M.Free;end;
end;
procedure TTestPasDoc.OwnerMembersAndExclusion;
var P:TDocParser;S:string;Found:Boolean;
begin
 P:=TDocParser.Create;
 try
  S:='unit Sample;'+#10+'interface'+#10+'// @abstract(Worker) @member(Run Runs well)'+#10+
   'type TWorker=class'+#10+'procedure Run;'+#10+'// @exclude'+#10+'procedure Hidden;'+#10+'end;'+#10+'implementation end.';
  P.ParseSource(S,E.FileName);Assert.IsTrue(P.GetElementAtLine(5).ExistingDocXml.Contains('Runs well'));
  Found:=False;for var Info in P.GetAllElements do if Info.Name='Hidden' then Found:=True;
  Assert.IsFalse(Found);Assert.AreEqual('Hidden',P.GetElementAtLine(7).Name);
  S:='unit Sample;'+#10+'interface'+#10+'// @exclude'+#10+'type TSkipped<T>=class'+#10+
   '// @include(missing.txt)'+#10+'procedure Run;'+#10+'end;'+#10+'implementation end.';
  P.ParseSource(S,E.FileName);Assert.AreEqual<Integer>(1,Length(P.GetAllElements));
  S:='unit Sample;'+#10+'interface'+#10+'/// <summary><![CDATA[<exclude/>]]></summary>'+#10+
    'procedure Run;'+#10+'implementation end.';
  P.ParseSource(S,E.FileName);Assert.AreEqual<Integer>(2,Length(P.GetAllElements));
 finally P.Free;end;
 Assert.AreEqual('Enum item',PasDocMember('@value(Item Enum item)','Item'));
 P:=TDocParser.Create;
 try
  for var Delimiter in ['{','(*'] do begin
   var Closing:string:='}';if Delimiter='(*' then Closing:='*)';
   S:='unit Sample;'+#10+'interface'+#10+Delimiter+#10+' @abstract(Block description)'+#10+
    ' @param(Value Block parameter)'+#10+Closing+#10+'procedure Run(Value:Integer);'+#10+'implementation end.';
   P.ParseSource(S,E.FileName);var Info:=P.GetElementAtLine(7);
   Assert.IsTrue(Info.ExistingDocXml.Contains('Block description'));
   Assert.IsTrue(Info.ExistingDocXml.Contains('Block parameter'));
   Assert.AreEqual<Integer>(3,Info.CommentStartLine);Assert.AreEqual<Integer>(6,Info.CommentEndLine);
  end;
 finally P.Free;end;
 Put('owner.txt','@abstract(Worker) @member(Run Included member)');
 P:=TDocParser.Create;
 try
  S:='unit Sample;'+#10+'interface'+#10+'// @include(owner.txt)'+#10+'type TWorker=class'+#10+
    'procedure Run;'+#10+'end;'+#10+'implementation end.';
  P.ParseSource(S,E.FileName);Assert.IsTrue(P.GetElementAtLine(5).ExistingDocXml.Contains('Included member'));
 finally P.Free;end;
end;
procedure TTestPasDoc.ExportedTablesAndLinks;
var Parser:TBatchParser;Options:TRenderOptions;Renderer:IDocRenderer;Content:string;
begin
 Put('Sample.pas','unit Sample;'+#10+'interface'+#10+
 '// @abstract(Test)'+#10+'// @table(@rowHead(@cell(Name) @cell(Value) @cell(Extra)) @row(@cell(A) @cell(B) @cell(C)))'+#10+
 '// @orderedList(@item(One) @itemSetNumber(10) @item(Ten))'+#10+
 '// @url(https://example.com Example)'+#10+'procedure Run;'+#10+'implementation end.');
 Parser:=TBatchParser.Create;
 try
  Parser.ParseAll([E.FileName]);Options:=Default(TRenderOptions);Options.OutputDir:=TPath.Combine(ExtractFilePath(ParamStr(0)),'PasDocFixture');
  if TDirectory.Exists(Options.OutputDir) then TDirectory.Delete(Options.OutputDir,True);
  Options.ProjectName:='PasDoc';Renderer:=THMXPDocRenderer.Create;Renderer.Render(Parser.Units,nil,Options);
  Content:='';for var FileName in TDirectory.GetFiles(TPath.Combine(Options.OutputDir,'hmxp\Topics'),'*.xml') do Content:=Content+TFile.ReadAllText(FileName);
  Assert.IsTrue(Content.Contains('colcount="3"'));Assert.IsTrue(Content.Contains('10. '));
  Assert.IsTrue(Content.Contains('type="weblink"'));Assert.IsTrue(Content.Contains('href="https://example.com"'));
 finally Parser.Free;end;
end;

procedure TTestPasDoc.MalformedAndFuzz;
var S,X:string;M:TXmlDocModel;
begin
 Assert.AreEqual('<summary>@unknown(@include(missing.txt))</summary>',ImportLegacyComment('@unknown(@include(missing.txt))',E));
 Assert.WillRaise(procedure begin ImportLegacyComment('@bold(Unclosed',E);end,EConvertError);
 Assert.WillRaise(procedure begin ImportLegacyComment('@orderedList(@itemSetNumber(abc))',E);end,EConvertError);
 M:=TXmlDocModel.Create;
 try
  S:='@bold(A @italic(B)) @table(@row(@cell(C))) @@ @br';
  for var I:=1 to Length(S) do begin
   X:=S;Delete(X,I,1);
   try
    X:=ImportLegacyComment(X,E);M.LoadFromXml(X);Assert.AreEqual('',M.ParseError);
    MarkupHTML(M.Summary);MarkupMarkdown(M.Summary);
   except on Error:EConvertError do begin end;end;
  end;
 finally M.Free;end;
end;
initialization
 TDUnitX.RegisterTestFixture(TTestPasDoc);
end.
