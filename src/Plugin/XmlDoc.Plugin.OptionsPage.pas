/// <summary>Embeds the shared plugin preferences in Tools Options under Third Party.</summary>
unit XmlDoc.Plugin.OptionsPage;

interface

uses System.Classes, System.SysUtils, Vcl.Forms, Vcl.Controls, Vcl.ExtCtrls,
  ToolsAPI, XmlDoc.Plugin.SettingsDialog;

type
  /// <summary>Resizable, scrollable host for the existing localized settings controls.</summary>
  TPluginOptionsFrame = class(TFrame)
  private
    FDialog: TSettingsDialog;
    FScroll: TScrollBox;
    FContent: TPanel;
    procedure LayoutContent(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Settings: TSettingsDialog read FDialog;
  end;

/// <summary>Registers a preferences page; the caller must unregister it before unloading.</summary>
function RegisterPluginOptions(const OnApplied: TProc): INTAAddInOptions;
/// <summary>Creates the page provider without registering it with the IDE.</summary>
function CreatePluginOptions(const OnApplied: TProc): INTAAddInOptions;
procedure UnregisterPluginOptions(var Page: INTAAddInOptions);

implementation

{$R *.dfm}

uses System.Math, Winapi.Windows, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Dialogs;

type
  TPluginOptions = class(TInterfacedObject, INTAAddInOptions)
  private
    FFrame: TPluginOptionsFrame;
    FOnApplied: TProc;
  public
    constructor Create(const OnApplied: TProc);
    function GetArea: string;
    function GetCaption: string;
    function GetFrameClass: TCustomFrameClass;
    procedure FrameCreated(AFrame: TCustomFrame);
    procedure DialogClosed(Accepted: Boolean);
    function ValidateContents: Boolean;
    function GetHelpContext: Integer;
    function IncludeInIDEInsight: Boolean;
  end;

constructor TPluginOptionsFrame.Create(AOwner: TComponent);
var Theme: IOTAIDEThemingServices;
begin
  inherited Create(AOwner);
  Align:=alClient;
  FScroll:=TScrollBox.Create(Self);
  FScroll.Parent:=Self;FScroll.Align:=alClient;FScroll.BorderStyle:=bsNone;
  FContent:=TPanel.Create(Self);
  FContent.Parent:=FScroll;FContent.BevelOuter:=bvNone;FContent.ParentBackground:=True;
  if Supports(BorlandIDEServices,IOTAIDEThemingServices,Theme) then
    Theme.RegisterFormClass(TSettingsDialog);
  FDialog:=TSettingsDialog.Create(Self);
  FDialog.PageControl.Parent:=FContent;
  FDialog.PageControl.Align:=alClient;
  // Stretch long fields while keeping compact numeric and shortcut controls compact.
  for var I:=0 to FDialog.ComponentCount-1 do
    if FDialog.Components[I] is TControl then begin
      var C:=TControl(FDialog.Components[I]);
      if (C.Parent is TTabSheet) and
        ((C is TEdit) or (C is TMemo) or (C is TComboBox) or
         ((C is TButton) and (C.Width>200))) then
        C.Anchors:=C.Anchors+[akRight];
    end;
  FScroll.OnResize:=LayoutContent;
  LayoutContent(nil);
  if Supports(BorlandIDEServices,IOTAIDEThemingServices,Theme) then Theme.ApplyTheme(Self);
end;

procedure TPluginOptionsFrame.LayoutContent(Sender:TObject);
begin
  if not Assigned(FContent) then Exit;
  FContent.SetBounds(0,0,Max(MulDiv(464,CurrentPPI,96),FScroll.ClientWidth),
    Max(MulDiv(475,CurrentPPI,96),FScroll.ClientHeight));
end;

destructor TPluginOptionsFrame.Destroy;
begin
  if Assigned(FScroll) then FScroll.OnResize:=nil;
  inherited;
end;

constructor TPluginOptions.Create(const OnApplied:TProc);
begin inherited Create;FOnApplied:=OnApplied;end;
function TPluginOptions.GetArea:string;
begin Result:='';end;
function TPluginOptions.GetCaption:string;
begin Result:='XmlDocPlugin';end;
function TPluginOptions.GetFrameClass:TCustomFrameClass;
begin Result:=TPluginOptionsFrame;end;
procedure TPluginOptions.FrameCreated(AFrame:TCustomFrame);
begin FFrame:=AFrame as TPluginOptionsFrame;end;
function TPluginOptions.ValidateContents:Boolean;
begin Result:=not Assigned(FFrame);if Assigned(FFrame) then Result:=FFrame.Settings.ValidateSettings;end;
procedure TPluginOptions.DialogClosed(Accepted:Boolean);
begin
  try
    if Accepted and Assigned(FFrame) then begin
      FFrame.Settings.SaveSettings;
      if Assigned(FOnApplied) then FOnApplied();
    end;
  except on E:Exception do if not (E is EAbort) then ShowMessage(E.Message);end;
  FFrame:=nil; // The IDE owns the frame and releases it after this callback.
end;
function TPluginOptions.GetHelpContext:Integer;
begin Result:=0;end;
function TPluginOptions.IncludeInIDEInsight:Boolean;
begin Result:=True;end;

function RegisterPluginOptions(const OnApplied:TProc):INTAAddInOptions;
var Services:INTAEnvironmentOptionsServices;
begin
  Result:=nil;
  if Supports(BorlandIDEServices,INTAEnvironmentOptionsServices,Services) then begin
    Result:=CreatePluginOptions(OnApplied);Services.RegisterAddInOptions(Result);
  end;
end;
function CreatePluginOptions(const OnApplied:TProc):INTAAddInOptions;
begin Result:=TPluginOptions.Create(OnApplied);end;
procedure UnregisterPluginOptions(var Page:INTAAddInOptions);
var Services:INTAEnvironmentOptionsServices;
begin
  if Assigned(Page) and Supports(BorlandIDEServices,INTAEnvironmentOptionsServices,Services) then
    Services.UnregisterAddInOptions(Page);
  Page:=nil;
end;
end.
