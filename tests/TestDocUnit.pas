unit TestDocUnit;
interface
uses DUnitX.TestFramework;
type
  [TestFixture] TTestDocUnit = class
  public
    [Test] procedure HeaderSelectionAndEditing;
    [Test] procedure UnitIsNotAUsedUnit;
    [Test] procedure BatchExportsUnitDocumentation;
  end;
implementation
uses System.SysUtils, System.IOUtils, System.Generics.Collections,
  XmlDoc.Consts, XmlDoc.Parser, XmlDoc.Model, XmlDoc.CodeGen, XmlDoc.StubGen,
  XmlDoc.HelpGen.BatchParser, XmlDoc.HelpGen.Types, XmlDoc.HelpGen.Renderer,
  XmlDoc.HelpGen.Renderer.HTML, XmlDoc.HelpGen.Renderer.MD,
  XmlDoc.HelpGen.Renderer.JSON, XmlDoc.HelpGen.Renderer.HMXP,
  XmlDoc.HelpGen.SitePublisher, XmlDoc.HelpGen.Coverage;
const Source = '{ Copyright remains intact }'#13#10 +
  '/// <summary>Unit overview marker.</summary>'#13#10 +
  '/// <remarks>Unit remarks marker.</remarks>'#13#10 +
  '/// <example><code>UnitExampleMarker;</code></example>'#13#10 +
  '/// <seealso cref="Demo.Module.TSample" />'#13#10 +
  'unit Demo.Module;'#13#10 +
  'interface'#13#10 + 'uses System.SysUtils;'#13#10 +
  'type TSample = class end;'#13#10 + 'implementation'#13#10 + 'end.';
procedure TTestDocUnit.HeaderSelectionAndEditing;
var P:TDocParser; E:TCodeElementInfo; M:TXmlDocModel; S:string; I:Integer;
begin
  P:=TDocParser.Create; M:=TXmlDocModel.Create;
  try
    P.ParseSource(Source);
    for I:=2 to 6 do begin
      E:=P.GetElementAtLine(I);
      Assert.AreEqual('Demo.Module',E.Name);
      Assert.AreEqual(Integer(dekUnit),Integer(E.Kind));
      Assert.AreEqual(6,E.LineNumber); Assert.AreEqual(2,E.CommentStartLine);
      Assert.AreEqual(5,E.CommentEndLine); Assert.AreEqual(0,E.IndentLevel);
    end;
    M.LoadFromXml(E.ExistingDocXml);
    Assert.AreEqual('Unit overview marker.',M.Summary);
    Assert.AreEqual<NativeInt>(1,M.Examples.Count); Assert.AreEqual<NativeInt>(1,M.SeeAlso.Count);
    M.Summary:='Edited unit overview';
    S:=TDocCodeGenerator.ApplyToSourceText(Source,E,M);
    Assert.IsTrue(S.StartsWith('{ Copyright remains intact }'));
    P.ParseSource(S); E:=P.GetElementAtLine(2); M.LoadFromXml(E.ExistingDocXml);
    Assert.AreEqual('Edited unit overview',M.Summary);
    Assert.AreEqual('Unit remarks marker.',M.Remarks);
    Assert.AreEqual<NativeInt>(1,M.Examples.Count); Assert.AreEqual<NativeInt>(1,M.SeeAlso.Count);
    M.Clear; S:=TDocCodeGenerator.ApplyToSourceText(S,E,M);
    Assert.IsFalse(S.Contains('///')); Assert.IsTrue(S.Contains('unit Demo.Module;'));
  finally M.Free; P.Free; end;
end;
procedure TTestDocUnit.UnitIsNotAUsedUnit;
var P:TDocParser; E:TCodeElementInfo; Count:Integer; M:TXmlDocModel;
begin
  P:=TDocParser.Create;
  try
    P.ParseSource('unit Empty.Module; interface uses System.SysUtils; implementation end.');
    Count:=0;
    for E in P.GetAllElements do if E.Kind=dekUnit then begin
      Inc(Count); Assert.AreEqual('Empty.Module',E.Name);
      M:=TDocStubGenerator.GenerateStub(E);
      try Assert.IsTrue(M.Summary.Contains('Empty.Module unit description')); finally M.Free;end;
    end;
    Assert.AreEqual(1,Count);
  finally P.Free;end;
end;
procedure TTestDocUnit.BatchExportsUnitDocumentation;
var P:TBatchParser; O:TRenderOptions; R:IDocRenderer; Root,F,Text,SavedDoc:string;
  Pub:TSitePublisher; Site:TSitePublishOptions; Kind:TSiteGenerator;
  Report:TDocCoverageReport; Stats:TCoverageStats; Missing:TArray<TCoverageItem>;
begin
  Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);
  TDirectory.CreateDirectory(Root); P:=TBatchParser.Create;
  try
    F:=TPath.Combine(Root,'DifferentFileName.pas'); TFile.WriteAllText(F,Source,TEncoding.UTF8);
    P.ParseAll([F]); Assert.AreEqual<NativeInt>(1,P.Units.Count);
    Assert.AreEqual('Demo.Module',P.Units[0].UnitName);
    Assert.AreEqual('Unit overview marker.',P.Units[0].UnitDoc.Summary);
    Report:=TDocCoverageReport.Create;
    try
      Stats:=Report.Analyze(P.Units);
      try Assert.AreEqual(2,Stats.TotalElements);Assert.AreEqual(1,Stats.Documented);
      finally Stats.ByKind.Free;Stats.ByUnit.Free;Stats.ByVisibility.Free;end;
      Missing:=Report.GetUndocumented(P.Units);
      Assert.AreEqual<NativeInt>(1,Length(Missing));
      Assert.AreEqual('Demo.Module.TSample',Missing[0].ElementFullName);
      SavedDoc:=P.Units[0].UnitDoc.ToXml;
      P.Units[0].UnitDoc.Clear;
      Missing:=Report.GetUndocumented(P.Units);
      Assert.AreEqual<NativeInt>(2,Length(Missing));
      Assert.AreEqual(Integer(dekUnit),Integer(Missing[0].Kind));
      Assert.AreEqual('Demo.Module',Missing[0].ElementFullName);
      P.Units[0].UnitDoc.LoadFromXml(SavedDoc);
    finally Report.Free;end;
    O:=Default(TRenderOptions);O.OutputDir:=Root;O.Title:='Unit test';O.ProjectName:='UnitTest';O.NumericFileNames:=True;
    R:=THTMLDocRenderer.Create;R.Render(P.Units,nil,O);
    R:=TMarkdownDocRenderer.Create;R.Render(P.Units,nil,O);
    R:=TJSONDocRenderer.Create;R.Render(P.Units,nil,O);
    R:=THMXPDocRenderer.Create;R.Render(P.Units,nil,O);
    Pub:=TSitePublisher.Create;
    try
      Site:=Default(TSitePublishOptions); Site.SiteName:=O.Title;
      for Kind:=Low(TSiteGenerator) to High(TSiteGenerator) do begin Site.Generator:=Kind; Pub.Publish(P.Units,nil,Site,O);end;
    finally Pub.Free;end;
    for F in ['units/t000001.html','units/t000001.md','api.json',
      'site-mkdocs/docs/units/t000001.md','site-docusaurus/docs/units/t000001.md',
      'site-vitepress/docs/units/t000001.md'] do begin
      Text:=TFile.ReadAllText(TPath.Combine(Root,F));
      Assert.IsTrue(Text.Contains('Unit overview marker.'),F);
      Assert.IsTrue(Text.Contains('Unit remarks marker.'),F);
      Assert.IsTrue(Text.Contains('UnitExampleMarker'),F);
    end;
    Text:='';for F in TDirectory.GetFiles(TPath.Combine(Root,'hmxp/Topics'),'*.xml') do Text:=Text+TFile.ReadAllText(F);
    Assert.IsTrue(Text.Contains('Unit overview marker.'));Assert.IsTrue(Text.Contains('Unit remarks marker.'));
  finally R:=nil;P.Free;TDirectory.Delete(Root,True);end;
end;
initialization
 TDUnitX.RegisterTestFixture(TTestDocUnit);
end.
