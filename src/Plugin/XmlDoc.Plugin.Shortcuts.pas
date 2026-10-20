/// <summary>IDE menu commands, keyboard bindings and callback registration.</summary>
unit XmlDoc.Plugin.Shortcuts;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Menus,
  Vcl.ActnList,
  ToolsAPI,
  XmlDoc.Plugin.Settings;

type
  /// <summary>Registers plugin keyboard commands through IOTAKeyboardBinding.</summary>
  TXmlDocKeyBinding = class(TNotifierObject, IOTAKeyboardBinding)
  private
    procedure DoGenerateHelp(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    procedure DoGenerateStub(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    procedure DoToggleInspector(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
  public
    { IOTAKeyboardBinding }
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
  end;

  /// <summary>Owns the plugin's IDE menu commands.</summary>
  TXmlDocMenuIntegration = class(TComponent)
  private
    FMiCoverageReport: TMenuItem;
    FMiGenerateHelp: TMenuItem;
    FMiGenerateStub: TMenuItem;
    FMenuItems: TList;
    FCommandActions:TList;
    FContextActions:TActionList;
    FEditorMenuRegistered:Boolean;
    FProjectMenuIndex:Integer;
    FMiNextUndocumented: TMenuItem;
    FMiPreviousUndocumented: TMenuItem;
    FMiToggleDocExplorer: TMenuItem;
    FMiToggleInspector: TMenuItem;

    procedure Notification(AComponent:TComponent;Operation:TOperation);override;
    procedure OnCommand(Sender:TObject);
    procedure OnAboutClick(Sender: TObject);
    procedure OnUserGuideClick(Sender:TObject);
    procedure OnCoverageReportClick(Sender: TObject);
    procedure OnDocumentMenuClick(Sender: TObject);
    procedure OnGenerateHelpClick(Sender: TObject);
    procedure OnGenerateStubClick(Sender: TObject);
    procedure OnNextUndocumentedClick(Sender: TObject);
    procedure OnPreviousUndocumentedClick(Sender: TObject);
    procedure OnSettingsClick(Sender: TObject);
    procedure OnToggleDocExplorerClick(Sender: TObject);
    procedure OnToggleInspectorClick(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// <para>Adds plugin commands to the IDE menu.</para>
    /// </summary>
    procedure InstallMenu;
    /// <summary>Updates menu shortcuts from the current preferences.</summary>
    procedure RefreshShortcuts;
    /// <summary>Removes plugin commands from the IDE menu.</summary>
    procedure UninstallMenu;
  end;

/// <summary>Registers the Inspector toggle callback.</summary>
/// <param name="ACallback">Callback returning visibility after toggling the view.</param>
procedure SetDocumentationCommandCallback(ACallback:TProc<string>);
procedure SetToggleInspectorCallback(ACallback: TFunc<Boolean>);

/// <summary>Registers the stub-generation callback.</summary>
/// <param name="ACallback">Callback invoked to generate a documentation stub.</param>
procedure SetGenerateStubCallback(ACallback: TProc);

/// <summary>Registers the documentation generation dialog callback.</summary>
/// <param name="ACallback">Callback invoked to open the dialog.</param>
procedure SetGenerateHelpCallback(ACallback: TProc);

/// <summary>Registers the coverage report callback.</summary>
/// <param name="ACallback">Callback invoked to open the report.</param>
procedure SetCoverageReportCallback(ACallback: TProc);

/// <summary>Registers navigation to the next undocumented declaration.</summary>
/// <param name="ACallback">Callback invoked to navigate to a declaration.</param>
procedure SetNextUndocumentedCallback(ACallback: TProc);

/// <summary>Registers navigation to the previous undocumented declaration.</summary>
/// <param name="ACallback">Callback invoked to navigate to a declaration.</param>
procedure SetPreviousUndocumentedCallback(ACallback: TProc);

/// <summary>Registers the Documentation Explorer toggle callback.</summary>
/// <param name="ACallback">Callback returning visibility after toggling the view.</param>
procedure SetToggleDocExplorerCallback(ACallback: TFunc<Boolean>);

/// <summary>Registers the Inspector visibility callback.</summary>
/// <param name="ACallback">Callback returning the view's current visibility.</param>
procedure SetIsInspectorVisibleFunc(ACallback: TFunc<Boolean>);

/// <summary>Registers the Explorer visibility callback.</summary>
/// <param name="ACallback">Callback returning the view's current visibility.</param>
procedure SetIsDocExplorerVisibleFunc(ACallback: TFunc<Boolean>);

/// <summary>Registers the settings dialog callback.</summary>
/// <param name="ACallback">Callback invoked to open the dialog.</param>
procedure SetSettingsCallback(ACallback: TProc);

implementation

uses
  XmlDoc.Plugin.Localization,XmlDoc.Plugin.AboutDialog,Winapi.Windows,Winapi.ShellAPI,System.IOUtils;

var
  GDocumentationCommand:TProc<string>;
  GToggleInspectorCallback: TFunc<Boolean>;
  GGenerateStubCallback: TProc;
  GGenerateHelpCallback: TProc;
  GCoverageReportCallback: TProc;
  GNextUndocumentedCallback: TProc;
  GPreviousUndocumentedCallback: TProc;
  GToggleDocExplorerCallback: TFunc<Boolean>;
  GIsInspectorVisibleFunc: TFunc<Boolean>;
  GIsDocExplorerVisibleFunc: TFunc<Boolean>;
  GSettingsCallback: TProc;

type TDocumentationProjectMenu=class(TNotifierObject,IOTAProjectManagerMenu)
 private
  FCaption,FName,FParent,FVerb:string;
  FChecked,FEnabled,FMulti:Boolean;
  FHelpContext,FPosition:Integer;
 public
  constructor Create(const Caption,Command:string);
  function GetCaption:string;
  procedure SetCaption(const Value:string);
  function GetChecked:Boolean;
  procedure SetChecked(Value:Boolean);
  function GetEnabled:Boolean;
  procedure SetEnabled(Value:Boolean);
  function GetHelpContext:Integer;
  procedure SetHelpContext(Value:Integer);
  function GetName:string;
  procedure SetName(const Value:string);
  function GetParent:string;
  procedure SetParent(const Value:string);
  function GetPosition:Integer;
  procedure SetPosition(Value:Integer);
  function GetVerb:string;
  procedure SetVerb(const Value:string);
  function GetIsMultiSelectable:Boolean;
  procedure SetIsMultiSelectable(Value:Boolean);
  procedure Execute(const MenuContextList:IInterfaceList);
  function PreExecute(const MenuContextList:IInterfaceList):Boolean;
  function PostExecute(const MenuContextList:IInterfaceList):Boolean;
 end;
 TDocumentationProjectMenuNotifier=class(TNotifierObject,IOTAProjectMenuItemCreatorNotifier)
 public
  procedure AddMenu(const Project:IOTAProject;const IdentList:TStrings;const ProjectManagerMenuList:IInterfaceList;IsMultiSelect:Boolean);
 end;

constructor TDocumentationProjectMenu.Create(const Caption,Command:string);
begin inherited Create;FCaption:=Caption;FVerb:=Command;FName:='XmlDocProject'+StringReplace(Command,'-','',[rfReplaceAll]);FEnabled:=True;FPosition:=pmmpUtilsSection+200;end;
function TDocumentationProjectMenu.GetCaption:string;
begin Result:=FCaption;end;
procedure TDocumentationProjectMenu.SetCaption(const Value:string);
begin FCaption:=Value;end;
function TDocumentationProjectMenu.GetChecked:Boolean;
begin Result:=FChecked;end;
procedure TDocumentationProjectMenu.SetChecked(Value:Boolean);
begin FChecked:=Value;end;
function TDocumentationProjectMenu.GetEnabled:Boolean;
begin Result:=FEnabled;end;
procedure TDocumentationProjectMenu.SetEnabled(Value:Boolean);
begin FEnabled:=Value;end;
function TDocumentationProjectMenu.GetHelpContext:Integer;
begin Result:=FHelpContext;end;
procedure TDocumentationProjectMenu.SetHelpContext(Value:Integer);
begin FHelpContext:=Value;end;
function TDocumentationProjectMenu.GetName:string;
begin Result:=FName;end;
procedure TDocumentationProjectMenu.SetName(const Value:string);
begin FName:=Value;end;
function TDocumentationProjectMenu.GetParent:string;
begin Result:=FParent;end;
procedure TDocumentationProjectMenu.SetParent(const Value:string);
begin FParent:=Value;end;
function TDocumentationProjectMenu.GetPosition:Integer;
begin Result:=FPosition;end;
procedure TDocumentationProjectMenu.SetPosition(Value:Integer);
begin FPosition:=Value;end;
function TDocumentationProjectMenu.GetVerb:string;
begin Result:=FVerb;end;
procedure TDocumentationProjectMenu.SetVerb(const Value:string);
begin FVerb:=Value;end;
function TDocumentationProjectMenu.GetIsMultiSelectable:Boolean;
begin Result:=FMulti;end;
procedure TDocumentationProjectMenu.SetIsMultiSelectable(Value:Boolean);
begin FMulti:=Value;end;
procedure TDocumentationProjectMenu.Execute(const MenuContextList:IInterfaceList);
var Context:IOTAProjectMenuContext;Services:IOTAModuleServices;
begin
 if (MenuContextList.Count=1) and Supports(MenuContextList[0],IOTAProjectMenuContext,Context) then begin
  Services:=BorlandIDEServices as IOTAModuleServices;
  if Assigned(Services.MainProjectGroup) and Assigned(Context.Project) then Services.MainProjectGroup.ActiveProject:=Context.Project;
  if SameText(ExtractFileExt(Context.Ident),'.pas') then (BorlandIDEServices as IOTAActionServices).OpenFile(Context.Ident);
 end;
 if Assigned(GDocumentationCommand) then GDocumentationCommand(FVerb);
end;
function TDocumentationProjectMenu.PreExecute(const MenuContextList:IInterfaceList):Boolean;
begin Result:=True;end;
function TDocumentationProjectMenu.PostExecute(const MenuContextList:IInterfaceList):Boolean;
begin Result:=True;end;
procedure TDocumentationProjectMenuNotifier.AddMenu(const Project:IOTAProject;const IdentList:TStrings;const ProjectManagerMenuList:IInterfaceList;IsMultiSelect:Boolean);
begin
 if IsMultiSelect or not Assigned(Project) then Exit;
 ProjectManagerMenuList.Add(TDocumentationProjectMenu.Create('Documentation Workspace','refresh-catalog'));
 ProjectManagerMenuList.Add(TDocumentationProjectMenu.Create('Documentation Problems','show-problems'));
end;

procedure SetDocumentationCommandCallback(ACallback:TProc<string>);
begin GDocumentationCommand:=ACallback;end;
procedure TXmlDocMenuIntegration.Notification(AComponent:TComponent;Operation:TOperation);
begin
 inherited;
 if Operation<>opRemove then Exit;
 if Assigned(FMenuItems) then FMenuItems.Remove(AComponent);
 if Assigned(FCommandActions) then FCommandActions.Remove(AComponent);
 if AComponent=FMiCoverageReport then FMiCoverageReport:=nil;
 if AComponent=FMiGenerateHelp then FMiGenerateHelp:=nil;
 if AComponent=FMiGenerateStub then FMiGenerateStub:=nil;
 if AComponent=FMiNextUndocumented then FMiNextUndocumented:=nil;
 if AComponent=FMiPreviousUndocumented then FMiPreviousUndocumented:=nil;
 if AComponent=FMiToggleDocExplorer then FMiToggleDocExplorer:=nil;
 if AComponent=FMiToggleInspector then FMiToggleInspector:=nil;
end;
procedure TXmlDocMenuIntegration.OnCommand(Sender:TObject);
begin
 if Assigned(GDocumentationCommand) then GDocumentationCommand(TAction(Sender).HelpKeyword);
end;
procedure SetToggleInspectorCallback(ACallback: TFunc<Boolean>);
begin
  GToggleInspectorCallback := ACallback;
end;

procedure SetGenerateStubCallback(ACallback: TProc);
begin
  GGenerateStubCallback := ACallback;
end;

procedure SetGenerateHelpCallback(ACallback: TProc);
begin
  GGenerateHelpCallback := ACallback;
end;

procedure SetCoverageReportCallback(ACallback: TProc);
begin
  GCoverageReportCallback := ACallback;
end;

procedure SetNextUndocumentedCallback(ACallback: TProc);
begin
  GNextUndocumentedCallback := ACallback;
end;

procedure SetPreviousUndocumentedCallback(ACallback: TProc);
begin
  GPreviousUndocumentedCallback := ACallback;
end;

procedure SetToggleDocExplorerCallback(ACallback: TFunc<Boolean>);
begin
  GToggleDocExplorerCallback := ACallback;
end;

procedure SetIsInspectorVisibleFunc(ACallback: TFunc<Boolean>);
begin
  GIsInspectorVisibleFunc := ACallback;
end;

procedure SetIsDocExplorerVisibleFunc(ACallback: TFunc<Boolean>);
begin
  GIsDocExplorerVisibleFunc := ACallback;
end;

procedure SetSettingsCallback(ACallback: TProc);
begin
  GSettingsCallback := ACallback;
end;

{ TXmlDocKeyBinding }

procedure TXmlDocKeyBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
var
  LSettings: TPluginSettings;
begin
  LSettings := TPluginSettings.Instance;

  BindingServices.AddKeyBinding(
    [LSettings.Global.Shortcuts.ToggleInspector],
    DoToggleInspector, nil);

  BindingServices.AddKeyBinding(
    [LSettings.Global.Shortcuts.GenerateStub],
    DoGenerateStub, nil);

  BindingServices.AddKeyBinding(
    [LSettings.Global.Shortcuts.GenerateHelp],
    DoGenerateHelp, nil);
end;

function TXmlDocKeyBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TXmlDocKeyBinding.GetDisplayName: string;
begin
  Result := 'XmlDoc Plugin Shortcuts';
end;

function TXmlDocKeyBinding.GetName: string;
begin
  Result := 'XmlDocPlugin.KeyBinding';
end;

procedure TXmlDocKeyBinding.DoGenerateHelp(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
begin
  BindingResult := krHandled;
  if Assigned(GGenerateHelpCallback) then
    GGenerateHelpCallback;
end;

procedure TXmlDocKeyBinding.DoGenerateStub(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
begin
  BindingResult := krHandled;
  if Assigned(GGenerateStubCallback) then
    GGenerateStubCallback;
end;

procedure TXmlDocKeyBinding.DoToggleInspector(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
begin
  BindingResult := krHandled;
  if Assigned(GToggleInspectorCallback) then
    GToggleInspectorCallback();
end;

{ TXmlDocMenuIntegration }

constructor TXmlDocMenuIntegration.Create;
begin
  inherited Create(nil);

  FProjectMenuIndex:=-1;FMenuItems := TList.Create;FCommandActions:=TList.Create;
end;

destructor TXmlDocMenuIntegration.Destroy;
begin
  UninstallMenu;
  FreeAndNil(FMenuItems);FreeAndNil(FCommandActions);

  inherited;
end;

procedure TXmlDocMenuIntegration.InstallMenu;
var
  LNTAServices: INTAServices;
  LMainMenu: TMainMenu;
  LToolsMenu: TMenuItem;
  LXmlDocMenu: TMenuItem;
  LItem: TMenuItem;
  Action,ContextAction:TAction;
  EditorServices:IOTAEditorServices;
  EditorMenu:INTAEditorLocalMenu;ProjectManager:IOTAProjectManager;
  Caption,Command:string;
  I: Integer;
begin
  if not Supports(BorlandIDEServices, INTAServices, LNTAServices) then
    Exit;

  LMainMenu := LNTAServices.MainMenu;
  if not Assigned(LMainMenu) then
    Exit;

  // Tools 메뉴 찾기
  LToolsMenu := nil;
  for I := 0 to LMainMenu.Items.Count - 1 do
  begin
    if SameText(LMainMenu.Items[I].Name, 'ToolsMenu') then
    begin
      LToolsMenu := LMainMenu.Items[I];
      Break;
    end;
  end;

  if not Assigned(LToolsMenu) then
    Exit;

  // Document 최상위 메뉴 생성
  LXmlDocMenu := TMenuItem.Create(Self);
  LXmlDocMenu.Caption := 'Document';
  LXmlDocMenu.Name := 'XmlDocDocumentMenu';
  LXmlDocMenu.OnClick := OnDocumentMenuClick;
  FMenuItems.Add(LXmlDocMenu);

  // Doc Inspector
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Doc Inspector';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.ToggleInspector;
  LItem.OnClick := OnToggleInspectorClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiToggleInspector := LItem;

  // Documentation Explorer
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Documentation Explorer';
  LItem.OnClick := OnToggleDocExplorerClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiToggleDocExplorer := LItem;

  // Generate Doc Stub
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Generate Doc Stub';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.GenerateStub;
  LItem.OnClick := OnGenerateStubClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiGenerateStub := LItem;

  // Separator
  LItem := TMenuItem.Create(Self);
  LItem.Caption := '-';
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  // Generate Help...
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Generate Help...';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.GenerateHelp;
  LItem.OnClick := OnGenerateHelpClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiGenerateHelp := LItem;

  // Coverage Report...
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Coverage Report...';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.CoverageReport;
  LItem.OnClick := OnCoverageReportClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiCoverageReport := LItem;

  // Separator
  LItem := TMenuItem.Create(Self);
  LItem.Caption := '-';
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  // Next Undocumented
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Next Undocumented';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.NextUndocumented;
  LItem.OnClick := OnNextUndocumentedClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiNextUndocumented := LItem;

  // Previous Undocumented
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Previous Undocumented';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.PreviousUndocumented;
  LItem.OnClick := OnPreviousUndocumentedClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiPreviousUndocumented := LItem;

  // Separator
  LItem := TMenuItem.Create(Self);
  LItem.Caption := '-';
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  // Settings...
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Settings...';
  LItem.OnClick := OnSettingsClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  // Separator
  LItem := TMenuItem.Create(Self);
  LItem.Caption := '-';
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  LItem:=TMenuItem.Create(Self);LItem.Caption:='User Guide';LItem.Hint:='Open the offline illustrated user guide';
  LItem.OnClick:=OnUserGuideClick;LXmlDocMenu.Add(LItem);FMenuItems.Add(LItem);

  // About...
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'About...';
  LItem.OnClick := OnAboutClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  FContextActions:=TActionList.Create(nil);
  for Command in ['sync-document','show-problems','open-xml','quick-documentation','pin-document','compact-document','insert-selection','format-document','fold-documentation','ai-describe','ai-rephrase'] do begin
    Caption:=Command;
    if Command='sync-document' then Caption:='Synchronize Documentation'
    else if Command='show-problems' then Caption:='Documentation Problems'
    else if Command='open-xml' then Caption:='Edit Documentation XML'
    else if Command='quick-documentation' then Caption:='Quick Documentation at Cursor'
    else if Command='pin-document' then Caption:='Pin Documentation'
    else if Command='compact-document' then Caption:='Compact Documentation Inspector'
    else if Command='insert-selection' then Caption:='Selected Source as Documentation Example'
    else if Command='format-document' then Caption:='Format Documentation'
    else if Command='fold-documentation' then Caption:='Fold Documentation Comments'
    else if Command='ai-describe' then Caption:='Describe method from code'
    else if Command='ai-rephrase' then Caption:='Rephrase summary';
    Action:=TAction.Create(Self);Action.Name:='XmlDocAction'+StringReplace(Command,'-','',[rfReplaceAll]);
    Action.Caption:=Caption;Action.Category:='Documentation';Action.HelpKeyword:=Command;Action.Hint:=Caption;
    Action.ActionList:=LNTAServices.ActionList;Action.OnExecute:=OnCommand;FCommandActions.Add(Action);
    ContextAction:=TAction.Create(FContextActions);ContextAction.Caption:=Caption;ContextAction.Category:='Documentation';ContextAction.HelpKeyword:=Command;ContextAction.Hint:=Caption;ContextAction.OnExecute:=OnCommand;ContextAction.ActionList:=FContextActions;
    LItem:=TMenuItem.Create(Self);LItem.Action:=Action;LXmlDocMenu.Add(LItem);FMenuItems.Add(LItem);
  end;

  if Supports(BorlandIDEServices,IOTAEditorServices,EditorServices) then begin
    EditorMenu:=EditorServices.GetEditorLocalMenu;if Assigned(EditorMenu) then begin EditorMenu.RegisterActionList(FContextActions,'XmlDocPlugin');FEditorMenuRegistered:=True;end;
  end;

  if Supports(BorlandIDEServices,IOTAProjectManager,ProjectManager) then FProjectMenuIndex:=ProjectManager.AddMenuItemCreatorNotifier(TDocumentationProjectMenuNotifier.Create);
  LocalizePluginUi(Self);LocalizePluginUi(FContextActions);
  // Tools 메뉴 오른쪽에 최상위 메뉴로 삽입
  I := LMainMenu.Items.IndexOf(LToolsMenu);
  if I >= 0 then
    LMainMenu.Items.Insert(I + 1, LXmlDocMenu)
  else
    LMainMenu.Items.Add(LXmlDocMenu);
end;

procedure TXmlDocMenuIntegration.RefreshShortcuts;
var
  LShortcuts: TShortcutSettings;
begin
  LocalizePluginUi(Self);LocalizePluginUi(FContextActions);
  LShortcuts := TPluginSettings.Instance.Global.Shortcuts;

  if Assigned(FMiToggleInspector) then
    FMiToggleInspector.ShortCut := LShortcuts.ToggleInspector;
  if Assigned(FMiGenerateStub) then
    FMiGenerateStub.ShortCut := LShortcuts.GenerateStub;
  if Assigned(FMiGenerateHelp) then
    FMiGenerateHelp.ShortCut := LShortcuts.GenerateHelp;
  if Assigned(FMiCoverageReport) then
    FMiCoverageReport.ShortCut := LShortcuts.CoverageReport;
  if Assigned(FMiNextUndocumented) then
    FMiNextUndocumented.ShortCut := LShortcuts.NextUndocumented;
  if Assigned(FMiPreviousUndocumented) then
    FMiPreviousUndocumented.ShortCut := LShortcuts.PreviousUndocumented;
end;

procedure TXmlDocMenuIntegration.UninstallMenu;
var
  I: Integer;
  LRootMenu: TMenuItem;
  EditorServices:IOTAEditorServices;EditorMenu:INTAEditorLocalMenu;ProjectManager:IOTAProjectManager;
begin
  // Acquire services only for the operation. Holding them for the wizard's
  // lifetime can keep the 64-bit IDE alive while it owns the wizard itself.
  if (FProjectMenuIndex>=0) and Supports(BorlandIDEServices,IOTAProjectManager,ProjectManager) then ProjectManager.RemoveMenuItemCreatorNotifier(FProjectMenuIndex);
  FProjectMenuIndex:=-1;
  if FEditorMenuRegistered and Supports(BorlandIDEServices,IOTAEditorServices,EditorServices) then begin
   EditorMenu:=EditorServices.GetEditorLocalMenu;if Assigned(EditorMenu) then EditorMenu.UnregisterActionList('XmlDocPlugin');
  end;FEditorMenuRegistered:=False;
  FreeAndNil(FContextActions);
  // 최상위 메뉴를 부모에서 먼저 분리
  if FMenuItems.Count > 0 then
  begin
    LRootMenu := TMenuItem(FMenuItems[0]);
    if Assigned(LRootMenu.Parent) then
      LRootMenu.Parent.Remove(LRootMenu);
  end;

  // 역순으로 제거 (자식 먼저, 부모 나중에)
  while FMenuItems.Count>0 do TMenuItem(FMenuItems[FMenuItems.Count-1]).Free;

  FMenuItems.Clear;
  while FCommandActions.Count>0 do TAction(FCommandActions[FCommandActions.Count-1]).Free;FCommandActions.Clear;
end;

procedure TXmlDocMenuIntegration.OnUserGuideClick(Sender:TObject);
var GuidePath:string;
begin
 GuidePath:=TPath.GetFullPath(TPath.Combine(ExtractFilePath(GetModuleName(HInstance)),'..\help\index.html'));
 if not TFile.Exists(GuidePath) then GuidePath:=TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),'XmlDocPlugin\Help\index.html');
 if not TFile.Exists(GuidePath) then raise Exception.Create('Offline user guide is missing. Reinstall XmlDocPlugin or run build-help.ps1.');
 if NativeInt(ShellExecute(0,'open',PChar(GuidePath),nil,nil,SW_SHOWNORMAL))<=32 then raise Exception.Create('Cannot open the offline user guide.');
end;

procedure TXmlDocMenuIntegration.OnAboutClick(Sender: TObject);
begin
  ShowAboutDialog;
end;

procedure TXmlDocMenuIntegration.OnCoverageReportClick(Sender: TObject);
begin
  if Assigned(GCoverageReportCallback) then
    GCoverageReportCallback;
end;

procedure TXmlDocMenuIntegration.OnDocumentMenuClick(Sender: TObject);
begin
  if Assigned(FMiToggleInspector) and Assigned(GIsInspectorVisibleFunc) then
    FMiToggleInspector.Checked := GIsInspectorVisibleFunc;

  if Assigned(FMiToggleDocExplorer) and Assigned(GIsDocExplorerVisibleFunc) then
    FMiToggleDocExplorer.Checked := GIsDocExplorerVisibleFunc;
end;

procedure TXmlDocMenuIntegration.OnGenerateHelpClick(Sender: TObject);
begin
  if Assigned(GGenerateHelpCallback) then
    GGenerateHelpCallback;
end;

procedure TXmlDocMenuIntegration.OnGenerateStubClick(Sender: TObject);
begin
  if Assigned(GGenerateStubCallback) then
    GGenerateStubCallback;
end;

procedure TXmlDocMenuIntegration.OnNextUndocumentedClick(Sender: TObject);
begin
  if Assigned(GNextUndocumentedCallback) then
    GNextUndocumentedCallback;
end;

procedure TXmlDocMenuIntegration.OnPreviousUndocumentedClick(Sender: TObject);
begin
  if Assigned(GPreviousUndocumentedCallback) then
    GPreviousUndocumentedCallback;
end;

procedure TXmlDocMenuIntegration.OnSettingsClick(Sender: TObject);
begin
  if Assigned(GSettingsCallback) then
    GSettingsCallback;
end;

procedure TXmlDocMenuIntegration.OnToggleDocExplorerClick(Sender: TObject);
begin
  if Assigned(GToggleDocExplorerCallback) then
    GToggleDocExplorerCallback;
end;

procedure TXmlDocMenuIntegration.OnToggleInspectorClick(Sender: TObject);
begin
  if Assigned(GToggleInspectorCallback) then
    GToggleInspectorCallback;
end;

end.
