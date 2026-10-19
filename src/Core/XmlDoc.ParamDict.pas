/// <summary>Persistent parameter-description hints used by documentation stub generation.</summary>
unit XmlDoc.ParamDict;

interface

uses
  System.SysUtils,
  System.Generics.Defaults,
  System.Generics.Collections;

type
  /// <summary>Persistent parameter-description dictionary used by stub generation.</summary>
  TParamDictionary = class
  strict private
    class var FInstance: TParamDictionary;

    class destructor Destroy;
  private
    FDirty: Boolean;
    FFilePath: string;
    FItems: TDictionary<string, string>;

    class function  GetInstance: TParamDictionary; static;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Selects a dictionary file and loads its existing entries.</summary>
    /// <param name="APath">JSON file path.</param>
    procedure LoadFromFile(const APath: string);

    /// <summary>Adds or updates a parameter description.</summary>
    /// <param name="AName">Parameter name.</param>
    /// <param name="ADescription">Parameter description.</param>
    procedure Register(const AName, ADescription: string);

    /// <summary>Saves modified dictionary entries.</summary>
    procedure SaveToFile;

    /// <summary>Looks up a parameter description.</summary>
    /// <param name="AName">Parameter name.</param>
    /// <param name="ADescription">Description returned when an entry exists.</param>
    /// <returns>True if a description was found.</returns>
    function TryGet(const AName: string; out ADescription: string): Boolean;

    /// <summary>Returns the shared dictionary instance.</summary>
    class property Instance: TParamDictionary read GetInstance;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON;

{ TParamDictionary }

class destructor TParamDictionary.Destroy;
begin
  FreeAndNil(FInstance);
end;

constructor TParamDictionary.Create;
begin
  inherited Create;
  FItems := TDictionary<string, string>.Create;
  FDirty := False;
end;

destructor TParamDictionary.Destroy;
begin
  SaveToFile;
  FItems.Free;

  inherited;
end;

class function TParamDictionary.GetInstance: TParamDictionary;
begin
  if not Assigned(FInstance) then
    FInstance := TParamDictionary.Create;

  Result := FInstance;
end;

procedure TParamDictionary.LoadFromFile(const APath: string);
var
  LJson: string;
  LObj: TJSONObject;
  LPair: TJSONPair;
  I: Integer;
begin
  FFilePath := APath;
  FItems.Clear;
  FDirty := False;

  if not TFile.Exists(APath) then
    Exit;

  try
    LJson := TFile.ReadAllText(APath, TEncoding.UTF8);
    LObj := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
    if Assigned(LObj) then
    begin
      try
        for I := 0 to LObj.Count - 1 do
        begin
          LPair := LObj.Pairs[I];
          FItems.AddOrSetValue(LPair.JsonString.Value, LPair.JsonValue.Value);
        end;
      finally
        LObj.Free;
      end;
    end;
  except
    // 파일 읽기/파싱 실패 시 빈 딕셔너리로 시작
  end;
end;

procedure TParamDictionary.Register(const AName, ADescription: string);
var
  LTrimmed: string;
  LExisting: string;
begin
  LTrimmed := Trim(ADescription);

  // 빈 값이나 TODO: 접두어는 무시
  if (LTrimmed = '') or LTrimmed.StartsWith('TODO:', True) then
    Exit;

  // 이름이 비어있으면 무시
  if Trim(AName) = '' then
    Exit;

  // 동일한 값이 이미 있으면 스킵
  if FItems.TryGetValue(AName, LExisting) and (LExisting = LTrimmed) then
    Exit;

  FItems.AddOrSetValue(AName, LTrimmed);
  FDirty := True;
end;

procedure TParamDictionary.SaveToFile;
var
  LObj: TJSONObject;
  LPair: TPair<string, string>;
  LSorted: TList<TPair<string, string>>;
  LJson: string;
begin
  if not FDirty then
    Exit;

  if FFilePath = '' then
    Exit;

  LObj := TJSONObject.Create;
  try
    // 키 알파벳순 정렬하여 저장
    LSorted := TList<TPair<string, string>>.Create;
    try
      for LPair in FItems do
        LSorted.Add(LPair);

      LSorted.Sort(TComparer<TPair<string, string>>.Construct(
        function(const ALeft, ARight: TPair<string, string>): Integer
        begin
          Result := CompareText(ALeft.Key, ARight.Key);
        end
      ));

      for LPair in LSorted do
        LObj.AddPair(LPair.Key, LPair.Value);
    finally
      LSorted.Free;
    end;

    LJson := LObj.Format(2);

    try
      ForceDirectories(ExtractFilePath(FFilePath));
      TFile.WriteAllText(FFilePath, LJson, TEncoding.UTF8);
      FDirty := False;
    except
      // 파일 쓰기 실패 시 무시 — 다음 기회에 재시도
    end;
  finally
    LObj.Free;
  end;
end;

function TParamDictionary.TryGet(const AName: string; out ADescription: string): Boolean;
begin
  Result := FItems.TryGetValue(AName, ADescription);
end;

end.
