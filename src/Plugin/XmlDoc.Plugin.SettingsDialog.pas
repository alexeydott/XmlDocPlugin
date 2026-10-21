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
  XmlDoc.Plugin.HelpInsight,
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
    tsHelpInsight: TTabSheet;
    cmbHintAppearance:TComboBox;btnHintPreview,btnRestoreHint:TButton;
    chkHelpInsightEnabled: TCheckBox;
    chkHelpInsightWrap: TCheckBox;
    chkHelpInsightCompact: TCheckBox;
    spnHintWidth: TSpinEdit;
    spnHintFontSize: TSpinEdit;
    spnHintLineHeight: TSpinEdit;
    spnHintParameterWidth: TSpinEdit;
    lblHintStatus: TLabel;
    btnExportHintCss: TButton;
    btnShellHintCss: TButton;

    procedure HintPreviewClick(Sender:TObject);
    procedure RestoreHintClick(Sender:TObject);
    procedure btnCreateThemeClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure AISettingsClick(Sender:TObject);
    procedure HelpInsightChanged(Sender: TObject);
    procedure ExportHintCssClick(Sender: TObject);
    procedure ShellHintCssClick(Sender: TObject);

  private
    FShortcutsChanged: Boolean;
    FShellHintCss: Boolean;

    procedure LoadThemes(const Selected: string);
    procedure LoadSettings;

    function HintSettingsFromControls: THelpInsightSettings;

  public
    procedure SaveSettings;
    function ValidateSettings: Boolean;
    property ShortcutsChanged: Boolean read FShortcutsChanged;
  end;

/// <summary>Returns the XSLT path selected by the IDE's preferred UI languages.</summary>
function IDEHelpInsightXsltPath:string;
/// <summary>Captures native IDE theme colours for Help Insight presentation and preview.</summary>
function IDEHelpInsightPalette:THelpInsightPalette;
/// <summary>Opens localized preferences shared with the Third Party IDE Options page.</summary>
/// <returns>True if preferences were accepted and saved.</returns>
function ShowSettingsDialog: Boolean;

implementation

uses Winapi.Windows,Vcl.Graphics,Vcl.Themes,Vcl.OleCtrls,SHDocVw,XmlDoc.Plugin.AISettings,System.IOUtils,XmlDoc.HelpGen.ThemeEngine,XmlDoc.I18n,XmlDoc.Plugin.Localization, ToolsAPI,Vcl.ActnList,XmlDoc.ShortcutValidation,Vcl.Dialogs;

{$R *.dfm}

function IDEHelpInsightXsltPath:string;
var Services:IOTAServices;
begin
 if Supports(BorlandIDEServices,IOTAServices,Services) then Result:=ChangeFileExt(HelpInsightCssPath(Services.GetIDEPreferredUILanguages),'.xsl') else Result:=ChangeFileExt(HelpInsightCssPath,'.xsl');
end;

function IDEHelpInsightPalette:THelpInsightPalette;
var Theme:IOTAIDEThemingServices;Background,Foreground:TColor;
 function Css(Color:TColor):string;
 var Value:Longint;
 begin Value:=ColorToRGB(Color);Result:=Format('#%.2x%.2x%.2x',[Value and 255,(Value shr 8) and 255,(Value shr 16) and 255]);end;
begin
 Background:=clWindow;Foreground:=clWindowText;
 if Supports(BorlandIDEServices,IOTAIDEThemingServices,Theme) and Theme.IDEThemingEnabled and Assigned(Theme.StyleServices) then begin Background:=Theme.StyleServices.GetSystemColor(clWindow);Foreground:=Theme.StyleServices.GetSystemColor(clWindowText);end;
 var RGB:=ColorToRGB(Background);
 if ((RGB and 255)*299+((RGB shr 8) and 255)*587+((RGB shr 16) and 255)*114)<128000 then Result:=THelpInsightPalette.Dark else Result:=THelpInsightPalette.Light;
 Result.Background:=Css(Background);Result.Foreground:=Css(Foreground);
end;

procedure TSettingsDialog.RestoreHintClick(Sender:TObject);
begin
 try RestoreHelpInsightTemplates(HelpInsightCssPath,IDEHelpInsightXsltPath);chkHelpInsightEnabled.Checked:=False;cmbHintAppearance.ItemIndex:=0;HelpInsightChanged(nil);
  var Saved:=TPluginSettings.Instance.Global;Saved.HelpInsight.Enabled:=False;Saved.HelpInsight.Extended:=False;TPluginSettings.Instance.Global:=Saved;TPluginSettings.Instance.Save;
 except on E:Exception do ShowMessage(E.Message);end;
end;

procedure TSettingsDialog.HintPreviewClick(Sender:TObject);
var Preview:TForm;Browser:TWebBrowser;FileName:string;
begin
 FileName:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName+'.html');Preview:=TForm.CreateNew(Self);
 try
  Preview.Caption:=TI18n.Instance.T('Help Insight preview');Preview.Position:=poMainFormCenter;Preview.Width:=MulDiv(800,CurrentPPI,96);Preview.Height:=MulDiv(650,CurrentPPI,96);
  var Xml:='<member DisplayName="TMapDocumentation.PrepareAndRenderMapWithClippingAndPixelDensity(Integer; Integer; Integer; Double; string; Boolean; string; out Integer): Boolean">'+
   '<summary><para>Prepares and renders a map with clipping, scaling and pixel density.</para></summary><param name="AViewportOffsetX" type="Integer">Horizontal offset. This description wraps onto several lines without overlapping the next parameter.</param>'+
   '<param name="APixelDensityScale" type="Double">Pixel density scale.</param><returns>True when rendering succeeds.</returns><remarks><para>Text with <b>emphasis</b>, a <see cref="TObject"/> reference and a line break.<br/>Second line.</para>'+
   '<list type="table"><listheader><term>Option</term><description>Meaning</description></listheader><item><term>Clipping</term><description>Restricts output to the viewport.</description></item></list>'+
   '<note type="caller">Provide a valid rendering context.</note></remarks></member>';
  TFile.WriteAllText(FileName,RenderHelpInsightPreview(Xml,HintSettingsFromControls,IDEHelpInsightPalette,HelpInsightCssPath,IDEHelpInsightXsltPath),TEncoding.UTF8);
  Browser:=TWebBrowser.Create(Preview);TWinControl(Browser).Parent:=Preview;Browser.Align:=alClient;Browser.Silent:=True;Browser.Navigate(FileName);Preview.ShowModal;
 finally Preview.Free;if TFile.Exists(FileName) then TFile.Delete(FileName);end;
end;

function ShowSettingsDialog: Boolean;
var
  LDialog: TSettingsDialog;
  Theme:IOTAIDEThemingServices;
begin
  Result := False;
  if Supports(BorlandIDEServices,IOTAIDEThemingServices,Theme) then Theme.RegisterFormClass(TSettingsDialog);
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
var Theme:IOTAIDEThemingServices;
begin
  FShortcutsChanged := False;
  LoadSettings;
  LocalizePluginUi(Self);
  var AppearanceIndex:=cmbHintAppearance.ItemIndex;
  cmbHintAppearance.Items[0]:=TI18n.Instance.T('IDE default');
  cmbHintAppearance.Items[1]:=TI18n.Instance.T('Extended');
  cmbHintAppearance.ItemIndex:=AppearanceIndex;
  HelpInsightChanged(nil);
  if Supports(BorlandIDEServices,IOTAIDEThemingServices,Theme) then Theme.ApplyTheme(Self);
end;

procedure TSettingsDialog.HelpInsightChanged(Sender: TObject);
begin
  cmbHintAppearance.Enabled:=chkHelpInsightEnabled.Checked;
  btnShellHintCss.Enabled:=(cmbHintAppearance.ItemIndex=0) and
    not (TFile.Exists(IDEHelpInsightXsltPath) and TFile.ReadAllText(IDEHelpInsightXsltPath).Contains('XmlDocPlugin native Help Insight'));
  btnShellHintCss.Hint:=TI18n.Instance.T('Enhanced templates can be exported for administrator installation.');btnShellHintCss.ShowHint:=True;
  spnHintWidth.Enabled := chkHelpInsightEnabled.Checked;
  spnHintFontSize.Enabled := chkHelpInsightEnabled.Checked;
  spnHintLineHeight.Enabled := chkHelpInsightEnabled.Checked;
  chkHelpInsightWrap.Enabled := chkHelpInsightEnabled.Checked;
  chkHelpInsightCompact.Enabled := chkHelpInsightEnabled.Checked;
  spnHintParameterWidth.Enabled := chkHelpInsightEnabled.Checked and chkHelpInsightCompact.Checked;
end;

function TSettingsDialog.HintSettingsFromControls: THelpInsightSettings;
begin
  Result.Enabled := chkHelpInsightEnabled.Checked;
  Result.Extended:=cmbHintAppearance.ItemIndex=1;
  Result.WrapSignature := chkHelpInsightWrap.Checked;
  Result.CompactParameters := chkHelpInsightCompact.Checked;
  Result.Width := spnHintWidth.Value;
  Result.FontSize := spnHintFontSize.Value;
  Result.LineHeight := spnHintLineHeight.Value;
  Result.ParameterWidth := spnHintParameterWidth.Value;
end;

procedure TSettingsDialog.ExportHintCssClick(Sender: TObject);
var Dialog: TSaveDialog;
begin
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Title := TI18n.Instance.T('Export Help Insight templates');
    Dialog.FileName := 'HelpInsight.css';
    Dialog.DefaultExt := 'css';
    Dialog.Filter := 'CSS (*.css)|*.css';
    Dialog.InitialDir := TPath.GetDocumentsPath;
    Dialog.Options := [ofOverwritePrompt, ofPathMustExist, ofEnableSizing];
    if not Dialog.Execute then Exit;
    try
      ExportHelpInsightTemplates(HelpInsightCssPath, Dialog.FileName, HintSettingsFromControls,IDEHelpInsightPalette,IDEHelpInsightXsltPath);
      ShowMessage(TI18n.Instance.T('Templates exported. Copy HelpInsight.css to ObjRepos and HelpInsight.xsl to ObjRepos and the IDE language folder. Restart the IDE.') +
        sLineBreak + Dialog.FileName + sLineBreak + HelpInsightCssPath);
    except
      on E: Exception do ShowMessage(E.Message);
    end;
  finally Dialog.Free; end;
end;

procedure TSettingsDialog.ShellHintCssClick(Sender: TObject);
begin
  FShellHintCss := True;
  try
    ModalResult := mrOk;
    btnOKClick(Sender);
  finally FShellHintCss := False; end;
end;

procedure TSettingsDialog.AISettingsClick(Sender:TObject);
var Project:IOTAProject;
begin Project:=GetActiveProject;if Assigned(Project) then ShowAISettings(ExtractFilePath(Project.FileName)) else ShowAISettings;end;

function TSettingsDialog.ValidateSettings: Boolean;
var Services:INTAServices;Actions:TCustomActionList;Conflicts:TArray<string>;RootMenu:TMenuItem;Previous:TShortcutSettings;
begin
  Actions:=nil;RootMenu:=nil;Previous:=TPluginSettings.Instance.Global.Shortcuts;
  if Supports(BorlandIDEServices,INTAServices,Services) then begin Actions:=Services.ActionList;if Assigned(Services.MainMenu) then RootMenu:=Services.MainMenu.Items;end;
  Conflicts:=DocumentationShortcutConflicts([hotToggleInspector.HotKey,hotGenerateStub.HotKey,hotGenerateHelp.HotKey,hotCoverageReport.HotKey,hotNextUndocumented.HotKey,hotPreviousUndocumented.HotKey],['Inspector','Generate stub','Generate help','Coverage','Next undocumented','Previous undocumented'],Actions,RootMenu,[Previous.ToggleInspector,Previous.GenerateStub,Previous.GenerateHelp,Previous.CoverageReport,Previous.NextUndocumented,Previous.PreviousUndocumented]);
  Result:=Length(Conflicts)=0;
  if not Result then ShowMessage(string.Join(sLineBreak,Conflicts));
end;

procedure TSettingsDialog.btnOKClick(Sender: TObject);
begin
  if not ValidateSettings then begin ModalResult:=mrNone;Exit;end;
  try
    SaveSettings;
  except
    on E: Exception do begin ModalResult:=mrNone;if not (E is EAbort) then ShowMessage(E.Message);end;
  end;
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

  chkHelpInsightEnabled.Checked := LSettings.HelpInsight.Enabled;
  cmbHintAppearance.ItemIndex:=Ord(LSettings.HelpInsight.Extended);
  chkHelpInsightWrap.Checked := LSettings.HelpInsight.WrapSignature;
  chkHelpInsightCompact.Checked := LSettings.HelpInsight.CompactParameters;
  spnHintWidth.Value := LSettings.HelpInsight.Width;
  spnHintFontSize.Value := LSettings.HelpInsight.FontSize;
  spnHintLineHeight.Value := LSettings.HelpInsight.LineHeight;
  spnHintParameterWidth.Value := LSettings.HelpInsight.ParameterWidth;
  lblHintStatus.Caption := HelpInsightCssPath;
  lblHintStatus.Hint := HelpInsightCssPath;

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
  LSettings.HelpInsight := HintSettingsFromControls;

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

  try
    TI18n.Instance.SetLanguage(LSettings.General.Language);
    if FShellHintCss and (LSettings.HelpInsight.Extended or not btnShellHintCss.Enabled) then raise Exception.Create(TI18n.Instance.T('Export or restore templates with write access to the IDE folder.'));
    if FShellHintCss then
      ApplyHelpInsightCssWithShell(HelpInsightCssPath, LSettings.HelpInsight, Handle)
    else
      ApplyHelpInsightPresentation(HelpInsightCssPath, LSettings.HelpInsight,IDEHelpInsightPalette,IDEHelpInsightXsltPath);
  except
    on E: EAbort do begin TI18n.Instance.SetLanguage(TPluginSettings.Instance.Global.General.Language);raise;end;
    on E: Exception do begin TI18n.Instance.SetLanguage(TPluginSettings.Instance.Global.General.Language);raise Exception.Create(
      TI18n.Instance.T('Cannot update Help Insight CSS. For a protected IDE folder, use Apply through Windows or export the CSS and copy it with administrator permission.') +
      sLineBreak + HelpInsightCssPath + sLineBreak + E.Message);end;
  end;
  TPluginSettings.Instance.Global := LSettings;
  TPluginSettings.Instance.Save;
end;

end.
