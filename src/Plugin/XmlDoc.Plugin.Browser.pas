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
    procedure LoadTimer(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadEditorResource(AInstance: THandle; const AName: string);
  end;

procedure ConfigureWebViewLoader;

implementation

uses
  System.IOUtils, Winapi.Windows, Winapi.EdgeUtils;

procedure ConfigureWebViewLoader;
var
  LPath: string;
begin
  LPath := TPath.Combine(ExtractFilePath(GetModuleName(HInstance)), 'WebView2Loader.dll');
  if TFile.Exists(LPath) then
    SetWebView2Path(LPath);
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

procedure TXmlDocBrowser.LoadTimer(Sender: TObject);
begin
  FLoadTimer.Enabled := False;
  NavigateToString(FHtml);
end;

end.
