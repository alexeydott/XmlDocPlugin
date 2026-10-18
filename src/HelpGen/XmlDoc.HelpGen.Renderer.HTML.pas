unit XmlDoc.HelpGen.Renderer.HTML;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.CrossRef,
  XmlDoc.HelpGen.Navigation,
  XmlDoc.HelpGen.Renderer;

type
  /// <summary>다중 페이지 정적 HTML 사이트를 생성합니다.</summary>
  THTMLDocRenderer = class(TInterfacedObject, IDocRenderer)
  private
    FOptions: TRenderOptions;
    FNames: TTopicNameMap;
    FCompact: Boolean;
    FResolver: TCrossRefResolver;
    FUnits: TObjectList<TUnitDocInfo>;

    function FileName(const FullName: string): string;
    function Anchor(const Name: string): string;
    procedure CopyStaticAssets;
    function EscapeHtml(const AText: string): string;
    function FormatDocToHtml(const ADoc: TXmlDocModel; const AUnitName: string): string;
    function GenerateNav(const APrefix: string = ''): string;
    function MakeCrefLink(const ACref, AUnitName: string): string;
    procedure RenderIndex;
    procedure RenderMemberSection(const ABuilder: TStringBuilder; const AElem: TElementDocInfo; const AUnitName: string);
    procedure RenderSearchIndex;
    procedure RenderTypePage(const AType: TTypeDocInfo; const AUnitName: string);
    procedure RenderUnitPage(const AUnit: TUnitDocInfo);
    function WrapPage(const ATitle, ABody, ANav: string): string;
    procedure WriteFile(const ARelPath, AContent: string);
  public
    destructor Destroy; override;
    constructor Create(ACompact: Boolean = False);
    procedure Render(const AUnits: TObjectList<TUnitDocInfo>; const AResolver: TCrossRefResolver; const AOptions: TRenderOptions);
  end;

implementation

uses XmlDoc.HelpGen.Resources,XmlDoc.Markup,
  System.JSON, System.Hash;

{ THTMLDocRenderer }

constructor THTMLDocRenderer.Create(ACompact: Boolean);
begin inherited Create; FCompact := ACompact; end;

function THTMLDocRenderer.FileName(const FullName: string): string;
begin Result := FNames.FileName(FullName, '.html'); end;


function THTMLDocRenderer.Anchor(const Name: string): string;
begin
  if FCompact then Result := 'a_' + LowerCase(THashSHA2.GetHashString(Name)) else Result := Name;
end;

destructor THTMLDocRenderer.Destroy;
begin FNames.Free; inherited; end;

procedure THTMLDocRenderer.Render(
  const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver;
  const AOptions: TRenderOptions);
var
  I, J: Integer;
begin
  SortDocumentation(AUnits);
  FUnits := AUnits;
  FResolver := AResolver;
  FOptions := AOptions;
  FreeAndNil(FNames);
  FNames := TTopicNameMap.Create(AUnits, FCompact or AOptions.NumericFileNames, AOptions.NumericFileNames);

  TDirectory.CreateDirectory(FOptions.OutputDir);
  TDirectory.CreateDirectory(TPath.Combine(FOptions.OutputDir, 'units'));
  FNames.Save(TPath.Combine(FOptions.OutputDir, 'topic-map.json'));
  TDirectory.CreateDirectory(TPath.Combine(FOptions.OutputDir, 'assets'));

  CopyStaticAssets;
  RenderIndex;

  for I := 0 to AUnits.Count - 1 do
  begin
    RenderUnitPage(AUnits[I]);

    for J := 0 to AUnits[I].Types.Count - 1 do
      RenderTypePage(AUnits[I].Types[J], AUnits[I].UnitName);
  end;

  if FOptions.IncludeSearchIndex then
    RenderSearchIndex;
end;

procedure THTMLDocRenderer.CopyStaticAssets;
var
  LCSS: string;
begin
  LCSS :=
    ':root{--bg:#fff;--text:#212529;--accent:#0d6efd;--border:#dee2e6;' +
    '--code-bg:#f1f3f5;--font:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;' +
    '--mono:"Cascadia Code",Consolas,monospace}' +
    '*{margin:0;padding:0;box-sizing:border-box}' +
    'body{font-family:var(--font);font-size:14px;color:var(--text);line-height:1.6;display:flex}' +
    'nav{width:260px;min-height:100vh;background:#f8f9fa;border-right:1px solid var(--border);' +
    'padding:16px;overflow-y:auto;position:sticky;top:0}' +
    'nav h2{font-size:14px;margin-bottom:12px}' +
    'nav ul{list-style:none}nav li{margin:2px 0}' +
    'nav a{color:var(--text);text-decoration:none;font-size:13px}' +
    'nav summary{cursor:pointer}nav a,nav summary{overflow-wrap:anywhere}' +
    'nav a:hover{color:var(--accent)}' +
    'main{flex:1;padding:24px 32px;max-width:900px}' +
    'h1{font-size:24px;margin-bottom:8px}' +
    'h2{font-size:18px;margin:24px 0 8px;border-bottom:1px solid var(--border);padding-bottom:4px}' +
    'h3{font-size:15px;margin:16px 0 4px}' +
    'table{border-collapse:collapse;width:100%;margin:8px 0}' +
    'th,td{border:1px solid var(--border);padding:6px 10px;text-align:left;font-size:13px}' +
    'th{background:#f8f9fa;font-weight:600}' +
    'code{font-family:var(--mono);font-size:0.9em;background:var(--code-bg);padding:1px 4px;border-radius:3px}' +
    'pre{background:var(--code-bg);padding:12px;border-radius:6px;overflow-x:auto;margin:8px 0}' +
    'pre code{background:none;padding:0}' +
    '.badge{display:inline-block;padding:2px 6px;border-radius:3px;font-size:11px;font-weight:600;' +
    'background:var(--accent);color:#fff;margin-right:4px}' +
    '.member-card{margin:12px 0;padding:12px;border:1px solid var(--border);border-radius:6px}' +
    '.member-sig{font-family:var(--mono);font-size:13px;font-weight:600;margin-bottom:8px}' +
    '.param-table td:first-child{font-family:var(--mono);font-weight:600;white-space:nowrap;width:140px}' +
    '.footer{margin-top:40px;padding-top:12px;border-top:1px solid var(--border);' +
    'font-size:11px;color:#6c757d}';

  WriteFile('assets/style.css', LCSS);
end;

function THTMLDocRenderer.EscapeHtml(const AText: string): string;
begin
  Result := AText;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function THTMLDocRenderer.FormatDocToHtml(const ADoc: TXmlDocModel;
  const AUnitName: string): string;
var
  LSB: TStringBuilder;
  I: Integer;
  function RenderProse(const Text:string):string;
  begin Result:=MarkupHTML(Text,function(Cref:string):string begin Result:=MakeCrefLink(Cref,AUnitName);end,function(Source:string):string begin Result:='../assets/'+CopyDocumentationImage(Source,AUnitName,FOptions.ProjectDir,FOptions.OutputDir,'assets',FUnits);end);end;
begin
  LSB := TStringBuilder.Create;
  try
    if ADoc.Summary <> '' then
      LSB.AppendLine('<p>' + RenderProse(ADoc.Summary) + '</p>');

    if ADoc.Remarks <> '' then
    begin
      LSB.AppendLine('<h3>Remarks</h3>');
      LSB.AppendLine('<p>' + RenderProse(ADoc.Remarks) + '</p>');
    end;

    if ADoc.Params.Count > 0 then
    begin
      LSB.AppendLine('<h3>Parameters</h3>');
      LSB.AppendLine('<table class="param-table"><tr><th>Name</th><th>Description</th></tr>');
      for I := 0 to ADoc.Params.Count - 1 do
      begin
        LSB.AppendFormat('<tr><td><code>%s</code></td><td>%s</td></tr>',
          [EscapeHtml(ADoc.Params[I].Name), RenderProse(ADoc.Params[I].Description)]);
        LSB.AppendLine;
      end;
      LSB.AppendLine('</table>');
    end;

    if ADoc.Returns <> '' then
    begin
      LSB.AppendLine('<h3>Returns</h3>');
      LSB.AppendLine('<p>' + RenderProse(ADoc.Returns) + '</p>');
    end;

    if ADoc.Exceptions.Count > 0 then
    begin
      LSB.AppendLine('<h3>Exceptions</h3>');
      LSB.AppendLine('<table><tr><th>Exception</th><th>Description</th></tr>');
      for I := 0 to ADoc.Exceptions.Count - 1 do
      begin
        LSB.AppendFormat('<tr><td><code>%s</code></td><td>%s</td></tr>',
          [MakeCrefLink(ADoc.Exceptions[I].TypeRef, AUnitName),
           RenderProse(ADoc.Exceptions[I].Description)]);
        LSB.AppendLine;
      end;
      LSB.AppendLine('</table>');
    end;

    if ADoc.Value <> '' then
      LSB.AppendLine('<h3>Value</h3><p>' + RenderProse(ADoc.Value) + '</p>');
    if ADoc.TypeParams.Count > 0 then
    begin
      LSB.AppendLine('<h3>Type Parameters</h3><ul>');
      for I := 0 to ADoc.TypeParams.Count - 1 do
        LSB.AppendLine('<li><code>' + EscapeHtml(ADoc.TypeParams[I].Name) + '</code>: ' + RenderProse(ADoc.TypeParams[I].Description) + '</li>');
      LSB.AppendLine('</ul>');
    end;
    for I := 0 to ADoc.Examples.Count - 1 do
    begin
      LSB.AppendLine('<h3>Example ' + EscapeHtml(ADoc.Examples[I].Title) + '</h3>');
      if ADoc.Examples[I].SourceFile<>'' then LSB.AppendLine('<p>Source: <a href="../assets/'+CopyDocumentationSource(ADoc.Examples[I].SourceFile,AUnitName,FOptions.ProjectDir,FOptions.OutputDir,'assets',FUnits)+'">'+EscapeHtml(ADoc.Examples[I].SourceFile)+'</a> '+EscapeHtml(ADoc.Examples[I].Region)+'</p>');
      LSB.AppendLine('<p>' + RenderProse(ADoc.Examples[I].Description) + '</p>');
      LSB.AppendLine('<pre><code>' + EscapeHtml(ADoc.Examples[I].Code) + '</code></pre>');
    end;
    if ADoc.SeeAlso.Count > 0 then
    begin
      LSB.AppendLine('<h3>See Also</h3>');
      LSB.Append('<ul>');
      for I := 0 to ADoc.SeeAlso.Count - 1 do
        LSB.AppendFormat('<li>%s %s</li>', [MakeCrefLink(ADoc.SeeAlso[I].Cref, AUnitName), RenderProse(ADoc.SeeAlso[I].Description)]);
      LSB.AppendLine('</ul>');
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function THTMLDocRenderer.MakeCrefLink(const ACref, AUnitName: string): string;
var
  U: TUnitDocInfo;
  T: TTypeDocInfo;
  E: TElementDocInfo;
  Href,Resolved:string;
  function Matches(const FullName, Name: string): Boolean;
  begin
    Result := SameText(Resolved, FullName) or
      (SameText(U.UnitName, AUnitName) and SameText(Resolved, Name));
  end;
begin
  // All documentation references are rendered inside units/. Only link to
  // pages/anchors actually emitted by this renderer; external symbols are text.
  Href := '';Resolved:=ACref;
  if Assigned(FResolver) then Resolved:=FResolver.ResolveReference(ACref,AUnitName);
  for U in FUnits do
  begin
    if SameText(ACref, U.UnitName) then Href := FileName(U.UnitName);
    for T in U.Types do
    begin
      if Matches(T.FullName, T.Name) then Href := FileName(T.FullName);
      for E in T.Members do
        if SameText(Resolved,E.CodeElement.SymbolId) or Matches(E.FullName, T.Name + '.' + E.Name) then
          Href := FileName(T.FullName) + '#' + Anchor(MemberAnchor(E.CodeElement,E.Name));
    end;
    for E in U.StandaloneMethods do
      if SameText(Resolved,E.CodeElement.SymbolId) or Matches(E.FullName, E.Name) then Href := FileName(U.UnitName) + '#' + Anchor(MemberAnchor(E.CodeElement,E.Name));
    for E in U.Constants do
      if SameText(Resolved,E.CodeElement.SymbolId) or Matches(E.FullName, E.Name) then Href := FileName(U.UnitName) + '#' + Anchor(MemberAnchor(E.CodeElement,E.Name));
  end;
  Result := '<code>' + EscapeHtml(ACref) + '</code>';
  if Href <> '' then
    Result := '<a href="' + EscapeHtml(Href) + '">' + Result + '</a>';
end;

function THTMLDocRenderer.GenerateNav(const APrefix: string): string;
var Root, Node: TDocNavNode; IndexHref: string;
  function NodeHTML(Node: TDocNavNode): string;
  var Child: TDocNavNode; Href: string;
  begin
    Result := '<li>';
    if Node.Children.Count > 0 then Result := Result + '<details><summary>';
    if Node.Target <> '' then begin
      Href := Node.Target;
      if APrefix = '' then Delete(Href, 1, Length('units/'));
      Result := Result + '<a href="' + EscapeHtml(Href) + '">' + EscapeHtml(Node.Caption) + '</a>';
    end else Result := Result + '<span>' + EscapeHtml(Node.Caption) + '</span>';
    if Node.Children.Count > 0 then begin
      Result := Result + '</summary><ul>';
      for Child in Node.Children do Result := Result + NodeHTML(Child);
      Result := Result + '</ul></details>';
    end;
    Result := Result + '</li>';
  end;
begin
  Root := BuildNavigation(FUnits, FOptions.Title, '.html', FCompact, FOptions.NumericFileNames);
  try
    if APrefix = '' then IndexHref := '../index.html' else IndexHref := 'index.html';
    Result := '<h2>' + EscapeHtml(FOptions.Title) + '</h2><ul><li><a href="' + IndexHref + '">Index</a></li>';
    for Node in Root.Children do Result := Result + NodeHTML(Node);
    Result := Result + '</ul>';
  finally Root.Free; end;
end;

function THTMLDocRenderer.WrapPage(const ATitle, ABody, ANav: string): string;
var
  LFooter: string;
begin
  LFooter := FOptions.FooterText;
  if LFooter = '' then
    LFooter := 'Generated by XmlDoc Plugin';

  Result :=
    '<!DOCTYPE html><html lang="en"><head>' +
    '<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>' + EscapeHtml(ATitle) + '</title>' +
    '<link rel="stylesheet" href="../assets/style.css">' +
    '</head><body>' +
    '<nav>' + ANav + '</nav>' +
    '<main>' + ABody + '</main>' +
    '<footer class="footer">' + EscapeHtml(LFooter) + '</footer>' +
    '</body></html>';
end;

procedure THTMLDocRenderer.WriteFile(const ARelPath, AContent: string);
var
  LFullPath: string;
  LDir: string;
begin
  LFullPath := TPath.Combine(FOptions.OutputDir, ARelPath);
  LDir := ExtractFilePath(LFullPath);
  if not TDirectory.Exists(LDir) then
    TDirectory.CreateDirectory(LDir);

  TFile.WriteAllText(LFullPath, AContent, TEncoding.UTF8);
end;

procedure THTMLDocRenderer.RenderIndex;
var
  LSB: TStringBuilder;
  I: Integer;
  LUnit: TUnitDocInfo;
  LNav: string;
begin
  LNav := GenerateNav;
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<h1>' + EscapeHtml(FOptions.Title) + '</h1>');
    LSB.AppendLine('<h2>Units</h2>');
    LSB.AppendLine('<table><tr><th>Unit</th><th>Description</th></tr>');

    for I := 0 to FUnits.Count - 1 do
    begin
      LUnit := FUnits[I];
      LSB.AppendFormat('<tr><td><a href="units/%s">%s</a></td><td>%s</td></tr>',
        [FileName(LUnit.UnitName), EscapeHtml(LUnit.UnitName),
         EscapeHtml(LUnit.UnitDoc.Summary)]);
      LSB.AppendLine;
    end;

    LSB.AppendLine('</table>');
    WriteFile('index.html',
      StringReplace(WrapPage(FOptions.Title, LSB.ToString,
        GenerateNav('units/')),
        '../assets/', 'assets/', [rfReplaceAll]));
  finally
    LSB.Free;
  end;
end;

procedure THTMLDocRenderer.RenderUnitPage(const AUnit: TUnitDocInfo);
var
  LSB: TStringBuilder;
  I: Integer;
  LNav: string;
begin
  LNav := GenerateNav;
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<h1>' + EscapeHtml(AUnit.UnitName) + '</h1>');
    LSB.Append(FormatDocToHtml(AUnit.UnitDoc, AUnit.UnitName));

    // Types
    if AUnit.Types.Count > 0 then
    begin
      LSB.AppendLine('<h2>Types</h2>');
      LSB.AppendLine('<table><tr><th>Type</th><th>Kind</th><th>Description</th></tr>');
      for I := 0 to AUnit.Types.Count - 1 do
      begin
        LSB.AppendFormat('<tr><td><a href="%s">%s</a></td><td>%s</td><td>%s</td></tr>',
          [FileName(AUnit.UnitName + '.' + AUnit.Types[I].Name),
           EscapeHtml(AUnit.Types[I].Name),
           EscapeHtml(AUnit.Types[I].Kind.ToString),
           EscapeHtml(AUnit.Types[I].Doc.Summary)]);
        LSB.AppendLine;
      end;
      LSB.AppendLine('</table>');
    end;

    // Standalone methods
    if AUnit.StandaloneMethods.Count > 0 then
    begin
      LSB.AppendLine('<h2>Functions &amp; Procedures</h2>');
      for I := 0 to AUnit.StandaloneMethods.Count - 1 do
        RenderMemberSection(LSB, AUnit.StandaloneMethods[I], AUnit.UnitName);
    end;

    // Constants
    if AUnit.Constants.Count > 0 then
    begin
      LSB.AppendLine('<h2>Constants</h2>');
      for I := 0 to AUnit.Constants.Count - 1 do
        RenderMemberSection(LSB, AUnit.Constants[I], AUnit.UnitName);
    end;

    if AUnit.Variables.Count > 0 then begin
      LSB.AppendLine('<h2>Variables</h2>');
      for I := 0 to AUnit.Variables.Count - 1 do RenderMemberSection(LSB, AUnit.Variables[I], AUnit.UnitName);
    end;

    WriteFile('units/' + FileName(AUnit.UnitName),
      WrapPage(AUnit.UnitName, LSB.ToString, LNav));
  finally
    LSB.Free;
  end;
end;

procedure THTMLDocRenderer.RenderTypePage(const AType: TTypeDocInfo;
  const AUnitName: string);
var
  LSB: TStringBuilder;
  I: Integer;
  LNav: string;
begin
  if AType.FullName = '' then AType.FullName := AUnitName + '.' + AType.Name;
  LNav := GenerateNav;
  LSB := TStringBuilder.Create;
  try
    LSB.AppendFormat('<h1><span class="badge">%s</span> %s</h1>',
      [EscapeHtml(AType.Kind.ToString), EscapeHtml(AType.Name)]);
    LSB.AppendLine;

    if AType.Ancestor <> '' then
      LSB.AppendLine('<p>Inherits from <code>' + EscapeHtml(AType.Ancestor) + '</code></p>');

    LSB.Append(FormatDocToHtml(AType.Doc, AUnitName));

    // Members
    if AType.Members.Count > 0 then
    begin
      LSB.AppendLine('<h2>Members</h2>');

      // Members table
      LSB.AppendLine('<table><tr><th>Name</th><th>Kind</th><th>Visibility</th><th>Description</th></tr>');
      for I := 0 to AType.Members.Count - 1 do
      begin
        LSB.AppendFormat('<tr><td><a href="#%s"><code>%s</code></a></td><td>%s</td><td>%s</td><td>%s</td></tr>',
          [EscapeHtml(Anchor(MemberAnchor(AType.Members[I].CodeElement,AType.Members[I].Name))),
           EscapeHtml(AType.Members[I].Name),
           EscapeHtml(AType.Members[I].Kind.ToString),
           EscapeHtml(AType.Members[I].Visibility),
           EscapeHtml(AType.Members[I].Doc.Summary)]);
        LSB.AppendLine;
      end;
      LSB.AppendLine('</table>');

      // Detailed member sections
      for I := 0 to AType.Members.Count - 1 do
        RenderMemberSection(LSB, AType.Members[I], AUnitName);
    end;

    WriteFile('units/' + FileName(AType.FullName),
      WrapPage(AType.FullName, LSB.ToString, LNav));
  finally
    LSB.Free;
  end;
  for I := 0 to AType.NestedTypes.Count - 1 do begin
    if AType.NestedTypes[I].FullName = '' then AType.NestedTypes[I].FullName := AType.FullName + '.' + AType.NestedTypes[I].Name;
    RenderTypePage(AType.NestedTypes[I], AUnitName);
  end;
end;

procedure THTMLDocRenderer.RenderMemberSection(const ABuilder: TStringBuilder;
  const AElem: TElementDocInfo; const AUnitName: string);
begin
  ABuilder.AppendFormat('<div class="member-card" id="%s">',
    [EscapeHtml(Anchor(MemberAnchor(AElem.CodeElement,AElem.Name)))]);
  ABuilder.AppendLine;
  ABuilder.AppendFormat('<div class="member-sig"><span class="badge">%s</span> %s</div>',
    [EscapeHtml(AElem.Kind.ToString), EscapeHtml(AElem.Name)]);
  ABuilder.AppendLine;
  ABuilder.Append(FormatDocToHtml(AElem.Doc, AUnitName));
  ABuilder.AppendLine('</div>');
end;

procedure THTMLDocRenderer.RenderSearchIndex;
var
  LArr: TJSONArray;
  LObj: TJSONObject;
  I, J: Integer;
  LUnit: TUnitDocInfo;
begin
  LArr := TJSONArray.Create;
  try
    for I := 0 to FUnits.Count - 1 do
    begin
      LUnit := FUnits[I];

      LObj := TJSONObject.Create;
      LObj.AddPair('name', LUnit.UnitName);
      LObj.AddPair('type', 'unit');
      LObj.AddPair('url', 'units/' + FileName(LUnit.UnitName));
      LObj.AddPair('summary', LUnit.UnitDoc.Summary);
      LArr.AddElement(LObj);

      for J := 0 to LUnit.Types.Count - 1 do
      begin
        LObj := TJSONObject.Create;
        LObj.AddPair('name', LUnit.Types[J].FullName);
        LObj.AddPair('type', LUnit.Types[J].Kind.ToString);
        LObj.AddPair('url', 'units/' + FileName(LUnit.Types[J].FullName));
        LObj.AddPair('summary', LUnit.Types[J].Doc.Summary);
        LArr.AddElement(LObj);
      end;
    end;

    WriteFile('assets/search-index.json', LArr.ToJSON);
  finally
    LArr.Free;
  end;
end;

end.
