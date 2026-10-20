unit TestDocPublish;
interface
uses DUnitX.TestFramework;
type
 [TestFixture] TTestDocPublish=class
 public
  [Test] procedure TestLinksAndCompleteSiteProjects;
  [Test] procedure TestMarkupAcrossFormats;
 end;
implementation
uses System.SysUtils,System.Classes,System.IOUtils,System.JSON,System.Generics.Collections,
 XmlDoc.Consts,XmlDoc.Model,XmlDoc.HelpGen.Types,XmlDoc.HelpGen.CrossRef,
 XmlDoc.HelpGen.Renderer,XmlDoc.HelpGen.Renderer.HTML,XmlDoc.HelpGen.Renderer.MD,
 XmlDoc.HelpGen.Renderer.CHM,XmlDoc.HelpGen.Renderer.HMXP,XmlDoc.HelpGen.Renderer.JSON,XmlDoc.HelpGen.SitePublisher,XmlDoc.Markup;
procedure TTestDocPublish.TestMarkupAcrossFormats;
const Prose='<para>First <b>bold</b> <strong>strong alias</strong> <i>italic</i> <em>emphasis alias</em> <c>inline code</c>.</para>'+
 '<para>Second<br/>short break<br></br>paired break.</para><para/><b/><strong/><i/><em/><c/><code/>';
const Lists='<list type="number"><item><description>First item</description></item><item><description>Second item</description></item></list>'+
 '<list type="table"><listheader><term>Key</term><description>Meaning</description></listheader><item><term>alpha</term><description>Table cell</description></item></list>';
var Units:TObjectList<TUnitDocInfo>;U:TUnitDocInfo;Renderer:IDocRenderer;Opt:TRenderOptions;Root,S:string;Site:TSitePublishOptions;Pub:TSitePublisher;
begin
 Root:=TPath.Combine(ExtractFilePath(ParamStr(0)),'MarkupFixture');Units:=TObjectList<TUnitDocInfo>.Create(True);
 try
  U:=TUnitDocInfo.Create;U.UnitName:='Markup.Example';U.UnitDoc.LoadFromXml('<summary>'+Prose+'</summary><remarks>'+Lists+'</remarks>');Units.Add(U);
  Assert.AreEqual(Prose,U.UnitDoc.Summary);
  Assert.AreEqual('',MarkupHTML('<b/><strong/><i/><em/><c/><code/><list type="bullet"/>'));
  Assert.AreEqual('Bold T'+#10+'Next',MarkupPlainText('<para><b>Bold</b> <typeparamref name="T"/></para>Next'));
  for var BreakTag in ['<br/>','<br />','<br></br>'] do begin
   Assert.AreEqual('A<br>B',MarkupHTML('A'+BreakTag+'B'));
   Assert.AreEqual('A  '+sLineBreak+'B',MarkupMarkdown('A'+BreakTag+'B'));
  end;
  S:=MarkupMarkdown(Prose);Assert.IsTrue(S.Contains('**bold**'));Assert.IsTrue(S.Contains('**strong alias**'));Assert.IsTrue(S.Contains('*emphasis alias*'));Assert.IsTrue(S.Contains('short break  '+sLineBreak+'paired break'));Assert.IsFalse(S.Contains('****'));
  S:=MarkupMarkdown(Lists);Assert.IsTrue(S.Contains('1. First item'));Assert.IsTrue(S.Contains('2. Second item'));Assert.IsTrue(S.Contains('| --- | --- |'));Assert.IsTrue(S.Contains('| **alpha** | Table cell |'));
  S:=MarkupMarkdown('<see cref="Target">custom label</see>',function(Cref:string):string begin Result:='[Target](target.md)';end);Assert.AreEqual('[custom label](target.md)',S);
  Opt:=Default(TRenderOptions);Opt.OutputDir:=Root;Opt.Title:='Markup';
  Renderer:=THTMLDocRenderer.Create;Renderer.Render(Units,nil,Opt);S:=TFile.ReadAllText(TPath.Combine(Root,'units/Markup.Example.html'));
  Assert.IsTrue(S.Contains('<p>First <strong>bold</strong>'));Assert.IsTrue(S.Contains('<em>emphasis alias</em>'));Assert.IsTrue(S.Contains('<ol>'));Assert.IsTrue(S.Contains('<table>'));Assert.IsFalse(S.Contains('<p><p>'));
  Renderer:=TMarkdownDocRenderer.Create;Renderer.Render(Units,nil,Opt);S:=TFile.ReadAllText(TPath.Combine(Root,'units/Markup.Example.md'));Assert.IsTrue(S.Contains('**bold**'));Assert.IsTrue(S.Contains('2. Second item'));
  Renderer:=THMXPDocRenderer.Create;Renderer.Render(Units,nil,Opt);S:='';for var FileName in TDirectory.GetFiles(TPath.Combine(Root,'hmxp/Topics'),'*.xml') do S:=S+TFile.ReadAllText(FileName);
  Assert.IsTrue(S.Contains('font-weight:bold;'));Assert.IsTrue(S.Contains('strong alias'));Assert.IsTrue(S.Contains('font-style:italic;'));Assert.IsTrue(S.Contains('<br/>'));Assert.IsTrue(S.Contains('<table colcount="2">'));Assert.IsTrue(S.Contains('2. '));
  Renderer:=TJSONDocRenderer.Create;Renderer.Render(Units,nil,Opt);var Json:=TJSONObject.ParseJSONValue(TFile.ReadAllText(TPath.Combine(Root,'api.json'))) as TJSONObject;
  try Assert.IsTrue(Json.ToJSON.Contains('<para>'));Assert.IsTrue(Json.ToJSON.Contains('<b/>'));finally Json.Free;end;
  Renderer:=TCHMDocRenderer.Create;Renderer.Render(Units,nil,Opt);S:=TFile.ReadAllText(TPath.Combine(Root,'units/Markup.Example.html'));Assert.IsTrue(S.Contains('<strong>bold</strong>'));Assert.IsFalse(S.Contains('<p><p>'));
  Pub:=TSitePublisher.Create;try Site:=Default(TSitePublishOptions);Site.SiteName:='Markup';for var Kind:=Low(TSiteGenerator) to High(TSiteGenerator) do begin Site.Generator:=Kind;Pub.Publish(Units,nil,Site,Opt);end;finally Pub.Free;end;
  for var Name in ['mkdocs','docusaurus','vitepress'] do begin S:=TFile.ReadAllText(TPath.Combine(Root,'site-'+Name+'/docs/units/Markup.Example.md'));Assert.IsTrue(S.Contains('**strong alias**'));Assert.IsTrue(S.Contains('2. Second item'));Assert.IsTrue(S.Contains('| --- | --- |'));end;
 finally Renderer:=nil;Units.Free;end;
end;
procedure TTestDocPublish.TestLinksAndCompleteSiteProjects;
var Units:TObjectList<TUnitDocInfo>; U:TUnitDocInfo; T:TTypeDocInfo; E:TElementDocInfo;
 Index:TDictionary<string,TElementDocInfo>; Resolver:TCrossRefResolver;
 Opt:TRenderOptions; Site:TSitePublishOptions; Pub:TSitePublisher;
 Root,Text:string; Ref:TSeeAlsoDoc; Kind:TSiteGenerator; Renderer:IDocRenderer;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);
 Units:=TObjectList<TUnitDocInfo>.Create(True);
 Index:=TDictionary<string,TElementDocInfo>.Create;
 Resolver:=TCrossRefResolver.Create(Index);
 try
  U:=TUnitDocInfo.Create;U.UnitName:='Acme.Graphics';Units.Add(U);
  T:=TTypeDocInfo.Create;T.Name:='TCanvas';T.FullName:=U.UnitName+'.'+T.Name;U.Types.Add(T);
  E:=TElementDocInfo.Create;E.Name:='Draw';E.FullName:=T.FullName+'.Draw';T.Members.Add(E);
  Ref:=Default(TSeeAlsoDoc);Ref.Cref:=E.FullName;T.Doc.SeeAlso.Add(Ref);
  Ref.Cref:='External.Library.TUnknown';T.Doc.SeeAlso.Add(Ref);
  Opt:=Default(TRenderOptions);Opt.ProjectName:='skia_vcl_canvas';Opt.Title:='skia_vcl_canvas';Opt.OutputDir:=Root;
  Renderer:=THTMLDocRenderer.Create;Renderer.Render(Units,Resolver,Opt);
  Text:=TFile.ReadAllText(TPath.Combine(Root,'units/Acme.Graphics.TCanvas.html'));
  Assert.IsTrue(Text.Contains('href="Acme.Graphics.TCanvas.html#Draw"'));
  Assert.IsTrue(Text.Contains('<code>External.Library.TUnknown</code>'));
  Assert.IsFalse(Text.Contains('units/#'));
  Renderer:=TMarkdownDocRenderer.Create;Renderer.Render(Units,Resolver,Opt);
  Text:=TFile.ReadAllText(TPath.Combine(Root,'units/Acme.Graphics.TCanvas.md'));
  Assert.IsTrue(Text.Contains('(Acme.Graphics.TCanvas.md#draw)'));
  Assert.IsFalse(Text.Contains('(units/'));
  Renderer:=TCHMDocRenderer.Create;Renderer.Render(Units,Resolver,Opt);
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'skia_vcl_canvas.hhp')));
  Text:=TFile.ReadAllText(TPath.Combine(Root,'skia_vcl_canvas.hhp'));
  Assert.IsTrue(Text.Contains('Compiled file=skia_vcl_canvas.chm'));
  Assert.IsTrue(Text.Contains('Contents file=skia_vcl_canvas.hhc'));
  Pub:=TSitePublisher.Create;
  try
   Site:=Default(TSitePublishOptions);Site.SiteName:=Opt.Title;
   for Kind:=Low(TSiteGenerator) to High(TSiteGenerator) do begin
    Site.Generator:=Kind;Pub.Publish(Units,Resolver,Site,Opt);
   end;
  finally Pub.Free;end;
  Text:=TFile.ReadAllText(TPath.Combine(Root,'site-mkdocs/mkdocs.yml'));
  Assert.IsTrue(Text.Contains('site_name: "skia_vcl_canvas"'));
  Assert.IsTrue(Text.Contains('language: en'));
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'site-mkdocs/requirements.txt')));
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'site-mkdocs/docs/index.md')));
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'site-docusaurus/package.json')));
  Text:=TFile.ReadAllText(TPath.Combine(Root,'site-docusaurus/docusaurus.config.js'));
  Assert.IsTrue(Text.Contains('title: "skia_vcl_canvas"'));
  Assert.IsTrue(Text.Contains('url: ''http://localhost'''));
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'site-vitepress/package.json')));
  Assert.AreEqual<Byte>(Ord('{'), TFile.ReadAllBytes(TPath.Combine(Root,'site-vitepress/package.json'))[0]);
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'site-vitepress/docs/index.md')));
  Text:=TFile.ReadAllText(TPath.Combine(Root,'site-vitepress/docs/.vitepress/config.mts'));
  Assert.IsTrue(Text.Contains('title: "skia_vcl_canvas"'));
 finally
  Renderer:=nil;Resolver.Free;Index.Free;Units.Free;
  if TDirectory.Exists(Root) then TDirectory.Delete(Root,True);
 end;
end;
initialization
 TDUnitX.RegisterTestFixture(TTestDocPublish);
end.
