unit XmlDoc.HelpGen.Renderer.MD;

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
  /// <summary>GitHub Wiki / GitBook 호환 Markdown 문서를 생성합니다.</summary>
  TMarkdownDocRenderer = class(TInterfacedObject, IDocRenderer)
  private
    FOptions: TRenderOptions;
    FNames: TTopicNameMap;
    FResolver: TCrossRefResolver;
    FUnits: TObjectList<TUnitDocInfo>;

    function FormatDocToMD(const ADoc: TXmlDocModel; const AUnitName: string): string;
    function MakeMDLink(const ACref, AUnitName: string): string;
    procedure RenderReadme;
    procedure RenderSidebar;
    procedure RenderSummary;
    procedure RenderTypeMD(const AType: TTypeDocInfo; const AUnitName: string);
    procedure RenderUnitMD(const AUnit: TUnitDocInfo);
    procedure WriteFile(const ARelPath, AContent: string);

  public
    destructor Destroy; override;
    procedure Render(
      const AUnits: TObjectList<TUnitDocInfo>;
      const AResolver: TCrossRefResolver;
      const AOptions: TRenderOptions
    );
  end;

implementation

uses XmlDoc.HelpGen.Resources,XmlDoc.Markup;


{ TMarkdownDocRenderer }

destructor TMarkdownDocRenderer.Destroy;
begin FNames.Free; inherited; end;

procedure TMarkdownDocRenderer.Render(
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
  FNames := TTopicNameMap.Create(AUnits, AOptions.NumericFileNames);

  TDirectory.CreateDirectory(FOptions.OutputDir);
  TDirectory.CreateDirectory(TPath.Combine(FOptions.OutputDir, 'units'));
  FNames.Save(TPath.Combine(FOptions.OutputDir, 'topic-map.json'));

  RenderReadme;
  RenderSummary;
  RenderSidebar;

  for I := 0 to AUnits.Count - 1 do
  begin
    RenderUnitMD(AUnits[I]);

    for J := 0 to AUnits[I].Types.Count - 1 do
      RenderTypeMD(AUnits[I].Types[J], AUnits[I].UnitName);
  end;
end;

function TMarkdownDocRenderer.FormatDocToMD(const ADoc: TXmlDocModel;
  const AUnitName: string): string;
var
  LSB: TStringBuilder;
  I: Integer;
  function RenderProse(const Text:string):string;
  begin Result:=MarkupMarkdown(Text,function(Cref:string):string begin Result:=MakeMDLink(Cref,AUnitName);end,function(Source:string):string begin Result:='../assets/'+CopyDocumentationImage(Source,AUnitName,FOptions.ProjectDir,FOptions.OutputDir,'assets',FUnits);end);end;
begin
  LSB := TStringBuilder.Create;
  try
    if ADoc.Summary <> '' then
    begin
      LSB.AppendLine(RenderProse(ADoc.Summary));
      LSB.AppendLine;
    end;

    if ADoc.Remarks <> '' then
    begin
      LSB.AppendLine('## Remarks');
      LSB.AppendLine;
      LSB.AppendLine(RenderProse(ADoc.Remarks));
      LSB.AppendLine;
    end;

    if ADoc.Params.Count > 0 then
    begin
      LSB.AppendLine('**Parameters:**');
      LSB.AppendLine;
      for I := 0 to ADoc.Params.Count - 1 do
        LSB.AppendLine('- **' + ADoc.Params[I].Name + '** — ' + RenderProse(ADoc.Params[I].Description));
      LSB.AppendLine;
    end;

    if ADoc.Returns <> '' then
    begin
      LSB.AppendLine('**Returns:** ' + RenderProse(ADoc.Returns));
      LSB.AppendLine;
    end;

    if ADoc.Exceptions.Count > 0 then
    begin
      LSB.AppendLine('**Raises:**');
      LSB.AppendLine;
      for I := 0 to ADoc.Exceptions.Count - 1 do
      begin
        LSB.AppendLine('- `' + ADoc.Exceptions[I].TypeRef + '` — ' +
          RenderProse(ADoc.Exceptions[I].Description));
      end;
      LSB.AppendLine;
    end;

    if ADoc.Value <> '' then
      LSB.AppendLine('**Value:** ' + RenderProse(ADoc.Value) + sLineBreak);
    if ADoc.TypeParams.Count > 0 then
    begin
      LSB.AppendLine('**Type Parameters:**');
      for I := 0 to ADoc.TypeParams.Count - 1 do
        LSB.AppendLine('- **' + ADoc.TypeParams[I].Name + '**: ' + RenderProse(ADoc.TypeParams[I].Description));
      LSB.AppendLine;
    end;
    for I := 0 to ADoc.Examples.Count - 1 do
    begin
      LSB.AppendLine('## Example ' + ADoc.Examples[I].Title);
      if ADoc.Examples[I].SourceFile<>'' then LSB.AppendLine('Source: ['+ADoc.Examples[I].SourceFile+'](../assets/'+CopyDocumentationSource(ADoc.Examples[I].SourceFile,AUnitName,FOptions.ProjectDir,FOptions.OutputDir,'assets',FUnits)+') '+ADoc.Examples[I].Region+sLineBreak);
      LSB.AppendLine(RenderProse(ADoc.Examples[I].Description) + sLineBreak);
      LSB.AppendLine('```pascal');
      LSB.AppendLine(ADoc.Examples[I].Code);
      LSB.AppendLine('```' + sLineBreak);
    end;
    if ADoc.SeeAlso.Count > 0 then
    begin
      LSB.AppendLine('**See Also:**');
      LSB.AppendLine;
      for I := 0 to ADoc.SeeAlso.Count - 1 do
        LSB.AppendLine('- ' + MakeMDLink(ADoc.SeeAlso[I].Cref, AUnitName) + ' ' + RenderProse(ADoc.SeeAlso[I].Description));
      LSB.AppendLine;
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TMarkdownDocRenderer.MakeMDLink(const ACref, AUnitName: string): string;
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
    if SameText(ACref, U.UnitName) then Href := FNames.FileName(U.UnitName, '.md');
    for T in U.Types do
    begin
      if Matches(T.FullName, T.Name) then Href := FNames.FileName(T.FullName, '.md');
      for E in T.Members do
        if SameText(Resolved,E.CodeElement.SymbolId) or Matches(E.FullName, T.Name + '.' + E.Name) then
          Href := FNames.FileName(T.FullName, '.md') + '#' + LowerCase(MemberAnchor(E.CodeElement,E.Name));
    end;
    for E in U.StandaloneMethods do
      if SameText(Resolved,E.CodeElement.SymbolId) or Matches(E.FullName, E.Name) then Href := FNames.FileName(U.UnitName, '.md') + '#' + LowerCase(MemberAnchor(E.CodeElement,E.Name));
    for E in U.Constants do
      if SameText(Resolved,E.CodeElement.SymbolId) or Matches(E.FullName, E.Name) then Href := FNames.FileName(U.UnitName, '.md') + '#' + LowerCase(MemberAnchor(E.CodeElement,E.Name));
  end;
  Result := '`' + ACref + '`';
  if Href <> '' then Result := '[' + Result + '](' + Href + ')';
end;

procedure TMarkdownDocRenderer.WriteFile(const ARelPath, AContent: string);
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

procedure TMarkdownDocRenderer.RenderReadme;
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('# ' + FOptions.Title);
    LSB.AppendLine;
    LSB.AppendLine('## Units');
    LSB.AppendLine;
    LSB.AppendLine('| Unit | Description |');
    LSB.AppendLine('|------|-------------|');

    for I := 0 to FUnits.Count - 1 do
    begin
      LSB.AppendFormat('| [%s](units/%s) | %s |',
        [FUnits[I].UnitName, FNames.FileName(FUnits[I].UnitName, '.md'), FUnits[I].UnitDoc.Summary]);
      LSB.AppendLine;
    end;

    WriteFile('README.md', LSB.ToString);
  finally
    LSB.Free;
  end;
end;

function MarkdownNav(Node: TDocNavNode; Level: Integer): string;
var Child: TDocNavNode;
begin
  Result := StringOfChar(' ', Level * 2) + '- ';
  if Node.Target <> '' then Result := Result + '[' + Node.Caption + '](' + Node.Target + ')'
  else Result := Result + '**' + Node.Caption + '**';
  Result := Result + sLineBreak;
  for Child in Node.Children do Result := Result + MarkdownNav(Child, Level + 1);
end;

procedure TMarkdownDocRenderer.RenderSummary;
var Root: TDocNavNode;
begin
  Root := BuildNavigation(FUnits, FOptions.Title, '.md', False, FOptions.NumericFileNames);
  try WriteFile('SUMMARY.md', '# Summary' + sLineBreak + sLineBreak + MarkdownNav(Root, 0));
  finally Root.Free; end;
end;

procedure TMarkdownDocRenderer.RenderSidebar;
var Root: TDocNavNode;
begin
  Root := BuildNavigation(FUnits, FOptions.Title, '.md', False, FOptions.NumericFileNames);
  try WriteFile('_sidebar.md', MarkdownNav(Root, 0));
  finally Root.Free; end;
end;

procedure TMarkdownDocRenderer.RenderUnitMD(const AUnit: TUnitDocInfo);
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('# ' + AUnit.UnitName);
    LSB.AppendLine;
    LSB.Append(FormatDocToMD(AUnit.UnitDoc, AUnit.UnitName));

    // Types
    if AUnit.Types.Count > 0 then
    begin
      LSB.AppendLine('## Types');
      LSB.AppendLine;
      LSB.AppendLine('| Type | Kind | Description |');
      LSB.AppendLine('|------|------|-------------|');

      for I := 0 to AUnit.Types.Count - 1 do
      begin
        LSB.AppendFormat('| [`%s`](%s) | %s | %s |',
          [AUnit.Types[I].Name,
           FNames.FileName(AUnit.UnitName + '.' + AUnit.Types[I].Name, '.md'),
           AUnit.Types[I].Kind.ToString,
           AUnit.Types[I].Doc.Summary]);
        LSB.AppendLine;
      end;

      LSB.AppendLine;
    end;

    // Standalone methods
    if AUnit.StandaloneMethods.Count > 0 then
    begin
      LSB.AppendLine('## Functions & Procedures');
      LSB.AppendLine;
      for I := 0 to AUnit.StandaloneMethods.Count - 1 do
      begin
        if AUnit.StandaloneMethods[I].CodeElement.IsOverload then LSB.AppendLine('<a id="'+LowerCase(MemberAnchor(AUnit.StandaloneMethods[I].CodeElement,AUnit.StandaloneMethods[I].Name))+'"></a>');
        LSB.AppendLine('### ' + AUnit.StandaloneMethods[I].Name);
        LSB.AppendLine;
        LSB.Append(FormatDocToMD(AUnit.StandaloneMethods[I].Doc, AUnit.UnitName));
      end;
    end;

    // Constants
    if AUnit.Constants.Count > 0 then
    begin
      LSB.AppendLine('## Constants');
      LSB.AppendLine;
      for I := 0 to AUnit.Constants.Count - 1 do
      begin
        if AUnit.Constants[I].CodeElement.IsOverload then LSB.AppendLine('<a id="'+LowerCase(MemberAnchor(AUnit.Constants[I].CodeElement,AUnit.Constants[I].Name))+'"></a>');
        LSB.AppendLine('### `' + AUnit.Constants[I].Name + '`');
        LSB.AppendLine;
        LSB.Append(FormatDocToMD(AUnit.Constants[I].Doc, AUnit.UnitName));
      end;
    end;

    if AUnit.Variables.Count > 0 then begin
      LSB.AppendLine('## Variables');
      for I := 0 to AUnit.Variables.Count - 1 do begin
        if AUnit.Variables[I].CodeElement.IsOverload then LSB.AppendLine('<a id="'+LowerCase(MemberAnchor(AUnit.Variables[I].CodeElement,AUnit.Variables[I].Name))+'"></a>');
        LSB.AppendLine('### ' + AUnit.Variables[I].Name);
        LSB.Append(FormatDocToMD(AUnit.Variables[I].Doc, AUnit.UnitName));
      end;
    end;
    WriteFile('units/' + FNames.FileName(AUnit.UnitName, '.md'), LSB.ToString);
  finally
    LSB.Free;
  end;
end;

procedure TMarkdownDocRenderer.RenderTypeMD(const AType: TTypeDocInfo; const AUnitName: string);
var
  LSB: TStringBuilder;
  I: Integer;
begin
  if AType.FullName = '' then AType.FullName := AUnitName + '.' + AType.Name;
  LSB := TStringBuilder.Create;
  try
    LSB.AppendFormat('# %s `%s`', [AType.Kind.ToString, AType.Name]);
    LSB.AppendLine;
    LSB.AppendLine;

    if AType.Ancestor <> '' then
    begin
      LSB.AppendLine('Inherits from `' + AType.Ancestor + '`');
      LSB.AppendLine;
    end;

    LSB.Append(FormatDocToMD(AType.Doc, AUnitName));

    // Members
    if AType.Members.Count > 0 then
    begin
      LSB.AppendLine('## Members');
      LSB.AppendLine;
      LSB.AppendLine('| Name | Kind | Visibility | Description |');
      LSB.AppendLine('|------|------|------------|-------------|');

      for I := 0 to AType.Members.Count - 1 do
      begin
        LSB.AppendFormat('| `%s` | %s | %s | %s |',
          [AType.Members[I].Name,
           AType.Members[I].Kind.ToString,
           AType.Members[I].Visibility,
           AType.Members[I].Doc.Summary]);
        LSB.AppendLine;
      end;

      LSB.AppendLine;

      // Detailed member sections
      for I := 0 to AType.Members.Count - 1 do
      begin
        if AType.Members[I].CodeElement.IsOverload then LSB.AppendLine('<a id="'+LowerCase(MemberAnchor(AType.Members[I].CodeElement,AType.Members[I].Name))+'"></a>');
        LSB.AppendLine('### ' + AType.Members[I].Name);
        LSB.AppendLine;
        LSB.Append(FormatDocToMD(AType.Members[I].Doc, AUnitName));
      end;
    end;

    WriteFile('units/' + FNames.FileName(AType.FullName, '.md'), LSB.ToString);
  finally
    LSB.Free;
  end;
  for I := 0 to AType.NestedTypes.Count - 1 do begin
    if AType.NestedTypes[I].FullName = '' then AType.NestedTypes[I].FullName := AType.FullName + '.' + AType.NestedTypes[I].Name;
    RenderTypeMD(AType.NestedTypes[I], AUnitName);
  end;
end;

end.
