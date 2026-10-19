/// <summary>Source navigation between undocumented declarations.</summary>
unit XmlDoc.Plugin.UndocNavigator;

interface

uses
  System.SysUtils,
  System.Classes,
  ToolsAPI,
  XmlDoc.Consts,
  XmlDoc.Parser;

type
  /// <summary>Navigates undocumented declarations using the configured plugin shortcuts.</summary>
  TUndocNavigator = class
  private
    FCurrentIndex: Integer;
    FLastSource,FLastFileName:string;
    FParser: TDocParser;
    FUndocElements: TArray<TCodeElementInfo>;

    function GetCurrentEditor: IOTASourceEditor;
    function GetCurrentSource(const AEditor: IOTASourceEditor): string;
    procedure JumpToElement(const AElement: TCodeElementInfo);
    procedure RebuildList;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Moves to the next undocumented declaration.</summary>
    procedure JumpToNext;

    /// <summary>Moves to the previous undocumented declaration.</summary>
    procedure JumpToPrevious;

    /// <summary>Returns an undocumented-declaration count for the active unit.</summary>
    /// <returns>For example: 5/23 undocumented (public).</returns>
    function GetUnitStatus: string;
  end;

implementation

uses XmlDoc.Plugin.DeclarationContext,XmlDoc.Plugin.EditSession;

{ TUndocNavigator }

constructor TUndocNavigator.Create;
begin
  inherited Create;

  FParser := TDocParser.Create;
  FCurrentIndex := -1;
end;

destructor TUndocNavigator.Destroy;
begin
  FParser.Free;

  inherited;
end;

function TUndocNavigator.GetCurrentEditor: IOTASourceEditor;
var
  LModule: IOTAModule;
  I: Integer;
begin
  Result := nil;
  LModule := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  if not Assigned(LModule) then
    Exit;

  for I := 0 to LModule.GetModuleFileCount - 1 do
  begin
    if Supports(LModule.GetModuleFileEditor(I), IOTASourceEditor, Result) then
      Exit;
  end;

  Result := nil;
end;

function TUndocNavigator.GetCurrentSource(const AEditor:IOTASourceEditor):string;
begin Result:=EditorSource(AEditor);end;

procedure TUndocNavigator.RebuildList;
var
  LEditor: IOTASourceEditor;
  LSource: string;
  LAllElements: TArray<TCodeElementInfo>;
  LUndocList: TArray<TCodeElementInfo>;
  I: Integer;
  LCount: Integer;
begin
  LEditor := GetCurrentEditor;
  if not Assigned(LEditor) then
    Exit;

  LSource := GetCurrentSource(LEditor);
  if LSource = '' then
    Exit;

  ConfigureDeclarationContext(FParser,nil,LEditor.FileName);
  if SameText(FLastFileName,LEditor.FileName) and (FLastSource=LSource) and FParser.IsUpToDate(LSource) then Exit;
  FLastFileName:=LEditor.FileName;FLastSource:=LSource;
  FCurrentIndex:=-1;
  FParser.ParseSource(LSource,LEditor.FileName);
  LAllElements := FParser.GetAllElements;

  // public/published 요소 중 미문서화된 것만 필터링
  SetLength(LUndocList, Length(LAllElements));
  LCount := 0;
  for I := 0 to Length(LAllElements) - 1 do
  begin
    if (LAllElements[I].ExistingDocXml = '') and
       ((LAllElements[I].Visibility = 'public') or
        (LAllElements[I].Visibility = 'published') or
        (LAllElements[I].Visibility = '')) then
    begin
      LUndocList[LCount] := LAllElements[I];
      Inc(LCount);
    end;
  end;

  SetLength(LUndocList, LCount);
  FUndocElements := LUndocList;
end;

procedure TUndocNavigator.JumpToElement(const AElement: TCodeElementInfo);
var
  LEditor: IOTASourceEditor;
  LView: IOTAEditView;
  LPos: TOTAEditPos;
begin
  LEditor := GetCurrentEditor;
  if not Assigned(LEditor) then
    Exit;

  LView := LEditor.GetEditView(0);
  if not Assigned(LView) then
    Exit;

  LPos.Line := AElement.LineNumber;
  LPos.Col := 1;
  LView.CursorPos := LPos;
  LView.MoveViewToCursor;
  LView.Paint;
end;

procedure TUndocNavigator.JumpToNext;
begin
  RebuildList;
  if Length(FUndocElements) = 0 then
    Exit;

  Inc(FCurrentIndex);
  if FCurrentIndex >= Length(FUndocElements) then
    FCurrentIndex := 0;

  JumpToElement(FUndocElements[FCurrentIndex]);
end;

procedure TUndocNavigator.JumpToPrevious;
begin
  RebuildList;
  if Length(FUndocElements) = 0 then
    Exit;

  Dec(FCurrentIndex);
  if FCurrentIndex < 0 then
    FCurrentIndex := Length(FUndocElements) - 1;

  JumpToElement(FUndocElements[FCurrentIndex]);
end;

function TUndocNavigator.GetUnitStatus: string;
var
  LTotal: Integer;
begin
  RebuildList;
  LTotal := Length(FParser.GetAllElements);
  Result := Format('%d/%d undocumented (public)',
    [Length(FUndocElements), LTotal]);
end;

end.
