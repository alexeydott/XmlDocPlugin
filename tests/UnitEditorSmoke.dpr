program UnitEditorSmoke;
{$APPTYPE CONSOLE}
{$R '..\src\Plugin\XmlDocEditor.res'}
uses System.SysUtils, System.IOUtils, System.JSON, Winapi.Windows, Winapi.ActiveX,
  Vcl.Forms, Vcl.Controls, Vcl.Edge, WebView2, XmlDoc.Plugin.Browser,
  XmlDoc.Parser, XmlDoc.Model, XmlDoc.Consts;
type
  TProbe = class(TForm)
  public
    Browser: TXmlDocBrowser;
    Done, Passed: Boolean;
    JumpCount: Integer;
    ElementJSON, DocJSON, UnitName, Summary: string;
    procedure Created(Sender:TCustomEdgeBrowser; Status:HRESULT);
    procedure Navigated(Sender:TCustomEdgeBrowser; Success:Boolean; Status:COREWEBVIEW2_WEB_ERROR_STATUS);
    procedure MessageReceived(Sender:TCustomEdgeBrowser; Args:TWebMessageReceivedEventArgs);
  end;
procedure TProbe.Created(Sender:TCustomEdgeBrowser; Status:HRESULT);
begin
  if Status<>S_OK then raise Exception.Create('WebView2 creation failed');
  Browser.LoadEditorResource(HInstance,'XMLDOC_EXPLORER_HTML');
end;
procedure TProbe.Navigated(Sender:TCustomEdgeBrowser; Success:Boolean; Status:COREWEBVIEW2_WEB_ERROR_STATUS);
var QuotedSummary: TJSONString;
begin
  if not Success then raise Exception.Create('Explorer navigation failed');
  QuotedSummary := TJSONString.Create(Summary);
  try
  Browser.ExecuteScript('setTimeout(()=>{try{' +
    'window.bridge.receive({type:"loadTree",data:{fileName:"Module.pas",elements:[Object.assign('+ElementJSON+',{doc:'+DocJSON+'})]}});'+
    'const row=document.querySelector(".tree-row");if(!row)throw Error("Missing unit root");row.click();'+
    'const exceptions=document.querySelector("#exceptions-section");'+
    'if(!exceptions.classList.contains("hidden"))throw Error("Unit exceptions should be hidden");'+
    'window.bridge.receive({type:"loadDoc",data:{element:{kind:"method",name:"Run",lineNumber:42,params:[{name:"Value",type:"Integer"}]},doc:{summary:"Method"}}});'+
    'if(exceptions.classList.contains("hidden"))throw Error("Method exceptions should be visible");'+
    'document.querySelector("#params-body .td-desc").dispatchEvent(new MouseEvent("dblclick",{bubbles:true}));'+
    'document.querySelector("#params-body .td-name").dispatchEvent(new MouseEvent("dblclick",{bubbles:true}));'+
    'window.bridge.receive({type:"loadDoc",data:{element:{kind:"method",name:"Unknown",params:[{name:"Other",type:"Integer"}]},doc:{summary:"Unknown"}}});'+
    'document.querySelector("#params-body .td-name").dispatchEvent(new MouseEvent("dblclick",{bubbles:true}));row.click();'+
    'if(!exceptions.classList.contains("hidden"))throw Error("Unit exceptions reappeared");'+
    'const editor=document.querySelector("#summary-editor .tiptap");'+
    'if(!editor || !editor.textContent.includes('+QuotedSummary.ToJSON+'))throw Error("Unit summary not loaded");'+
    'if(document.querySelectorAll(".tree-row").length!==1)throw Error("Duplicate unit root");'+
    'editor.focus();const range=document.createRange();range.selectNodeContents(editor);'+
    'const selection=getSelection();selection.removeAllRanges();selection.addRange(range);'+
    'document.execCommand("insertText",false,"Edited unit documentation smoke");'+
    '}catch(e){window.chrome.webview.postMessage("FAIL:"+e.message)}},200);');
  finally QuotedSummary.Free; end;
end;
procedure TProbe.MessageReceived(Sender:TCustomEdgeBrowser; Args:TWebMessageReceivedEventArgs);
var Text:PWideChar;S:string;J:TJSONObject;
begin
  Text:=nil;if Args.ArgsInterface.TryGetWebMessageAsString(Text)<>S_OK then Exit;
  try S:=string(Text);finally CoTaskMemFree(Text);end;
  if S.StartsWith('FAIL:') then begin Writeln(S);Done:=True;Exit;end;
  J:=TJSONObject.ParseJSONValue(S) as TJSONObject;
  try
    if (J<>nil) and (J.GetValue<string>('type','')='jumpToLine') then begin
      if J.GetValue<Integer>('line',0)<>42 then begin Done:=True;Exit;end;
      Inc(JumpCount);
    end;
    if (J<>nil) and (J.GetValue<string>('type','')='docUpdated') then begin
      Passed:=(JumpCount=1) and (J.GetValue<string>('elementFullName','')=UnitName) and
        J.GetValue<TJSONObject>('doc').GetValue<string>('summary','').Contains('Edited unit documentation smoke');
      Done:=True;
    end;
  finally J.Free;end;
end;
var Probe:TProbe;Parser:TDocParser;Model:TXmlDocModel;E:TCodeElementInfo;Started:UInt64;Path:string;
begin
  Application.Initialize;Probe:=TProbe.CreateNew(nil);Parser:=TDocParser.Create;Model:=TXmlDocModel.Create;
  try
    Path:=GetEnvironmentVariable('XMLDOC_UNIT_SOURCE');
    if Path<>'' then Parser.ParseSource(TFile.ReadAllText(Path))
    else Parser.ParseSource('/// <summary>Unit editor smoke overview</summary>'#13#10+'unit Demo.Module; interface implementation end.');
    E:=Parser.GetElementAtLine(1);
    if E.Kind<>dekUnit then raise Exception.Create('Header must select the unit');
    Model.LoadFromXml(E.ExistingDocXml);Probe.UnitName:=E.Name;Probe.Summary:=Model.Summary;
    Probe.ElementJSON:='{"kind":"unit","name":"'+E.Name+'","fullName":"'+E.FullName+'","params":[]}';
    Probe.DocJSON:=Model.ToJSON;
    Probe.SetBounds(100,100,900,700);Probe.Browser:=TXmlDocBrowser.Create(Probe);
    Probe.Browser.Parent:=Probe;Probe.Browser.Align:=alClient;
    Probe.Browser.UserDataFolder:=GetEnvironmentVariable('LOCALAPPDATA')+'\XmlDocPlugin\UnitEditorSmoke';
    Probe.Browser.OnCreateWebViewCompleted:=Probe.Created;Probe.Browser.OnNavigationCompleted:=Probe.Navigated;
    Probe.Browser.OnWebMessageReceived:=Probe.MessageReceived;Probe.Show;Probe.Browser.CreateWebView;
    Started:=GetTickCount64;
    while not Probe.Done and (GetTickCount64-Started<15000) do begin Application.ProcessMessages;Sleep(10);end;
    if not Probe.Passed then begin Writeln('FAIL unit editor round trip');ExitCode:=1;end
    else Writeln('PASS unit root selection, summary loading and editing: '+E.Name);
  finally Model.Free;Parser.Free;Probe.Free;end;
end.
