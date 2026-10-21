unit WorkbenchProbe;
interface
procedure Register;
implementation
uses XmlDoc.Plugin.OptionsPage,XmlDoc.Plugin.HelpInsight,XmlDoc.Plugin.Splash,XmlDoc.ParamDict,XmlDoc.AI.Transport,System.Win.ComObj,XmlDoc.SourceText,XmlDoc.Plugin.AIAssistant,XmlDoc.Plugin.AISettings,XmlDoc.AI.Contracts,XmlDoc.AI.Prompts,XmlDoc.AI.OpenAI,XmlDoc.Documentation,XmlDoc.Logger,XmlDoc.HelpGen.ThemeEngine,System.SyncObjs,System.RegularExpressions,XmlDoc.Plugin.ProjectDocumentation,XmlDoc.ProjectContext,System.Diagnostics,System.Hash,XmlDoc.Plugin.DeclarationContext,XmlDoc.I18n,System.SysUtils,System.StrUtils,System.Classes,System.IOUtils,System.JSON,Winapi.Windows,Winapi.Messages,Winapi.ActiveX,
 Vcl.Imaging.pngimage,Vcl.ComCtrls,Vcl.Samples.Spin,Vcl.Forms,Vcl.ActnList,Vcl.Menus,Vcl.Controls,Vcl.ExtCtrls,Vcl.Edge,WebView2,ToolsAPI,XmlDoc.Plugin.DocInspector,
 XmlDoc.Plugin.Localization,XmlDoc.Plugin.SettingsDialog,XmlDoc.Plugin.CoverageDialog,XmlDoc.Plugin.Browser,XmlDoc.Plugin.DocExplorer,XmlDoc.Plugin.EditSession,XmlDoc.Parser,XmlDoc.Consts,Vcl.StdCtrls,XmlDoc.Plugin.BatchGenDialog,Vcl.Graphics,XmlDoc.ShortcutValidation,XmlDoc.Plugin.Settings,XmlDoc.Plugin.AboutDialog,XmlDoc.Plugin.Utils;
type TAIScreenshot=class(TInterfacedObject,ICoreWebView2CapturePreviewCompletedHandler)
 public Stream:IStream;Name:string;Browser:TXmlDocBrowser;
 function Invoke(errorCode:HResult):HResult;stdcall;
 end;
 TRealAITransport=class(TInterfacedObject,IAITransport)
 private Delegate:IAITransport;Phase,Directory:string;
 public constructor Create(const APhase,ADirectory:string);
 function Execute(const Request:TAIHttpRequest):TAIHttpResponse;
 procedure Cancel;
 end;
 TAIProbeTransport=class(TInterfacedObject,IAITransport)
 private FCancelled:Integer;
 public function Execute(const Request:TAIHttpRequest):TAIHttpResponse;procedure Cancel;
 end;
 TRetry503Transport=class(TInterfacedObject,IAITransport)
 public Entered:TEvent;Calls:Integer;
 constructor Create;destructor Destroy;override;
 function Execute(const Request:TAIHttpRequest):TAIHttpResponse;
 procedure Cancel;
 end;
 TPublicationProbe=class(TProjectDocumentation)
 public
  IncludeFile,NewModule:string;Armed,Changed:Boolean;
 protected
  procedure BeforePublication;override;
 end;
 TProbe=class(TComponent)
 public
 Timer,FormatConfirmation:TTimer;Inspector:TDocInspectorForm;Explorer:TDocExplorerForm;Browser,ExplorerBrowser:TXmlDocBrowser;OriginalMessage,OriginalExplorerMessage:TWebMessageReceivedEvent;ExplorerAttempted:Boolean;
 ValidationProbe:TPublicationProbe;
 StressEntered,StressContinue:TEvent;StressChecks:Integer;
 StressRound:Integer;StressGeneration,StressStarted:UInt64;
 AIBefore,AIWritten:string;RealLine:Integer;RealSource,RealDiskHash,RealPhase,RealDirectory:string;
 RecoveryFile,RecoveryOriginal:string;
 LanguageSaved:Boolean;OriginalLanguage:string;
 PrefixSettingsSaved:Boolean;OriginalPrefixSettings:TGlobalSettings;LastGenerationMessage:string;
 ProtectedBefore,SystemFile,PrimaryProjectFile,FormatBefore:string;
 SharedFile,SharedProjectA,SharedProjectB,SharedMainXml,SharedSettings:string;
 FormatWait,Step:Integer;Initial,AfterWrite,SecondInitial,SampleFile,SecondFile,Root:string;Finished:Boolean;
 procedure CheckAISettings(Sender:TObject);procedure CheckAILocalization(Sender:TObject);
 procedure ConfirmFormat(Sender:TObject);procedure Tick(Sender:TObject); procedure ExportAll; procedure CloseExportMessage(Sender:TObject);
 procedure ExplorerMessage(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
 procedure MessageReceived(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
 procedure Select(const FileName,Name,TypeName:string);
 procedure AssertTrue(Value:Boolean;const Message:string);
 procedure Finish;
 procedure OpenDocumentationPanels;
 procedure Notification(AComponent:TComponent;Operation:TOperation);override;
end;
var Probe:TProbe;
constructor TRetry503Transport.Create;
begin inherited;Entered:=TEvent.Create(nil,True,False,'');end;
destructor TRetry503Transport.Destroy;
begin Entered.Free;inherited;end;
function TRetry503Transport.Execute(const Request:TAIHttpRequest):TAIHttpResponse;
begin TInterlocked.Increment(Calls);Result.Status:=503;Result.Body:='Unavailable';Entered.SetEvent;end;
procedure TRetry503Transport.Cancel;
begin end;
procedure ReplaceSourceBuffer(const Editor:IOTASourceEditor;const Source:string);
var Reader:IOTAEditReader;Writer:IOTAEditWriter;Buffer:array[0..32767] of AnsiChar;Count,Total:Integer;Bytes:UTF8String;Position:TOTAEditPos;
begin
 Reader:=Editor.CreateReader;Total:=0;repeat Count:=Reader.GetText(Total,@Buffer[0],SizeOf(Buffer));Inc(Total,Count);until Count<SizeOf(Buffer);Reader:=nil;
 Bytes:=UTF8Encode(Source);Writer:=Editor.CreateUndoableWriter;Writer.CopyTo(0);Writer.DeleteTo(Total);Writer.Insert(PAnsiChar(Bytes));Writer:=nil;
 Position.Line:=4;Position.Col:=1;Editor.EditViews[0].SetCursorPos(Position);
end;
procedure TPublicationProbe.BeforePublication;
begin
 inherited;
 if not Armed then Exit;Armed:=False;
 if NewModule<>'' then begin var Project:=GetActiveProject;if not Assigned(Project) then raise Exception.Create('No project at publication boundary');Project.AddFile(NewModule,True);Changed:=True;Exit;end;
 var Editor:=SourceEditorForFile(IncludeFile);if not Assigned(Editor) then raise Exception.Create('Open include unavailable at publication boundary');
 var Existing:=UTF8Encode(EditorSource(Editor));var Writer:=Editor.CreateUndoableWriter;
 Writer.CopyTo(0);Writer.DeleteTo(Length(Existing));var Replacement:=UTF8String('type TChanged=class end;');Writer.Insert(PAnsiChar(Replacement));Writer:=nil;Changed:=True;
end;

procedure Log(const Text:string);
begin TFile.AppendAllText(GetEnvironmentVariable('XMLDOC_E2E_LOG'),Text+sLineBreak,TEncoding.UTF8);end;
function XmlEscape(const Value:string):string;
begin Result:=Value.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;');end;
function FindMenuCommand(Parent:TMenuItem;const Caption:string):TMenuItem;
begin
 if SameText(StringReplace(Parent.Caption,'&','',[rfReplaceAll]),TI18n.Instance.T(Caption)) then Exit(Parent);
 for var I:=0 to Parent.Count-1 do begin Result:=FindMenuCommand(Parent[I],Caption);if Assigned(Result) then Exit;end;
 Result:=nil;
end;
function TAIScreenshot.Invoke(errorCode:HResult):HResult;
begin
 Stream:=nil;Result:=S_OK;
 if errorCode<0 then Log('FAIL AI screenshot '+Name) else Browser.ExecuteScript('window.__aiScreenshot='+('"'+Name+'"')+';');
end;
constructor TRealAITransport.Create(const APhase,ADirectory:string);
begin inherited Create;Phase:=APhase;Directory:=ADirectory;Delegate:=TAIHTTPTransport.Create;end;
procedure TRealAITransport.Cancel;
begin Delegate.Cancel;end;
function TRealAITransport.Execute(const Request:TAIHttpRequest):TAIHttpResponse;
var Watch:TStopwatch;
begin
 TFile.WriteAllText(TPath.Combine(Directory,Phase+'.request.json'),Request.Body,TEncoding.UTF8);Watch:=TStopwatch.StartNew;
 try
  if Phase='html' then begin
   Result.Status:=200;var Envelope:=TJSONObject.ParseJSONValue(TFile.ReadAllText(TPath.Combine(Directory,'html-baseline.response.json'),TEncoding.UTF8)) as TJSONObject;
   try var Message:=TJSONObject(TJSONObject(Envelope.GetValue<TJSONArray>('choices').Items[0]).GetValue('message'));
    var Content:=TJSONObject.ParseJSONValue(Message.GetValue<string>('content')) as TJSONObject;
    try Content.RemovePair('summary').Free;Content.AddPair('summary','<html><body><p class="provider">First <strong>formatted</strong> paragraph.</p><p>Second paragraph.</p><script>window.__aiInjectedScript=true</script><style>.provider{color:red}</style></body></html>');
     if Assigned(Content.GetValue('parameters')) and (Content.GetValue<TJSONArray>('parameters').Count>0) then begin var Item:=TJSONObject(Content.GetValue<TJSONArray>('parameters').Items[0]);Item.RemovePair('description').Free;Item.AddPair('description','<div class="provider">Parameter <b>description</b></div>');end;
     Message.RemovePair('content').Free;Message.AddPair('content',Content.ToJSON);Result.Body:=Envelope.ToJSON;
    finally Content.Free;end;
   finally Envelope.Free;end;
  end else Result:=Delegate.Execute(Request);
  TFile.WriteAllText(TPath.Combine(Directory,Phase+'.response.json'),Result.Body,TEncoding.UTF8);
  var Meta:=TJSONObject.Create.AddPair('status',TJSONNumber.Create(Result.Status)).AddPair('elapsedMs',TJSONNumber.Create(Watch.ElapsedMilliseconds)).AddPair('url',Request.URL);try TFile.WriteAllText(TPath.Combine(Directory,Phase+'.result.json'),Meta.ToJSON,TEncoding.UTF8);finally Meta.Free;end;
 except on E:Exception do begin TFile.WriteAllText(TPath.Combine(Directory,Phase+'.error.txt'),E.ClassName+': '+E.Message,TEncoding.UTF8);raise;end;end;
end;
function TAIProbeTransport.Execute(const Request:TAIHttpRequest):TAIHttpResponse;
begin
 if not Request.Body.Contains('TDocumented.Run') and not Request.Body.Contains('TDocumented.NoBody') and not Request.Body.Contains('TDocumented.Calculate') and not Request.Body.Contains('TSecond.Run') and not Request.Body.Contains('Connection check') then raise Exception.Create('AI request missed the selected method');
 if Request.Body.Contains('XML rephrase fixture') and
   (not Request.Body.Contains('Editable prose') or not Request.Body.Contains('bold wording')) then
   raise Exception.Create('Formatting markup hid editable prose from the AI request');
 var Steps:=30;if GetEnvironmentVariable('XMLDOC_E2E_SCREENSHOTS')<>'' then Steps:=160;
 for var I:=0 to Steps do begin if TInterlocked.CompareExchange(FCancelled,0,0)<>0 then raise Exception.Create('AI request cancelled');Sleep(10);end;
 var Summary:='Returns immediately when the supplied value is empty.';var Seen:=TStringList.Create;var Root:=TJSONObject.Create;
 try
  var SummaryPrefix:='';for var Match in TRegEx.Matches(Request.Body,'__XMLDOC_[0-9a-fA-F]+_[0-9]+__') do begin
   var Prefix:=Copy(Match.Value,1,LastDelimiter('_',Copy(Match.Value,1,Length(Match.Value)-2)));
   if SummaryPrefix='' then SummaryPrefix:=Prefix;
   if (Prefix=SummaryPrefix) and (Seen.IndexOf(Match.Value)<0) then begin Seen.Add(Match.Value);Summary:=Summary+' '+Match.Value;end;end;
  if Request.Body.Contains('HTML cleanup fixture') then begin
   Summary:='<p class="provider">First <b>formatted</b> paragraph.</p><p>Second paragraph.</p><script>providerHtmlFixture()</script><style>.provider{color:red}</style>';
   for var Token in Seen do Summary:=Summary+Token;
  end;
  var Content:=TJSONObject.Create.AddPair('summary',Summary).AddPair('uncertainties',TJSONArray.Create(TJSONString.Create('Ownership is not specified.'))).AddPair('parameters',TJSONArray.Create(TJSONObject.Create.AddPair('name','Value').AddPair('description','Input text to process.')));
  if Request.Body.Contains('TDocumented.Calculate') then begin
   Content.RemovePair('summary').Free;Content.AddPair('summary','Proposed calculation summary.');
   Content.RemovePair('parameters').Free;Content.AddPair('parameters',TJSONArray.Create(TJSONObject.Create.AddPair('name','Value').AddPair('description','Reviewed first operand.'),TJSONObject.Create.AddPair('name','Other').AddPair('description','Proposed second operand.')));
   Content.AddPair('returns','The sum of Value and Other.').AddPair('remarks','Proposed calculation remarks.').AddPair('changes',TJSONArray.Create(TJSONString.Create('The result is computed by Value + Other.')));
  end;
  try var Choices:=TJSONArray.Create;Root.AddPair('choices',Choices);Choices.AddElement(TJSONObject.Create.AddPair('finish_reason','stop').AddPair('message',TJSONObject.Create.AddPair('content',Content.ToJSON)));Result.Status:=200;Result.Body:=Root.ToJSON;finally Content.Free;end;
 finally Root.Free;Seen.Free;end;
end;
procedure TAIProbeTransport.Cancel;
begin TInterlocked.Exchange(FCancelled,1);end;
function AssistantFor(Form:TForm):TAIAssistant;
begin for var I:=0 to Form.ComponentCount-1 do if Form.Components[I] is TAIAssistant then Exit(TAIAssistant(Form.Components[I]));raise Exception.Create('AI component missing');end;
procedure TProbe.CheckAISettings(Sender:TObject);
begin
 try
 for var I:=0 to Screen.FormCount-1 do if Screen.Forms[I].ClassName='TAISettingsForm' then begin
  TTimer(Sender).Enabled:=False;var Form:=Screen.Forms[I];
  AssertTrue(Form.Caption=TI18n.Instance.T('AI profiles and prompts'),'AI settings caption not localized');
  var ShotDir:=GetEnvironmentVariable('XMLDOC_E2E_SCREENSHOTS');
  if ShotDir<>'' then begin
   ForceDirectories(ShotDir);var Name:=TEdit(Form.FindComponent('AIField0'));var Endpoint:=TEdit(Form.FindComponent('AIField1'));var Model:=TEdit(Form.FindComponent('AIField3'));
   var OldName:=Name.Text;var OldEndpoint:=Endpoint.Text;var OldModel:=Model.Text;var AuthCombo:TComboBox:=nil;for var N:=0 to Form.ComponentCount-1 do if (Form.Components[N] is TComboBox) and (TComboBox(Form.Components[N]).Items.IndexOf('Bearer')>=0) then AuthCombo:=TComboBox(Form.Components[N]);var OldAuth:=-1;if Assigned(AuthCombo) then OldAuth:=AuthCombo.ItemIndex;
   try if Assigned(AuthCombo) then AuthCombo.ItemIndex:=0;Name.Text:='OpenAI';Endpoint.Text:='https://api.openai.com/v1';Model.Text:='your-model-id';Form.Repaint;
    var Bitmap:=Form.GetFormImage;var PNG:=TPngImage.Create;try PNG.Assign(Bitmap);PNG.SaveToFile(TPath.Combine(ShotDir,'ai-settings.png'));finally PNG.Free;Bitmap.Free;end;
   finally if Assigned(AuthCombo) then AuthCombo.ItemIndex:=OldAuth;Name.Text:=OldName;Endpoint.Text:=OldEndpoint;Model.Text:=OldModel;end;
  end;
  var Preview:=TCheckBox(Form.FindComponent('AIPreviewRequests'));AssertTrue(Assigned(Preview) and not Preview.Checked,'AI request preview must default to off');Preview.Checked:=True;var PreviewConfig:=LoadAIConfiguration;try AssertTrue(PreviewConfig.GetValue<Boolean>('previewRequests',False),'AI request preview setting not saved');finally PreviewConfig.Free;end;
  var Retries:=TEdit(Form.FindComponent('AIRetryCount'));AssertTrue(Assigned(Retries) and (Retries.Text='3'),'Retry count default incorrect');Retries.Text:='2';
  var Thinking:=TCheckBox(Form.FindComponent('AIDisableThinking'));AssertTrue(Assigned(Thinking) and not Thinking.Checked,'Thinking must default to provider behavior');
  Thinking.Checked:=True;TButton(Form.FindComponent('AIButtonSaveprofile')).Click;var ThinkingConfig:=LoadAIConfiguration;try AssertTrue(AIProfileFromJson(TJSONObject(ThinkingConfig.GetValue<TJSONArray>('profiles')[0])).DisableThinking,'Thinking setting not persisted');AssertTrue(AIProfileFromJson(TJSONObject(ThinkingConfig.GetValue<TJSONArray>('profiles')[0])).RetryCount=2,'Retry count not persisted');finally ThinkingConfig.Free;end;
  Retries.Text:='3';Thinking.Checked:=False;TButton(Form.FindComponent('AIButtonSaveprofile')).Click;
  AssertTrue(TEdit(Form.FindComponent('AIField3')).Text='your-model-id','AI model did not load');AssertTrue(TEdit(Form.FindComponent('AIKey')).Text='','Credential was exposed in native key field');
  for var J:=0 to Form.ComponentCount-1 do if Form.Components[J] is TPageControl then begin var Pages:=TPageControl(Form.Components[J]);
   for var Tab:=0 to Pages.PageCount-1 do begin Pages.ActivePageIndex:=Tab;
    for var K:=0 to Form.ComponentCount-1 do if Form.Components[K] is TWinControl then begin var Control:=TWinControl(Form.Components[K]);if Control.Parent=Pages.Pages[Tab] then AssertTrue(Control.Visible and Control.Enabled and Control.CanFocus,'AI control inaccessible: '+Control.ClassName);end;
   end;
  end;
  AssertTrue(Pos('{{implementation}}',TMemo(Form.FindComponent('AIUserPrompt')).Text)>0,'Prompt source was localized or lost');
  AssertTrue(TMemo(Form.FindComponent('AIUserPrompt')).Lines.Count>5,'Prompt variable lines collapsed in native editor');
  if ShotDir<>'' then begin
   for var J:=0 to Form.ComponentCount-1 do if Form.Components[J] is TPageControl then TPageControl(Form.Components[J]).ActivePageIndex:=1;
   Form.Repaint;var Bitmap:=Form.GetFormImage;var PNG:=TPngImage.Create;try PNG.Assign(Bitmap);PNG.SaveToFile(TPath.Combine(ShotDir,'ai-prompts.png'));finally PNG.Free;Bitmap.Free;end;
  end;
  for var J:=0 to Form.ComponentCount-1 do if Form.Components[J] is TPageControl then TPageControl(Form.Components[J]).ActivePageIndex:=0;
  var Profiles:=TComboBox(Form.FindComponent('AIProfiles'));var NameField:=TEdit(Form.FindComponent('AIField0'));
  var NewButton:=TButton(Form.FindComponent('AIButtonNewprofile'));var SaveButton:=TButton(Form.FindComponent('AIButtonSaveprofile'));var DeleteButton:=TButton(Form.FindComponent('AIButtonDeleteprofile'));
  var OriginalCount:=Profiles.Items.Count;
  NewButton.Click;NewButton.Click;AssertTrue(Profiles.Items.Count=OriginalCount,'New profile created duplicate placeholder rows');
  AssertTrue(NameField.Visible and NameField.CanFocus,'Profile name is inaccessible');NameField.Text:='Native profile name';TEdit(Form.FindComponent('AIField3')).Clear;SaveButton.Click;
  AssertTrue(Profiles.Items.Count=OriginalCount+1,'New named profile was not saved');AssertTrue(Profiles.Text='Native profile name','Saved profile name missing');
  NameField.Text:='Renamed native profile';SaveButton.Click;AssertTrue((Profiles.Items.Count=OriginalCount+1) and (Profiles.Text='Renamed native profile'),'Profile rename created a duplicate');
  DeleteButton.Click;AssertTrue(Profiles.Items.Count=OriginalCount,'Delete profile did not remove the saved row');
  for var PPI in [96,144,192] do begin
   Form.ScaleForPPI(PPI);
   var Padding:=MulDiv(16,PPI,96);var Area:=Form.Monitor.WorkareaRect;
   Log(Format('AI window at %d DPI: %dx%d; minimum %dx%d; profile field width %d; actual DPI %d/%d',[PPI,Form.Width,Form.Height,Form.Constraints.MinWidth,Form.Constraints.MinHeight,NameField.Width,Form.CurrentPPI,NameField.CurrentPPI]));
   AssertTrue(Abs(NameField.Width-MulDiv(540,PPI,96))<=MulDiv(32,PPI,96),'AI field did not scale with its form');
   AssertTrue((Abs(Form.Constraints.MinWidth-Form.Width)<=MulDiv(32,PPI,96)) and (Abs(Form.Constraints.MinHeight-Form.Height)<=MulDiv(32,PPI,96)),'AI window minimum does not match its content');
   AssertTrue((Form.Width<=Area.Width-Padding*2) and (Form.Height<=Area.Height-Padding*2),'AI settings exceed the monitor work area');
   for var ScrollName in ['AIProfilesScroll','AIPromptsScroll'] do begin
    var Scroll:=TScrollBox(Form.FindComponent(ScrollName));AssertTrue(Assigned(Scroll),'AI tab must support scrolling on small screens');
    var RightEdge:=0;var BottomEdge:=0;
    for var N:=0 to Scroll.ControlCount-1 do begin var C:=Scroll.Controls[N];if C.Left+C.Width>RightEdge then RightEdge:=C.Left+C.Width;if C.Top+C.Height>BottomEdge then BottomEdge:=C.Top+C.Height;end;
    AssertTrue((Scroll.HorzScrollBar.Range>=RightEdge) or (Scroll.ClientWidth>=RightEdge),'AI controls extend beyond horizontal scroll range');
    AssertTrue((Scroll.VertScrollBar.Range>=BottomEdge) or (Scroll.ClientHeight>=BottomEdge),'AI controls extend beyond vertical scroll range');
   end;
   var OriginalWidth:=Form.Width;var OriginalFieldWidth:=NameField.Width;var OriginalPromptWidth:=TMemo(Form.FindComponent('AIUserPrompt')).Width;
   var KeyButton:=TButton(Form.FindComponent('AIButtonDeletestoredkey'));var OriginalKeyLeft:=KeyButton.Left;
   Form.Width:=OriginalWidth+80;Form.Realign;
   AssertTrue(NameField.Width=OriginalFieldWidth+80,'Profile field does not follow window width');
   AssertTrue(TMemo(Form.FindComponent('AIUserPrompt')).Width=OriginalPromptWidth+80,'Prompt editor does not follow window width');
   AssertTrue(KeyButton.Left=OriginalKeyLeft+80,'Delete key action lost its right anchor');
   Form.Width:=OriginalWidth;Form.Realign;
   AssertTrue(NewButton.Top>=Profiles.Top+Profiles.Height,'Profile actions overlap selector');
   AssertTrue(NameField.Top>=SaveButton.Top+SaveButton.Height,'Profile name overlaps actions');
   Form.Canvas.Font.Assign(DeleteButton.Font);AssertTrue(Form.Canvas.TextWidth(DeleteButton.Caption)+16<DeleteButton.Width,'Delete profile caption is clipped');
  end;
  Form.ScaleForPPI(Screen.PixelsPerInch);
  var General:=TSettingsDialog.Create(nil);try
   for var PPI in [96,144,192] do begin General.ScaleForPPI(PPI);AssertTrue(General.btnAISettings.Top>=General.chkShowSignatureHeader.Top+General.chkShowSignatureHeader.Height,'AI settings button overlaps general settings');end;
  finally General.Free;end;
  Log('PASS native AI profile create, rename, delete and 100/150/200 percent layout');
  Form.ModalResult:=mrCancel;Log('PASS native AI settings loads profiles, protects keys and exposes both tabs');
 end;
except on E:Exception do begin Log('FAIL '+E.Message);if GetEnvironmentVariable('XMLDOC_E2E_KEEP_FAILURE')<>'1' then ExitProcess(1);end;end;
end;
procedure TProbe.CheckAILocalization(Sender:TObject);
begin
 try
 for var I:=0 to Screen.FormCount-1 do if Screen.Forms[I].ClassName='TAISettingsForm' then begin
  TTimer(Sender).Enabled:=False;var Form:=Screen.Forms[I];var Preview:=TCheckBox(Form.FindComponent('AIPreviewRequests'));
  AssertTrue(Form.Caption=TI18n.Instance.T('AI profiles and prompts'),'AI locale title mismatch');
  AssertTrue((Preview.Caption=TI18n.Instance.T('Preview AI requests before sending')) and (Preview.Hint=Preview.Caption),'AI preview caption/hint mismatch');
  AssertTrue(TEdit(Form.FindComponent('AIRetryCount')).Hint=TI18n.Instance.T('Retries after the first attempt; 0 disables retries. Temporary errors only.'),'Retry hint not localized');
  AssertTrue(TCheckBox(Form.FindComponent('AIDisableThinking')).Caption=TI18n.Instance.T('Disable AI thinking'),'Thinking caption not localized');
  AssertTrue(TCheckBox(Form.FindComponent('AIDisableThinking')).Hint=TI18n.Instance.T('Uses a supported non-reasoning model when available; otherwise adds a prompt instruction. Support depends on the provider.'),'Thinking hint not localized');
  AssertTrue(TEdit(Form.FindComponent('AIKey')).TextHint=TI18n.Instance.T('Blank keeps the stored key'),'AI key hint mismatch');
  AssertTrue(TButton(Form.FindComponent('AIButtonNewprofile')).Caption=TI18n.Instance.T('New profile'),'AI action caption mismatch');
  AssertTrue(TEdit(Form.FindComponent('AIKey')).Text='','AI key exposed while changing locale');
  Form.ModalResult:=mrCancel;Log('PASS native AI captions and hints: '+TI18n.Instance.CurrentLanguage);
 end;
 except on E:Exception do begin Log('FAIL '+E.Message);ExitProcess(1);end;end;
end;
procedure TProbe.AssertTrue(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
procedure TProbe.Select(const FileName,Name,TypeName:string);
var Editor:IOTASourceEditor;Parser:TDocParser;E:TCodeElementInfo;Line:Integer;Pos:TOTAEditPos;
begin
 (BorlandIDEServices as IOTAActionServices).OpenFile(FileName);Editor:=SourceEditorForFile(FileName);
 AssertTrue(Assigned(Editor),'Source editor unavailable');Editor.Show;Parser:=TDocParser.Create;
 try Parser.ParseSource(EditorSource(Editor),FileName);Line:=0;
  for E in Parser.GetAllElements do if (E.Name=Name) and ((TypeName='') or ((Length(E.Params)>0) and SameText(E.Params[0].TypeName,TypeName))) then begin Line:=E.LineNumber;Break;end;
  AssertTrue(Line>0,'Fixture declaration missing: '+Name);Pos.Line:=Line;Pos.Col:=1;Editor.EditViews[0].SetCursorPos(Pos);
  Inspector.HandleCursorChanged(Line,EditorSource(Editor),FileName);
 finally Parser.Free;end;
end;
procedure TProbe.Notification(AComponent:TComponent;Operation:TOperation);
begin
 inherited;
 if Operation<>opRemove then Exit;
 if AComponent=Inspector then begin Inspector:=nil;Browser:=nil;Log('PASS IDE released Inspector');end;
 if AComponent=Explorer then begin Explorer:=nil;ExplorerBrowser:=nil;Log('PASS IDE released Explorer');end;
end;
procedure TProbe.OpenDocumentationPanels;
begin
 if GetEnvironmentVariable('XMLDOC_E2E_SHUTDOWN_OPEN_PANELS')='1' then begin
  var Menu:=(BorlandIDEServices as INTAServices).MainMenu;
  var InspectorCommand:=FindMenuCommand(Menu.Items,'Doc Inspector');
  var ExplorerCommand:=FindMenuCommand(Menu.Items,'Documentation Explorer');
  AssertTrue(Assigned(InspectorCommand) and Assigned(ExplorerCommand),'Documentation panel IDE commands are missing');
  InspectorCommand.Click;ExplorerCommand.Click;
  for var I:=0 to Screen.FormCount-1 do begin
   if Screen.Forms[I] is TDocInspectorForm then Inspector:=TDocInspectorForm(Screen.Forms[I]);
   if Screen.Forms[I] is TDocExplorerForm then Explorer:=TDocExplorerForm(Screen.Forms[I]);
  end;
  AssertTrue(Assigned(Inspector) and Assigned(Explorer),'IDE commands did not create both documentation panels');
  Inspector.FreeNotification(Self);Explorer.FreeNotification(Self);
  Log('PASS documentation panels opened through IDE commands');
 end else begin
  Log('Creating Inspector');Inspector:=TDocInspectorForm.Create(nil);
  Log('Creating Explorer');Explorer:=TDocExplorerForm.Create(nil);
 end;
 Inspector.Show;Explorer.Show;
end;
procedure TProbe.Finish;
var Project:IOTAProject;Module:IOTAModule;Services:IOTAModuleServices;I:Integer;Menu:TMainMenu;ExitItem:TMenuItem;
 function FindExit(Parent:TMenuItem):TMenuItem;
 var Child:TMenuItem;
 begin Result:=nil;for Child in Parent do begin
  if SameText(StringReplace(Child.Caption,'&','',[rfReplaceAll]),'Exit') then Exit(Child);
  Result:=FindExit(Child);if Assigned(Result) then Exit;
 end;end;
begin
 if Finished then Exit;
 Finished:=True;
 if PrefixSettingsSaved then begin TPluginSettings.Instance.Global:=OriginalPrefixSettings;TPluginSettings.Instance.Save;PrefixSettingsSaved:=False;end;
 if LanguageSaved then begin var SavedSettings:=TPluginSettings.Instance.Global;SavedSettings.General.Language:=OriginalLanguage;TPluginSettings.Instance.Global:=SavedSettings;TPluginSettings.Instance.Save;TI18n.Instance.SetLanguage(OriginalLanguage);end;Timer.Enabled:=False;
 if GetEnvironmentVariable('XMLDOC_E2E_SHUTDOWN_OPEN_PANELS')='1' then begin
  AssertTrue(Assigned(Inspector) and Assigned(Explorer),'Open-panel shutdown requires both forms');
  Inspector.Show;Explorer.Show;
  AssertTrue(Inspector.Visible and Explorer.Visible,'Documentation panels are not visible before IDE shutdown');
  AssertTrue(Assigned(Browser) and Assigned(ExplorerBrowser),'Documentation browsers are missing before IDE shutdown');
  AssertTrue(Browser.WebViewCreated and ExplorerBrowser.WebViewCreated,'Documentation browsers are not running before IDE shutdown');
  Log('PASS shutdown with both Inspector and Explorer open');
 end else begin
  Log('Closing Explorer');FreeAndNil(Explorer);Log('Closing Inspector');FreeAndNil(Inspector);Log('Closed Inspector');
 end;
 Services:=BorlandIDEServices as IOTAModuleServices;
 if RealSource<>'' then begin Module:=Services.FindModule(RealSource);if Assigned(Module) then Module.CloseModule(True);Module:=nil;Log('Closed unchanged real source');end;
 Project:=Services.GetActiveProject;if Assigned(Project) then begin
  Log('Closing project '+Project.FileName);Project.CloseModule(True);Log('Closed project');end;
 if Assigned(Services.MainProjectGroup) then begin Log('Closing temporary project group');Services.MainProjectGroup.CloseModule(True);Log('Closed project group');end;
 for var J:=Services.ModuleCount-1 downto 0 do begin var FixtureModule:=Services.Modules[J];if FixtureModule.FileName.StartsWith(Root,True) then FixtureModule.CloseModule(True);end;
 Menu:=(BorlandIDEServices as INTAServices).MainMenu;ExitItem:=FindExit(Menu.Items);AssertTrue(Assigned(ExitItem),'IDE Exit command is unavailable');
 Log('Invoke IDE Exit: '+ExitItem.Name+' target='+UIntToStr(Menu.WindowHandle));ExitItem.Click;Log('IDE Exit invoked');
end;
procedure TProbe.ExplorerMessage(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
var Buffer:PWideChar;Json:TJSONObject;
begin
 Buffer:=nil;Args.ArgsInterface.TryGetWebMessageAsString(Buffer);
 if Assigned(Buffer) then begin try Json:=ParseHostMessage(string(Buffer));finally CoTaskMemFree(Buffer);end;
  try
   if Assigned(StressEntered) and Assigned(Json) and (Json.GetValue<string>('type','')='requestCatalog') then begin Log('Ignored automatic Explorer refresh during native worker barrier');Exit;end;
   if Assigned(Json) and (Json.GetValue<string>('type','')='docUpdated') then ExplorerAttempted:=True;
  finally Json.Free;end;
 end;
 if Assigned(OriginalExplorerMessage) then OriginalExplorerMessage(Sender,Args);
end;
procedure TProbe.MessageReceived(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
var Buffer:PWideChar;Text,Action,Source,NativeTitle,NativeHint,GenerationTitle,CoverageTitle:string;Json:TJSONObject;Editor:IOTASourceEditor;EditBuffer:IOTAEditBuffer;Writer:IOTAEditWriter;Offset,UndoMarkers:Integer;Utf8:UTF8String;
 procedure AssertParsed(Form:TForm);
 begin
  for var I:=0 to Form.ComponentCount-1 do if (Form.Components[I] is TMemo) and (Form.Components[I].Name='DocumentationError') then
   AssertTrue(not (TMemo(Form.Components[I]).Visible and (System.Pos('Cannot parse',TMemo(Form.Components[I]).Text)=1)),'System.pas parse error: '+TMemo(Form.Components[I]).Text);
 end;
begin
 Buffer:=nil;Args.ArgsInterface.TryGetWebMessageAsString(Buffer);if Buffer=nil then Exit;
 try Text:=string(Buffer);finally CoTaskMemFree(Buffer);end;
 Json:=TJSONObject.ParseJSONValue(Text) as TJSONObject;
 try
  // Native stress requests are issued directly through Docs.Handle. Do not let
  // the new card's automatic catalog replace that controlled worker request.
  if Assigned(StressEntered) and Assigned(Json) and (Json.GetValue<string>('type','')='requestCatalog') then begin Log('Ignored automatic Inspector refresh during native worker barrier');Exit;end;
  if Assigned(Json) and (Json.GetValue<string>('type','')='docUpdated') then Log('EDIT '+Json.GetValue<string>('sourceRevision','')+' '+Json.GetValue<TJSONObject>('doc').GetValue<string>('summary',''));
  if not Assigned(Json) or (Json.GetValue<string>('type','')<>'e2e') then begin if Assigned(OriginalMessage) then OriginalMessage(Sender,Args);Exit;end;
  Action:=Json.GetValue<string>('action','');
  try
   if Action='parser-break-source' then begin
    RecoveryFile:=TPath.Combine(Root,'Units\ParserRecovery.pas');
    RecoveryOriginal:='unit ParserRecovery;'+#10+'interface'+#10+'/// <summary>Recovery sample</summary>'+#10+'procedure Healthy;'+#10+'implementation'+#10+'procedure Healthy;'+#10+'var Value:Integer;'+#10+'begin'+#10+'  Value := 1;'+#10+'end;'+#10+'end.';
    TFile.WriteAllText(RecoveryFile,RecoveryOriginal,TEncoding.UTF8);GetActiveProject.AddFile(RecoveryFile,True);
    (BorlandIDEServices as IOTAActionServices).OpenFile(RecoveryFile);Editor:=SourceEditorForFile(RecoveryFile);AssertTrue(Assigned(Editor),'Recovery source did not open');Editor.Show;
    Inspector.HandleCursorChanged(4,RecoveryOriginal,RecoveryFile);Explorer.HandleFileChanged(RecoveryFile,RecoveryOriginal);
    for var Panel in [TForm(Inspector),TForm(Explorer)] do begin var Poll:=TTimer(Panel.FindComponent('SourcePollTimer'));AssertTrue(Assigned(Poll),'Native source polling is unavailable');Poll.Interval:=100;Poll.Enabled:=True;end;
    ReplaceSourceBuffer(Editor,RecoveryOriginal.Replace('Value := 1;','Value := (1;'));
   end
   else if Action='parser-poll-state' then begin
    var HasErrors:=True;var Recovered:=True;
    for var Panel in [TForm(Inspector),TForm(Explorer)] do begin var Memo:=TMemo(Panel.FindComponent('DocumentationError'));HasErrors:=HasErrors and Memo.Visible and string(Memo.Text).Contains(RecoveryFile) and string(Memo.Text).Contains('Line: 9') and string(Memo.Text).Contains('Exception: ESyntaxTreeException');Recovered:=Recovered and not Memo.Visible;end;
    Browser.ExecuteScript('window.__nativeParseErrors='+LowerCase(BoolToStr(HasErrors,True))+';window.__nativeParseRecovered='+LowerCase(BoolToStr(Recovered,True))+';');
   end
   else if Action='parser-error-observed' then begin
    AssertTrue(Browser.Visible and ExplorerBrowser.Visible,'Parser error hid the browser/editor');
    AssertTrue(EditorSource(SourceEditorForFile(RecoveryFile)).Contains('Value := (1;'),'Parse failure wrote to the source');
    for var Panel in [TForm(Inspector),TForm(Explorer)] do for var N:=0 to Panel.ComponentCount-1 do if Panel.Components[N] is TDocumentationErrorActions then begin
     var Actions:=TDocumentationErrorActions(Panel.Components[N]);for var B:=0 to Actions.ControlCount-1 do if Actions.Controls[B] is TButton then begin
      var Button:=TButton(Actions.Controls[B]);
      if Button.Caption=TI18n.Instance.T('Hide details') then begin Button.Click;AssertTrue(not TMemo(Panel.FindComponent('DocumentationError')).Visible,'Error details did not collapse');Button.Click;end;
      if Button.Caption=TI18n.Instance.T('Go to error') then begin Button.Click;AssertTrue(SourceEditorForFile(RecoveryFile).EditViews[0].CursorPos.Line=9,'Error navigation used the wrong source line');end;
      if Button.Caption=TI18n.Instance.T('Retry parsing') then begin Button.Click;AssertTrue(TMemo(Panel.FindComponent('DocumentationError')).Visible,'Retry hid an unresolved parse error');end;
     end;
    end;
    Log('PASS parser failure details, visible browser, collapsed diagnostics and blocked writes');
   end
   else if Action='parser-fix-source' then ReplaceSourceBuffer(SourceEditorForFile(RecoveryFile),RecoveryOriginal.Replace('Recovery sample','Recovered automatically'))
   else if Action='parser-recovery-complete' then begin
    AssertTrue(ReadSourceFile(RecoveryFile)=RecoveryOriginal,'Automatic recovery must read the unsaved OTA buffer');
    AssertTrue(EditorSource(SourceEditorForFile(RecoveryFile)).Contains('Recovered automatically'),'Corrected source was lost');
    Log('PASS automatic unsaved-buffer recovery in Inspector/Explorer and partial project catalog');Log('PASS');Step:=90;Timer.Interval:=100;Timer.Enabled:=True;
   end
   else if Action='marker-log' then Log('AUDIT '+Json.GetValue<string>('result'))
   else if Action='marker-select' then begin Select(SampleFile,'UndocumentedFirst','');Browser.ExecuteScript('window.__markerSelected=true');end
   else if Action='marker-coverage' then begin
    var D:=TCoverageDialog.Create(nil);
    try D.Show;D.btnAnalyze.Click;
     var Reply:=TJSONObject.Create;try Reply.AddPair('complete',D.lblComplete.Caption);Reply.AddPair('documented',D.lblDocumented.Caption);Reply.AddPair('total',D.lblTotal.Caption);
      Browser.ExecuteScript('window.__markerCoverage='+Reply.ToJSON);Log('AUDIT coverage '+Reply.ToJSON);
     finally Reply.Free;end;
    finally D.Free;end;
   end
   else if Action='prefix-ui' then begin
    if not PrefixSettingsSaved then begin OriginalPrefixSettings:=TPluginSettings.Instance.Global;PrefixSettingsSaved:=True;end;
    var Updated:=TPluginSettings.Instance.Global;Updated.Stub.IncludePlaceholders:=True;TPluginSettings.Instance.Global:=Updated;
    var Dialog:=TSettingsDialog.Create(nil);
    try Dialog.edtPlaceholderPrefix.Text:=Json.GetValue<string>('prefix');
     Dialog.memPlaceholderMarkers.Lines.Text:=CDefaultPlaceholderMarkers+#10+'ПРОВЕРИТЬ:';
     Dialog.hotToggleInspector.HotKey:=0;Dialog.hotGenerateStub.HotKey:=0;Dialog.hotGenerateHelp.HotKey:=0;Dialog.hotCoverageReport.HotKey:=0;Dialog.hotNextUndocumented.HotKey:=0;Dialog.hotPreviousUndocumented.HotKey:=0;
     Dialog.btnOKClick(nil);
    finally Dialog.Free;end;
    var Reader:=TPluginSettings.Create;
    try AssertTrue(Reader.Global.Stub.PlaceholderPrefix=Json.GetValue<string>('prefix'),'Settings did not persist the custom stub prefix');
     AssertTrue(Reader.Global.Stub.PlaceholderMarkers.Contains('ПРОВЕРИТЬ:'),'Settings did not persist recognized markers');finally Reader.Free;end;
    Browser.ApplySettings;ExplorerBrowser.ApplySettings;Select(SampleFile,Json.GetValue<string>('member'),'');
    Log('PASS custom placeholder prefix saved through Settings: '+Json.GetValue<string>('prefix'));
   end
   else if Action='prefix-restore' then begin
    TPluginSettings.Instance.Global:=OriginalPrefixSettings;TPluginSettings.Instance.Save;PrefixSettingsSaved:=False;
    Browser.ApplySettings;ExplorerBrowser.ApplySettings;Initial:=EditorSource(SourceEditorForFile(SampleFile));Select(SampleFile,'Run','string');
    Browser.ExecuteScript('window.__prefixRestored=true');Log('PASS custom prefix settings restored after native editor checks');
   end
   else if Action='live-review-arm' then begin
    RealDirectory:=ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_LOG'));RealPhase:='describe';
    var UserConfig:=TJSONObject.ParseJSONValue(TFile.ReadAllText(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),'XmlDocPlugin\ai.json'),TEncoding.UTF8)) as TJSONObject;
    try var Profile:TJSONObject:=nil;for var Item in UserConfig.GetValue<TJSONArray>('profiles') do if SameText(TJSONObject(Item).GetValue<string>('name'),GetEnvironmentVariable('XMLDOC_E2E_LIVE_PROFILE')) then Profile:=TJSONObject(Item);
     AssertTrue(Assigned(Profile),'Configured live profile not found');var Config:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1)).AddPair('previewRequests',TJSONBool.Create(False)).AddPair('profiles',TJSONArray.Create(Profile.Clone as TJSONObject));
     try SaveAIConfiguration(Config);finally Config.Free;end;
    finally UserConfig.Free;end;
    Select(SampleFile,'Calculate','Integer');AIBefore:=EditorSource(SourceEditorForFile(SampleFile));SecondInitial:=EditorSource(SourceEditorForFile(SecondFile));
    TFile.WriteAllText(TPath.Combine(RealDirectory,'live-before.pas'),AIBefore,TEncoding.UTF8);
    AssistantFor(Inspector).TransportFactory:=function:IAITransport begin Result:=TRealAITransport.Create(RealPhase,RealDirectory);end;
    Browser.ExecuteScript('window.xmlDocAI.reload();window.__liveArmed=true;');
   end
   else if Action='live-review-phase' then begin RealPhase:=Json.GetValue<string>('phase');Browser.ExecuteScript('window.__livePhase="'+RealPhase+'";');end
   else if Action='live-review-finish' then begin
    AssertTrue(not AssistantFor(Inspector).Busy,'Live request still running');
    AssertTrue(EditorSource(SourceEditorForFile(SampleFile))=AIBefore,'Live review changed source buffer');
    AssertTrue(EditorSource(SourceEditorForFile(SecondFile))=SecondInitial,'Live queue changed second buffer');
    AssertTrue(TFile.ReadAllText(SampleFile,TEncoding.UTF8)=AIBefore,'Live review changed source disk');
    AssertTrue(TFile.ReadAllText(SecondFile,TEncoding.UTF8)=SecondInitial,'Live queue changed second disk file');
    Log('PASS live requests completed without applying; source buffers and disk unchanged');Log('PASS');Step:=90;Timer.Interval:=100;Timer.Enabled:=True;
   end
   else if Action='real-ai-arm' then begin
    RealSource:=GetEnvironmentVariable('XMLDOC_E2E_LARGE_SOURCE');RealDiskHash:=THashSHA2.GetHashStringFromFile(RealSource);RealDirectory:=ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_LOG'));
    var UserConfig:=TJSONObject.ParseJSONValue(TFile.ReadAllText(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),'XmlDocPlugin\ai.json'),TEncoding.UTF8)) as TJSONObject;
    try var Profiles:=UserConfig.GetValue<TJSONArray>('profiles');var Profile:TJSONObject:=nil;for var Item in Profiles do if SameText(TJSONObject(Item).GetValue<string>('name'),'neuraldeep') then Profile:=TJSONObject(Item);
     AssertTrue(Assigned(Profile),'neuraldeep profile not found');var Config:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1)).AddPair('previewRequests',TJSONBool.Create(True)).AddPair('profiles',TJSONArray.Create(Profile.Clone as TJSONObject));
     try var TestTimeout:=StrToIntDef(GetEnvironmentVariable('XMLDOC_E2E_AI_TIMEOUT'),0);if TestTimeout>0 then begin var TestProfile:=Config.GetValue<TJSONArray>('profiles')[0] as TJSONObject;TestProfile.RemovePair('timeoutMs').Free;TestProfile.AddPair('timeoutMs',TJSONNumber.Create(TestTimeout));end;SaveAIConfiguration(Config);finally Config.Free;end;
    finally UserConfig.Free;end;
    var Project:=GetActiveProject;AssertTrue(Assigned(Project) and Project.FileName.StartsWith(Root,True),'Real AI context must use the isolated test project');
    var Context:=TProjectContext.Create(GetEnvironmentVariable('XMLDOC_E2E_LARGE_PROJECT'),'Debug','Win32');
    try var ProjectXml:='<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"><PropertyGroup><MainSource>SourceLatency.dpr</MainSource><DCC_Define>'+XmlEscape(string.Join(';',Context.Defines))+'</DCC_Define><DCC_IncludePath>'+XmlEscape(ExtractFilePath(Context.ProjectFile)+';'+string.Join(';',Context.IncludePaths))+'</DCC_IncludePath><DCC_UnitSearchPath>'+XmlEscape(string.Join(';',Context.SearchPaths))+'</DCC_UnitSearchPath></PropertyGroup><ItemGroup>';
     for var Name in Context.SourceFiles+[RealSource] do if not SameText(ExtractFileExt(Name),'.dpr') then ProjectXml:=ProjectXml+'<DCCReference Include="'+XmlEscape(Name)+'"/>';
     TFile.WriteAllText(Project.FileName,ProjectXml+'</ItemGroup></Project>',TEncoding.UTF8);TFile.WriteAllText(TPath.Combine(ExtractFilePath(Project.FileName),'SourceLatency.dpr'),'program SourceLatency;begin end.',TEncoding.UTF8);
    finally Context.Free;end;
    AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(RealSource),'Cannot open real source');Editor:=SourceEditorForFile(RealSource);AIBefore:=EditorSource(Editor);TParamDictionary.Instance.LoadFromFile(TPath.Combine(Root,'real-ai-parameters.json'));
    var P:=TDocParser.Create;try ConfigureDeclarationContext(P,nil,RealSource);P.ParseSource(AIBefore,RealSource);var Line:=0;for var Item in P.GetAllElements do if SameText(Item.Name,'RefreshMapDC') and SameText(Item.QualifiedParent,'TGisMappl') and (Item.SourceSection='interface') then begin Line:=Item.LineNumber;Break;end;AssertTrue(Line>0,'RefreshMapDC declaration not found');RealLine:=Line;var Position:TOTAEditPos;Position.Line:=Line;Position.Col:=5;Editor.EditViews[0].SetCursorPos(Position);Editor.Show;Inspector.HandleCursorChanged(Line,AIBefore,RealSource);finally P.Free;end;
    RealPhase:='preview';AssistantFor(Inspector).TransportFactory:=function:IAITransport begin Result:=TRealAITransport.Create(RealPhase,RealDirectory);end;
    Browser.ExecuteScript('window.xmlDocAI.reload();window.__realMode="'+GetEnvironmentVariable('XMLDOC_E2E_REAL_MODE')+'";window.__realArmed=true;');Log('PASS real neuraldeep profile and original RefreshMapDC opened');
   end
   else if Action='real-ai-phase' then begin
    RealPhase:=Json.GetValue<string>('phase');AssertTrue(MatchText(RealPhase,['preview','direct','cancel','html']),'Invalid real AI phase');var Config:=LoadAIConfiguration;
    try Config.RemovePair('previewRequests').Free;Config.AddPair('previewRequests',TJSONBool.Create(RealPhase='preview'));SaveAIConfiguration(Config);finally Config.Free;end;
    Browser.ExecuteScript('window.xmlDocAI.reload();window.__realPhase="'+RealPhase+'";');
   end
   else if Action='real-ai-poll' then Browser.ExecuteScript('window.__realNativeBusy='+LowerCase(BoolToStr(AssistantFor(Inspector).Busy,True))+';window.__realDispatched='+LowerCase(BoolToStr(TFile.Exists(TPath.Combine(RealDirectory,RealPhase+'.request.json')),True))+';')
   else if Action='real-ai-applied' then begin
    Editor:=SourceEditorForFile(RealSource);var Modified:=EditorSource(Editor);AssertTrue(Modified<>AIBefore,'AI proposal did not reach source writer');
    TFile.WriteAllText(TPath.Combine(RealDirectory,RealPhase+'.applied.pas'),Modified,TEncoding.UTF8);
    AssertTrue(Supports(Editor,IOTAEditBuffer,EditBuffer),'No Undo buffer');for var I:=0 to 20 do begin if EditorSource(Editor)=AIBefore then Break;EditBuffer.Undo;end;
    AssertTrue(EditorSource(Editor)=AIBefore,'Undo did not restore original source');AssertTrue(THashSHA2.GetHashStringFromFile(RealSource)=RealDiskHash,'Real source changed on disk');var Position:TOTAEditPos;Position.Line:=RealLine;Position.Col:=5;Editor.EditViews[0].SetCursorPos(Position);TParamDictionary.Instance.LoadFromFile(TPath.Combine(Root,'real-ai-parameters.json'));Inspector.HandleCursorChanged(RealLine,AIBefore,RealSource);
    Browser.ExecuteScript('window.__realUndone=true;');Log('PASS '+RealPhase+' applied through OTA and fully undone');
   end
   else if Action='real-ai-observation' then TFile.WriteAllText(TPath.Combine(RealDirectory,Json.GetValue<string>('phase')+'.observation.json'),Json.ToJSON,TEncoding.UTF8)
   else if Action='real-ai-finish' then begin
    AssertTrue(not AssistantFor(Inspector).Busy,'Real request still running');AssertTrue(EditorSource(SourceEditorForFile(RealSource))=AIBefore,'Real buffer changed');AssertTrue(THashSHA2.GetHashStringFromFile(RealSource)=RealDiskHash,'Real source saved');
    Log('PASS real file byte-for-byte unchanged');Log('PASS');Step:=90;Timer.Interval:=100;Timer.Enabled:=True;
   end
   else if Action='ai-test-arm' then begin
    var RetryTransport:=TRetry503Transport.Create;var RetryInterface:IAITransport:=RetryTransport;
    var RetryRequest:=Default(TAIHttpRequest);RetryRequest.RetryCount:=3;RetryRequest.MaxResponseBytes:=1024;
    var RetryWorker:=TAIWorker.Create(RetryRequest,RetryInterface);
    try
     RetryWorker.Start;AssertTrue(RetryTransport.Entered.WaitFor(5000)=wrSignaled,'Retry worker never dispatched');
     var CancelStarted:=GetTickCount64;RetryWorker.Cancel;RetryWorker.WaitFor;
     AssertTrue(GetTickCount64-CancelStarted<500,'Retry delay cancellation blocked IDE');
     AssertTrue(RetryWorker.Error='AI request cancelled','Retry cancellation error lost');
     AssertTrue(RetryTransport.Calls=1,'Cancelled retry dispatched another request');
     Log('PASS active retry worker cancellation ms: '+UIntToStr(GetTickCount64-CancelStarted));
    finally RetryWorker.Cancel;RetryWorker.WaitFor;RetryWorker.Free;RetryInterface:=nil;end;

    var Config:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1));var Profiles:=TJSONArray.Create;Config.AddPair('profiles',Profiles);
    var Profile:=TAIProfile.Defaults;Profile.Id:=TGUID.NewGuid.ToString;Profile.Name:='OpenAI';Profile.Model:='your-model-id';Profile.Authorization:='none';Profile.Endpoint:='https://api.openai.com/v1';Profiles.AddElement(AIProfileJson(Profile));try SaveAIConfiguration(Config);finally Config.Free;end;
    Profile.Id:=TGUID.NewGuid.ToString;var KeyProfile:=Profile;
    try WriteAIKey(Profile,'E2E-not-a-real-secret');AssertTrue(ReadAIKey(Profile)='E2E-not-a-real-secret','Credential round trip failed');Profile.Endpoint:='https://other.invalid/v1';AssertTrue(ReadAIKey(Profile)='','Changed destination reused a credential');Profile.Endpoint:='https://fixture.invalid/v1';finally WriteAIKey(KeyProfile,'');end;
    AssertTrue(not TFile.ReadAllText(AIConfigurationPath).Contains('E2E-not-a-real-secret'),'Credential leaked to JSON');
    var Templates:=AIPrompts('');
    try
     var Custom:=Templates[0].Clone as TJSONObject;Custom.RemovePair('id').Free;Custom.AddPair('id','custom-describe');Custom.RemovePair('name').Free;Custom.AddPair('name','Detailed description');Templates.AddElement(Custom);SaveAIPrompts(Templates,'');SaveAIPrompts(Templates,Root);
     var Reloaded:=AIPrompts(Root);try AssertTrue(Reloaded.Count=4,'Project/global AI templates did not merge');finally Reloaded.Free;end;
     var Previous:=TFile.ReadAllText(AIConfigurationPath);Custom.RemovePair('user').Free;Custom.AddPair('user','{{unknown_variable}}');var Rejected:=False;
     try SaveAIPrompts(Templates,'');except on E:Exception do Rejected:=True;end;AssertTrue(Rejected and (TFile.ReadAllText(AIConfigurationPath)=Previous),'Invalid prompt changed saved configuration');
    finally Templates.Free;end;
    var CaptureLanguage:=TI18n.Instance.CurrentLanguage;if GetEnvironmentVariable('XMLDOC_E2E_SCREENSHOTS')<>'' then TI18n.Instance.SetLanguage('en');
    var SettingsTimer:=TTimer.Create(nil);try SettingsTimer.Interval:=100;SettingsTimer.OnTimer:=CheckAISettings;ShowAISettings(Root);finally SettingsTimer.Free;TI18n.Instance.SetLanguage(CaptureLanguage);end;
    if GetEnvironmentVariable('XMLDOC_E2E_SCREENSHOTS')<>'' then Inspector.SetBounds(100,100,1120,1000);
    Inspector.BringToFront;Browser.SetFocus;
    AssistantFor(Inspector).TransportFactory:=function:IAITransport begin Result:=TAIProbeTransport.Create;end;
    AssistantFor(Explorer).TransportFactory:=function:IAITransport begin Result:=TAIProbeTransport.Create;end;
    AIBefore:=EditorSource(SourceEditorForFile(SampleFile));Browser.ExecuteScript('window.xmlDocAI.reload();window.__aiTestArmed=true;');Log('PASS AI profile and credential recipient binding');
   end
   else if Action='ai-screenshot' then begin
    var Directory:=GetEnvironmentVariable('XMLDOC_E2E_SCREENSHOTS');if Directory<>'' then begin
     var Name:=Json.GetValue<string>('name');if not MatchText(Name,['ai-preview','ai-waiting','ai-proposal','inspector','explorer','synchronization','project-workspace','wording','replacement']) then raise Exception.Create('Invalid screenshot name');
     var Capture:=TAIScreenshot.Create;Capture.Name:=Name;Capture.Browser:=Browser;
     Capture.Stream:=TStreamAdapter.Create(TFileStream.Create(TPath.Combine(Directory,Name+'.png'),fmCreate),soOwned);
     var CaptureBrowser:=Browser;if Name='explorer' then CaptureBrowser:=ExplorerBrowser;
     OleCheck(CaptureBrowser.DefaultInterface.CapturePreview(COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG,Capture.Stream,Capture));
    end else Browser.ExecuteScript('window.__aiScreenshot='+('"'+Json.GetValue<string>('name')+'"')+';');
   end
   else if Action='ai-preview-off' then begin
    var Config:=LoadAIConfiguration;try Config.RemovePair('previewRequests').Free;Config.AddPair('previewRequests',TJSONBool.Create(False));SaveAIConfiguration(Config);finally Config.Free;end;
    Browser.ExecuteScript('window.xmlDocAI.reload();window.__previewOff=true;');
   end
   else if Action='ai-write-checked' then begin
    AIWritten:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(AIWritten.Contains('Returns without further processing when the value is empty.'),'AI apply did not use OTA');AssertTrue(AIWritten.Contains('custom-root keep="yes"'),'AI apply lost unknown XML');Log('PASS manually edited AI proposal applies through OTA and retains other XML');
    Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer);UndoMarkers:=0;repeat EditBuffer.Undo;Inc(UndoMarkers);until (EditorSource(EditBuffer)<>AIWritten) or (UndoMarkers=4);AssertTrue(EditorSource(EditBuffer)=AIBefore,'AI Undo did not restore original');UndoMarkers:=0;repeat EditBuffer.Redo;Inc(UndoMarkers);until (EditorSource(EditBuffer)<>AIBefore) or (UndoMarkers=4);AssertTrue(EditorSource(EditBuffer)=AIWritten,'AI Redo failed');Inspector.RefreshFromCurrentEditor;Browser.ExecuteScript('window.__aiUndoRedo=true;');Log('PASS AI OTA Undo/Redo');
   end
   else if Action='ai-rephrase-checked' then begin AssertTrue(EditorSource(SourceEditorForFile(SampleFile)).Contains('Stops processing immediately for an empty value.'),'Rephrase did not reach OTA');Log('PASS native rephrase with independent template and reviewed apply');end
   else if Action='ai-clear-param' then begin
    Editor:=SourceEditorForFile(SampleFile);Source:=EditorSource(Editor);AssertTrue(Source.Contains('The text to process.'),'Existing parameter text absent');
    ReplaceSourceBuffer(Editor,Source.Replace('The text to process.',''));Select(SampleFile,'Run','string');Inspector.RefreshFromCurrentEditor;Browser.ExecuteScript('window.__aiParamCleared=true;');
   end
   else if Action='ai-param-checked' then begin
    AssertTrue(EditorSource(SourceEditorForFile(SampleFile)).Contains('Reviewed input parameter'),'AI parameter did not reach OTA source');Log('PASS reviewed AI parameter description applies through OTA');
   end
   else if Action='ai-html-checked' then begin
    var HtmlSource:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(HtmlSource.Contains('<para>First formatted paragraph.</para>') and HtmlSource.Contains('<para>Second paragraph.</para>'),'AI paragraphs were not formatted in source');
    AssertTrue(not HtmlSource.Contains('providerHtmlFixture') and not HtmlSource.Contains('class="provider"') and not HtmlSource.Contains('&lt;p'),'Provider HTML leaked into source');
    Browser.ExecuteScript('window.__aiHTMLChecked=true;');Log('PASS HTML-free AI paragraphs applied through OTA');
   end
   else if Action='ai-body-change' then begin
    Editor:=SourceEditorForFile(SampleFile);Source:=EditorSource(Editor);AssertTrue(Source.Contains('if Value='),'AI body token absent');Source:=Source.Replace('begin if Value=','begin {changed during AI request} if Value=');
    var Reader:=Editor.CreateReader;var B:TBytes;SetLength(B,32768);var Total:=0;var N:Integer;repeat N:=Reader.GetText(Total,PAnsiChar(B),Length(B));Inc(Total,N);until N<Length(B);Reader:=nil;
    Writer:=Editor.CreateUndoableWriter;Writer.CopyTo(0);Writer.DeleteTo(Total);Utf8:=UTF8String(Source);Writer.Insert(PAnsiChar(Utf8));Writer:=nil;Browser.ExecuteScript('window.__aiBodyChanged=true;');
   end
   else if Action='review-select' then begin
    Select(SampleFile,Json.GetValue<string>('name'),Json.GetValue<string>('param',''));
   end
   else if Action='review-source-check' then begin
    var ReviewSource:=EditorSource(SourceEditorForFile(SampleFile));
    AssertTrue(ReviewSource.Contains(Json.GetValue<string>('text')),'Reviewed content did not reach OTA source');
    Log('PASS reviewed source: '+Json.GetValue<string>('label'));
    Browser.ExecuteScript('window.__reviewSourceChecked=true;');
   end
   else if Action='review-quick' then begin
    var ReviewEditor:=SourceEditorForFile(SampleFile);ReviewEditor.Show;
    var ReviewSource:=EditorSource(ReviewEditor);var ReviewLines:=ReviewSource.Split([#10]);var ReviewPos:TOTAEditPos;ReviewPos.Line:=0;
    for var I:=0 to High(ReviewLines) do if ReviewLines[I].Contains(Json.GetValue<string>('marker')) then begin
     ReviewPos.Line:=I+1;ReviewPos.Col:=System.Pos('Run(',ReviewLines[I])+1;Break;
    end;
    AssertTrue(ReviewPos.Line>0,'Quick documentation review call missing');ReviewEditor.EditViews[0].SetCursorPos(ReviewPos);
    Inspector.HandleCursorChanged(ReviewPos.Line,ReviewSource,SampleFile);Browser.ExecuteScript('window.__reviewQuickReady=true;');
   end
   else if Action='review-calculate-checked' then begin
    var CalcSource:=EditorSource(SourceEditorForFile(SampleFile));
    AssertTrue(CalcSource.Contains('Adds two numbers.') and CalcSource.Contains('Reviewed first operand.') and CalcSource.Contains('Keep second parameter description.') and CalcSource.Contains('The sum of Value and Other.') and CalcSource.Contains('Keep local calculation remarks.'),'Independent AI selections did not reach OTA intact');
    AssertTrue(not CalcSource.Contains('Proposed calculation summary.') and not CalcSource.Contains('Proposed second operand.') and not CalcSource.Contains('Proposed calculation remarks.'),'An unselected AI field was written');
    Browser.ExecuteScript('window.__reviewCalculateChecked=true');Log('PASS independent AI summary, parameter, returns and remarks selection through OTA');
   end
   else if Action='review-custom-templates' then begin
    var Templates:=AIPrompts(Root);
    try
     var BuiltIn:=TAIPrompt.BuiltIn(aoReview);
     for var Scope in ['missing','system','user'] do begin
      var SystemText:=BuiltIn.SystemText+' Custom Review '+Scope;
      var UserText:='{{ signature }}'+#10+'{{ implementation }}'+#10+'{{ parameters }}';
      if Scope='system' then SystemText:=SystemText+#10+'{{ documentation }}';
      if Scope='user' then UserText:=UserText+#10+'{{  documentation  }}';
      Templates.AddElement(TJSONObject.Create.AddPair('id','custom-review-'+Scope).AddPair('name','Custom Review '+Scope).AddPair('operation','review').AddPair('system',SystemText).AddPair('user',UserText));
     end;
     SaveAIPrompts(Templates,Root);
    finally Templates.Free;end;
    Browser.ExecuteScript('window.xmlDocAI.reload();window.__customReviewReady=true;');
   end
   else if Action='review-queue-start' then begin
    var P:=TDocParser.Create;try P.ParseSource(EditorSource(SourceEditorForFile(SecondFile)),SecondFile);
     for var E in P.GetAllElements do if (E.Name='Run') and (E.SourceSection='interface') then begin
      var Data:=TJSONObject.Create.AddPair('kind','method').AddPair('name',E.Name).AddPair('fileName',SecondFile).AddPair('symbolId',E.SymbolId).AddPair('lineNumber',TJSONNumber.Create(E.LineNumber));
      try Browser.ExecuteScript('window.xmlDocAI.startQueue([window.xmlDocEditor.get().element,'+Data.ToJSON+']);');finally Data.Free;end;Break;
     end;
    finally P.Free;end;
   end
   else if Action='review-queue-checked' then begin
    AssertTrue(EditorSource(SourceEditorForFile(SampleFile)).Contains('Proposed calculation summary.'),'Queue accepted proposal did not reach OTA before navigation');
    AssertTrue(EditorSource(SourceEditorForFile(SecondFile))=SecondInitial,'The queue applied an unreviewed proposal to another method');
    Browser.ExecuteScript('window.__reviewQueueChecked=true');Log('PASS AI queue navigates methods, supports cancellation and never auto-applies');
   end
   else if Action='queue-conflict-source' then begin
    AIBefore:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(AIBefore.Contains('begin Result:=Value+Other;end;'),'Queue conflict body absent');
    ReplaceSourceBuffer(SourceEditorForFile(SampleFile),AIBefore.Replace('begin Result:=Value+Other;end;','begin {queue conflict} Result:=Value+Other;end;'));
    Browser.ExecuteScript('window.__queueConflictReady=true;');
   end
   else if Action='queue-conflict-checked' then begin
    var ConflictSource:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(ConflictSource.Contains('{queue conflict}'),'External source edit lost');
    AssertTrue(not ConflictSource.Contains('Must not be written after a source conflict.'),'Rejected queue proposal reached OTA');
    ReplaceSourceBuffer(SourceEditorForFile(SampleFile),AIBefore);Inspector.RefreshFromCurrentEditor;
    Browser.ExecuteScript('window.__queueConflictChecked=true;');Log('PASS AI queue source conflict rejects the write and retains the current method');
   end
   else if Action='shared-progress' then Log('Shared context: '+Json.GetValue<string>('message',''))
   else if Action='shared-context-arm' then begin Step:=113;Timer.Interval:=100;Timer.Enabled:=True;end
   else if Action='shared-context-finish' then begin
    AssertTrue(SameText(GetActiveProject.FileName,SharedProjectA),'Shared navigation changed the active project');
    TFile.WriteAllText(SharedProjectA,SharedMainXml,TEncoding.UTF8);TFile.WriteAllText(TPath.Combine(Root,'.xmldocplugin.json'),SharedSettings,TEncoding.UTF8);
    Browser.ExecuteScript('window.__sharedContextChecked=true;');Log('PASS shared unit navigation and AI Capture preserve selected project defines and terminology');
   end
   else if Action='ai-close-pending' then begin
    Select(SampleFile,'Run','string');Explorer.HandleFileChanged(SampleFile,EditorSource(SourceEditorForFile(SampleFile)));
    ExplorerBrowser.ExecuteScript('(()=>{const row=Array.from(document.querySelectorAll(".tree-row")).find(r=>r.dataset.symbolId?.includes("tdocumented.run(const string)"));if(row)row.click();window.xmlDocAI.reload();})();');
    Step:=110;Timer.Interval:=150;Timer.Enabled:=True;
   end
   else if Action='language-ui' then begin
    var Language:=Json.GetValue<string>('language');AssertTrue((Language='ru') or (Language='zh') or (Language='en') or (Language='ko') or (Language='ja'),'Unexpected language');
    var Updated:=TPluginSettings.Instance.Global;if not LanguageSaved then begin OriginalLanguage:=Updated.General.Language;LanguageSaved:=True;end;
    Updated.General.Language:=Language;TPluginSettings.Instance.Global:=Updated;
    var Dialog:=TSettingsDialog.Create(nil);
    try
     AssertTrue(Dialog.cmbLanguage.Items.IndexOf('ko')>=0,'Korean option missing');AssertTrue(Dialog.cmbLanguage.Items.IndexOf('ja')>=0,'Japanese option missing');AssertTrue(Dialog.cmbLanguage.Items.IndexOf('ru')>=0,'Russian option missing');AssertTrue(Dialog.cmbLanguage.Items.IndexOf('zh')>=0,'Chinese option missing');AssertTrue(Dialog.cmbLanguage.Text=Language,'Selected language changed');
     AssertTrue(Dialog.memPlaceholderMarkers.Hint=TI18n.Instance.T('One marker per line. The generated prefix and TODO are always recognized.'),'Marker hint not translated');
     AssertTrue(Dialog.Caption=TI18n.Instance.T('XmlDoc Plugin Settings'),'Settings title not translated');if Language<>'en' then AssertTrue(Dialog.Caption<>'XmlDoc Plugin Settings','Native language pack missing');
     NativeTitle:=Dialog.Caption;NativeHint:=Dialog.memPlaceholderMarkers.Hint;
     Log('AUDIT native language='+Language+' caption='+Dialog.Caption+' markerHint='+Dialog.memPlaceholderMarkers.Hint);
    finally Dialog.Free;end;
    var AILocaleTimer:=TTimer.Create(nil);try AILocaleTimer.Interval:=100;AILocaleTimer.OnTimer:=CheckAILocalization;ShowAISettings(Root);finally AILocaleTimer.Free;end;
    var Generation:=TBatchGenDialog.Create(nil);try GenerationTitle:=Generation.Caption;if Language<>'en' then AssertTrue(GenerationTitle<>'Generate API Documentation','Generation language pack missing');AssertTrue(Generation.Caption=TI18n.Instance.T('Generate API Documentation'),'Generation dialog not translated');finally Generation.Free;end;
    var Coverage:=TCoverageDialog.Create(nil);try CoverageTitle:=Coverage.Caption;if Language<>'en' then AssertTrue(CoverageTitle<>'Documentation Coverage Report','Coverage language pack missing');AssertTrue(Coverage.Caption=TI18n.Instance.T('Documentation Coverage Report'),'Coverage dialog not translated');finally Coverage.Free;end;
    var MenuRoot:=(BorlandIDEServices as INTAServices).MainMenu.Items;for var I:=0 to MenuRoot.Count-1 do if MenuRoot[I].Name='XmlDocDocumentMenu' then LocalizePluginUi(MenuRoot[I].Owner);
    AssertTrue(Assigned(FindMenuCommand(MenuRoot,'User Guide')),'Localized guide menu missing');Browser.ApplySettings;ExplorerBrowser.ApplySettings;
    var LocaleAudit:=TJSONObject.Create;try LocaleAudit.AddPair('language',Language);LocaleAudit.AddPair('settingsTitle',NativeTitle);LocaleAudit.AddPair('markerHint',NativeHint);LocaleAudit.AddPair('generationTitle',GenerationTitle);LocaleAudit.AddPair('coverageTitle',CoverageTitle);Browser.ExecuteScript('window.__nativeLocaleAudit='+LocaleAudit.ToJSON);finally LocaleAudit.Free;end;
    if GetEnvironmentVariable('XMLDOC_E2E_SCREENSHOTS')<>'' then Inspector.SetBounds(100,100,1120,1000);
    Inspector.BringToFront;Browser.SetFocus;
    Browser.ExecuteScript('window.__xmlDocLanguageUi="'+Language+'"');Log('PASS native Settings, generation, coverage and menus language '+Language);
   end
   else if Action='arm-explorer' then begin
     Explorer.HandleFileChanged(SampleFile,EditorSource(SourceEditorForFile(SampleFile)));
     ExplorerBrowser.ExecuteScript('(()=>{const row=Array.from(document.querySelectorAll(".tree-row")).find(r=>r.dataset.symbolId?.includes("tdocumented.run(const string)"));if(row)row.click();window.e2eOldDocument=JSON.parse(JSON.stringify(window.xmlDocEditor.get()));})()');
   end
   else if Action='stale-explorer' then ExplorerBrowser.ExecuteScript('(()=>{const d=window.e2eOldDocument;window.bridge.sendToHost({type:"docUpdated",...d.element,doc:{...d.doc,summary:"EXPLORER STALE SHOULD NOT WRITE"}})})()')
   else if Action='assert-second-view-conflict' then begin AssertTrue(ExplorerAttempted,'Explorer did not attempt the stale edit');AssertTrue(not EditorSource(SourceEditorForFile(SampleFile)).Contains('EXPLORER STALE SHOULD NOT WRITE'),'Conflicting Explorer edit was applied');Log('PASS simultaneous Inspector and Explorer reject stale revisions');end
   else if Action='assert-grid' then begin
     Source:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(Source.Contains('E2E grid first') and Source.Contains('E2E grid second'),'Selected member summaries were not applied');Log('PASS reviewed multi-member summary update');
   end
   else if Action='assert-grid-repeat' then begin
     Source:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(Source.Contains('E2E grid first again') and Source.Contains('E2E grid second'),'Repeated batch did not use its acknowledged baseline');Log('PASS repeat member summaries after acknowledged batch');
   end
   else if Action='switch-second' then Select(SecondFile,'Run','Integer')
   else if Action='switch-sample' then Select(SampleFile,'Run','string')
   else if Action='switch-broken' then Select(SampleFile,'BrokenDocumentation','')
   else if Action='switch-rename' then Select(SampleFile,'RenameScenario','string')
   else if Action='assert-cancelled' then begin
    AssertTrue(EditorSource(SourceEditorForFile(SampleFile))=Initial,'Cancelled A draft changed A');
    AssertTrue(EditorSource(SourceEditorForFile(SecondFile))=SecondInitial,'A draft was written to B');Log('PASS delayed save A to B and file switch');end
   else if Action='assert-write' then begin
    Source:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(Source.Contains('E2E applied summary'),'Browser edit not applied');
    AssertTrue(Source.Contains('custom-root keep="yes"'),'Unknown top-level XML lost');AssertTrue(Source.Contains('Base description'),'See Also label lost');AssertTrue(Source.Contains('Unicode &amp; escaping'),'Example title lost');
    AfterWrite:=Source;TFile.WriteAllText(TPath.Combine(Root,'after-write.txt'),Source);Log('PASS guarded browser-to-OTA edit and preserved metadata');end
   else if Action='undo' then begin
    AssertTrue(Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer),'Undo buffer unavailable');Log('GroupUndo='+BoolToStr(EditBuffer.BufferOptions.GroupUndo,True));UndoMarkers:=0;
    repeat EditBuffer.Undo;Inc(UndoMarkers);until (EditorSource(EditBuffer)<>AfterWrite) or (UndoMarkers=4);
    AssertTrue(EditorSource(EditBuffer)=Initial,'Undo changed text outside the comment or did not restore it');Log('PASS Undo preserves surrounding Pascal');end
   else if Action='redo' then begin
    Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer);UndoMarkers:=0;
    repeat EditBuffer.Redo;Inc(UndoMarkers);until (EditorSource(EditBuffer)<>Initial) or (UndoMarkers=4);
    TFile.WriteAllText(TPath.Combine(Root,'redo-actual.txt'),EditorSource(EditBuffer));AssertTrue(EditorSource(EditBuffer)=AfterWrite,'Redo did not restore comment');Log('PASS Redo');end
   else if Action='mutate-signature' then begin
    Editor:=SourceEditorForFile(SampleFile);Source:=EditorSource(Editor);Offset:=Pos('Value:string',Source)-1;AssertTrue(Offset>=0,'Signature token missing');
    Writer:=Editor.CreateUndoableWriter;Writer.CopyTo(Offset);Writer.DeleteTo(Offset+Length('Value:string'));Utf8:='Value:UnicodeString';Writer.Insert(PAnsiChar(Utf8));Writer:=nil;end
   else if Action='assert-conflict' then begin AssertTrue(not EditorSource(SourceEditorForFile(SampleFile)).Contains('SHOULD NOT WRITE'),'Stale update was written');Log('PASS stale buffer revision rejected');end
   else if Action='repair-signature' then begin Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer);EditBuffer.Undo;Select(SampleFile,'Run','string');end
   else if Action='assert-sync' then begin Source:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(Source.Contains('<param name="NewName">Description to map explicitly.</param>'),'Mapped description lost');AssertTrue(Source.Contains('<param name="Options">'),'New parameter not added');AssertTrue(Source.Contains('<paramref name="NewName"'),'Inline reference not renamed');Log('PASS synchronization preview and explicit rename');end
   else if Action='assert-resources' then Log('PASS project image resource and narrow controls')
   else if Action='assert-project' then Log('PASS project catalog, search and diagnostics')
   else if Action='context' then begin
    var Project:=GetActiveProject;AssertTrue(Assigned(Project),'Context project unavailable');
    var Configs:IOTAProjectOptionsConfigurations;AssertTrue(Supports(Project.ProjectOptions,IOTAProjectOptionsConfigurations,Configs),'Build configurations unavailable');
    Project.CurrentPlatform:=Json.GetValue<string>('platform','Win32');
    var ConfigName:=Json.GetValue<string>('config','Debug');var Chosen:IOTABuildConfiguration:=nil;
    for var I:=0 to Configs.ConfigurationCount-1 do if SameText(Configs.Configurations[I].Name,ConfigName) then begin Chosen:=Configs.Configurations[I];Break;end;
    if not Assigned(Chosen) then Chosen:=Configs.AddConfiguration(ConfigName,Configs.BaseConfiguration);
    Configs.ActiveConfiguration:=Chosen;Select(SecondFile,'ContextProbe','');Inspector.RefreshFromCurrentEditor;
    Log('PASS switched IDE context '+ConfigName+' '+Project.CurrentPlatform+' with unchanged source');
    var Reply:=TJSONString.Create(Json.GetValue<string>('requestId',''));try Browser.ExecuteScript('window.__xmlDocContextReady='+Reply.ToJSON+';');finally Reply.Free;end;
   end
   else if Action='prepare-group' then begin
    PrimaryProjectFile:=GetActiveProject.FileName;var Dir:=TPath.Combine(Root,'GroupB');TDirectory.CreateDirectory(Dir);
    TFile.WriteAllText(TPath.Combine(Dir,'ContextB.pas'),'unit ContextB;'+sLineBreak+'interface'+sLineBreak+'{$I Features.inc}'+sLineBreak+'type TWorker=class procedure Run(Value:Integer); overload; procedure Run(Value:string); overload; end;'+sLineBreak+'procedure OtherB(Value:{$IFDEF FROM_B}string{$ELSE}Integer{$ENDIF});'+sLineBreak+'procedure FromB(Value:{$IFDEF FROM_B}string{$ELSE}Integer{$ENDIF});'+sLineBreak+'implementation'+sLineBreak+'procedure OtherB(Value:{$IFDEF FROM_B}string{$ELSE}Integer{$ENDIF}); begin end;'+sLineBreak+'procedure FromB(Value:{$IFDEF FROM_B}string{$ELSE}Integer{$ENDIF});'+sLineBreak+'begin end;'+sLineBreak+'procedure TWorker.Run(Value:Integer); begin end;'+sLineBreak+'procedure TWorker.Run(Value:string); begin end;'+sLineBreak+'procedure Exercise(Worker:TWorker);'+sLineBreak+'var Local:Integer;'+sLineBreak+'begin'+sLineBreak+' Worker.Run(Local);'+sLineBreak+'end;'+sLineBreak+'end.');
    TFile.WriteAllText(TPath.Combine(Dir,'Features.inc'),'{$DEFINE FROM_B}');
    TFile.WriteAllText(TPath.Combine(Dir,'GroupB.dpr'),'program GroupB; uses ContextB in ''ContextB.pas'', SearchOnly in ''SearchOnly.pas''; begin end.');
    var GroupXml:=TFile.ReadAllText(TPath.Combine(Root,'XmlDocE2E.dproj')).Replace('XmlDocE2E','GroupB');
    GroupXml:=GroupXml.Replace('{3A72602E-67CF-469D-A733-BC75247CC365}',TGUID.NewGuid.ToString);
    GroupXml:=GroupXml.Replace('<DCCReference Include="Units\Workbench.Contracts.pas"/>','<DCCReference Include="ContextB.pas"/>');
    GroupXml:=GroupXml.Replace('<DCCReference Include="Units\Workbench.Sample.pas"/>','').Replace('<DCCReference Include="Units\Workbench.Second.pas"/>','').Replace('<DCCReference Include="Units\Workbench.Markup.pas"/>','').Replace('<DCCReference Include="Examples\Workbench.Examples.pas"/>','');
    GroupXml:=GroupXml.Replace('<DCC_Define>DEBUG;','<DCC_Define>FROM_B;DEBUG;');
    // A bare DCCReference is deliberately outside the project directory. OTA
    // reports the unresolved project-directory alias; analysis must normalize it.
    var References:=TPath.Combine(Dir,'ReferenceSources');ForceDirectories(References);
    TFile.WriteAllText(TPath.Combine(References,'SearchOnly.pas'),'unit SearchOnly; interface type TSearchOnly=class end; implementation end.');
    GroupXml:=GroupXml.Replace('</Project>','<PropertyGroup><DCC_UnitSearchPath>ReferenceSources;$(DCC_UnitSearchPath)</DCC_UnitSearchPath></PropertyGroup><ItemGroup><DCCReference Include="SearchOnly.pas"/></ItemGroup></Project>');
    TFile.WriteAllText(TPath.Combine(Dir,'GroupB.dproj'),GroupXml);
    Step:=80;Timer.Interval:=100;Timer.Enabled:=True;
   end
   else if Action='assert-group' then begin
    AssertTrue(SameText(GetActiveProject.FileName,TPath.Combine(Root,'XmlDocE2E.dproj')),'Group navigation changed active project A');
    AssertTrue(Assigned(SourceEditorForFile(TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas'))),'Group source did not open');
    Log('PASS group symbol navigation uses project B defines while A is active');
   end
   else if Action='group-navigation-checked' then Log('PASS GroupB Source and Back/Forward retain owning project while A is active')
   else if Action='group-include-checked' then Log('PASS catalog Refresh detects a changed closed include')
   else if Action='group-context-error' then begin
    var BrokenProject:=TPath.Combine(TPath.Combine(Root,'GroupB'),'GroupB.dproj');var ProjectBefore:=TFile.ReadAllText(BrokenProject);var ProjectStamp:=TFile.GetLastWriteTimeUtc(BrokenProject);var ErrorFile:=TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas');var ErrorSource:=EditorSource(SourceEditorForFile(ErrorFile));
    try
     TFile.WriteAllText(BrokenProject,ProjectBefore.Replace('ContextB.pas','MissingReviewSource.pas'));
     Inspector.HandleCursorChanged(3,ErrorSource,ErrorFile);Explorer.HandleFileChanged(ErrorFile,ErrorSource);
     for var Panel in TArray<TForm>.Create(Inspector,Explorer) do begin
      var ErrorShown:=False;for var N:=0 to Panel.ComponentCount-1 do if (Panel.Components[N] is TMemo) and (Panel.Components[N].Name='DocumentationError') then begin var LabelControl:=TMemo(Panel.Components[N]);if LabelControl.Visible and (Pos('Missing project source',string(LabelControl.Text))>0) then ErrorShown:=True;end;
      AssertTrue(ErrorShown,'Project-context error was not shown inside '+Panel.Caption);
     end;
    finally TFile.WriteAllText(BrokenProject,ProjectBefore);TFile.SetLastWriteTimeUtc(BrokenProject,ProjectStamp);end;
    var ReferenceDirectory:=TPath.Combine(TPath.Combine(Root,'GroupB'),'ReferenceSources');ForceDirectories(ReferenceDirectory);TFile.WriteAllText(TPath.Combine(ReferenceDirectory,'SearchOnly.pas'),'unit SearchOnly; interface type TSearchOnly=class end; implementation end.');
    try
     var SearchProject:=ProjectBefore.Replace('Include="ContextB.pas"','Include="SearchOnly.pas"').Replace('</Project>','<PropertyGroup><DCC_UnitSearchPath>ReferenceSources;$(DCC_UnitSearchPath)</DCC_UnitSearchPath></PropertyGroup></Project>');
     TFile.WriteAllText(BrokenProject,SearchProject);Inspector.HandleCursorChanged(3,ErrorSource,ErrorFile);Explorer.HandleFileChanged(ErrorFile,ErrorSource);AssertParsed(Inspector);AssertParsed(Explorer);
     Log('PASS Inspector/Explorer resolve bare project source using DCC_UnitSearchPath');
    finally TFile.WriteAllText(BrokenProject,ProjectBefore);TFile.SetLastWriteTimeUtc(BrokenProject,ProjectStamp);end;
    Inspector.RefreshFromCurrentEditor;Explorer.HandleFileChanged(ErrorFile,ErrorSource);Log('PASS Inspector/Explorer contain and recover from project-context errors');
   end
   else if Action='analysis-metrics' then Log('PERF analysis '+Json.ToJSON)
   else if Action='large-editor-check' then begin Step:=95;Timer.Interval:=100;Timer.Enabled:=True;end
   else if Action='open-user-guide' then begin
    var HelpItem:=FindMenuCommand((BorlandIDEServices as INTAServices).MainMenu.Items,'User Guide');AssertTrue(Assigned(HelpItem),'User Guide menu missing');HelpItem.Click;Log('PASS offline User Guide opened from IDE menu');
   end
   else if Action='review-external-comment' then begin
    var ReviewFile:=TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas');Editor:=SourceEditorForFile(ReviewFile);Source:=EditorSource(Editor);
    var Marker:='XML requires explicit approval';var CharOffset:=Pos(Marker,Source);AssertTrue(CharOffset>0,'Original review comment absent');
    Offset:=Length(UTF8Encode(Copy(Source,1,CharOffset-1)));Writer:=Editor.CreateUndoableWriter;Writer.CopyTo(Offset);Writer.DeleteTo(Offset+Length(Marker));Utf8:='EXTERNAL SOURCE CHANGE';Writer.Insert(PAnsiChar(Utf8));Writer:=nil;
    Inspector.HandleCursorChanged(Json.GetValue<Integer>('line'),EditorSource(Editor),ReviewFile);Browser.ExecuteScript('window.__reviewExternalReady=true');Log('PASS external source mutation for native recovery conflict');
   end
   else if Action='assert-review-undo' then begin
    var Actual:=EditorSource(SourceEditorForFile(TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas')));
    AssertTrue(not Actual.Contains('REVIEW HIDDEN RAW') and not Actual.Contains('REVIEW UNDO TEMPORARY TEXT'),'Undo wrote hidden/unconfirmed text');Log('PASS native source after raw draft / Design edit / Undo to baseline');
   end
   else if Action='assert-review-design' then begin
    var Actual:=EditorSource(SourceEditorForFile(TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas')));
    AssertTrue(Actual.Contains('REVIEW VISIBLE DESIGN WINS'),'Visible Design text did not reach native XML serialization');
    AssertTrue(not Actual.Contains('REVIEW HIDDEN RAW MUST NOT WRITE'),'Hidden XML draft overwrote Design text');
    Log('PASS restored raw draft to Design serializes visible content into source');
   end
   else if Action='group-xml-applied-checked' then begin
    var ApprovedSource:=EditorSource(SourceEditorForFile(TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas')));
    AssertTrue(ApprovedSource.Contains('XML requires explicit approval'),'Explicit XML apply did not update source');Log('PASS explicit XML Apply writes the approved draft');
   end
   else if Action='group-xml-draft-checked' then begin
    var XmlDraftSource:=EditorSource(SourceEditorForFile(TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas')));
    AssertTrue(XmlDraftSource.Contains('Implementation design before XML'),'Design save did not complete');AssertTrue(not XmlDraftSource.Contains('XML requires explicit approval'),'Unapproved XML draft was written');Log('PASS XML draft stays unapplied after Design ACK');
   end
   else if Action='group-implementation-checked' then begin
    var GroupFile:=TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas');var CheckParser:=TDocParser.Create;
    try CheckParser.ParseSource(EditorSource(SourceEditorForFile(GroupFile)),GroupFile);var Seen:=0;
     for var E in CheckParser.GetAllElements do if E.Name='FromB' then begin
      if E.SourceSection='implementation' then AssertTrue(E.ExistingDocXml.Contains('Implementation second'),'Pinned second edit missed implementation')
      else AssertTrue(E.ExistingDocXml.Contains('GroupB saved before format'),'Pinned implementation edit changed interface declaration');Inc(Seen);
     end;AssertTrue(Seen=2,'Declaration/implementation pair missing');
    finally CheckParser.Free;end;
    Log('PASS pinned implementation ACK retains both source locations after line shifts');
   end
   else if Action='group-include' then begin
    var IncludePath:=TPath.Combine(TPath.Combine(Root,'GroupB'),'Features.inc');
    if Json.GetValue<Boolean>('enabled',True) then TFile.WriteAllText(IncludePath,'{$DEFINE FROM_B}') else TFile.WriteAllText(IncludePath,'{$UNDEF FROM_B}');
   end
   else if Action='group-quick-context' then begin
    var QuickFile:=TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas');var QuickEditor:=SourceEditorForFile(QuickFile);QuickEditor.Show;var QuickSource:=EditorSource(QuickEditor);var Lines:=QuickSource.Split([#10]);
    var QuickPos:TOTAEditPos;QuickPos.Line:=0;for var I:=0 to High(Lines) do if Lines[I].Contains('Worker.Run(Local)') then begin QuickPos.Line:=I+1;QuickPos.Col:=System.Pos('Run(Local)',Lines[I])+1;Break;end;
    AssertTrue(QuickPos.Line>0,'Quick documentation call fixture absent');QuickEditor.EditViews[0].SetCursorPos(QuickPos);QuickEditor.EditViews[0].MoveViewToCursor;Inspector.HandleCursorChanged(QuickPos.Line,QuickSource,QuickFile);Browser.ExecuteScript('window.__quickContextReady=true');
   end
   else if Action='group-stub' then begin
    var StubItem:=FindMenuCommand((BorlandIDEServices as INTAServices).MainMenu.Items,'Generate Doc Stub');AssertTrue(Assigned(StubItem),'Stub menu absent');StubItem.Click;
    var StubSource:=EditorSource(SourceEditorForFile(TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas')));
    AssertTrue(StubSource.Contains('<param name="Value">'),'Stub did not document project B parameter');Log('PASS GroupB Generate Stub with owning project');
   end
   else if Action='assert-group-format' then begin
    var GroupFile:=TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas');
    var GroupSource:=EditorSource(SourceEditorForFile(GroupFile));
    AssertTrue(GroupSource.Contains('GroupB '+Json.GetValue<string>('mode')+' before format'),'Formatted GroupB documentation was not written');
    AssertTrue(GroupSource.Contains('Пример &amp; details'),'Format lost Unicode or XML escaping');
    AssertTrue(GroupSource.Contains('procedure FromB'),'Format damaged GroupB declaration');
    Log('PASS GroupB open, edit, format, apply: '+Json.GetValue<string>('mode'));
   end
   else if Action='format-group-source' then begin
    {$IF CompilerVersion >= 37.0}
    Log('SKIP native Ctrl+D: the built-in Pascal formatter is unavailable in RAD Studio 13');
    Browser.ExecuteScript('window.__xmlDocNativeFormatted="unavailable";');
    {$ELSE}
    Step:=82;Timer.Interval:=100;Timer.Enabled:=True;
    {$IFEND}
   end
   else if Action='lock-source' then begin
    ProtectedBefore:=EditorSource(SourceEditorForFile(SampleFile));
    if Json.GetValue<string>('mode','')='buffer' then begin
     AssertTrue(Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer),'Read-only buffer unavailable');EditBuffer.IsReadOnly:=True;
    end else if Json.GetValue<string>('mode','')='system' then FileSetAttr(SampleFile,FileGetAttr(SampleFile) or faSysFile)
    else FileSetAttr(SampleFile,FileGetAttr(SampleFile) or faReadOnly);
    Select(SampleFile,'Run','string');Inspector.RefreshFromCurrentEditor;
   end
   else if Action='assert-protected' then begin
    AssertTrue(EditorSource(SourceEditorForFile(SampleFile))=ProtectedBefore,'Read-only source was modified');Log('PASS read-only file rejects forged browser write');
    FileSetAttr(SampleFile,FileGetAttr(SampleFile) and not (faReadOnly or faSysFile));
    if Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer) then EditBuffer.IsReadOnly:=False;
    Inspector.RefreshFromCurrentEditor;
   end
   else if Action='view-system' then begin
    SystemFile:=TPath.Combine(ExtractFileDir(ExcludeTrailingPathDelimiter(ExtractFilePath(GetModuleName(0)))),'source\rtl\sys\System.pas');
    ProtectedBefore:=TFile.ReadAllText(SystemFile);(BorlandIDEServices as IOTAActionServices).OpenFile(SystemFile);
    var SystemEditor:=SourceEditorForFile(SystemFile);AssertTrue(Assigned(SystemEditor),'System source editor missing');SystemEditor.Show;
    Inspector.HandleCursorChanged(1,EditorSource(SystemEditor),SystemFile);Explorer.HandleFileChanged(SystemFile,EditorSource(SystemEditor));
   end
   else if Action='assert-system' then begin
    AssertTrue(TFile.ReadAllText(SystemFile)=ProtectedBefore,'System.pas disk content changed');
    AssertTrue(not EditorSource(SourceEditorForFile(SystemFile)).Contains('FORBIDDEN READONLY WRITE'),'System buffer was modified');
    AssertParsed(Inspector);AssertParsed(Explorer);
    AssertTrue(SourceEditProtection(SystemFile)<>'','Compiler source is writable');Log('PASS System.pas parsed and protected in Inspector and Explorer');
   end
   else if Action='finish' then begin Log('PASS');Step:=90;Timer.Interval:=100;Timer.Enabled:=True;end
   else if Action='fail' then raise Exception.Create(Json.GetValue<string>('message','Unknown browser failure')+' '+Json.GetValue<string>('stack',''));
  except on E:Exception do begin Log('FAIL '+E.Message);if GetEnvironmentVariable('XMLDOC_E2E_KEEP_FAILURE')<>'1' then ExitProcess(1);end;end;
 finally Json.Free;end;
end;
function NativeWindowText(W:HWND):string;forward;
procedure TProbe.CloseExportMessage(Sender:TObject);
var F:TForm;C:TComponent;Text:string;W:HWND;P:DWORD;
begin
 W:=FindWindowEx(0,0,'#32770',nil);
 while W<>0 do begin
  GetWindowThreadProcessId(W,@P);
  if P=GetCurrentProcessId then begin LastGenerationMessage:=NativeWindowText(W);Log('GENERATION native completion dialog: '+LastGenerationMessage);PostMessage(W,WM_USER+102,IDOK,0);PostMessage(W,WM_COMMAND,IDOK,0);end;
  W:=FindWindowEx(0,W,'#32770',nil);
 end;
 for var I:=0 to Screen.FormCount-1 do begin F:=Screen.Forms[I];
  if (F.ClassName='TInputQueryForm') and (F.Caption=TI18n.Instance.T('Create CSS theme')) then begin
    for var J:=0 to F.ComponentCount-1 do if F.Components[J] is TEdit then TEdit(F.Components[J]).Text:='e2e-created';
    F.ModalResult:=mrOK;
  end;
  if (F.ClassName='TMessageForm') then begin
   Text:='';for var J:=0 to F.ComponentCount-1 do begin C:=F.Components[J];if C is TLabel then Text:=Text+TLabel(C).Caption;end;
   LastGenerationMessage:=Text;Log('GENERATION MESSAGE: '+Text);F.ModalResult:=mrOK;
  end;
 end;
end;
procedure AssertErrorLabelTheme(Form:TForm);
var LabelControl:TMemo;Foreground,Background:Longint;Difference:Integer;Theme:IOTAIDEThemingServices;
begin
 for var I:=0 to Form.ComponentCount-1 do if (Form.Components[I] is TMemo) and (Form.Components[I].Name='DocumentationError') then begin
  LabelControl:=TMemo(Form.Components[I]);
  Foreground:=ColorToRGB(LabelControl.Font.Color);Background:=ColorToRGB(LabelControl.Color);
  if Supports(BorlandIDEServices,IOTAIDEThemingServices,Theme) and Theme.IDEThemingEnabled then
   if Background<>ColorToRGB(Theme.StyleServices.GetSystemColor(clWindow)) then raise Exception.Create('Native diagnostic does not follow the IDE theme');
  Difference:=Abs(Integer(GetRValue(Foreground))-Integer(GetRValue(Background)))+
   Abs(Integer(GetGValue(Foreground))-Integer(GetGValue(Background)))+
   Abs(Integer(GetBValue(Foreground))-Integer(GetBValue(Background)));
  if not LabelControl.ReadOnly or not LabelControl.WordWrap then raise Exception.Create('Error panel must be read-only and wrap text');
  if Difference<192 then raise Exception.Create('Unreadable native error label in '+Form.Caption);
 end;
 Log('PASS native error label theme: '+Form.Caption);
end;
procedure TProbe.ExportAll;
var D:TBatchGenDialog;C:TComponent;B:TButton;T:TTimer;N:Integer;Output,ThemeDirectory,OriginalThemeDirectory:string;Done:Boolean;
begin
 Output:=TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_LOG')),'documentation');
 OriginalThemeDirectory:=TThemeEngine.Instance.CustomThemesDir;
 ThemeDirectory:=TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_LOG')),'created-themes');
 TThemeEngine.Instance.SetCustomThemesDir(ThemeDirectory);
 D:=TBatchGenDialog.Create(nil);T:=TTimer.Create(nil);
 try
  B:=nil;N:=0;
  for var I:=0 to D.ComponentCount-1 do begin C:=D.Components[I];
   if C is TComboBox then begin
    AssertTrue(TComboBox(C).Text=TPluginSettings.Instance.DocumentationTheme,'Generation dialog lost the effective global/project theme');
    TComboBox(C).ItemIndex:=TComboBox(C).Items.IndexOf('e2e-created');
    AssertTrue(TComboBox(C).ItemIndex>=0,'New custom theme missing from generation dialog');
   end;
   if C is TCheckBox then begin
    if TCheckBox(C).Caption=TI18n.Instance.T('Include private members') then TCheckBox(C).Checked:=False
    else TCheckBox(C).Checked:=True;
   end;
   if C is TEdit then begin
    Inc(N);case N of 2:TEdit(C).Text:='';3:TEdit(C).Text:=Output;4:TEdit(C).Text:='XmlDocE2E';end;
   end;
   if (C is TButton) and (TButton(C).Caption=TI18n.Instance.T('Generate')) then B:=TButton(C);
  end;
  AssertTrue(Assigned(B),'Generate button unavailable');D.Show;T.Interval:=200;T.OnTimer:=CloseExportMessage;
  // Change the selected custom CSS after the dialog loaded its initial catalog.
  TFile.WriteAllText(TPath.Combine(ThemeDirectory,'e2e-created.css'),TThemeEngine.Instance.GetCSS(btHighContrast),TEncoding.UTF8);
  B.Click;T.Enabled:=False;
  Done:=False;
  for var I:=0 to D.ComponentCount-1 do
    if (D.Components[I] is TLabel) and (TLabel(D.Components[I]).Caption=TI18n.Instance.T('Done!')) then Done:=True;
  AssertTrue(Done,'Generation did not reach the successful completion phase');
  AssertTrue(TFile.Exists(TPath.Combine(Output,'XmlDocE2E.chm')),'CHM generation did not complete');
  AssertTrue(TFile.Exists(TPath.Combine(Output,'site-vitepress\package.json')),'Site generation did not complete');
  for var CSSFile in ['assets\style.css','_chm_html\assets\style.css'] do
    AssertTrue(TFile.ReadAllText(TPath.Combine(Output,CSSFile)).Contains(TThemeEngine.Instance.GetCSS(btHighContrast)),'Generation ignored the selected HTML/CHM theme: '+CSSFile);
  Log('PASS native generation applies selected custom theme and reloads edited CSS for HTML and CHM');
  Log('PASS all eight formats through installed plugin dialog: '+Output);
  var SpinCount:=0;var ReadyLimit:TSpinEdit;ReadyLimit:=nil;
  for var I:=0 to D.ComponentCount-1 do if D.Components[I] is TSpinEdit then begin Inc(SpinCount);if SpinCount=2 then ReadyLimit:=TSpinEdit(D.Components[I]);end;
  AssertTrue((SpinCount=2) and Assigned(ReadyLimit),'Separate presence/readiness controls missing');
  var OldLogPath:=TLogger.Instance.LogPath;var OldLogLevel:=TLogger.Instance.Level;
  var GateLog:=TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_LOG')),'readiness-gate.log');
  TLogger.Instance.Configure(llDebug,GateLog);
  try
   ReadyLimit.Value:=100;LastGenerationMessage:='';T.Enabled:=True;B.Click;T.Enabled:=False;
  finally TLogger.Instance.Configure(OldLogLevel,OldLogPath);end;
  AssertTrue(TFile.ReadAllText(GateLog).Contains('Ready documentation') and TFile.ReadAllText(GateLog).Contains('below the required 100%'),'Readiness threshold did not reject unfinished fixture; see '+GateLog);
  Log('PASS native generation rejects unfinished documentation with readiness threshold 100');
  ReadyLimit.Value:=0;LastGenerationMessage:='';T.Enabled:=True;B.Click;T.Enabled:=False;
  Done:=False;for var I:=0 to D.ComponentCount-1 do if (D.Components[I] is TLabel) and (TLabel(D.Components[I]).Caption=TI18n.Instance.T('Done!')) then Done:=True;
  AssertTrue(Done,'Generation did not recover after disabling readiness threshold');
  Log('PASS native generation succeeds with readiness threshold disabled');

 finally T.Free;D.Free;TThemeEngine.Instance.SetCustomThemesDir(OriginalThemeDirectory);end;
end;
function NativeWindowText(W:HWND):string;
var C:HWND;Buffer:array[0..4095] of Char;
begin
 GetWindowText(W,Buffer,Length(Buffer));Result:=string(Buffer);C:=GetWindow(W,GW_CHILD);
 while C<>0 do begin Result:=Result+NativeWindowText(C);C:=GetWindow(C,GW_HWNDNEXT);end;
end;
function NativeYesButton(W:HWND):HWND;
var C:HWND;Buffer:array[0..127] of Char;
begin
 Result:=0;GetWindowText(W,Buffer,Length(Buffer));if SameText(StringReplace(string(Buffer),'&','',[rfReplaceAll]),'Yes') then Exit(W);
 C:=GetWindow(W,GW_CHILD);while C<>0 do begin Result:=NativeYesButton(C);if Result<>0 then Exit;C:=GetWindow(C,GW_HWNDNEXT);end;
end;
procedure TProbe.ConfirmFormat(Sender:TObject);
var Text:string;W,Button:HWND;P:DWORD;
begin
 W:=FindWindowEx(0,0,nil,nil);
 while W<>0 do begin
  GetWindowThreadProcessId(W,@P);
  if P=GetCurrentProcessId then begin
   Text:=NativeWindowText(W);
   if Text.Contains('Do you really want to format the selected file:') and Text.Contains(TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas')) then begin
    Button:=NativeYesButton(W);
    if Button<>0 then begin Log('Confirmed native formatter for isolated GroupB fixture');SendMessage(Button,BM_CLICK,0,0);end;
   end;
  end;
  W:=FindWindowEx(0,W,nil,nil);
 end;
end;
function FocusCodeEditor(Control:TWinControl):Boolean;
begin
 Result:=False;
 if ContainsText(Control.ClassName,'EditControl') and Control.CanFocus then begin Log('Native editor focus '+Control.ClassName);Control.SetFocus;Exit(True);end;
 for var I:=0 to Control.ControlCount-1 do if Control.Controls[I] is TWinControl then if FocusCodeEditor(TWinControl(Control.Controls[I])) then Exit(True);
end;
procedure TProbe.Tick(Sender:TObject);
var I:Integer;Editor:IOTASourceEditor;
begin
 Timer.Enabled:=False;
 try
 case Step of
  104:begin
   StressEntered:=TEvent.Create(nil,True,False,'');
   var Modules:=StrToInt(GetEnvironmentVariable('XMLDOC_E2E_BENCHMARK_MODULES'));
   var SavedActive:=GetActiveProject;
   for var ProjectNumber:=0 to 1 do begin
    var Dir:=TPath.Combine(Root,'Benchmark'+ProjectNumber.ToString);ForceDirectories(Dir);
    var Name:='Benchmark'+ProjectNumber.ToString;
    var ProjectXml:='<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"><PropertyGroup><MainSource>'+Name+'.dpr</MainSource><ProjectGuid>'+TGUID.NewGuid.ToString+'</ProjectGuid><ProjectVersion>20.3</ProjectVersion><FrameworkType>None</FrameworkType><AppType>Console</AppType><Config>Debug</Config><Platform>Win32</Platform><DCC_Namespace>System;System.Win;Winapi</DCC_Namespace></PropertyGroup><ItemGroup>';
    var ProgramText:='program '+Name+';'+sLineBreak+'uses ';
    TFile.WriteAllText(TPath.Combine(Dir,'Shared.inc'),'{$DEFINE BENCHMARK}',TEncoding.UTF8);
    for var J:=1 to Modules div 2 do begin
     var UnitName:='Perf'+ProjectNumber.ToString+'Unit'+J.ToString;
     var Text:='unit '+UnitName+'; interface {$I Shared.inc} type TItem=class procedure Run; end; implementation procedure TItem.Run; begin end;'+sLineBreak;
     for var K:=1 to 100 do Text:=Text+'// Representative source payload for publication hashing '+K.ToString+sLineBreak;
     Text:=Text+'end.';TFile.WriteAllText(TPath.Combine(Dir,UnitName+'.pas'),Text,TEncoding.UTF8);
     ProjectXml:=ProjectXml+'<DCCReference Include="'+UnitName+'.pas"/>';
     if J>1 then ProgramText:=ProgramText+','+sLineBreak;ProgramText:=ProgramText+UnitName+' in '+QuotedStr(UnitName+'.pas');
    end;
    TFile.WriteAllText(TPath.Combine(Dir,Name+'.dpr'),ProgramText+';'+sLineBreak+'begin end.',TEncoding.UTF8);
    ProjectXml:=ProjectXml+'</ItemGroup><Import Project="$(BDS)\Bin\CodeGear.Delphi.Targets"/></Project>';
    var ProjectFile:=TPath.Combine(Dir,Name+'.dproj');TFile.WriteAllText(ProjectFile,ProjectXml,TEncoding.UTF8);
    AssertTrue((BorlandIDEServices as IOTAActionServices).OpenProject(ProjectFile,False),'Cannot open publication benchmark project');
   end;
   (BorlandIDEServices as IOTAModuleServices).MainProjectGroup.ActiveProject:=SavedActive;
   ValidationProbe:=TPublicationProbe.Create;StressRound:=0;
   var Request:=TJSONObject.Create;try Request.AddPair('type','requestCatalog');Request.AddPair('scope','group');ValidationProbe.Handle(Request,Browser);finally Request.Free;end;
   StressStarted:=GetTickCount64;Step:=105;Timer.Interval:=20;Timer.Enabled:=True;Exit;
  end;
  105:begin
   if ValidationProbe.Busy then begin AssertTrue(GetTickCount64-StressStarted<90000,'Large group publication timed out');Timer.Enabled:=True;Exit;end;
   AssertTrue(ValidationProbe.LastError='','Benchmark failed: '+ValidationProbe.LastError);
   AssertTrue(ValidationProbe.ModuleCount>=StrToInt(GetEnvironmentVariable('XMLDOC_E2E_BENCHMARK_MODULES')),'Large group did not include the generated modules: '+ValidationProbe.ModuleCount.ToString);
   Log('PERF publication round='+StressRound.ToString+' modules='+ValidationProbe.ModuleCount.ToString+' finalFreshMs='+FloatToStr(ValidationProbe.FinalValidationMs)+' maxValidationUiPauseMs='+FloatToStr(ValidationProbe.MaxValidationPauseMs)+' publicationMs='+FloatToStr(ValidationProbe.PublicationMs));
   if StressRound=0 then begin
    Inc(StressRound);var Request:=TJSONObject.Create;try Request.AddPair('type','requestCatalog');Request.AddPair('scope','group');ValidationProbe.Handle(Request,Browser);finally Request.Free;end;
    StressStarted:=GetTickCount64;Timer.Enabled:=True;Exit;
   end;
   Log('PASS large-group cold and warm publication measurements');FreeAndNil(ValidationProbe);FreeAndNil(StressEntered);Log('PASS');Finish;Exit;
  end;
  95:begin
   Log('Starting large-file IDE check');
   var LargeProject:=GetEnvironmentVariable('XMLDOC_E2E_LARGE_PROJECT');var LargeFile:=GetEnvironmentVariable('XMLDOC_E2E_LARGE_SOURCE');
   if (LargeProject<>'') and (LargeFile<>'') then begin
    var BeforeHash:=THashSHA2.GetHashStringFromFile(LargeFile);
    var GroupBefore:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;var ActiveBefore:=GetActiveProject;
    // Carry the actual project's evaluated compiler context into a temporary,
    // source-only project. Restoring its desktop would instantiate unavailable
    // third-party form classes in the deliberately isolated test profile.
    var Context:=TProjectContext.Create(LargeProject,'Debug','Win32');
    var PerformanceRoot:=TPath.Combine(Root,'Performance');ForceDirectories(PerformanceRoot);
    var PerformanceProject:=TPath.Combine(PerformanceRoot,'SourceLatency.dproj');
    try
     var ProjectXml:='<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"><PropertyGroup><MainSource>SourceLatency.dpr</MainSource><DCC_Define>'+XmlEscape(string.Join(';',Context.Defines))+'</DCC_Define><DCC_IncludePath>'+XmlEscape(ExtractFilePath(LargeProject)+';'+string.Join(';',Context.IncludePaths))+'</DCC_IncludePath><DCC_UnitSearchPath>'+XmlEscape(ExtractFilePath(LargeProject)+';'+string.Join(';',Context.SearchPaths))+'</DCC_UnitSearchPath></PropertyGroup><ItemGroup>';
     for var OriginalFile in Context.SourceFiles+[LargeFile] do if not SameText(ExtractFileExt(OriginalFile),'.dpr') then ProjectXml:=ProjectXml+'<DCCReference Include="'+XmlEscape(OriginalFile)+'"/>';
    ProjectXml:=ProjectXml+'</ItemGroup></Project>';TFile.WriteAllText(PerformanceProject,ProjectXml,TEncoding.UTF8);TFile.WriteAllText(TPath.Combine(PerformanceRoot,'SourceLatency.dpr'),'program SourceLatency; begin end.',TEncoding.UTF8);
    finally Context.Free;end;
    AssertTrue(Assigned(ActiveBefore) and ActiveBefore.FileName.StartsWith(Root,True),'Performance context must belong to the isolated fixture');
    var SavedProject:=TFile.ReadAllBytes(ActiveBefore.FileName);var SavedStamp:=TFile.GetLastWriteTimeUtc(ActiveBefore.FileName);
    // Exercise the real evaluated context through the normal Inspector path,
    // without restoring the user project's form designer in the test profile.
    TFile.WriteAllText(TPath.Combine(ExtractFilePath(ActiveBefore.FileName),'SourceLatency.dpr'),'program SourceLatency; begin end.',TEncoding.UTF8);
    try
    TFile.WriteAllBytes(ActiveBefore.FileName,TFile.ReadAllBytes(PerformanceProject));TFile.SetLastWriteTimeUtc(ActiveBefore.FileName,SavedStamp);
    Log('Opening performance source '+LargeFile);AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(LargeFile),'Cannot open large source');
    var LargeEditor:=SourceEditorForFile(LargeFile);AssertTrue(Assigned(LargeEditor),'Large source editor unavailable');
    var LargeText:=EditorSource(LargeEditor);var Parser:=TDocParser.Create;var LargeLine:=0;
    try ConfigureDeclarationContext(Parser,nil,LargeFile);Parser.ParseSource(LargeText,LargeFile);
     for var Item in Parser.GetAllElements do if (Item.Name='WriteToChangeLogTable') and (Item.SourceSection='implementation') then begin LargeLine:=Item.LineNumber;Break;end;
    finally Parser.Free;end;
    AssertTrue(LargeLine>0,'Requested large-file method not found');
    var Watch:=TStopwatch.StartNew;Inspector.HandleCursorChanged(LargeLine,LargeText,LargeFile);Log('PERF large Inspector cold ms='+FloatToStr(Watch.Elapsed.TotalMilliseconds));
    var Total,Maximum:Double;Total:=0;Maximum:=0;
    for var J:=1 to 20 do begin Watch:=TStopwatch.StartNew;Inspector.HandleCursorChanged(LargeLine+(J mod 2),LargeText,LargeFile);var Elapsed:=Watch.Elapsed.TotalMilliseconds;Total:=Total+Elapsed;if Elapsed>Maximum then Maximum:=Elapsed;end;
    Log('PERF large Inspector warm mean ms='+FloatToStr(Total/20)+' max synchronous UI ms='+FloatToStr(Maximum));
    AssertTrue(BeforeHash=THashSHA2.GetHashStringFromFile(LargeFile),'Large user source changed');
    Log('PASS large source remained byte-for-byte unchanged: '+LargeFile);
    finally TFile.WriteAllBytes(ActiveBefore.FileName,SavedProject);TFile.SetLastWriteTimeUtc(ActiveBefore.FileName,SavedStamp);end;
   end;
   Step:=96;Timer.Interval:=20;Timer.Enabled:=True;Exit;
  end;
  96:begin
   var Name:=TPath.Combine(Root,'WorkerStress'+StressRound.ToString+'.pas');
   var Text:=TStringBuilder.Create;
   try Text.Append('unit WorkerStress').Append(StressRound).Append(';').AppendLine.AppendLine('interface').AppendLine('type TBase=class procedure Run; virtual; end;');
    for var J:=1 to 500 do Text.Append(' TChild').Append(J).AppendLine('=class(TBase) procedure Run; override; end;');Text.AppendLine('implementation').AppendLine('end.');TFile.WriteAllText(Name,Text.ToString,TEncoding.UTF8);
   finally Text.Free;end;
   AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(Name),'Cannot open stress fixture');
   var Docs:TProjectDocumentation;var Target:TXmlDocBrowser;
   if StressRound=3 then begin Docs:=Explorer.Documentation;Target:=ExplorerBrowser;end else begin Docs:=Inspector.Documentation;Target:=Browser;end;
   StressEntered:=TEvent.Create(nil,True,False,'');StressContinue:=TEvent.Create(nil,True,False,'');StressChecks:=0;
   Docs.OnWorkerCheck:=procedure begin if TInterlocked.Increment(StressChecks)=8 then begin StressEntered.SetEvent;if StressContinue.WaitFor(10000)<>wrSignaled then raise Exception.Create('Active worker barrier timed out');end;end;
   StressGeneration:=Docs.PublishedGeneration;
   var Request:=TJSONObject.Create;try Request.AddPair('type','requestCatalog');Request.AddPair('scope','module');Docs.Handle(Request,Target);finally Request.Free;end;
   StressStarted:=GetTickCount64;Step:=97;Timer.Enabled:=True;Exit;
  end;
  97:begin
   var Docs:TProjectDocumentation;var Target:TXmlDocBrowser;
   if StressRound=3 then begin Docs:=Explorer.Documentation;Target:=ExplorerBrowser;end else begin Docs:=Inspector.Documentation;Target:=Browser;end;
   if not Docs.Working or (StressEntered.WaitFor(0)<>wrSignaled) then begin AssertTrue(GetTickCount64-StressStarted<10000,'Stress worker did not become active: round='+StressRound.ToString+' checks='+StressChecks.ToString+' busy='+BoolToStr(Docs.Busy,True)+' error='+Docs.LastError);Timer.Enabled:=True;Exit;end;
   StressStarted:=GetTickCount64;StressContinue.SetEvent;
   if StressRound>=2 then begin
    if StressRound=2 then begin Inspector.Free;Inspector:=nil;Browser:=nil;end else begin Explorer.Free;Explorer:=nil;ExplorerBrowser:=nil;end;
    var Delay:=GetTickCount64-StressStarted;Log('PERF close form during active worker round='+StressRound.ToString+' ms='+UIntToStr(Delay));AssertTrue(Delay<2000,'Closing a form waited more than 2 seconds for active analysis');FreeAndNil(StressContinue);FreeAndNil(StressEntered);
    Inc(StressRound);if StressRound=4 then begin Log('PASS active-worker cancellation, superseding request, Inspector/Explorer close');Log('PASS');Step:=90;end else Step:=96;
   end else begin
    var Request:=TJSONObject.Create;
    try if StressRound=0 then Request.AddPair('type','cancelAnalysis') else begin Request.AddPair('type','requestCatalog');Request.AddPair('scope','module');end;Docs.Handle(Request,Target);finally Request.Free;end;
    Step:=98;
   end;Timer.Enabled:=True;Exit;
  end;
  98:begin
   var Docs:=Inspector.Documentation;
   if Docs.Busy then begin AssertTrue(GetTickCount64-StressStarted<20000,'Active worker did not stop/complete');Timer.Enabled:=True;Exit;end;
   var Delay:=GetTickCount64-StressStarted;Log('PERF active worker round='+StressRound.ToString+' ms='+UIntToStr(Delay));
   if StressRound=0 then begin AssertTrue(Delay<2000,'Active cancellation took more than 2 seconds');AssertTrue(Docs.PublishedGeneration=StressGeneration,'Cancelled job published a partial catalog');end
   else AssertTrue(Docs.PublishedGeneration=StressGeneration+1,'Superseded job published a catalog');
   Docs.OnWorkerCheck:=nil;FreeAndNil(StressContinue);FreeAndNil(StressEntered);
   Inc(StressRound);if StressRound=2 then Step:=100 else Step:=96;Timer.Enabled:=True;Exit;
  end;
  100:begin
   ValidationProbe:=TPublicationProbe.Create;
   ValidationProbe.IncludeFile:=TPath.Combine(Root,'PublicationFeatures.inc');TFile.WriteAllText(ValidationProbe.IncludeFile,'type TOriginal=class end;',TEncoding.UTF8);
   var SourceFile:=TPath.Combine(Root,'PublicationMain.pas');TFile.WriteAllText(SourceFile,'unit PublicationMain; interface {$I PublicationFeatures.inc} implementation end.',TEncoding.UTF8);
   AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(ValidationProbe.IncludeFile),'Cannot open publication include');
   AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(SourceFile),'Cannot open publication source');
   var Request:=TJSONObject.Create;try Request.AddPair('type','requestCatalog');Request.AddPair('scope','module');ValidationProbe.Handle(Request,Browser);finally Request.Free;end;
   StressStarted:=GetTickCount64;Step:=101;Timer.Enabled:=True;Exit;
  end;
  101:begin
   if ValidationProbe.Busy then begin AssertTrue(GetTickCount64-StressStarted<10000,'Initial publication timed out');Timer.Enabled:=True;Exit;end;
   AssertTrue(ValidationProbe.PublishedGeneration=1,'Initial validation catalog not published');ValidationProbe.Armed:=True;
   var Request:=TJSONObject.Create;try Request.AddPair('type','requestCatalog');Request.AddPair('scope','module');ValidationProbe.Handle(Request,Browser);finally Request.Free;end;
   StressStarted:=GetTickCount64;Step:=102;Timer.Enabled:=True;Exit;
  end;
  102:begin
   if ValidationProbe.Busy then begin AssertTrue(GetTickCount64-StressStarted<10000,'Publication validation timed out');Timer.Enabled:=True;Exit;end;
   AssertTrue(ValidationProbe.Changed,'Include did not change at the publication boundary');AssertTrue(ValidationProbe.PublishedGeneration=1,'A reused module published after its open include changed');
   Log('PASS reused-module publication rejects include edited after incremental validation and retains the previous catalog');
   ValidationProbe.NewModule:=TPath.Combine(Root,'PublicationExtra.pas');TFile.WriteAllText(ValidationProbe.NewModule,'unit PublicationExtra; interface type TExtra=class end; implementation end.',TEncoding.UTF8);ValidationProbe.Changed:=False;ValidationProbe.Armed:=True;
   var Request:=TJSONObject.Create;try Request.AddPair('type','requestCatalog');Request.AddPair('scope','project');ValidationProbe.Handle(Request,Browser);finally Request.Free;end;
   StressStarted:=GetTickCount64;Step:=103;Timer.Enabled:=True;Exit;
  end;
  103:begin
   if ValidationProbe.Busy then begin AssertTrue(GetTickCount64-StressStarted<10000,'Project membership validation timed out');Timer.Enabled:=True;Exit;end;
   AssertTrue(ValidationProbe.Changed,'Project membership did not change at the publication boundary');AssertTrue(ValidationProbe.PublishedGeneration=1,'Catalog published with a stale project module set');
   Log('PASS publication rejects changed project membership and retains the previous catalog');FreeAndNil(ValidationProbe);Step:=96;Timer.Enabled:=True;Exit;
  end;
  113:begin
    Log('Shared context: creating project fixtures');
    var ProjectA:=GetActiveProject;SharedProjectA:=ProjectA.FileName;SharedMainXml:=TFile.ReadAllText(SharedProjectA,TEncoding.UTF8);
    SharedFile:=TPath.Combine(Root,'SharedContext.pas');
    TFile.WriteAllText(SharedFile,'unit SharedContext;'+sLineBreak+'interface'+sLineBreak+'type TShared=class'+sLineBreak+'/// <summary>Shared documentation.</summary>'+sLineBreak+'procedure Run(Value:Integer);'+sLineBreak+'end;'+sLineBreak+'implementation'+sLineBreak+'procedure TShared.Run(Value:Integer);'+sLineBreak+'begin end;'+sLineBreak+'end.',TEncoding.UTF8);
    ProjectA.AddFile(SharedFile,True);Log('Shared context: source added to A');
    TFile.WriteAllText(SharedProjectA,SharedMainXml.Replace('DEBUG;','SHARED_A;DEBUG;'),TEncoding.UTF8);
    var SettingsPath:=TPath.Combine(Root,'.xmldocplugin.json');SharedSettings:=TFile.ReadAllText(SettingsPath,TEncoding.UTF8);var Settings:=TJSONObject.ParseJSONValue(SharedSettings) as TJSONObject;
    try var Authoring:=Settings.GetValue<TJSONObject>('authoring');Authoring.RemovePair('terminology').Free;Authoring.AddPair('terminology',TJSONArray.Create(TJSONString.Create('SHARED_TERM_A')));TFile.WriteAllText(SettingsPath,Settings.ToJSON,TEncoding.UTF8);finally Settings.Free;end;
    var Dir:=TPath.Combine(Root,'SharedB');ForceDirectories(Dir);SharedProjectB:=TPath.Combine(Dir,'SharedB.dproj');
    var Xml:=TRegEx.Replace(SharedMainXml.Replace('XmlDocE2E','SharedB'),'<DCCReference[^>]*/>','');Xml:=Xml.Replace('{3A72602E-67CF-469D-A733-BC75247CC365}',TGUID.NewGuid.ToString).Replace('DEBUG;','SHARED_B;DEBUG;').Replace('</Project>','<ItemGroup><DCCReference Include="'+SharedFile+'"/></ItemGroup></Project>');
    TFile.WriteAllText(SharedProjectB,Xml,TEncoding.UTF8);TFile.WriteAllText(TPath.Combine(Dir,'SharedB.dpr'),'program SharedB; uses SharedContext in ''..\SharedContext.pas'';begin end.',TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(Dir,'.xmldocplugin.json'),'{"authoring":{"terminology":["SHARED_TERM_B"]}}',TEncoding.UTF8);
    Log('Shared context: opening B');
    AssertTrue((BorlandIDEServices as IOTAActionServices).OpenProject(SharedProjectB,False),'Shared project B did not open');var Group:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;Group.ActiveProject:=ProjectA;Log('Shared context: B open, A active');
    var Targets:=TJSONArray.Create;var P:=TDocParser.Create;
    try P.ParseSource(TFile.ReadAllText(SharedFile,TEncoding.UTF8),SharedFile);for var E in P.GetAllElements do if (E.Name='Run') and (E.SourceSection='interface') then
     for var ProjectFile in [SharedProjectB,SharedProjectA,SharedProjectB] do Targets.AddElement(TJSONObject.Create.AddPair('type','openSymbol').AddPair('projectFile',ProjectFile).AddPair('fileName',SharedFile).AddPair('symbolId',E.SymbolId).AddPair('locationId',E.SymbolId+'@interface').AddPair('line',TJSONNumber.Create(E.LineNumber)));
     Inspector.Show;
     Browser.ExecuteScript('window.__sharedTargets='+Targets.ToJSON+';window.__sharedContextReady=true;');Log('Shared context: targets ready');
    finally P.Free;Targets.Free;end;
    Step:=114;Exit;
  end;
  110:begin
   Browser.ExecuteScript('document.getElementById("ai-describe").click();');ExplorerBrowser.ExecuteScript('document.getElementById("ai-describe").click();');Step:=111;Timer.Interval:=300;Timer.Enabled:=True;Exit;
  end;
  111:begin
   Browser.ExecuteScript('document.getElementById("ai-send").click();');ExplorerBrowser.ExecuteScript('document.getElementById("ai-send").click();');Step:=112;Timer.Interval:=50;Timer.Enabled:=True;Exit;
  end;
  112:begin
   AssertTrue(AssistantFor(Inspector).Busy and AssistantFor(Explorer).Busy,'Both AI operations must be active at close');var Started:=GetTickCount64;
   FreeAndNil(Explorer);FreeAndNil(Inspector);AssertTrue(GetTickCount64-Started<1500,'AI close blocked IDE');Log('PASS close Inspector/Explorer with active AI workers: '+IntToStr(GetTickCount64-Started)+' ms');Log('PASS');Finish;Exit;
  end;
  90:begin Finish;Exit;end;
  80:begin
   Log('Adding project B outside WebView callback');
   AssertTrue((BorlandIDEServices as IOTAActionServices).OpenProject(TPath.Combine(TPath.Combine(Root,'GroupB'),'GroupB.dproj'),False),'Cannot add group project B');
   var Group:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;
   for var J:=0 to Group.ProjectCount-1 do if SameText(Group.Projects[J].FileName,PrimaryProjectFile) then begin Group.ActiveProject:=Group.Projects[J];Break;end;
   Log('Added project B; active project '+GetActiveProject.FileName);Step:=81;Timer.Interval:=1500;Timer.Enabled:=True;
   Exit;
  end;
  82:begin
   var GroupFile:=TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas');
   var GroupEditor:=SourceEditorForFile(GroupFile);AssertTrue(Assigned(GroupEditor),'GroupB editor unavailable for Format Source');var ProjectGroup:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;ProjectGroup.ActiveProject:=ProjectGroup.FindProject(GroupFile);GroupEditor.Show;
   var Actions:=(BorlandIDEServices as INTAServices).ActionList;var FormatAction:TCustomAction:=nil;
   for var K:=0 to Actions.ActionCount-1 do if Actions.Actions[K] is TCustomAction then begin
    var A:=TCustomAction(Actions.Actions[K]);
    if SameText(A.Name,'actFormatSource') then FormatAction:=A;
   end;
   AssertTrue(Assigned(FormatAction),'Native Format Source action not found');AssertTrue(FormatAction.ShortCut=ShortCut(Ord('D'),[ssCtrl]),'Native formatter is not bound to Ctrl+D');
   var SourceBytes:=UTF8Encode(EditorSource(GroupEditor));var EditOffset:=Pos(UTF8String('begin end;'),SourceBytes)-1;AssertTrue(EditOffset>=0,'GroupB body missing');
   var NativeWriter:=GroupEditor.CreateUndoableWriter;NativeWriter.CopyTo(EditOffset);NativeWriter.DeleteTo(EditOffset+Length('begin end;'));var InsertBytes:=UTF8String('begin   {E2E native format}   end;');NativeWriter.Insert(PAnsiChar(InsertBytes));NativeWriter:=nil;FormatBefore:=EditorSource(GroupEditor);
   Application.MainForm.Show;Application.MainForm.BringToFront;Application.MainForm.SetFocus;var EditForm:=GroupEditor.GetEditView(0).GetEditWindow.Form;AssertTrue(FocusCodeEditor(EditForm),'Native source control could not acquire focus');
   Log('Invoking native formatter '+FormatAction.Name+' after Pascal buffer edit');FormatConfirmation:=TTimer.Create(nil);FormatConfirmation.Interval:=100;FormatConfirmation.OnTimer:=ConfirmFormat;if Assigned(FormatAction.OnExecute) then FormatAction.OnExecute(FormatAction) else AssertTrue(FormatAction.Execute,'Native Format Source action rejected');
   Step:=83;Timer.Interval:=750;Timer.Enabled:=True;Exit;
  end;
  83:begin
   var GroupEditor:=SourceEditorForFile(TPath.Combine(TPath.Combine(Root,'GroupB'),'ContextB.pas'));
   if (EditorSource(GroupEditor)=FormatBefore) and (FormatWait<40) then begin Inc(FormatWait);Timer.Enabled:=True;Exit;end;
   AssertTrue(EditorSource(GroupEditor)<>FormatBefore,'Native formatter did not change unformatted Pascal buffer');
   FreeAndNil(FormatConfirmation);
   AssertTrue(EditorSource(GroupEditor).Contains('E2E native format'),'Native formatter lost Pascal buffer edit');
   AssertTrue(EditorSource(GroupEditor).Contains('GroupB saved before format'),'Native formatter lost documentation');
   Inspector.RefreshFromCurrentEditor;Log('PASS native Format Source on edited GroupB');
   Browser.ExecuteScript('window.__xmlDocNativeFormatted=true;');Step:=81;Timer.Interval:=1500;Timer.Enabled:=True;Exit;
  end;
  81:begin
   Browser.ExecuteScript(TFile.ReadAllText(TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_JS')),'WorkbenchGroupProbe.js'),TEncoding.UTF8));
   Timer.Enabled:=True;Exit;
  end;
  0:begin
   if GetEnvironmentVariable('XMLDOC_E2E_MARKER_PHASE')<>'' then begin
    Root:=GetEnvironmentVariable('XMLDOC_E2E_FIXTURE');SampleFile:=TPath.Combine(Root,'Units\Workbench.Sample.pas');SecondFile:=TPath.Combine(Root,'Units\Workbench.Second.pas');
    var D:=TSettingsDialog.Create(nil);
    try
     if GetEnvironmentVariable('XMLDOC_E2E_MARKER_PHASE')='save' then begin
      D.memPlaceholderMarkers.Lines.Text:=CDefaultPlaceholderMarkers+#10+'VERIFY-RESTART:'+#10+'[draft].*:';
      D.edtPlaceholderPrefix.Text:='OTHER: ';
      D.hotToggleInspector.HotKey:=0;D.hotGenerateStub.HotKey:=0;D.hotGenerateHelp.HotKey:=0;D.hotCoverageReport.HotKey:=0;D.hotNextUndocumented.HotKey:=0;D.hotPreviousUndocumented.HotKey:=0;
      D.btnOKClick(nil);
     end;
     AssertTrue(D.memPlaceholderMarkers.Lines.Text.Replace(#13,'').Trim=(CDefaultPlaceholderMarkers+#10+'VERIFY-RESTART:'+#10+'[draft].*:').Replace(#13,'').Trim,'Marker list was lost across restart');
     AssertTrue(D.edtPlaceholderPrefix.Text='OTHER: ','Generation prefix was lost across restart');
     Log('PASS persisted marker Settings phase='+GetEnvironmentVariable('XMLDOC_E2E_MARKER_PHASE')+' process='+GetCurrentProcessId.ToString);
    finally D.Free;end;
    AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(TPath.Combine(Root,'XmlDocE2E.dproj')),'Cannot open E2E project');Inc(Step);Timer.Enabled:=True;Exit;
   end;
    var Actions:=(BorlandIDEServices as INTAServices).ActionList;var Found:=False;
    for var ActionIndex:=0 to Actions.ActionCount-1 do if Actions.Actions[ActionIndex].Name='XmlDocActionsyncdocument' then Found:=True;
    AssertTrue(Found,'Documentation actions are not registered in the IDE action catalog');AssertTrue(Assigned(FindMenuCommand((BorlandIDEServices as INTAServices).MainMenu.Items,'User Guide')),'Offline User Guide menu missing');Log('PASS IDE action registration and offline User Guide menu');
    var Shortcuts:=TPluginSettings.Instance.Global.Shortcuts;
    var Conflicts:=DocumentationShortcutConflicts([Shortcuts.ToggleInspector,Shortcuts.GenerateStub,Shortcuts.CoverageReport,Shortcuts.NextUndocumented],['Inspector','Stub','Coverage','Next'],Actions,(BorlandIDEServices as INTAServices).MainMenu.Items);
    for var Conflict in Conflicts do begin
      Log('SHORTCUT '+Conflict);
      AssertTrue(not Conflict.Contains('Doc Inspector') and not Conflict.Contains('Generate Doc Stub') and not Conflict.Contains('Coverage Report') and not Conflict.Contains('Next Undocumented'),'Own IDE menu wrapper reported as shortcut conflict');
    end;
    Log('PASS IDE shortcut ownership validation');
    AssertTrue(GetModuleVersion=GetEnvironmentVariable('XMLDOC_E2E_VERSION'),'Loaded BPL version differs from the shared version');
    AssertTrue(RegisteredSplashCaption='XmlDocPlugin '+GetModuleVersion,'Startup splash did not register the plugin name and shared version');
    RegisterPluginSplash;
    AssertTrue(RegisteredSplashCaption='XmlDocPlugin '+GetModuleVersion,'Repeated splash registration changed its caption');
    for var IconSize in [24,48,96] do begin
     var IconStream:=TResourceStream.Create(FindClassHInstance(TDocInspectorForm),'XMLDOC_SPLASH_'+IconSize.ToString,RT_RCDATA);
     var IconImage:=TPngImage.Create;
     try IconImage.LoadFromStream(IconStream);AssertTrue((IconImage.Width=IconSize) and (IconImage.Height=IconSize),'Splash icon resource has the wrong DPI size');finally IconImage.Free;IconStream.Free;end;
    end;
    Log('PASS IDE splash registration, shared version and 24/48/96 pixel icons');
    var About:=TAboutDialog.Create(nil);
    try AssertTrue(About.lblVersion.Caption=TI18n.Instance.T('Version')+' '+GetEnvironmentVariable('XMLDOC_E2E_VERSION'),'About dialog version mismatch');finally About.Free;end;
    Log('PASS loaded BPL and About dialog shared version');
    var HintCss:=HelpInsightCssPath;
    var HintOriginal:=TFile.ReadAllBytes(HintCss);
    var HintTemplates:TArray<string>:=[ChangeFileExt(HintCss,'.xsl'),IDEHelpInsightXsltPath];
    var HintTemplateBytes:TArray<TBytes>;SetLength(HintTemplateBytes,Length(HintTemplates));
    var HintTemplateBackups:TArray<TBytes>;SetLength(HintTemplateBackups,Length(HintTemplates));
    var HintTemplateHadBackup:TArray<Boolean>;SetLength(HintTemplateHadBackup,Length(HintTemplates));
    for var Index:=0 to High(HintTemplates) do begin
     HintTemplateBytes[Index]:=TFile.ReadAllBytes(HintTemplates[Index]);
     HintTemplateHadBackup[Index]:=TFile.Exists(HintTemplates[Index]+'.xmldocplugin.bak');
     if HintTemplateHadBackup[Index] then HintTemplateBackups[Index]:=TFile.ReadAllBytes(HintTemplates[Index]+'.xmldocplugin.bak');
    end;
    var HintBackup:=HintCss+'.xmldocplugin.bak';
    var HintHadBackup:=TFile.Exists(HintBackup);
    var HintBackupBytes:TBytes;if HintHadBackup then HintBackupBytes:=TFile.ReadAllBytes(HintBackup);
    var OriginalThemeSettings:=TPluginSettings.Instance.Global;
    var OldThemeDirectory:=TThemeEngine.Instance.CustomThemesDir;
    TThemeEngine.Instance.SetCustomThemesDir(TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_LOG')),'created-themes'));
    var OptionsApplied:=0;
    var OptionsProvider:=CreatePluginOptions(procedure begin Inc(OptionsApplied);end);
    AssertTrue((OptionsProvider.GetArea='') and (OptionsProvider.GetCaption='XmlDocPlugin') and OptionsProvider.IncludeInIDEInsight,'Options page is not under Third Party');
    var OptionsHost:=TForm.CreateNew(nil);
    try
     var OptionsFrame:=TPluginOptionsFrame.Create(OptionsHost);OptionsFrame.Parent:=OptionsHost;
     OptionsProvider.FrameCreated(OptionsFrame);
     OptionsFrame.Settings.PageControl.ActivePage:=OptionsFrame.Settings.tsCodeGen;
     OptionsHost.Show;
     for var OptionsPPI in [96,144,192] do begin
      OptionsHost.ScaleForPPI(OptionsPPI);OptionsFrame.ScaleForPPI(OptionsPPI);
      OptionsHost.ClientWidth:=MulDiv(900,OptionsPPI,96);OptionsHost.ClientHeight:=MulDiv(700,OptionsPPI,96);
      var WideField:=OptionsFrame.Settings.edtPlaceholderPrefix.Width;
      OptionsHost.ClientWidth:=MulDiv(650,OptionsPPI,96);
      AssertTrue(OptionsFrame.Settings.edtPlaceholderPrefix.Width<WideField,'Options field did not resize: DPI='+IntToStr(OptionsPPI)+' wide='+IntToStr(WideField)+' narrow='+IntToStr(OptionsFrame.Settings.edtPlaceholderPrefix.Width));
      OptionsHost.ClientWidth:=MulDiv(260,OptionsPPI,96);OptionsHost.ClientHeight:=MulDiv(240,OptionsPPI,96);
      AssertTrue(OptionsFrame.Settings.PageControl.Width>=MulDiv(464,OptionsFrame.CurrentPPI,96),'Narrow options page clips controls instead of scrolling: DPI='+IntToStr(OptionsPPI)+' frame='+IntToStr(OptionsFrame.CurrentPPI)+' width='+IntToStr(OptionsFrame.Settings.PageControl.Width));
     end;
     OptionsFrame.Settings.spnFontSize.Value:=17;
     OptionsProvider.DialogClosed(False);
     AssertTrue((TPluginSettings.Instance.Global.Editor.FontSize=OriginalThemeSettings.Editor.FontSize) and (OptionsApplied=0),'Cancel applied plugin preferences');
     OptionsProvider.FrameCreated(OptionsFrame);
     OptionsFrame.Settings.spnFontSize.Value:=18;
     OptionsFrame.Settings.cmbLanguage.ItemIndex:=OptionsFrame.Settings.cmbLanguage.Items.IndexOf('ru');
     OptionsFrame.Settings.chkCollapseEmptySections.Checked:=False;
     OptionsFrame.Settings.chkShowSignatureHeader.Checked:=False;
     OptionsFrame.Settings.chkAutoGenerate.Checked:=not OriginalThemeSettings.Stub.AutoGenerate;
     OptionsFrame.Settings.edtPlaceholderPrefix.Text:='OPTIONS-TODO:';
     OptionsFrame.Settings.memPlaceholderMarkers.Text:='OPTIONS-TODO:'+sLineBreak+'待补充';
     OptionsFrame.Settings.cmbDocumentationTheme.ItemIndex:=OptionsFrame.Settings.cmbDocumentationTheme.Items.IndexOf('dark');
     OptionsFrame.Settings.spnDebounceMs.Value:=450;OptionsFrame.Settings.spnSaveDebounceMs.Value:=650;
     OptionsFrame.Settings.cmbLogLevel.ItemIndex:=Ord(llDebug);
     OptionsFrame.Settings.hotToggleInspector.HotKey:=0;OptionsFrame.Settings.hotGenerateStub.HotKey:=0;OptionsFrame.Settings.hotGenerateHelp.HotKey:=0;
     OptionsFrame.Settings.hotCoverageReport.HotKey:=0;OptionsFrame.Settings.hotNextUndocumented.HotKey:=0;OptionsFrame.Settings.hotPreviousUndocumented.HotKey:=0;
     OptionsFrame.Settings.chkHelpInsightEnabled.Checked:=True;OptionsFrame.Settings.cmbHintAppearance.ItemIndex:=1;
     OptionsFrame.Settings.chkHelpInsightWrap.Checked:=True;OptionsFrame.Settings.chkHelpInsightCompact.Checked:=True;
     OptionsFrame.Settings.spnHintWidth.Value:=880;OptionsFrame.Settings.spnHintFontSize.Value:=12;
     OptionsFrame.Settings.spnHintLineHeight.Value:=150;OptionsFrame.Settings.spnHintParameterWidth.Value:=230;
     OptionsFrame.Settings.HelpInsightChanged(nil);

     AssertTrue(OptionsProvider.ValidateContents,'Valid Options contents rejected');
     OptionsProvider.DialogClosed(True);
     AssertTrue((TPluginSettings.Instance.Global.Editor.FontSize=18) and (OptionsApplied=1),'Tools Options did not apply settings exactly once');
     var OptionsReload:=TPluginSettings.Create;
     try
      var ReadOptions:=OptionsReload.Global;
      AssertTrue((ReadOptions.General.Language='ru') and (ReadOptions.Editor.FontSize=18) and not ReadOptions.Editor.CollapseEmptySections and not ReadOptions.Editor.ShowSignatureHeader,'General preferences not persisted');
      AssertTrue((ReadOptions.Stub.AutoGenerate<>OriginalThemeSettings.Stub.AutoGenerate) and (ReadOptions.Stub.PlaceholderPrefix='OPTIONS-TODO:') and ReadOptions.Stub.PlaceholderMarkers.Contains('待补充') and (ReadOptions.General.DocumentationTheme='dark'),'Code generation preferences not persisted');
      AssertTrue((ReadOptions.Editor.DebounceMs=450) and (ReadOptions.Editor.SaveDebounceMs=650) and (ReadOptions.General.LogLevel=llDebug) and (TLogger.Instance.Level=llDebug),'Advanced settings not persisted or logging not applied');
      AssertTrue((ReadOptions.Shortcuts.ToggleInspector=0) and (ReadOptions.Shortcuts.GenerateStub=0) and (ReadOptions.Shortcuts.GenerateHelp=0) and (ReadOptions.Shortcuts.CoverageReport=0) and (ReadOptions.Shortcuts.NextUndocumented=0) and (ReadOptions.Shortcuts.PreviousUndocumented=0),'Shortcut settings not persisted');
      AssertTrue(ReadOptions.HelpInsight.Enabled and ReadOptions.HelpInsight.Extended and ReadOptions.HelpInsight.WrapSignature and ReadOptions.HelpInsight.CompactParameters and (ReadOptions.HelpInsight.Width=880) and (ReadOptions.HelpInsight.FontSize=12) and (ReadOptions.HelpInsight.LineHeight=150) and (ReadOptions.HelpInsight.ParameterWidth=230),'Help Insight preferences not persisted');
      AssertTrue(TFile.ReadAllText(HintCss).Contains('width: 880px') and TFile.ReadAllText(HintCss).Contains('font-size: 12pt'),'Embedded Help Insight controls did not update native CSS');
      var ReopenedOptions:=TPluginOptionsFrame.Create(nil);
      try
       AssertTrue((ReopenedOptions.Settings.cmbLanguage.Text='ru') and (ReopenedOptions.Settings.spnFontSize.Value=18) and (ReopenedOptions.Settings.edtPlaceholderPrefix.Text='OPTIONS-TODO:') and (ReopenedOptions.Settings.spnSaveDebounceMs.Value=650) and (ReopenedOptions.Settings.cmbHintAppearance.ItemIndex=1),'Reopened Options controls did not read persisted values');
      finally ReopenedOptions.Free;end;
      Log('PASS embedded Options all preference fields persist, reload and apply native CSS/logging');
     finally OptionsReload.Free;end;
     TPluginSettings.Instance.Global:=OriginalThemeSettings;TPluginSettings.Instance.Save;
     TI18n.Instance.SetLanguage(OriginalThemeSettings.General.Language);

     Log('PASS Third Party Options Apply/Cancel, resizable fields and DPI scrolling');
    finally
     OptionsHost.Free;OptionsProvider:=nil;
     TPluginSettings.Instance.Global:=OriginalThemeSettings;TPluginSettings.Instance.Save;
     TI18n.Instance.SetLanguage(OriginalThemeSettings.General.Language);
     TFile.WriteAllBytes(HintCss,HintOriginal);
     for var Index:=0 to High(HintTemplates) do begin
      TFile.WriteAllBytes(HintTemplates[Index],HintTemplateBytes[Index]);
      if HintTemplateHadBackup[Index] then TFile.WriteAllBytes(HintTemplates[Index]+'.xmldocplugin.bak',HintTemplateBackups[Index])
      else if TFile.Exists(HintTemplates[Index]+'.xmldocplugin.bak') then TFile.Delete(HintTemplates[Index]+'.xmldocplugin.bak');
     end;
     if HintHadBackup then TFile.WriteAllBytes(HintBackup,HintBackupBytes) else if TFile.Exists(HintBackup) then TFile.Delete(HintBackup);
    end;
    var ThemeDialog:=TSettingsDialog.Create(nil);
    for var HintPPI in [96,144,192] do begin
     ThemeDialog.ScaleForPPI(HintPPI);
     AssertTrue(ThemeDialog.btnOK.Top>=ThemeDialog.PageControl.Top+ThemeDialog.PageControl.Height,'Settings footer overlaps pages at DPI '+IntToStr(HintPPI));
     AssertTrue(ThemeDialog.btnHintPreview.Top+ThemeDialog.btnHintPreview.Height<=ThemeDialog.tsHelpInsight.ClientHeight,'Hint preview is clipped at DPI '+IntToStr(HintPPI));
     AssertTrue(ThemeDialog.btnRestoreHint.Left+ThemeDialog.btnRestoreHint.Width<=ThemeDialog.tsHelpInsight.ClientWidth,'Hint restore is clipped at DPI '+IntToStr(HintPPI));
    end;
    ThemeDialog.ScaleForPPI(96);
    try
      for var ThemeName in ['default','dark','high-contrast','minimal'] do
        AssertTrue(ThemeDialog.cmbDocumentationTheme.Items.IndexOf(ThemeName)>=0,'Settings theme option missing: '+ThemeName);
      ThemeDialog.cmbDocumentationTheme.ItemIndex:=ThemeDialog.cmbDocumentationTheme.Items.IndexOf('dark');
      var ThemeInputTimer:=TTimer.Create(nil);
      try
        ThemeInputTimer.Interval:=100;ThemeInputTimer.OnTimer:=CloseExportMessage;
        ThemeDialog.btnCreateTheme.Click;
      finally ThemeInputTimer.Free;end;
      AssertTrue(ThemeDialog.cmbDocumentationTheme.Text='e2e-created','Create CSS theme did not select the new theme');
      AssertTrue(TFile.ReadAllText(TPath.Combine(TThemeEngine.Instance.CustomThemesDir,'e2e-created.css')).Contains('#1e1e2e'),'Created CSS did not inherit the selected dark palette');
      ThemeDialog.hotToggleInspector.HotKey:=0;ThemeDialog.hotGenerateStub.HotKey:=0;ThemeDialog.hotGenerateHelp.HotKey:=0;
      ThemeDialog.hotCoverageReport.HotKey:=0;ThemeDialog.hotNextUndocumented.HotKey:=0;ThemeDialog.hotPreviousUndocumented.HotKey:=0;
      ThemeDialog.btnOKClick(nil);
      var ThemeReader:=TPluginSettings.Create;
      try AssertTrue(ThemeReader.Global.General.DocumentationTheme='e2e-created','Settings did not persist the selected documentation theme');finally ThemeReader.Free;end;
      var ReopenedThemeDialog:=TSettingsDialog.Create(nil);
      try AssertTrue(ReopenedThemeDialog.cmbDocumentationTheme.Text='e2e-created','Reopened Settings lost the theme selection');finally ReopenedThemeDialog.Free;end;
      Log('PASS native Settings CSS creation, theme selection, save and reopen');
      AssertTrue(SameText(HintCss,TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),'..\ObjRepos\HelpInsight.css'))),'Help Insight belongs to another IDE');
      ThemeDialog.chkHelpInsightEnabled.Checked:=True;ThemeDialog.cmbHintAppearance.ItemIndex:=1;ThemeDialog.HelpInsightChanged(nil);
      AssertTrue(ThemeDialog.spnHintWidth.Enabled and ThemeDialog.spnHintFontSize.Enabled,'Help Insight settings unavailable');
      ThemeDialog.spnHintWidth.Value:=940;ThemeDialog.spnHintFontSize.Value:=11;ThemeDialog.spnHintLineHeight.Value:=140;ThemeDialog.spnHintParameterWidth.Value:=220;
      ThemeDialog.chkHelpInsightWrap.Checked:=True;ThemeDialog.chkHelpInsightCompact.Checked:=True;ThemeDialog.HelpInsightChanged(nil);ThemeDialog.btnOKClick(nil);
      AssertTrue(TFile.ReadAllText(HintCss).Contains('width: 940px') and TFile.ReadAllText(HintCss).Contains('font-size: 11pt'),'Help Insight CSS not applied');
      var HintReader:=TSettingsDialog.Create(nil);try
       AssertTrue(HintReader.chkHelpInsightEnabled.Checked and (HintReader.cmbHintAppearance.ItemIndex=1) and (HintReader.spnHintWidth.Value=940) and (HintReader.spnHintParameterWidth.Value=220),'Help Insight settings not reloaded');
       HintReader.chkHelpInsightEnabled.Checked:=False;HintReader.HelpInsightChanged(nil);
       AssertTrue(not HintReader.spnHintWidth.Enabled,'Disabled Help Insight controls stayed enabled');HintReader.btnOKClick(nil);
       AssertTrue(not TFile.ReadAllText(HintCss).Contains('/* XmlDocPlugin Help Insight: begin */'),'Help Insight disable left overrides');
      finally HintReader.Free;end;
      Log('PASS native Help Insight settings apply, reopen and disable in the running IDE');
    finally
      TFile.WriteAllBytes(HintCss,HintOriginal);
      for var Index:=0 to High(HintTemplates) do begin
       TFile.WriteAllBytes(HintTemplates[Index],HintTemplateBytes[Index]);
       if HintTemplateHadBackup[Index] then TFile.WriteAllBytes(HintTemplates[Index]+'.xmldocplugin.bak',HintTemplateBackups[Index])
       else if TFile.Exists(HintTemplates[Index]+'.xmldocplugin.bak') then TFile.Delete(HintTemplates[Index]+'.xmldocplugin.bak');
      end;
      if HintHadBackup then TFile.WriteAllBytes(HintBackup,HintBackupBytes) else if TFile.Exists(HintBackup) then TFile.Delete(HintBackup);
      ThemeDialog.Free;TPluginSettings.Instance.Global:=OriginalThemeSettings;TPluginSettings.Instance.Save;
      TThemeEngine.Instance.SetCustomThemesDir(OldThemeDirectory);
    end;

    Root:=GetEnvironmentVariable('XMLDOC_E2E_FIXTURE');SampleFile:=TPath.Combine(Root,'Units\Workbench.Sample.pas');SecondFile:=TPath.Combine(Root,'Units\Workbench.Second.pas');
    var Settings:=TPluginSettings.Create;
    var SettingsRoot:=TPath.Combine(Root,'settings-fixture');TDirectory.CreateDirectory(SettingsRoot);
    try
     TFile.WriteAllText(TPath.Combine(SettingsRoot,'.xmldocplugin.json'),'{"helpGen":{"outputDir":"project-a","includePrivate":true}}');Settings.LoadProject(SettingsRoot);
     AssertTrue(Settings.Project.HelpGen.OutputDir='project-a','Project A options were not loaded');
     Settings.LoadProject(Root);AssertTrue((Settings.Project.HelpGen.OutputDir='docs') and not Settings.Project.HelpGen.IncludePrivate,'Project A options leaked into B');
     TFile.WriteAllText(TPath.Combine(SettingsRoot,'.xmldocplugin.json'),'{"helpGen":{"title":"Partial"}}');Settings.LoadProject(SettingsRoot);
     AssertTrue((Settings.Project.HelpGen.OutputDir='docs') and (Settings.Project.HelpGen.Title='Partial'),'Partial settings did not use defaults');
     var UnicodeAuthoring:='Термины 中文 용어 用語';
     TFile.WriteAllBytes(TPath.Combine(SettingsRoot,'.xmldocplugin.json'),TEncoding.UTF8.GetBytes('{"authoring":{"terminology":"'+UnicodeAuthoring+'"}}'));
     Settings.LoadProject(SettingsRoot);Settings.SaveProject;
     var PreservedSettings:=TJSONObject.ParseJSONValue(TFile.ReadAllText(TPath.Combine(SettingsRoot,'.xmldocplugin.json'),TEncoding.UTF8));
     try AssertTrue(Assigned(PreservedSettings) and (PreservedSettings.GetValue<string>('authoring.terminology')=UnicodeAuthoring),'Project settings corrupted BOM-free UTF-8 authoring data');finally PreservedSettings.Free;end;
     Log('PASS project settings preserve BOM-free UTF-8 authoring data');
     Log('PASS project settings reset between projects and partial files');
    finally Settings.Free;TDirectory.Delete(SettingsRoot,True);end;
    AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(TPath.Combine(Root,'XmlDocE2E.dproj')),'Cannot open E2E project');Inc(Step);end;
  1:begin if (GetEnvironmentVariable('XMLDOC_E2E_AI_ONLY')='1') or (GetEnvironmentVariable('XMLDOC_E2E_MARKER_PHASE')<>'') or (StrToIntDef(GetEnvironmentVariable('XMLDOC_E2E_BENCHMARK_MODULES'),0)>0) or (GetEnvironmentVariable('XMLDOC_E2E_DIAGNOSTICS_ONLY')='1') then begin OpenDocumentationPanels;Inc(Step);Timer.Enabled:=True;Exit;end;ExportAll;if GetEnvironmentVariable('XMLDOC_E2E_THEMES_ONLY')='1' then begin Log('PASS');Finish;Exit;end;OpenDocumentationPanels;AssertErrorLabelTheme(Inspector);AssertErrorLabelTheme(Explorer);Inc(Step);end;
  2:begin
    for I:=0 to Inspector.ComponentCount-1 do if Inspector.Components[I] is TXmlDocBrowser then Browser:=TXmlDocBrowser(Inspector.Components[I]);
    AssertTrue(Assigned(Browser),'Browser unavailable');
    for I:=0 to Inspector.ComponentCount-1 do if Inspector.Components[I] is TTimer then TTimer(Inspector.Components[I]).Enabled:=False;
    for I:=0 to Explorer.ComponentCount-1 do begin
      if Explorer.Components[I] is TXmlDocBrowser then ExplorerBrowser:=TXmlDocBrowser(Explorer.Components[I]);
      if Explorer.Components[I] is TTimer then TTimer(Explorer.Components[I]).Enabled:=False;
    end;
    AssertTrue(Assigned(ExplorerBrowser),'Explorer browser unavailable');OriginalExplorerMessage:=ExplorerBrowser.OnWebMessageReceived;ExplorerBrowser.OnWebMessageReceived:=ExplorerMessage;
    OriginalMessage:=Browser.OnWebMessageReceived;Browser.OnWebMessageReceived:=MessageReceived;
    (BorlandIDEServices as IOTAActionServices).OpenFile(SecondFile);SecondInitial:=EditorSource(SourceEditorForFile(SecondFile));
    Select(SampleFile,'Run','string');Initial:=EditorSource(SourceEditorForFile(SampleFile));Log('Resource map: '+Browser.ResourceStatus);AssertTrue(Initial.Contains('Пример'),'Unicode was lost while reading the editor buffer');Inc(Step);end;
  3:begin
   if GetEnvironmentVariable('XMLDOC_E2E_AI_ONLY')='1' then begin Browser.ExecuteScript('window.__sharedOnly='+LowerCase(BoolToStr(GetEnvironmentVariable('XMLDOC_E2E_SHARED_ONLY')='1',True))+';'+TFile.ReadAllText(TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_JS')),'SharedContextProbe.js'),TEncoding.UTF8));Browser.ExecuteScript(TFile.ReadAllText(TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_JS')),IfThen(GetEnvironmentVariable('XMLDOC_E2E_REAL_AI')='1',IfThen(GetEnvironmentVariable('XMLDOC_E2E_LIVE_REVIEW')='1','LiveReviewProbe.js','RealAIAssistantProbe.js'),'AIAssistantProbe.js')),TEncoding.UTF8));Inc(Step);Exit;end;
   if GetEnvironmentVariable('XMLDOC_E2E_SHUTDOWN_OPEN_PANELS')='1' then begin
    var ShutdownEditor:=SourceEditorForFile(SampleFile);
    ReplaceSourceBuffer(ShutdownEditor,EditorSource(ShutdownEditor)+sLineBreak+'// E2E unsaved source at IDE shutdown');
    Log('PASS unsaved source buffer before open-panel shutdown');
    Browser.ExecuteScript('(()=>{const send=(action,message)=>window.chrome.webview.postMessage(JSON.stringify({type:"e2e",action,message}));'+
     'if(!window.xmlDocEditor||!document.querySelector("#workbench"))send("fail","Editor is not ready for shutdown");else send("finish");})()');
    Inc(Step);Exit;
   end;
   if GetEnvironmentVariable('XMLDOC_E2E_DIAGNOSTICS_ONLY')='1' then begin
   // A successful parse must not clear a browser failure. Inject the event only
   // after the real WebView has loaded; recover through its navigation callback.
   if Assigned(Browser.OnCreateWebViewCompleted) and Assigned(ExplorerBrowser.OnCreateWebViewCompleted) then begin
    Browser.OnCreateWebViewCompleted(Browser,E_FAIL);ExplorerBrowser.OnCreateWebViewCompleted(ExplorerBrowser,E_FAIL);
    Inspector.HandleCursorChanged(1,EditorSource(SourceEditorForFile(SampleFile)),SampleFile);
    Explorer.HandleFileChanged(SampleFile,EditorSource(SourceEditorForFile(SampleFile)));
    for var Panel in [TForm(Inspector),TForm(Explorer)] do begin
     var ErrorVisible:=False;for var N:=0 to Panel.ComponentCount-1 do if (Panel.Components[N] is TMemo) and (Panel.Components[N].Name='DocumentationError') then ErrorVisible:=TMemo(Panel.Components[N]).Visible and string(TMemo(Panel.Components[N]).Text).Contains('WebView2 could not start');
     AssertTrue(ErrorVisible,'Successful source parsing hid the browser initialization error');
    end;
    AssertTrue(not Browser.Visible and not ExplorerBrowser.Visible,'Failed browser was shown as ready');
    Browser.OnNavigationCompleted(Browser,True,Default(COREWEBVIEW2_WEB_ERROR_STATUS));ExplorerBrowser.OnNavigationCompleted(ExplorerBrowser,True,Default(COREWEBVIEW2_WEB_ERROR_STATUS));
    AssertTrue(Browser.Visible and ExplorerBrowser.Visible,'Successful browser recovery did not restore the editor');
    Log('PASS independent parser/browser diagnostics and browser recovery');
   end;
    Browser.ExecuteScript(TFile.ReadAllText(TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_JS')),'ParseRecoveryProbe.js'),TEncoding.UTF8));Inc(Step);Exit;
   end;
   if StrToIntDef(GetEnvironmentVariable('XMLDOC_E2E_BENCHMARK_MODULES'),0)>0 then begin Step:=104;Timer.Enabled:=True;Exit;end;Inc(Step);Select(SampleFile,'Run','string');if GetEnvironmentVariable('XMLDOC_E2E_SCREENSHOTS')<>'' then begin Inspector.SetBounds(100,100,1120,1000);Explorer.SetBounds(100,100,1400,1000);Browser.ExecuteScript('window.__guideScreenshots=true;');end;if GetEnvironmentVariable('XMLDOC_E2E_GROUP_ONLY')='1' then Browser.ExecuteScript('window.chrome.webview.postMessage(JSON.stringify({type:"e2e",action:"prepare-group"}));') else Browser.ExecuteScript(TFile.ReadAllText(GetEnvironmentVariable('XMLDOC_E2E_JS'),TEncoding.UTF8));end;
 end;
 if Step<4 then Timer.Enabled:=True;
 except on E:Exception do begin Log('FAIL '+E.Message);if GetEnvironmentVariable('XMLDOC_E2E_KEEP_FAILURE')<>'1' then ExitProcess(1);end;end;
end;
procedure Register;
begin if Assigned(Probe) then Exit;Probe:=TProbe.Create(nil);Probe.Timer:=TTimer.Create(nil);Probe.Timer.Interval:=2500;Probe.Timer.OnTimer:=Probe.Tick;end;
initialization
finalization
 Log('Finalizing probe');
 if Probe<>nil then begin
  Log('Finalizing probe timer');FreeAndNil(Probe.Timer);
  Log('Finalizing publication probe');FreeAndNil(Probe.ValidationProbe);
  Log('Finalizing format confirmation');FreeAndNil(Probe.FormatConfirmation);
  Log('Finalizing probe Inspector');
  if GetEnvironmentVariable('XMLDOC_E2E_SHUTDOWN_OPEN_PANELS')='1' then begin
   if Assigned(Probe.Browser) then Probe.Browser.OnWebMessageReceived:=Probe.OriginalMessage;
   Probe.Inspector:=nil;Probe.Browser:=nil;
  end else FreeAndNil(Probe.Inspector);
  Log('Finalizing probe Explorer');
  if GetEnvironmentVariable('XMLDOC_E2E_SHUTDOWN_OPEN_PANELS')='1' then begin
   if Assigned(Probe.ExplorerBrowser) then Probe.ExplorerBrowser.OnWebMessageReceived:=Probe.OriginalExplorerMessage;
   Probe.Explorer:=nil;Probe.ExplorerBrowser:=nil;
  end else FreeAndNil(Probe.Explorer);
  Log('Finalizing probe object');FreeAndNil(Probe);
 end;
 Log('Probe finalized');
end.
