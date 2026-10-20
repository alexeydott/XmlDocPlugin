/// <summary>Supported global editor preferences, stub options and command shortcuts.</summary>
unit XmlDoc.Plugin.SettingsDialog;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Menus,
  XmlDoc.Plugin.Settings,
  XmlDoc.Logger, Vcl.Samples.Spin;

type
  /// <summary>Dialog for supported global preferences and command shortcuts.</summary>
  TSettingsDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    btnAISettings: TButton;
    chkAutoGenerate: TCheckBox;
    chkCollapseEmptySections: TCheckBox;
    chkShowSignatureHeader: TCheckBox;
    cmbDocumentationTheme: TComboBox;
    btnCreateTheme: TButton;
    cmbLanguage: TComboBox;
    cmbLogLevel: TComboBox;
    edtPlaceholderPrefix: TEdit;
    memPlaceholderMarkers: TMemo;
    hotCoverageReport: THotKey;
    hotGenerateHelp: THotKey;
    hotGenerateStub: THotKey;
    hotNextUndocumented: THotKey;
    hotPreviousUndocumented: THotKey;
    hotToggleInspector: THotKey;
    PageControl: TPageControl;
    spnDebounceMs: TSpinEdit;
    spnFontSize: TSpinEdit;
    spnSaveDebounceMs: TSpinEdit;
    tsAdvanced: TTabSheet;
    tsCodeGen: TTabSheet;
    tsGeneral: TTabSheet;
    tsShortcuts: TTabSheet;

    procedure btnCreateThemeClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure AISettingsClick(Sender:TObject);

  private
    FShortcutsChanged: Boolean;

    procedure LoadThemes(const Selected: string);
    procedure LoadSettings;
    procedure SaveSettings;

  public
    property ShortcutsChanged: Boolean read FShortcutsChanged;
  end;

/// <summary>Opens the plugin settings dialog.</summary>
/// <returns>True if preferences were accepted and saved.</returns>
function ShowSettingsDialog: Boolean;

implementation

uses XmlDoc.Plugin.AISettings,System.IOUtils,XmlDoc.HelpGen.ThemeEngine,XmlDoc.I18n,XmlDoc.Plugin.Localization, ToolsAPI,Vcl.ActnList,XmlDoc.ShortcutValidation,Vcl.Dialogs;

{$R *.dfm}

function ShowSettingsDialog: Boolean;
var
  LDialog: TSettingsDialog;
begin
  Result := False;
  LDialog := TSettingsDialog.Create(Application);
  try
    if LDialog.ShowModal = mrOk then
      Result := True;
  finally
    LDialog.Free;
  end;
end;

{ TSettingsDialog }

procedure TSettingsDialog.FormCreate(Sender: TObject);
begin
  FShortcutsChanged := False;
  LoadSettings;
  LocalizePluginUi(Self);
end;

procedure TSettingsDialog.AISettingsClick(Sender:TObject);
var Project:IOTAProject;
begin Project:=GetActiveProject;if Assigned(Project) then ShowAISettings(ExtractFilePath(Project.FileName)) else ShowAISettings;end;

procedure TSettingsDialog.btnOKClick(Sender: TObject);
var Services:INTAServices;Actions:TCustomActionList;Conflicts:TArray<string>;RootMenu:TMenuItem;Previous:TShortcutSettings;
begin
  Actions:=nil;RootMenu:=nil;Previous:=TPluginSettings.Instance.Global.Shortcuts;
  if Supports(BorlandIDEServices,INTAServices,Services) then begin Actions:=Services.ActionList;if Assigned(Services.MainMenu) then RootMenu:=Services.MainMenu.Items;end;
  Conflicts:=DocumentationShortcutConflicts([hotToggleInspector.HotKey,hotGenerateStub.HotKey,hotGenerateHelp.HotKey,hotCoverageReport.HotKey,hotNextUndocumented.HotKey,hotPreviousUndocumented.HotKey],['Inspector','Generate stub','Generate help','Coverage','Next undocumented','Previous undocumented'],Actions,RootMenu,[Previous.ToggleInspector,Previous.GenerateStub,Previous.GenerateHelp,Previous.CoverageReport,Previous.NextUndocumented,Previous.PreviousUndocumented]);
  if Length(Conflicts)>0 then begin ModalResult:=mrNone;ShowMessage(string.Join(sLineBreak,Conflicts));Exit;end;
  SaveSettings;
end;

procedure TSettingsDialog.LoadThemes(const Selected: string);
begin
  TThemeEngine.Instance.Reload;
  cmbDocumentationTheme.Items.Clear;
  for var Name in TThemeEngine.Instance.GetAvailableThemes do
    cmbDocumentationTheme.Items.Add(Name);
  cmbDocumentationTheme.ItemIndex := cmbDocumentationTheme.Items.IndexOf(Selected);
  if cmbDocumentationTheme.ItemIndex < 0 then
    cmbDocumentationTheme.ItemIndex := cmbDocumentationTheme.Items.Add(Selected);
end;

procedure TSettingsDialog.btnCreateThemeClick(Sender: TObject);
var
  Name, Path: string;
begin
  Name := '';
  if not InputQuery(TI18n.Instance.T('Create CSS theme'), TI18n.Instance.T('New theme name:'), Name) then Exit;
  try
    Path := TThemeEngine.Instance.CreateCustomTheme(Name, cmbDocumentationTheme.Text);
    LoadThemes(TPath.GetFileNameWithoutExtension(Path));
    ShowMessage(TI18n.Instance.T('Theme saved:') + sLineBreak + Path);
  except
    on E: Exception do ShowMessage(E.Message);
  end;
end;

procedure TSettingsDialog.LoadSettings;
var
  LSettings: TGlobalSettings;
begin
  LSettings := TPluginSettings.Instance.Global;

  // General

  spnFontSize.Value := LSettings.Editor.FontSize;

  cmbLanguage.ItemIndex := cmbLanguage.Items.IndexOf(LSettings.General.Language);
  if cmbLanguage.ItemIndex < 0 then
    cmbLanguage.ItemIndex := 0;

  chkCollapseEmptySections.Checked := LSettings.Editor.CollapseEmptySections;
  chkShowSignatureHeader.Checked := LSettings.Editor.ShowSignatureHeader;

  // Code Generation
  LoadThemes(LSettings.General.DocumentationTheme);
  chkAutoGenerate.Checked := LSettings.Stub.AutoGenerate;
  edtPlaceholderPrefix.Text := LSettings.Stub.PlaceholderPrefix;
  memPlaceholderMarkers.Lines.Text := LSettings.Stub.PlaceholderMarkers;

  // Shortcuts
  hotToggleInspector.HotKey := LSettings.Shortcuts.ToggleInspector;
  hotGenerateStub.HotKey := LSettings.Shortcuts.GenerateStub;
  hotGenerateHelp.HotKey := LSettings.Shortcuts.GenerateHelp;
  hotCoverageReport.HotKey := LSettings.Shortcuts.CoverageReport;
  hotNextUndocumented.HotKey := LSettings.Shortcuts.NextUndocumented;
  hotPreviousUndocumented.HotKey := LSettings.Shortcuts.PreviousUndocumented;

  // Advanced
  spnDebounceMs.Value := LSettings.Editor.DebounceMs;
  spnSaveDebounceMs.Value := LSettings.Editor.SaveDebounceMs;
  cmbLogLevel.ItemIndex := Ord(LSettings.General.LogLevel);
end;

procedure TSettingsDialog.SaveSettings;
var
  LSettings: TGlobalSettings;
begin
  LSettings := TPluginSettings.Instance.Global;

  // General
  LSettings.Editor.FontSize := spnFontSize.Value;
  LSettings.General.Language := cmbLanguage.Text;
  LSettings.Editor.CollapseEmptySections := chkCollapseEmptySections.Checked;
  LSettings.Editor.ShowSignatureHeader := chkShowSignatureHeader.Checked;

  // Code Generation
  LSettings.General.DocumentationTheme := cmbDocumentationTheme.Text;
  LSettings.Stub.AutoGenerate := chkAutoGenerate.Checked;
  LSettings.Stub.PlaceholderPrefix := edtPlaceholderPrefix.Text;
  LSettings.Stub.PlaceholderMarkers := memPlaceholderMarkers.Lines.Text;

  // Shortcuts
  FShortcutsChanged :=
    (LSettings.Shortcuts.ToggleInspector <> hotToggleInspector.HotKey) or
    (LSettings.Shortcuts.GenerateStub <> hotGenerateStub.HotKey) or
    (LSettings.Shortcuts.GenerateHelp <> hotGenerateHelp.HotKey) or
    (LSettings.Shortcuts.CoverageReport <> hotCoverageReport.HotKey) or
    (LSettings.Shortcuts.NextUndocumented <> hotNextUndocumented.HotKey) or
    (LSettings.Shortcuts.PreviousUndocumented <> hotPreviousUndocumented.HotKey);

  LSettings.Shortcuts.ToggleInspector := hotToggleInspector.HotKey;
  LSettings.Shortcuts.GenerateStub := hotGenerateStub.HotKey;
  LSettings.Shortcuts.GenerateHelp := hotGenerateHelp.HotKey;
  LSettings.Shortcuts.CoverageReport := hotCoverageReport.HotKey;
  LSettings.Shortcuts.NextUndocumented := hotNextUndocumented.HotKey;
  LSettings.Shortcuts.PreviousUndocumented := hotPreviousUndocumented.HotKey;

  // Advanced
  LSettings.Editor.DebounceMs := spnDebounceMs.Value;
  LSettings.Editor.SaveDebounceMs := spnSaveDebounceMs.Value;
  LSettings.General.LogLevel := TLogLevel(cmbLogLevel.ItemIndex);

  TPluginSettings.Instance.Global := LSettings;
  TPluginSettings.Instance.Save;
end;

end.
