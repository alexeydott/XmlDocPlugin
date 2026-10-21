/// <summary>IDE wizard registration, command wiring and plugin lifetime management.</summary>
unit XmlDoc.Plugin.Main;

interface

uses
  XmlDoc.Plugin.HelpInsight,
  XmlDoc.Logger,
  DeskUtil,
  System.SysUtils,
  System.Classes,
  Vcl.Menus,
  Vcl.Dialogs,
  ToolsAPI,
  XmlDoc.Plugin.DocExplorer,
  XmlDoc.Plugin.DocInspector,
  XmlDoc.Plugin.Shortcuts,
  XmlDoc.Plugin.UndocNavigator;

type
  /// <summary>Registers IDE services, menus and editor notifications and owns plugin lifetime.</summary>
  TXmlDocWizard = class(TNotifierObject, IOTAWizard, IOTAMenuWizard)
  private
    FDocExplorer: TDocExplorerForm;
    FDocInspector: TDocInspectorForm;
    FEditorNotifierIndex: Integer;
    FThemeNotifierIndex:Integer;
    FOptionsPage:INTAAddInOptions;
    FKeyBindingIndex: Integer;
    FMenuIntegration: TXmlDocMenuIntegration;
    FUndocNavigator: TUndocNavigator;

    procedure CreateDocExplorer;
    procedure CreateDocInspector;
    procedure DestroyDocExplorer;
    procedure DestroyDocInspector;
    procedure GenerateStubForCurrentElement;
    procedure GenerateForPrefix(ALine:Integer;const Source,FileName:string);
    procedure SetupCallbacks;
    procedure SettingsApplied;

  public
    constructor Create;
    destructor Destroy; override;

    { IOTAWizard }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Execute;
    procedure Modified;

    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;

    { IOTAMenuWizard }
    function GetMenuText: string;

    property DocExplorer: TDocExplorerForm read FDocExplorer;
    property DocInspector: TDocInspectorForm read FDocInspector;
  end;

procedure Register;

implementation

uses
  XmlDoc.I18n,
  XmlDoc.Plugin.Splash,
  XmlDoc.Plugin.EditorNotifier,
  XmlDoc.Plugin.BatchGenDialog,
  XmlDoc.Plugin.CoverageDialog,
  XmlDoc.Plugin.Settings,
  XmlDoc.Plugin.SettingsDialog,
  XmlDoc.Plugin.OptionsPage,
  XmlDoc.Parser,
  XmlDoc.Plugin.DeclarationContext,
  XmlDoc.Plugin.EditSession,
  XmlDoc.StubGen,
  XmlDoc.CodeGen.OTA,
  XmlDoc.Consts,
  XmlDoc.Model;

type THelpInsightThemeNotifier=class(TNotifierObject,INTAIDEThemingServicesNotifier)
 public procedure ChangingTheme;procedure ChangedTheme;
end;
procedure THelpInsightThemeNotifier.ChangingTheme;
begin end;
procedure THelpInsightThemeNotifier.ChangedTheme;
begin
 if TPluginSettings.Instance.Global.HelpInsight.Enabled and TPluginSettings.Instance.Global.HelpInsight.Extended then
 try ApplyHelpInsightPresentation(HelpInsightCssPath,TPluginSettings.Instance.Global.HelpInsight,IDEHelpInsightPalette,IDEHelpInsightXsltPath);
 except on E:Exception do TLogger.Instance.Warn(E.Message,'Help Insight');end;
end;
procedure Register;
begin
  RegisterPluginSplash;
  XmlDoc.I18n.TI18n.Instance.SetLanguage(TPluginSettings.Instance.Global.General.Language);
  if TPluginSettings.Instance.Global.HelpInsight.Enabled then
  try
    ApplyHelpInsightPresentation(HelpInsightCssPath, TPluginSettings.Instance.Global.HelpInsight,IDEHelpInsightPalette,IDEHelpInsightXsltPath);
  except
    on E: Exception do TLogger.Instance.Warn(E.Message, 'Help Insight');
  end;
  // Let the IDE release the wizard before unloading its design-time package.
  RegisterPackageWizard(TXmlDocWizard.Create);
end;

{ TXmlDocWizard }

constructor TXmlDocWizard.Create;
var
  LEditorServices: IOTAEditorServices;
  LKeyServices: IOTAKeyboardServices;
begin
  inherited Create;
  FEditorNotifierIndex := -1;
  FThemeNotifierIndex:=-1;
  var Theme:IOTAIDEThemingServices;
  if Supports(BorlandIDEServices,IOTAIDEThemingServices,Theme) then FThemeNotifierIndex:=Theme.AddNotifier(THelpInsightThemeNotifier.Create);
  FKeyBindingIndex := -1;

  RegisterDesktopFormClass(TDocInspectorForm, 'XmlDocDocInspector', 'XmlDocDocInspector');
  if Assigned(RegisterFieldAddress) then
    RegisterFieldAddress('XmlDocDocInspector', @FDocInspector);

  // 에디터 노티파이어 등록
  if Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
  begin
    FEditorNotifierIndex := LEditorServices.AddNotifier(
      TXmlDocEditorNotifier.Create(
        procedure(ALine: Integer; const ASource, AFileName: string)
        begin
          GenerateForPrefix(ALine,ASource,AFileName);
          if Assigned(FDocInspector) then
            FDocInspector.HandleCursorChanged(ALine, ASource, AFileName);
          if Assigned(FDocExplorer) then
            FDocExplorer.HandleFileChanged(AFileName, ASource);
        end
      )
    );
  end;

  // 키보드 바인딩 등록
  if Supports(BorlandIDEServices, IOTAKeyboardServices, LKeyServices) then
    FKeyBindingIndex := LKeyServices.AddKeyboardBinding(TXmlDocKeyBinding.Create);

  // 미문서화 네비게이터
  FUndocNavigator := TUndocNavigator.Create;

  // 콜백 설정
  SetupCallbacks;

  // IDE 메뉴 통합
  FMenuIntegration := TXmlDocMenuIntegration.Create;
  FMenuIntegration.InstallMenu;
  FOptionsPage:=RegisterPluginOptions(SettingsApplied);
end;

destructor TXmlDocWizard.Destroy;
var
  LEditorServices: IOTAEditorServices;
  LKeyServices: IOTAKeyboardServices;
begin
  UnregisterPluginOptions(FOptionsPage);
  var Theme:IOTAIDEThemingServices;
  if (FThemeNotifierIndex>=0) and Supports(BorlandIDEServices,IOTAIDEThemingServices,Theme) then begin Theme.RemoveNotifier(FThemeNotifierIndex);FThemeNotifierIndex:=-1;end;
  SetDocumentationCommandCallback(nil);
  SetToggleInspectorCallback(nil);SetGenerateStubCallback(nil);SetGenerateHelpCallback(nil);
  SetCoverageReportCallback(nil);SetNextUndocumentedCallback(nil);SetPreviousUndocumentedCallback(nil);
  SetToggleDocExplorerCallback(nil);SetIsInspectorVisibleFunc(nil);SetIsDocExplorerVisibleFunc(nil);SetSettingsCallback(nil);
  FreeAndNil(FMenuIntegration);

  // 키보드 바인딩 해제
  if (FKeyBindingIndex >= 0) and
     Supports(BorlandIDEServices, IOTAKeyboardServices, LKeyServices) then
  begin
    LKeyServices.RemoveKeyboardBinding(FKeyBindingIndex);
  end;

  // 에디터 노티파이어 해제
  if (FEditorNotifierIndex >= 0) and
     Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
  begin
    LEditorServices.RemoveNotifier(FEditorNotifierIndex);
  end;

  FreeAndNil(FUndocNavigator);
  DestroyDocExplorer;
  DestroyDocInspector;
  if Assigned(UnregisterFieldAddress) then
    UnregisterFieldAddress(@FDocInspector);
  UnRegisterClass(TDocInspectorForm);
  inherited;
end;

procedure TXmlDocWizard.AfterSave;
begin
  // not used
end;

procedure TXmlDocWizard.BeforeSave;
begin
  // not used
end;

procedure TXmlDocWizard.CreateDocExplorer;
begin
  if not Assigned(FDocExplorer) then
  begin
    FDocExplorer := TDocExplorerForm.Create(nil);
    FDocExplorer.Show;
    FDocExplorer.RefreshFromCurrentEditor;
  end
  else
  begin
    if FDocExplorer.Visible then
      FDocExplorer.Hide
    else
    begin
      FDocExplorer.Show;
      FDocExplorer.RefreshFromCurrentEditor;
    end;
  end;
end;

procedure TXmlDocWizard.CreateDocInspector;
begin
  if not Assigned(FDocInspector) then
  begin
    FDocInspector := TDocInspectorForm.Create(nil);
    FDocInspector.Show;
    FDocInspector.RefreshFromCurrentEditor;
  end
  else
  begin
    if FDocInspector.Visible then
      FDocInspector.Hide
    else
    begin
      FDocInspector.Show;
      FDocInspector.RefreshFromCurrentEditor;
    end;
  end;
end;

procedure TXmlDocWizard.Destroyed;
begin
  // not used
end;

procedure TXmlDocWizard.DestroyDocExplorer;
begin
  FreeAndNil(FDocExplorer);
end;

procedure TXmlDocWizard.DestroyDocInspector;
begin
  FreeAndNil(FDocInspector);
end;

procedure TXmlDocWizard.Execute;
begin
  CreateDocInspector;
end;

procedure TXmlDocWizard.GenerateForPrefix(ALine:Integer;const Source,FileName:string);
var Lines:TArray<string>;Parser:TDocParser;Element:TCodeElementInfo;Model:TXmlDocModel;Editor:IOTASourceEditor;
begin
 if not TPluginSettings.Instance.Global.Stub.AutoGenerate then Exit;
 Lines:=Source.Split([#10]);if (ALine<1) or (ALine>Length(Lines)) or (Trim(Lines[ALine-1])<>'///') then Exit;
 Editor:=XmlDoc.Plugin.EditSession.SourceEditorForFile(FileName);if not Assigned(Editor) or (EditorSource(Editor)<>Source) then Exit;
 Parser:=TDocParser.Create;
 try
  try ConfigureDeclarationContext(Parser,nil,FileName);Parser.ParseSource(Source,FileName);except Exit;end;
  Element:=Parser.GetElementAtLine(ALine);if (Element.Name='') or (Trim(Element.ExistingDocXml)<>'') then Exit;
  Model:=TDocStubGenerator.GenerateStub(Element, TPluginSettings.Instance.Global.Stub.PlaceholderPrefix, TPluginSettings.Instance.Global.Stub.IncludePlaceholders);
  try TDocOTAWriter.ApplyToEditor(Editor,Element,Model);finally Model.Free;end;
 finally Parser.Free;end;
end;

procedure TXmlDocWizard.GenerateStubForCurrentElement;
var
  LEditor: IOTASourceEditor;
  LParser: XmlDoc.Parser.TDocParser;
  LElement: TCodeElementInfo;
  LStub: TXmlDocModel;
  LView: IOTAEditView;
  LSource: string;
  LReader: IOTAEditReader;
  LBuf: TBytes;
  LBufLen: Integer;
begin
  LEditor := TDocOTAWriter.GetCurrentSourceEditor;
  if not Assigned(LEditor) then
    Exit;

  LSource:=EditorSource(LEditor);

  // 현재 커서 위치의 요소 찾기
  LParser := XmlDoc.Parser.TDocParser.Create;
  try
    ConfigureDeclarationContext(LParser,nil,LEditor.FileName);
    LParser.ParseSource(LSource,LEditor.FileName);
    LView := LEditor.GetEditView(0);
    if not Assigned(LView) then
      Exit;

    LElement := LParser.GetElementAtLine(LView.CursorPos.Line);
    if LElement.Name = '' then
      Exit;

    // 이미 문서가 있으면 무시
    if LElement.ExistingDocXml <> '' then
      Exit;

    LStub := TDocStubGenerator.GenerateStub(LElement, TPluginSettings.Instance.Global.Stub.PlaceholderPrefix, TPluginSettings.Instance.Global.Stub.IncludePlaceholders);
    try
      TDocOTAWriter.ApplyToEditor(LEditor, LElement, LStub);
    finally
      LStub.Free;
    end;
  finally
    LParser.Free;
  end;
end;

function TXmlDocWizard.GetIDString: string;
begin
  Result := 'XmlDocPlugin.Wizard';
end;

function TXmlDocWizard.GetMenuText: string;
begin
  Result := 'Toggle Doc Inspector';
end;

function TXmlDocWizard.GetName: string;
begin
  Result := 'XmlDoc Plugin';
end;

function TXmlDocWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TXmlDocWizard.Modified;
begin
  // not used
end;

procedure TXmlDocWizard.SetupCallbacks;
begin
  SetDocumentationCommandCallback(procedure(Command:string)
  begin
    if not Assigned(FDocInspector) then FDocInspector:=TDocInspectorForm.Create(nil);
    FDocInspector.Show;FDocInspector.RefreshFromCurrentEditor;FDocInspector.ExecuteCommand(Command);
  end);

  SetToggleInspectorCallback(
    function: Boolean
    begin
      CreateDocInspector;
      Result := Assigned(FDocInspector) and FDocInspector.Visible;
    end
  );

  SetToggleDocExplorerCallback(
    function: Boolean
    begin
      CreateDocExplorer;
      Result := Assigned(FDocExplorer) and FDocExplorer.Visible;
    end
  );

  SetIsInspectorVisibleFunc(
    function: Boolean
    begin
      Result := Assigned(FDocInspector) and FDocInspector.Visible;
    end
  );

  SetIsDocExplorerVisibleFunc(
    function: Boolean
    begin
      Result := Assigned(FDocExplorer) and FDocExplorer.Visible;
    end
  );

  SetGenerateStubCallback(
    procedure
    begin
      GenerateStubForCurrentElement;
    end
  );

  SetGenerateHelpCallback(
    procedure
    begin
      ShowBatchGenDialog;
    end
  );

  SetCoverageReportCallback(
    procedure
    begin
      ShowCoverageDialog;
    end
  );

  SetNextUndocumentedCallback(
    procedure
    begin
      FUndocNavigator.JumpToNext;
    end
  );

  SetPreviousUndocumentedCallback(
    procedure
    begin
      FUndocNavigator.JumpToPrevious;
    end
  );

  SetSettingsCallback(
    procedure
    begin
      if ShowSettingsDialog then SettingsApplied;
    end
  );
end;

procedure TXmlDocWizard.SettingsApplied;
var LKeyServices:IOTAKeyboardServices;
begin
        FMenuIntegration.RefreshShortcuts;
        if Assigned(FDocInspector) then
          FDocInspector.RefreshFromCurrentEditor;
        if Assigned(FDocExplorer) then
          FDocExplorer.RefreshFromCurrentEditor;

        if Supports(BorlandIDEServices, IOTAKeyboardServices, LKeyServices) then
        begin
          if FKeyBindingIndex >= 0 then
            LKeyServices.RemoveKeyboardBinding(FKeyBindingIndex);

          FKeyBindingIndex := LKeyServices.AddKeyboardBinding(TXmlDocKeyBinding.Create);
        end;
end;

end.
