/// <summary>Help and Manual project generation with topic hierarchy and bundled resources.</summary>
unit XmlDoc.HelpGen.Renderer.HMXP;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Xml.XMLIntf, XmlDoc.Model, XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.Renderer, XmlDoc.HelpGen.CrossRef;

type
  THMTopic = class
    ID, Name, FullName, UnitName, Signature, Ancestor, GroupName: string;
    Doc: TXmlDocModel;
    Children: TList<THMTopic>;
    constructor Create;
    destructor Destroy; override;
  end;

  THMXPDocRenderer = class(TInterfacedObject, IDocRenderer)
  private
    FTopics: TObjectList<THMTopic>;
    FSymbols: TDictionary<string, THMTopic>;
    FTopicKeys: TDictionary<string, Integer>;
    FShortNames: TDictionary<string, THMTopic>;
    FOptions: TRenderOptions;
    FUnits:TObjectList<TUnitDocInfo>;
    function AddTopic(const AName, AFullName, AUnitName, ASignature: string;
      ADoc: TXmlDocModel; AParent: THMTopic): THMTopic;
    procedure AddType(AType: TTypeDocInfo; const AUnitName: string; AParent: THMTopic);
    procedure AddElement(AElement: TElementDocInfo; const AUnitName: string; AParent: THMTopic);
    function Visible(const AVisibility: string): Boolean;
    function Resolve(const ACref: string; AContext: THMTopic): string;
    function RenderInline(ANode: IXMLNode; AContext: THMTopic): string;
    function Content(const AText: string; AContext: THMTopic): string;
    function Section(const ATitle, AText: string; AContext: THMTopic): string;
    function TopicBody(ATopic: THMTopic): string;
    function Toc(ATopic: THMTopic): string;
    procedure SortTree(ATopic: THMTopic);
    procedure WriteResources(const ADir, AProjectFile: string);
  public
    procedure Render(const AUnits: TObjectList<TUnitDocInfo>;
      const AResolver: TCrossRefResolver; const AOptions: TRenderOptions);
  end;

implementation

{$R HelpManual.res}

uses
  System.IOUtils, System.Hash, System.JSON, XmlDoc.HelpGen.Navigation, System.StrUtils, System.Generics.Defaults,
  Winapi.Windows, Xml.XMLDoc, XmlDoc.Consts,XmlDoc.HelpGen.Resources;

const
  CProjectFile = 'Documentation.hmxp';
  CXml = '<?xml version="1.0" encoding="UTF-8"?>' + #13#10;

function Esc(const S: string): string;
begin
  Result := S.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
    .Replace('"', '&quot;').Replace('''', '&apos;');
end;

function Text(const S: string): string;
begin
  Result := '<text>' + Esc(S).Replace(#13#10, #10).Replace(#13, #10)
    .Replace(#10, '</text><br/><text>') + '</text>';
end;

function Para(const S: string; const AStyle: string = 'Normal'): string;
begin
  Result := '<para styleclass="' + AStyle + '">' + S + '</para>' + sLineBreak;
end;

function Attr(ANode: IXMLNode; const AName: string): string;
begin
  Result := '';
  if ANode.HasAttribute(AName) then Result := ANode.Attributes[AName];
end;

function NodeText(ANode: IXMLNode): string;
var
  I: Integer;
  LChild: IXMLNode;
begin
  Result := '';
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    LChild := ANode.ChildNodes[I];
    if LChild.NodeType in [ntText, ntCData] then Result := Result + LChild.Text
    else Result := Result + NodeText(LChild);
  end;
end;

constructor THMTopic.Create;
begin
  inherited;
  Children := TList<THMTopic>.Create;
end;

destructor THMTopic.Destroy;
begin
  Children.Free;
  inherited;
end;

function THMXPDocRenderer.Visible(const AVisibility: string): Boolean;
begin
  Result := FOptions.IncludePrivate or
    not (SameText(Trim(AVisibility), 'private') or SameText(Trim(AVisibility), 'strict private'));
end;

function THMXPDocRenderer.AddTopic(const AName, AFullName, AUnitName, ASignature: string;
  ADoc: TXmlDocModel; AParent: THMTopic): THMTopic;
var
  LKey: string;
  LCount: Integer;
begin
  Result := THMTopic.Create;
  FTopics.Add(Result);
  Result.Name := AName;
  Result.FullName := AFullName;
  Result.UnitName := AUnitName;
  Result.Signature := ASignature;
  Result.Doc := ADoc;
  // ASCII IDs avoid path characters, case-folding and generic/overload collisions.
  LKey := AFullName + '|' + ASignature;
  if FTopicKeys.TryGetValue(LKey, LCount) then
    FTopicKeys[LKey] := LCount + 1
  else
  begin
    LCount := 0;
    FTopicKeys.Add(LKey, 1);
  end;
  LKey := LKey + '|' + IntToStr(LCount);
  if FOptions.NumericFileNames then Result.ID := Format('T%.6d', [FTopics.Count])
  else Result.ID := 'T' + THashSHA2.GetHashString(LKey).ToLower;
  if AParent = nil then Exit;
  AParent.Children.Add(Result);
  if not FSymbols.ContainsKey(AFullName) then FSymbols.Add(AFullName, Result) else FSymbols[AFullName]:=nil;
  if FShortNames.ContainsKey(AName) then FShortNames[AName] := nil
  else FShortNames.Add(AName, Result);
end;

procedure THMXPDocRenderer.AddElement(AElement: TElementDocInfo;
  const AUnitName: string; AParent: THMTopic);
var
  LSignature: string;
  LParam: TParamInfo;
  LTopic: THMTopic;
begin
  if not Visible(AElement.Visibility) then Exit;
  LSignature := AElement.Signature;
  if LSignature = '' then
  begin
    LSignature := AElement.CodeElement.MethodKind + ' ' + AElement.Name;
    if Length(AElement.CodeElement.Params) > 0 then
    begin
      LSignature := LSignature + '(';
      for LParam in AElement.CodeElement.Params do
      begin
        if not LSignature.EndsWith('(') then LSignature := LSignature + '; ';
        if LParam.IsConst then LSignature := LSignature + 'const '
        else if LParam.IsVar then LSignature := LSignature + 'var '
        else if LParam.IsOut then LSignature := LSignature + 'out ';
        LSignature := LSignature + LParam.Name + ': ' + LParam.TypeName;
        if LParam.DefaultValue <> '' then LSignature := LSignature + ' = ' + LParam.DefaultValue;
      end;
      LSignature := LSignature + ')';
    end;
    if AElement.CodeElement.ReturnType <> '' then
      LSignature := LSignature + ': ' + AElement.CodeElement.ReturnType;
  end;
  LTopic := AddTopic(AElement.Name, AElement.FullName, AUnitName, Trim(LSignature), AElement.Doc, AParent);
  if AElement.CodeElement.SymbolId<>'' then FSymbols.AddOrSetValue(AElement.CodeElement.SymbolId,LTopic);
  case AElement.Kind of
    dekProperty: LTopic.GroupName := 'Properties';
    dekField: LTopic.GroupName := 'Fields';
    dekConstant: LTopic.GroupName := 'Constants';
    dekType: LTopic.GroupName := 'Types';
  else
    if SameText(AElement.CodeElement.MethodKind, 'constructor') then LTopic.GroupName := 'Constructors'
    else if SameText(AElement.CodeElement.MethodKind, 'destructor') then LTopic.GroupName := 'Destructors'
    else LTopic.GroupName := 'Methods';
  end;
end;

procedure THMXPDocRenderer.AddType(AType: TTypeDocInfo;
  const AUnitName: string; AParent: THMTopic);
var
  LTopic: THMTopic;
  LMember: TElementDocInfo;
  LNested: TTypeDocInfo;
  LInterface: string;
begin
  if not Visible(AType.Visibility) then Exit;
  LTopic := AddTopic(AType.Name, AType.FullName, AUnitName, '', AType.Doc, AParent);
  case AType.Kind of
    dekClass: LTopic.GroupName := 'Classes';
    dekRecord: LTopic.GroupName := 'Records';
    dekInterface: LTopic.GroupName := 'Interfaces';
  else LTopic.GroupName := 'Types';
  end;
  LTopic.Ancestor := AType.Ancestor;
  for LInterface in AType.Implements do
  begin
    if LTopic.Signature <> '' then LTopic.Signature := LTopic.Signature + ', ';
    LTopic.Signature := LTopic.Signature + LInterface;
  end;
  if LTopic.Signature <> '' then LTopic.Signature := 'Implements: ' + LTopic.Signature;
  for LMember in AType.Members do AddElement(LMember, AUnitName, LTopic);
  for LNested in AType.NestedTypes do AddType(LNested, AUnitName, LTopic);
end;

function THMXPDocRenderer.Resolve(const ACref: string; AContext: THMTopic): string;
var
  LTopic: THMTopic;
  LPrefix: string;
  P: Integer;
begin
  Result := '';
  if FSymbols.TryGetValue(ACref, LTopic) and Assigned(LTopic) then Exit(LTopic.ID);
  LPrefix := AContext.FullName;
  repeat
    if FSymbols.TryGetValue(LPrefix + '.' + ACref, LTopic) and Assigned(LTopic) then Exit(LTopic.ID);
    P := LastDelimiter('.', LPrefix);
    if P = 0 then Break;
    LPrefix := Copy(LPrefix, 1, P - 1);
  until LPrefix = '';
  if FSymbols.TryGetValue(AContext.UnitName + '.' + ACref, LTopic) and Assigned(LTopic) then Exit(LTopic.ID);
  if FShortNames.TryGetValue(ACref, LTopic) and Assigned(LTopic) then Result := LTopic.ID;
end;

function THMXPDocRenderer.RenderInline(ANode: IXMLNode; AContext: THMTopic): string;
var
  LChild: IXMLNode;
  LRef, LID, LLabel, LStyle, LInner: string;
  I: Integer;
begin
  Result := '';
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    LChild := ANode.ChildNodes[I];
    if LChild.NodeType in [ntText, ntCData] then
      Result := Result + Text(LChild.Text)
    else
    begin
      LInner := RenderInline(LChild, AContext);
      if (LChild.NodeName = 'see') or (LChild.NodeName = 'seealso') then
      begin
        if Attr(LChild,'href')<>'' then begin
          LRef:=Attr(LChild,'href');
          LInner:=Esc(NodeText(LChild));if LInner='' then LInner:=Esc(LRef);
          if LRef.StartsWith('https://') or LRef.StartsWith('http://') or LRef.StartsWith('mailto:') then
            Result:=Result+'<link type="weblink" displaytype="text" href="'+Esc(LRef)+'">'+LInner+'</link>'
          else Result:=Result+LInner;
          Continue;
        end;
        LRef := Attr(LChild, 'cref');
        LLabel := LInner;
        if LLabel = '' then LLabel := Text(LRef);
        LID := Resolve(LRef, AContext);
        if LID <> '' then
          Result := Result + '<link type="topiclink" displaytype="text" href="' + LID + '">' + Esc(IfThen(NodeText(LChild) <> '', NodeText(LChild), LRef)) + '</link>'
        else Result := Result + LLabel;
      end
      else if (LChild.NodeName = 'paramref') or (LChild.NodeName = 'typeparamref') then
        Result := Result + Text(Attr(LChild, 'name'))
      else if MatchText(LChild.NodeName,['c','b','strong','i','em']) then
      begin
        if LInner='' then Continue;
        LStyle := 'font-family:Courier New;';
        if MatchText(LChild.NodeName,['b','strong']) then LStyle := 'font-weight:bold;';
        if MatchText(LChild.NodeName,['i','em']) then LStyle := 'font-style:italic;';
        Result := Result + '<text style="' + LStyle + '">' + LInner + '</text>';
      end
      else if (LChild.NodeName='image') or (LChild.NodeName='img') then Result:=Result+'<image src="'+Esc(CopyDocumentationImage(Attr(LChild,'src'),AContext.UnitName,FOptions.ProjectDir,TPath.Combine(FOptions.OutputDir,'hmxp'),'Images',FUnits))+'"/>'
      else if LChild.NodeName = 'br' then Result := Result + '<br/>'
      else if LChild.NodeName = 'para' then Result := Result + '<br/>' + LInner + '<br/>'
      else Result := Result + LInner;
    end;
  end;
end;

function THMXPDocRenderer.Content(const AText: string; AContext: THMTopic): string;
var
  LDoc: IXMLDocument;
  LNode, LItem: IXMLNode;
  I, J, K, Number: Integer;
  LPending, LLine, Table, Row, Cell, Prefix, RowTag: string;
begin
  Result := '';
  if AText = '' then Exit;
  try
    LDoc := LoadXMLData('<fragment>' + AText + '</fragment>');
  except
    // Editor text can contain literal &, <, or incomplete inline XML.
    for LLine in AText.Replace(#13#10, #10).Replace(#13, #10).Split([#10]) do
      Result := Result + Para(Text(LLine));
    Exit;
  end;
  LPending := '';
  for I := 0 to LDoc.DocumentElement.ChildNodes.Count - 1 do
  begin
    LNode := LDoc.DocumentElement.ChildNodes[I];
    if (LNode.NodeName='code') and (LNode.Text='') then Continue;
    if (LNode.NodeName = 'para') or (LNode.NodeName = 'code') or (LNode.NodeName = 'list') or (LNode.NodeName='table') then
    begin
      if Trim(LPending) <> '' then Result := Result + Para(LPending);
      LPending := '';
      if LNode.NodeName='table' then begin
        Table:='';var ColumnCount:=0;
        for J:=0 to LNode.ChildNodes.Count-1 do begin
          LItem:=LNode.ChildNodes[J];if LItem.NodeName<>'tr' then Continue;
          Row:='';var Count:=0;var Header:=False;
          for K:=0 to LItem.ChildNodes.Count-1 do begin
            var C:=LItem.ChildNodes[K];if not MatchText(C.NodeName,['td','th']) then Continue;
            Header:=Header or (C.NodeName='th');Inc(Count);Row:=Row+'<td>'+Para(RenderInline(C,AContext))+'</td>';
          end;
          if Count>ColumnCount then ColumnCount:=Count;
          RowTag:='tr';if Header then RowTag:='thead';Table:=Table+'<'+RowTag+'>'+Row+'</'+RowTag+'>';
        end;
        if ColumnCount>0 then Result:=Result+Para('<table colcount="'+IntToStr(ColumnCount)+'">'+Table+'</table>');
      end else if LNode.NodeName = 'list' then
      begin
        if SameText(Attr(LNode,'type'),'table') then begin
          Table:='';for J:=0 to LNode.ChildNodes.Count-1 do begin
            LItem:=LNode.ChildNodes[J];if LItem.NodeType<>ntElement then Continue;
            Row:='';for K:=0 to 1 do begin
              Cell:='';for var C:=0 to LItem.ChildNodes.Count-1 do
                if ((K=0) and (LItem.ChildNodes[C].NodeName='term')) or ((K=1) and (LItem.ChildNodes[C].NodeName='description')) then Cell:=Cell+RenderInline(LItem.ChildNodes[C],AContext);
              Row:=Row+'<td>'+Para(Cell)+'</td>';
            end;
            RowTag:='tr';if LItem.NodeName='listheader' then RowTag:='thead';Table:=Table+'<'+RowTag+'>'+Row+'</'+RowTag+'>';
          end;
          if Table<>'' then Result:=Result+Para('<table colcount="2">'+Table+'</table>');Continue;
        end;
        Number:=0;
        for J := 0 to LNode.ChildNodes.Count - 1 do
        begin
          LItem := LNode.ChildNodes[J];
          if LItem.NodeName='item' then begin
            Inc(Number);if LItem.HasAttribute('number') then TryStrToInt(Attr(LItem,'number'),Number);Prefix:='• ';if SameText(Attr(LNode,'type'),'number') then Prefix:=IntToStr(Number)+'. ';
            Result := Result + Para(Text(Prefix) + RenderInline(LItem, AContext));
          end;
        end;
      end
      else if LNode.NodeName = 'code' then Result := Result + Para(RenderInline(LNode, AContext), 'Code')
      else Result := Result + Para(RenderInline(LNode, AContext));
    end
    else if LNode.NodeType in [ntText, ntCData] then LPending := LPending + Text(LNode.Text)
    else
    begin
      // Reuse the inline converter without losing the enclosing inline element.
      LItem := LDoc.CreateNode('span');
      LItem.ChildNodes.Add(LNode.CloneNode(True));
      LPending := LPending + RenderInline(LItem, AContext);
    end;
  end;
  if LPending <> '' then Result := Result + Para(LPending);
end;

function THMXPDocRenderer.Section(const ATitle, AText: string; AContext: THMTopic): string;
begin
  Result := '';
  if AText <> '' then Result := Para(Text(ATitle), 'Heading2') + Content(AText, AContext);
end;

function THMXPDocRenderer.TopicBody(ATopic: THMTopic): string;
var
  D: TXmlDocModel;
  P: TParamDoc;
  TP: TTypeParamDoc;
  E: TExceptionDoc;
  Ex: TExampleDoc;
  S: TSeeAlsoDoc;
  LChild: THMTopic;
  LID, LGroup: string;
begin
  Result := Para(Text(ATopic.FullName), 'Code');
  if ATopic.Signature <> '' then Result := Result + Para(Text(ATopic.Signature), 'Code');
  if ATopic.Ancestor <> '' then Result := Result + Section('Ancestor', ATopic.Ancestor, ATopic);
  D := ATopic.Doc;
  if D <> nil then
  begin
    Result := Result + Section('Summary', D.Summary, ATopic) + Section('Remarks', D.Remarks, ATopic);
    for P in D.Params do Result := Result + Section('Parameter: ' + P.Name, P.Description, ATopic);
    for TP in D.TypeParams do Result := Result + Section('Type parameter: ' + TP.Name, TP.Description, ATopic);
    Result := Result + Section('Returns', D.Returns, ATopic) + Section('Value', D.Value, ATopic);
    for E in D.Exceptions do Result := Result + Section('Exception: ' + E.TypeRef, E.Description, ATopic);
    for Ex in D.Examples do
    begin
      if Ex.SourceFile<>'' then Result:=Result+Para('<link type="filelink" displaytype="text" href="../Baggage/'+Esc(CopyDocumentationSource(Ex.SourceFile,ATopic.UnitName,FOptions.ProjectDir,TPath.Combine(FOptions.OutputDir,'hmxp'),'Baggage',FUnits))+'">'+Esc('Source: '+Ex.SourceFile+' '+Ex.Region)+'</link>');
      Result := Result + Para(Text('Example ' + Ex.Title), 'Heading2') + Content(Ex.Description, ATopic);
      for LID in Ex.Code.Replace(#13#10, #10).Replace(#13, #10).Split([#10]) do
        Result := Result + Para(Text(LID), 'Code');
    end;
    for S in D.SeeAlso do
    begin
      LID := Resolve(S.Cref, ATopic);
      if LID <> '' then Result := Result + Para('<link type="topiclink" displaytype="text" href="' + LID + '">' + Esc(S.Cref) + '</link>')
      else Result := Result + Para(Text(S.Cref));
      Result := Result + Content(S.Description, ATopic);
    end;
  end;
  if ATopic.Children.Count > 0 then
  begin
    Result := Result + Para(Text('Contents'), 'Heading2');
    LGroup := '';
    for LChild in ATopic.Children do
    begin
      if LChild.GroupName <> LGroup then
      begin
        LGroup := LChild.GroupName;
        if LGroup <> '' then Result := Result + Para(Text(LGroup), 'Heading2');
      end;
      Result := Result + Para('<link type="topiclink" displaytype="text" href="' + LChild.ID + '">' + Esc(LChild.Name) + '</link>');
    end;
  end;
end;

procedure THMXPDocRenderer.SortTree(ATopic: THMTopic);
var LChild: THMTopic;
begin
  ATopic.Children.Sort(TComparer<THMTopic>.Construct(
    function(const Left, Right: THMTopic): Integer
    begin
      Result := CompareText(Left.GroupName, Right.GroupName);
      if Result = 0 then Result := CompareText(Left.Name, Right.Name);
      if Result = 0 then Result := CompareStr(Left.Signature, Right.Signature);
      if Result = 0 then Result := CompareStr(Left.ID, Right.ID);
    end));
  for LChild in ATopic.Children do SortTree(LChild);
end;

function THMXPDocRenderer.Toc(ATopic: THMTopic): string;
var LChild: THMTopic; LGroup: string;
begin
  Result := '<topicref type="topic" build="ALL" href="' + ATopic.ID + '"><caption>' + Esc(ATopic.Name) + '</caption>';
  LGroup := '';
  for LChild in ATopic.Children do
  begin
    if LChild.GroupName <> LGroup then
    begin
      if LGroup <> '' then Result := Result + '</topicref>';
      LGroup := LChild.GroupName;
      if LGroup <> '' then Result := Result + '<topicref type="topic" build="ALL"><caption>' + Esc(LGroup) + '</caption>';
    end;
    Result := Result + Toc(LChild);
  end;
  if LGroup <> '' then Result := Result + '</topicref>';
  Result := Result + '</topicref>' + sLineBreak;
end;

function ResourceText(const AName: string): string;
var S: TResourceStream; B: TBytes;
begin
  S := TResourceStream.Create(FindClassHInstance(THMXPDocRenderer), AName, RT_RCDATA);
  try
    SetLength(B, S.Size);
    S.ReadBuffer(B, Length(B));
    Result := TEncoding.UTF8.GetString(B);
    if Result.StartsWith(#$FEFF) then Delete(Result, 1, 1);
  finally S.Free; end;
end;

procedure THMXPDocRenderer.WriteResources(const ADir, AProjectFile: string);
var S: string;
begin
  S := ResourceText('XMLDOC_HM_SCHEMA').Replace('schemaLocation="http://www.w3.org/XML/1998/namespace"', 'schemaLocation="xml.xsd"');
  TFile.WriteAllText(TPath.Combine(ADir, 'helpproject.xsd'), S, TEncoding.UTF8);
  S := ResourceText('XMLDOC_HM_STYLESHEET');
  S := S.Replace(CProjectFile, Esc(AProjectFile.Replace('%', '%25').Replace('#', '%23').Replace('''', '%27').Replace(' ', '%20')));
  TFile.WriteAllText(TPath.Combine(ADir, 'helpproject.xsl'), S, TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(ADir, 'xml.xsd'), CXml +
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://www.w3.org/XML/1998/namespace">' +
    '<xs:attribute name="base" type="xs:anyURI"/></xs:schema>', TEncoding.UTF8);
end;

function ManagedTopicPath(const S: string): Boolean;
var I: Integer;
begin
  Result := (Length(S) = 76) and S.StartsWith('Topics/T') and S.EndsWith('.xml');
  if not Result then Exit;
  for I := 9 to 72 do
    if not CharInSet(S[I], ['0'..'9', 'a'..'f']) then Exit(False);
end;

procedure THMXPDocRenderer.Render(const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver; const AOptions: TRenderOptions);
var
  LRoot, LUnit, LTopic: THMTopic;
  U: TUnitDocInfo;
  T: TTypeDocInfo;
  E: TElementDocInfo;
  LDir, LProject, LStyles, LName, LStyle, LFiles, LProjectFile: string;
  LPrevious, LCurrent: TStringList;
  TopicMap, Entry: TJSONObject;
  LDoc: IXMLDocument;
  LFileNodes: IXMLNode;
  I: Integer;
begin
  SortDocumentation(AUnits);
  FOptions := AOptions;FUnits:=AUnits;
  LDir := TPath.Combine(AOptions.OutputDir, 'hmxp');
  LProjectFile := CProjectFile;
  if AOptions.ProjectName <> '' then
    LProjectFile := TPath.GetFileName(AOptions.ProjectName) + '.hmxp';
  LPrevious := TStringList.Create;
  LCurrent := TStringList.Create;
  FTopics := TObjectList<THMTopic>.Create(True);
  FTopicKeys := TDictionary<string, Integer>.Create(TIStringComparer.Ordinal);
  FSymbols := TDictionary<string, THMTopic>.Create(TIStringComparer.Ordinal);
  FShortNames := TDictionary<string, THMTopic>.Create(TIStringComparer.Ordinal);
  try
    if TFile.Exists(TPath.Combine(LDir, LProjectFile)) then
    try
      LDoc := LoadXMLDocument(TPath.Combine(LDir, LProjectFile));
      LFileNodes := LDoc.DocumentElement.ChildNodes.FindNode('project-files');
      if Assigned(LFileNodes) then
        for I := 0 to LFileNodes.ChildNodes.Count - 1 do
        begin
          LName := Attr(LFileNodes.ChildNodes[I], 'href');
          if ManagedTopicPath(LName) then LPrevious.Add(LName);
        end;
    except
      // Preserve unrecognized files if a previous project was edited or damaged.
      LPrevious.Clear;
    end;
    LDoc := nil;
    LFileNodes := nil;
    LName := AOptions.Title;
    if LName = '' then LName := 'API Reference';
    LRoot := AddTopic(LName, LName, '', '', nil, nil);
    for U in AUnits do
    begin
      LUnit := AddTopic(U.UnitName, U.UnitName, U.UnitName, '', U.UnitDoc, LRoot);
      for T in U.Types do AddType(T, U.UnitName, LUnit);
      for E in U.StandaloneMethods do
      begin
        AddElement(E, U.UnitName, LUnit);
        if Visible(E.Visibility) then
          if E.Kind = dekField then FTopics.Last.GroupName := 'Variables'
          else FTopics.Last.GroupName := 'Routines';
      end;
      for E in U.Constants do AddElement(E, U.UnitName, LUnit);
      for E in U.Variables do
      begin
        AddElement(E, U.UnitName, LUnit);
        if Visible(E.Visibility) then FTopics.Last.GroupName := 'Variables';
      end;
    end;
    SortTree(LRoot);
    for LName in ['Topics', 'Maps', 'Baggage', 'Images'] do
      TDirectory.CreateDirectory(TPath.Combine(LDir, LName));
    WriteResources(LDir, LProjectFile);
    if AOptions.NumericFileNames then begin
      TopicMap := TJSONObject.Create;
      try
        for LTopic in FTopics do begin
          Entry := TJSONObject.Create;
          Entry.AddPair('symbol', LTopic.FullName);
          Entry.AddPair('signature', LTopic.Signature);
          Entry.AddPair('file', 'Topics/' + LTopic.ID + '.xml');
          TopicMap.AddPair(LTopic.ID, Entry);
        end;
        TFile.WriteAllBytes(TPath.Combine(LDir, 'Baggage/topic-map.json'), TEncoding.UTF8.GetBytes(TopicMap.Format(2)));
      finally TopicMap.Free; end;
    end;
    LStyles := '';
    for LName in ['Normal', 'Heading1', 'Heading2', 'Code'] do
    begin
      LStyle := 'font-family:Segoe UI;font-size:10pt;';
      if LName = 'Heading1' then LStyle := 'font-family:Segoe UI;font-size:20pt;font-weight:bold;';
      if LName = 'Heading2' then LStyle := 'font-family:Segoe UI;font-size:14pt;font-weight:bold;';
      if LName = 'Code' then LStyle := 'font-family:Consolas;font-size:10pt;white-space:pre-wrap;';
      LStyles := LStyles + '<styleclass name="' + LName + '"><style-set media="screen" type="text">' + LStyle + '</style-set></styleclass>';
    end;
    LFiles := '';
    for LTopic in FTopics do
    begin
      LCurrent.Add('Topics/' + LTopic.ID + '.xml');
      LFiles := LFiles + '<file href="Topics/' + LTopic.ID + '.xml" build="ALL" filetype="topic"/>';
    end;
    LProject := CXml + '<helpproject xmlns:xi="http://www.w3.org/2001/XInclude"><config>' +
      '<config-group name="project"><config-value name="title">' + Esc(LRoot.Name) + '</config-value>' +
      '<config-value name="lcid">en-us</config-value><config-value name="charset">ANSI_CHARSET</config-value>' +
      '<config-value name="searchpath">.\Images\</config-value></config-group>' +
      '<styleclasses>' + LStyles + '</styleclasses></config>' +
      '<xi:include parse="xml" href="Maps/table_of_contents.xml"/>' +
      '<project-files>' + LFiles +
      '<file href="Baggage/*.*" build="ALL" filetype="baggage"/></project-files></helpproject>';
    TFile.WriteAllText(TPath.Combine(LDir, LProjectFile), LProject, TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LDir, 'Maps\table_of_contents.xml'), CXml + '<map>' + Toc(LRoot) + '</map>', TEncoding.UTF8);
    for LTopic in FTopics do
      TFile.WriteAllText(TPath.Combine(LDir, 'Topics\' + LTopic.ID + '.xml'), CXml +
        '<?xml-stylesheet type="text/xsl" href="../helpproject.xsl"?>' + sLineBreak +
        '<topic template="Default" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../helpproject.xsd">' +
        '<title>' + Esc(LTopic.Name) + '</title><keywords><keyword>' + Esc(LTopic.FullName) +
        '</keyword></keywords><body><header>' + Para(Text(LTopic.Name), 'Heading1') + '</header>' +
        TopicBody(LTopic) + '</body></topic>', TEncoding.UTF8);
    for LName in LPrevious do
      if (LCurrent.IndexOf(LName) < 0) and TFile.Exists(TPath.Combine(LDir, LName)) then
        TFile.Delete(TPath.Combine(LDir, LName));
  finally
    LPrevious.Free;
    LCurrent.Free;
    FShortNames.Free;
    FSymbols.Free;
    FTopicKeys.Free;
    FTopics.Free;
  end;
end;

end.
