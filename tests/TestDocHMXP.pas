unit TestDocHMXP;

interface
uses DUnitX.TestFramework;
type
  [TestFixture]
  TTestHMXP = class
  public
    [Test] procedure TestCompleteProjectAndStableIDs;
    [Test] procedure TestEmptyProject;
  end;

implementation
uses
  System.SysUtils, System.StrUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  Xml.XMLDoc, Xml.XMLIntf, XmlDoc.Consts, XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.Renderer, XmlDoc.HelpGen.Renderer.HMXP;

procedure TTestHMXP.TestCompleteProjectAndStableIDs;
var
  Units: TObjectList<TUnitDocInfo>;
  U: TUnitDocInfo;
  T, N: TTypeDocInfo;
  M: TElementDocInfo;
  P: TParamDoc;
  TP: TTypeParamDoc;
  Ex: TExampleDoc;
  E: TExceptionDoc;
  S: TSeeAlsoDoc;
  Opts: TRenderOptions;
  Renderer: IDocRenderer;
  Project: IXMLDocument;
  Files: IXMLNode;
  IDs: TList<string>;
  I: Integer;
  Path, Combined, ID: string;
  function Element(const Name, FullName: string): TElementDocInfo;
  begin
    Result := TElementDocInfo.Create;
    Result.Name := Name;
    Result.FullName := FullName;
    Result.Doc.Summary := 'Documentation for ' + Name;
  end;
begin
  Units := TObjectList<TUnitDocInfo>.Create(True);
  IDs := TList<string>.Create;
  try
    U := TUnitDocInfo.Create;
    Units.Add(U);
    U.UnitName := 'Sample.Юнит';
    U.UnitDoc.Summary := 'Обзор & специальные символы';
    T := TTypeDocInfo.Create;
    U.Types.Add(T);
    T.Name := 'TThing<T>';
    T.FullName := U.UnitName + '.' + T.Name;
    T.Ancestor := 'TObject';
    T.Doc.Summary := 'Тип <c>T' + sLineBreak + '  value</c>.';
    N := TTypeDocInfo.Create;
    T.NestedTypes.Add(N);
    N.Name := 'TNested';
    N.FullName := T.FullName + '.TNested';
    N.Doc.Summary := 'Nested type';
    for I := 0 to 1 do
    begin
      M := Element('Run', T.FullName + '.Run');
      T.Members.Add(M);
      M.Signature := 'procedure Run(X: ' + IfThen(I = 0, 'Integer', 'string') + '); overload;';
      M.Doc.Summary := 'До <see cref="TThing&lt;T&gt;">типа</see> после <paramref name="X"/>.';
      M.Doc.Remarks := '<para>First paragraph.</para><para>Second paragraph.</para>';
      M.Doc.Returns := 'Result description';
      M.Doc.Value := 'Property value';
      P.Name := 'X'; P.Description := 'Parameter documentation'; M.Doc.Params.Add(P);
      TP.Name := 'T'; TP.Description := 'Type parameter documentation'; M.Doc.TypeParams.Add(TP);
      Ex.Title := 'Example'; Ex.Description := 'Sample description';
      Ex.Code := 'if A < B then Run("x");' + sLineBreak + '  // keep indentation & Unicode: тест';
      M.Doc.Examples.Add(Ex);
      E.TypeRef := 'EArgumentException'; E.Description := 'Invalid argument'; M.Doc.Exceptions.Add(E);
      S.Cref := T.FullName; S.Description := 'Related type'; M.Doc.SeeAlso.Add(S);
      S.Cref := 'Missing.External'; S.Description := ''; M.Doc.SeeAlso.Add(S);
    end;
    M := Element('Secret', T.FullName + '.Secret'); M.Visibility := 'strict private'; T.Members.Add(M);
    M := Element('Limit', U.UnitName + '.Limit'); U.Constants.Add(M);
    M := Element('State', U.UnitName + '.State'); U.Variables.Add(M);
    M := Element('Execute', U.UnitName + '.Execute'); U.StandaloneMethods.Add(M);
    Opts := Default(TRenderOptions);
    Opts.Title := 'API & справочник <demo>';
    Opts.OutputDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'HMXPFixture');
    Renderer := THMXPDocRenderer.Create;
    Renderer.Render(Units, nil, Opts);
    Path := TPath.Combine(Opts.OutputDir, 'hmxp');
    Project := LoadXMLDocument(TPath.Combine(Path, 'Documentation.hmxp'));
    Assert.AreEqual(Opts.Title, Project.DocumentElement.ChildNodes['config'].ChildNodes['config-group'].ChildNodes['config-value'].Text);
    Files := Project.DocumentElement.ChildNodes['project-files'];
    Assert.AreEqual(10, Files.ChildNodes.Count); // 9 topics plus baggage
    Combined := '';
    for I := 0 to Files.ChildNodes.Count - 1 do
    begin
      if string(Files.ChildNodes[I].Attributes['filetype']) <> 'topic' then Continue;
      ID := string(Files.ChildNodes[I].Attributes['href']);
      Assert.IsFalse(IDs.Contains(ID), 'Each overloaded member needs a unique topic');
      IDs.Add(ID);
      Assert.IsTrue(TFile.Exists(TPath.Combine(Path, ID)));
      Combined := Combined + TFile.ReadAllText(TPath.Combine(Path, ID), TEncoding.UTF8);
    end;
    Assert.IsTrue(Combined.Contains('if A &lt; B then Run(&quot;x&quot;);'));
    Assert.IsTrue(Combined.Contains('Type parameter documentation'));
    Assert.IsTrue(Combined.Contains('<br/>'));
    Assert.IsTrue(Combined.Contains('Parameter documentation'));
    Assert.IsTrue(Combined.Contains('Invalid argument'));
    Assert.IsTrue(Combined.Contains('type="topiclink"'));
    Assert.IsTrue(Combined.Contains('Missing.External'));
    Assert.IsFalse(Combined.Contains('Secret'));
    Assert.IsTrue(TFile.Exists(TPath.Combine(Path, 'helpproject.xsd')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(Path, 'helpproject.xsl')));
    Opts.IncludePrivate := True;
    Renderer.Render(Units, nil, Opts);
    Project := LoadXMLDocument(TPath.Combine(Path, 'Documentation.hmxp'));
    Assert.AreEqual(11, Project.DocumentElement.ChildNodes['project-files'].ChildNodes.Count);
    Opts.IncludePrivate := False;
    Renderer.Render(Units, nil, Opts);
    Project := LoadXMLDocument(TPath.Combine(Path, 'Documentation.hmxp'));
    Files := Project.DocumentElement.ChildNodes['project-files'];
    Assert.AreEqual(10, Files.ChildNodes.Count);
    Assert.AreEqual<NativeInt>(9, Length(TDirectory.GetFiles(TPath.Combine(Path, 'Topics'), '*.xml')));
    for I := 0 to IDs.Count - 1 do
      Assert.AreEqual(IDs[I], string(Files.ChildNodes[I].Attributes['href']));
  finally
    IDs.Free;
    Units.Free;
  end;
end;

procedure TTestHMXP.TestEmptyProject;
var Units: TObjectList<TUnitDocInfo>; Opts: TRenderOptions; Renderer: IDocRenderer;
begin
  Units := TObjectList<TUnitDocInfo>.Create(True);
  try
    Opts := Default(TRenderOptions);
    Opts.OutputDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'HMXPEmpty');
    Renderer := THMXPDocRenderer.Create;
    Renderer.Render(Units, nil, Opts);
    Assert.IsTrue(TFile.Exists(TPath.Combine(Opts.OutputDir, 'hmxp\Documentation.hmxp')));
  finally Units.Free; end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHMXP);
end.
