unit XmlDoc.HelpGen.SitePublisher;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.CrossRef,
  XmlDoc.HelpGen.Renderer,
  XmlDoc.HelpGen.Renderer.MD;

type
  /// <summary>정적 사이트 생성기 종류</summary>
  TSiteGenerator = (sgMkDocs, sgDocusaurus, sgVitePress);

  /// <summary>사이트 퍼블리시 옵션</summary>
  TSitePublishOptions = record
    AutoBuild: Boolean;
    NumericFileNames: Boolean;
    BaseURL: string;
    Generator: TSiteGenerator;
    RepoURL: string;
    SiteName: string;
  end;

  /// <summary>MkDocs / Docusaurus / VitePress 프로젝트 구성을 자동 생성합니다.</summary>
  TSitePublisher = class
  private
    procedure GenerateDocusaurus(const AOutputDir: string; const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
    procedure GenerateMkDocs(const AOutputDir: string; const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
    procedure GenerateVitePress(const AOutputDir: string; const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
  public
    /// <summary>Markdown 렌더링 후 사이트 프레임워크 설정 파일을 생성합니다.</summary>
    /// <param name="AUnits">유닛 목록</param>
    /// <param name="AResolver">교차 참조 해석기</param>
    /// <param name="AOpts">사이트 퍼블리시 옵션</param>
    /// <param name="ARenderOpts">렌더링 옵션</param>
    procedure Publish(const AUnits: TObjectList<TUnitDocInfo>; const AResolver: TCrossRefResolver; const AOpts: TSitePublishOptions; const ARenderOpts: TRenderOptions);
  end;

implementation

uses System.JSON, XmlDoc.HelpGen.Navigation;

procedure WriteUTF8(const Path, Content: string);
begin
  // package.json is parsed directly by Node tools that reject a UTF-8 BOM.
  TFile.WriteAllBytes(Path, TEncoding.UTF8.GetBytes(Content));
end;

function QuotedValue(const Value: string): string;
var J: TJSONString;
begin
  J := TJSONString.Create(Value);
  try Result := J.ToJSON; finally J.Free; end;
end;

procedure WriteSiteNavigation(const OutputDir, Title: string; Units: TObjectList<TUnitDocInfo>; Numeric: Boolean);
var Root: TDocNavNode; J: TJSONObject;
  procedure AbsoluteLinks(N: TDocNavNode);
  var Child: TDocNavNode;
  begin
    if N.Target <> '' then N.Target := '/' + N.Target;
    for Child in N.Children do AbsoluteLinks(Child);
  end;
begin
  Root := BuildNavigation(Units, Title, '', False, Numeric);
  try
    AbsoluteLinks(Root); J := Root.ToJSON;
    try WriteUTF8(TPath.Combine(OutputDir, 'navigation.json'), J.Format(2)); finally J.Free; end;
  finally Root.Free; end;
end;

{ TSitePublisher }

procedure TSitePublisher.Publish(
  const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver;
  const AOpts: TSitePublishOptions;
  const ARenderOpts: TRenderOptions);
var
  LOutputDir: string;
  LMDRenderer: TMarkdownDocRenderer;
  LMDOpts: TRenderOptions;
  SiteOpts: TSitePublishOptions;
begin
  case AOpts.Generator of
    sgMkDocs:     LOutputDir := TPath.Combine(ARenderOpts.OutputDir, 'site-mkdocs');
    sgDocusaurus: LOutputDir := TPath.Combine(ARenderOpts.OutputDir, 'site-docusaurus');
    sgVitePress:  LOutputDir := TPath.Combine(ARenderOpts.OutputDir, 'site-vitepress');
  end;

  SiteOpts := AOpts;
  SiteOpts.NumericFileNames := ARenderOpts.NumericFileNames;
  SortDocumentation(AUnits);
  TDirectory.CreateDirectory(LOutputDir);
  WriteSiteNavigation(LOutputDir, AOpts.SiteName, AUnits, ARenderOpts.NumericFileNames);

  // Markdown 렌더링
  LMDOpts := ARenderOpts;
  LMDOpts.OutputDir := TPath.Combine(LOutputDir, 'docs');
  LMDRenderer := TMarkdownDocRenderer.Create;
  try
    IDocRenderer(LMDRenderer).Render(AUnits, AResolver, LMDOpts);
  finally
    LMDRenderer := nil;
  end;

  // These navigation files belong to Docsify/GitBook, not these site frameworks.
  TFile.Delete(TPath.Combine(LOutputDir, 'docs/_sidebar.md'));
  TFile.Delete(TPath.Combine(LOutputDir, 'docs/SUMMARY.md'));

  // 프레임워크별 설정 파일 생성
  case AOpts.Generator of
    sgMkDocs:     GenerateMkDocs(LOutputDir, SiteOpts, AUnits);
    sgDocusaurus: GenerateDocusaurus(LOutputDir, AOpts, AUnits);
    sgVitePress:  GenerateVitePress(LOutputDir, AOpts, AUnits);
  end;
end;

procedure TSitePublisher.GenerateMkDocs(const AOutputDir: string;
  const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
var
  LSB: TStringBuilder;
  Root: TDocNavNode;
  function HasPage(Node: TDocNavNode): Boolean;
  var Child: TDocNavNode;
  begin
    if Pos('#', Node.Target) > 0 then Exit(False);
    if Node.Target <> '' then Exit(True);
    for Child in Node.Children do
      if HasPage(Child) then Exit(True);
    Result := False;
  end;
  procedure Nav(Node: TDocNavNode; Level: Integer);
  var Child: TDocNavNode; Pad: string; HasChildren: Boolean;
  begin
    Pad := StringOfChar(' ', Level * 2);
    if not HasPage(Node) then Exit;
    HasChildren := False;
    for Child in Node.Children do
      if HasPage(Child) then HasChildren := True;
    if not HasChildren then
      LSB.AppendLine(Pad + '- ' + QuotedValue(Node.Caption) + ': ' + QuotedValue(Node.Target))
    else begin
      LSB.AppendLine(Pad + '- ' + QuotedValue(Node.Caption) + ':');
      if Node.Target <> '' then LSB.AppendLine(Pad + '  - Overview: ' + QuotedValue(Node.Target));
      for Child in Node.Children do Nav(Child, Level + 1);
    end;
  end;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('site_name: ' + QuotedValue(AOpts.SiteName));
    if AOpts.BaseURL <> '' then
      LSB.AppendLine('site_url: ' + QuotedValue(AOpts.BaseURL));
    if AOpts.RepoURL <> '' then
      LSB.AppendLine('repo_url: ' + QuotedValue(AOpts.RepoURL));

    LSB.AppendLine('theme:');
    LSB.AppendLine('  name: material');
    LSB.AppendLine('  language: en');
    LSB.AppendLine;
    LSB.AppendLine('nav:');
    LSB.AppendLine('  - Home: index.md');
    LSB.AppendLine('  - API Reference:');

    Root := BuildNavigation(AUnits, AOpts.SiteName, '.md', False, AOpts.NumericFileNames);
    try Nav(Root, 2); finally Root.Free; end;

    LSB.AppendLine;
    LSB.AppendLine('markdown_extensions:');
    LSB.AppendLine('  - toc:');
    LSB.AppendLine('      permalink: true');
    LSB.AppendLine('  - tables');
    LSB.AppendLine('  - fenced_code');

    WriteUTF8(TPath.Combine(AOutputDir, 'mkdocs.yml'), LSB.ToString);

    WriteUTF8(TPath.Combine(AOutputDir, 'requirements.txt'),
      'mkdocs>=1.6,<2' + sLineBreak + 'mkdocs-material>=9.6,<10' + sLineBreak);
    WriteUTF8(TPath.Combine(AOutputDir, 'README.md'),
      '# ' + AOpts.SiteName + sLineBreak + sLineBreak +
      'Install Python 3.10 or later, then run:' + sLineBreak +
      '```shell' + sLineBreak + 'python -m pip install -r requirements.txt' + sLineBreak +
      'python -m mkdocs build --strict' + sLineBreak + 'python -m mkdocs serve' + sLineBreak + '```' + sLineBreak);
    // docs/index.md 복사 (README.md → index.md)
    TFile.Copy(
      TPath.Combine(AOutputDir, 'docs', 'README.md'),
      TPath.Combine(AOutputDir, 'docs', 'index.md'),
      True
    );
    TFile.Delete(TPath.Combine(AOutputDir, 'docs/README.md'));
  finally
    LSB.Free;
  end;
end;

procedure TSitePublisher.GenerateDocusaurus(const AOutputDir: string;
  const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
var
  LSB: TStringBuilder;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('// @ts-check');
    LSB.AppendLine('/** @type {import(''@docusaurus/types'').Config} */');
    LSB.AppendLine('const config = {');
    LSB.AppendLine('  title: ' + QuotedValue(AOpts.SiteName) + ',');
    LSB.AppendLine;
    if AOpts.BaseURL <> '' then
    begin
      LSB.AppendLine('  url: ' + QuotedValue(AOpts.BaseURL) + ',');
      LSB.AppendLine;
    end;
    if AOpts.BaseURL = '' then LSB.AppendLine('  url: ''http://localhost'',');
    LSB.AppendLine('  baseUrl: ''/'',');
    LSB.AppendLine('  i18n: { defaultLocale: ''en'', locales: [''en''] },');
    LSB.AppendLine('  markdown: { format: ''md'' },');
    LSB.AppendLine('  onBrokenLinks: ''throw'',');
    LSB.AppendLine('  themeConfig: {');
    LSB.AppendLine('    navbar: {');
    LSB.AppendLine('      title: ' + QuotedValue(AOpts.SiteName) + ',');
    LSB.AppendLine;
    LSB.AppendLine('    },');
    LSB.AppendLine('  },');
    LSB.AppendLine('  presets: [');
    LSB.AppendLine('    [''classic'', { docs: { routeBasePath: ''/'', sidebarPath: require.resolve(''./sidebars.js''), exclude: [''**/_sidebar.md'', ''**/SUMMARY.md''] }, blog: false }],');
    LSB.AppendLine('  ],');
    LSB.AppendLine('};');
    LSB.AppendLine('module.exports = config;');

    WriteUTF8(
      TPath.Combine(AOutputDir, 'docusaurus.config.js'), LSB.ToString);
    WriteUTF8(TPath.Combine(AOutputDir, 'sidebars.js'),
      'const nav = require("./navigation.json");' + sLineBreak +
      'const page = (href,label) => href.includes("#") ? {type:"link",label,href} : {type:"doc",label,id:href.replace(/^\//,"")};' + sLineBreak +
      'const convert = n => n.items ? {type:"category",label:n.text,items:[' +
      '...(n.link ? [page(n.link,"Overview")] : []),...n.items.map(convert)]}' +
      ' : page(n.link,n.text);' + sLineBreak +
      'module.exports = {api: [{type:"doc",id:"README",label:"Home"},...nav.items.map(convert)]};' + sLineBreak);
    WriteUTF8(TPath.Combine(AOutputDir, 'package.json'),
      '{"name":"api-documentation","version":"1.0.0","private":true,' +
      '"scripts":{"start":"docusaurus start","build":"docusaurus build","serve":"docusaurus serve"},' +
      '"dependencies":{"@docusaurus/core":"3.10.2","@docusaurus/preset-classic":"3.10.2",' +
      '"react":"18.3.1","react-dom":"18.3.1"},"engines":{"node":">=20.0.0"}}');
    WriteUTF8(TPath.Combine(AOutputDir, 'docs/README.md'),
      '---' + sLineBreak + 'slug: /' + sLineBreak + '---' + sLineBreak +
      TFile.ReadAllText(TPath.Combine(AOutputDir, 'docs/README.md')));
    WriteUTF8(TPath.Combine(AOutputDir, 'README.md'),
      '# ' + AOpts.SiteName + sLineBreak + sLineBreak +
      'Requires Node.js 20 or later. Run `npm install`, then `npm run build`.' + sLineBreak +
      'Use `npm start` for development or `npm run serve` to preview the build.' + sLineBreak +
      'Set `url` and `baseUrl` in docusaurus.config.js before deployment.' + sLineBreak);
  finally
    LSB.Free;
  end;
end;

procedure TSitePublisher.GenerateVitePress(const AOutputDir: string;
  const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
var
  LSB: TStringBuilder;
  LConfigDir: string;
  I, J: Integer;
begin
  LConfigDir := TPath.Combine(AOutputDir, 'docs', '.vitepress');
  TDirectory.CreateDirectory(LConfigDir);

  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('import { defineConfig } from ''vitepress''');
    LSB.AppendLine('import navigation from ''../../navigation.json''');
    LSB.AppendLine;
    LSB.AppendLine('export default defineConfig({');
    LSB.AppendLine('  title: ' + QuotedValue(AOpts.SiteName) + ',');
    LSB.AppendLine;
    LSB.AppendLine('  lang: ''en-US'',');
    LSB.AppendLine('  themeConfig: { sidebar: navigation.items }');
    LSB.AppendLine('})');

    WriteUTF8(
      TPath.Combine(LConfigDir, 'config.mts'), LSB.ToString);
    TFile.Copy(TPath.Combine(AOutputDir, 'docs/README.md'), TPath.Combine(AOutputDir, 'docs/index.md'), True);
    TFile.Delete(TPath.Combine(AOutputDir, 'docs/README.md'));
    WriteUTF8(TPath.Combine(AOutputDir, 'package.json'),
      '{"name":"api-documentation","version":"1.0.0","private":true,"type":"module",' +
      '"scripts":{"dev":"vitepress dev docs","build":"vitepress build docs","preview":"vitepress preview docs"},' +
      '"devDependencies":{"vitepress":"1.6.4","vue":"3.5.22"},"engines":{"node":">=20.0.0"}}');
    WriteUTF8(TPath.Combine(AOutputDir, 'README.md'),
      '# ' + AOpts.SiteName + sLineBreak + sLineBreak +
      'Requires Node.js 20 or later. Run `npm install`, then `npm run build`.' + sLineBreak +
      'Use `npm run dev` for development or `npm run preview` to preview the build.' + sLineBreak);
  finally
    LSB.Free;
  end;
end;

end.
