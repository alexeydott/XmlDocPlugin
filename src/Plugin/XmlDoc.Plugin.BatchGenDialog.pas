/// <summary>IDE documentation generation dialog and output orchestration.</summary>
unit XmlDoc.Plugin.BatchGenDialog;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.Threading,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls, Vcl.Samples.Spin,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  Vcl.FileCtrl,
  ToolsAPI,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.Scanner,
  XmlDoc.Plugin.EditSession,
  XmlDoc.Plugin.DeclarationContext,
  XmlDoc.ProjectContext,
  XmlDoc.HelpGen.BatchParser,
  XmlDoc.HelpGen.CrossRef,
  XmlDoc.HelpGen.Renderer,
  XmlDoc.HelpGen.Renderer.HTML,
  XmlDoc.HelpGen.Renderer.MD,
  XmlDoc.HelpGen.Renderer.CHM,
  XmlDoc.HelpGen.Renderer.JSON,
  XmlDoc.HelpGen.Renderer.HMXP,
  XmlDoc.HelpGen.SitePublisher,
  XmlDoc.HelpGen.Coverage,
  XmlDoc.Plugin.Settings,
  XmlDoc.Logger;

type
  /// <summary>IDE dialog for project and directory documentation generation.</summary>
  TBatchGenDialog = class(TForm)
  private
    FMinCoverage,FMinReady:TSpinEdit;
    FTheme: TComboBox;
    FBtnBrowseDir: TButton;
    FBtnBrowseOutput: TButton;
    FBtnCancel: TButton;
    FBtnGenerate: TButton;
    FCancelled: Boolean;
    FChkNumericFileNames: TCheckBox;
    FChkCHM: TCheckBox;
    FChkCoverage: TCheckBox;
    FChkDocusaurus: TCheckBox;
    FChkHTML: TCheckBox;
    FChkIncludePrivate: TCheckBox;
    FChkInterfaceOnly: TCheckBox;
    FChkJSON: TCheckBox;
    FChkHMXP: TCheckBox;
    FChkMarkdown: TCheckBox;
    FChkMkDocs: TCheckBox;
    FChkSearchIndex: TCheckBox;
    FChkVitePress: TCheckBox;
    FEdtDirectory: TEdit;
    FEdtExclude: TEdit;
    FEdtOutputDir: TEdit;
    FEdtTitle: TEdit;
    FLblPhase: TLabel;
    FLblProgress: TLabel;
    FLblStats: TLabel;
    FProgress: TProgressBar;
    FRbDirectory: TRadioButton;
    FRbProject: TRadioButton;

    procedure BuildUI;
    procedure DoGenerate;
    function  GetSelectedFormats: TArray<string>;
    procedure OnBrowseDirClick(Sender: TObject);
    procedure OnBrowseOutputClick(Sender: TObject);
    procedure OnCancelClick(Sender: TObject);
    procedure OnGenerateClick(Sender: TObject);
    procedure RenderFormat(const AFormat: string; const AUnits: TObjectList<TUnitDocInfo>; const AResolver: TCrossRefResolver; const ARenderOpts: TRenderOptions);
    procedure SetControlsEnabled(AEnabled: Boolean);
    procedure UpdateProgress(ACurrent, ATotal: Integer; const AMessage: string);

  public
    procedure ScaleForPPI(NewPPI: Integer); override;
    constructor Create(AOwner: TComponent); override;
  end;

/// <summary>Opens the documentation generation dialog.</summary>
procedure ShowBatchGenDialog;

implementation
uses XmlDoc.HelpGen.ThemeEngine,XmlDoc.Plugin.Localization,XmlDoc.I18n;


procedure ShowBatchGenDialog;
var
  LDialog: TBatchGenDialog;
begin
  LDialog := TBatchGenDialog.Create(Application);
  try
    LDialog.ShowModal;
  finally
    LDialog.Free;
  end;
end;

{ TBatchGenDialog }

constructor TBatchGenDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  // Establish the monitor DPI before creating controls in code. Their bounds
  // below are converted from design pixels to the form's current DPI.
  Caption := 'Generate API Documentation';
  Position := poMainFormCenter;
  BorderStyle := bsDialog;
  ScaleForCurrentDPI;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  ClientWidth := MulDiv(504, CurrentPPI, 96);
  FCancelled := False;

  BuildUI;
  LocalizePluginUi(Self);
end;

procedure TBatchGenDialog.ScaleForPPI(NewPPI: Integer);
begin
  inherited;
  // Keep the fixed button row visible when moving to a higher-DPI monitor.
  if HandleAllocated and (Height > Monitor.WorkareaRect.Height - MulDiv(16, NewPPI, 96)) then
    Height := Monitor.WorkareaRect.Height - MulDiv(16, NewPPI, 96);
end;

procedure TBatchGenDialog.BuildUI;
var
  LPanel, LButtons: TPanel;
  LContent: TScrollBox;
  LLabel: TLabel;
  LTop: Integer;
  LProjectPath: string;
  LSettings: TPluginSettings;
  function S(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, CurrentPPI, 96);
  end;
begin
  LContent := TScrollBox.Create(Self);
  LContent.Parent := Self;
  LContent.BorderStyle := bsNone;
  LContent.Align := alClient;
  LContent.HorzScrollBar.Visible := False;

  LButtons := TPanel.Create(Self);
  LButtons.Parent := Self;
  LButtons.BevelOuter := bvNone;
  LButtons.Align := alBottom;
  LButtons.Height := S(60);

  LSettings := TPluginSettings.Instance;

  // 현재 프로젝트 경로 가져오기
  LProjectPath := '';
  if Assigned(BorlandIDEServices) then
  begin
    try
      LProjectPath := (BorlandIDEServices as IOTAModuleServices).MainProjectGroup
        .ActiveProject.FileName;
    except
      LProjectPath := '';
    end;
  end;

  LSettings.LoadProject(ExtractFileDir(LProjectPath));

  LTop := S(16);

  // Source 섹션
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LContent;
  LLabel.ScaleForPPI(CurrentPPI);
  LLabel.Left := S(16);
  LLabel.Top := LTop;
  LLabel.Caption := TI18n.Instance.T('Source:');
  LLabel.Font.Style := [fsBold];
  Inc(LTop, S(22));

  FRbProject := TRadioButton.Create(Self);
  FRbProject.Parent := LContent;
  FRbProject.ScaleForPPI(CurrentPPI);
  FRbProject.Left := S(24);
  FRbProject.Top := LTop;
  FRbProject.Width := S(460);
  FRbProject.Height := S(20);
  if LProjectPath <> '' then
    FRbProject.Caption := 'Current Project (' + ExtractFileName(LProjectPath) + ')'
  else
    FRbProject.Caption := TI18n.Instance.T('Current Project (none)');
  FRbProject.Checked := LProjectPath <> '';
  FRbProject.Enabled := LProjectPath <> '';
  Inc(LTop, S(24));

  FRbDirectory := TRadioButton.Create(Self);
  FRbDirectory.Parent := LContent;
  FRbDirectory.ScaleForPPI(CurrentPPI);
  FRbDirectory.Left := S(24);
  FRbDirectory.Top := LTop;
  FRbDirectory.Width := S(80);
  FRbDirectory.Height := S(20);
  FRbDirectory.Caption := TI18n.Instance.T('Directory:');
  FRbDirectory.Checked := LProjectPath = '';
  Inc(LTop, S(1));

  FEdtDirectory := TEdit.Create(Self);
  FEdtDirectory.Parent := LContent;
  FEdtDirectory.ScaleForPPI(CurrentPPI);
  FEdtDirectory.Left := S(110);
  FEdtDirectory.Top := LTop - S(3);
  FEdtDirectory.Width := S(340);

  FBtnBrowseDir := TButton.Create(Self);
  FBtnBrowseDir.Parent := LContent;
  FBtnBrowseDir.ScaleForPPI(CurrentPPI);
  FBtnBrowseDir.Left := S(456);
  FBtnBrowseDir.Top := LTop - S(4);
  FBtnBrowseDir.Width := S(30);
  FBtnBrowseDir.Height := S(25);
  FBtnBrowseDir.Caption := '...';
  FBtnBrowseDir.OnClick := OnBrowseDirClick;
  Inc(LTop, S(30));

  // Exclude
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LContent;
  LLabel.ScaleForPPI(CurrentPPI);
  LLabel.Left := S(24);
  LLabel.Top := LTop;
  LLabel.Caption := TI18n.Instance.T('Exclude:');
  Inc(LTop, S(18));

  FEdtExclude := TEdit.Create(Self);
  FEdtExclude.Parent := LContent;
  FEdtExclude.ScaleForPPI(CurrentPPI);
  FEdtExclude.Left := S(24);
  FEdtExclude.Top := LTop;
  FEdtExclude.Width := S(462);
  FEdtExclude.Text := String.Join(';', LSettings.Project.HelpGen.ExcludePatterns);
  Inc(LTop, S(36));

  // Output Format 섹션
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LContent;
  LLabel.ScaleForPPI(CurrentPPI);
  LLabel.Left := S(16);
  LLabel.Top := LTop;
  LLabel.Caption := TI18n.Instance.T('Output Format:');
  LLabel.Font.Style := [fsBold];
  Inc(LTop, S(22));

  FChkHTML := TCheckBox.Create(Self);
  FChkHTML.Parent := LContent;
  FChkHTML.ScaleForPPI(CurrentPPI);
  FChkHTML.Left := S(24);
  FChkHTML.Top := LTop;
  FChkHTML.Width := S(220);
  FChkHTML.Height := S(20);
  FChkHTML.Caption := TI18n.Instance.T('HTML (Multi-page website)');


  FChkCHM := TCheckBox.Create(Self);
  FChkCHM.Parent := LContent;
  FChkCHM.ScaleForPPI(CurrentPPI);
  FChkCHM.Left := S(260);
  FChkCHM.Top := LTop;
  FChkCHM.Width := S(220);
  FChkCHM.Height := S(20);
  FChkCHM.Caption := TI18n.Instance.T('CHM (Windows Help)');
  Inc(LTop, S(24));

  FChkMarkdown := TCheckBox.Create(Self);
  FChkMarkdown.Parent := LContent;
  FChkMarkdown.ScaleForPPI(CurrentPPI);
  FChkMarkdown.Left := S(24);
  FChkMarkdown.Top := LTop;
  FChkMarkdown.Width := S(220);
  FChkMarkdown.Height := S(20);
  FChkMarkdown.Caption := TI18n.Instance.T('Markdown (GitHub Wiki)');

  FChkJSON := TCheckBox.Create(Self);
  FChkJSON.Parent := LContent;
  FChkJSON.ScaleForPPI(CurrentPPI);
  FChkJSON.Left := S(260);
  FChkJSON.Top := LTop;
  FChkJSON.Width := S(220);
  FChkJSON.Height := S(20);
  FChkJSON.Caption := TI18n.Instance.T('JSON (Machine-readable)');
  Inc(LTop, S(28));

  FChkHMXP := TCheckBox.Create(Self);
  FChkHMXP.Parent := LContent;
  FChkHMXP.ScaleForPPI(CurrentPPI);
  FChkHMXP.Left := S(24);
  FChkHMXP.Top := LTop;
  FChkHMXP.Width := S(440);
  FChkHMXP.Height := S(20);
  FChkHMXP.Caption := TI18n.Instance.T('Help && Manual (HMXP project)');
  Inc(LTop, S(28));

  // Static Site
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LContent;
  LLabel.ScaleForPPI(CurrentPPI);
  LLabel.Left := S(24);
  LLabel.Top := LTop;
  LLabel.Caption := TI18n.Instance.T('── Static Site ──');
  LLabel.Font.Color := clGray;
  Inc(LTop, S(20));

  FChkMkDocs := TCheckBox.Create(Self);
  FChkMkDocs.Parent := LContent;
  FChkMkDocs.ScaleForPPI(CurrentPPI);
  FChkMkDocs.Left := S(24);
  FChkMkDocs.Top := LTop;
  FChkMkDocs.Width := S(220);
  FChkMkDocs.Height := S(20);
  FChkMkDocs.Caption := TI18n.Instance.T('MkDocs (Material theme)');

  FChkDocusaurus := TCheckBox.Create(Self);
  FChkDocusaurus.Parent := LContent;
  FChkDocusaurus.ScaleForPPI(CurrentPPI);
  FChkDocusaurus.Left := S(260);
  FChkDocusaurus.Top := LTop;
  FChkDocusaurus.Width := S(220);
  FChkDocusaurus.Height := S(20);
  FChkDocusaurus.Caption := TI18n.Instance.T('Docusaurus (React-based)');
  Inc(LTop, S(24));

  FChkVitePress := TCheckBox.Create(Self);
  FChkVitePress.Parent := LContent;
  FChkVitePress.ScaleForPPI(CurrentPPI);
  FChkVitePress.Left := S(24);
  FChkVitePress.Top := LTop;
  FChkVitePress.Width := S(220);
  FChkVitePress.Height := S(20);
  FChkVitePress.Caption := TI18n.Instance.T('VitePress (Vue-based)');
  FChkHTML.Checked := MatchText('html', LSettings.Project.HelpGen.DefaultFormats);
  FChkCHM.Checked := MatchText('chm', LSettings.Project.HelpGen.DefaultFormats);
  FChkMarkdown.Checked := MatchText('md', LSettings.Project.HelpGen.DefaultFormats);
  FChkJSON.Checked := MatchText('json', LSettings.Project.HelpGen.DefaultFormats);
  FChkHMXP.Checked := MatchText('hmxp', LSettings.Project.HelpGen.DefaultFormats);
  FChkMkDocs.Checked := MatchText('mkdocs', LSettings.Project.HelpGen.DefaultFormats);
  FChkDocusaurus.Checked := MatchText('docusaurus', LSettings.Project.HelpGen.DefaultFormats);
  FChkVitePress.Checked := MatchText('vitepress', LSettings.Project.HelpGen.DefaultFormats);

  Inc(LTop, S(36));

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LContent;
  LLabel.ScaleForPPI(CurrentPPI);
  LLabel.Left := S(24);
  LLabel.Top := LTop;
  LLabel.Caption := TI18n.Instance.T('HTML / CHM theme:');
  FTheme := TComboBox.Create(Self);
  FTheme.Parent := LContent;
  FTheme.ScaleForPPI(CurrentPPI);
  FTheme.SetBounds(S(200), LTop - S(3), S(260), S(24));
  FTheme.Style := csDropDownList;
  TThemeEngine.Instance.Reload;
  for var Name in TThemeEngine.Instance.GetAvailableThemes do FTheme.Items.Add(Name);
  FTheme.ItemIndex := FTheme.Items.IndexOf(LSettings.DocumentationTheme);
  if FTheme.ItemIndex < 0 then FTheme.ItemIndex := FTheme.Items.Add(LSettings.DocumentationTheme);
  Inc(LTop, S(36));

  // Output Directory
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LContent;
  LLabel.ScaleForPPI(CurrentPPI);
  LLabel.Left := S(16);
  LLabel.Top := LTop;
  LLabel.Caption := TI18n.Instance.T('Output Directory:');
  LLabel.Font.Style := [fsBold];
  Inc(LTop, S(20));

  FEdtOutputDir := TEdit.Create(Self);
  FEdtOutputDir.Parent := LContent;
  FEdtOutputDir.ScaleForPPI(CurrentPPI);
  FEdtOutputDir.Left := S(24);
  FEdtOutputDir.Top := LTop;
  FEdtOutputDir.Width := S(426);
  FEdtOutputDir.Text := LSettings.Project.HelpGen.OutputDir;

  FBtnBrowseOutput := TButton.Create(Self);
  FBtnBrowseOutput.Parent := LContent;
  FBtnBrowseOutput.ScaleForPPI(CurrentPPI);
  FBtnBrowseOutput.Left := S(456);
  FBtnBrowseOutput.Top := LTop - S(1);
  FBtnBrowseOutput.Width := S(30);
  FBtnBrowseOutput.Height := S(25);
  FBtnBrowseOutput.Caption := '...';
  FBtnBrowseOutput.OnClick := OnBrowseOutputClick;
  Inc(LTop, S(34));

  // Options
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LContent;
  LLabel.ScaleForPPI(CurrentPPI);
  LLabel.Left := S(16);
  LLabel.Top := LTop;
  LLabel.Caption := TI18n.Instance.T('Options:');
  LLabel.Font.Style := [fsBold];
  Inc(LTop, S(22));

  FChkIncludePrivate := TCheckBox.Create(Self);
  FChkIncludePrivate.Parent := LContent;
  FChkIncludePrivate.ScaleForPPI(CurrentPPI);
  FChkIncludePrivate.Left := S(24);
  FChkIncludePrivate.Top := LTop;
  FChkIncludePrivate.Width := S(220);
  FChkIncludePrivate.Height := S(20);
  FChkIncludePrivate.Caption := TI18n.Instance.T('Include private members');
  FChkIncludePrivate.Checked := LSettings.Project.HelpGen.IncludePrivate;

  FChkSearchIndex := TCheckBox.Create(Self);
  FChkSearchIndex.Parent := LContent;
  FChkSearchIndex.ScaleForPPI(CurrentPPI);
  FChkSearchIndex.Left := S(260);
  FChkSearchIndex.Top := LTop;
  FChkSearchIndex.Width := S(220);
  FChkSearchIndex.Height := S(20);
  FChkSearchIndex.Caption := TI18n.Instance.T('Generate search index');
  FChkSearchIndex.Checked := True;
  Inc(LTop, S(24));

  FChkInterfaceOnly := TCheckBox.Create(Self);
  FChkInterfaceOnly.Parent := LContent;
  FChkInterfaceOnly.ScaleForPPI(CurrentPPI);
  FChkInterfaceOnly.Left := S(24);
  FChkInterfaceOnly.Top := LTop;
  FChkInterfaceOnly.Width := S(220);
  FChkInterfaceOnly.Height := S(20);
  FChkInterfaceOnly.Caption := TI18n.Instance.T('Interface section only');
  FChkInterfaceOnly.Checked := LSettings.Project.HelpGen.InterfaceOnly;

  FChkCoverage := TCheckBox.Create(Self);
  FChkCoverage.Parent := LContent;
  FChkCoverage.ScaleForPPI(CurrentPPI);
  FChkCoverage.Left := S(260);
  FChkCoverage.Top := LTop;
  FChkCoverage.Width := S(220);
  FChkCoverage.Height := S(20);
  FChkCoverage.Caption := TI18n.Instance.T('Generate coverage report');
  Inc(LTop, S(28));

  FChkNumericFileNames := TCheckBox.Create(Self);
  FChkNumericFileNames.Parent := LContent;
  FChkNumericFileNames.ScaleForPPI(CurrentPPI);
  FChkNumericFileNames.SetBounds(S(24), LTop, S(440), S(20));
  FChkNumericFileNames.Caption := TI18n.Instance.T('Use numeric topic file names');
  Inc(LTop, S(28));

  LLabel:=TLabel.Create(Self);LLabel.Parent:=LContent;LLabel.ScaleForPPI(CurrentPPI);
  LLabel.SetBounds(S(24),LTop+S(0),S(320),S(20));LLabel.Caption:=TI18n.Instance.T('Minimum comment presence (%):');
  FMinCoverage:=TSpinEdit.Create(Self);FMinCoverage.Parent:=LContent;FMinCoverage.ScaleForPPI(CurrentPPI);
  FMinCoverage.SetBounds(S(380),LTop+S(0-3),S(80),S(24));FMinCoverage.MinValue:=0;FMinCoverage.MaxValue:=100;
  FMinCoverage.Value:=LSettings.Project.HelpGen.CoverageMinPercent;
  LLabel:=TLabel.Create(Self);LLabel.Parent:=LContent;LLabel.ScaleForPPI(CurrentPPI);
  LLabel.SetBounds(S(24),LTop+S(36),S(320),S(20));LLabel.Caption:=TI18n.Instance.T('Minimum ready documentation (%):');
  FMinReady:=TSpinEdit.Create(Self);FMinReady.Parent:=LContent;FMinReady.ScaleForPPI(CurrentPPI);
  FMinReady.SetBounds(S(380),LTop+S(36-3),S(80),S(24));FMinReady.MinValue:=0;FMinReady.MaxValue:=100;
  FMinReady.Value:=LSettings.Project.HelpGen.ReadyMinPercent;
  Inc(LTop,S(74));
  LLabel:=TLabel.Create(Self);LLabel.Parent:=LContent;LLabel.ScaleForPPI(CurrentPPI);
  LLabel.SetBounds(S(24),LTop,S(450),S(44));LLabel.AutoSize:=False;LLabel.WordWrap:=True;
  LLabel.Caption:=TI18n.Instance.T('Presence counts comments; ready requires complete descriptions without unfinished placeholders or errors. Zero disables a threshold.');
  Inc(LTop,S(50));

  // Title
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LContent;
  LLabel.ScaleForPPI(CurrentPPI);
  LLabel.Left := S(24);
  LLabel.Top := LTop;
  LLabel.Caption := TI18n.Instance.T('Title:');

  FEdtTitle := TEdit.Create(Self);
  FEdtTitle.Parent := LContent;
  FEdtTitle.ScaleForPPI(CurrentPPI);
  FEdtTitle.Left := S(70);
  FEdtTitle.Top := LTop - S(2);
  FEdtTitle.Width := S(416);
  FEdtTitle.Text := LSettings.Project.HelpGen.Title;
  if (FEdtTitle.Text = '') or (FEdtTitle.Text = 'API Reference') then
    if LProjectPath <> '' then
      FEdtTitle.Text := ChangeFileExt(ExtractFileName(LProjectPath), '')
    else FEdtTitle.Text := 'Documentation';
  Inc(LTop, S(38));

  // Progress 영역
  LPanel := TPanel.Create(Self);
  LPanel.Parent := LContent;
  LPanel.ScaleForPPI(CurrentPPI);
  LPanel.Left := S(16);
  LPanel.Top := LTop;
  LPanel.Width := S(472);
  LPanel.Height := S(60);
  LPanel.BevelOuter := bvLowered;

  FProgress := TProgressBar.Create(Self);
  FProgress.Parent := LPanel;
  FProgress.ScaleForPPI(CurrentPPI);
  FProgress.Left := S(8);
  FProgress.Top := S(8);
  FProgress.Width := S(456);
  FProgress.Height := S(16);

  FLblPhase := TLabel.Create(Self);
  FLblPhase.AutoSize := False;
  FLblPhase.Parent := LPanel;
  FLblPhase.ScaleForPPI(CurrentPPI);
  FLblPhase.Left := S(8);
  FLblPhase.Top := S(28);
  FLblPhase.Width := S(300);
  FLblPhase.Height := S(18);
  FLblPhase.EllipsisPosition := epEndEllipsis;
  FLblPhase.Caption := '';

  FLblStats := TLabel.Create(Self);
  FLblStats.AutoSize := False;
  FLblStats.Parent := LPanel;
  FLblStats.ScaleForPPI(CurrentPPI);
  FLblStats.Left := S(8);
  FLblStats.Top := S(42);
  FLblStats.Width := S(300);
  FLblStats.Height := S(18);
  FLblStats.EllipsisPosition := epEndEllipsis;
  FLblStats.Caption := '';

  FLblProgress := TLabel.Create(Self);
  FLblProgress.AutoSize := False;
  FLblProgress.Parent := LPanel;
  FLblProgress.ScaleForPPI(CurrentPPI);
  FLblProgress.Left := S(420);
  FLblProgress.Width := S(44);
  FLblProgress.Top := S(28);
  FLblProgress.Alignment := taRightJustify;
  FLblProgress.Height := S(18);
  FLblProgress.EllipsisPosition := epEndEllipsis;
  FLblProgress.Caption := '';
  Inc(LTop, S(72));

  // 버튼
  FBtnGenerate := TButton.Create(Self);
  FBtnGenerate.Parent := LButtons;
  FBtnGenerate.ScaleForPPI(CurrentPPI);
  FBtnGenerate.Left := S(300);
  FBtnGenerate.Top := S(16);
  FBtnGenerate.Width := S(90);
  FBtnGenerate.Height := S(28);
  FBtnGenerate.Caption := TI18n.Instance.T('Generate');
  FBtnGenerate.Default := True;
  FBtnGenerate.OnClick := OnGenerateClick;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := LButtons;
  FBtnCancel.ScaleForPPI(CurrentPPI);
  FBtnCancel.Left := S(396);
  FBtnCancel.Top := S(16);
  FBtnCancel.Width := S(90);
  FBtnCancel.Height := S(28);
  FBtnCancel.Caption := TI18n.Instance.T('Close');
  FBtnCancel.Cancel := True;
  FBtnCancel.OnClick := OnCancelClick;
  LContent.VertScrollBar.Range := LTop;
  ClientHeight := LTop + LButtons.Height;
  if Height > Monitor.WorkareaRect.Height - S(16) then
    Height := Monitor.WorkareaRect.Height - S(16);
end;

procedure TBatchGenDialog.OnBrowseDirClick(Sender: TObject);
var
  LDir: string;
begin
  LDir := FEdtDirectory.Text;
  if SelectDirectory(TI18n.Instance.T('Select source directory'), '', LDir) then
    FEdtDirectory.Text := LDir;
end;

procedure TBatchGenDialog.OnBrowseOutputClick(Sender: TObject);
var
  LDir: string;
begin
  LDir := FEdtOutputDir.Text;
  if SelectDirectory(TI18n.Instance.T('Select output directory'), '', LDir) then
    FEdtOutputDir.Text := LDir;
end;

procedure TBatchGenDialog.OnCancelClick(Sender: TObject);
begin
  FCancelled := True;
  ModalResult := mrCancel;
end;

procedure TBatchGenDialog.OnGenerateClick(Sender: TObject);
begin
  DoGenerate;
end;

function TBatchGenDialog.GetSelectedFormats: TArray<string>;
var
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    if FChkHTML.Checked then
      LList.Add('html');
    if FChkCHM.Checked then
      LList.Add('chm');
    if FChkMarkdown.Checked then
      LList.Add('md');
    if FChkHMXP.Checked then
      LList.Add('hmxp');
    if FChkJSON.Checked then
      LList.Add('json');
    if FChkMkDocs.Checked then
      LList.Add('mkdocs');
    if FChkDocusaurus.Checked then
      LList.Add('docusaurus');
    if FChkVitePress.Checked then
      LList.Add('vitepress');
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TBatchGenDialog.SetControlsEnabled(AEnabled: Boolean);
begin
  FMinCoverage.Enabled:=AEnabled;FMinReady.Enabled:=AEnabled;
  FTheme.Enabled := AEnabled;
  FBtnGenerate.Enabled := AEnabled;
  FRbProject.Enabled := AEnabled;
  FRbDirectory.Enabled := AEnabled;
  FEdtDirectory.Enabled := AEnabled;
  FEdtOutputDir.Enabled := AEnabled;
  FEdtTitle.Enabled := AEnabled;
  FEdtExclude.Enabled := AEnabled;
  FChkHTML.Enabled := AEnabled;
  FChkCHM.Enabled := AEnabled;
  FChkMarkdown.Enabled := AEnabled;
  FChkJSON.Enabled := AEnabled;
  FChkHMXP.Enabled := AEnabled;
  FChkMkDocs.Enabled := AEnabled;
  FChkDocusaurus.Enabled := AEnabled;
  FChkVitePress.Enabled := AEnabled;
  FChkIncludePrivate.Enabled := AEnabled;
  FChkInterfaceOnly.Enabled := AEnabled;
  FChkSearchIndex.Enabled := AEnabled;
  FChkCoverage.Enabled := AEnabled;
  FChkNumericFileNames.Enabled := AEnabled;

  if AEnabled then
    FBtnCancel.Caption := TI18n.Instance.T('Close')
  else
    FBtnCancel.Caption := TI18n.Instance.T('Cancel');
end;

procedure TBatchGenDialog.UpdateProgress(ACurrent, ATotal: Integer;
  const AMessage: string);
begin
  FProgress.Max := ATotal;
  FProgress.Position := ACurrent;
  FLblPhase.Caption := TI18n.Instance.TranslateText(AMessage);
  FLblProgress.Caption := Format('%d%%', [Round(ACurrent / ATotal * 100)]);
  Application.ProcessMessages;
end;

procedure TBatchGenDialog.DoGenerate;
var
  LFormats: TArray<string>;
  LScanner: TProjectScanner;
  LParser: TBatchParser;
  LResolver: TCrossRefResolver;
  LScanOpts: TScanOptions;
  LFiles: TArray<string>;
  LRenderOpts: TRenderOptions;
  LFormat: string;
  LProjectPath: string;
  LCoverage: TDocCoverageReport;
  LStats: TCoverageStats;
  LItems: TArray<TCoverageItem>;
  I: Integer;
begin
  LScanOpts := Default(TScanOptions);
  LRenderOpts := Default(TRenderOptions);
  LFormats := GetSelectedFormats;
  if Length(LFormats) = 0 then
  begin
    MessageDlg(TI18n.Instance.T('Please select at least one output format.'), mtWarning, [mbOK], 0);
    Exit;
  end;

  FCancelled := False;
  SetControlsEnabled(False);
  try
    // Pick up external CSS edits even when this dialog stays open between runs.
    TThemeEngine.Instance.Reload;
    // 소스 경로 결정
    LProjectPath := '';
    if FRbProject.Checked then
    begin
      try
        LProjectPath := (BorlandIDEServices as IOTAModuleServices).MainProjectGroup
          .ActiveProject.FileName;
      except
        MessageDlg(TI18n.Instance.T('No active project found.'), mtError, [mbOK], 0);
        Exit;
      end;
    end;

    FLblPhase.Caption := TI18n.Instance.T('Scanning source files...');
    FLblStats.Caption := '';
    Application.ProcessMessages;

    // 스캔
    LScanner := TProjectScanner.Create;
    try
      if LProjectPath <> '' then
      begin
        LScanOpts.Source := ssProjectFile;
        LScanOpts.ProjectPath := LProjectPath;
      end
      else
      begin
        LScanOpts.Source := ssDirectory;
        LScanOpts.ProjectPath := FEdtDirectory.Text;
      end;

      if FEdtExclude.Text <> '' then
        LScanOpts.ExcludePatterns := String(FEdtExclude.Text).Split([';']);

      var Context:=ActiveDocumentationContext;
      try
        if Assigned(Context) then begin LScanOpts.Configuration:=Context.Configuration;LScanOpts.Platform:=Context.Platform;end;
      finally Context.Free;end;
      LFiles := LScanner.Scan(LScanOpts);
      LScanOpts.Platform:=LScanner.Platform;LScanOpts.SearchPaths:=LScanner.SearchPaths;LScanOpts.Defines:=LScanner.Defines;
    finally
      LScanner.Free;
    end;

    if Length(LFiles) = 0 then
    begin
      MessageDlg(TI18n.Instance.T('No source files found.'), mtWarning, [mbOK], 0);
      Exit;
    end;

    FLblStats.Caption := Format(TI18n.Instance.T('Found %d source files.'), [Length(LFiles)]);
    Application.ProcessMessages;

    if FCancelled then
      Exit;

    // 파싱
    LParser := TBatchParser.Create;
    try
      LParser.OnProgress := UpdateProgress;
      LParser.SourceSnapshots:=CurrentSourceSnapshots;LParser.Platform:=LScanOpts.Platform;LParser.SearchPaths:=LScanOpts.SearchPaths;LParser.Defines:=LScanOpts.Defines;
      LParser.ParseAll(LFiles);

      if FCancelled then
        Exit;

      // 교차 참조
      FLblPhase.Caption := TI18n.Instance.T('Resolving cross-references...');
      Application.ProcessMessages;

      LResolver := TCrossRefResolver.Create(LParser.SymbolIndex);
      try
        LResolver.ResolveAllRefs(LParser.Units);

        if LResolver.Unresolved.Count > 0 then
          FLblStats.Caption := FLblStats.Caption +
            Format(TI18n.Instance.T(' | %d unresolved refs'), [LResolver.Unresolved.Count]);

        // 렌더링 옵션
        LRenderOpts.NumericFileNames := FChkNumericFileNames.Checked;
        LRenderOpts.OutputDir := FEdtOutputDir.Text;
        if TDirectory.Exists(LProjectPath) then LRenderOpts.ProjectDir:=LProjectPath else LRenderOpts.ProjectDir:=ExtractFilePath(LProjectPath);
        LRenderOpts.ProjectName := ChangeFileExt(ExtractFileName(LProjectPath), '');
        LRenderOpts.Title := FEdtTitle.Text;
        LRenderOpts.IncludePrivate := FChkIncludePrivate.Checked;
        LRenderOpts.IncludeSearchIndex := FChkSearchIndex.Checked;
        LRenderOpts.CSSTheme := FTheme.Text;

        // 형식별 렌더링
        for I := 0 to Length(LFormats) - 1 do
        begin
          LFormat := LFormats[I];
          if FCancelled then
            Exit;

          FLblPhase.Caption := TI18n.Instance.T('Rendering: ') + LFormat;
          FProgress.Position := 0;
          Application.ProcessMessages;

          RenderFormat(LFormat, LParser.Units, LResolver, LRenderOpts);
        end;

        // 커버리지
        if FChkCoverage.Checked or (FMinCoverage.Value>0) or (FMinReady.Value>0) then
        begin
          FLblPhase.Caption := TI18n.Instance.T('Analyzing coverage...');
          Application.ProcessMessages;

          LCoverage := TDocCoverageReport.Create;
      LCoverage.PlaceholderPrefix:=TPluginSettings.Instance.Global.Stub.PlaceholderPrefix;
      LCoverage.PlaceholderMarkers:=TPluginSettings.Instance.Global.Stub.PlaceholderMarkers;
          try
            LStats := LCoverage.Analyze(LParser.Units);
            try

            if FChkCoverage.Checked then
            begin
              LItems := LCoverage.GetUndocumented(LParser.Units);
              LCoverage.RenderHTMLReport(LStats, LItems,
                TPath.Combine(FEdtOutputDir.Text, 'coverage.html'));
            end;

            FLblStats.Caption := FLblStats.Caption +
              Format(TI18n.Instance.T(' | Coverage: %.1f%%'), [LStats.CoveragePercent]);
            var Failure:=TDocCoverageReport.ThresholdFailure(LStats,FMinCoverage.Value,FMinReady.Value);
            if Failure<>'' then raise Exception.Create(Failure);
            finally
              LStats.ByKind.Free;
              LStats.ByVisibility.Free;
              LStats.ByUnit.Free;
            end;
          finally
            LCoverage.Free;
          end;
        end;

      finally
        LResolver.Free;
      end;
    finally
      LParser.Free;
    end;

    FProgress.Position := FProgress.Max;
    FLblPhase.Caption := TI18n.Instance.T('Done!');
    FLblProgress.Caption := '100%';

    MessageDlg(Format(TI18n.Instance.T('Documentation generated successfully in: %s'),
      [FEdtOutputDir.Text]), mtInformation, [mbOK], 0);
  except
    on E: Exception do
    begin
      TLogger.Instance.Error('Batch generation failed: ' + E.Message,
        'TBatchGenDialog.DoGenerate');
      MessageDlg(TI18n.Instance.T('Error: ') + E.Message, mtError, [mbOK], 0);
    end;
  end;

  SetControlsEnabled(True);
end;

procedure TBatchGenDialog.RenderFormat(const AFormat: string;
  const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver;
  const ARenderOpts: TRenderOptions);
var
  LPublisher: TSitePublisher;
  LSiteOpts: TSitePublishOptions;
  LRenderer: IDocRenderer;
begin
  if AFormat = 'html' then
    THTMLDocRenderer.Create.Render(AUnits, AResolver, ARenderOpts)
  else if AFormat = 'md' then
    TMarkdownDocRenderer.Create.Render(AUnits, AResolver, ARenderOpts)
  else if AFormat = 'chm' then
    TCHMDocRenderer.Create.Render(AUnits, AResolver, ARenderOpts)
  else if (AFormat = 'hmxp') or (AFormat = 'helpmanual') then
  begin
    LRenderer := THMXPDocRenderer.Create;
    LRenderer.Render(AUnits, AResolver, ARenderOpts);
  end
  else if AFormat = 'json' then
    TJSONDocRenderer.Create.Render(AUnits, AResolver, ARenderOpts)
  else if (AFormat = 'mkdocs') or (AFormat = 'docusaurus') or (AFormat = 'vitepress') then
  begin
    LSiteOpts := Default(TSitePublishOptions);
    LSiteOpts.SiteName := ARenderOpts.Title;
    if LSiteOpts.SiteName = '' then
      LSiteOpts.SiteName := 'Documentation';

    if AFormat = 'mkdocs' then
      LSiteOpts.Generator := sgMkDocs
    else if AFormat = 'docusaurus' then
      LSiteOpts.Generator := sgDocusaurus
    else
      LSiteOpts.Generator := sgVitePress;

    LPublisher := TSitePublisher.Create;
    try
      LPublisher.Publish(AUnits, AResolver, LSiteOpts, ARenderOpts);
    finally
      LPublisher.Free;
    end;
  end;
end;

end.
