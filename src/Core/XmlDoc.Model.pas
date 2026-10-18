unit XmlDoc.Model;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  Xml.XMLDoc,
  Xml.XMLIntf,
  XmlDoc.Consts;

type
  /// <summary>XML Documentation 주석의 구조화된 모델</summary>
  TXmlDocModel = class
  private
    FExamples: TList<TExampleDoc>;
    FExceptions: TList<TExceptionDoc>;
    FIsModified: Boolean;
    FParams: TList<TParamDoc>;
    FRemarks: string;
    FReturns: string;
    FSeeAlso: TList<TSeeAlsoDoc>;
    FSummary: string;
    FTypeParams: TList<TTypeParamDoc>;
    FValue: string;

    FOnChanged: TNotifyEvent;
    FSourceXml, FOriginalCanonical, FParseError, FInheritedFrom: string;
    FParseErrorLine,FParseErrorColumn:Integer;
    procedure ClearContent;
    function SerializeKnownXml: string;

    procedure DoChanged;
    function  EscapeXml(const AText: string): string;
    function  ExtractInlineContent(const ANode: IXMLNode; AExcludeCode: Boolean = False): string;
    function  ExtractNodeText(const ANode: IXMLNode): string;
    function  GetIsEmpty: Boolean;
    procedure ParseChildNodes(const AParentNode: IXMLNode);
    procedure SetRemarks(const AValue: string);
    procedure SetReturns(const AValue: string);
    procedure SetSummary(const AValue: string);
    procedure SetValue(const AValue: string);
    function  TrimDocText(const AText: string): string;
    function  UnescapeXml(const AText: string): string;
    function  WrapParaTags(const AText: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>다른 모델의 내용을 복사합니다.</summary>
    /// <param name="ASource">복사할 원본 모델</param>
    procedure Assign(ASource: TXmlDocModel);
    procedure MergeMissing(ASource:TXmlDocModel;const SourceSymbol:string);

    /// <summary>모든 필드를 초기화합니다.</summary>
    procedure Clear;

    /// <summary>JSON 문자열에서 모델을 로드합니다 (WebView 수신용).</summary>
    /// <param name="AJson">파싱할 JSON 문자열</param>
    procedure FromJson(const AJson: string);

    /// <summary>XML 문자열에서 모델을 로드합니다.</summary>
    /// <param name="AXml">파싱할 XML 문자열 (doc 루트 또는 개별 태그들)</param>
    procedure LoadFromXml(const AXml: string);

    /// <summary>모델을 XML 문자열로 변환합니다.</summary>
    /// <returns>XML 문서 주석 형식의 문자열</returns>
    function ToXml: string;

    /// <summary>모델을 JSON 문자열로 변환합니다 (WebView 전달용).</summary>
    /// <returns>JSON 형식 문자열</returns>
    function ToJson: string;

    property InheritedFrom:string read FInheritedFrom write FInheritedFrom;
    property SourceXml: string read FSourceXml;
    property ParseErrorLine:Integer read FParseErrorLine;
    property ParseErrorColumn:Integer read FParseErrorColumn;
    property ParseError: string read FParseError;
    property Examples: TList<TExampleDoc> read FExamples;
    property Exceptions: TList<TExceptionDoc> read FExceptions;
    property IsEmpty: Boolean read GetIsEmpty;
    property IsModified: Boolean read FIsModified write FIsModified;
    property Params: TList<TParamDoc> read FParams;
    property Remarks: string read FRemarks write SetRemarks;
    property Returns: string read FReturns write SetReturns;
    property SeeAlso: TList<TSeeAlsoDoc> read FSeeAlso;
    property Summary: string read FSummary write SetSummary;
    property TypeParams: TList<TTypeParamDoc> read FTypeParams;
    property Value: string read FValue write SetValue;

    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

implementation

uses
  System.StrUtils,XmlDoc.XmlFragments,Xml.xmldom;

{ TXmlDocModel }

constructor TXmlDocModel.Create;
begin
  inherited Create;

  FParams := TList<TParamDoc>.Create;
  FTypeParams := TList<TTypeParamDoc>.Create;
  FExceptions := TList<TExceptionDoc>.Create;
  FExamples := TList<TExampleDoc>.Create;
  FSeeAlso := TList<TSeeAlsoDoc>.Create;
end;

destructor TXmlDocModel.Destroy;
begin
  FSeeAlso.Free;
  FExamples.Free;
  FExceptions.Free;
  FTypeParams.Free;
  FParams.Free;

  inherited;
end;

procedure TXmlDocModel.Assign(ASource: TXmlDocModel);
var
  I: Integer;
begin
  Clear;
  FSummary := ASource.FSummary;
  FRemarks := ASource.FRemarks;
  FReturns := ASource.FReturns;
  FValue := ASource.FValue;

  for I := 0 to ASource.FParams.Count - 1 do
    FParams.Add(ASource.FParams[I]);

  for I := 0 to ASource.FTypeParams.Count - 1 do
    FTypeParams.Add(ASource.FTypeParams[I]);

  for I := 0 to ASource.FExceptions.Count - 1 do
    FExceptions.Add(ASource.FExceptions[I]);

  for I := 0 to ASource.FExamples.Count - 1 do
    FExamples.Add(ASource.FExamples[I]);

  for I := 0 to ASource.FSeeAlso.Count - 1 do
    FSeeAlso.Add(ASource.FSeeAlso[I]);

  FInheritedFrom:=ASource.FInheritedFrom;
  FSourceXml := ASource.FSourceXml;
  FOriginalCanonical := ASource.FOriginalCanonical;
  FParseError := ASource.FParseError;
  FIsModified := True;
  DoChanged;
end;

procedure TXmlDocModel.MergeMissing(ASource:TXmlDocModel;const SourceSymbol:string);
var P:TParamDoc;TP:TTypeParamDoc;I:Integer;Found:Boolean;
begin
 if (FParseError<>'') or (ASource.ParseError<>'') then Exit;
 if FSummary='' then FSummary:=ASource.Summary;if FRemarks='' then FRemarks:=ASource.Remarks;
 if FReturns='' then FReturns:=ASource.Returns;if FValue='' then FValue:=ASource.Value;
 for P in ASource.Params do begin
  Found:=False;for I:=0 to FParams.Count-1 do if SameText(P.Name,FParams[I].Name) then begin
   Found:=True;if FParams[I].Description='' then FParams[I]:=P;Break;end;
  if not Found then FParams.Add(P);
 end;
 for TP in ASource.TypeParams do begin
  Found:=False;for I:=0 to FTypeParams.Count-1 do if SameText(TP.Name,FTypeParams[I].Name) then begin
   Found:=True;if FTypeParams[I].Description='' then FTypeParams[I]:=TP;Break;end;
  if not Found then FTypeParams.Add(TP);
 end;
 if FExamples.Count=0 then FExamples.AddRange(ASource.Examples);
 if FExceptions.Count=0 then FExceptions.AddRange(ASource.Exceptions);
 if FSeeAlso.Count=0 then FSeeAlso.AddRange(ASource.SeeAlso);
 FInheritedFrom:=SourceSymbol;
end;

procedure TXmlDocModel.Clear;
begin
  ClearContent;FParseErrorLine:=0;FParseErrorColumn:=0;FInheritedFrom:=''; FSourceXml:=''; FOriginalCanonical:=''; FParseError:='';
end;

procedure TXmlDocModel.ClearContent;
begin
  FSummary := '';
  FRemarks := '';
  FReturns := '';
  FValue := '';
  FParams.Clear;
  FTypeParams.Clear;
  FExceptions.Clear;
  FExamples.Clear;
  FSeeAlso.Clear;
  FIsModified := False;
end;

procedure TXmlDocModel.DoChanged;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

function TXmlDocModel.EscapeXml(const AText: string): string;
begin
  Result := AText;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

procedure TXmlDocModel.FromJson(const AJson: string);
var
  LRoot: TJSONObject;
  LArr: TJSONArray;
  LObj: TJSONObject;
  LParam: TParamDoc;
  LTypeParam: TTypeParamDoc;
  LException: TExceptionDoc;
  LExample: TExampleDoc;
  LSeeAlso: TSeeAlsoDoc;
  I: Integer;
  Mapping:TJSONObject;MappingPair:TJSONPair;Mappings:TArray<string>;OriginalXml:string;
begin
  Clear;
  LRoot := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    if LRoot.GetValue<Boolean>('xmlEdited',False) then begin
      LoadFromXml(LRoot.GetValue<string>('rawXml','')); Exit;
    end;
    OriginalXml:=LRoot.GetValue<string>('sourceXml','');
    Mapping:=nil;LRoot.TryGetValue<TJSONObject>('renameMappings',Mapping);Mappings:=nil;
    if Assigned(Mapping) then for MappingPair in Mapping do Mappings:=Mappings+[MappingPair.JsonString.Value+'='+MappingPair.JsonValue.Value];
    if Length(Mappings)>0 then OriginalXml:=RenameDocNames(OriginalXml,Mappings);
    if OriginalXml<>'' then LoadFromXml(OriginalXml);
    ClearContent;
    LRoot.TryGetValue<string>('inheritedFrom',FInheritedFrom);
    if LRoot.TryGetValue<string>('summary', FSummary) then
      { ok };
    if LRoot.TryGetValue<string>('remarks', FRemarks) then
      { ok };
    if LRoot.TryGetValue<string>('returns', FReturns) then
      { ok };
    if LRoot.TryGetValue<string>('value', FValue) then
      { ok };

    if LRoot.TryGetValue<TJSONArray>('params', LArr) then
    begin
      for I := 0 to LArr.Count - 1 do
      begin
        LObj := LArr.Items[I] as TJSONObject;
        LParam := Default(TParamDoc);
        LObj.TryGetValue<string>('name', LParam.Name);
        LObj.TryGetValue<string>('description', LParam.Description);
        FParams.Add(LParam);
      end;
    end;

    if LRoot.TryGetValue<TJSONArray>('typeParams', LArr) then
    begin
      for I := 0 to LArr.Count - 1 do
      begin
        LObj := LArr.Items[I] as TJSONObject;
        LTypeParam := Default(TTypeParamDoc);
        LObj.TryGetValue<string>('name', LTypeParam.Name);
        LObj.TryGetValue<string>('description', LTypeParam.Description);
        FTypeParams.Add(LTypeParam);
      end;
    end;

    if LRoot.TryGetValue<TJSONArray>('exceptions', LArr) then
    begin
      for I := 0 to LArr.Count - 1 do
      begin
        LObj := LArr.Items[I] as TJSONObject;
        LException := Default(TExceptionDoc);
        LObj.TryGetValue<string>('typeRef', LException.TypeRef);
        LObj.TryGetValue<string>('description', LException.Description);
        FExceptions.Add(LException);
      end;
    end;

    if LRoot.TryGetValue<TJSONArray>('examples', LArr) then
    begin
      for I := 0 to LArr.Count - 1 do
      begin
        LObj := LArr.Items[I] as TJSONObject;
        LExample := Default(TExampleDoc);
        LObj.TryGetValue<string>('title', LExample.Title);LObj.TryGetValue<string>('source',LExample.SourceFile);LObj.TryGetValue<string>('region',LExample.Region);
        LObj.TryGetValue<string>('code', LExample.Code);
        LObj.TryGetValue<string>('description', LExample.Description);
        FExamples.Add(LExample);
      end;
    end;

    if LRoot.TryGetValue<TJSONArray>('seeAlso', LArr) then
    begin
      for I := 0 to LArr.Count - 1 do
      begin
        LObj := LArr.Items[I] as TJSONObject;
        LSeeAlso := Default(TSeeAlsoDoc);
        LObj.TryGetValue<string>('cref', LSeeAlso.Cref);
        LObj.TryGetValue<string>('description', LSeeAlso.Description);
        FSeeAlso.Add(LSeeAlso);
      end;
    end;

    FIsModified := True;
    DoChanged;
  finally
    LRoot.Free;
  end;
end;

function TXmlDocModel.ExtractInlineContent(const ANode: IXMLNode; AExcludeCode: Boolean): string;
var
  LSB: TStringBuilder;
  I: Integer;
  LChild: IXMLNode;
begin
  LSB := TStringBuilder.Create;
  try
    for I := 0 to ANode.ChildNodes.Count - 1 do
    begin
      LChild := ANode.ChildNodes[I];

      if AExcludeCode and (LChild.NodeName = 'code') then
        Continue;

      if LChild.NodeType in [ntText, ntCData] then
        LSB.Append(EscapeXml(LChild.Text))
      else
        LSB.Append(LChild.XML);
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TXmlDocModel.ExtractNodeText(const ANode: IXMLNode): string;
var
  LSB: TStringBuilder;
  I: Integer;
  LChild: IXMLNode;
  LHasPara: Boolean;
begin
  // <para> 자식 노드가 있으면 각 para 텍스트를 줄바꿈으로 결합
  LHasPara := False;
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    if ANode.ChildNodes[I].NodeName = 'para' then
    begin
      LHasPara := True;
      Break;
    end;
  end;

  if LHasPara then for I:=0 to ANode.ChildNodes.Count-1 do begin
    LChild:=ANode.ChildNodes[I];
    if ((LChild.NodeType in [ntText,ntCData]) and (Trim(LChild.Text)<>'')) or
      ((LChild.NodeType=ntElement) and (LChild.NodeName<>'para')) then Exit(Trim(ExtractInlineContent(ANode)));
  end;

  if not LHasPara then
  begin
    Result := Trim(ExtractInlineContent(ANode));
    Exit;
  end;

  LSB := TStringBuilder.Create;
  try
    for I := 0 to ANode.ChildNodes.Count - 1 do
    begin
      LChild := ANode.ChildNodes[I];
      if LChild.NodeName = 'para' then
      begin
        if LSB.Length > 0 then
          LSB.AppendLine;
        LSB.Append(Trim(ExtractInlineContent(LChild)));
      end;
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TXmlDocModel.GetIsEmpty: Boolean;
begin
  Result := (FSummary = '') and (FRemarks = '') and (FReturns = '') and
    (FValue = '') and (FParams.Count = 0) and (FTypeParams.Count = 0) and
    (FExceptions.Count = 0) and (FExamples.Count = 0) and (FSeeAlso.Count = 0) and
    (Trim(FSourceXml)='');
end;

procedure TXmlDocModel.LoadFromXml(const AXml: string);
var
  LXmlDoc: IXMLDocument;
  LWrapped: string;
  LRoot: IXMLNode;
  ParseError:IDOMParseError;
  Wrapped:Boolean;
begin
  Clear;
  FSourceXml:=AXml;
  if HasForbiddenDeclarations(AXml) then begin
    FParseError:='Document type declarations and entities are not allowed';Exit;end;

  if Trim(AXml) = '' then
    Exit;

  // doc 루트가 없으면 감싸기
  LWrapped := Trim(AXml);
  Wrapped:=not LWrapped.StartsWith('<doc>');
  if Wrapped then
    LWrapped := '<doc>' + LWrapped + '</doc>';

  LXmlDoc := TXMLDocument.Create(nil);
  LXmlDoc.ParseOptions:=[poPreserveWhiteSpace];LXmlDoc.Options:=[];
  try
    LXmlDoc.LoadFromXML(LWrapped);
    LXmlDoc.Active := True;
    LRoot := LXmlDoc.DocumentElement;

    ParseChildNodes(LRoot);

    FOriginalCanonical:=SerializeKnownXml;
    FIsModified := False;
  except
    on E:Exception do begin
      FParseError:=E.Message;
      if Supports(LXmlDoc.DOMDocument,IDOMParseError,ParseError) then begin
        FParseErrorLine:=ParseError.Line;FParseErrorColumn:=ParseError.LinePos;
        if Wrapped and (FParseErrorLine=1) then Dec(FParseErrorColumn,5);
        if FParseErrorColumn<1 then FParseErrorColumn:=1;
      end;
    end;
  end;
end;

procedure TXmlDocModel.ParseChildNodes(const AParentNode: IXMLNode);
var
  I: Integer;
  LNode: IXMLNode;
  LParam: TParamDoc;
  LTypeParam: TTypeParamDoc;
  LException: TExceptionDoc;
  LExample: TExampleDoc;
  LSeeAlso: TSeeAlsoDoc;
  LCodeNode: IXMLNode;
begin
  for I := 0 to AParentNode.ChildNodes.Count - 1 do
  begin
    LNode := AParentNode.ChildNodes[I];

    if LNode.NodeName = 'summary' then
      FSummary := ExtractNodeText(LNode)

    else if LNode.NodeName = 'remarks' then
      FRemarks := ExtractNodeText(LNode)

    else if LNode.NodeName = 'returns' then
      FReturns := ExtractNodeText(LNode)

    else if LNode.NodeName = 'value' then
      FValue := ExtractNodeText(LNode)

    else if LNode.NodeName = 'param' then
    begin
      LParam := Default(TParamDoc);
      if LNode.HasAttribute('name') then
        LParam.Name := LNode.Attributes['name'];
      LParam.Description := Trim(ExtractInlineContent(LNode));
      FParams.Add(LParam);
    end

    else if LNode.NodeName = 'typeparam' then
    begin
      LTypeParam := Default(TTypeParamDoc);
      if LNode.HasAttribute('name') then
        LTypeParam.Name := LNode.Attributes['name'];
      LTypeParam.Description := Trim(ExtractInlineContent(LNode));
      FTypeParams.Add(LTypeParam);
    end

    else if LNode.NodeName = 'exception' then
    begin
      LException := Default(TExceptionDoc);
      if LNode.HasAttribute('cref') then
        LException.TypeRef := LNode.Attributes['cref'];
      LException.Description := Trim(ExtractInlineContent(LNode));
      FExceptions.Add(LException);
    end

    else if LNode.NodeName = 'example' then
    begin
      LExample := Default(TExampleDoc);
      LExample.Description := TrimDocText(ExtractInlineContent(LNode, True));
      if LNode.HasAttribute('source') then LExample.SourceFile:=LNode.Attributes['source'];
      if LNode.HasAttribute('region') then LExample.Region:=LNode.Attributes['region'];
      if LNode.HasAttribute('title') then
        LExample.Title := LNode.Attributes['title'];
      LCodeNode := LNode.ChildNodes.FindNode('code');
      if Assigned(LCodeNode) then
        LExample.Code := LCodeNode.Text;
      var CodeCount:=0;
      for var J:=0 to LNode.ChildNodes.Count-1 do if LNode.ChildNodes[J].NodeName='code' then Inc(CodeCount);
      if CodeCount>1 then begin LExample.Code:='';LExample.Description:=TrimDocText(ExtractInlineContent(LNode));end;
      FExamples.Add(LExample);
    end

    else if LNode.NodeName = 'seealso' then
    begin
      LSeeAlso := Default(TSeeAlsoDoc);
      if LNode.HasAttribute('cref') then
        LSeeAlso.Cref := LNode.Attributes['cref'];
      LSeeAlso.Description := TrimDocText(ExtractInlineContent(LNode));
      FSeeAlso.Add(LSeeAlso);
    end;
  end;
end;

procedure TXmlDocModel.SetRemarks(const AValue: string);
begin
  if FRemarks <> AValue then
  begin
    FRemarks := AValue;
    FIsModified := True;
    DoChanged;
  end;
end;

procedure TXmlDocModel.SetReturns(const AValue: string);
begin
  if FReturns <> AValue then
  begin
    FReturns := AValue;
    FIsModified := True;
    DoChanged;
  end;
end;

procedure TXmlDocModel.SetSummary(const AValue: string);
begin
  if FSummary <> AValue then
  begin
    FSummary := AValue;
    FIsModified := True;
    DoChanged;
  end;
end;

procedure TXmlDocModel.SetValue(const AValue: string);
begin
  if FValue <> AValue then
  begin
    FValue := AValue;
    FIsModified := True;
    DoChanged;
  end;
end;

function TXmlDocModel.ToJson: string;
var
  LRoot: TJSONObject;
  LArr: TJSONArray;
  LObj: TJSONObject;
  I: Integer;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('inheritedFrom',FInheritedFrom);
    LRoot.AddPair('sourceXml', FSourceXml);
    LRoot.AddPair('parseError', FParseError);
    LRoot.AddPair('parseErrorLine',TJSONNumber.Create(FParseErrorLine));LRoot.AddPair('parseErrorColumn',TJSONNumber.Create(FParseErrorColumn));
    LRoot.AddPair('summary', FSummary);

    if FRemarks <> '' then
      LRoot.AddPair('remarks', FRemarks);

    if FReturns <> '' then
      LRoot.AddPair('returns', FReturns);

    if FValue <> '' then
      LRoot.AddPair('value', FValue);

    if FParams.Count > 0 then
    begin
      LArr := TJSONArray.Create;
      for I := 0 to FParams.Count - 1 do
      begin
        LObj := TJSONObject.Create;
        LObj.AddPair('name', FParams[I].Name);
        LObj.AddPair('description', FParams[I].Description);
        LArr.AddElement(LObj);
      end;
      LRoot.AddPair('params', LArr);
    end;

    if FTypeParams.Count > 0 then
    begin
      LArr := TJSONArray.Create;
      for I := 0 to FTypeParams.Count - 1 do
      begin
        LObj := TJSONObject.Create;
        LObj.AddPair('name', FTypeParams[I].Name);
        LObj.AddPair('description', FTypeParams[I].Description);
        LArr.AddElement(LObj);
      end;
      LRoot.AddPair('typeParams', LArr);
    end;

    if FExceptions.Count > 0 then
    begin
      LArr := TJSONArray.Create;
      for I := 0 to FExceptions.Count - 1 do
      begin
        LObj := TJSONObject.Create;
        LObj.AddPair('typeRef', FExceptions[I].TypeRef);
        LObj.AddPair('description', FExceptions[I].Description);
        LArr.AddElement(LObj);
      end;
      LRoot.AddPair('exceptions', LArr);
    end;

    if FExamples.Count > 0 then
    begin
      LArr := TJSONArray.Create;
      for I := 0 to FExamples.Count - 1 do
      begin
        LObj := TJSONObject.Create;
        if FExamples[I].SourceFile<>'' then LObj.AddPair('source',FExamples[I].SourceFile);
        if FExamples[I].Region<>'' then LObj.AddPair('region',FExamples[I].Region);
        if FExamples[I].Title <> '' then
          LObj.AddPair('title', FExamples[I].Title);
        if FExamples[I].Code <> '' then
          LObj.AddPair('code', FExamples[I].Code);
        LObj.AddPair('description', FExamples[I].Description);
        LArr.AddElement(LObj);
      end;
      LRoot.AddPair('examples', LArr);
    end;

    if FSeeAlso.Count > 0 then
    begin
      LArr := TJSONArray.Create;
      for I := 0 to FSeeAlso.Count - 1 do
      begin
        LObj := TJSONObject.Create;
        LObj.AddPair('cref', FSeeAlso[I].Cref);
        if FSeeAlso[I].Description <> '' then
          LObj.AddPair('description', FSeeAlso[I].Description);
        LArr.AddElement(LObj);
      end;
      LRoot.AddPair('seeAlso', LArr);
    end;

    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TXmlDocModel.SerializeKnownXml: string;
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    if FSummary <> '' then
    begin
      if not FSummary.Contains(#10) then LSB.AppendLine('<summary>'+FSummary+'</summary>')
      else begin LSB.AppendLine('<summary>');LSB.AppendLine(WrapParaTags(FSummary));LSB.AppendLine('</summary>');end;
    end;

    if FRemarks <> '' then
    begin
      LSB.AppendLine('<remarks>');
      LSB.AppendLine(WrapParaTags(FRemarks));
      LSB.AppendLine('</remarks>');
    end;

    for I := 0 to FParams.Count - 1 do
    begin
      LSB.AppendFormat('<param name="%s">%s</param>', [
        EscapeXml(FParams[I].Name),
        FParams[I].Description
      ]);
      LSB.AppendLine;
    end;

    for I := 0 to FTypeParams.Count - 1 do
    begin
      LSB.AppendFormat('<typeparam name="%s">%s</typeparam>', [
        EscapeXml(FTypeParams[I].Name),
        FTypeParams[I].Description
      ]);
      LSB.AppendLine;
    end;

    if FReturns <> '' then
    begin
      LSB.AppendFormat('<returns>%s</returns>', [FReturns]);
      LSB.AppendLine;
    end;

    if FValue <> '' then
    begin
      LSB.AppendFormat('<value>%s</value>', [FValue]);
      LSB.AppendLine;
    end;

    for I := 0 to FExceptions.Count - 1 do
    begin
      if FExceptions[I].Description <> '' then
      begin
        LSB.AppendFormat('<exception cref="%s">', [EscapeXml(FExceptions[I].TypeRef)]);
        LSB.AppendLine;
        LSB.AppendLine(FExceptions[I].Description);
        LSB.AppendLine('</exception>');
      end
      else
      begin
        LSB.AppendFormat('<exception cref="%s"/>', [EscapeXml(FExceptions[I].TypeRef)]);
        LSB.AppendLine;
      end;
    end;

    for I := 0 to FExamples.Count - 1 do
    begin
      LSB.Append('<example');
      if FExamples[I].Title<>'' then LSB.Append(' title="'+EscapeXml(FExamples[I].Title)+'"');
      if FExamples[I].SourceFile<>'' then LSB.Append(' source="'+EscapeXml(FExamples[I].SourceFile)+'"');
      if FExamples[I].Region<>'' then LSB.Append(' region="'+EscapeXml(FExamples[I].Region)+'"');
      LSB.Append('>');
      LSB.AppendLine;
      if FExamples[I].Description <> '' then
        LSB.AppendLine(FExamples[I].Description);
      if FExamples[I].Code <> '' then
      begin
        LSB.AppendLine('<code>');
        LSB.AppendLine(EscapeXml(FExamples[I].Code));
        LSB.AppendLine('</code>');
      end;
      LSB.AppendLine('</example>');
    end;

    for I := 0 to FSeeAlso.Count - 1 do
    begin
      if FSeeAlso[I].Description <> '' then
      begin
        LSB.AppendFormat('<seealso cref="%s">%s</seealso>', [
          EscapeXml(FSeeAlso[I].Cref),
          FSeeAlso[I].Description
        ]);
      end
      else
      begin
        LSB.AppendFormat('<seealso cref="%s"/>', [EscapeXml(FSeeAlso[I].Cref)]);
      end;
      LSB.AppendLine;
    end;

    Result := Trim(LSB.ToString);
  finally
    LSB.Free;
  end;
end;

function TXmlDocModel.ToXml:string;
var OldDoc,BaseDoc,NewDoc,AttributeDoc,BaseAttributeDoc:IXMLDocument;N,B,O:IXMLNode;Attr:IXMLNode;J:Integer;Wrapped:Boolean;
  Counts:TDictionary<string,Integer>;Base,Old:TDictionary<string,string>;
  Fresh,Key:string;I:Integer;SB:TStringBuilder;
  function NodeKey(Node:IXMLNode):string;
  var K:string;C:Integer;
  begin
    K:=Node.NodeName;
    if Node.HasAttribute('name') then K:=K+'@'+string(Node.Attributes['name'])
    else if Node.HasAttribute('cref') then K:=K+'@'+string(Node.Attributes['cref']);
    if not Counts.TryGetValue(K,C) then C:=0;
    Counts.AddOrSetValue(K,C+1);Result:=K+'#'+IntToStr(C);
  end;
  function InnerXml(Node:IXMLNode):string;
  var K:Integer;
  begin Result:='';for K:=0 to Node.ChildNodes.Count-1 do Result:=Result+Node.ChildNodes[K].XML;end;
  procedure PreserveAttributes(Source,Target:IXMLNode);
  var A,C,S:IXMLNode;X,Y,Ordinal,Seen:Integer;
  begin
   if (Source.NodeType<>ntElement) or (Target.NodeType<>ntElement) then Exit;
   for X:=0 to Source.AttributeNodes.Count-1 do begin A:=Source.AttributeNodes[X];if not Target.HasAttribute(A.NodeName) then Target.Attributes[A.NodeName]:=A.NodeValue;end;
   for X:=0 to Target.ChildNodes.Count-1 do begin
    C:=Target.ChildNodes[X];if C.NodeType<>ntElement then Continue;Ordinal:=0;
    for Y:=0 to X-1 do if Target.ChildNodes[Y].NodeName=C.NodeName then Inc(Ordinal);
    Seen:=0;
    for Y:=0 to Source.ChildNodes.Count-1 do begin S:=Source.ChildNodes[Y];
     if (S.NodeType=ntElement) and (S.NodeName=C.NodeName) then begin if Seen=Ordinal then begin PreserveAttributes(S,C);Break;end;Inc(Seen);end;
    end;
   end;
  end;
  function Known(const Name:string):Boolean;
  begin Result:=(Name='summary') or (Name='remarks') or (Name='param') or
    (Name='typeparam') or (Name='returns') or (Name='value') or
    (Name='exception') or (Name='example') or (Name='seealso');end;
begin
  if FParseError<>'' then Exit(FSourceXml);
  Fresh:=SerializeKnownXml;
  if FSourceXml='' then Exit(Fresh);
  if Fresh=FOriginalCanonical then Exit(FSourceXml);
  Wrapped:=Trim(FSourceXml).StartsWith('<doc>');
  if Wrapped then OldDoc:=LoadDocXml(FSourceXml) else OldDoc:=LoadDocXml('<doc>'+FSourceXml+'</doc>');
  BaseDoc:=LoadDocXml('<doc>'+FOriginalCanonical+'</doc>');
  NewDoc:=LoadDocXml('<doc>'+Fresh+'</doc>');
  Counts:=TDictionary<string,Integer>.Create;Base:=TDictionary<string,string>.Create;
  Old:=TDictionary<string,string>.Create;SB:=TStringBuilder.Create;
  try
    for I:=0 to BaseDoc.DocumentElement.ChildNodes.Count-1 do begin
      B:=BaseDoc.DocumentElement.ChildNodes[I];
      if B.NodeType=ntElement then Base.AddOrSetValue(NodeKey(B),B.XML);
    end;
    Counts.Clear;
    for I:=0 to OldDoc.DocumentElement.ChildNodes.Count-1 do begin
      O:=OldDoc.DocumentElement.ChildNodes[I];
      if O.NodeType=ntElement then Old.AddOrSetValue(NodeKey(O),O.XML);
    end;
    Counts.Clear;
    for I:=0 to NewDoc.DocumentElement.ChildNodes.Count-1 do begin
      N:=NewDoc.DocumentElement.ChildNodes[I];if N.NodeType<>ntElement then Continue;
      Key:=NodeKey(N);
      if Base.ContainsKey(Key) and Old.ContainsKey(Key) and (Base[Key]=N.XML) then SB.AppendLine(Old[Key])
      else begin
        if Old.ContainsKey(Key) then begin
          AttributeDoc:=LoadDocXml(Old[Key]);O:=AttributeDoc.DocumentElement;
          if Base.ContainsKey(Key) then begin
            BaseAttributeDoc:=LoadDocXml(Base[Key]);
            if InnerXml(BaseAttributeDoc.DocumentElement)=InnerXml(N) then begin
              for J:=0 to N.AttributeNodes.Count-1 do begin Attr:=N.AttributeNodes[J];O.Attributes[Attr.NodeName]:=Attr.NodeValue;end;
              for J:=0 to BaseAttributeDoc.DocumentElement.AttributeNodes.Count-1 do begin
                Attr:=BaseAttributeDoc.DocumentElement.AttributeNodes[J];if not N.HasAttribute(Attr.NodeName) then O.AttributeNodes.Delete(Attr.NodeName);
              end;
              SB.AppendLine(O.XML);Continue;
            end;
          end;
          PreserveAttributes(O,N);
        end;
        SB.AppendLine(N.XML);
      end;
    end;
    for I:=0 to OldDoc.DocumentElement.ChildNodes.Count-1 do begin
      O:=OldDoc.DocumentElement.ChildNodes[I];
      if ((O.NodeType=ntElement) and not Known(O.NodeName)) or (O.NodeType=ntComment) or ((O.NodeType in [ntText,ntCData]) and (Trim(O.Text)<>'')) then SB.AppendLine(O.XML);
    end;
    Result:=Trim(SB.ToString);
    if Wrapped then Result:='<doc>'+Result+'</doc>';
  finally SB.Free;Old.Free;Base.Free;Counts.Free;end;
end;

function TXmlDocModel.TrimDocText(const AText: string): string;
var
  LLines: TArray<string>;
  LSB: TStringBuilder;
  I: Integer;
  LLine: string;
begin
  // 여러 줄의 텍스트에서 공통 선행 공백/줄바꿈 정리
  Result := Trim(AText);
  if Result = '' then
    Exit;

  LLines := Result.Split([#13#10, #10, #13]);
  if Length(LLines) <= 1 then
    Exit;

  LSB := TStringBuilder.Create;
  try
    for I := 0 to High(LLines) do
    begin
      LLine := Trim(LLines[I]);
      if (I = 0) and (LLine = '') then
        Continue;
      if (I = High(LLines)) and (LLine = '') then
        Continue;

      if LSB.Length > 0 then
        LSB.AppendLine;
      LSB.Append(LLine);
    end;
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TXmlDocModel.WrapParaTags(const AText: string): string;
var
  LLines: TArray<string>;
  LSB: TStringBuilder;
  I: Integer;
  LLine: string;
begin
  // 멀티라인이면 각 라인을 <para>로 감싸기
  // 인라인 XML 태그(<c>, <see>, <paramref>, <typeparamref>)는 이미 적절히 이스케이프되어 있으므로 재이스케이프 불필요
  if AText.Contains('<para') or AText.Contains('<list') or AText.Contains('<table') or AText.Contains('<code') then Exit(AText);
  if not AText.Contains(#10) and not AText.Contains(#13) then
  begin
    Result := AText;
    Exit;
  end;

  LLines := AText.Split([#13#10, #10, #13]);
  LSB := TStringBuilder.Create;
  try
    for I := 0 to High(LLines) do
    begin
      LLine := Trim(LLines[I]);
      if LLine = '' then
        Continue;

      if LSB.Length > 0 then
        LSB.AppendLine;
      LSB.Append('<para>' + LLine + '</para>');
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TXmlDocModel.UnescapeXml(const AText: string): string;
begin
  Result := AText;
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
end;

end.
