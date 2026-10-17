unit XmlDoc.StubGen;

interface

uses
  System.SysUtils,
  System.Classes,
  XmlDoc.Consts,
  XmlDoc.Model;

type
  /// <summary>코드 요소 시그니처를 분석해 문서 스텁을 자동 생성합니다.</summary>
  TDocStubGenerator = class
  private
    class function ExtractParamHint(const AParamName, ATypeName: string): string;
    class function GenerateReturnHint(const AReturnType: string): string;
    class function GenerateSummaryHint(const AElement: TCodeElementInfo): string;
  public
    /// <summary>코드 요소에 대한 문서 스텁 모델을 생성합니다.</summary>
    /// <param name="AElement">대상 코드 요소 정보</param>
    /// <returns>스텁이 채워진 TXmlDocModel (호출자가 Free해야 함)</returns>
    class function GenerateStub(const AElement: TCodeElementInfo): TXmlDocModel;
  end;

implementation

uses
  System.StrUtils,
  XmlDoc.ParamDict;

const
  CPlaceholderPrefix = 'TODO: ';

{ TDocStubGenerator }

class function TDocStubGenerator.ExtractParamHint(const AParamName, ATypeName: string): string;
var
  LName: string;
begin
  // A 접두어 제거
  if (Length(AParamName) > 1) and (AParamName[1] = 'A') and
     (AParamName[2] >= 'A') and (AParamName[2] <= 'Z') then
    LName := Copy(AParamName, 2, MaxInt)
  else
    LName := AParamName;

  LName := LowerCase(LName);

  // 이름 기반 힌트
  if LName = 'filename' then
    Result := 'File name'
  else if LName = 'filepath' then
    Result := 'File path'
  else if LName = 'dirname' then
    Result := 'Directory name'
  else if LName = 'dirpath' then
    Result := 'Directory path'
  else if LName = 'count' then
    Result := 'Count'
  else if LName = 'index' then
    Result := 'Index (zero-based)'
  else if LName = 'name' then
    Result := 'Name'
  else if LName = 'text' then
    Result := 'Text'
  else if LName = 'value' then
    Result := 'Value'
  else if LName = 'source' then
    Result := 'Source'
  else if LName = 'target' then
    Result := 'Target'
  else if LName = 'stream' then
    Result := 'Stream'
  else if LName = 'format' then
    Result := 'Format'
  else if LName = 'owner' then
    Result := 'Owner'
  else if LName = 'parent' then
    Result := 'Parent'
  else if LName = 'key' then
    Result := 'Key'
  else if LName = 'msg' then
    Result := 'Message'
  else if LName = 'message' then
    Result := 'Message'
  else if LName = 'result' then
    Result := 'Result'
  else if LName = 'enabled' then
    Result := 'Whether enabled'
  else if LName = 'visible' then
    Result := 'Whether visible'
  else if LName = 'width' then
    Result := 'Width'
  else if LName = 'height' then
    Result := 'Height'
  else if LName = 'size' then
    Result := 'Size'
  else if LName = 'timeout' then
    Result := 'Timeout (milliseconds)'
  else if LName = 'callback' then
    Result := 'Callback'
  else if LName = 'handler' then
    Result := 'Handler'
  else if LName = 'sender' then
    Result := 'Event sender'
  else if LName = 'args' then
    Result := 'Arguments'
  else
    Result := '';
end;

class function TDocStubGenerator.GenerateReturnHint(const AReturnType: string): string;
var
  LType: string;
begin
  LType := LowerCase(AReturnType);

  if LType = 'boolean' then
    Result := 'True on success'
  else if LType = 'string' then
    Result := CPlaceholderPrefix + 'Description of the returned string'
  else if (LType = 'integer') or (LType = 'int64') or (LType = 'cardinal') then
    Result := CPlaceholderPrefix + 'Description of the return value'
  else if LType <> '' then
    Result := CPlaceholderPrefix + AReturnType + ' description'
  else
    Result := '';
end;

class function TDocStubGenerator.GenerateSummaryHint(const AElement: TCodeElementInfo): string;
var
  LMethodKind: string;
begin
  LMethodKind := LowerCase(AElement.MethodKind);

  case AElement.Kind of
  dekMethod:
    begin
      if LMethodKind = 'constructor' then
        Result := 'Creates a new instance.'
      else
      if LMethodKind = 'destructor' then
        Result := 'Destroys the instance.'
      else
        Result := CPlaceholderPrefix + AElement.Name + ' description';
    end;
  dekClass:
    Result := CPlaceholderPrefix + AElement.Name + ' class description';
  dekRecord:
    Result := CPlaceholderPrefix + AElement.Name + ' record description';
  dekInterface:
    Result := CPlaceholderPrefix + AElement.Name + ' interface description';
  dekProperty:
    Result := CPlaceholderPrefix + AElement.Name + ' description';
  dekField:
    Result := CPlaceholderPrefix + AElement.Name + ' description';
  dekConstant:
    Result := CPlaceholderPrefix + AElement.Name + ' description';
  dekType:
    Result := CPlaceholderPrefix + AElement.Name + ' type description';
  else
    Result := CPlaceholderPrefix + 'Description';
  end;
end;

class function TDocStubGenerator.GenerateStub(const AElement: TCodeElementInfo): TXmlDocModel;
var
  LParamDoc: TParamDoc;
  LTypeParamDoc: TTypeParamDoc;
  I: Integer;
  LHint: string;
begin
  Result := TXmlDocModel.Create;

  // 빈 요소면 빈 모델 반환
  if AElement.Name = '' then
    Exit;

  // Summary
  Result.Summary := GenerateSummaryHint(AElement);

  // Params
  for I := 0 to Length(AElement.Params) - 1 do
  begin
    LParamDoc.Name := AElement.Params[I].Name;
    LHint := ExtractParamHint(AElement.Params[I].Name, AElement.Params[I].TypeName);
    if LHint = '' then
      TParamDictionary.Instance.TryGet(AElement.Params[I].Name, LHint);

    if LHint <> '' then
      LParamDoc.Description := LHint
    else
      LParamDoc.Description := CPlaceholderPrefix + AElement.Params[I].Name + ' description';
    Result.Params.Add(LParamDoc);
  end;

  // TypeParams (제네릭)
  for I := 0 to Length(AElement.GenericParams) - 1 do
  begin
    LTypeParamDoc.Name := AElement.GenericParams[I];
    LTypeParamDoc.Description := CPlaceholderPrefix + AElement.GenericParams[I] + ' type description';
    Result.TypeParams.Add(LTypeParamDoc);
  end;

  // Returns
  if (AElement.Kind = dekMethod) and (AElement.ReturnType <> '') then
    Result.Returns := GenerateReturnHint(AElement.ReturnType);
end;

end.
