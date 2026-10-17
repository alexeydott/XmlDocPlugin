unit TestDocPublish;
interface
uses DUnitX.TestFramework;
type
 [TestFixture] TTestDocPublish=class
 public
  [Test] procedure TestLinksAndCompleteSiteProjects;
 end;
implementation
uses System.SysUtils,System.Classes,System.IOUtils,System.JSON,System.Generics.Collections,
 XmlDoc.Consts,XmlDoc.Model,XmlDoc.HelpGen.Types,XmlDoc.HelpGen.CrossRef,
 XmlDoc.HelpGen.Renderer,XmlDoc.HelpGen.Renderer.HTML,XmlDoc.HelpGen.Renderer.MD,
 XmlDoc.HelpGen.Renderer.CHM,XmlDoc.HelpGen.SitePublisher;
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
