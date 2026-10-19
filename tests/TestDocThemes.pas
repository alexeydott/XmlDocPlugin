unit TestDocThemes;
interface
uses DUnitX.TestFramework;
type
 [TestFixture] TDocThemeTests = class
 public
  [Test] procedure CustomThemeCreationAndInvalidNames;
  [Test] procedure BuiltInNamesAndCustomReload;
  [Test] procedure CustomThemesLoadOnCreation;
  [Test] procedure RenderedStylesFollowSelectedTheme;
 end;
implementation
uses Winapi.Windows,System.SysUtils,System.IOUtils,System.Generics.Collections,
 XmlDoc.HelpGen.ThemeEngine,XmlDoc.HelpGen.Types,XmlDoc.HelpGen.CrossRef,
 XmlDoc.HelpGen.Renderer,XmlDoc.HelpGen.Renderer.HTML;
procedure TDocThemeTests.CustomThemeCreationAndInvalidNames;
var Root,FileName:string;Engine:TThemeEngine;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);Engine:=TThemeEngine.Create;
 try
  Engine.SetCustomThemesDir(Root);
  FileName:=Engine.CreateCustomTheme('Ocean','dark');
  Assert.IsTrue(TFile.Exists(FileName));
  Assert.IsTrue(TFile.ReadAllText(FileName,TEncoding.UTF8).Contains('#1e1e2e'));
  Assert.IsTrue(Engine.GetCSS('ocean').Contains('#1e1e2e'));
  Assert.WillRaise(procedure begin Engine.CreateCustomTheme('OCEAN','minimal');end,EArgumentException);
  Assert.IsTrue(Engine.GetCSS('ocean').Contains('#1e1e2e'),'Duplicate creation must not overwrite a theme');
  for var Name in ['', '.', '..', '../escape', '..\escape', 'bad/name', 'bad:name', 'default', 'DARK', 'bad*name', 'bad?name', 'trailing.'] do
    Assert.WillRaise(procedure begin Engine.CreateCustomTheme(Name,'dark');end,EArgumentException);
  // Exercise control characters and path separators as invalid user-provided names.
  for var I:=0 to 31 do
    Assert.WillRaise(procedure begin Engine.CreateCustomTheme('fuzz'+Char(I)+'theme','dark');end,EArgumentException);
 finally Engine.Free;if TDirectory.Exists(Root) then TDirectory.Delete(Root,True);end;
end;

procedure TDocThemeTests.CustomThemesLoadOnCreation;
var Root,OldAppData:string;Engine:TThemeEngine;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);
 ForceDirectories(TPath.Combine(Root,'XmlDocPlugin\themes'));
 TFile.WriteAllText(TPath.Combine(Root,'XmlDocPlugin\themes\ocean.css'),':root{--bg-primary:#102030}',TEncoding.UTF8);
 OldAppData:=System.SysUtils.GetEnvironmentVariable('APPDATA');Engine:=nil;
 try
  if not Winapi.Windows.SetEnvironmentVariable('APPDATA',PChar(Root)) then RaiseLastOSError;
  Engine:=TThemeEngine.Create;
  Assert.IsTrue(Engine.GetCSS('ocean').Contains('#102030'),'Constructor must discover the default custom-theme directory');
 finally
  Winapi.Windows.SetEnvironmentVariable('APPDATA',PChar(OldAppData));
  Engine.Free;TDirectory.Delete(Root,True);
 end;
end;
procedure TDocThemeTests.BuiltInNamesAndCustomReload;
var Engine:TThemeEngine;Root,Other:string;Themes:TArray<string>;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);
 Other:=TPath.Combine(Root,'other');ForceDirectories(Other);
 Engine:=TThemeEngine.Create;
 try
  Engine.SetCustomThemesDir(Root);
  Themes:=Engine.GetAvailableThemes;Assert.AreEqual<Integer>(4,Length(Themes));
  for var Theme:=Low(TBuiltInTheme) to High(TBuiltInTheme) do begin
   Assert.AreEqual(Engine.GetCSS(TThemeEngine.ThemeName(Theme)),Engine.GetCSS(Theme));
   Assert.IsNotEmpty(Engine.GetCSS(Theme));
  end;
  Assert.AreEqual(Engine.GetCSS(btDark),Engine.GetCSS(' DARK '));
  Assert.AreEqual(Engine.GetCSS(btDefault),Engine.GetCSS('unknown'));
  TFile.WriteAllText(TPath.Combine(Root,'Ocean.css'),':root{--bg-primary:#102030}',TEncoding.UTF8);
  Engine.SetCustomThemesDir(Root);
  Assert.IsTrue(Engine.GetCSS('ocean').Contains('#102030'));
  TFile.WriteAllText(TPath.Combine(Root,'Ocean.css'),':root{--bg-primary:#405060}',TEncoding.UTF8);
  Engine.SetCustomThemesDir(Root);
  Assert.IsTrue(Engine.GetCSS('ocean').Contains('#405060'));
  Engine.SetCustomThemesDir(Other);
  Assert.AreEqual<Integer>(4,Length(Engine.GetAvailableThemes),'Old custom themes must not leak into a new directory');
  Assert.AreEqual(Engine.GetCSS(btDefault),Engine.GetCSS('ocean'));
 finally Engine.Free;TDirectory.Delete(Root,True);end;
end;
procedure TDocThemeTests.RenderedStylesFollowSelectedTheme;
var Root,Text,Previous:string;Units:TObjectList<TUnitDocInfo>;
 Resolver:TCrossRefResolver;Index:TDictionary<string,TElementDocInfo>;
 Renderer:IDocRenderer;Options:TRenderOptions;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);
 Units:=TObjectList<TUnitDocInfo>.Create(True);
 Index:=TDictionary<string,TElementDocInfo>.Create;
 Resolver:=TCrossRefResolver.Create(Index);
 try
  Options:=Default(TRenderOptions);Options.OutputDir:=Root;Options.Title:='Theme test';
  Renderer:=THTMLDocRenderer.Create;
  Previous:='';
  for var Theme:=Low(TBuiltInTheme) to High(TBuiltInTheme) do begin
   Options.CSSTheme:=TThemeEngine.ThemeName(Theme);
   Renderer.Render(Units,Resolver,Options);
   Text:=TFile.ReadAllText(TPath.Combine(Root,'assets/style.css'));
   Assert.IsTrue(Text.Contains(TThemeEngine.Instance.GetCSS(Theme)),'Selected palette must be exported');
   Assert.AreNotEqual(Previous,Text,'Switching themes must change the exported stylesheet');Previous:=Text;
   Assert.IsTrue(Text.Contains('background:var(--bg-nav)'));
   Assert.IsTrue(Text.Contains('background:var(--bg)'));
   Assert.IsTrue(Text.Contains('color:var(--code-text)'));
   Assert.IsTrue(Text.Contains('color:var(--text-secondary)'));
   Assert.IsTrue(TFile.ReadAllText(TPath.Combine(Root,'index.html')).Contains('assets/style.css'));
  end;
 finally Renderer:=nil;Resolver.Free;Index.Free;Units.Free;TDirectory.Delete(Root,True);end;
end;
initialization
 TDUnitX.RegisterTestFixture(TDocThemeTests);
end.
