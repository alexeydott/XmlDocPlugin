/// <summary>WebView2 resource hosting, editor settings and persistent section state.</summary>
unit XmlDoc.Plugin.Browser;

interface

uses
  System.Classes, System.SysUtils, Vcl.Edge, Vcl.ExtCtrls;

type
  // Navigation must run after TEdgeBrowser finishes restoring its previous URI.
  TXmlDocBrowser = class(TEdgeBrowser)
  private
    FLoadTimer: TTimer;
    FHtml: string;
    FResourceName: string;
    FResourceRoot:string;
    FResourceBase:string;
    FResourceStatus:string;
    FAppliedSettings:string;
    FHostTheme:string;
    procedure LoadTimer(Sender: TObject);
  protected
    procedure DestroyWnd;override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadEditorResource(AInstance: THandle; const AName: string);
    procedure RestoreSections;
    procedure SaveSections(const AJson: string);
    procedure ApplySettings;
    procedure MapResources(const Root:string);
    property ResourceStatus:string read FResourceStatus;
    property ResourceBase:string read FResourceBase;
    property HostTheme:string read FHostTheme write FHostTheme;
  end;

procedure ConfigureWebViewLoader;

implementation

uses
  System.IOUtils, System.JSON, System.Hash, System.Win.Registry, Winapi.Windows, Winapi.EdgeUtils,
  XmlDoc.Plugin.Settings,XmlDoc.Plugin.Localization,XmlDoc.I18n,WebView2;

{$IF CompilerVersion < 36.0}
// Delphi 11 ships the base WebView2 interface only. Keep the extension vtable
// in SDK order; IUnknown parameters stand for unused COM callback interfaces.
type
 ICoreWebView2_2=interface(ICoreWebView2)
  ['{9E8F0CF8-E670-4B5E-B2BC-73E061E3184C}']
  function add_WebResourceResponseReceived(const Handler:IUnknown;out Token:EventRegistrationToken):HRESULT;stdcall;
  function remove_WebResourceResponseReceived(Token:EventRegistrationToken):HRESULT;stdcall;
  function NavigateWithWebResourceRequest(const Request:ICoreWebView2WebResourceRequest):HRESULT;stdcall;
  function add_DOMContentLoaded(const Handler:IUnknown;out Token:EventRegistrationToken):HRESULT;stdcall;
  function remove_DOMContentLoaded(Token:EventRegistrationToken):HRESULT;stdcall;
  function Get_CookieManager(out Manager:IUnknown):HRESULT;stdcall;
  function Get_Environment(out Environment:ICoreWebView2Environment):HRESULT;stdcall;
 end;
 ICoreWebView2_3=interface(ICoreWebView2_2)
  ['{A0D6DF20-3B92-416D-AA0C-437A9C727857}']
  function TrySuspend(const Handler:IUnknown):HRESULT;stdcall;
  function Resume:HRESULT;stdcall;
  function Get_IsSuspended(out Value:Integer):HRESULT;stdcall;
  function SetVirtualHostNameToFolderMapping(Host,Folder:PWideChar;AccessKind:Integer):HRESULT;stdcall;
  function ClearVirtualHostNameToFolderMapping(Host:PWideChar):HRESULT;stdcall;
 end;
const COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS=2;
var WebViewLoaderHandle:HMODULE;
{$ENDIF}

procedure ConfigureWebViewLoader;
var
  LPath: string;
begin
  LPath := TPath.Combine(ExtractFilePath(GetModuleName(HInstance)), 'WebView2Loader.dll');
  if TFile.Exists(LPath) then
  begin
    {$IF CompilerVersion >= 36.0}
    SetWebView2Path(LPath);
    {$ELSE}
    // The older EdgeUtils loads by basename. Pin the adjacent loader first,
    // so its subsequent LoadLibrary call resolves the same module.
    if WebViewLoaderHandle=0 then WebViewLoaderHandle:=LoadLibraryEx(PChar(LPath),0,LOAD_WITH_ALTERED_SEARCH_PATH);
    {$ENDIF}
  end;
end;

constructor TXmlDocBrowser.Create(AOwner: TComponent);
begin
  ConfigureWebViewLoader;
  inherited;
  FLoadTimer := TTimer.Create(Self);
  FLoadTimer.Enabled := False;
  FLoadTimer.Interval := 1;
  FLoadTimer.OnTimer := LoadTimer;
end;

procedure TXmlDocBrowser.LoadEditorResource(AInstance: THandle; const AName: string);
var
  LStream: TResourceStream;
  LBytes: TBytes;
begin
  FResourceName := AName;
  LStream := TResourceStream.Create(AInstance, AName, RT_RCDATA);
  try
    SetLength(LBytes, LStream.Size);
    LStream.ReadBuffer(LBytes, Length(LBytes));
    FHtml := TEncoding.UTF8.GetString(LBytes);
  finally
    LStream.Free;
  end;
  FLoadTimer.Enabled := True;
end;

procedure TXmlDocBrowser.RestoreSections;
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_READ);
  try
    if LReg.OpenKeyReadOnly('Software\XmlDocPlugin\EditorSections') and
       LReg.ValueExists(FResourceName) then
      ExecuteScript('window.xmlDocSections?.restore(' + LReg.ReadString(FResourceName) + ');');
  finally
    LReg.Free;
  end;
end;

procedure TXmlDocBrowser.SaveSections(const AJson: string);
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_WRITE);
  try
    if LReg.OpenKey('Software\XmlDocPlugin\EditorSections', True) then
      LReg.WriteString(FResourceName, AJson);
  finally
    LReg.Free;
  end;
end;

procedure TXmlDocBrowser.MapResources(const Root:string);
var View:ICoreWebView2_3;Status:HRESULT;Folder,Host:string;
begin
 Folder:=ExcludeTrailingPathDelimiter(TPath.GetFullPath(Root));
 if SameText(Folder,FResourceRoot) then Exit;
 if not TDirectory.Exists(Folder) then begin FResourceStatus:='Missing resource directory: '+Folder;Exit;end;
 // A VCL handle recreation creates a new WebView controller. Reapply the map
 // even when the project path is unchanged.
 if not Supports(DefaultInterface,ICoreWebView2_3,View) then begin FResourceStatus:='WebView2 resource mapping is unavailable';Exit;end;
 // A distinct host avoids changing an existing mapping, which would require
 // navigation and discard editor drafts and AI queue state.
 Host:='r'+Copy(THashSHA2.GetHashString(LowerCase(Folder)),1,32)+'.xmldoc.resources';
 Status:=View.SetVirtualHostNameToFolderMapping(PChar(Host),PChar(Folder),COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS);
 FResourceStatus:=Folder+' HRESULT='+IntToHex(Status,8);
 if Status=S_OK then begin FResourceRoot:=Folder;FResourceBase:='https://'+Host+'/';end;
end;

procedure TXmlDocBrowser.ApplySettings;
var
  LJson: TJSONObject;
  LSettings: TEditorSettings;
begin
  LSettings := TPluginSettings.Instance.Global.Editor;
  LJson := TJSONObject.Create;
  try
    TI18n.Instance.SetLanguage(TPluginSettings.Instance.Global.General.Language);
    LJson.AddPair('placeholderPrefix',TPluginSettings.Instance.Global.Stub.PlaceholderPrefix);
    LJson.AddPair('placeholderMarkers',TPluginSettings.Instance.Global.Stub.PlaceholderMarkers);
    LJson.AddPair('language',TI18n.Instance.CurrentLanguage);
    LJson.AddPair('saveDebounceMs',TJSONNumber.Create(LSettings.SaveDebounceMs));
    if FHostTheme<>'' then LJson.AddPair('theme',FHostTheme) else LJson.AddPair('theme',LSettings.Theme);
    LJson.AddPair('fontSize', TJSONNumber.Create(LSettings.FontSize));
    LJson.AddPair('collapseEmptySections', TJSONBool.Create(LSettings.CollapseEmptySections));
    LJson.AddPair('showSignatureHeader', TJSONBool.Create(LSettings.ShowSignatureHeader));
    var Payload:=LJson.ToJSON;if Payload=FAppliedSettings then Exit;
    LocalizePluginUi(Owner);FAppliedSettings:=Payload;
    ExecuteScript('window.xmlDocSettings?.apply(' + Payload + ');');
  finally
    LJson.Free;
  end;
end;

procedure TXmlDocBrowser.DestroyWnd;
begin
 FResourceRoot:='';FResourceBase:='';FAppliedSettings:='';inherited;
end;

procedure TXmlDocBrowser.LoadTimer(Sender:TObject);
begin
 FLoadTimer.Enabled:=False;
 // Resource loaders are created at navigation time. Mapping after a page has
 // loaded requires a new navigation (WebView2 host mapping contract).
 FLoadTimer.Enabled:=False;FAppliedSettings:='';NavigateToString(FHtml);
end;

{$IF CompilerVersion < 36.0}
initialization
finalization
 if WebViewLoaderHandle<>0 then FreeLibrary(WebViewLoaderHandle);
{$ENDIF}
end.
