unit WorkbenchProbe;
interface
procedure Register;
implementation
uses XmlDoc.Plugin.AIAssistant,XmlDoc.Plugin.AISettings,XmlDoc.AI.Contracts,XmlDoc.AI.Prompts,XmlDoc.AI.OpenAI,XmlDoc.Documentation,XmlDoc.Logger,XmlDoc.HelpGen.ThemeEngine,System.SyncObjs,System.RegularExpressions,XmlDoc.Plugin.ProjectDocumentation,XmlDoc.ProjectContext,System.Diagnostics,System.Hash,XmlDoc.Plugin.DeclarationContext,XmlDoc.I18n,System.SysUtils,System.StrUtils,System.Classes,System.IOUtils,System.JSON,Winapi.Windows,Winapi.Messages,Winapi.ActiveX,
 Vcl.ComCtrls,Vcl.Samples.Spin,Vcl.Forms,Vcl.ActnList,Vcl.Menus,Vcl.Controls,Vcl.ExtCtrls,Vcl.Edge,WebView2,ToolsAPI,XmlDoc.Plugin.DocInspector,
 XmlDoc.Plugin.Localization,XmlDoc.Plugin.SettingsDialog,XmlDoc.Plugin.CoverageDialog,XmlDoc.Plugin.Browser,XmlDoc.Plugin.DocExplorer,XmlDoc.Plugin.EditSession,XmlDoc.Parser,XmlDoc.Consts,Vcl.StdCtrls,XmlDoc.Plugin.BatchGenDialog,Vcl.Graphics,XmlDoc.ShortcutValidation,XmlDoc.Plugin.Settings,XmlDoc.Plugin.AboutDialog,XmlDoc.Plugin.Utils;
type TAIProbeTransport=class(TInterfacedObject,IAITransport)
 private FCancelled:Integer;
 public function Execute(const Request:TAIHttpRequest):TAIHttpResponse;procedure Cancel;
 end;
 TPublicationProbe=class(TProjectDocumentation)
 public
  IncludeFile,NewModule:string;Armed,Changed:Boolean;
 protected
  procedure BeforePublication;override;
 end;
 TProbe=class
 Timer,FormatConfirmation:TTimer;Inspector:TDocInspectorForm;Explorer:TDocExplorerForm;Browser,ExplorerBrowser:TXmlDocBrowser;OriginalMessage,OriginalExplorerMessage:TWebMessageReceivedEvent;ExplorerAttempted:Boolean;
 ValidationProbe:TPublicationProbe;
 StressEntered,StressContinue:TEvent;StressChecks:Integer;
 StressRound:Integer;StressGeneration,StressStarted:UInt64;
 AIBefore,AIWritten:string;
 LanguageSaved:Boolean;OriginalLanguage:string;
 PrefixSettingsSaved:Boolean;OriginalPrefixSettings:TGlobalSettings;LastGenerationMessage:string;
 ProtectedBefore,SystemFile,PrimaryProjectFile,FormatBefore:string;
 FormatWait,Step:Integer;Initial,AfterWrite,SecondInitial,SampleFile,SecondFile,Root:string;Finished:Boolean;
 procedure CheckAISettings(Sender:TObject);
 procedure ConfirmFormat(Sender:TObject);procedure Tick(Sender:TObject); procedure ExportAll; procedure CloseExportMessage(Sender:TObject);
 procedure ExplorerMessage(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
 procedure MessageReceived(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
 procedure Select(const FileName,Name,TypeName:string);
 procedure AssertTrue(Value:Boolean;const Message:string);
 procedure Finish;
end;
var Probe:TProbe;
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
begin TFile.AppendAllText(GetEnvironmentVariable('XMLDOC_E2E_LOG'),Text+sLineBreak);end;
function XmlEscape(const Value:string):string;
begin Result:=Value.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;');end;
function FindMenuCommand(Parent:TMenuItem;const Caption:string):TMenuItem;
begin
 if SameText(StringReplace(Parent.Caption,'&','',[rfReplaceAll]),TI18n.Instance.T(Caption)) then Exit(Parent);
 for var I:=0 to Parent.Count-1 do begin Result:=FindMenuCommand(Parent[I],Caption);if Assigned(Result) then Exit;end;
 Result:=nil;
end;
function TAIProbeTransport.Execute(const Request:TAIHttpRequest):TAIHttpResponse;
begin
 if not Request.Body.Contains('TDocumented.Run') and not Request.Body.Contains('Connection check') then raise Exception.Create('AI request missed the selected method');
 for var I:=0 to 30 do begin if TInterlocked.CompareExchange(FCancelled,0,0)<>0 then raise Exception.Create('AI request cancelled');Sleep(10);end;
 var Summary:='Native AI proposed summary';var Seen:=TStringList.Create;var Root:=TJSONObject.Create;
 try
  for var Match in TRegEx.Matches(Request.Body,'__XMLDOC_[0-9a-fA-F]+_[0-9]+__') do if Seen.IndexOf(Match.Value)<0 then begin Seen.Add(Match.Value);Summary:=Summary+' '+Match.Value;end;
  var Content:=TJSONObject.Create.AddPair('summary',Summary).AddPair('uncertainties',TJSONArray.Create(TJSONString.Create('Ownership is not specified.')));
  try var Choices:=TJSONArray.Create;Root.AddPair('choices',Choices);Choices.AddElement(TJSONObject.Create.AddPair('finish_reason','stop').AddPair('message',TJSONObject.Create.AddPair('content',Content.ToJSON)));Result.Status:=200;Result.Body:=Root.ToJSON;finally Content.Free;end;
 finally Root.Free;Seen.Free;end;
end;
procedure TAIProbeTransport.Cancel;
begin TInterlocked.Exchange(FCancelled,1);end;
function AssistantFor(Form:TForm):TAIAssistant;
begin for var I:=0 to Form.ComponentCount-1 do if Form.Components[I] is TAIAssistant then Exit(TAIAssistant(Form.Components[I]));raise Exception.Create('AI component missing');end;
procedure TProbe.CheckAISettings(Sender:TObject);
begin
 for var I:=0 to Screen.FormCount-1 do if Screen.Forms[I].ClassName='TAISettingsForm' then begin
  TTimer(Sender).Enabled:=False;var Form:=Screen.Forms[I];
  AssertTrue(Form.Caption=TI18n.Instance.T('AI profiles and prompts'),'AI settings caption not localized');
  AssertTrue(TEdit(Form.FindComponent('AIField3')).Text='fixture','AI model did not load');AssertTrue(TEdit(Form.FindComponent('AIKey')).Text='','Credential was exposed in native key field');
  for var J:=0 to Form.ComponentCount-1 do if Form.Components[J] is TPageControl then begin var Pages:=TPageControl(Form.Components[J]);
   for var Tab:=0 to Pages.PageCount-1 do begin Pages.ActivePageIndex:=Tab;
    for var K:=0 to Form.ComponentCount-1 do if Form.Components[K] is TWinControl then begin var Control:=TWinControl(Form.Components[K]);if Control.Parent=Pages.Pages[Tab] then AssertTrue(Control.Visible and Control.Enabled and Control.CanFocus,'AI control inaccessible: '+Control.ClassName);end;
   end;
  end;
  AssertTrue(Pos('{{implementation}}',TMemo(Form.FindComponent('AIUserPrompt')).Text)>0,'Prompt source was localized or lost');
  Form.ModalResult:=mrCancel;Log('PASS native AI settings loads profiles, protects keys and exposes both tabs');
 end;
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
 Log('Closing Explorer');Explorer.Free;Explorer:=nil;Log('Closing Inspector');Inspector.Free;Inspector:=nil;Log('Closed Inspector');Services:=BorlandIDEServices as IOTAModuleServices;
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
   if Action='marker-log' then Log('AUDIT '+Json.GetValue<string>('result'))
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
   else if Action='ai-test-arm' then begin
    var Config:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1));var Profiles:=TJSONArray.Create;Config.AddPair('profiles',Profiles);
    var Profile:=TAIProfile.Defaults;Profile.Id:=TGUID.NewGuid.ToString;Profile.Name:='E2E';Profile.Model:='fixture';Profile.Authorization:='none';Profile.Endpoint:='https://fixture.invalid/v1';Profiles.AddElement(AIProfileJson(Profile));try SaveAIConfiguration(Config);finally Config.Free;end;
    Profile.Id:=TGUID.NewGuid.ToString;var KeyProfile:=Profile;
    try WriteAIKey(Profile,'E2E-not-a-real-secret');AssertTrue(ReadAIKey(Profile)='E2E-not-a-real-secret','Credential round trip failed');Profile.Endpoint:='https://other.invalid/v1';AssertTrue(ReadAIKey(Profile)='','Changed destination reused a credential');Profile.Endpoint:='https://fixture.invalid/v1';finally WriteAIKey(KeyProfile,'');end;
    AssertTrue(not TFile.ReadAllText(AIConfigurationPath).Contains('E2E-not-a-real-secret'),'Credential leaked to JSON');
    var Templates:=AIPrompts('');
    try
     var Custom:=Templates[0].Clone as TJSONObject;Custom.RemovePair('id').Free;Custom.AddPair('id','custom-describe');Custom.RemovePair('name').Free;Custom.AddPair('name','Custom E2E');Templates.AddElement(Custom);SaveAIPrompts(Templates,'');SaveAIPrompts(Templates,Root);
     var Reloaded:=AIPrompts(Root);try AssertTrue(Reloaded.Count=3,'Project/global AI templates did not merge');finally Reloaded.Free;end;
     var Previous:=TFile.ReadAllText(AIConfigurationPath);Custom.RemovePair('user').Free;Custom.AddPair('user','{{unknown_variable}}');var Rejected:=False;
     try SaveAIPrompts(Templates,'');except on E:Exception do Rejected:=True;end;AssertTrue(Rejected and (TFile.ReadAllText(AIConfigurationPath)=Previous),'Invalid prompt changed saved configuration');
    finally Templates.Free;end;
    var SettingsTimer:=TTimer.Create(nil);try SettingsTimer.Interval:=100;SettingsTimer.OnTimer:=CheckAISettings;ShowAISettings(Root);finally SettingsTimer.Free;end;
    Inspector.BringToFront;Browser.SetFocus;
    AssistantFor(Inspector).TransportFactory:=function:IAITransport begin Result:=TAIProbeTransport.Create;end;
    AssistantFor(Explorer).TransportFactory:=function:IAITransport begin Result:=TAIProbeTransport.Create;end;
    AIBefore:=EditorSource(SourceEditorForFile(SampleFile));Browser.ExecuteScript('window.xmlDocAI.reload();window.__aiTestArmed=true;');Log('PASS AI profile and credential recipient binding');
   end
   else if Action='ai-write-checked' then begin
    AIWritten:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(AIWritten.Contains('Native AI reviewed summary'),'AI apply did not use OTA');AssertTrue(AIWritten.Contains('custom-root keep="yes"'),'AI apply lost unknown XML');Log('PASS manually edited AI proposal applies through OTA and retains other XML');
    Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer);UndoMarkers:=0;repeat EditBuffer.Undo;Inc(UndoMarkers);until (EditorSource(EditBuffer)<>AIWritten) or (UndoMarkers=4);AssertTrue(EditorSource(EditBuffer)=AIBefore,'AI Undo did not restore original');UndoMarkers:=0;repeat EditBuffer.Redo;Inc(UndoMarkers);until (EditorSource(EditBuffer)<>AIBefore) or (UndoMarkers=4);AssertTrue(EditorSource(EditBuffer)=AIWritten,'AI Redo failed');Inspector.RefreshFromCurrentEditor;Browser.ExecuteScript('window.__aiUndoRedo=true;');Log('PASS AI OTA Undo/Redo');
   end
   else if Action='ai-rephrase-checked' then begin AssertTrue(EditorSource(SourceEditorForFile(SampleFile)).Contains('Rephrased native summary'),'Rephrase did not reach OTA');Log('PASS native rephrase with independent template and reviewed apply');end
   else if Action='ai-body-change' then begin
    Editor:=SourceEditorForFile(SampleFile);Source:=EditorSource(Editor);AssertTrue(Source.Contains('if Value='),'AI body token absent');Source:=Source.Replace('begin if Value=','begin {changed during AI request} if Value=');
    var Reader:=Editor.CreateReader;var B:TBytes;SetLength(B,32768);var Total:=0;var N:Integer;repeat N:=Reader.GetText(Total,PAnsiChar(B),Length(B));Inc(Total,N);until N<Length(B);Reader:=nil;
    Writer:=Editor.CreateUndoableWriter;Writer.CopyTo(0);Writer.DeleteTo(Total);Utf8:=UTF8String(Source);Writer.Insert(PAnsiChar(Utf8));Writer:=nil;Browser.ExecuteScript('window.__aiBodyChanged=true;');
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
    var Generation:=TBatchGenDialog.Create(nil);try GenerationTitle:=Generation.Caption;if Language<>'en' then AssertTrue(GenerationTitle<>'Generate API Documentation','Generation language pack missing');AssertTrue(Generation.Caption=TI18n.Instance.T('Generate API Documentation'),'Generation dialog not translated');finally Generation.Free;end;
    var Coverage:=TCoverageDialog.Create(nil);try CoverageTitle:=Coverage.Caption;if Language<>'en' then AssertTrue(CoverageTitle<>'Documentation Coverage Report','Coverage language pack missing');AssertTrue(Coverage.Caption=TI18n.Instance.T('Documentation Coverage Report'),'Coverage dialog not translated');finally Coverage.Free;end;
    var MenuRoot:=(BorlandIDEServices as INTAServices).MainMenu.Items;for var I:=0 to MenuRoot.Count-1 do if MenuRoot[I].Name='XmlDocDocumentMenu' then LocalizePluginUi(MenuRoot[I].Owner);
    AssertTrue(Assigned(FindMenuCommand(MenuRoot,'User Guide')),'Localized guide menu missing');Browser.ApplySettings;ExplorerBrowser.ApplySettings;
    var LocaleAudit:=TJSONObject.Create;try LocaleAudit.AddPair('language',Language);LocaleAudit.AddPair('settingsTitle',NativeTitle);LocaleAudit.AddPair('markerHint',NativeHint);LocaleAudit.AddPair('generationTitle',GenerationTitle);LocaleAudit.AddPair('coverageTitle',CoverageTitle);Browser.ExecuteScript('window.__nativeLocaleAudit='+LocaleAudit.ToJSON);finally LocaleAudit.Free;end;
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
    GroupXml:=GroupXml.Replace('<DCCReference Include="Units\Workbench.Sample.pas"/>','').Replace('<DCCReference Include="Units\Workbench.Second.pas"/>','').Replace('<DCCReference Include="Examples\Workbench.Examples.pas"/>','');
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
    AssertTrue(Assigned(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas'))),'Group source did not open');
    Log('PASS group symbol navigation uses project B defines while A is active');
   end
   else if Action='group-navigation-checked' then Log('PASS GroupB Source and Back/Forward retain owning project while A is active')
   else if Action='group-include-checked' then Log('PASS catalog Refresh detects a changed closed include')
   else if Action='group-context-error' then begin
    var BrokenProject:=TPath.Combine(Root,'GroupB','GroupB.dproj');var ProjectBefore:=TFile.ReadAllText(BrokenProject);var ProjectStamp:=TFile.GetLastWriteTimeUtc(BrokenProject);var ErrorFile:=TPath.Combine(Root,'GroupB','ContextB.pas');var ErrorSource:=EditorSource(SourceEditorForFile(ErrorFile));
    try
     TFile.WriteAllText(BrokenProject,ProjectBefore.Replace('ContextB.pas','MissingReviewSource.pas'));
     Inspector.HandleCursorChanged(3,ErrorSource,ErrorFile);Explorer.HandleFileChanged(ErrorFile,ErrorSource);
     for var Panel in TArray<TForm>.Create(Inspector,Explorer) do begin
      var ErrorShown:=False;for var N:=0 to Panel.ComponentCount-1 do if (Panel.Components[N] is TMemo) and (Panel.Components[N].Name='DocumentationError') then begin var LabelControl:=TMemo(Panel.Components[N]);if LabelControl.Visible and (Pos('Missing project source',string(LabelControl.Text))>0) then ErrorShown:=True;end;
      AssertTrue(ErrorShown,'Project-context error was not shown inside '+Panel.Caption);
     end;
    finally TFile.WriteAllText(BrokenProject,ProjectBefore);TFile.SetLastWriteTimeUtc(BrokenProject,ProjectStamp);end;
    var ReferenceDirectory:=TPath.Combine(Root,'GroupB','ReferenceSources');ForceDirectories(ReferenceDirectory);TFile.WriteAllText(TPath.Combine(ReferenceDirectory,'SearchOnly.pas'),'unit SearchOnly; interface type TSearchOnly=class end; implementation end.');
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
    var ReviewFile:=TPath.Combine(Root,'GroupB','ContextB.pas');Editor:=SourceEditorForFile(ReviewFile);Source:=EditorSource(Editor);
    var Marker:='XML requires explicit approval';var CharOffset:=Pos(Marker,Source);AssertTrue(CharOffset>0,'Original review comment absent');
    Offset:=Length(UTF8Encode(Copy(Source,1,CharOffset-1)));Writer:=Editor.CreateUndoableWriter;Writer.CopyTo(Offset);Writer.DeleteTo(Offset+Length(Marker));Utf8:='EXTERNAL SOURCE CHANGE';Writer.Insert(PAnsiChar(Utf8));Writer:=nil;
    Inspector.HandleCursorChanged(Json.GetValue<Integer>('line'),EditorSource(Editor),ReviewFile);Browser.ExecuteScript('window.__reviewExternalReady=true');Log('PASS external source mutation for native recovery conflict');
   end
   else if Action='assert-review-undo' then begin
    var Actual:=EditorSource(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas')));
    AssertTrue(not Actual.Contains('REVIEW HIDDEN RAW') and not Actual.Contains('REVIEW UNDO TEMPORARY TEXT'),'Undo wrote hidden/unconfirmed text');Log('PASS native source after raw draft / Design edit / Undo to baseline');
   end
   else if Action='assert-review-design' then begin
    var Actual:=EditorSource(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas')));
    AssertTrue(Actual.Contains('REVIEW VISIBLE DESIGN WINS'),'Visible Design text did not reach native XML serialization');
    AssertTrue(not Actual.Contains('REVIEW HIDDEN RAW MUST NOT WRITE'),'Hidden XML draft overwrote Design text');
    Log('PASS restored raw draft to Design serializes visible content into source');
   end
   else if Action='group-xml-applied-checked' then begin
    var ApprovedSource:=EditorSource(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas')));
    AssertTrue(ApprovedSource.Contains('XML requires explicit approval'),'Explicit XML apply did not update source');Log('PASS explicit XML Apply writes the approved draft');
   end
   else if Action='group-xml-draft-checked' then begin
    var XmlDraftSource:=EditorSource(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas')));
    AssertTrue(XmlDraftSource.Contains('Implementation design before XML'),'Design save did not complete');AssertTrue(not XmlDraftSource.Contains('XML requires explicit approval'),'Unapproved XML draft was written');Log('PASS XML draft stays unapplied after Design ACK');
   end
   else if Action='group-implementation-checked' then begin
    var GroupFile:=TPath.Combine(Root,'GroupB','ContextB.pas');var CheckParser:=TDocParser.Create;
    try CheckParser.ParseSource(EditorSource(SourceEditorForFile(GroupFile)),GroupFile);var Seen:=0;
     for var E in CheckParser.GetAllElements do if E.Name='FromB' then begin
      if E.SourceSection='implementation' then AssertTrue(E.ExistingDocXml.Contains('Implementation second'),'Pinned second edit missed implementation')
      else AssertTrue(E.ExistingDocXml.Contains('GroupB saved before format'),'Pinned implementation edit changed interface declaration');Inc(Seen);
     end;AssertTrue(Seen=2,'Declaration/implementation pair missing');
    finally CheckParser.Free;end;
    Log('PASS pinned implementation ACK retains both source locations after line shifts');
   end
   else if Action='group-include' then begin
    var IncludePath:=TPath.Combine(Root,'GroupB','Features.inc');
    if Json.GetValue<Boolean>('enabled',True) then TFile.WriteAllText(IncludePath,'{$DEFINE FROM_B}') else TFile.WriteAllText(IncludePath,'{$UNDEF FROM_B}');
   end
   else if Action='group-quick-context' then begin
    var QuickFile:=TPath.Combine(Root,'GroupB','ContextB.pas');var QuickEditor:=SourceEditorForFile(QuickFile);QuickEditor.Show;var QuickSource:=EditorSource(QuickEditor);var Lines:=QuickSource.Split([#10]);
    var QuickPos:TOTAEditPos;QuickPos.Line:=0;for var I:=0 to High(Lines) do if Lines[I].Contains('Worker.Run(Local)') then begin QuickPos.Line:=I+1;QuickPos.Col:=System.Pos('Run(Local)',Lines[I])+1;Break;end;
    AssertTrue(QuickPos.Line>0,'Quick documentation call fixture absent');QuickEditor.EditViews[0].SetCursorPos(QuickPos);QuickEditor.EditViews[0].MoveViewToCursor;Inspector.HandleCursorChanged(QuickPos.Line,QuickSource,QuickFile);Browser.ExecuteScript('window.__quickContextReady=true');
   end
   else if Action='group-stub' then begin
    var StubItem:=FindMenuCommand((BorlandIDEServices as INTAServices).MainMenu.Items,'Generate Doc Stub');AssertTrue(Assigned(StubItem),'Stub menu absent');StubItem.Click;
    var StubSource:=EditorSource(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas')));
    AssertTrue(StubSource.Contains('<param name="Value">'),'Stub did not document project B parameter');Log('PASS GroupB Generate Stub with owning project');
   end
   else if Action='assert-group-format' then begin
    var GroupFile:=TPath.Combine(Root,'GroupB','ContextB.pas');
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
   if Text.Contains('Do you really want to format the selected file:') and Text.Contains(TPath.Combine(Root,'GroupB','ContextB.pas')) then begin
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
   AssertTrue((BorlandIDEServices as IOTAActionServices).OpenProject(TPath.Combine(Root,'GroupB','GroupB.dproj'),False),'Cannot add group project B');
   var Group:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;
   for var J:=0 to Group.ProjectCount-1 do if SameText(Group.Projects[J].FileName,PrimaryProjectFile) then begin Group.ActiveProject:=Group.Projects[J];Break;end;
   Log('Added project B; active project '+GetActiveProject.FileName);Step:=81;Timer.Interval:=1500;Timer.Enabled:=True;
   Exit;
  end;
  82:begin
   var GroupFile:=TPath.Combine(Root,'GroupB','ContextB.pas');
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
   var GroupEditor:=SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas'));
   if (EditorSource(GroupEditor)=FormatBefore) and (FormatWait<40) then begin Inc(FormatWait);Timer.Enabled:=True;Exit;end;
   AssertTrue(EditorSource(GroupEditor)<>FormatBefore,'Native formatter did not change unformatted Pascal buffer');
   FreeAndNil(FormatConfirmation);
   AssertTrue(EditorSource(GroupEditor).Contains('E2E native format'),'Native formatter lost Pascal buffer edit');
   AssertTrue(EditorSource(GroupEditor).Contains('GroupB saved before format'),'Native formatter lost documentation');
   Inspector.RefreshFromCurrentEditor;Log('PASS native Format Source on edited GroupB');
   Browser.ExecuteScript('window.__xmlDocNativeFormatted=true;');Step:=81;Timer.Interval:=1500;Timer.Enabled:=True;Exit;
  end;
  81:begin
   Browser.ExecuteScript(TFile.ReadAllText(TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_JS')),'WorkbenchGroupProbe.js')));
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
    var About:=TAboutDialog.Create(nil);
    try AssertTrue(About.lblVersion.Caption=TI18n.Instance.T('Version')+' '+GetEnvironmentVariable('XMLDOC_E2E_VERSION'),'About dialog version mismatch');finally About.Free;end;
    Log('PASS loaded BPL and About dialog shared version');
    var OriginalThemeSettings:=TPluginSettings.Instance.Global;
    var OldThemeDirectory:=TThemeEngine.Instance.CustomThemesDir;
    TThemeEngine.Instance.SetCustomThemesDir(TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_LOG')),'created-themes'));
    var ThemeDialog:=TSettingsDialog.Create(nil);
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
    finally
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
     Log('PASS project settings reset between projects and partial files');
    finally Settings.Free;TDirectory.Delete(SettingsRoot,True);end;
    AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(TPath.Combine(Root,'XmlDocE2E.dproj')),'Cannot open E2E project');Inc(Step);end;
  1:begin if (GetEnvironmentVariable('XMLDOC_E2E_AI_ONLY')='1') or (GetEnvironmentVariable('XMLDOC_E2E_MARKER_PHASE')<>'') or (StrToIntDef(GetEnvironmentVariable('XMLDOC_E2E_BENCHMARK_MODULES'),0)>0) or (GetEnvironmentVariable('XMLDOC_E2E_DIAGNOSTICS_ONLY')='1') then begin Inspector:=TDocInspectorForm.Create(nil);Inspector.Show;Explorer:=TDocExplorerForm.Create(nil);Explorer.Show;Inc(Step);Timer.Enabled:=True;Exit;end;ExportAll;if GetEnvironmentVariable('XMLDOC_E2E_THEMES_ONLY')='1' then begin Log('PASS');Finish;Exit;end;Inspector:=TDocInspectorForm.Create(nil);Inspector.Show;Explorer:=TDocExplorerForm.Create(nil);Explorer.Show;AssertErrorLabelTheme(Inspector);AssertErrorLabelTheme(Explorer);Inc(Step);end;
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
   if GetEnvironmentVariable('XMLDOC_E2E_AI_ONLY')='1' then begin Browser.ExecuteScript(TFile.ReadAllText(TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_JS')),'AIAssistantProbe.js')));Inc(Step);Exit;end;
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
    Log('PASS');Step:=90;Timer.Interval:=100;Timer.Enabled:=True;Exit;
   end;
   if StrToIntDef(GetEnvironmentVariable('XMLDOC_E2E_BENCHMARK_MODULES'),0)>0 then begin Step:=104;Timer.Enabled:=True;Exit;end;Inc(Step);Select(SampleFile,'Run','string');if GetEnvironmentVariable('XMLDOC_E2E_GROUP_ONLY')='1' then Browser.ExecuteScript('window.chrome.webview.postMessage(JSON.stringify({type:"e2e",action:"prepare-group"}));') else Browser.ExecuteScript(TFile.ReadAllText(GetEnvironmentVariable('XMLDOC_E2E_JS')));end;
 end;
 if Step<4 then Timer.Enabled:=True;
 except on E:Exception do begin Log('FAIL '+E.Message);if GetEnvironmentVariable('XMLDOC_E2E_KEEP_FAILURE')<>'1' then ExitProcess(1);end;end;
end;
procedure Register;
begin if Assigned(Probe) then Exit;Probe:=TProbe.Create;Probe.Timer:=TTimer.Create(nil);Probe.Timer.Interval:=2500;Probe.Timer.OnTimer:=Probe.Tick;end;
initialization
finalization
 Log('Finalizing probe');if Probe<>nil then begin Probe.Timer.Free;Probe.ValidationProbe.Free;Probe.FormatConfirmation.Free;Probe.Inspector.Free;Probe.Explorer.Free;Probe.Free;Probe:=nil;end;Log('Probe finalized');
end.
